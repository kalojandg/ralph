# Одит на Ralph Wiggum алгоритъма

> Пълен одит на активния цикъл. Папка `working algorithm/` е бекъп и НЕ е разглеждана.
> Цел: подготовка за пренареждане към универсална структура ("в еди-коя стъпка отиваш в тази папка и четеш този файл"). Този документ = стъпка 1 (одит). Разчистването е стъпка 2.

---

## 0. Най-важното наблюдение

В момента **две неща живеят в една папка и са слепени**:

1. **Harness (машината)** — универсалният loop-механизъм: `ralph.ps1`, `ralph-iteration.ps1`, `ralph-config.json`.
2. **Project data (съдържанието за BDZ проекта)** — `tasks.json`, `PROMPT.md`, `user-steps.md`, `feedback.md`, `feature-map.json`, всички `*-spec.md` / `wagon-*.md`, `DOCS/`.

Целият harness е universal по замисъл, но е **закотвен с hardcode-нати абсолютни пътища** (`C:\Users\kaloyan.georgiev\Projects\...`) и с BDZ-специфично съдържание. Точно това ще разделяме в стъпка 2.

---

## 1. Точки за вход (entry points)

| Файл | Какво прави | Статус |
|------|-------------|--------|
| **START-RALPH-TDD.bat** | `pause` → `ralph.ps1 70` | ✅ **Реалният старт** (70 итерации) |
| ralph-quick.bat | `ralph.ps1 10` | ✅ работи (тест, 10 итерации) |
| ralph-with-config.bat | `ralph.ps1 <N> <config>` | ✅ работи (custom config) |
| ralph.bat | Чист batch loop, вика `claude -p "@PROMPT.md"` **директно** | ⚠️ **Legacy** — заобикаля целия ralph.ps1, стара completion логика |
| ralph-bash.bat → ralph.sh | Git Bash loop, вика claude директно | ⚠️ **Legacy** — същото, bash версия |

> `ralph-quick.bat` и `STRUCTURE.md` сочат към файлове, които **не съществуват**: `ralph.exe.bat`, `compile-to-exe.ps1`, `create-shortcut.ps1`, `README-BG.md`, `RALPH-ADVANCED.md`. STRUCTURE.md е остаряла карта.

**Реалната верига е само една:** `START-RALPH-TDD.bat` → `ralph.ps1` → `ralph-iteration.ps1`.
Останалите 3 (`ralph.bat`, `ralph-bash.bat`, `ralph.sh`) са примитивни дубликати от ранна версия.

---

## 2. Външният loop — `ralph.ps1`

Приема `<iterations>` + опц. config. Логиката:

1. Проверява, че `claude` CLI е на PATH (иначе fatal).
2. `while i <= iterations`: снима брой лог-файлове преди → вика `ralph-iteration.ps1 -iterationNumber i` → чете `$LASTEXITCODE`.
3. Реагира на exit кода на итерацията:

| Exit | Значение | Реакция на loop-а |
|------|----------|-------------------|
| **0** | Всички таскове passes:true | Спира — "All tasks complete" |
| **1** | Още има таскове / нормален край | `i++`, продължава |
| **2** | Quota hit (итерацията вече е изчакала reset) | retry **без** да хаби итерация |
| **3** | Timeout (claude убит) | `i++`, пауза 5с, напред към следващ таск |

4. **Silent-failure guard:** ако итерацията не е произвела нов лог → брои поредни провали; на 3 подред → abort с диагностика (auth изтекъл, network, лош модел).

---

## 3. Вътрешната итерация — `ralph-iteration.ps1` (ядрото)

Най-сложният и най-важен файл. Стъпка по стъпка:

**A. Сглобяване на prompt-а** (редове 50–98) — конкатенира в temp файл:
```
PROMPT.md
  + "\n--- Prerequisite: Read Before Implementation ---\n" + prerequisite-steps.md
  + "\n--- Post-Implementation Steps ---\n"               + user-steps.md
```
→ записва в `%TEMP%\ralph-prompt-<n>.txt`.

**B. Показва текущия таск** — чете `tasks.json`, намира първия `passes:false`, печата id/description/repo/migrationRef.

**C. Пуска Claude като background job** (ред 114–124):
```
claude -p "@<tempprompt>" --model <model> --dangerously-skip-permissions
        --verbose --output-format stream-json
```
Работната директория е **`C:\Users\kaloyan.georgiev\Projects`** (не ralph!) — агентът сам навигира към repo-то.

**D. Watchdog spinner** (ред 138–176) — докато job-ът върви:
- **Hard timeout:** 180 мин → exit 3.
- **Stale timeout:** 60 мин без растеж на output файла → exit 3. (Затова се ползва `stream-json` — за да расте файлът и watchdog-ът да „вижда" прогрес.)
- **Completion detection:** ако в последните редове се появи `"terminal_reason"` → break. (Нужно, защото фонов процес оставен от агента може да държи pipe-а отворен и `$job.State` никога да не стане Completed.)

**E. Cleanup** — Stop/Remove job, после **reap-ва** заблудени `node.exe` с `vitest|playwright` в командата (за да не се трупат при нощни run-ове). Vite dev server се оставя жив.

**F. Обработка на резултата** (ред 221+):
- Парсва NDJSON → извлича само `assistant.text` + финалния `result` за четим лог.
- **Quota detection:** regex `"hit your limit"` + `"resets 7pm (Europe/Sofia)"` → пресмята минути до reset, чака на чънкове по 5 мин, после **exit 2** (retry).
- Иначе печата output, записва `logs/iteration-<n>-<timestamp>.txt`.

**G. Completion check** (ред 331+) — чете `tasks.json`, брои `done/total`. Ако `done==total` → **exit 0**. Иначе печата следващия таск → **exit 1**.

---

## 4. Данни и проследяване на прогреса

| Файл | Роля | Формат |
|------|------|--------|
| **tasks.json** (516 KB) | **Source of truth.** 252 таска, **всички `passes:true`** (текущият run е приключил) | JSON array |
| **activity.md** (542 KB) | Append-only дневник — агентът пише по запис на таск | Markdown |
| **feedback.md** | Ръчен контекст между етапи (архитектурни правила, „червени линии") | Markdown |

**Схема на таск** (union от всички полета):
```
id, category, description, steps[], passes          ← ядро
repo, priority, notes                               ← рутиране
tddWorkflow, designReference, specRef, migrationRef ← контекст
```
`steps[]` носи `{id, action}`, а при TDD — и `phase: RED|GREEN|VISUAL|REFACTOR|DONE`.
`repo` разпределение: frontend 104, backend 47, database 2, shared 1, липсва 98.

**Прогресът се траква по два начина:**
- Механично → скриптът брои `passes:true` в `tasks.json` → решава exit кода.
- Наративно → агентът добавя запис в `activity.md`.

---

## 5. Конфигурацията — какво реално се чете vs. мъртво

`ralph-config.json` изглежда богат, но **голяма част не се консумира**:

| Ключ | Реално ползван? |
|------|-----------------|
| `prompt_file`, `prerequisite_steps`, `user_defined_steps` | ✅ да — четат се в ralph-iteration.ps1 |
| `claude_args → --model` | ✅ да (само моделът се вади оттам) |
| `claude_args → --output-format text` | ❌ **игнориран** — скриптът хардкодва `stream-json` |
| `completion_criteria` (patterns, continue_patterns, `completion-check.ps1`) | ❌ **мъртво** — итерацията прави собствено броене на tasks.json |
| `feedback` (feedback.md, append_after_iteration) | ❌ **мъртво** — `feedback.md` **никога не се inject-ва** в prompt-а автоматично |
| `tdd` (test_commands, visual_testing, mock_backend) | ❌ **чисто информативен** — нищо не го чете |

---

## 6. Мъртъв код и несъответствия (findings)

1. **`completion-check.ps1` е напълно мъртъв** — не се вика отникъде. Отгоре чете **грешен път**: `docs\composition\tasks.json` (спрямо parent), а реалният `tasks.json` е в ralph root.
2. **`feedback.md` е сирак** — config-ът обещава автоматично append, но кодът не го прави; PROMPT.md също не го изброява в „Context Files". Влияе само ако агентът случайно го отвори.
3. **`--output-format text` в config се игнорира** — реално е `stream-json` (умишлено, за watchdog-а). Config-ът заблуждава.
4. **3 legacy entry points** (`ralph.bat`, `ralph.sh`, `ralph-bash.bat`) — стар loop без watchdog/quota/completion логика. Объркват коя е „истинската" машина.
5. **STRUCTURE.md е остаряла** — описва несъществуващи файлове и грешна стъпка „Append feedback.md".
6. **Двата txt файла** („🚀 СТАРТ ТУК.txt", „КЛИКНИ ТУК.txt") — onboarding от ранна версия, вероятно вече неверни.

---

## 7. Какво го прави НЕуниверсален (подготовка за стъпка 2)

Три вида закотвяне, всичкото за разчистване:

**а) Hardcode-нати абсолютни пътища** — навсякъде `C:\Users\kaloyan.georgiev\Projects\...`:
- `ralph-iteration.ps1`: `$bdzProject` е фиксиран.
- `PROMPT.md` и `prerequisite-steps.md`: десетки абсолютни пътища.

**б) Project data, което живее ВЪН от ralph/** (PROMPT.md ги сочи):
```
Projects/Admin-App/docs/composition/PRD.json, designs/
Projects/railrun-backend-structure.md
Projects/admin-app-frontend-structure.md
Projects/railrun-database-guide.md
Projects/wagon-migrations/*.md
```
Тези BDZ-специфични референции са зашити в „универсалния" prompt.

**в) BDZ съдържание вътре в ralph/**, което няма нищо общо с машината:
```
rbac-spec.md, wagon-creation-spec.md, wagon-creation-gap-analysis.md,
wagon-implementation-plan.md, wagon-occupancy-report-spec.md, DOCS/,
feature-map.json + select-e2e.ps1 (специфични за Admin-App e2e структурата)
```

---

## 8. Инвентар: кой файл какъв е

| Файл / папка | Категория | Бележка |
|--------------|-----------|---------|
| ralph.ps1 | 🟢 Harness | Външен loop |
| ralph-iteration.ps1 | 🟢 Harness | Ядро: итерация + watchdog + quota + completion |
| ralph-config.json | 🟢 Harness | Частично ползван (виж т.5) |
| START-RALPH-TDD.bat | 🟢 Harness | Реален старт |
| ralph-quick.bat / ralph-with-config.bat | 🟢 Harness | Алтернативни стартове |
| ralph.bat / ralph.sh / ralph-bash.bat | 🔴 Legacy | Дубликати, за махане |
| completion-check.ps1 | 🔴 Мъртъв | Не се вика, грешен път |
| STRUCTURE.md | 🟡 Остаряла | Грешна карта |
| 🚀 СТАРТ ТУК.txt / КЛИКНИ ТУК.txt | 🟡 Остаряли | Onboarding от ранна версия |
| PROMPT.md | 🟠 Project data (harness-shaped) | Универсален prompt, но с BDZ пътища |
| prerequisite-steps.md | 🟠 Project data | repo-routing таблица с абс. пътища |
| user-steps.md | 🟠 Project data | BDZ TDD правила |
| feedback.md | 🟠 Project data (orphaned) | Не се inject-ва автоматично |
| tasks.json | 🟠 Project data | 252 таска, всички done |
| activity.md | 🟠 Project data | Дневник |
| feature-map.json + select-e2e.ps1 | 🟠 Project data | Admin-App e2e селекция |
| rbac-spec.md, wagon-*.md, DOCS/ | 🟠 Project data | BDZ спецификации |
| logs/ | ⚪ Runtime | Авто-генериран |
| working algorithm/ | 🔒 Бекъп | НЕ пипаме |

---

## Резюме за следващата стъпка

Реалната машина са **само 3 файла**: `ralph.ps1` + `ralph-iteration.ps1` + `ralph-config.json`. Всичко останало е или **project data**, или **legacy/мъртво**.

Идеята „в еди-коя стъпка отиваш в тази папка и четеш този файл" вече частично съществува чрез `repo` полето + prerequisite-steps.md таблицата — но е закотвена с абсолютни пътища и разбъркана с BDZ съдържанието. Чистата цел за стъпка 2:

- **`harness/`** — машината (path-agnostic, чете корен от config/env).
- **`project/`** (или отделно repo) — tasks.json, prompt-ове, spec-ове, feature-map.
- Един **`paths` блок в config** вместо hardcode → машината и prompt-ите четат оттам.
