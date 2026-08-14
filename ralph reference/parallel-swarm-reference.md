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
| Конфликт при merge? | **Автоматичен resolve retry**: конфликтните файлове отиват в retry контекста, таскът се re-queue-ва в conflict режим — агентът merge-ва integration branch-а В СОБСТВЕНОТО си worktree и разрешава (бюджетирано, дял от `max_fail_retries`). Чак след изчерпан бюджет → branch за ръчен resolve. |
| Retry при провал? | ✅ Bounded (x`max_fail_retries`, default 4) и **CONTINUATION**: worktree-то и branch-ът на провалилия се опит СЕ ПАЗЯТ; следващият агент ги наследява + failure контекста и ПОПРАВЯ/ДОВЪРШВА, не преражда от нулата. Виж §1 „Retry поведение". |
| Кой пази integration branch-а зелен? | **Post-merge verify gate**: след всеки merge оркестраторът пуска `verify` командите на репото (repos.json); червено → merge-ът се връща (`reset --hard`) + информиран retry. Следващият merge стъпва само върху ВЕРИФИЦИРАНО зелен branch. |

---

## ЧАСТ 1 — Архитектура

### Компоненти

```
ralph-swarm.ps1            ← ОРКЕСТРАТОР (нов): claim → worktree → spawn → merge → board update
ralph-iteration.ps1        ← агентска обвивка; +parallel mode параметри (-taskId, -workDir, -branch, -resultFile, -agentSlot)
tasks.json                 ← task board (+ lane / dependsOn / files полета)
claims/task-<id>.claim     ← atomic claim файлове (session-scoped locks)
results/task-<id>.json     ← агентски отчети (заместват писането в tasks.json/activity.md)
retry/task-<id>.md         ← failure контекст (причина + log tail на провалилия се опит);
                             инжектира се в prompt-а на СЛЕДВАЩИЯ опит; трие се при merge
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
       merged   → POST-MERGE VERIFY GATE: пуска `verify` командите на репото (repos.json)
                  върху merged integration branch-а:
                    зелено  → tasks.json passes:true + prepend activity entry
                              + изтрий worktree/branch + изтрий retry/task-<id>.md
                    червено/timeout → git reset --hard до pre-merge SHA (merge-ът се ВРЪЩА,
                              integration branch-ът остава зелен) → информиран retry
                              с verify отчета като контекст (бюджет max_fail_retries)
       conflict → merge --abort, branch остава, таскът НЕ е passed (ръчен resolve)
       skipped  → главният checkout е на друг branch/dirty → branch остава
     exit 2 (quota)         → re-queue (НЕ е failed), чист worktree при следващия pass
     exit 3 (timeout/stale) → re-queue с чист worktree, до max_timeout_requeues пъти
                              (default 2); след изчерпване → failed за сесията
     status=failed / няма result → ИНФОРМИРАН RETRY: причината + tail на лога отиват в
                              retry/task-<id>.md, следващият опит го получава в prompt-а
                              (-retryFile) — до max_fail_retries пъти (default 2);
                              след изчерпване → failed за сесията
7. Слотът се освобождава → следващият eligible таск стартира (rolling pipeline)
8. Всички passes:true → **FINISHING STEP** → SWARM SUMMARY → exit
     Finishing step (САМО при пълен успех — всеки merge е минал гейта, публикуването е безопасно):
       finish_review → REVIEW STAGE (преди docs/push): по репо — review агент чете diff-а
                     на ЦЕЛИЯ run (startSha..HEAD, снимнат при старта) срещу structure
                     reference-а като правила (шаблон: ralph reference/review-prompt-template.md,
                     адаптиран от служебния review промпт на потребителя) → доклад в
                     C:\CodeReview\<repo>\CODE-REVIEW-*.md + машинен verdict.json
                     {blockers, important, recommendations}. ACCEPTANCE: 0 блокери И 0 важни
                     (препоръките са позволени). При провал → FIX агент оправя САМО
                     блокери+важни (или обосновава грешна забележка в доклада), commit,
                     който трябва да мине ПЪЛНИЯ verify гейт (червен → rollback) → ре-ревю.
                     До finish_review_cycles (default 2) цикъла; неуспех → FINISHING ABORTED:
                     без docs, БЕЗ push — докладите чакат човек. Логове: logs/review-* и
                     logs/reviewfix-*.
       finish_docs → по един docs агент per докоснато репо: обновява structure reference-а
                     (в ralph репото) + собствените docs на репото (README/BEHAVIOR/TEST_CASES)
                     спрямо какво board-ът промени; commit-ва САМО документация; timeout 25 мин;
                     лог в logs/finishing-<repo>-*.txt
       finish_push → ПЪРВО commit на ralph репото (оркестраторът пише tasks.json/activity.md
                     БЕЗ да комитва — иначе push-ът му е празен; runtime директориите са gitignored),
                     ПОСЛЕ git push на всяко докоснато репо + ralph репото
     Провал тук = WARNING, не проваля run-а (резултатът е безопасен локално).
     При частично провален board (изход "no eligible") finishing step НЕ се изпълнява.
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

### Exit кодове (parallel mode на ralph-iteration.ps1) и реакцията на оркестратора

| Exit | Значение | Оркестраторът прави |
|------|----------|---------------------|
| 0 | Result file написан и валиден JSON | status=done → merge; status=failed → информиран retry (до `max_fail_retries`) |
| 1 | Няма result file / невалиден | Информиран retry (до `max_fail_retries`), после failed |
| 2 | Quota (агентът вече е изчакал reset-а) | Re-queue, не брои за нищо лошо |
| 3 | Timeout/stale (watchdog kill) | Re-queue с чист worktree (до `max_timeout_requeues`), после failed |
| 4 | Фатална billing/auth грешка ("Credit balance is too low") | **ABORT на целия run** — таскът НЕ се брои за failed, retry бюджетът му не се пипа; човек оправя кредити/модел и пуска нов run |

### Retry поведение — CONTINUATION семантика (бюджети per task, config: `swarm.max_timeout_requeues` / `swarm.max_fail_retries`, default 4/4)

- **ГЛАВНОТО ПРАВИЛО: при retryable изход worktree-то И branch-ът НЕ се трият.** Следващият опит (когато `retry/task-<id>.md` + worktree + branch съществуват) се spawn-ва В СЪЩОТО worktree (`CONTINUATION retry` на таблото) и получава `-retryMode continue`: инструкцията е първо `git status/log/diff`, запази правилното, поправи точно каквото отчетът казва, довърши липсващото, commit + result. Поправка/доработка, НЕ прераждане.
- **Quota (exit 2) / Timeout (exit 3) / Fatal env (exit 4):** пишат "resume" бележка в retry контекста („работата е запазена, продължи откъдето спря") — прекъснатата работа, вкл. некомитнати промени, се наследява.
- **Истински провал / verify RED:** причината (status/summary, verify отчет) + последните ~60 реда от лога отиват в `retry/task-<id>.md`; контекстът се инжектира СЛЕД parallel-mode секцията, ПРЕДИ feedback. При continuation агентът вижда и кода на предшественика директно в worktree-то — контекст + диффът на живо.
- **Fresh spawn** става само при: първи опит, липсващ branch/worktree (напр. изчистени ръчно), или липсващ retry контекст.
- **РЕЖИМНА СТЪЛБИЦА на continuation retry-тата** (`-retryMode`):
  - `continue` (опити 1..`escalate_after`): поправка В РАМКИТЕ на `files` границата;
  - `escalate` (след `escalate_after` изчерпани fail retry-та, config default 2): **scope-ът е вдигнат за гейт-доказани провали** — агентът може хирургично да поправя out-of-scope файлове (чужди спекове/съседен код), с изрична преценка „остарял тест ИЛИ прав тест, хванал мой бъг", и изброява всеки out-of-scope файл в result summary. Решава патърна „агентът вижда фикса, дисциплината го спира, бюджетът гори" (#33/#34);
  - `conflict` (след неуспешен merge): мандат по изключение за `git merge <mainBranch>` в собственото worktree + resolve на изброените конфликтни файлове + merge commit. Останалите git забрани важат винаги (push/checkout/rebase/главния checkout).
- **Per-task verify override:** таск може да носи собствен `verify` масив в tasks.json — той ПЕЧЕЛИ над repo-wide гейта за неговия merge. Употреба: прицелен subset вместо пълния suite (напр. `["npm test -- flavor-ui critical-path"]` — playwright филтрира по подниз от пътя на спека), без `npm ci` когато таскът не пипа package.json. Финалният таск на всяка lane остава БЕЗ override → пълният repo гейт хваща каквото subset-ите са изпуснали. Празен масив `[]` = без гейт за таска (внимавай). Правило при авторството: във филтъра слагай само спекове, които ГАРАНТИРАНО съществуват след таска (изтрит спек във филтъра → playwright error → фалшиво червено).
- **Verify gate провал → същият информиран retry.** Ако merge-ът мине, но `verify` командите на репото са червени на integration branch-а, merge-ът се връща и таскът се retry-ва с verify отчета (команда, exit код, последните ~60 реда изход) като контекст — споделя бюджета `max_fail_retries`.
- Няколко провала се **акумулират** в същия файл (в prompt-а влизат последните ~8000 знака — най-новото печели).
- `retry/task-<id>.md` **преживява сесиите** (нов run започва с контекста от стария) и се **трие при успешен merge**; при старт на run се измитат и retry файловете на таскове, които вече са `passes:true` (напр. завършени ръчно) — няма stale състояние.
- Броячите са per-session; изчерпан бюджет → failed за сесията, lane-ът спира (нов run започва с нулирани броячи + запазения контекст).
- Quota re-queue е ИЗВЪН бюджетите — не хаби retry.
- **Environment-failure guard:** 3 поредни агента, умрели за <60 сек = проблем на средата (лош `--model`, изтекъл auth, API 400, стар claude CLI), НЕ на тасковете → оркестраторът ABORT-ва целия run с диагностика, вместо да изгори retry бюджета на всички таскове върху една и съща конфигурационна грешка. Merge или „бавен" провал нулира брояча. (Огледало на silent-failure guard-а от соло ralph.ps1.)

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

### Колко агента тръгват реално? (agents = таван, eligibility = регулатор)

`-agents N` е само **максимум слотове**. Реално тръгват `min(свободни слотове, eligible таскове)` — ако само 1 таск е eligible, тръгва 1 агент, останалите слотове чакат. Никой не се пуска „защото има свободен слот".

### TDD ред между таскове (тестове ПРЕДИ имплементация)

- **Канонично (препоръчано):** RED+GREEN са стъпки на ЕДИН таск (`tddWorkflow:true`) — един агент пише теста и имплементацията в една итерация. Никакъв междутасков ред не е нужен.
- **Разделени таскове** (тестове = отделен таск): използвай **двата предпазителя**:
  ```json
  { "id": 10, "lane": "feature-x", "description": "[TEST] Contract тестове за X" },
  { "id": 11, "lane": "feature-x", "dependsOn": [10], "description": "[BE] Имплементирай X" }
  ```
  Същата lane пази реда; `dependsOn` гейтва на **merged** (`passes:true` в swarm = done И merged). Критично: worktree на #11 се клонира от integration branch-а ПРИ СТАРТА му → имплементаторът физически вижда тестовете само ако #10 вече е merged. Затова dependsOn чака merge, не просто „done".

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
Config: `ralph-config.json → swarm: { agents, worktree_root, keep_windows, window_style, max_timeout_requeues, max_fail_retries, verify_enabled, verify_timeout_min }`. Verify командите per repo: `repos.json → repos.<key>.verify` (масив; липсва → няма gate за това репо).

### Изисквания преди пускане
- Integration branch-ът (`repos.json → mainBranch` — ⚠ различен per repo: hero e `master`, останалите `main`) е **checked out и чист** във ВСЕКИ gitRoot, по който има таскове — иначе merge-ът се skip-ва (safe, но ръчна работа после).
- `tasks.json` е декомпозиран по правилата от Част 2 (най-вече: без файлово застъпване между lanes) и **всеки таск има `repo` поле** (inventory/hero/combat/spells — няма безопасен дефолт при 4 приложения).
- **Никакви ръчни dev/serve сървъри по време на run** — портовете са споделени (45279: inventory/hero/spells; 45278: combat) и playwright `reuseExistingServer` в гейта ще тества ГРЕШНОТО приложение, ако завари чужд сървър на порта.

### Multi-repo паралелизъм (fleet режим)
- **Cross-repo таскове са перфектно паралелни по конструкция**: отделни gitRoots = нула споделени файлове = merge конфликт между два репота е физически невъзможен. 4 приложения × 1 lane = 4 агента без никакъв риск от застъпване.
- Lanes и dependsOn са глобални имена — cross-repo dependsOn работи (напр. „фича в inventory чака утилита в hero" — рядко, но възможно).
- Verify gate-ът си остава последователен (един merge → един гейт → следващият), затова споделените e2e портове не се бият МЕЖДУ гейтовете — само с ръчни сървъри (виж горе).

### Мониторинг (3 нива на видимост)

1. **Прозорец на агент** — всеки агент е отделен PowerShell прозорец със заглавие `Ralph SLOT N - task #X (ralph/task-X)`: там виждаш каквото и в соло режим (таск инфо, spinner, CLAUDE OUTPUT). По default прозорецът се затваря при край; `-keepWindows` (или config `swarm.keep_windows:true`) го оставя отворен за преглед.
   **Стил на прозорците** — `-agentWindows Normal|Minimized|Hidden` (или config `swarm.window_style`, default в config-а: `Minimized`): `Normal` изскача на екрана; `Minimized` стои тихо в taskbar-а (не краде фокус — отваряш го само ако искаш да гледаш); `Hidden` изобщо без конзоли — следиш само таблото на оркестратора + `logs/`.
2. **Оркестраторска конзола (таблото)** — събития (`[>] SLOT started`, `[v] verify gate ...`, `[+] DONE+MERGED`, `[X] CONFLICT`, `[X] VERIFY GATE RED - merge undone`, `[~] QUOTA re-queued`, `[~] TIMEOUT re-queued`, `[~] FAILED - RETRY n/m`) + статус ред на всеки 15s: `running: [ids] | merged X | conflicts Y | skipped Z | failed W`. Summary-то накрая показва и `Timeout re-queues` / `Fail retries` / `Verify reverts`.
3. **Трайни следи** — `logs/iteration-<taskId>-*.txt` (пълният изход на всеки агент; iterationNumber = task id → логовете са per-таск), `results/task-<id>.json` (отчетът), `retry/task-<id>.md` (история на провалените опити — съществува само докато таскът не merge-не), `tasks.json`/`activity.md` (board + наратив).

Playbook правило: проверявай агентите на всеки 20–30 мин за drift.

### Възстановяване след провал
| Ситуация | Какво остава | Какво правиш |
|----------|--------------|--------------|
| merge_conflict | branch `ralph/task-<id>` | ръчен merge/rebase → after: маркирай `passes:true` ръчно |
| merge_skipped (dirty/друг branch) | branch + result | почисти главния checkout → merge ръчно или нов swarm run |
| failed след изчерпани retry-та | branch (worktree е изтрит) + `retry/task-<id>.md` с историята на опитите | виж retry файла + лога в `logs/`; поправи таска/спека; нов run (тръгва с нулирани броячи + запазения контекст) |
| Оркестраторът убит насред run | worktrees + claims + retry файлове | нов run чисти claims автоматично; stale worktrees се пресъздават force; retry файловете се преизползват (информиран retry) |

### Квота при паралелна работа (важно!)

**Общият разход токени е ~същият като sequential** (20 таска = ~20 таска токени + малко worktree overhead). Swarm не хаби повече — **изразходва бюджета на прозореца по-рано**:
```
Sequential: ████░░░░░░░░░░░░  равномерно през прозореца
Swarm x3:   ████████████░░░░  същото количество, изгорено 3x по-бързо
                              → всички агенти удрят лимита ~едновременно и чакат reset
```
**Поведение при quota hit:** всеки агент сам засича „hit your limit", изчаква reset-а в собствения си прозорец и излиза с exit 2 → оркестраторът **re-queue-ва таска** (НЕ го брои за failed) → таскът тръгва пак с чист worktree при следващия pass. Виждаш го като `Quota re-queues` в summary.
**Контрол на изгарянето:** `-agents 2` (по-полека), `-maxTasks N` („направи N таска и спри" — бюджетиране на run-а). За нощен run на голям backlog: няма смисъл от >3 агента, ако квотата издържа ~X таска на прозорец — те просто ще ги свършат в началото и ще чакат.

### Ограничения (известни, приети)
- **Retry-ята са bounded** (виж „Retry поведение" в Част 1): timeout → до `max_timeout_requeues` слепи re-queue-та; провал → до `max_fail_retries` информирани retry-та. След изчерпване таскът е failed за сесията и lane-ът му спира — предпазва от вечно зацикляне. Нов run тръгва с нулирани броячи, но пази retry контекста.
- **Merge conflict НЕ се retry-ва автоматично** — branch-ът се пази за ръчен resolve (retry би изхвърлил свършената работа).
- **Verify gate-ът е синхронен в оркестратора** — докато `verify` командите вървят (мин-мин), поредните merges и събирането на приключили агенти изчакват. Агентите продължават да работят необезпокоявани (те са в worktrees). Това е цената merges-ите да са строго последователни върху верифицирано зелена база. Дълъг suite → вдигни `verify_timeout_min` или подреди бързите команди първи (fail fast).
- **Verify командите НЕ трябва да оставят untracked файлове** в главния checkout (build артефакти → .gitignore) — иначе следващите merges се skip-ват като "dirty".
- **`files` boundary не се enforce-ва механично** — инструкция е към агента (+ ревюто при merge). Дисциплината в декомпозицията е първата защита.
- **tasks.json се преформатира** от оркестратора при ъпдейт (PowerShell ConvertTo-Json — кирилицата става `\uXXXX` escapes; валиден JSON, но по-грозен за четене).
- Quota: всеки агент сам си чака reset-а (exit 2 логиката е в агентската обвивка).
