# Ralph Wiggum Algorithm - Advanced Features

## 🏗️ Модулна Архитектура

Новата версия е рефакторирана в модулни компоненти:

### Основни Файлове

```
ralph.ps1               → Main loop (извиква итерациите)
ralph-iteration.ps1     → Една итерация (с user-defined стъпки)
ralph-config.json       → Конфигурация
```

### Допълнителни Файлове

```
user-steps.md           → Твои custom стъпки за Claude
feedback.md             → Feedback между итерации
completion-check.ps1    → Custom completion criteria
PROMPT.md               → Основен prompt (както преди)
```

## 📋 Как Работи

### 1. Main Loop (ralph.ps1)

Извиква `ralph-iteration.ps1` N пъти:

```powershell
# Стандартно използване
.\ralph.ps1 10

# С custom config
.\ralph.ps1 10 my-config.json
```

### 2. Iteration Script (ralph-iteration.ps1)

За всяка итерация:

1. **Зарежда config** от `ralph-config.json`
2. **Чете PROMPT.md** - основния prompt
3. **Append user-steps.md** (ако е enabled в config)
4. **Append feedback.md** (от предишна итерация)
5. **Извиква Claude** с пълния prompt
6. **Записва log** (ако е enabled)
7. **Проверява completion criteria**:
   - Built-in patterns (`<promise>COMPLETE</promise>`)
   - User-defined check script (`completion-check.ps1`)
8. **Връща exit code**: 0 = complete, 1 = continue

## ⚙️ Конфигурация (ralph-config.json)

### Prompt Settings

```json
{
  "prompt_file": "PROMPT.md",
  "claude_args": ["--output-format", "text"]
}
```

### User-Defined Steps

```json
{
  "user_defined_steps": {
    "enabled": true,
    "steps_file": "user-steps.md",
    "append_to_prompt": true
  }
}
```

Когато `enabled: true`:
- Чете `user-steps.md`
- Append към основния prompt
- Позволява dynamic инструкции без да променяш PROMPT.md

### Completion Criteria

```json
{
  "completion_criteria": {
    "patterns": [
      "<promise>COMPLETE</promise>",
      "<status>DONE</status>",
      "<finished>true</finished>"
    ],
    "user_defined_file": "completion-check.ps1"
  }
}
```

**Built-in patterns**: Проверява за текст в резултата

**User-defined script**: Извиква PowerShell скрипт който може да има custom логика:
- Проверка на файлове
- API calls
- Сложни условия
- Комбинации от критерии

### Feedback Loop

```json
{
  "feedback": {
    "enabled": true,
    "feedback_file": "feedback.md",
    "append_after_iteration": true
  }
}
```

Позволява:
- Ръчно редактиране на `feedback.md` между итерации
- Автоматично append към следващата итерация
- Итеративно подобряване

### Logging

```json
{
  "logging": {
    "enabled": true,
    "log_dir": "logs",
    "save_iterations": true
  }
}
```

Записва всяка итерация в `logs/iteration-N-timestamp.txt`

## 🎯 Use Cases

### Use Case 1: Feature Development Loop

```json
{
  "prompt_file": "PROMPT.md",
  "user_defined_steps": {
    "enabled": true,
    "steps_file": "feature-requirements.md"
  },
  "completion_criteria": {
    "patterns": ["<feature>COMPLETE</feature>"]
  }
}
```

**Workflow**:
1. Създаваш `feature-requirements.md` с конкретни изисквания
2. Ralph итерира докато Claude върне `<feature>COMPLETE</feature>`
3. Можеш да редактираш requirements между runs

### Use Case 2: Bug Fixing Loop

```json
{
  "user_defined_steps": {
    "enabled": true,
    "steps_file": "bug-description.md"
  },
  "completion_criteria": {
    "user_defined_file": "check-tests-passing.ps1"
  }
}
```

**check-tests-passing.ps1**:
```powershell
param([string]$result)

# Run tests
$testResult = & npm test 2>&1

if ($testResult -match "All tests passed") {
    Write-Output "COMPLETE"
} else {
    Write-Output "CONTINUE"
}
```

### Use Case 3: Deployment Pipeline

```json
{
  "user_defined_steps": {
    "enabled": true,
    "steps_file": "deployment-steps.md"
  },
  "completion_criteria": {
    "user_defined_file": "check-deployment.ps1"
  },
  "feedback": {
    "enabled": true
  }
}
```

**check-deployment.ps1**:
```powershell
param([string]$result)

# Check if deployment is live
try {
    $response = Invoke-WebRequest "https://myapp.com/health"
    if ($response.StatusCode -eq 200) {
        Write-Output "COMPLETE"
    }
} catch {
    Write-Output "CONTINUE"
}
```

## 🚀 Quick Start Examples

### Пример 1: Базово използване (като преди)

```cmd
ralph-quick.bat
```

Просто работи с defaults - без промяна!

### Пример 2: С user-defined стъпки

1. Редактирай `user-steps.md`:
```markdown
## Current Task
Fix the login bug where users can't authenticate with Google

## Requirements
- Check OAuth configuration
- Verify redirect URIs
- Test with multiple accounts
```

2. Стартирай:
```cmd
ralph.exe.bat 10
```

### Пример 3: Custom completion criteria

1. Създай `my-completion.ps1`:
```powershell
param([string]$result)

if (Test-Path "deployment-success.txt") {
    Write-Output "COMPLETE"
} else {
    Write-Output "CONTINUE"
}
```

2. Обнови `ralph-config.json`:
```json
{
  "completion_criteria": {
    "user_defined_file": "my-completion.ps1"
  }
}
```

3. Стартирай:
```powershell
.\ralph.ps1 20
```

### Пример 4: Feedback loop между итерации

1. Стартирай първа итерация:
```cmd
ralph.exe.bat 5
```

2. След итерация 1, редактирай `feedback.md`:
```markdown
## Observations
- The authentication flow is partially working
- Need to add error handling for edge cases

## Next Steps
- Add try-catch blocks
- Improve error messages
```

3. Стартирай отново - feedback се append автоматично!

## 🔧 Advanced Configuration

### Multiple Config Files

Можеш да имаш различни configs за различни задачи:

```
ralph-config-dev.json      → Development mode
ralph-config-prod.json     → Production deployment
ralph-config-testing.json  → Testing & QA
```

Използване:
```powershell
.\ralph.ps1 10 ralph-config-testing.json
```

Или:
```cmd
ralph-with-config.bat 10 ralph-config-prod.json
```

### Conditional Steps

В `user-steps.md` можеш да имаш conditional logic:

```markdown
## Iteration-Specific Instructions

### If this is iteration 1-3:
- Focus on implementation
- Don't worry about optimization

### If this is iteration 4+:
- Optimize performance
- Add comprehensive error handling
- Write documentation
```

### Chaining Multiple Prompts

Можеш да chain различни prompts:

```json
{
  "prompt_file": "PROMPT-step1.md"
}
```

След completion, промени config и стартирай отново с нов prompt!

## 📊 Monitoring & Debugging

### Log Analysis

Всички итерации се записват в `logs/`:

```cmd
dir logs
type logs\iteration-5-2026-01-31_14-30-00.txt
```

### Debug Mode

Добави в config:
```json
{
  "debug": {
    "verbose": true,
    "save_prompts": true
  }
}
```

## 💡 Best Practices

### 1. Incremental Steps

Не правиразбивай сложни задачи на много малки итерации:

**Bad**: 100 iterations за една задача
**Good**: 10-20 iterations с ясни стъпки

### 2. Clear Completion Criteria

Винаги дефинирай ясни критерии:

```json
{
  "completion_criteria": {
    "patterns": [
      "<task>DONE</task>",
      "All requirements met",
      "Ready for review"
    ]
  }
}
```

### 3. Use Feedback Loops

Редактирай `feedback.md` между iterations за по-добър контрол:

```markdown
## Iteration 3 Feedback
- Good progress on authentication
- ❌ Still missing error handling
- ➡️ Next: Focus on edge cases
```

### 4. Version Control Config

Commit различни configs за различни workflows:

```
git add ralph-config-*.json
git commit -m "Add config for different workflows"
```

## 🎨 Integration с External Tools

### NPM Scripts

```json
{
  "scripts": {
    "ralph": "powershell -File ralph.ps1 10",
    "ralph:prod": "powershell -File ralph.ps1 20 ralph-config-prod.json"
  }
}
```

### CI/CD Integration

```yaml
# .github/workflows/ralph.yml
- name: Run Ralph Algorithm
  run: |
    powershell -ExecutionPolicy Bypass -File ralph.ps1 15
```

## 🆘 Troubleshooting

**Q: User steps не се добавят към prompt?**
A: Провери `"enabled": true` в config и че `user-steps.md` съществува.

**Q: Completion criteria не работят?**
A: Debug с logging enabled - виж точния резултат в `logs/`.

**Q: Custom completion script не се извиква?**
A: Провери пътя в config и че скриптът е валиден PowerShell.

**Q: Feedback не се append?**
A: Proveri `"append_after_iteration": true` и че има `feedback.md` файл.

---

🎉 **Готово!** Сега имаш пълен контрол над Ralph Wiggum алгоритъма!
