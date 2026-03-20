# Prerequisite Steps — Прочети ПРЕДИ имплементация

След като избереш таск, но **ПРЕДИ** да пишеш код — изпълни тези стъпки.

---

## Стъпка 1: Определи repo на таска

Погледни полето `"repo"` в таска от `tasks.json`:

| repo | Какво е | Working Directory |
|------|---------|-------------------|
| `frontend` | React Admin-App | `C:\Projects\BDZ Project\Admin-App` |
| `backend` | .NET RailRunService | `C:\Projects\BDZ Project\OSDM-Src\DotNetServices\RailRunService` |
| `database` | SQL seed data & schema | `C:\Projects\BDZ Project\OSDM-Src\SQLProjects\RailRunServiceSQL` |

Ако `"repo"` липсва — определи от описанието на таска:
- UI компонент, страница, React тест → `frontend`
- Endpoint, command, query, DTO, C# → `backend`
- Seed data, миграция, SQL скрипт → `database`

---

## Стъпка 2: Прочети САМО файла за твоето repo

**НЕ чети другите! Прочети ЕДИНСТВЕНО файла, който съответства на `repo`:**

- Ако `repo` = **frontend** →
  ```bash
  cat C:/Projects/admin-app-frontend-structure.md
  ```

- Ако `repo` = **backend** →
  ```bash
  cat C:/Projects/railrun-backend-structure.md
  ```

- Ако `repo` = **database** →
  ```bash
  cat C:/Projects/railrun-database-guide.md
  ```

---

## Стъпка 3: Имплементирай

Спазвай конвенциите от файла, който прочете. Започни TDD цикъла по стъпките в таска.
