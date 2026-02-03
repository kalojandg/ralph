# ✅ Ralph Wiggum TDD Setup Summary

## 📋 Какво беше направено

Ralph Wiggum структурата в `.claude/` папка беше адаптирана за **Test-Driven Development (TDD)** workflow с **visual feedback** чрез cursor-ide-browser MCP (Chrome DevTools Protocol).

**Дата:** 2026-02-03

---

## 🎯 Главни промени

### 1. **PROMPT.md** - Напълно пренаписан

**Преди:** Generic prompt за static HTML projects

**Сега:** TDD-specific prompt с:
- RED → GREEN → VISUAL → REFACTOR → DONE workflow
- cursor-ide-browser MCP instructions (Chrome DevTools Protocol browser automation)
- localStorage mock backend guidelines
- Step-by-step execution (ONE step at a time)
- Verification loop (iterate until tests pass AND design matches)
- XML output tags за completion tracking

**Ключови секции:**
- TDD Workflow per Phase (детайлни инструкции)
- Verification Loop (mandatory checks преди mark complete)
- Visual Testing Checklist (layout, colors, typography, spacing)
- Success Criteria (6 критерия за completion)

### 2. **user-steps.md** - Специализиран за Visual Feedback

**Преди:** Generic user steps template

**Сега:** Visual testing specifics:
- cursor-ide-browser MCP setup и usage (browser automation)
- Visual Comparison Checklist (от design-mapping.json)
- Common design fixes (colors, spacing, typography)
- Testing Loop instructions (unit, E2E, linter, TypeScript)
- Step-by-step execution examples
- Debugging tips за visual mismatches

**Ключови секции:**
- Visual Feedback Loop (КРИТИЧНО!)
- Testing Loop (КРИТИЧНО!)
- Step-by-Step Execution (ONE at a time)
- Critical Checkpoints (before marking complete)

### 3. **completion-check.ps1** - Нов файл

**Цел:** Check дали всички tasks са завършени

**Функционалност:**
- Проверява за `<promise>COMPLETE</promise>` XML tag
- Чете `tasks.json` и брои `"passes": true` tasks
- Показва progress (X / 30 tasks complete)
- Намира следващия incomplete task
- Returns exit code 0 (complete) или 1 (continue)

### 4. **ralph-config.json** - Актуализиран

**Добавени секции:**

```json
{
  "tdd": {
    "enabled": true,
    "test_commands": {
      "unit": "npm test",
      "e2e": "npx playwright test",
      "lint": "npm run lint",
      "typecheck": "npm run type-check"
    },
    "visual_testing": {
      "mcp_server": "cursor-ide-browser",
      "dev_server": "npm run dev",
      "designs_folder": "docs/composition/designs"
    },
    "mock_backend": {
      "type": "localStorage",
      "storage_key": "bdz_mockups"
    }
  }
}
```

**Актуализирани patterns:**
- `<promise>COMPLETE</promise>`
- `<task-complete>`
- `<status>CONTINUE</status>`

### 5. **feedback.md** - Template за feedback loop

**Цел:** Ralph чете този файл преди всяка итерация за context

**Съдържа:**
- Last Iteration Summary
- Feedback for Next Iteration
- Issues from Last Iteration (ако има)

**Auto-updated:** След всяка итерация (опционално)

### 6. Launcher Scripts (New & Updated)

#### 🆕 START-RALPH-TDD.bat

**Главен launcher с 20 iterations**

Features:
- Beautiful ASCII box art
- Clear description на TDD workflow
- Pause преди старт (за review)
- Post-execution summary (къде да видиш резултати)

#### 📝 ralph-quick.bat (Updated)

**Quick test launcher с 10 iterations**

Промени:
- Updated UI (ASCII boxes)
- Added TDD workflow description
- Shorter для бързо тестване

#### 🆕 CHECK-PROGRESS.bat

**Check колко tasks са готови**

Shows:
- Progress percentage
- List of completed tasks (✓)
- Next 5 remaining tasks (○)

#### 🆕 VIEW-LOGS.bat

**View latest iteration log**

Features:
- Automatically finds latest log
- Displays full content
- Option to open logs folder

#### 🆕 RESET-TASKS.bat

**Reset ALL tasks (for testing)**

⚠️ Dangerous! Use only for:
- Testing Ralph setup
- Starting completely fresh
- Requires "YES" confirmation

### 7. Documentation (New)

#### 📖 README.md (Overwritten)

**Quick start guide на български**

Sections:
- Бързо стартиране
- Структура на файлове
- TDD Workflow
- Testing Stack
- Visual Testing
- Progress Tracking
- Troubleshooting

#### 📖 README-TDD.md

**Detailed TDD guide (English)**

Comprehensive documentation:
- Prerequisites
- How It Works
- File Structure
- TDD Configuration
- Visual Testing Details
- Progress Tracking Commands
- Troubleshooting Guide

#### 📖 🚀 СТАРТ ТУК.txt

**Eye-catching start file**

Features:
- Emoji + ASCII art (easy to spot)
- Quick start instructions
- What Ralph does
- Success criteria
- Troubleshooting

---

## 🎯 TDD Workflow Summary

Ralph сега следва този процес за всеки UI таsk:

```
1. READ tasks.json
   └─ Find first task with "passes": false

2. EXECUTE STEPS ONE BY ONE
   
   RED Phase:
   └─ Write failing test
   └─ Run test → verify FAILS ✅

   GREEN Phase:
   └─ Implement minimal code
   └─ Run test → verify PASSES ✅

   VISUAL Phase:
   └─ Start dev server
   └─ cursor-ide-browser MCP screenshot
   └─ Compare с designs/{id}.png

   REFACTOR Phase:
   └─ If not match:
      └─ Adjust layout/colors/spacing
      └─ Re-screenshot
      └─ ITERATE until matches ✅

3. VERIFICATION LOOP
   └─ Run ALL tests
   └─ Run linter
   └─ Run TypeScript check
   └─ IF ANYTHING FAILS:
      └─ Fix it
      └─ Re-run
      └─ ITERATE until ALL pass ✅

4. MARK COMPLETE
   └─ Update tasks.json: "passes": true
   └─ Log in activity.md
   └─ Git commit

5. OUTPUT STATUS
   └─ <task-complete> XML tag
   └─ <status>CONTINUE</status>
   
6. REPEAT
   └─ Next task with "passes": false
```

---

## 🎨 Visual Testing Flow

```
1. Start dev server
   npm run dev → http://localhost:5173

2. Navigate with cursor-ide-browser MCP
   CallMcpTool({
     server: "cursor-ide-browser",
     toolName: "browser_navigate",
     arguments: { url: "http://localhost:5173/compositions" }
   })

3. Take screenshot
   CallMcpTool({
     server: "cursor-ide-browser",
     toolName: "browser_screenshot",
     arguments: { fullPage: true }
   })

4. Compare with mockup
   Reference: designs/{task_id}.png
   Check: Layout, Colors, Typography, Spacing

5. If doesn't match → REFACTOR
   Adjust → Re-screenshot → Compare → Repeat

6. When matches → DONE ✅
```

---

## 📂 File Structure (Final)

```
.claude/
├── ralph.ps1                      # Main loop (unchanged)
├── ralph-iteration.ps1            # Iteration executor (unchanged)
├── ralph-config.json              # ✅ Updated (TDD config)
├── PROMPT.md                      # ✅ Completely rewritten (TDD)
├── user-steps.md                  # ✅ Completely rewritten (Visual feedback)
├── completion-check.ps1           # ✅ New (Check if done)
├── feedback.md                    # ✅ New (Feedback loop)
│
├── START-RALPH-TDD.bat            # ✅ New (Main launcher - 20 iter)
├── ralph-quick.bat                # ✅ Updated (Quick test - 10 iter)
├── CHECK-PROGRESS.bat             # ✅ New (Progress check)
├── VIEW-LOGS.bat                  # ✅ New (View logs)
├── RESET-TASKS.bat                # ✅ New (Reset for testing)
│
├── README.md                      # ✅ New (Quick guide BG)
├── README-TDD.md                  # ✅ New (Detailed guide EN)
├── 🚀 СТАРТ ТУК.txt               # ✅ New (Eye-catching start)
├── SETUP-SUMMARY.md               # ✅ New (This file)
│
└── logs/                          # Auto-created on first run

../docs/composition/
├── tasks.json                     # 30 tasks (already TDD format)
├── PRD.json                       # Requirements (already TDD)
├── activity.md                    # Activity log (Ralph updates)
├── plan.md                        # Detailed instructions
└── designs/                       # 10 UI mockups
    ├── 9.png, 10.png, ... 20.png
    └── design-mapping.json
```

---

## ✅ Success Criteria

Ralph mark-ва task като `"passes": true` САМО когато:

1. ✅ **Tests pass**
   - `npm test` → all green
   - `npx playwright test` → all green

2. ✅ **Visual match** (ако има `designReference`)
   - cursor-ide-browser MCP screenshot
   - Compare със `designs/{task_id}.png`
   - Layout ✅ Colors ✅ Typography ✅ Spacing ✅

3. ✅ **Linter passes**
   - `npm run lint` → no errors

4. ✅ **TypeScript compiles**
   - `npm run type-check` → no errors

5. ✅ **Git committed with exact task description**
   - Format: `git commit -m "feat(compositions): {task.description}"`
   - Example: `git commit -m "feat(compositions): Create Dashboard List Page with compositions table"`
   - Must use EXACT description from tasks.json!

6. ✅ **Logged in activity.md**
   - TDD phases documented
   - Files modified listed
   - Verification results noted

**IF ANY FAILS → DO NOT MARK COMPLETE → ITERATE!**

---

## 🚀 How to Start

### Quick Start (Recommended)

```
1. Отвори .claude/ папка
2. Двойно кликни: START-RALPH-TDD.bat
3. Wait за Ralph да работи
4. Monitor: CHECK-PROGRESS.bat
5. Done когато видиш: <promise>COMPLETE</promise>
```

### PowerShell

```powershell
cd "c:\Projects\BDZ Project\Admin-App\.claude"
.\ralph.ps1 20
```

### Monitor Progress

```powershell
# Terminal 1: Run Ralph
.\ralph.ps1 20

# Terminal 2: Watch Progress
while ($true) {
  Clear-Host
  $tasks = Get-Content "..\docs\composition\tasks.json" | ConvertFrom-Json
  $completed = ($tasks | Where-Object { $_.passes -eq $true }).Count
  Write-Host "Completed: $completed / $($tasks.Count)" -ForegroundColor Green
  Start-Sleep 10
}
```

---

## 🎯 Expected Output

### During Execution

```
Iteration 3
--------------------------------
Task #11: Create Dashboard List Page (TDD)

Phase: RED
✓ Test written
✗ Test FAILS (expected)

Phase: GREEN
✓ Component created
✓ Test PASSES

Phase: VISUAL
✓ Dev server started
✓ Screenshot taken
✗ Design doesn't match (colors off)

Phase: REFACTOR
✓ Colors adjusted to #1976d2
✓ Re-screenshot matches

Phase: DONE
✓ All tests pass
✓ Linter passes
✓ TypeScript compiles
✓ Committed: feat(compositions): implement list page

--- End of iteration 3 ---
```

### XML Output Tags

```xml
<task-complete>
  <task-id>11</task-id>
  <tests>PASSED</tests>
  <visual>MATCHED</visual>
  <committed>YES</committed>
</task-complete>

<status>CONTINUE</status>
<next-task>12</next-task>
```

### Final Completion

```xml
<promise>COMPLETE</promise>
<total-tasks>30</total-tasks>
<all-passed>true</all-passed>
```

---

## 📊 Metrics to Track

Ralph ще track-ва в `activity.md`:

- **Test Coverage**: Unit tests, E2E tests, Visual tests created
- **TDD Cycles**: Total cycles, iterations per component
- **Design Match Rate**: % from първи път
- **Time per Phase**: Average time за RED/GREEN/VISUAL/REFACTOR

---

## 🚨 Important Notes

### localStorage Mock Backend

**КРИТИЧНО:** Няма реален backend!

```javascript
// All data in localStorage
localStorage['bdz_mockups'] = JSON.stringify({
  compositions: [...],
  wagons: [...],
  wagonTypes: [...],
  trains: [...],
  stations: [...]
});

// API calls
compositionsApi.getAll() // → reads localStorage
compositionsApi.create(data) // → writes localStorage
```

### cursor-ide-browser MCP (Browser Automation)

**Server name:** `cursor-ide-browser` (НЕ cursor-browser-extension!)
**Technology:** Chrome DevTools Protocol
**Purpose:** Browser automation, screenshots, interaction

**Tools:**
- `browser_navigate` - Navigate to URL
- `browser_screenshot` - Take screenshot
- `browser_snapshot` - Get page structure

### Design Comparison

Reference file: `../docs/composition/designs/design-mapping.json`

**Must check:**
- Layout structure
- Color palette (badges, borders, backgrounds)
- Typography (h4, h6, body1, caption)
- Spacing (16px gaps, 400px drawer, 25% sidebar)

---

## 🎉 Next Steps

1. ✅ **Setup е завършен!**
2. ✅ **Всички файлове са на място**
3. ✅ **Ralph е конфигуриран за TDD**
4. 🚀 **Ready to launch!**

### To Start:

```
Double-click: START-RALPH-TDD.bat
```

### To Monitor:

```
Double-click: CHECK-PROGRESS.bat
```

### To View Results:

```
notepad ..\docs\composition\activity.md
explorer logs
```

---

## 📚 Documentation Reference

| File | Purpose |
|------|---------|
| `README.md` | Quick start (BG) |
| `README-TDD.md` | Detailed guide (EN) |
| `🚀 СТАРТ ТУК.txt` | Eye-catching start |
| `SETUP-SUMMARY.md` | This file |
| `../docs/composition/TDD-SETUP-COMPLETE.md` | Full TDD setup docs |
| `../docs/composition/plan.md` | Detailed TDD instructions |

---

**Ralph Wiggum TDD е готов! 🚀 Време е да кодираме!**

**Expected Results:**
- ⏱️ Duration: ~30-40 hours of autonomous work
- 📊 Tasks: 30 total (all will be completed)
- 🧪 Tests: Unit + E2E + Visual (all will pass)
- 🎨 Design: 10 mockups (all will match)
- 💾 Backend: localStorage mock (fully functional)
- ✅ Commits: 30 commits (one per task)

**When done:**
- All tasks marked `"passes": true`
- All tests passing
- All designs matching
- Fully functional Compositions module
- Ready for review and deployment

**GO RALPH GO! 🚀🎉**

---

**Created:** 2026-02-03  
**By:** AI Assistant  
**For:** БДЖ Административен Портал - Модул Композиране (Frontend PoC)
