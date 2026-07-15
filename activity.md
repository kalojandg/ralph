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

## Task #24 — refactor: extract quests logic into modules/quests.js

**Date:** 2026-07-15
**Status:** ✅ Done

**What was done:**
- Created `modules/quests.js` with verbatim-moved `BADGE`, `NEXT_STATUS`, `renderQuests`, `saveQuests` and the bodies of `openQuestModal`, `closeQuestModal`, `editQuest`, `saveQuest`, `cycleStatus`, `deleteQuest` as exported functions. Imports `state` from `./state.js`, `QUESTS_DOC`/`setDoc` from `./firebase.js`, and `esc`/`syncMsg`/`initSortable` from `./ui.js` (mirrors `modules/items.js`).
- `app.js`: added the `./modules/quests.js` import, replaced the entire QUESTS region with `window.*` wiring (`openQuestModal`/`closeQuestModal`/`editQuest`/`saveQuest`/`cycleStatus`/`deleteQuest`), and re-exports `BADGE`/`NEXT_STATUS`/`renderQuests`/`saveQuests` from the module (facade). The `onSnapshot(QUESTS_DOC)` listener still calls the imported `renderQuests`.
- No behavior change; tests were not edited.

**Verification:** `npm run test:unit` → 6 files, 75 tests passed. `git diff` scoped to `app.js` + new `modules/quests.js` only (index.html, test/**, firebaseConfig untouched).

**Files modified:** `app.js`, `modules/quests.js` (new)

**Git commit:** `1893673b793c67dd9385e531222e36bcfd3cd511`


## Task 23 — refactor: extract leaf ui helpers and inventory items logic into modules/ui.js and modules/items.js

**Date:** 2026-07-15
**Status:** ✅ Done

**What was done:**
- Created `modules/ui.js` with verbatim `esc`, `syncMsg`, `initSortable` (no dependencies on items/quests, so the potential import cycle is broken first).
- Created `modules/items.js` with `renderItems`, `saveItems`, and the bodies of `openItemModal`/`closeItemModal`/`editItem`/`saveItem`/`deleteItem` as named exports; imports from `./state.js`, `./firebase.js`, `./ui.js`.
- `app.js`: imports from both new modules, keeps `window.*` wiring (`openItemModal`, `closeItemModal`, `editItem`, `saveItem`, `deleteItem`) and the `PLAYERS` → `#iCarrier` populate; renderQuests/handlers still use `esc`/`syncMsg`/`initSortable` via the ui.js import. Facade re-exports updated: `esc, syncMsg, initSortable` from ui.js and `renderItems, saveItems` from items.js.
- Behaviour unchanged; characterization tests not edited.

**Verification:** `npm run test:unit` → 6 files, 75 tests passed. Only `app.js` modified; `modules/ui.js` and `modules/items.js` added; no test/index.html/firebaseConfig changes.

**Files modified:** app.js, modules/ui.js (new), modules/items.js (new)

**Git commit:** ffbc5b5


## Task 22 — refactor: extract pure gold logic into modules/gold.js

**Date:** 2026-07-15
**Status:** ✅ Done

**What was done:**
- Created `modules/gold.js` holding the pure gold logic moved verbatim: `spendGold` (borrow-down), `renderGold`, `coinInputs`, `clearCoinInputs`. `renderGold` reads `state.gold` via `import { state } from './state.js'`.
- `app.js`: removed the four inline function definitions, added `import { spendGold, renderGold, coinInputs, clearCoinInputs } from './modules/gold.js'`. `handleGain`/`handleSpend` remain in `app.js` (they still depend on `syncMsg`, moved only in task 23) and now use the imported gold helpers.
- Facade preserved: bottom re-export now does `export { spendGold, renderGold, coinInputs, clearCoinInputs } from './modules/gold.js'` alongside the remaining `export { renderItems, ... }`.
- No import cycle: gold.js depends only on state.js; app.js depends on gold.js.

**Verification:** `npm run test:unit` → 6 files, 75 tests passed. Tests not edited; `index.html` untouched; CDN imports and firebaseConfig unchanged.

**Files modified:** `app.js`, `modules/gold.js` (new)

**Git commit:** 7562863


## [2026-07-15 19:13] - Task #21: refactor: extract mutable app state into modules/state.js

**Status:** ✅ Complete

**TDD Phase:** RECON → REFACTOR → DONE

**Problem:** The mutable app state lived as bare module-level `let` variables in app.js; the refactor lane needs it in a shared `modules/state.js` so later modules (gold/items/quests/ui) can read/write a single state object.

**What was done:**
- Created `modules/state.js` exporting `const state = { gold: {pp:0,gp:0,sp:0,cp:0}, items: [], quests: [], editingItemIdx: null, editingQuestIdx: null, expandedItemIdx: null, expandedQuestIdx: null, saving: false, savingQuests: false }`.
- In app.js: removed the 9 `let` declarations, added `import { state } from './modules/state.js'`, and mechanically redirected EVERY read/write to `state.x` — renderGold, handleGain/handleSpend, renderItems + item modal/save/delete/saveItems (incl. `saving` flag), renderQuests + quest modal/save/cycle/delete/saveQuests (incl. `savingQuests` flag), the accordion `expanded*Idx` logic, the 3 onSnapshot callbacks (incl. the echo-guard `if (state.saving)` / `if (state.savingQuests)`), exportData bundle.
- `getState`/`setState` keep their exact previous signatures, now delegating to the state object: `getState()` returns `{gold: state.gold, items: state.items, quests: state.quests}`; `setState` writes into `state.*`.
- Verbatim move — no logic changed. app.js stays the facade re-exporting everything it exported before.

**Verification:**
- `npm run test:unit` → 6 files / 75 tests passed, no test edits.
- `git diff --stat` → only app.js changed + new modules/state.js; index.html and test/ untouched.

**Files modified:**
- `app.js`
- `modules/state.js` (new)

**Git commit:** `3f4784be26f9846738f85abfbc78ac88b3769b02` — `refactor: extract mutable app state into modules/state.js`

---


## Task 20 — refactor: extract firebase init and doc refs into modules/firebase.js

- **Date:** 2026-07-15
- **Task:** #20 refactor: extract firebase init and doc refs into modules/firebase.js
- **Status:** DONE ✅
- **What was done:**
  - Created `modules/firebase.js` holding the CONFIG (`firebaseConfig` verbatim) and INIT regions (`initializeApp`/`getFirestore` → `db`, and `GOLD_DOC`/`ITEMS_DOC`/`QUESTS_DOC`). It keeps the CDN import URLs byte-for-byte identical and re-exports `db`, the three doc refs, and the firestore functions `doc, collection, onSnapshot, setDoc, updateDoc, deleteDoc, getDoc`.
  - `app.js`: replaced the CONFIG/INIT region + CDN imports with `import { db, GOLD_DOC, ITEMS_DOC, QUESTS_DOC, doc, collection, onSnapshot, setDoc, updateDoc, deleteDoc, getDoc } from './modules/firebase.js';`. `PLAYERS` remains in app.js. No behavior changed; app.js stays the facade re-exporting everything it exported before.
  - Vitest alias continues to intercept the CDN imports through `modules/firebase.js` (URLs unchanged).
- **Verification:** `npm run test:unit` → 6 files / 75 tests passed, no test edits. `git diff` clean outside app.js + new modules/. index.html not touched.
- **Files modified:** `app.js`, `modules/firebase.js` (new)
- **Git commit:** 720be854fd869f31c840a377765d5c9417ac8562


### Task 14 — test: characterization tests for tabs, modals, esc helper and sortable wiring

- **Date:** 2026-07-15
- **Status:** DONE
- **What was done:** Created `test/unit/ui.spec.js` with characterization tests (§2 DND/TABS/MODALS/HELPERS, §6) covering the current, unmodified app.js behaviour:
  - **Tabs:** clicking `data-tab="quests"` marks that button `.active`, deactivates the inventory button, activates `#tab-quests` and deactivates `#tab-inventory`; clicking back restores inventory.
  - **Modals:** `openItemModal()`/`openQuestModal()` add `.open` and reset every field to its §2 default (iCat→Разно, iQty→1, iWeight/iValue→0, iCarrier→Party, qStatus→Активен, text fields empty); clicking the backdrop (`e.target === modal`) closes, clicking inside `.modal-card` does not.
  - **esc():** escapes `&`,`<`,`>`,`"` (with `&` first so no double-escape), leaves other characters and single quotes untouched, and casts non-string input via `String()` (42→'42', null→'null', etc.).
  - **initSortable:** a repeated call destroys the previous Sortable instance (verified with a counting stub swapped in after boot); the stub-retained `opts.onEnd({oldIndex,newIndex})` reorders the backing array and calls `saveFn`, producing a `setDoc('inventory/items', {list})` recorded in `fs.calls`.
- **Verification:** `npm run test:unit` → 63 passed across 5 files; `git diff` shows app.js and all non-test files untouched.
- **Files modified:** `test/unit/ui.spec.js` (new).
- **Git commit:** `825947adbc8f7db32702f77e9116980457f85452`


### 2026-07-15 — Task #13: test: characterization tests for firestore snapshots, export bundle and import flow

**Status:** ✅ Done

**What was done:**
- Created `test/unit/sync.spec.js` with characterization tests for the LISTENERS and EXPORT/IMPORT regions of `app.js` (§2, §4, §5, §6), documenting current behaviour against an unmodified `app.js`.
- Snapshots (driven via mock `__emit`): `inventory/gold` null → all coins show 0; gold data → `renderGold` displays values; `inventory/items`/`quests/items` null → empty-state rows; `quests/items` emit → `#syncStatus` becomes 'Live sync ✓' and `window.__appReady === true`.
- `exportData`: stubbed `URL.createObjectURL`/`revokeObjectURL` and `HTMLAnchorElement.prototype.click`, captured the Blob, asserted bundle `{version:1, exportedAt ISO string, gold, items, quests}` and download filename starts with `shared-inventory-`.
- `importData`: valid bundle + confirm=true → `setDoc` for `inventory/gold`, `inventory/items` ({list}), `quests/items` ({list}); items-only bundle → exactly one setDoc; confirm=false → zero setDoc; invalid JSON → `alert` + zero setDoc; file input `value` cleared after each attempt.

**Verification:** `npm run test:unit` → 3 files, 30 tests, all green. `app.js` untouched (git diff clean outside the new spec). Red lines respected — mocks only, no real Firestore, CDN imports intact, e2e/fixtures untouched.

**Files modified:**
- `test/unit/sync.spec.js` (new)

**Git commit:** `c896c7f0eb7bcda172f6b199cb7449a5023f0ac6`


## Task #10 — test: characterization tests for gold treasury (spendGold borrow-down, gain/spend handlers, input clamping)

**Date:** 2026-07-15
**Status:** DONE

**What was done:**
- Created `test/unit/gold.spec.js` characterizing the GOLD region of `app.js` against the unchanged production code, consuming `bootApp()` (§6) and the firestore mock's `fs.calls`.
- `spendGold` pure-function tests: exact spend without borrow; single borrows cp←sp, sp←gp, gp←pp; chained borrow (1cp paid from 1pp → {pp:0,gp:9,sp:9,cp:9}); shortfall → null; floor affordability guard (10.9→affordable, 11→null); zero cost (unchanged); missing cost fields default to 0.
- DOM tests via `bootApp({gold})`: `renderGold` fills #dispPP/GP/SP/CP; `coinInputs` clamps negatives→0, floors floats, empty→0; `window.handleGain` sums inputs, clears them, writes setDoc('inventory/gold', sum); `window.handleSpend` writes borrow-down result & keeps #goldError hidden on success, adds 'visible' + no setDoc + gold unchanged on shortfall, and clears 'visible' on a later successful spend.

**Files modified:**
- `test/unit/gold.spec.js` (new)

**Verification:** `npm run test:unit` → 2 files, 18 tests passed (3 smoke + 15 gold). `git diff` clean outside the new test file; `app.js` untouched.

**Git commit:** 3091c77


### 2026-07-15 — Task #12: test: characterization tests for quests (render, status badges, cycleStatus, save/edit/delete, accordion)

**Status:** ✅ Done

**What was done:**
- Created `test/unit/quests.spec.js` with 18 characterization tests over the QUESTS region of app.js (§2 QUESTS, §4, §6), consuming the existing `bootApp()` helper and `fs.calls`/`fs.__emit` from the firestore mock.
- Coverage: renderQuests empty-state; name/giver/reward rendering with `—` fallback; description shown only when present; BADGE class per status (active/done/failed/paused); `esc()` escaping of quest name; direct-import assertion of the `NEXT_STATUS` map; `cycleStatus` status advance + unshift-to-top + setDoc `quests/items`; `saveQuest` new/edit/empty-name; `deleteQuest` confirm true/false; `savingQuests` in-flight echo guard (ignored snapshot); accordion single-expand, drag-handle no-toggle, and expanded-state survival across re-render.
- app.js NOT modified — tests pass against unchanged production code.

**Files modified:**
- `test/unit/quests.spec.js` (new)

**Verification:** `npm run test:unit` → 2 files, 21 tests passed (18 new + 3 smoke). git diff clean outside the new test file.

**Git commit:** `4a3705b`


## Task #11 — test: characterization tests for inventory items (render, totals, escaping, save/edit/delete, accordion)

**Date:** 2026-07-15
**Status:** ✅ Done

**What was done:**
- Created `test/unit/items.spec.js` with characterization tests documenting the CURRENT behaviour of the ITEMS region in `app.js` (run against unmodified app code).
- Coverage:
  - **renderItems:** empty list → empty-state row + blank `#invFooter`; populated row shows name/qty/weight/value/carrier; carrier defaults to `Party` when missing; footer = Σ weight*qty `toFixed(1)` lb | Σ value*qty `toFixed(2)` gp; `esc()` escapes `<script>`/quotes so no raw tag is injected.
  - **saveItem (via DOM modal):** new item unshifted to top + `setDoc('inventory/items', {list})`; empty/whitespace name → no write, no change; edit (`openItemModal(idx)` + `saveItem`) removes old entry and moves edited item to top.
  - **deleteItem:** `confirm=true` removes item + writes; `confirm=false` leaves state and calls untouched.
  - **Echo guard (§4):** a `inventory/items` snapshot emitted while `saveItems()` is in-flight (`saving` flag) is ignored — local state keeps `['A']` instead of `HACKED`.
  - **Accordion:** row click toggles `item-expanded`; second click removes it; expanding another row leaves only that one expanded; clicking `.drag-handle` does not toggle; expanded state survives a `renderItems()` re-render.
- Used `bootApp()` from `test/helpers/dom.js` and `fs.calls` for Firestore assertions; `window.confirm` stubbed per-test for delete scenarios.

**Verification:** `npm run test:unit` → 2 files, 18 tests passed (3 smoke + 15 new). app.js and all non-test files untouched (`git status` shows only the new spec).

**Files modified:**
- `test/unit/items.spec.js` (new)

**Git commit:** `7fc74e25b21e6ae8be1748f7d43f770ea519963a`


## Task #3 — chore: add vitest unit test infrastructure with firebase CDN mocks and bootApp helper

**Date:** 2026-07-15
**Status:** DONE ✅
**Commit:** 45c745e

**What was done:**
- `package.json`: added `"test:unit": "vitest run"` (existing scripts untouched) + `vitest`/`jsdom` devDeps.
- `vitest.config.js`: `environment: 'jsdom'`, `include: ['test/unit/**/*.spec.js']`, `resolve.alias` mapping the two Firebase CDN URLs → `./test/mocks/firebase-app.js` and `./test/mocks/firebase-firestore.js` (app.js CDN imports stay byte-identical, intercepted via alias per §5).
- `test/mocks/firebase-app.js`: `initializeApp(cfg) → { cfg }`.
- `test/mocks/firebase-firestore.js` (§5 contract): `doc()` → `${col}/${id}` string token; `calls = {setDoc,updateDoc,deleteDoc}`; `onSnapshot` registers cb + returns unsubscribe; `__emit(token,data)` fires cbs with `{exists,data}`; `__reset()` clears calls+listeners; also exports `collection` (app.js imports it, else the ES named import throws) and `getFirestore/getDoc`.
- `test/helpers/dom.js` (§6 `bootApp`): loads index.html `<body>` sans `<script>` tags into `document.body.innerHTML`, stubs `Sortable`/`confirm`/`alert`, `vi.resetModules()` then imports the firestore mock **before** app.js so both share one module instance (shared listeners), imports app.js (top-level runs), `__emit`s the three docs (`inventory/gold`, `inventory/items`, `quests/items`), returns `{ fs }`.
- `test/unit/smoke.spec.js`: (a) empty boot → `#dispGP` = '0' + both tables show empty-state text; (b) one item → row with 'Меч'; (c) app.js exports `spendGold`/`getState`/`setState`.

**Root cause of prior failures & fix:** The post-merge verify gate's 16 uniform e2e failures were an infrastructure failure, not real assertion failures — `npm ci` rejected the committed lockfile (`Missing: @emnapi/core / @emnapi/runtime from lock file`), a known npm optional-deps lockfile bug (still present in npm 11.6.2). With `npm ci` failing, Playwright + http-server never installed, so every e2e test errored. Reproduced it locally (`npm install` then `npm ci` → EUSAGE), then fixed by deleting node_modules + package-lock.json and running a fresh `npm install` (which records the emnapi packages as proper lockfile entries), and — the step prior attempts skipped or didn't hold — verified with the gate's exact `npm ci --no-audit --no-fund` (exit 0, repeatably, and after a clean install) BEFORE committing.

**Files modified:** package.json, package-lock.json, vitest.config.js, test/mocks/firebase-app.js, test/mocks/firebase-firestore.js, test/helpers/dom.js, test/unit/smoke.spec.js

**Verification:** `npm run test:unit` → 3/3 green (also green after a fresh `npm ci`) · `npm ci --no-audit --no-fund` → exit 0 · app.js/index.html untouched (`git diff` clean) · node_modules/.cache gitignored · firebaseConfig/CDN imports untouched · no real Firestore.

**Git commit hash:** 45c745e


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














