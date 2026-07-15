# Ralph Project Structure

## 📁 Core Files

### Execution Files
```
ralph.ps1              → Main loop (извиква ralph-iteration.ps1 N пъти)
ralph-iteration.ps1    → Single iteration (с user-defined стъпки)
ralph.sh               → Original bash version
```

### Launcher Files (.bat) - За Windows
```
ralph-quick.bat        → Quick start с 10 iterations
ralph.exe.bat          → Interactive или command-line
ralph.bat              → Pure batch implementation
ralph-bash.bat         → Wrapper за ralph.sh (изисква Git Bash)
ralph-with-config.bat  → Launcher с custom config file
```

### Configuration & User Files
```
ralph-config.json      → Main configuration
user-steps.md          → Custom стъпки за Claude (append to prompt)
feedback.md            → Feedback между итерации
completion-check.ps1   → Custom completion criteria script
PROMPT.md              → Main prompt (създай го!)
```

### Documentation
```
README-BG.md           → Основна документация
RALPH-ADVANCED.md      → Advanced features guide
STRUCTURE.md           → Този файл
КЛИКНИ ТУК.txt         → Quick start инструкции
```

### Utility Scripts
```
compile-to-exe.ps1     → Компилира ralph.ps1 в .exe
create-shortcut.ps1    → Създава desktop shortcut
```

### Runtime Files (created automatically)
```
logs/                  → Iteration logs (ако enabled в config)
  ├── iteration-1-timestamp.txt
  ├── iteration-2-timestamp.txt
  └── ...
```

## 🔄 Execution Flow

```
┌─────────────────────────────────────────────────────────┐
│  User starts:                                           │
│  • ralph-quick.bat                                      │
│  • ralph.exe.bat                                        │
│  • .\ralph.ps1 10                                       │
└─────────────────────┬───────────────────────────────────┘
                      │
                      ▼
        ┌─────────────────────────────┐
        │     ralph.ps1 (main loop)   │
        │  - Loads config             │
        │  - Loops N times            │
        └──────────┬──────────────────┘
                   │
                   │ For each iteration:
                   ▼
        ┌─────────────────────────────┐
        │  ralph-iteration.ps1        │
        │  1. Load config             │
        │  2. Read PROMPT.md          │
        │  3. Append user-steps.md    │
        │  4. Append feedback.md      │
        │  5. Execute Claude CLI      │
        │  6. Save log                │
        │  7. Check completion        │
        └──────────┬──────────────────┘
                   │
                   ├─── Exit 0 → COMPLETE! ✓
                   └─── Exit 1 → Continue to next iteration
```

## 🎯 Configuration Flow

```
ralph-config.json
├── prompt_file → PROMPT.md
├── user_defined_steps
│   ├── enabled → true/false
│   └── steps_file → user-steps.md
├── completion_criteria
│   ├── patterns → ["<promise>COMPLETE</promise>", ...]
│   └── user_defined_file → completion-check.ps1
├── feedback
│   ├── enabled → true/false
│   └── feedback_file → feedback.md
└── logging
    ├── enabled → true/false
    └── log_dir → logs/
```

## 🚀 Quick Start Paths

### Path 1: Супер бързо (за нетехнически юзъри)
```
1. Двойно кликване на: ralph-quick.bat
2. Готово!
```

### Path 2: Интерактивно (за юзъри които искат контрол)
```
1. Двойно кликване на: ralph.exe.bat
2. Въведи брой итерации
3. Готово!
```

### Path 3: Command line (за разработчици)
```powershell
# Базово
.\ralph.ps1 10

# С custom config
.\ralph.ps1 20 my-config.json

# От batch
ralph.exe.bat 15
```

### Path 4: Advanced (за power users)
```
1. Редактирай ralph-config.json
2. Редактирай user-steps.md
3. (Optional) Създай completion-check.ps1
4. .\ralph.ps1 10
5. Редактирай feedback.md между iterations
```

## 📝 Minimal Setup

За да работи скриптът, **минимум** трябва:

```
✓ claude CLI (инсталиран и в PATH)
✓ PROMPT.md (създай го!)
✓ ralph.ps1 + ralph-iteration.ps1
✓ ralph-config.json (или ще използва defaults)
```

Всичко останало е optional!

## 🔧 Customization Levels

### Level 0: Zero Config
```
- Използвай ralph-quick.bat
- Няма нужда от нищо друго
- Работи с defaults
```

### Level 1: Basic Config
```
- Редактирай PROMPT.md
- Използвай ralph.exe.bat
- Контрол над iterations
```

### Level 2: User Steps
```
- Създай user-steps.md
- Enable в ralph-config.json
- Dynamic instructions без да променяш PROMPT.md
```

### Level 3: Full Control
```
- Custom ralph-config.json
- User-defined completion-check.ps1
- Feedback loops с feedback.md
- Logging enabled
- Multiple config files за различни workflows
```

## 🎨 Example Workflows

### Workflow 1: Feature Development
```
Files needed:
- PROMPT.md → "Implement user authentication"
- user-steps.md → Specific requirements
- ralph-config.json → Default settings

Command:
.\ralph.ps1 15
```

### Workflow 2: Bug Fixing
```
Files needed:
- PROMPT.md → "Fix login bug"
- completion-check.ps1 → Runs tests
- ralph-config.json → Custom completion criteria

Command:
.\ralph.ps1 10
```

### Workflow 3: Deployment
```
Files needed:
- PROMPT.md → "Deploy to production"
- user-steps.md → Deployment checklist
- completion-check.ps1 → Checks deployment health
- feedback.md → Manual verification steps

Command:
.\ralph.ps1 20 ralph-config-prod.json
```

## 🆘 Dependencies

### Required
- **Windows** (тестван на Windows 10/11)
- **PowerShell** 5.1+ (built-in in Windows)
- **Claude CLI** (installed and in PATH)

### Optional
- **Git Bash** (за ralph-bash.bat)
- **ps2exe module** (за compile-to-exe.ps1)

## 📊 File Size Reference

```
Small files (<1KB):
- *.bat files
- PROMPT.md (обикновено)

Medium files (1-5KB):
- ralph.ps1
- ralph-iteration.ps1
- completion-check.ps1

Config/Data files (varies):
- ralph-config.json
- user-steps.md
- feedback.md
- logs/*.txt
```

---

🎉 Всичко е готово! Изчупи този Ralph Wiggum алгоритъм! 🚀
