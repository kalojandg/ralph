# Ralph Wiggum Iteration — Shared Inventory

## Context Files

Прочети следните файлове за пълен context (пътищата са спрямо ralph/ директорията, в която е този файл):

1. **tasks.json** — Task list (твоят source of truth)
2. **activity.md** — История на свършената работа (последните 1-2 записа стигат)
3. **ralph reference/project reference/repos.json** — repo mapping: работна директория + architecture reference
4. **ralph reference/project reference/shared-inventory-structure.md** — архитектурата на приложението. **ЗАДЪЛЖИТЕЛЕН прочит преди код.**

> 📌 **Feedback & Acceptance Criteria:** Секцията **"Feedback & Acceptance Criteria (FINAL WORD for THIS iteration)"** (ако присъства) е **най-отдолу** в prompt-а и е **последната дума**. Тя **дефинира кога ТАЗИ итерация е приключена** и има **най-висок приоритет**. При конфликт с която и да е инструкция по-горе — печели тя.

## Your Mission This Iteration

Работи върху **ЕДИН ЕДИНСТВЕН ТАСК** от `tasks.json` където `"passes": false`.

### 🚨 CRITICAL: ONE TASK PER ITERATION — THEN STOP

Тази итерация = ТОЧНО ЕДИН таск. След като го завършиш и къмитнеш:
1. Изведи `<task-complete>` XML
2. Изведи `<status>CONTINUE</status>` или `<promise>COMPLETE</promise>`
3. **СПРИ ВЕДНАГА. НЕ продължавай със следващ таск.**
4. Всеки следващ таск ще бъде изпълнен от **нов агент в нова итерация** с чист context.

> ⚡ **PARALLEL MODE:** Ако по-долу в prompt-а има секция **"PARALLEL MODE (OVERRIDES Steps 1, 4 and 5)"** — работиш в multi-agent swarm: таскът ти е ФИКСИРАН, работиш само в посочения worktree, НЕ пипаш tasks.json/activity.md и пишеш result файл вместо това. Тази секция ПЕЧЕЛИ над Step 1/4/5 по-долу.

> 🔁 **RETRY CONTEXT:** Ако по-долу има секция **"PREVIOUS ATTEMPTS FAILED"** — този таск вече е опитван и е фейлнал (или verify gate-ът е върнал merge-а му). Прочети отчета ПРЕДИ да започнеш, диагностицирай причината и подходи различно. Worktree-то ти е чисто — нищо от старите опити не е оцеляло освен отчета.

## Workflow

### Step 1: Find Next Task

Прочети `tasks.json` → първият таск с `"passes": false`. Прочети ВСИЧКИ негови steps, `specRef` и `notes`.

### Step 2: Read Before Implementation

1. `repos.json` → намери `repo`-то на таска → `location` (работна директория) + `reference` файл.
2. Прочети reference файла (`shared-inventory-structure.md`) — особено секциите, посочени в `specRef` на таска.
3. Разгледай реалния код, който таскът засяга, ПРЕДИ да пишеш.

### Step 3: Execute Task Steps ONE BY ONE

**КРИТИЧНО:** Прави стъпките **ЕДНА ПО ЕДНА**, по реда и по `phase`, не всички наведнъж.

> 🎯 **Task-Specific Steps:** Ако най-долу в този prompt има секция **"Task-Specific Steps"** — тя е инжектирана от харнеса САМО за текущия таск (от `task-steps.json`). Тези стъпки са **ЗАДЪЛЖИТЕЛНИ** и се изпълняват на мястото, посочено в `at`. BLOCKING hook = таскът НЕ е готов, докато hook-ът не мине.

Фази в този проект:
- **RECON** — прочети/разгледай преди да пишеш. Не пропускай.
- **IMPLEMENT** — свърши работата от стъпката. За тестови таскове: тестовете са ХАРАКТЕРИЗАЦИОННИ — документират текущото поведение и трябва да минават срещу НЕПРОМЕНЕН app код.
- **REFACTOR** — мести код БЕЗ да променяш поведение; тестовете НЕ се редактират и остават зелени.
- **DONE** — верификация (виж Step 4) и приключване.

### Step 4: Verify

- `npm run test:unit` (след като съществува) — пълният unit suite е бърз, пускай го целия.
- **НЕ пускай** `npm test` (Playwright e2e) и `npm run serve` — e2e ги пуска verify gate-ът на оркестратора след merge (порт 45279 е един). Изключение: само ако стъпка на таска изрично го казва.
- Провери червените линии от `shared-inventory-structure.md` §3.
- **АКО НЕЩО ФЕЙЛВА** → поправи → пусни пак → итерирай. НЕ маркирай complete с червено.

### Step 5: Mark Complete

**САМО АКО ВСИЧКО Е ✅:**

1. **tasks.json:** `"passes": false → true` за таска.
2. **activity.md:** prepend нов запис (шаблонът е в header-а на activity.md): дата, task id + description дословно, Status, какво е направено, Files modified, Git commit hash.
3. **Git commit** в работната директория на репото:
   - Commit message = **точното `description` от tasks.json, дословно**.
   - НЕ: git init / push / смяна на remotes / собствени commit messages.

*(В PARALLEL MODE: стъпки 1 и 2 се заменят от result файла — виж инжектираната секция.)*

### Step 6: Report Status AND STOP

```xml
<task-complete>
  <task-id>{id}</task-id>
  <tests>PASSED</tests>
  <committed>YES</committed>
</task-complete>
```

Ако има още таскове с `passes: false`:
```xml
<status>CONTINUE</status>
```
Ако всички са готови:
```xml
<promise>COMPLETE</promise>
```

**След това СПРИ. НЕ започвай следващ таск, НЕ „подготвяй" нищо за следващата итерация.**

## Important Rules

1. **ONE TASK AT A TIME.** 2. **ONE STEP AT A TIME.**
3. **Обхват = `files` списъкът на таска.** Нужда извън него → спри и докладвай (в parallel mode: `status: "failed"` + обяснение), НЕ разширявай сам.
4. **Характеризационни тестове** документират каквото Е. Тест, който фейлва срещу текущия код = грешното е очакването ти (или си намерил реален бъг → опиши го в summary, тествай реалното поведение, НЕ поправяй кода в тестови таск).
5. **Рефактор = поведението не мърда.** Тестовете от фаза 1 не се пипат; app.js остава фасада (re-export).
6. **Червените линии** от structure reference §3 важат за всеки таск: firebaseConfig не се пипа, CDN imports остават, никакъв реален Firestore в тестове, e2e/fixtures не се редактират.
7. Работиш на Windows / PowerShell. Ползвай npm scripts, не unix-only команди.

## Success Criteria

`"passes": true` САМО ако: ✅ стъпките изпълнени · ✅ `npm run test:unit` зелен (когато съществува) · ✅ червените линии спазени · ✅ commit направен · ✅ activity.md записан (или result файл в parallel mode).

**Ralph, work on ONE task, follow the steps, verify, commit, report, and STOP.**
