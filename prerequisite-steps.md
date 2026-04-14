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

## Стъпка 3: Ако таскът е wagon migration — прочети и migration спецификацията

Ако таскът има `"migrationRef"` поле — прочети го **в допълнение** към structure файла от Стъпка 2.

`"migrationRef"` съдържа относителен път от `C:\Projects\wagon-migrations\`. Например:
- `"migrationRef": "02_series_15-63.md"` → прочети `C:\Projects\wagon-migrations\02_series_15-63.md`

**Винаги прочети и общата референция:**
```bash
cat C:/Projects/wagon-migrations/_COMMON_REFERENCE.md
```

Тя съдържа OSDM кодове, icon mapping, JSON структура и fallback стратегия.

---

## Стъпка 4: Правила за database промени

Ако `repo` = **database**, спазвай стриктно:

- **НИКОГА не променяй съществуващи seed/migration скриптове** — те вече са изпълнени в Azure и не се преизпълняват.
- Промените се правят **само чрез НОВИ post-deployment скриптове** в `PostDeployment/` папката.
- Именувай ги с пореден номер: `PostDeployment/042_AddOsdmLayoutToSeries1563.sql`
- Скриптът трябва да е **idempotent** — да може да се изпълни многократно без грешка (ползвай `IF NOT EXISTS`, `MERGE`, или `WHERE NOT EXISTS` guards).
- Добави `PRINT` съобщение в началото за проследимост.
- Регистрирай новия скрипт в `PostDeployment/Script.PostDeployment.sql` с `SQLCMD :r` синтаксис.

**Пример:**
```sql
-- PostDeployment/042_AddOsdmLayoutToSeries1563.sql
PRINT 'Adding OSDM layout data for series 15-63...'

IF NOT EXISTS (SELECT 1 FROM dbo.CoachLayoutInternals WHERE CoachLayoutId = @layoutId)
BEGIN
    INSERT INTO dbo.CoachLayoutInternals (CoachLayoutId, IconCode, GridX, GridY)
    VALUES ...
END
```

---

## Стъпка 5: Прочети и спазвай structure файловете

При **frontend** таскове — ЗАДЪЛЖИТЕЛНО прочети и спазвай:
```bash
cat C:/Projects/admin-app-frontend-structure.md
```

При **backend** таскове — ЗАДЪЛЖИТЕЛНО прочети и спазвай:
```bash
cat C:/Projects/railrun-backend-structure.md
```

Тези файлове съдържат актуалната архитектура, конвенции за именуване, folder structure и patterns.
**Не импровизирай** — следвай установените patterns от файла.

---

## Стъпка 6: При рефакторинг — regression guard

Ако таскът е от категория `"refactor"`:
1. **ПРЕДИ всяка промяна** пусни `npm test && npm run type-check` и запиши резултата
2. **Не променяй логика** — само местиш код между файлове + добавяш import/export
3. **СЛЕД всяка промяна** пусни отново `npm test && npm run type-check`
4. Ако нещо фейлва — **ВЕДНАГА rollback** и анализирай какво е счупено
5. Всички съществуващи визуализации ТРЯБВА да продължат да работят както преди

---

## Стъпка 7: Имплементирай

Спазвай конвенциите от файла, който прочете. Започни TDD цикъла по стъпките в таска.
