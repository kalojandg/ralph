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
