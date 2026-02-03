# Ralph Wiggum TDD Setup - Compositions Module

## 📋 Quick Start

### Prerequisites

1. ✅ Node.js and npm installed
2. ✅ Claude CLI installed and configured (`claude --version`)
3. ✅ Playwright MCP (cursor-ide-browser) configured
4. ✅ Project dependencies installed (`npm install`)

### Run Ralph Wiggum

**Option 1: Quick Launch (10 iterations)**

```powershell
cd "c:\Projects\BDZ Project\Admin-App\.claude"
.\ralph-quick.bat
```

**Option 2: Custom Iterations**

```powershell
cd "c:\Projects\BDZ Project\Admin-App\.claude"
.\ralph.ps1 20
```

**Option 3: With Custom Config**

```powershell
.\ralph.ps1 20 custom-config.json
```

---

## 🎯 How It Works

### Iteration Flow

```
ralph.ps1 (main loop)
    ↓
ralph-iteration.ps1 (single iteration)
    ↓
PROMPT.md (main instructions) + user-steps.md (TDD specifics)
    ↓
Claude executes ONE task from tasks.json
    ↓
TDD Workflow: RED → GREEN → VISUAL → REFACTOR → DONE
    ↓
completion-check.ps1 (check if done)
    ↓
Back to ralph.ps1 (next iteration or complete)
```

### TDD Workflow per Task

```
1. RED Phase
   - Write failing test
   - Run test → verify FAILS ✅

2. GREEN Phase
   - Implement minimal code
   - Run test → verify PASSES ✅

3. VISUAL Phase
   - Start dev server
   - Playwright MCP screenshot
   - Compare with designs/{id}.png

4. REFACTOR Phase
   - If design doesn't match:
     - Adjust layout/colors/spacing
     - Re-screenshot
     - Iterate until matches ✅

5. DONE Phase
   - Verify ALL:
     - Tests pass
     - Design matches
     - Linter passes
     - TypeScript compiles
   - Mark "passes": true
   - Git commit
```

---

## 📂 File Structure

```
.claude/
├── ralph.ps1                   # Main loop script
├── ralph-iteration.ps1         # Single iteration script
├── ralph-config.json           # Configuration (TDD enabled)
├── PROMPT.md                   # Main TDD instructions
├── user-steps.md               # Visual feedback specifics
├── completion-check.ps1        # Check if all tasks done
├── feedback.md                 # Feedback between iterations
├── ralph-quick.bat             # Quick launcher (10 iterations)
├── ralph.bat                   # Manual launcher
└── logs/                       # Iteration logs (auto-created)

../docs/composition/
├── tasks.json                  # 30 tasks (TDD format)
├── PRD.json                    # Requirements
├── activity.md                 # Activity log (Ralph updates)
└── designs/                    # UI mockups for comparison
    ├── 9.png, 10.png, ...
    └── design-mapping.json
```

---

## 🧪 TDD Configuration

### ralph-config.json

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

---

## 🎨 Visual Testing

### Playwright MCP Usage

Ralph will use `cursor-ide-browser` MCP to:

1. **Navigate**: `browser_navigate` → http://localhost:5173/...
2. **Screenshot**: `browser_screenshot` → auto-saved
3. **Compare**: Screenshot vs `designs/{task_id}.png`

### Visual Comparison Checklist

From `design-mapping.json`:

- ✅ **Layout**: Header, sidebar (25%), main (75%)
- ✅ **Colors**: Status badges, wagon borders, backgrounds
- ✅ **Typography**: h4, h6, body1, caption
- ✅ **Spacing**: 16px gaps, 400px drawer

---

## 📊 Progress Tracking

### Check Progress

```powershell
# From project root
cd "c:\Projects\BDZ Project\Admin-App"

# Count completed tasks
$tasks = Get-Content "docs/composition/tasks.json" | ConvertFrom-Json
$completed = ($tasks | Where-Object { $_.passes -eq $true }).Count
$total = $tasks.Count
Write-Host "Progress: $completed / $total tasks"

# View activity log
Get-Content "docs/composition/activity.md" -Tail 50

# View latest iteration log
Get-ChildItem ".claude/logs" | Sort-Object LastWriteTime -Descending | Select-Object -First 1 | Get-Content -Tail 30
```

### Monitor During Execution

**Terminal 1: Run Ralph**
```powershell
.\ralph.ps1 20
```

**Terminal 2: Watch Activity**
```powershell
Get-Content "../docs/composition/activity.md" -Wait
```

**Terminal 3: Watch Tasks**
```powershell
# Every 10 seconds, show progress
while ($true) {
  Clear-Host
  $tasks = Get-Content "../docs/composition/tasks.json" | ConvertFrom-Json
  $completed = ($tasks | Where-Object { $_.passes -eq $true }).Count
  Write-Host "Completed: $completed / $($tasks.Count)" -ForegroundColor Green
  Start-Sleep 10
}
```

---

## 🚨 Troubleshooting

### Issue: Ralph gets stuck on one task

**Solution:**
1. Check `.claude/logs/` for latest iteration
2. Read error messages
3. Manually fix issue
4. Continue: `.\ralph.ps1 5` (5 more iterations)

### Issue: Tests keep failing

**Solution:**
1. Stop Ralph (Ctrl+C)
2. Manually run tests: `npm test`
3. Fix issues
4. Re-run Ralph

### Issue: Visual comparison fails

**Solution:**
1. Check screenshot was taken (should be logged)
2. Manually compare screenshot with `designs/{id}.png`
3. Check `design-mapping.json` for correct colors/spacing
4. Manually adjust if needed
5. Re-run Ralph

### Issue: Context window fills up

**Solution:** 
- This shouldn't happen! Each iteration is fresh context.
- If it does, check `ralph-iteration.ps1` is being called correctly.

---

## 🎯 Success Criteria

### Per Task

Ralph marks `"passes": true` ONLY when:

1. ✅ Tests pass (npm test + npx playwright test)
2. ✅ Visual match (screenshot comparison) - if designReference
3. ✅ Linter passes (npm run lint)
4. ✅ TypeScript compiles (npm run type-check)
5. ✅ Git committed
6. ✅ Logged in activity.md

### Overall Completion

Ralph outputs `<promise>COMPLETE</promise>` when:

- ALL 30 tasks have `"passes": true`
- All tests pass
- All visual comparisons match
- All commits done

---

## 📝 Output Format

### During Iteration

Ralph will output progress updates:

```
Iteration 3
--------------------------------
Reading tasks.json...
Found task #11: Create Dashboard List Page (TDD)
Phase: RED - Writing failing test...
✓ Test written
✗ Test FAILS (expected)
Phase: GREEN - Implementing...
✓ Component created
✓ Test PASSES
Phase: VISUAL - Screenshot comparison...
✓ Screenshot taken
✗ Design doesn't match (colors off)
Phase: REFACTOR - Adjusting...
✓ Colors adjusted
✓ Re-screenshot matches
✓ All verifications passed
✓ Committed
--- End of iteration 3 ---
```

### Completion Tags

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

Or:

```xml
<promise>COMPLETE</promise>
<total-tasks>30</total-tasks>
<all-passed>true</all-passed>
```

---

## 💡 Best Practices

1. **Start with 10-20 iterations** for testing
2. **Monitor activity.md** to see progress
3. **Check logs/** if something goes wrong
4. **Don't interrupt** during a test run (let it fail/pass naturally)
5. **Review git commits** after completion
6. **Use feedback.md** to give Ralph additional context between runs

---

## 🔗 Related Files

- **Main Setup Docs**: `../docs/composition/README.md`
- **TDD Setup Complete**: `../docs/composition/TDD-SETUP-COMPLETE.md`
- **Plan Instructions**: `../docs/composition/plan.md`
- **Tasks List**: `../docs/composition/tasks.json`
- **Activity Log**: `../docs/composition/activity.md`

---

**Ralph е готов! 🚀 Double-click на `ralph-quick.bat` за да започнеш!**
