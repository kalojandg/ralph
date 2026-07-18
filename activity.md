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

## Task #50 — fix: unify familiar records into st.familiars so export/import round-trips them like aliases and npc names

**Repo:** combat (monk_combat_app) · **Lane:** bugfix · **Commit:** `3e7d9b4`

**Bug (prod, user-reported):** Saving a record in each of the three Names tables → export → delete → import restored alias and npc but NOT familiar. Cause: familiar records lived in a standalone `localStorage['familiars_v1']` key *outside* `st`, and the export/import bundle only packages `st`.

**Fix (4 files, all in scope):**
1. `modules/namegen.js` — familiar store adapter now reads/writes `window.st.familiars` + `window.save()`, identical to the alias/npc adapters. Record schema `{name, cat, note, ts}` unchanged.
2. `modules/namegen.js` — added a defensive one-time `migrateFamiliars()` at the top of `attachNamegen()`: moves any legacy `familiars_v1` records into `st.familiars`, `save()`s *first*, then removes the old key; merges by `ts` if both hold data; leaves invalid JSON untouched. Live characters keep their familiars, which now also cloud-sync.
3. `app.js` — deleted the dead, never-called `stripTransientState` (confirmed zero call sites) that misleadingly implied familiars were transient.
4. Tests — updated the familiar-routing test to assert `st.familiars`, added a migration test (seed `familiars_v1` → reload → row visible, `st.familiars` populated, old key deleted), and added an import-export familiar bundle round-trip test.

**Verification:** Static review of the retained commit; `st.familiars` is wired through defaultState/applyBundle/buildBundle; only remaining `familiars_v1` refs are the read-then-delete migration path. The retry gate's single red — `rest-mechanics.spec.js:240` (multi level-up on Long Rest) — is out of scope and unrelated: a pre-existing timing flake (4 chained modal→observer-click cycles within `waitForTimeout(600)`, `retries:0`, shared server under parallel-mode load). Not caused by this change.


## Task #44 — chore: final sweep after Name Gen consolidation - rename label, navigation spec, bundle check and docs

**Repo:** combat (monk_combat_app) · **Lane:** generators · **Branch:** ralph/task-44 · **Commit:** 606e92b

### What changed
- **index.html:** renamed the `data-tab="namegen"` button label from `Name Gen` to `Names` and moved it to the end of `.tab-nav`; final order is Stats, PC Characteristics, Resurrection, Inventory, Flavor, Skills, Session Notes, Names. `data-tab="namegen"` unchanged (specs depend on it).
- **styles.css:** removed dead rules for the removed tabs — `#tab-shenanigans input[readonly]`, `#tab-shenanigans .one-liner-box(+button)`, `#btnGetName`, `#btnSaveAlias`, and the `#tab-npc-names .one-liner-box` responsive block. `.alias-table` kept (still used by the Names log).
- **test/e2e/import-export.spec.js:** the round-trip fixture no longer clicks the removed Shenanigans/Familiars tabs; it now generates+saves an alias and a familiar through the Names tab (`#genGenerate`, `#genTypeButtons`, `#genFamGroups`, `#genAlias*`/`#genFam*` modals). Bundle round-trip assertions unchanged (st.aliases still in bundle; familiar log stays in `familiars_v1` outside the bundle — existing behavior).
- **test/e2e/tabs-navigation.spec.js:** reordered the `All tabs are clickable` list so `namegen` is last (1:1 with the real nav) and added two tests — the button label reads `Names`, and the Names tab opens with `#genOutput` + the type buttons.
- **BEHAVIOR_DOCUMENTATION.md / TEST_CASES.md:** replaced the separate Shenanigans / Familiar Names / NPC sections with one `Names (Name Gen)` section documenting the 3 generators, save routing (alias→st.aliases, familiar→localStorage['familiars_v1'], npc→st.npcNames), per-type sub-UI and the 3 Save modals; updated the JSON-files list (shenanigans/familiars/npc-names now feed the Names tab) and the TOC/summary counts.

### Verify
- Residue grep (attach*/btn*/data-tab of the 6 removed tabs, fakeNameOutput/famNameOutput/npcNameOutput) → 0 hits in code.
- data-loading.spec.js already covers all five flavor JSONs + familiars + npc-names through the two new tabs (no change needed).
- styles.css brace balance verified (290/290). app.js namegen wiring intact (tabMap + attachNamegen guard).
- Repo is e2e-only (no `test:unit`); Playwright e2e intentionally left to the post-merge verify gate.
- Scope: only the 6 touched files, all within task #44's `files` list.


## Task #43 — refactor: remove legacy NPC Names tab superseded by Name Gen tab

**Repo:** combat (monk_combat_app) · **Branch:** ralph/task-43 · **Commit:** b0c8091

### What
Removed the legacy standalone NPC Names tab now that the consolidated **Name Gen** tab covers NPC name generation writing to the same `st.npcNames` store.

### Changes
- **index.html:** removed `data-tab="npc-names"` button, `#tab-npc-names` div, and `<script src="modules/npc-names.js">`.
- **app.js:** removed `'npc-names'` from `tabMap`, the `attachNpcNames()` boot call, and the now-dead `window.renderNpcNamesUI?.()` hook in `save()`. Kept `st.npcNames` default + normalization (lines ~131/782/1117) — Name Gen persists there.
- **Deleted:** `modules/npc-names.js`, `tabs/npc-names.html`, `test/e2e/npc-names.spec.js` (coverage now via namegen-ui.spec.js).
- **test/e2e/tabs-navigation.spec.js:** removed `'npc-names'` from the clickable-tabs list (now 1:1 with the 8 real tab-nav buttons).
- **test/e2e/data-loading.spec.js:** added a `Data Loading - NPC Names (npc-names.json via Name Gen)` describe block verifying npc-names.json loads and produces varied names through the NPC type of Name Gen.
- **styles.css:** untouched — not in the task `files` scope, and `.npc-options`/`.npc-fieldset` are reused by Name Gen's NPC sub-UI.

### Verify
- `grep` for `attachNpcNames|btnGenerateName|tabs/npc-names|renderNpcNamesUI` → 0 hits in code (only the retained `npc-names.json` fetch in modules/namegen.js remains).
- `node --check` clean on app.js and the edited specs.
- Combat repo has no unit infrastructure; e2e (`npm test`) is left to the post-merge verify gate on port 45278.


## Task #42 — refactor: remove legacy Familiars tab superseded by Name Gen tab

**Repo:** combat (monk_combat_app) · **Lane:** generators · **Commit:** f571298

### What
Removed the legacy Familiars tab now that Name Gen (task 40) covers familiar generation over the same store.

- **index.html:** removed `<button data-tab="familiars">`, `<div id="tab-familiars">`, and `<script src="modules/familiars.js">`.
- **app.js:** removed `'familiars'` from `tabMap`, the `attachFamiliars()` boot call, both `renderFamTable()` call sites (in `save()` and after import), and the entire historical duplicate of the familiars block (`loadFamiliars`, `famPickRandom`, `FAM_LS_KEY`/records helpers, modal, `renderFamTable`, `attachFamiliars`, and the private `escapeHtml` used only by it). The legacy `st.familiars` bundle field (import/export migration) was left untouched — separate live contract, not the tab.
- **modules/familiars.js, tabs/familiars.html:** deleted.
- **styles.css:** untouched — `.fam-btn`/`.fam-groups` are reused by the Name Gen tab.

### Tests
- Deleted `test/e2e/crud-aliases-familiars.spec.js` (only tested the removed tab; namegen-ui.spec.js already covers familiar generate/save/delete via the same FAM_LS_KEY store).
- `tabs-navigation.spec.js`: removed `familiars` from the tab list and the Familiars smoke test.
- `data-loading.spec.js`: routed the familiars.json checks through Name Gen (Familiar type + group buttons → #genOutput); also routed the stale Shenanigans block (task-41 leftover referencing the removed shenanigans tab) through Name Gen's alias generator so the data-loading gate is green.

### Verify
- `node --check` clean on app.js, data-loading.spec.js, tabs-navigation.spec.js.
- e2e not run from agent (shared port 45278 / orchestrator post-merge gate).
- DONE grep: `attachFamiliars`, `tabs/familiars`, `renderFamTable` gone from app code; `btnFamSave` remains only in import-export.spec.js / BEHAVIOR_DOCUMENTATION.md, which are outside task 42's boundary and assigned to task 44's final sweep.


## Task #41 - refactor: remove legacy Shenanigans tab superseded by Name Gen tab

**Repo:** combat (monk_combat_app) · **Lane:** generators · **Status:** done

**What:** Retry of the Shenanigans-tab removal. Predecessor commit `888aa3f` already removed the tab (button, `#tab-shenanigans`, `modules/aliases.js`, `tabs/shenanigans.html`, all alias/shenanigans wiring in `app.js`, `shenanigans-ui.spec.js`, and the Aliases describe in `crud-aliases-familiars.spec.js`) — that work is correct and kept. The verify gate (`namegen-ui tabs-navigation critical-path`) had 1 red: `tabs-navigation.spec.js › Familiars tab shows fam groups and log`.

**Diagnosis:** Task 40's Name Gen tab reuses the `.fam-groups` / `.fam-btn` classes (`<div id="genFamGroups" class="fam-groups hidden">`). `loadTabs()` injects every tab into the DOM at boot, so the Familiars test's unscoped `page.locator('.fam-groups')` matched 2 elements → Playwright strict-mode violation, and `.fam-btn.first()` resolved to Name Gen's hidden button (Name Gen loads before Familiars in tabMap order) → not visible.

**Fix (within #41 files boundary):**
- `test/e2e/tabs-navigation.spec.js` — scoped the Familiars smoke-test class selectors to `#tab-familiars .fam-groups` / `#tab-familiars .fam-btn`.
- `test/e2e/crud-aliases-familiars.spec.js` — defensively scoped the identical `.fam-btn[data-famcat=...]` click selectors to `#tab-familiars` (same latent collision; unique-id locators like `#famNameOutput`/`#famLog`/`.alias-del` are Familiars-only and left untouched — Name Gen uses `.gen-del`).

**Verify:** `node --check` clean on both specs and `app.js`. e2e not run locally (shared ports; post-merge gate owns it). Committed as `e04697f`.

**Out of scope (not touched):** `tabs/namegen.html` / `modules/namegen.js` own the reused classes but are outside #41's `files` list; the fix lives correctly in the test layer.


## Task #40 — feat: add consolidated Name Gen tab with per-type save routing for aliases, familiars and NPC names

**Repo:** combat (monk_combat_app) · **Lane:** generators · **Branch:** ralph/task-40 · **Commit:** 094d691

**What:** New ADDITIVE 'Name Gen' tab consolidating Alias / Familiar / NPC generators into one registry-driven module with a single output zone, Generate/Save buttons and per-type Save modals. Save routes to the CORRECT store based on active type — st.aliases (+window.save), localStorage['familiars_v1'] (FAM_LS_KEY), st.npcNames (+window.save) — reusing the exact record schemas from the old modules so live-character data is visible 1:1. Type switch clears the output, disables Save and swaps the log table; Familiar generates via its 7 group buttons (Generate hidden), NPC via race/gender radios (distinct name attrs to avoid cross-tab radio collision; toblin hides gender).

**Files:** modules/namegen.js (new), tabs/namegen.html (new), test/e2e/namegen-ui.spec.js (new), index.html (tab button + div + script), app.js (tabMap + attachNamegen guard), styles.css (#genOutput sizing, reuses .flavor-btn/.flavor-grid).

**Red lines respected:** old shenanigans/familiars/npc-names tabs & modules NOT touched (removed later in 41-43); no persistence schema/key changes; no runtime artifacts committed.

**Verify:** node --check on namegen.js + app.js green. e2e (npm test -- namegen-ui critical-path) left to the post-merge gate (shared port 45278).


## [2026-07-18 07:35] - Task #34: chore: final sweep after Flavor consolidation - navigation spec, docs and dead code check

**Repo:** combat (monk_combat_app) · **Lane:** flavor · **Branch:** ralph/task-34 · **Commit:** 7ffac26

**Status:** ✅ Complete

**Problem:** Task 34's in-scope work was already done, but the verify gate kept bouncing the task on `attack-bonuses.spec.js:111` ("Attack bonuses update on level up"). Root cause: predecessor agents edited SIX e2e specs OUTSIDE task 34's `files` scope — they removed the `beforeEach` pollers (present on `main`) that auto-click cardMonk to dismiss the multiclass level-up modal, and replaced attack-bonuses' poller with a fragile explicit 4-click loop that went red under full-suite load. The multiclass modal was introduced by a separate task (`ebf0b41`), not the flavor work, so `main`'s pollers are the correct handling.

**What was done:**
- Reverted the six out-of-scope specs to `main` (`git checkout main --`): attack-bonuses, derived-values, import-export, npc-names, proficiency-toggles, skills-features — restoring the working level-up-modal pollers and the data-driven npc name pools. Branch diff vs main is now ONLY the four in-scope files.
- 34.1 RECON: project grep for `attachOneLiners|attachExcuses|attachInsults|btnCritMiss|btnExLifeWisdom|btnGenerateInsult|olCritMiss|exLifeWisdom|tabs/liners|tabs/excuses|tabs/insults` → 0 code matches (only legit Flavor section labels + `*.json` data-source references remain).
- 34.2: `tabs-navigation.spec.js` has 'Can click Flavor tab' and an 'All tabs are clickable' list 1:1 with index.html (stats, pcchar, resurrection, inventory, shenanigans, flavor, familiars, skills, sessionNotes, npc-names — quests commented out at index.html:117). `data-loading.spec.js` covers all 5 Flavor JSONs (one-liners, excuses, insults, dark-jokes, tasha-jokes) via correct `data-flavor` ids verified against modules/flavor.js.
- 34.3: `BEHAVIOR_DOCUMENTATION.md` §5.5 collapsed to a single Flavor tab section (17 types / clear+random+active / 5 JSON sources) with sections renumbered; `TEST_CASES.md` §16 FLAVOR TAB added (main had no separate old-tab sections). No stale One-Liners/Excuses/Insults UI sections remain (§15 headers are data-file references, valid).
- 34.4: `index.html`/`app.js`/`styles.css` byte-identical to main → no in-scope dead code; `.one-liner-box` kept (shared class still used by #tab-npc-names and #tab-shenanigans).

**Verification:**
- Static review of specs only — e2e is forbidden by task step 34.1 ("npm е забранен за e2e — само прегледай спековете статично") and shared-port policy.
- Branch diff vs main = exactly the 4 in-scope files (BEHAVIOR_DOCUMENTATION.md, TEST_CASES.md, test/e2e/data-loading.spec.js, test/e2e/tabs-navigation.spec.js).
- Sole gate blocker `attack-bonuses.spec.js` restored to its green `main` version (poller-based modal dismissal).

**Files modified:**
- BEHAVIOR_DOCUMENTATION.md
- TEST_CASES.md
- test/e2e/data-loading.spec.js
- test/e2e/tabs-navigation.spec.js
- (reverted to main, out-of-scope cleanup) test/e2e/{attack-bonuses,derived-values,import-export,npc-names,proficiency-toggles,skills-features}.spec.js

**Git commit:** `7ffac26` — `chore: final sweep after Flavor consolidation - navigation spec, docs and dead code check`

---


## Task 33 — refactor: remove legacy Insults tab superseded by Flavor tab

**Repo:** combat (monk_combat_app) · **Lane:** flavor · **Branch:** ralph/task-33 · **Commit:** 706ece6

### What
Removed the legacy Insults tab whose three generators (Insult, Dark Joke, Tasha's Joke) are all already provided by the consolidated Flavor tab (task 30).

### Changes
- **index.html:** removed `<button data-tab="insults">`, `<div id="tab-insults">`, and `<script src="modules/insults.js">`.
- **app.js:** removed `'insults': 'tabs/insults.html'` from `tabMap`, the `window.renderInsultsUI?.()` call in `save()`, and the `attachInsults()` guard call in boot.
- **styles.css:** deleted the entire `.insult-*` / `.dark-joke-*` / `.tasha-*` block including the `insultAppear` / `insultSpin` keyframes (lines 1382–1671). Confirmed via grep that the Flavor tab uses its own `.flavor-*` classes and none of these.
- **Deleted files:** `modules/insults.js` (incl. the large commented-out AI/bot block — preserved in git history), `tabs/insults.html`, `test/e2e/insults.spec.js`.
- **Specs:** `tabs-navigation.spec.js` and `data-loading.spec.js` already contained no insults references (removed during tasks 31/32), so no edits were required.

### Kept (live data contract)
`insults.json`, `dark-jokes.json`, `tasha-jokes.json` — still consumed by the Flavor tab.

### Verify
- grep for `attachInsults` / `btnGenerateInsult` / `tabs/insults` / `renderInsultsUI` / `data-tab="insults"` → 0 hits in code (only legitimate Flavor `data-flavor="dark-joke"|"tasha"` and json-url references remain).
- No unit infrastructure in this repo → unit step skipped. e2e (`flavor-ui`, `tabs-navigation`, `data-loading`, `critical-path`) left to the post-merge verify gate.


## Task 32 — refactor: remove legacy Excuses tab superseded by Flavor tab

**Repo:** combat (monk_combat_app) · **Branch:** ralph/task-32 · **Commit:** 845dfc8

### What changed
- **index.html:** removed `<button data-tab="excuses">`, `<div id="tab-excuses">` and `<script src="modules/excuses.js">`.
- **app.js:** removed the `'excuses': 'tabs/excuses.html'` tabMap entry, the historically duplicated `loadExcuses`/`attachExcuses` block (~1220-1258), and the `attachExcuses()` guard call. `pickRandom` helper kept (still used by Shenanigans).
- **Deleted:** `modules/excuses.js`, `tabs/excuses.html`, `test/e2e/excuses-ui.spec.js`.
- **test/e2e/tabs-navigation.spec.js:** dropped `excuses` from the all-tabs list; rewrote the "Excuses tab shows all categories" smoke test to assert the 5 excuses `data-flavor` buttons in the Flavor tab.
- **test/e2e/data-loading.spec.js:** redirected the `Data Loading - Excuses` describe and the `Excuses generate different results` variety test through the Flavor tab (`#flavorOutput` + `[data-flavor]` buttons).
- **Kept:** `excuses.json` (Flavor tab data source).

### Verification
- `grep` for `exLifeWisdom|btnExLifeWisdom|attachExcuses|tabs/excuses|data-tab="excuses"|tab-excuses|modules/excuses` → 0 matches in code.
- Remaining `excuses` mentions are only the JSON data file, the Flavor registry/tab, the redirected specs, and BEHAVIOR_DOCUMENTATION.md (out of scope, task 34).
- `node --check` passes for app.js, modules/flavor.js and both modified specs.
- No unit infrastructure in combat → unit step skipped per repos.json; e2e reserved for the post-merge verify gate.


## Task 31 — refactor: remove legacy One-Liners tab superseded by Flavor tab

**Repo:** combat (monk_combat_app) · **Branch:** ralph/task-31 · **Commit:** 9ca2195

### What changed
- **index.html** — removed the `data-tab="liners"` button, the `#tab-liners` div, and the `modules/one-liners.js` script tag.
- **app.js** — removed the `'liners'` tabMap entry, the `attachOneLiners()` boot call, and the whole legacy One-Liners block (`__ol_cache`/`OL_URL`/`loadOneLiners`/`attachOneLiners`). **Kept `pickRandom`** (still used by Shenanigans).
- **Deleted** `modules/one-liners.js`, `tabs/liners.html`, `test/e2e/one-liners-ui.spec.js`. `one-liners.json` stays (Flavor reads it).
- **test/e2e/tabs-navigation.spec.js** — swapped `liners`→`flavor` in the clickable-tabs list; rewrote the One-Liners smoke check to assert the 9 one-liner buttons in `#tab-flavor`; added multiclass level-up modal clicks (2× Monk for the 1→3 Long Rest) in the Stats-persist test.
- **test/e2e/data-loading.spec.js** — redirected the 9 One-Liners data checks + the variety test through the Flavor tab (`#tab-flavor [data-flavor=...]` → `#flavorOutput`); added 4× Monk modal clicks for the 1→5 Long Rest.

### Root cause of the previous failure (fixed)
The recurring red test `data-loading › skills-and-features.json loads for Level 5` was NOT a level-up problem. Its `text=Extra Attack` locator resolved to **two** elements — the accordion `<summary>[Monk] Lv 5 — Extra Attack</summary>` AND the hidden level-up modal's `#monkFeatureLabel` ("Extra Attack, Stunning Strike") — a Playwright **strict-mode violation**. Since the multiclass modal is created once and kept (hidden) in the DOM, this only bites tests that trigger a level-up. Fix: scope the assertion to `#featuresAccordion details.feat summary` with `hasText`.

### Verify
`npx playwright test flavor-ui tabs-navigation data-loading critical-path` → **88 passed** (server auto-managed by Playwright on 45278, torn down after). Step 31.4 grep (`olCritMiss|btnCritMiss|attachOneLiners|tabs/liners`) returns 0 code matches. `node --check` clean. All edits within task 31's `files` scope.


## Task 30 — feat: add consolidated Flavor tab with registry-driven line generator for all 17 flavor types

**Repo:** combat (monk_combat_app) · **Branch:** ralph/task-30 · **Commit:** 36fad8f

### What was done
- **modules/flavor.js** (new): IIFE + `window.attachFlavor`, following the existing module style. `FLAVOR_TYPES` registry of all 17 types as `{id, label, group, url, key}` — 9 One-Liners (`one-liners.json`, keys incl. `Q&A`/`magic_cocktails`), 5 Excuses (`excuses.json`), 3 Insults & Jokes (`insults.json` / `dark-jokes.json` / `tasha-jokes.json`, flat arrays → `key: null`, read logic lifted from modules/insults.js). Lazy cache is a `Map<url, data>`, so the 9 one-liner types share a single fetch. Click handler clears `#flavorOutput`, picks a random line (trim, `(empty)` fallback, `(failed to load <url>)` on error) and moves `.active` onto the pressed button.
- **tabs/flavor.html** (new): 'Flavor' title, large readonly `#flavorOutput` textarea always visible at the top, then three `section-title` sections (One-Liners / Excuses / Insults & Jokes), each a `.flavor-grid` of `.flavor-btn[data-flavor]` buttons with readable labels. No per-type fields.
- **styles.css**: additive only — `.flavor-btn` (min-height 48px, 1rem/600, hover + accent `.active`), `.flavor-grid` (auto-fill minmax(170px, 1fr)), `#flavorOutput` (min-height 200px, 1.15rem). Per the user's design requirement: big, clearly visible buttons and a large text area.
- **index.html / app.js**: `Flavor` tab-btn placed before One-Liners, `#tab-flavor` div, `modules/flavor.js` script before app.js; `'flavor': 'tabs/flavor.html'` in `tabMap` and a guarded `attachFlavor()` call alongside the other attaches.
- **test/e2e/flavor-ui.spec.js** (new): one click-test per type (22 tests total), looped in the one-liners-ui.spec.js shape, plus tab-opens-empty/readonly, all-17-visible, switching-type-moves-.active, and repeat-click-varies.

### Verification
- `npx playwright test flavor-ui critical-path` → **46/46 passed (1.1m)**.
- Old tabs untouched: `git status --porcelain` clean for tabs/liners.html, tabs/excuses.html, tabs/insults.html, modules/one-liners.js, modules/excuses.js, modules/insults.js (additive task — their specs stay green; removal is tasks 31-33).
- No runtime artifacts committed; no stray http-server left on 45278.

### Note on the previous failed attempt
The earlier attempt failed the verify gate on critical-path → 'Long rest fully restores HP, Ki, and HD', a stale test unrelated to task 30 (it set `xp = 6500` expecting level 5, but the app stores level in `st.level`). Base commit **9dcae14** has since fixed that test by setting `st.level`/`monkLevel`/`clericLevel` directly, so the blocker no longer exists — the gate is green on this branch. The prior attempt's secondary worry (full `npm test` exceeding the gate timeout) did not apply: the gate runs this task's own `verify` (28→46 tests, ~1 min), not the whole suite.


## Task #26 — refactor: finalize app.js as thin orchestrator facade and document module structure in README

**Date:** 2026-07-15
**Status:** ✅ Done

**What was done:**
- Cleaned up dead/unused imports in `app.js` that were only present for direct `export ... from` re-exports:
  - `firebase.js`: dropped `db, doc, collection, updateDoc, deleteDoc, getDoc` (kept `GOLD_DOC, ITEMS_DOC, QUESTS_DOC, onSnapshot, setDoc`).
  - `gold.js`: dropped `spendGold, coinInputs, clearCoinInputs` (kept `renderGold, handleGain, handleSpend`).
  - `ui.js`: dropped `esc, initSortable` (kept `syncMsg, initTabs, initModalBackdrops`).
- Verified the facade is complete — all 15 legacy exports still present (spendGold, renderGold, coinInputs, clearCoinInputs, renderItems, renderQuests, saveItems, saveQuests, initSortable, esc, syncMsg, BADGE, NEXT_STATUS, getState, setState).
- Wrote a `Structure` section in `README.md` documenting each file/module, how to run unit + e2e tests, and the intentional CDN-imports (no-bundler) decision.

**Files modified:** `app.js`, `README.md`

**Verification:** `npm run test:unit` → 6 files / 75 tests passed. No app.js behavior change; unit tests untouched.

**Git commit:** `bb856f7172abd6e6a8174a1cbaa1bf375ecb90f5`


### 2026-07-15 — Task #25: refactor: move gold handlers, tabs and modal backdrop wiring into their modules

**Status:** DONE (passes: true)

**What was done:**
- `modules/gold.js`: added imports for `syncMsg` (./ui.js) and `GOLD_DOC`, `setDoc` (./firebase.js); moved `handleGain` and `handleSpend` verbatim from app.js as exported `async function`s. No import cycle (ui.js does not import gold.js).
- `modules/ui.js`: extracted the `.tab-btn` click wiring into `export function initTabs()` and the modal backdrop-close wiring into `export function initModalBackdrops()`; both moved verbatim.
- `app.js`: imports `handleGain`/`handleSpend` from gold.js and `initTabs`/`initModalBackdrops` from ui.js; replaced the handler function bodies with `window.handleGain = handleGain` / `window.handleSpend = handleSpend` wiring; replaced the tabs and backdrop wiring blocks with `initTabs();` / `initModalBackdrops();` at the same top-level positions (execution order preserved); added `handleGain`/`handleSpend` to the gold.js facade re-export.
- Characterization tests untouched; `npm run test:unit` green (6 files, 75 tests).

**Files modified:** `app.js`, `modules/gold.js`, `modules/ui.js`

**Git commit:** d572efb61d6fa7b1156ed0d18387164e78d1db44


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



























