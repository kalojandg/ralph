# Prerequisite Steps — Прочети ПРЕДИ имплементация

След като избереш таск, но **ПРЕДИ** да пишеш код — изпълни тези стъпки.

---

## Стъпка 1: Определи repo и намери го в mapping-а

Погледни полето `"repo"` в таска от `tasks.json` (`frontend` / `backend` / `database`).

**Единственият source of truth за „кое репо къде е на диска и кой reference да чета" е mapping файлът:**
```
C:/Users/kaloyan.georgiev/Projects/ralph/ralph reference/project reference/repos.json
```

Прочети го, намери своя `repo` ключ и вземи оттам:
- `location` → работната директория (`cd` тук преди да пишеш код)
- `reference` → архитектурния файл за това репо (в същата `project reference/` папка)
- `commands` → build / test / lint команди за това репо

**Ако `"repo"` липсва** в таска — изведи го по `fallback.rules` в `repos.json`:
- UI компонент, страница, React тест → `frontend`
- Endpoint, command, query, DTO, C# → `backend`
- Seed data, миграция, SQL скрипт → `database`

---

## Стъпка 2: Прочети САМО reference файла за твоето repo

**НЕ чети другите reference файлове! Прочети ЕДИНСТВЕНО този, който `repos.json` сочи за твоя `repo`:**

```bash
# Пример за backend (заместИ с reference-а от твоя repo запис):
cat "C:/Users/kaloyan.georgiev/Projects/ralph/ralph reference/project reference/railrun-backend-structure.md"
```

| repo | reference файл (в `project reference/`) |
|------|------------------------------------------|
| `frontend` | `admin-app-frontend-structure.md` |
| `backend` | `railrun-backend-structure.md` |
| `database` | `railrun-database-guide.md` |

Reference файлът ти казва **къде са файловете в това репо и какви patterns се ползват** — спазвай ги, не импровизирай.

---

## Стъпка 3: Ако таскът е wagon migration — прочети и migration спецификацията

Ако таскът има `"migrationRef"` поле — прочети го **в допълнение** към structure файла от Стъпка 2.

`"migrationRef"` съдържа относителен път от `C:\Users\kaloyan.georgiev\Projects\wagon-migrations\`. Например:
- `"migrationRef": "02_series_15-63.md"` → прочети `C:\Users\kaloyan.georgiev\Projects\wagon-migrations\02_series_15-63.md`

**Винаги прочети и общата референция:**
```bash
cat C:/Users/kaloyan.georgiev/Projects/wagon-migrations/_COMMON_REFERENCE.md
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

## Стъпка 5: Спазвай reference файла (вече прочетен в Стъпка 2)

Reference файлът от Стъпка 2 съдържа актуалната архитектура, конвенции за именуване, folder structure и patterns за твоето репо. **Не импровизирай** — следвай установените patterns.

При таск, който **засяга API contract** (endpoint URL / DTO shape между FE и BE) — прочети **и двата** reference файла (frontend + backend) от `project reference/`.

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
