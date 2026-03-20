# Prerequisite Steps — Прочети ПРЕДИ имплементация

Тези стъпки се изпълняват **ПРЕДИ** да започнеш да пишеш код по таска.

---

## Стъпка 0: Определи репото на таска

Всеки таск в `tasks.json` трябва да има поле `"repo"`:

| repo стойност | Какво е | Working Directory |
|---------------|---------|-------------------|
| `frontend` | React Admin-App | `C:\Projects\BDZ Project\Admin-App` |
| `backend` | .NET RailRunService | `C:\Projects\BDZ Project\OSDM-Src\DotNetServices\RailRunService` |
| `database` | SQL seed data & schema | `C:\Projects\BDZ Project\OSDM-Src\SQLProjects\RailRunServiceSQL` |

Ако `"repo"` липсва — определи го от описанието:
- UI компонент, страница, React тест → `frontend`
- Endpoint, command, query, DTO, C# → `backend`
- Seed data, миграция, SQL скрипт → `database`

---

## Стъпка 1: Прочети САМО релевантния structure файл

**КРИТИЧНО: Прочети ЕДИН файл — този, който отговаря на `repo`!**

| Ако `repo` е | Прочети този файл |
|---------------|-------------------|
| `frontend` | `C:/Projects/admin-app-frontend-structure.md` |
| `backend` | `C:/Projects/railrun-backend-structure.md` |
| `database` | `C:/Projects/railrun-database-guide.md` |

```bash
# Пример: таскът е frontend
cat C:/Projects/admin-app-frontend-structure.md
```

---

## Стъпка 2: Запомни ключовите конвенции

### За `frontend`:
- Imports: `@/` alias, никога `../../`
- Компоненти: PascalCase `.tsx`, функционални, MUI
- API response: `response.data.data` (double-wrap), exception: stationsApi → `response.data`
- Тестове: `vi.mock('@/hooks/useTranslation')`, mock double-wrap
- i18n: `t('domain.component.element')`, добави в **bg.json И en.json**
- State: React Query за сървърни данни, Zustand за auth/i18n, Redux за UI, useState за локално

### За `backend`:
- Command + Handler в **един файл**
- Return: `Result<T>.Ok(data)` или `Result<T>.Fail(msg, ErrorKind.NotFound)`
- Controller наследява `RailRunControllerBase`, ползва `HandleResult(result)`
- Status стрингове: **UPPERCASE** — `"DRAFT"`, `"ACTIVE"`, `"ARCHIVED"`
- Нов feature: Domain Entity → EF Config → DTO → Command/Query → Controller → DI

### За `database`:
- `IsPhysicallyPresent = 1` за реални места, `0` за структурни елементи (стени, коридор)
- Attributes: JSON array `["WINDOW","FACING_LEFT"]`
- RendererType: `ROWS` (безкупеен), `CABIN` (спален), `COMPARTMENT` (купеен)
- GridX/GridY трябва да са в рамките на CoachLayout.GridWidth / GridLength
- `DefaultCapacity` = COUNT(IsPhysicallyPresent=1 AND type IN (SEAT, BERTH, COUCHETTE, WHEELCHAIR_SPACE))

---

## Стъпка 3: Премини към имплементация

Едва след като си прочел structure файла, започни TDD цикъла (RED → GREEN → VISUAL → REFACTOR) по стъпките в таска.
