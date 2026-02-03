# Ralph Wiggum TDD для БДЖ Compositions Module

## 🎯 Какво е това?

Автономен TDD (Test-Driven Development) workflow за Ralph Wiggum агента, специално конфигуриран за имплементация на БДЖ Compositions модул с:

- ✅ **TDD Workflow**: RED → GREEN → VISUAL → REFACTOR → DONE
- ✅ **Visual Testing**: Playwright MCP screenshot comparison с design mockups
- ✅ **localStorage Mock Backend**: Няма реален API, всичко е в localStorage
- ✅ **Step-by-step Execution**: Всяка стъпка се изпълнява поотделно с verification
- ✅ **Fresh Context**: Всяка итерация с нов контекст (no bloat)

---

## 🚀 Бързо Стартиране

### 1️⃣ Двойно кликни тук за старт:

```
START-RALPH-TDD.bat     ← 20 iterations (препоръчително)
ralph-quick.bat         ← 10 iterations (бързо тестване)
```

### 2️⃣ Или от PowerShell:

```powershell
cd "c:\Projects\BDZ Project\Admin-App\.claude"
.\ralph.ps1 20
```

---

## 📊 Проследяване на прогреса

### Проверка на статус:

```
CHECK-PROGRESS.bat      ← Колко tasks са завършени
```

### Виж logs:

```
VIEW-LOGS.bat           ← Последната итерация
explorer logs           ← Всички logs
```

### Виж activity log:

```
notepad ..\docs\composition\activity.md
```

---

## 📂 Структура

### Главни файлове

| Файл | Описание |
|------|----------|
| `ralph.ps1` | Main loop (вика ralph-iteration.ps1) |
| `ralph-iteration.ps1` | Single iteration executor |
| `ralph-config.json` | Configuration (TDD enabled) |
| `PROMPT.md` | Main TDD instructions за Claude |
| `user-steps.md` | Visual feedback specifics |
| `completion-check.ps1` | Check if all tasks done |
| `feedback.md` | Feedback между iterations |

### Launcher скриптове

| Файл | Действие |
|------|----------|
| `START-RALPH-TDD.bat` | ⭐ Старт с 20 iterations |
| `ralph-quick.bat` | Бързо тестване (10 iterations) |
| `CHECK-PROGRESS.bat` | Виж прогрес |
| `VIEW-LOGS.bat` | Виж последния log |
| `RESET-TASKS.bat` | ⚠️ Reset всички tasks (testing only) |

### Reference файлове

| Файл | Описание |
|------|----------|
| `..\docs\composition\tasks.json` | 30 tasks (TDD format) |
| `..\docs\composition\PRD.json` | Requirements |
| `..\docs\composition\activity.md` | Activity log (Ralph updates) |
| `..\docs\composition\designs\` | UI mockups за comparison |

---

## 🎯 TDD Workflow

Ralph следва този цикъл за всеки UI таск:

```
1. RED Phase
   └─ Напиши failing test
   └─ Run test → verify FAILS ✅

2. GREEN Phase
   └─ Имплементирай minimal code
   └─ Run test → verify PASSES ✅

3. VISUAL Phase
   └─ Start dev server (npm run dev)
   └─ Playwright MCP screenshot
   └─ Compare с designs/{task_id}.png

4. REFACTOR Phase
   └─ If not match:
      └─ Adjust layout/colors/spacing
      └─ Re-screenshot
      └─ Iterate until MATCHES ✅

5. DONE Phase
   └─ Verify ALL:
      ✅ Tests pass
      ✅ Design matches
      ✅ Linter passes
      ✅ TypeScript compiles
   └─ Mark "passes": true
   └─ Git commit
```

---

## 🧪 Testing Stack

| Test Type | Command | Purpose |
|-----------|---------|---------|
| Unit/Component | `npm test` | Component logic |
| E2E | `npx playwright test` | User flows |
| Linter | `npm run lint` | Code quality |
| TypeScript | `npm run type-check` | Type safety |
| Visual | Playwright MCP | Design match |

---

## 🎨 Visual Testing

### Playwright MCP

Ralph използва `cursor-ide-browser` MCP за:

1. **Navigate**: `browser_navigate` → http://localhost:5173/...
2. **Screenshot**: `browser_screenshot` → auto-saved
3. **Compare**: Screenshot vs `designs/{task_id}.png`

### Comparison Checklist

От `design-mapping.json`:

- ✅ Layout (header, sidebar 25%, main 75%)
- ✅ Colors (badges, borders, backgrounds)
- ✅ Typography (h4, h6, body1, caption)
- ✅ Spacing (16px gaps, 400px drawer)

---

## 📋 Success Criteria

Ralph маркира `"passes": true` САМО когато:

1. ✅ Tests pass (npm test + npx playwright test)
2. ✅ Visual match (screenshot comparison) - ако има designReference
3. ✅ Linter passes (npm run lint)
4. ✅ TypeScript compiles (npm run type-check)
5. ✅ Git committed
6. ✅ Logged in activity.md

---

## 🚨 Troubleshooting

### Ralph се зацикли на един таск

```powershell
# Спри го (Ctrl+C)
# Виж logs
.\VIEW-LOGS.bat

# Fix manually ако трябва
npm test
npm run lint

# Продължи
.\ralph.ps1 5
```

### Тестове не минават

```powershell
# Спри Ralph
# Run tests manually
npm test
npx playwright test

# Fix issues
# Re-run Ralph
.\ralph.ps1 10
```

### Visual comparison fails

```powershell
# Check screenshot
explorer screenshots

# Compare with mockup
explorer ..\docs\composition\designs

# Check color/spacing rules
notepad ..\docs\composition\designs\design-mapping.json

# Manual fix if needed
# Re-run Ralph
```

---

## 📊 Progress Tracking

### CLI Commands

```powershell
# Count completed
$tasks = Get-Content "..\docs\composition\tasks.json" | ConvertFrom-Json
$completed = ($tasks | Where-Object { $_.passes -eq $true }).Count
$total = $tasks.Count
Write-Host "Progress: $completed / $total"

# View activity
Get-Content "..\docs\composition\activity.md" -Tail 50

# View latest log
Get-ChildItem "logs" | Sort-Object LastWriteTime -Descending | Select-Object -First 1 | Get-Content -Tail 30
```

### Live Monitoring

**Terminal 1: Run Ralph**
```powershell
.\ralph.ps1 20
```

**Terminal 2: Watch Progress**
```powershell
while ($true) {
  Clear-Host
  $tasks = Get-Content "..\docs\composition\tasks.json" | ConvertFrom-Json
  $completed = ($tasks | Where-Object { $_.passes -eq $true }).Count
  Write-Host "Completed: $completed / $($tasks.Count)" -ForegroundColor Green
  Get-Content "..\docs\composition\activity.md" -Tail 10
  Start-Sleep 10
}
```

---

## 🎯 Output Format

### During Iteration

```
Iteration 3
--------------------------------
Task #11: Create Dashboard List Page (TDD)
Phase: RED - Writing test...
✓ Test written
✗ Test FAILS (expected)
Phase: GREEN - Implementing...
✓ Component created
✓ Test PASSES
Phase: VISUAL - Screenshot...
✓ Screenshot taken
✗ Design doesn't match
Phase: REFACTOR - Adjusting...
✓ Colors adjusted
✓ Design matches
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

Or when done:

```xml
<promise>COMPLETE</promise>
<total-tasks>30</total-tasks>
<all-passed>true</all-passed>
```

---

## 💡 Best Practices

1. ✅ **Първи път**: Run с 10 iterations за testing
2. ✅ **Monitor**: Check `CHECK-PROGRESS.bat` често
3. ✅ **Logs**: Review `logs/` ако нещо не върви
4. ✅ **Don't interrupt**: Let tests fail/pass naturally
5. ✅ **Review commits**: `git log --oneline` след completion

---

## 🔗 Документация

- 📖 **TDD Setup Complete**: `..\docs\composition\TDD-SETUP-COMPLETE.md`
- 📖 **Plan Instructions**: `..\docs\composition\plan.md`
- 📖 **README**: `..\docs\composition\README.md`
- 📖 **Detailed TDD Guide**: `README-TDD.md` (в тази папка)

---

## 🎉 Quick Start Reminder

1. **Double-click**: `START-RALPH-TDD.bat`
2. **Wait**: Ralph ще работи автономно
3. **Monitor**: `CHECK-PROGRESS.bat` за статус
4. **Review**: `activity.md` за резултати
5. **Done**: Когато видиш `<promise>COMPLETE</promise>`

---

**Ralph е готов! 🚀 Двойно кликни на START-RALPH-TDD.bat за да започнеш!**
