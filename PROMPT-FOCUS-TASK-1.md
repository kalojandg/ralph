
## SPECIAL INSTRUCTION FOR THIS RUN

FOCUS MODE: Work ONLY on Task #1

Task Details:
- ID: 1
- Description: Install @dnd-kit packages for drag-and-drop functionality
- Category: setup

Instructions:
1. Read tasks.json and find Task #1
2. Work ONLY on this task (ignore all others)
3. Follow full TDD workflow: RED -> GREEN -> VISUAL -> REFACTOR -> DONE
4. Mark passes: true ONLY when ALL criteria met
5. If task is already complete (passes: true), report success and exit

DO NOT work on any other tasks!


# Ralph Wiggum TDD Iteration - Compositions Module

## Context Files

РџСЂРѕС‡РµС‚Рё СЃР»РµРґРЅРёС‚Рµ С„Р°Р№Р»РѕРІРµ Р·Р° РїСЉР»РµРЅ context:

1. **@docs/composition/activity.md** - РСЃС‚РѕСЂРёСЏ РЅР° СЃРІСЉСЂС€РµРЅР°С‚Р° СЂР°Р±РѕС‚Р°
2. **@docs/composition/tasks.json** - Task list (С‚РІРѕСЏ source of truth)
3. **@docs/composition/PRD.json** - Requirements Рё TDD methodology
4. **@docs/composition/designs/** - UI mockups Р·Р° visual testing

## Your Mission This Iteration

Р Р°Р±РѕС‚Рё РІСЉСЂС…Сѓ **Р•Р”РРќ Р•Р”РРќРЎРўР’Р•Рќ РўРђРЎРљ** РѕС‚ `tasks.json` РєСЉРґРµС‚Рѕ `"passes": false`.

## TDD Workflow (RED в†’ GREEN в†’ VISUAL в†’ REFACTOR)

### Step 1: Find Next Task

```powershell
# РџСЂРѕС‡РµС‚Рё tasks.json Рё РЅР°РјРµСЂРё РїСЉСЂРІРёСЏ С‚Р°СЃРє СЃ "passes": false
# РџСЂРѕС‡РµС‚Рё Р’РЎРР§РљР steps Р·Р° С‚РѕР·Рё С‚Р°СЃРє
# Note: РђРєРѕ РёРјР° "designReference" Рё "tddWorkflow": true в†’ СЃР»РµРґРІР°Р№ TDD phases
```

### Step 2: Execute Task Steps ONE BY ONE

**РљР РРўРР§РќРћ:** РџСЂР°РІРё СЃС‚СЉРїРєРёС‚Рµ **Р•Р”РќРђ РџРћ Р•Р”РќРђ**, РЅРµ РІСЃРёС‡РєРё РЅР°РІРµРґРЅСЉР¶!

#### РђРєРѕ С‚Р°СЃРє РёРјР° `"tddWorkflow": true`:

**Phase RED (Write Failing Test):**
- РР·РїСЉР»РЅРё steps СЃ `"phase": "RED"`
- РќР°РїРёС€Рё failing test (unit test РёР»Рё E2E test СЃ Playwright)
- **RUN TEST** в†’ verify it **FAILS**
- РђРєРѕ РЅРµ С„РµР№Р»РІР° в†’ С‚РµСЃС‚СЉС‚ РЅРµ С‚РµСЃС‚РІР° РїСЂР°РІРёР»РЅРѕС‚Рѕ РЅРµС‰Рѕ!

**Phase GREEN (Minimal Implementation):**
- РР·РїСЉР»РЅРё steps СЃ `"phase": "GREEN"`
- РРјРїР»РµРјРµРЅС‚РёСЂР°Р№ **РјРёРЅРёРјР°Р»РµРЅ РєРѕРґ** Р·Р° РґР° РјРёРЅР°РІР° С‚РµСЃС‚СЉС‚
- **RUN TEST AGAIN** в†’ verify it **PASSES**

**Phase VISUAL (Screenshot Comparison):**
- РР·РїСЉР»РЅРё steps СЃ `"phase": "VISUAL"`
- Start dev server: `npm run dev`
- **Use cursor-ide-browser MCP for screenshots**:
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
- **Compare screenshot** СЃ `@docs/composition/designs/{task_id}.png`
- РџСЂРѕРІРµСЂРё: Layout вњ… Colors вњ… Typography вњ… Spacing вњ…

**Phase REFACTOR (Iterate Until Matches):**
- РР·РїСЉР»РЅРё steps СЃ `"phase": "REFACTOR"`
- РђРєРѕ РґРёР·Р°Р№РЅСЉС‚ РќР• СЃСЉРІРїР°РґР°:
  - Adjust layout/colors/spacing/typography
  - Reference: `@docs/composition/designs/design-mapping.json`
  - Re-screenshot and compare again
- **ITERATE** РґРѕРєР°С‚Рѕ screenshot СЃСЉРІРїР°РґР° СЃ mockup

**Phase DONE (Verification):**
- РР·РїСЉР»РЅРё steps СЃ `"phase": "DONE"`
- **VERIFY ALL:**
  - вњ… Tests pass: `npm test && npx playwright test`
  - вњ… Visual match: Screenshot СЃСЉРІРїР°РґР° СЃ design mockup
  - вњ… No linter errors: `npm run lint`
  - вњ… TypeScript compiles: `npm run type-check`

#### РђРєРѕ С‚Р°СЃРє РќРЇРњРђ `"tddWorkflow"` (setup tasks):

- РР·РїСЉР»РЅРё steps РїРѕСЃР»РµРґРѕРІР°С‚РµР»РЅРѕ (РµРґРЅР° РїРѕ РµРґРЅР°!)
- Verify functionality СЃР»РµРґ РІСЃСЏРєР° СЃС‚СЉРїРєР°
- Run relevant commands (npm install, create folders, etc.)

### Step 3: Verification Loop

**РЎР›Р•Р” РёР·РїСЉР»РЅРµРЅРёРµ РЅР° Р’РЎРР§РљР steps:**

1. **Run Tests:**
   ```bash
   npm test                # Unit/component tests
   npx playwright test     # E2E tests
   ```
   
2. **Check Linter:**
   ```bash
   npm run lint
   ```

3. **Visual Comparison** (Р°РєРѕ РёРјР° designReference):
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

**РЎРђРњРћ РђРљРћ Р’РЎРР§РљР РљР РРўР•Р РР РЎРђ вњ…:**

1. **Update tasks.json:**
   ```json
   // Change for completed task:
   "passes": false в†’ "passes": true
   ```

2. **Log in activity.md:**
   ```markdown
   ## [2026-02-03 HH:MM] - Task #{id}: {description}
   
   **Status:** вњ… Complete
   
   **TDD Phase:** RED в†’ GREEN в†’ VISUAL в†’ REFACTOR в†’ DONE
   
   **What was done:**
   ### RED Phase
   - Step X: Wrote failing test in {file}
   - Step Y: Ran test - FAILS вњ…
   
   ### GREEN Phase
   - Step X: Implemented {component}
   - Step Y: Ran test - PASSES вњ…
   
   ### VISUAL Phase
   - Step X: Started dev server
   - Step Y: cursor-ide-browser MCP screenshot
   - Step Z: Compared with design {id}.png
   - Result: Layout вњ… Colors вњ… Typography вњ… Spacing вњ…
   
   **Files modified:**
   - {file1}
   - {file2}
   
   **Git commit:**
   - `feat(compositions): {exact task.description from tasks.json}`
   - Example: `feat(compositions): Create Dashboard List Page with compositions table`
   
   ---
   ```

3. **Git commit:**
   
   **IMPORTANT:** Use the exact task `description` from tasks.json as commit message!
   
   ```bash
   git add .
   git commit -m "feat(compositions): {exact task.description from tasks.json}"
   ```
   
   **Example:** For Task #11 with description "Create Dashboard List Page with compositions table":
   ```bash
   git commit -m "feat(compositions): Create Dashboard List Page with compositions table"
   ```
   
   **DO NOT:**
   - git init
   - git push
   - change remotes
   - make up your own commit message (use exact description!)

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

### рџљЁ Critical

1. **ONE TASK AT A TIME** - Never work on multiple tasks in parallel
2. **ONE STEP AT A TIME** - Execute steps sequentially, verify after each
3. **TESTS FIRST** (for TDD tasks) - Write failing test BEFORE implementation
4. **VISUAL FEEDBACK MANDATORY** (for designReference tasks) - Must screenshot and compare
5. **ITERATE UNTIL PASS** - Don't mark complete until tests pass AND design matches

### рџЋЇ Testing Commands

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

### рџЋЁ Visual Testing (cursor-ide-browser MCP)

**MUST use MCP server:** `cursor-ide-browser` (NOT cursor-browser-extension or playwright)

**Available tools:**
1. `browser_navigate` - Navigate to URL
2. `browser_screenshot` - Take screenshot (fullPage: true)
3. `browser_snapshot` - Get page structure (for debugging)

**Comparison Checklist:**

Reference `@docs/composition/designs/design-mapping.json`:

- вњ… **Layout**: Header, sidebar (25%), main (75%) positioning
- вњ… **Colors**: 
  - Status badges: gray (Draft), green (Active)
  - Wagon borders: green (active), gray (inactive)
  - Wagon backgrounds: blue (Compartment), purple (Sleeper), yellow (Bistro)
- вњ… **Typography**: h4 (title), h6 (placard), body1 (type), caption (capacity)
- вњ… **Spacing**: 16px gaps, 400px drawer, proper padding

### рџ“¦ localStorage Mock Backend

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
compositionsApi.getAll() // в†’ reads localStorage
compositionsApi.create(data) // в†’ writes localStorage
```

**Task #3** will setup auto-seed with sample data.

### вЏ±пёЏ Iteration Summary

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

1. вњ… Tests pass (npm test AND npx playwright test)
2. вњ… Visual match (screenshot СЃСЉРІРїР°РґР°) - Р°РєРѕ РёРјР° designReference
3. вњ… No linter errors (npm run lint)
4. вњ… TypeScript compiles (npm run type-check)
5. вњ… Git committed
6. вњ… Logged in activity.md

**If ANY criteria fails в†’ DO NOT mark passes: true в†’ ITERATE!**

---

**Ralph, work on ONE task, follow TDD phases, verify everything, commit, and report status!**

**Remember:** 
- Steps ONE BY ONE
- Tests FIRST (for TDD tasks)
- Screenshot comparison MANDATORY (for designReference tasks)
- Iterate until ALL verifications pass
- Only then mark complete

**Good luck! рџљЂ**

