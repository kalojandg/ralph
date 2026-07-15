# Ralph Reference — `tasks.json` структура и проследяване на прогреса

> Дълбок одит на **как е структуриран `tasks.json`** и **как `activity.md` записва прогреса**.
> Придружава `AUDIT.md` (общия одит на машината). Този документ = референция за данните и progress-модела.
> Числата са снети от текущия `tasks.json` (252 таска, всички `passes:true`) и `activity.md` (7746 реда, 225 записа).

---

## ЧАСТ 1 — `tasks.json`

### 1.1 Общ вид

- Файлът е **JSON масив** от task-обекти. Няма wrapper обект, няма metadata — само `[ {...}, {...} ]`.
- Масивът е **сортиран възходящо по `id`** (проверено). Това е важно: машината взима **първия** таск с `passes:false` в реда на масива → редът = ред на изпълнение.
- Големина: ~516 KB, 252 таска.
- `id` варира **1 → 268**, но има **дупки** (липсват 52-54, 57, 126-129, 144-149, 181, 183). Дупките са ОК — идват от таскове, които са били планирани и после махнати/слети. **Няма дублирани id.**

### 1.2 Схема на таск — поле по поле

| Поле | Тип | Честота | Задължително? | Роля |
|------|-----|---------|---------------|------|
| `id` | number | 252/252 | ✅ винаги | Уникален идентификатор. Ред в масива = ред на изпълнение. |
| `description` | string | 252/252 | ✅ винаги | Едноредово описание. Ползва се **дословно** като git commit message. Дължина 29–835 знака (avg 138). |
| `steps` | array | 252/252 | ✅ винаги | Списък под-стъпки (виж 1.4). |
| `passes` | boolean | 252/252 | ✅ винаги | **Единственият progress флаг.** `false` = чака, `true` = готов. |
| `category` | string | 232/252 | ⬜ опц. | Групиране (виж 1.3). 20 таска нямат. |
| `tddWorkflow` | boolean | 184/252 | ⬜ опц. | `true` → агентът следва RED→GREEN→…; steps имат `phase`. Липсва → прост setup таск. |
| `repo` | string | 154/252 | ⬜ опц. | Рутиране: `frontend` / `backend` / `database` / `shared`. Липсва → агентът гади от описанието. |
| `specRef` | string | 82/252 | ⬜ опц. | Указател към спецификация, напр. `"frontend-requirements.md §5.5"`. Свободен текст, чете се от човек/агент. |
| `notes` | string | 57/252 | ⬜ опц. | Свободна бележка/контекст (напр. „предишен опит не match-на дизайна"). |
| `designReference` | string | 31/252 | ⬜ опц. | Път до дизайн PNG, напр. `"docs/composition/designs/9.png"`. Тригер за VISUAL фаза. |
| `priority` | string | 20/252 | ⬜ опц. | `critical` / `high` / `medium` / `low`. **Само информативно — НЕ влияе на реда** (редът е по масив). |
| `migrationRef` | string | 4/252 | ⬜ опц. | Относителен път от `wagon-migrations/`, напр. `"02_series_15-63.md"`. Тригер за четене на миграционна спека. |

> **Ядро (винаги):** `id`, `description`, `steps`, `passes`. Всичко останало е опционален контекст/рутиране.

### 1.2.1 Полета за ПАРАЛЕЛЕН режим (swarm) — добавени по-късно

| Поле | Тип | Роля |
|------|-----|------|
| `lane` | string | Зона на собственост. Таскове в една lane вървят ЕДИН ПО ЕДИН (по реда в масива); различни lanes — паралелно. Липсва → таскът е сам в своя lane. |
| `dependsOn` | int[] | Стартира само когато всички изброени таскове са `passes:true` (merged). |
| `files` | string[] | Ownership boundary (glob-ове от gitRoot) — агентът пипа само тях. Две lanes не претендират едни и същи файлове. |

Пълните правила за декомпозиция: [[parallel-swarm-reference]] Част 2.

### 1.3 `category` разпределение

```
frontend         108      setup            11
backend           67      refactor          5
(липсва)          20      wagon-migration   4
feature           17      testing           2
e2e               13      polish            2
                          docs / documentation  3
```
Забележка: `category` и `repo` **се припокриват частично, но не са едно и също** — `category` е за групиране/четимост, `repo` е за рутиране (коя работна директория + кой structure файл да се чете). Има таскове с `category:"frontend"` но без `repo` поле.

### 1.4 Схема на `steps[]`

Всеки step е обект с максимум 3 полета:

| Поле | Честота | Роля |
|------|---------|------|
| `id` | 1204/1204 | под-номер, напр. `"78.1"`, `"267.3"` (`<taskId>.<n>`) |
| `action` | 1204/1204 | текст какво да се направи |
| `phase` | 948/1204 | TDD фаза (само при `tddWorkflow:true` таскове) |

Общо 1204 стъпки в 252 таска (avg ~5 стъпки/таск).

**Разпределение на `phase`** (948 стъпки с фаза):
```
GREEN 333   RED 203   DONE 198   RECON 66   VISUAL 58   REFACTOR 40
+ дребни/нестандартни: RED/GREEN 19, IMPLEMENT 13, AUDIT 9, DESIGN 3, FIX 2,
  E2E 1, PERFORMANCE 1, RESEARCH 1, INTEGRATE 1
```

> ⚠️ **Наблюдение за нормализация:** каноничните фази са `RED → GREEN → VISUAL → REFACTOR → DONE` (+ `RECON` за разузнаване преди RED). Но има **свободни вариации** (`RED/GREEN`, `IMPLEMENT`, `AUDIT`, `DESIGN`…) — влезли са ръчно. Не чупят машината (тя не парсва фазите — само агентът ги чете), но за универсалната версия си струва да се фиксира enum.

### 1.5 Примерен таск (пълен, backend TDD)

```json
{
  "id": 78,
  "category": "backend",
  "repo": "backend",
  "description": "[BE] CRUD API за CoachLayouts — POST /api/coach-layouts",
  "tddWorkflow": true,
  "steps": [
    { "id": "78.1", "phase": "RED",   "action": "Напиши unit тест за CreateCoachLayoutCommand + Handler…" },
    { "id": "78.2", "phase": "GREEN", "action": "Създай Application/Features/…/CreateCoachLayout.cs…" },
    { "id": "78.3", "phase": "GREEN", "action": "Добави endpoint POST /api/coach-layouts…" },
    { "id": "78.4", "phase": "DONE",  "action": "…" }
  ],
  "passes": true
}
```

### 1.6 Как полетата тригерират поведение

| Поле в таска | Какво кара агента/машината да направи |
|--------------|----------------------------------------|
| `repo` | Избира работна директория + кой `*-structure.md` файл да прочете (виж `prerequisite-steps.md`) |
| `tddWorkflow:true` | Следва TDD фазите от `steps[].phase` |
| `designReference` | Пуска VISUAL фаза (screenshot vs. дизайн PNG) |
| `migrationRef` | Чете допълнително миграционната спека от `wagon-migrations/` |
| `specRef` | Чете посочената секция от изискванията |
| `passes` | **Машината** брои това поле за прогрес и решава кой е следващ |

---

## ЧАСТ 2 — Проследяване на прогреса

### 2.1 Двата паралелни канала

Прогресът се пази на **две места, с различна цел**:

| Канал | Файл | Кой пише | За какво служи |
|-------|------|----------|----------------|
| **Машинен** | `tasks.json` → `passes` | Агентът обръща `false→true` | Машината брои и решава кога да спре / кой е следващ |
| **Наративен** | `activity.md` → нов запис | Агентът добавя запис | Човешка история: какво/защо/как е направено, за одит и debugging |

Двата НЕ са свързани автоматично — агентът трябва да актуализира **и двете** в рамките на итерацията (Step 4 от PROMPT.md).

**⚡ В SWARM (паралелен) режим writer-ът се сменя:** агентите НЕ пишат tasks.json/activity.md (shared → race). Всеки агент пише `results/task-<id>.json`; **оркестраторът** (single writer) прави merge на branch-а и чак тогава маркира `passes:true` + prepend-ва activity записа от резултата. Т.е. `passes:true` в swarm означава „done И merged в integration branch-а". Виж [[parallel-swarm-reference]].

### 2.2 Машинният канал — точна механика

1. **Избор на следващ таск** (`ralph-iteration.ps1`):
   ```
   $currentTask = $tasks | Where-Object { $_.passes -eq $false } | Select-Object -First 1
   ```
   → **първият** `passes:false` в реда на масива. (Затова редът в масива = приоритет, НЕ полето `priority`.)

2. **Завършване:** агентът редактира таска `"passes": false → true`.

3. **Completion check** в края на итерацията:
   ```
   $done = (# passes:true),  $total = (# всички)
   if ($done -eq $total) → exit 0   # всичко готово, loop-ът спира
   else → exit 1                    # има още, напред
   ```

Текущо състояние: **252/252 `passes:true` → next = NONE → машината би излязла с exit 0.**

### 2.3 Наративният канал — анатомия на `activity.md`

- **Подредба: обратно-хронологична** — най-новият запис е **отгоре** (агентът prepend-ва). Най-горе е `2026-06-25 12:05` (Task #267), надолу датите намаляват.
- 225 записа за 252 таска → **не всеки таск има запис** (ранни/тривиални setup таскове са пропуснати; понякога един запис покрива слети под-таскове).
- Разделител между записи: `---`.

**Шаблон на запис** (както реално изглежда в новите записи — по-богат от примера в PROMPT.md):

```markdown
## [YYYY-MM-DD HH:MM] - Task #<id>: <description дословно>

**Status:** ✅ Complete

**TDD Phase:** RECON → RED/GREEN → DONE (`tddWorkflow: true`)

**Problem:** <какъв е бил проблемът / контекст>

**What was done (RED → GREEN):**
- RED: <какъв failing тест е добавен, verify че fail-ва>
- GREEN: <минимална имплементация, verify че pass-ва>

**Verification (DONE <step>):**
- <тест файл> → X/Y pass
- eslint → 0 errors
- npm run type-check → clean
- <бележки за pre-existing провали, e2e решения и т.н.>

**Files modified:**
- <path 1>
- <path 2>

**Git commit:** `<hash>` — `<commit message>`. (<бележки за unstaged артефакти>)

---
```

**Задължителни секции** (присъстват във всеки нов запис): header с дата+task, `Status`, `Files modified`, `Git commit`.
**Условни секции:** `TDD Phase` (само при tddWorkflow), `Problem`, `What was done`, `Verification`, понякога `VISUAL` резултат (Layout/Colors/Typography/Spacing ✅).

### 2.4 Пълен жизнен цикъл на един таск

```
1. Машината избира първия passes:false таск  ─────────────┐
2. Агентът чете steps + (repo → structure файл, specRef,   │  ИТЕРАЦИЯ
   designReference, migrationRef)                          │  (нов агент,
3. Изпълнява steps една по една (TDD фази ако tddWorkflow)  │   чист контекст)
4. Verify (тестове/lint/type-check/visual)                  │
5. tasks.json: passes false → true          ← машинен      │
6. activity.md: prepend нов запис            ← наративен    │
7. git commit -m "<description дословно>"                   │
8. Извежда <task-complete> + <status>CONTINUE/COMPLETE>     │
9. STOP  ─────────────────────────────────────────────────┘
   → машината брои passes, решава exit 0/1, пуска следваща итерация
```

---

## ЧАСТ 3 — Наблюдения за универсалната версия (стъпка 2)

1. **`passes` е единственият source of truth за прогреса.** Прост и надежден boolean. Запази го.
2. **Редът в масива = приоритет, НЕ полето `priority`.** Това е скрито правило — `priority` в момента е декоративно. За универсалната версия: или направи `priority` реален (сортиране), или премахни подвеждащото поле.
3. **`phase` enum-ът е разкапан** (15 различни стойности вместо ~6). Струва си канонизиране: `RECON, RED, GREEN, VISUAL, REFACTOR, DONE`.
4. **`category` vs `repo` дублират цел.** `repo` върши рутирането; `category` е само за четимост. Помисли дали и двете са нужни.
5. **Пътищата в `designReference`/`specRef`/`migrationRef` са относителни към РАЗЛИЧНИ корени** (`docs/composition/designs/` спрямо Admin-App; `wagon-migrations/` спрямо Projects). За универсалност — единна конвенция за база на пътищата (напр. всичко спрямо `project/` корен, дефиниран в config).
6. **activity.md няма машинна връзка с tasks.json.** Разчита на дисциплина на агента да пише и двете. Ако искаш по-надеждно — може машината да генерира скелета на activity записа от таска автоматично.
7. **activity.md расте неограничено** (542 KB вече). За дълги проекти обмисли ротация/архив по етапи.
8. **Шаблонът в PROMPT.md е остарял** спрямо реалните записи (реалните имат `Problem`, `RECON`, richer verification). Синхронизирай шаблона с реалната практика.
```
