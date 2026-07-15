# Activity Log

Наративен дневник на свършената работа. **Подредба: най-новият запис ОТГОРЕ** (prepend).
Агентът добавя по един запис на завършен таск (Step 4 от PROMPT.md). Пълна спецификация на формата:
`ralph reference/tasks-and-progress-reference.md` §2.3.

Шаблон на запис (копирай, попълни, сложи най-отгоре):

```markdown
## [YYYY-MM-DD HH:MM] - Task #<id>: <description дословно от tasks.json>

**Status:** ✅ Complete

**TDD Phase:** RECON → RED → GREEN → (VISUAL →) (REFACTOR →) DONE   ← само при tddWorkflow

**Problem:** <какъв е бил проблемът / контекст>   ← по избор

**What was done:**
- RED: <какъв failing тест е добавен, verify че fail-ва>
- GREEN: <минимална имплементация, verify че pass-ва>

**Verification:**
- <тест файл> → X/Y pass
- eslint → 0 errors | type-check → clean

**Files modified:**
- <path 1>
- <path 2>

**Git commit:** `<hash>` — `<commit message>`

---
```

<!-- Записите започват под тази линия — най-новият веднага след нея. -->

## [2026-07-15] - Task #2: refactor: extract inline module script from index.html into app.js verbatim with named exports

**Status:** ✅ Complete

**Problem:** Целият JS живееше inline в <script type="module"> блок в index.html (редове 166-599). Bootstrap таск за фаза 1 — тестовата инфраструктура (таск 3) import-ва app.js като модул.

**What was done:**
- Създаден app.js с ТОЧНОТО съдържание на module script блока (редове 167-598, без script таговете) — byte-identical извличане, верифицирано с cmp срещу оригиналния блок. firebaseConfig, коментарите и подредбата на регионите са verbatim.
- В края на app.js добавени САМО export статментите по спецификацията: export { spendGold, renderGold, coinInputs, clearCoinInputs, renderItems, renderQuests, saveItems, saveQuests, initSortable, esc, syncMsg, BADGE, NEXT_STATUS }; export const getState; export function setState.
- В index.html module script блокът е заменен с <script type="module" src="./app.js"></script>. Service worker inline classic скриптът и SortableJS <script src> тагът са непокътнати.

**Verification:**
- git diff на index.html: 1 insertion, 434 deletions — само замяната на блока със src reference
- cmp: първите 432 реда на app.js са byte-identical с оригиналния блок; node --check app.js → clean
- 18-те window.* assignments са на място (HTML onclick handler-ите разчитат на тях); CDN imports непроменени
- npm run test:unit не съществува още (преди таск 3) — стъпката се пропуска по правилата; e2e се пуска от verify gate-а

**Files modified:**
- index.html
- app.js (нов)

**Git commit:** `dd7e4f5` — `refactor: extract inline module script from index.html into app.js verbatim with named exports`

---


## [2026-07-15 18:04] - Task #1: refactor: extract inline CSS from index.html into styles.css

**Status:** ✅ Complete

**Problem:** Целият CSS живееше inline в <style> блок в <head> на index.html (редове 11-168). Механичен bootstrap таск, който валидира pipeline-а (worktree -> merge -> verify gate).

**What was done:**
- Създаден styles.css с ТОЧНОТО съдържание на <style> блока (без <style> таговете), без промени/преформатиране — byte-identical извличане, верифицирано програмно срещу git HEAD версията.
- В index.html целият <style>...</style> блок е заменен с `<link rel="stylesheet" href="./styles.css">`. Нищо друго в index.html не е пипано.

**Verification:**
- git diff на index.html: само изваждането на блока + 1 добавен link ред (1 insertion, 158 deletions)
- Няма останали <style> тагове в index.html; styles.css съдържа всички правила verbatim
- npm run test:unit не съществува още (преди таск 3) — стъпката се пропуска по правилата; e2e се пуска от verify gate-а

**Files modified:**
- index.html
- styles.css (нов)

**Git commit:** `806dadb` — `refactor: extract inline CSS from index.html into styles.css`

---



