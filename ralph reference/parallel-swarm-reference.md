# Ralph Reference — SWARM: паралелни агенти върху git worktrees

> Как Ralph работи с **N агента едновременно**, без да си пречат: worktree изолация, lanes, claiming, sequential merge.
> Принципи, заимствани от parallel agentic development методологията (MindStudio playbook) + task board / operator pattern.
> Каноничният Ralph (1 агент, 1 таск, чист контекст) си остава — swarm е N канонични Ralph-а + оркестратор.

---

## TL;DR

| Въпрос | Отговор |
|--------|---------|
| Как се пуска? | `START-RALPH-SWARM.bat [agents] [maxTasks]` → `ralph-swarm.ps1` |
| Колко агента? | Старт: **2–3**. Практичен таван: **5–6** (после review overhead изяжда печалбата) |
| Как не си пречат? | Всеки агент = собствен **git worktree + branch** (`ralph/task-<id>`); файлова изолация by construction |
| Кой избира таскове? | **Само оркестраторът** (single writer). Агентът получава фиксиран `-taskId` |
| Кой пише tasks.json/activity.md? | **Само оркестраторът.** Агентите пишат `results/task-<id>.json` |
| Как влиза в главния клон? | Оркестраторът merge-ва завършените branch-ове **последователно** (`--no-ff`) в integration branch-а |
| Конфликт при merge? | `merge --abort`, branch-ът се пази за ръчен resolve, таскът остава `passes:false` |

---

## ЧАСТ 1 — Архитектура

### Компоненти

```
ralph-swarm.ps1            ← ОРКЕСТРАТОР (нов): claim → worktree → spawn → merge → board update
ralph-iteration.ps1        ← агентска обвивка; +parallel mode параметри (-taskId, -workDir, -branch, -resultFile, -agentSlot)
tasks.json                 ← task board (+ lane / dependsOn / files полета)
claims/task-<id>.claim     ← atomic claim файлове (session-scoped locks)
results/task-<id>.json     ← агентски отчети (заместват писането в tasks.json/activity.md)
repos.json                 ← + gitRoot / workSubdir / mainBranch (worktree топология)
<parent>\.ralph-worktrees\ ← worktree директории: <repoKey>-task-<id>
```

### Жизнен цикъл на един таск в swarm

```
1. Оркестраторът чете tasks.json → eligible таскове:
     - ПЪРВИЯТ pending таск от всяка lane (редът в масива = ред в lane-а)
     - lane-ът няма вече работещ агент (един агент на lane)
     - всички dependsOn са passes:true
     - не е фейлвал в тази сесия
2. Claim: claims/task-<id>.claim (atomic CreateNew — не може двоен claim)
3. Worktree: git -C <gitRoot> worktree add -b ralph/task-<id> <wtRoot>\<repo>-task-<id> <mainBranch>
     + копира .env* от главния checkout (untracked файлове не пътуват с worktree)
4. Spawn: ralph-iteration.ps1 -taskId <id> -workDir <worktree[/subdir]> -branch ... -resultFile ... -agentSlot N
     → отделен console прозорец на агент (visibility като tmux патърна)
5. Агентът работи САМО в worktree-то, комитва в собствения branch,
     накрая пише results/task-<id>.json → exit 0
6. Оркестраторът (rolling poll на 15s) хваща приключилия процес:
     status=done → SEQUENTIAL MERGE: git merge --no-ff ralph/task-<id> в mainBranch
       merged   → tasks.json passes:true + prepend activity entry + изтрий worktree/branch
       conflict → merge --abort, branch остава, таскът НЕ е passed (ръчен resolve)
       skipped  → главният checkout е на друг branch/dirty → branch остава
     status=failed / няма result → failed за сесията (не се retry-ва автоматично)
7. Слотът се освобождава → следващият eligible таск стартира (rolling pipeline)
8. Всички passes:true → SWARM SUMMARY → exit
```

### Защо оркестраторът е single writer

Два агента, които едновременно пишат `tasks.json` / `activity.md` = race + загубени ъпдейти. Затова:
- **Агент** пише само в **собствения си** worktree + **собствения си** `results/task-<id>.json` (никаква конкуренция).
- **Оркестраторът** е единственият, който пипа `tasks.json`, `activity.md`, прави merge и чисти worktrees.

### PARALLEL MODE override (какво вижда агентът)

Харнесът инжектира в prompt-а (след task-specific steps, преди feedback) секция, която **override-ва Steps 1/4/5**:
1. Работи САМО по task #X (не избира сам)
2. Работи САМО в worktree директорията; напускането ѝ е забранено
3. Git: комит само в текущия branch; **забранени**: checkout/switch/merge/rebase/push/worktree
4. `files` списъкът на таска = ownership boundary; нужда извън него → `status:"failed"` + обяснение (не самоволно разширяване)
5. Dev server портове: 5173+slot / 3000+slot (без колизии между агенти)
6. Вместо tasks.json/activity.md → пише result JSON: `{taskId, status, commit, testsPassed, summary, activity}`
7. Worktree започва без node_modules → `npm ci` при нужда; .env* са копирани
8. `<task-complete>` XML → STOP

### Exit кодове (parallel mode на ralph-iteration.ps1)

| Exit | Значение |
|------|----------|
| 0 | Result file написан и валиден JSON |
| 1 | Няма result file / невалиден → оркестраторът го брои за failed |
| 2/3 | Quota / timeout — както в каноничния режим |

---

## ЧАСТ 2 — Как се пишат таскове за паралелна работа (АВТОРСКИ ПРАВИЛА)

Това е **най-важната част**. Изолацията на worktree предпазва от едновременни писания, но **НЕ предпазва от merge конфликти** — тях ги предотвратява добрата декомпозиция.

### Новите полета в tasks.json

| Поле | Тип | Роля |
|------|-----|------|
| `lane` | string | **Зона на собственост / последователност.** Таскове в ЕДНА lane се изпълняват ЕДИН ПО ЕДИН по реда в масива (един агент на lane). Различни lanes вървят паралелно. Без `lane` → таскът е сам в собствена lane (независим). |
| `dependsOn` | int[] | Таскът стартира само когато ВСИЧКИ изброени id-та са `passes:true` (т.е. **merged**). Cross-lane зависимости стават така. |
| `files` | string[] | Ownership boundary — glob-ове (относителни към gitRoot-а). Агентът пипа САМО тях (+ нови тестове за тях). Двe lanes НЕ трябва да претендират едни и същи файлове. |

### Правила за декомпозиция (от playbook-а, адаптирани)

1. **Разбий по независими фичи, не по слоеве.** 3–5 паралелни lanes е сладката точка. „Фича A цялата" в една lane; НЕ „всички контролери" / „всички тестове" като lanes.
2. **Никакво застъпване на файлове между lanes.** Ако два таска пипат един файл/таблица → СЪЩАТА lane (последователни) или `dependsOn`. Провери `files` списъците за пресичане ПРЕДИ да пуснеш swarm-а.
3. **Списъкът shared/cross-cutting файлове е отрова за паралелизма:** router, DI регистрации, `locales/*.json`, `package.json`, shared types, DbContext, `Program.cs`. Таск, който ги пипа → **собствена lane + dependsOn към всичко, което може да го засегне**, или го пусни соло (канонично) преди/след swarm-а.
4. **Конкретика на спека:** „подобри UX" се проваля; „добави server-side pagination на /api/products" успява. Едно-параграфов спек + acceptance criteria.
5. **DB миграции НЕ вървят паралелно.** Два агента с миграции срещу една база = schema, която никой не очаква. Всички database таскове → ЕДНА lane. Идемпотентни post-deployment скриптове с поредни номера се дублират, ако два агента ги номерират едновременно — затова database lane-ът е един.
6. **API contract между FE и BE:** BE таскът дефинира contract-а, FE таскът е `dependsOn` BE-то (вижда merged endpoint-а). Алтернатива: FE мокне contract-а и двата вървят паралелно — тогава сложи contract-а в спека на ДВАТА таска дословно.
7. **Стъбиране пред секвениране:** ако B зависи само от интерфейса на A, дай на B мок и ги пусни паралелно; `dependsOn` само когато B има нужда от реалния merged код.
8. **Дръж тасковете къси.** Един таск = един commit = един merge. Колкото по-дълго живее branch-ът, толкова по-вероятен е конфликтът с вече merged работа.

### Пример за правилна декомпозиция

```json
[
  { "id": 10, "lane": "wagon-export",  "files": ["src/app/features/wagons/export/**"], ... },
  { "id": 11, "lane": "wagon-export",  "dependsOn": [10], "files": ["src/app/features/wagons/export/**"], ... },
  { "id": 20, "lane": "audit-log-be",  "repo": "backend",  "files": ["DotNetServices/RailRunService/**/Audit*"], ... },
  { "id": 21, "lane": "audit-log-fe",  "dependsOn": [20], "files": ["src/app/features/audit/**"], ... },
  { "id": 30, "lane": "i18n-cleanup",  "files": ["src/locales/**"], "notes": "пипа shared locales → сам в lane, БЕЗ паралелен FE таск, който добавя ключове!", ... }
]
```
→ #10 → #11 са последователни (една lane); #20 върви паралелно с #10; #21 чака #20 да е merged; #30 е соло-lane, но внимавай — виж правило 3.

### Анти-патърни

| Анти-патърн | Защо се чупи |
|-------------|--------------|
| Два таска в различни lanes добавят i18n ключове | `bg.json`/`en.json` merge конфликт всеки път |
| „Рефактор на shared/wagonGrid" паралелно с фича, която го ползва | Фичата стъпва на код, който изчезва под нея |
| DB миграция в две lanes | Дублирани номера на скриптове / неочаквана схема |
| Огромен таск (10+ файла, 3 слоя) в swarm | Дълголетен branch = гарантиран конфликт; пусни го соло |
| `dependsOn` цикъл (A→B→A) | Deadlock — оркестраторът спира с "no eligible tasks" |

---

## ЧАСТ 3 — Оперативни бележки

### Стартиране
```
START-RALPH-SWARM.bat            → 3 агента, до изчерпване
START-RALPH-SWARM.bat 2          → 2 агента
START-RALPH-SWARM.bat 4 10       → 4 агента, спри след 10 таска
powershell .\ralph-swarm.ps1 -agents 3 -maxTasks 0
```
Config: `ralph-config.json → swarm: { agents, worktree_root }`.

### Изисквания преди пускане
- Integration branch-ът (`repos.json → mainBranch`, сега `devdev`) е **checked out и чист** във всеки gitRoot — иначе merge-ът се skip-ва (safe, но ръчна работа после).
- `tasks.json` е декомпозиран по правилата от Част 2 (най-вече: без файлово застъпване между lanes).
- Забележка за OSDM-Src: backend и database споделят един gitRoot — един OSDM worktree носи и двете подпапки, но lanes пак определят кой какво пипа.

### Мониторинг
- Всеки агент = отделен PowerShell прозорец (виждаш spinner-а/лога му на живо).
- Оркестраторът печата на 15s: `running: [ids] | merged X | conflicts Y | skipped Z | failed W`.
- Playbook правило: проверявай агентите на всеки 20–30 мин за drift.

### Възстановяване след провал
| Ситуация | Какво остава | Какво правиш |
|----------|--------------|--------------|
| merge_conflict | branch `ralph/task-<id>` | ръчен merge/rebase → after: маркирай `passes:true` ръчно |
| merge_skipped (dirty/друг branch) | branch + result | почисти главния checkout → merge ръчно или нов swarm run |
| failed (без result) | branch (worktree е изтрит) | виж лога на агента в `logs/`; поправи таска/спека; нов run |
| Оркестраторът убит насред run | worktrees + claims | нов run чисти claims автоматично; stale worktrees се пресъздават force |

### Ограничения (известни, приети)
- **Няма автоматичен retry** на failed таск в същата сесия (предпазва от зацикляне). Нов run на swarm-а ги пробва пак.
- **`files` boundary не се enforce-ва механично** — инструкция е към агента (+ ревюто при merge). Дисциплината в декомпозицията е първата защита.
- **tasks.json се преформатира** от оркестратора при ъпдейт (PowerShell ConvertTo-Json — кирилицата става `\uXXXX` escapes; валиден JSON, но по-грозен за четене).
- Quota: всеки агент сам си чака reset-а (exit 2 логиката е в агентската обвивка).
