# Ralph Wiggum TDD Iteration - Compositions Module

## Context Files

Прочети следните файлове за пълен context:

1. **@docs/composition/activity.md** - История на свършената работа
2. **@docs/composition/tasks.json** - Task list (твоя source of truth)
3. **@docs/composition/PRD.json** - Requirements и TDD methodology
4. **@docs/composition/designs/** - UI mockups за visual testing

## Your Mission This Iteration

Работи върху **ЕДИН ЕДИНСТВЕН ТАСК** от `tasks.json` където `"passes": false`.

## TDD Workflow (RED → GREEN → VISUAL → REFACTOR)

### Step 1: Find Next Task

```powershell
# Прочети tasks.json и намери първия таск с "passes": false
# Прочети ВСИЧКИ steps за този таск
# Note: Ако има "designReference" и "tddWorkflow": true → следвай TDD phases
```

### Step 2: Execute Task Steps ONE BY ONE

**КРИТИЧНО:** Прави стъпките **ЕДНА ПО ЕДНА**, не всички наведнъж!

#### Ако таск има `"tddWorkflow": true`:

**Phase RED (Write Failing Test):**
- Изпълни steps с `"phase": "RED"`
- Напиши failing test (unit test или E2E Playwright test)
- **RUN TEST** → verify it **FAILS**
- Ако не фейлва → тестът не тества правилното нещо!

**Phase GREEN (Minimal Implementation):**
- Изпълни steps с `"phase": "GREEN"`
- Имплементирай **минимален код** за да минава тестът
- **RUN TEST AGAIN** → verify it **PASSES**

**Phase VISUAL (Screenshot Comparison):**
- Изпълни steps с `"phase": "VISUAL"`
- Start dev server: `npm run dev`
- **Use Playwright MCP (cursor-ide-browser)**:
  ```javascript
  // Navigate to component/page
  CallMcpTool({
    server: "cursor-ide-browser",
    toolName: "browser_navigate",
    arguments: { url: "http://localhost:5173/..." }
  })
  
  // Take screenshot
  CallMcpTool({
    server: "cursor-ide-browser",
    toolName: "browser_screenshot",
    arguments: { fullPage: true }
  })
  ```
- **Compare screenshot** с `@docs/composition/designs/{task_id}.png`
- Провери: Layout ✅ Colors ✅ Typography ✅ Spacing ✅

**Phase REFACTOR (Iterate Until Matches):**
- Изпълни steps с `"phase": "REFACTOR"`
- Ако дизайнът НЕ съвпада:
  - Adjust layout/colors/spacing/typography
  - Reference: `@docs/composition/designs/design-mapping.json`
  - Re-screenshot and compare again
- **ITERATE** докато screenshot съвпада с mockup

**Phase DONE (Verification):**
- Изпълни steps с `"phase": "DONE"`
- **VERIFY ALL:**
  - ✅ Tests pass: `npm test && npx playwright test`
  - ✅ Visual match: Screenshot съвпада с design mockup
  - ✅ No linter errors: `npm run lint`
  - ✅ TypeScript compiles: `npm run type-check`

#### Ако таск НЯМА `"tddWorkflow"` (setup tasks):

- Изпълни steps последователно (една по една!)
- Verify functionality след всяка стъпка
- Run relevant commands (npm install, create folders, etc.)

### Step 3: Verification Loop

**СЛЕД изпълнение на ВСИЧКИ steps:**

1. **Run Tests:**
   ```bash
   npm test                # Unit/component tests
   npx playwright test     # E2E tests
   ```
   
2. **Check Linter:**
   ```bash
   npm run lint
   ```

3. **Visual Comparison** (ако има designReference):
   - Use Playwright MCP screenshot
   - Compare with `designs/{task_id}.png`
   - Check: Layout, Colors, Typography, Spacing

4. **IF ANYTHING FAILS:**
   - Go back and fix
   - Re-run tests
   - Re-screenshot and compare
   - **ITERATE** until ALL verifications pass

5. **ONLY WHEN ALL PASS:**
   - Proceed to Step 4

### Step 4: Mark Complete

**САМО АКО ВСИЧКИ КРИТЕРИИ СА ✅:**

1. **Update tasks.json:**
   ```json
   // Change for completed task:
   "passes": false → "passes": true
   ```

2. **Log in activity.md:**
   ```markdown
   ## [2026-02-03 HH:MM] - Task #{id}: {description}
   
   **Status:** ✅ Complete
   
   **TDD Phase:** RED → GREEN → VISUAL → REFACTOR → DONE
   
   **What was done:**
   ### RED Phase
   - Step X: Wrote failing test in {file}
   - Step Y: Ran test - FAILS ✅
   
   ### GREEN Phase
   - Step X: Implemented {component}
   - Step Y: Ran test - PASSES ✅
   
   ### VISUAL Phase
   - Step X: Started dev server
   - Step Y: Playwright MCP screenshot
   - Step Z: Compared with design {id}.png
   - Result: Layout ✅ Colors ✅ Typography ✅ Spacing ✅
   
   **Files modified:**
   - {file1}
   - {file2}
   
   **Git commit:**
   - `feat(compositions): {description}`
   
   ---
   ```

3. **Git commit:**
   ```bash
   git add .
   git commit -m "feat(compositions): {task description}"
   ```
   
   **DO NOT:**
   - git init
   - git push
   - change remotes

### Step 5: Report Status

**Output exactly:**

```xml
<task-complete>
  <task-id>{id}</task-id>
  <tests>PASSED</tests>
  <visual>MATCHED</visual>
  <committed>YES</committed>
</task-complete>
```

**IF there are more tasks with passes: false:**

Output:
```xml
<status>CONTINUE</status>
<next-task>{next_task_id}</next-task>
```

**IF ALL tasks have passes: true:**

Output:
```xml
<promise>COMPLETE</promise>
<total-tasks>{count}</total-tasks>
<all-passed>true</all-passed>
```

## Important Rules

### 🚨 Critical

1. **ONE TASK AT A TIME** - Never work on multiple tasks in parallel
2. **ONE STEP AT A TIME** - Execute steps sequentially, verify after each
3. **TESTS FIRST** (for TDD tasks) - Write failing test BEFORE implementation
4. **VISUAL FEEDBACK MANDATORY** (for designReference tasks) - Must screenshot and compare
5. **ITERATE UNTIL PASS** - Don't mark complete until tests pass AND design matches

### 🎯 Testing Commands

```bash
# Unit/Component tests
npm test

# E2E tests
npx playwright test

# Linter
npm run lint

# TypeScript
npm run type-check

# Dev server (for visual testing)
npm run dev
```

### 🎨 Visual Testing (Playwright MCP)

**MUST use MCP server:** `cursor-ide-browser` (NOT cursor-browser-extension)

**Available tools:**
1. `browser_navigate` - Navigate to URL
2. `browser_screenshot` - Take screenshot (fullPage: true)
3. `browser_snapshot` - Get page structure (for debugging)

**Comparison Checklist:**

Reference `@docs/composition/designs/design-mapping.json`:

- ✅ **Layout**: Header, sidebar (25%), main (75%) positioning
- ✅ **Colors**: 
  - Status badges: gray (Draft), green (Active)
  - Wagon borders: green (active), gray (inactive)
  - Wagon backgrounds: blue (Compartment), purple (Sleeper), yellow (Bistro)
- ✅ **Typography**: h4 (title), h6 (placard), body1 (type), caption (capacity)
- ✅ **Spacing**: 16px gaps, 400px drawer, proper padding

### 📦 localStorage Mock Backend

**CRITICAL:** No real backend! Everything is in `localStorage['bdz_mockups']`.

```javascript
// Structure
localStorage['bdz_mockups'] = JSON.stringify({
  compositions: [...],
  wagons: [...],
  wagonTypes: [...],
  trains: [...],
  stations: [...]
});

// API methods read/write from localStorage
compositionsApi.getAll() // → reads localStorage
compositionsApi.create(data) // → writes localStorage
```

**Task #3** will setup auto-seed with sample data.

### ⏱️ Iteration Summary

**At END of iteration, output summary:**

```markdown
## Iteration Summary

**Task Worked On:** #{id} - {description}

**TDD Phase Completed:** {RED/GREEN/VISUAL/REFACTOR/DONE or N/A}

**Tests Status:**
- Unit tests: {PASSED/FAILED/N/A}
- E2E tests: {PASSED/FAILED/N/A}
- Linter: {PASSED/FAILED}

**Visual Status:**
- Screenshot taken: {YES/NO}
- Design matches: {YES/NO/N/A}

**Verification:**
- All steps completed: {YES/NO}
- Task marked passes: {true/false}
- Git committed: {YES/NO}

**Next Action:**
- {Continue to next task / Iterate on current task / All complete}
```

## Success Criteria

Mark `"passes": true` ONLY IF:

1. ✅ Tests pass (npm test AND npx playwright test)
2. ✅ Visual match (screenshot съвпада) - ако има designReference
3. ✅ No linter errors (npm run lint)
4. ✅ TypeScript compiles (npm run type-check)
5. ✅ Git committed
6. ✅ Logged in activity.md

**If ANY criteria fails → DO NOT mark passes: true → ITERATE!**

---

**Ralph, work on ONE task, follow TDD phases, verify everything, commit, and report status!**

**Remember:** 
- Steps ONE BY ONE
- Tests FIRST (for TDD tasks)
- Screenshot comparison MANDATORY (for designReference tasks)
- Iterate until ALL verifications pass
- Only then mark complete

**Good luck! 🚀**
