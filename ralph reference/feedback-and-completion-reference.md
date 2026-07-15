# Ralph Reference — Feedback loop и сигнализиране „край на итерация"

> Отговаря на два въпроса: **(1) как се сигнализира, че една итерация е завършена** и **(2) как работи feedback loop-ът**.
> Състоянието е снето от реалния код (`ralph-iteration.ps1`, `ralph.ps1`, `ralph-config.json`), не от намеренията в config-а.

---

## TL;DR

| Въпрос | Кратък отговор |
|--------|----------------|
| Как машината разбира, че агентът е **спрял да работи**? | Търси `"terminal_reason"` в stream-json output-а → прекъсва watchdog-а. |
| Как разбира, че **таск/всички таскове са готови**? | Брои `passes:true` в `tasks.json` → връща exit код. **НЕ** чете XML таговете. |
| Какво правят XML таговете (`<task-complete>`, `<promise>COMPLETE</promise>`)? | Само **self-report** на агента (инструктиран в PROMPT.md Step 5). Машината не ги парсва за control flow. |
| Има ли **feedback loop**? | ✅ **ДА, на ниво итерация.** `feedback.md` се инжектира в prompt-а на всяка итерация (ако има активен текст). Виж Част 2. |

---

## ЧАСТ 1 — Сигнализиране „край на итерация"

Има **три нива**, но само две от тях реално управляват потока.

### Ниво 1 — Self-report на агента (XML тагове) — само информативно

В края на работата PROMPT.md (Step 5) инструктира агента да изведе:
```xml
<task-complete>
  <task-id>{id}</task-id>
  <tests>PASSED</tests>
  <committed>YES</committed>
</task-complete>
```
после **едно** от:
```xml
<status>CONTINUE</status>   <!-- има още passes:false таскове -->
```
или
```xml
<promise>COMPLETE</promise> <!-- всички таскове готови -->
```

⚠️ **Машината НЕ разчита на тези тагове.** `ralph-iteration.ps1` не ги grep-ва за решение. Те са за човека, който чете лога. (`ralph-config.json` изброява `<promise>COMPLETE</promise>` в `completion_criteria.patterns`, но този блок е **мъртъв** — скриптът, който би го проверявал, `completion-check.ps1`, е изтрит.)

### Ниво 2 — „Агентът спря" → `terminal_reason` (реалният сигнал)

Харнесът пуска `claude -p ... --output-format stream-json`, който излива по едно NDJSON събитие на стъпка. Финалното събитие е `result` с поле `"terminal_reason"`.

Watchdog-ът в `ralph-iteration.ps1` (~ред 215) чете последните редове на output файла и:
```powershell
if ($tail -match '"terminal_reason"') { break }
```
→ това е **истинският сигнал**, че итерацията е приключила. Нужен е, защото фонов процес, оставен от агента (dev server / watch / vitest), може да държи stdout pipe-а отворен и PowerShell job-ът никога да не стане `Completed` — без този break loop-ът би висял до 60-мин stale timeout.

**Други изходи от watchdog-а:**
- Hard timeout 180 мин → exit 3
- Stale 60 мин без растеж на output → exit 3
- Открит `"hit your limit"` → изчаква reset → exit 2 (retry)

### Ниво 3 — „Готово ли е?" → броене на `tasks.json` → exit код

След като агентът спре, `ralph-iteration.ps1` (~ред 380+) брои:
```powershell
$done = (# tasks с passes:true),  $total = (# всички)
if ($done -eq $total -and $total -gt 0) { exit 0 }   # всичко готово
else { exit 1 }                                       # има още
```

**Exit кодове и реакция на външния loop (`ralph.ps1`):**

| Exit | Значение | `ralph.ps1` прави |
|------|----------|-------------------|
| **0** | Всички таскове passes:true | Спира — „All tasks complete" |
| **1** | Още има таскове / нормален край на итерация | `i++`, следваща итерация |
| **2** | Quota hit (вече изчакал reset) | retry **без** да хаби итерация |
| **3** | Timeout (агентът убит) | `i++`, пауза 5с, напред |
| **4** | Фатална billing/auth грешка („Credit balance is too low" — БЕЗ reset час, за разлика от quota) | **Спира целия loop** — човек оправя кредити/модел; в swarm: оркестраторът abort-ва run-а, таскът не се брои за failed |

### Пълен поток на края на итерация

```
Агент работи
  │
  ├─ извежда XML self-report (task-complete / status / promise)   ← Ниво 1 (само за човека)
  │
  ▼
stream-json емитва "terminal_reason"
  │
  ▼
watchdog break  ← Ниво 2 (реалният „агентът спря")
  │
  ├─ "hit your limit"? → изчакай reset → exit 2 (retry)
  ├─ timeout?          → exit 3 (advance)
  │
  ▼
брой passes в tasks.json  ← Ниво 3 („готово ли е?")
  │
  ├─ done == total → exit 0 (ЦЯЛ ЦИКЪЛ ГОТОВ)
  └─ else          → exit 1 (следваща итерация)
  │
  ▼
ralph.ps1 реагира на exit кода → пуска нов агент с чист context
```

> **Извод:** „Итерацията е завършена" = агентът е емитнал `terminal_reason` И машината е преброила tasks.json. „Цялата работа е завършена" = `done == total` → exit 0. Един таск на итерация (виж [[tasks-and-progress-reference]] §2.2).

### ⚡ SWARM режим — различно Ниво 3

В паралелен режим (`ralph-swarm.ps1`) Ниво 1 и 2 са същите, но Ниво 3 се сменя:
- Агентът НЕ брои tasks.json. Успех = написан валиден `results/task-<id>.json` → exit 0; липсва/невалиден → exit 1.
- **Оркестраторът** решава „готово ли е всичко": merge-ва branch-а, пуска **post-merge verify gate** (`verify` командите на репото върху integration branch-а; червено → merge-ът се връща + информиран retry), чак тогава маркира `passes:true` (single writer) и спира, когато няма pending таскове и няма работещи агенти. Т.е. `passes:true` в swarm = done И merged И **верифициран на integration branch-а**.
- Quota (exit 2) си остава в агентската обвивка — всеки агент сам изчаква reset-а; оркестраторът re-queue-ва.
- **Провалите се retry-ват bounded:** timeout (exit 3) → сляп re-queue с чист worktree (до `max_timeout_requeues`); истински провал → **информиран retry** — оркестраторът пише `retry/task-<id>.md` (причина + log tail) и следващият опит го получава в prompt-а през `-retryFile`. До `max_fail_retries`, после failed за сесията.
Виж [[parallel-swarm-reference]] §„Retry поведение" за пълния поток.

---

## ЧАСТ 2 — Feedback loop

### Текущо състояние: WIRE-НАТ на ниво итерация ✅

Feedback се инжектира в prompt-а на **ВСЯКА итерация** (не per-task). Реализация в `ralph-iteration.ps1` — **като ПОСЛЕДНА секция** (след PROMPT.md, prerequisite, user-steps И task-specific steps). Причина: **recency** — последната дума задава **acceptance criteria** (кога итерацията е приключена) и печели при конфликт.

**Механика:**
1. Чете `feedback.md` с `-Encoding UTF8`.
2. Маха HTML коментарите (`<!-- ... -->`) и trim-ва.
3. Ако е останал реален текст → добавя най-отдолу секция `--- Feedback & Acceptance Criteria (FINAL WORD for THIS iteration) ---` + ред „highest priority, defines when done" + текста.
4. Ако е празно (само коментар/whitespace) → **не инжектира нищо** (важат стандартните Success Criteria от PROMPT.md).

**Config (реално ползван):**
```json
"feedback": {
  "enabled": true,          // чете се — false спира инжектирането
  "feedback_file": "feedback.md"  // чете се — може да се смени файлът
}
```
(`append_after_iteration` не се чете — реалното поведение е „inject в началото на всяка итерация".)

**Ред на сглобяване на prompt-а сега:**
```
PROMPT.md
  + prerequisite-steps.md
  + user-steps.md
  + [task-specific hooks]   ← per-task, от task-steps.json
  + [PARALLEL MODE override] ← само в swarm режим
  + [PREVIOUS ATTEMPTS FAILED] ← само при retry: retry/task-<id>.md (причина + log tail
                                 на провалилите се опити; cap ~8000 знака, най-новото печели)
  + [Feedback & Acceptance Criteria]  ← ПОСЛЕДЕН, ако има активен текст (recency = финална дума)
```
`PROMPT.md` също уведомява агента, че тази секция е **последната дума** и дефинира кога итерацията е приключена.

### Как се ползва

**Ръчно (human-in-the-loop):** пишеш кратки насоки под коментара в `feedback.md` (напр. „dev server е на порт 3000, не 5173"). Всяка следваща итерация ги вижда, докато не ги изтриеш. Празен файл = нищо не се добавя.

**Feedback vs task-steps — кое кога:**
| | Feedback (`feedback.md`) | Task-steps (`task-steps.json`) |
|---|---|---|
| Обхват | цялата итерация / всички таскове | конкретен таск или стъпка |
| Живот | краткотраен, ръчно чистиш | траен, вързан към id |
| Кога | „внимавай за X сега" | „за таск 8: направи screenshot" |

### Възможно разширение — динамичен learning loop

Ако искаш агентът сам да пише feedback за следващата итерация (истински „learning loop"):
1. Инструкция в PROMPT.md Step 5: „допълни `feedback.md` с 1–3 реда за следващия агент".
2. Механиката за четене вече съществува (готово).
3. Добави ротация/лимит на размера, за да не набъбне.

Засега е **ръчен** iteration-level feedback — достатъчен за steering между итерации.
