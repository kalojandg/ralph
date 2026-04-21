# Ralph Wiggum TDD Iteration - Compositions Module

## Context Files

Прочети следните файлове за пълен context:

1. **C:/Projects/ralph/activity.md** - История на свършената работа
2. **C:/Projects/ralph/tasks.json** - Task list (твоя source of truth)
3. **C:/Projects/BDZ Project/Admin-App/docs/composition/PRD.json** - Requirements и TDD methodology
4. **C:/Projects/BDZ Project/Admin-App/docs/composition/designs/** - UI mockups за visual testing

**Working directories по repo:**
- `frontend` → `C:\Projects\BDZ Project\Admin-App`
- `backend` → `C:\Projects\BDZ Project\OSDM-Src\DotNetServices\RailRunService`
- `database` → `C:\Projects\BDZ Project\OSDM-Src\SQLProjects\RailRunServiceSQL`

## Your Mission This Iteration

Работи върху **ЕДИН ЕДИНСТВЕН ТАСК** от `C:/Projects/ralph/tasks.json` където `"passes": false`.

### 🚨 CRITICAL: ONE TASK PER ITERATION — THEN STOP

Тази итерация = ТОЧНО ЕДИН таск. След като го завършиш и къмитнеш:
1. Изведи `<task-complete>` XML
2. Изведи `<status>CONTINUE</status>` или `<promise>COMPLETE</promise>`
3. **СПРИ ВЕДНАГА. НЕ продължавай със следващ таск.**
4. Всеки следващ таск ще бъде изпълнен от **нов агент в нова итерация** с чист context.

**Причина:** Избягваме context bloating. Всяка итерация = нов агент = чист context window.
**Ако продължиш с втори таск в същата итерация — нарушаваш Ralph Wiggum алгоритъма.**

## TDD Workflow (RED → GREEN → VISUAL → REFACTOR)

### Step 1: Find Next Task

```powershell
# Прочети C:/Projects/ralph/tasks.json и намери първия таск с "passes": false
# Прочети ВСИЧКИ steps за този таск
# Note: Ако има "designReference" и "tddWorkflow": true → следвай TDD phases
```

### Step 2: Execute Task Steps ONE BY ONE

**КРИТИЧНО:** Прави стъпките **ЕДНА ПО ЕДНА**, не всички наведнъж!

#### Ако таск има `"tddWorkflow": true`:

**Phase RED (Write Failing Test):**
- Изпълни steps с `"phase": "RED"`
- Напиши failing test (unit test или E2E test с Playwright)
- **RUN TEST** → verify it **FAILS**
- Ако не фейлва → тестът не тества правилното нещо!

**Phase GREEN (Minimal Implementation):**
- Изпълни steps с `"phase": "GREEN"`
- Имплементирай **минимален код** за да минава тестът
- **RUN TEST AGAIN** → verify it **PASSES**

**Phase VISUAL (Screenshot Comparison):**
- Изпълни steps с `"phase": "VISUAL"`
- Start dev server: `npm run dev`
- **Use cursor-ide-browser MCP for screenshots**:
  ```javascript
  // Navigate to component/page
  CallMcpTool({
    server: "cursor-ide-browser",
    toolName: "browser_navigate",
    arguments: { url: "http://localhost:5173/..." }
  })
  
  // Take screenshot
  CallMcpTool({
    server: "cursor-ide-browser",
    toolName: "browser_screenshot",
    arguments: { fullPage: true }
  })
  ```
- **Compare screenshot** с `@docs/composition/designs/{task_id}.png`
- Провери: Layout ✅ Colors ✅ Typography ✅ Spacing ✅

**Phase REFACTOR (Iterate Until Matches):**
- Изпълни steps с `"phase": "REFACTOR"`
- Ако дизайнът НЕ съвпада:
  - Adjust layout/colors/spacing/typography
  - Reference: `@docs/composition/designs/design-mapping.json`
  - Re-screenshot and compare again
- **ITERATE** докато screenshot съвпада с mockup

**Phase DONE (Verification):**
- Изпълни steps с `"phase": "DONE"`
- **VERIFY ALL:**
  - ✅ Tests pass: `npm test && npx playwright test`
  - ✅ Visual match: Screenshot съвпада с design mockup
  - ✅ No linter errors: `npm run lint`
  - ✅ TypeScript compiles: `npm run type-check`

#### Ако таск НЯМА `"tddWorkflow"` (setup tasks):

- Изпълни steps последователно (една по една!)
- Verify functionality след всяка стъпка
- Run relevant commands (npm install, create folders, etc.)

### Step 3: Verification Loop

**СЛЕД изпълнение на ВСИЧКИ steps:**

1. **Run Tests:**
   ```bash
   npm test                # Unit/component tests
   npx playwright test     # E2E tests
   ```
   
2. **Check Linter:**
   ```bash
   npm run lint
   ```

3. **Visual Comparison** (ако има designReference):
   - Use Playwright MCP screenshot
   - Compare with `designs/{task_id}.png`
   - Check: Layout, Colors, Typography, Spacing

4. **IF ANYTHING FAILS:**
   - Go back and fix
   - Re-run tests
   - Re-screenshot and compare
   - **ITERATE** until ALL verifications pass

5. **ONLY WHEN ALL PASS:**
   - Proceed to Step 4

### Step 4: Mark Complete

**САМО АКО ВСИЧКИ КРИТЕРИИ СА ✅:**

1. **Update C:/Projects/ralph/tasks.json:**
   ```json
   // Change for completed task:
   "passes": false → "passes": true
   ```

2. **Log in C:/Projects/ralph/activity.md:**
   ```markdown
   ## [2026-02-03 HH:MM] - Task #{id}: {description}
   
   **Status:** ✅ Complete
   
   **TDD Phase:** RED → GREEN → VISUAL → REFACTOR → DONE
   
   **What was done:**
   ### RED Phase
   - Step X: Wrote failing test in {file}
   - Step Y: Ran test - FAILS ✅
   
   ### GREEN Phase
   - Step X: Implemented {component}
   - Step Y: Ran test - PASSES ✅
   
   ### VISUAL Phase
   - Step X: Started dev server
   - Step Y: cursor-ide-browser MCP screenshot
   - Step Z: Compared with design {id}.png
   - Result: Layout ✅ Colors ✅ Typography ✅ Spacing ✅
   
   **Files modified:**
   - {file1}
   - {file2}
   
   **Git commit:**
   - `feat(compositions): {exact task.description from tasks.json}`
   - Example: `feat(compositions): Create Dashboard List Page with compositions table`
   
   ---
   ```

3. **Git commit:**
   
   **IMPORTANT:** Use the exact task `description` from tasks.json as commit message!
   
   ```bash
   git add .
   git commit -m "feat(compositions): {exact task.description from tasks.json}"
   ```
   
   **Example:** For Task #11 with description "Create Dashboard List Page with compositions table":
   ```bash
   git commit -m "feat(compositions): Create Dashboard List Page with compositions table"
   ```
   
   **DO NOT:**
   - git init
   - git push
   - change remotes
   - make up your own commit message (use exact description!)

### Step 5: Report Status AND STOP

**Output exactly this, then STOP — do NOT continue with another task:**

```xml
<task-complete>
  <task-id>{id}</task-id>
  <tests>PASSED</tests>
  <visual>MATCHED</visual>
  <committed>YES</committed>
</task-complete>
```

**Then check: are there more tasks with passes: false?**

If YES — output this and **STOP IMMEDIATELY** (next task = next iteration = new agent):
```xml
<status>CONTINUE</status>
<next-task>{next_task_id}</next-task>
```

If NO (all tasks done) — output:
```xml
<promise>COMPLETE</promise>
<total-tasks>{count}</total-tasks>
<all-passed>true</all-passed>
```

### 🛑 AFTER Step 5: YOUR ITERATION IS OVER

**Do NOT:**
- Start working on the next task
- Read the next task's steps
- "Prepare" anything for the next iteration
- Continue writing code

**The Ralph loop will spawn a NEW agent with clean context for the next task.**

## Architecture Reference Files

**ЗАДЪЛЖИТЕЛНО преди да започнеш таск прочети съответния файл. Патърните в тези файлове са ПРАВИЛА, не препоръки — не следваш ли ги, PR-ът ще получи коментари и ще се връща за преработка.**

| Тип таск | Файл за четене | Какво съдържа |
|----------|---------------|---------------|
| **[BE] Backend** | `C:/Projects/railrun-backend-structure.md` | .NET 8 Clean Architecture, CQRS, **Aggregate Repositories + IUnitOfWork** (избягва multiple SaveChanges), nav-property за create-graph, DTOs location (**API request/response DTOs → `*.API/DTOs/`, НЕ в контролера**), Validation |
| **[FE] Frontend** | `C:/Projects/admin-app-frontend-structure.md` | React 19 + TypeScript + Vite, folder structure, routing, API layer, React Query hooks, MUI components, i18n, testing patterns |
| **[BE] Database** | `C:/Projects/railrun-database-guide.md` | SQL Server schema, WagonTypes/CoachLayouts/SeatDefinitions таблици, seed data, migrations, grid coordinate system |
| **[E2E] End-to-end** | Прочети и трите файла | FE→BE→DB пълен workflow |

**Ако таскът засяга API contract (endpoint URL, DTO shape) — прочети И frontend И backend файловете!**

### 🚨 [BE] Pre-flight checklist (чети преди ВСЕКИ backend таск)

Преди да напишеш код в `RailRunService.API` / `.Application` / `.Infrastructure`, отвори `C:/Projects/railrun-backend-structure.md` секция **"Code Patterns"** и потвърди, че разбираш тези правила. Всички са извлечени от реални PR ревюта:

1. **DTO location** — API request/response records/classes се дефинират в `*.API/DTOs/{Feature}*.cs`, НИКОГА вътре в `*Controller.cs`. Application-layer DTOs (commands/queries) са в `*.Application/DTOs/`.
2. **Един логически write → един `SaveChangesAsync`.** Ако handler-ът пише в 2+ таблици (delete aggregate, replace child collection, create parent+child), използвай **custom `IXxxRepository` + `IUnitOfWork`**, НЕ верига от `AddAsync`/`DeleteAsync` върху generic `IRepository<T,long>` (всеки генеричен call е отделна транзакция → partial failure).
3. **Create graph чрез nav property** — `child.Parent = parent;` + `await _childRepo.AddAsync(child);` вместо `await _parentRepo.AddAsync(parent); child.ParentId = parent.Id; await _childRepo.AddAsync(child);`. EF traverse-ва графа и insert-ва всичко в едно SaveChanges.
4. **Delete aggregate чрез nav property + Include** — `_context.Parents.Include(p => p.Children).ThenInclude(c => c.GrandChildren).FirstOrDefaultAsync(...)`, после `RemoveRange` на децата + `Remove` на parent, после един `SaveChanges`.
5. **Extract constants; don't hardcode** — magic strings като `"DRAFT"`, `"ROWS"`, хардкоднати grid sizes, pre-baked JSON strings — в `private const`. Ако имаш seed JSON, сериализирай от анонимен обект (`JsonSerializer.Serialize(new { ... }, LayoutJsonOptions)`), не хардкодвай stringified JSON.
6. **Без излишни коментари** — `// Validate X unique`, `// Create WagonType with DRAFT status` не добавят информация, която имената на методите/константите вече казват. Махай ги.

### 📛 Existing aggregate repos (НЕ преоткривай, следвай образеца)

| Репо | Кога се ползва | Handler пример |
|------|---------------|---------------|
| `ICompositionRepository` | Delete composition (cascade carriages/audit/availability/blocks) | `DeleteComposition.cs` |
| `IWagonTypeRepository` | Delete wagon type (cascade coach layouts + seat defs) | `DeleteWagonType.cs` |
| `ICoachLayoutRepository` | Replace seat definitions атомарно | `SaveSeatDefinitions.cs` |
| `IBlockedSeatRepository` | Bulk remove/update blocked seats | seat unblock flows |

Нужен ти е нов aggregate repo? Добави:
1. `IXxxRepository.cs` в `RailRunService.Application/Interfaces/` (докстринг: "without auto-SaveChanges. Use with IUnitOfWork.")
2. `XxxRepository.cs` в `RailRunService.Infrastructure/Repositories/` (inject `SqlDbContext`)
3. DI регистрация в `ServiceCollectionExtensions.cs`
4. Handler inject-ва `IXxxRepository` + `IUnitOfWork`, вика един `_unitOfWork.SaveChangesAsync(ct)` накрая.

## Working Directories

| Слой | Директория |
|------|-----------|
| **Frontend** | `C:\Projects\BDZ Project\Admin-App` |
| **Backend** | `C:\Projects\BDZ Project\OSDM-Src\DotNetServices\RailRunService` |
| **Database (SQL Project)** | `C:\Projects\BDZ Project\OSDM-Src\SQLProjects\RailRunServiceSQL` |

## Build & Verify Commands

```bash
# === Frontend ===
cd "C:\Projects\BDZ Project\Admin-App"
npm run type-check          # TypeScript проверка
npm run lint                # ESLint
npm test                    # Vitest unit/component тестове
npm run dev                 # Dev server на http://localhost:5173

# === Backend ===
cd "C:\Projects\BDZ Project\OSDM-Src\DotNetServices\RailRunService"
dotnet build                # Build
dotnet test                 # Unit тестове
dotnet run --project RailRunService.API  # Стартира API

# === Database (SQL Project) ===
cd "C:\Projects\BDZ Project\OSDM-Src\SQLProjects\RailRunServiceSQL"
dotnet build -c Release --no-incremental
SqlPackage /Action:Publish /SourceFile:bin/Release/RailRunServiceDb.dacpac /TargetConnectionString:"Server=localhost,14430;Database=RailRunServiceDB;User Id=sa;Password=YourStrong@Passw0rd;TrustServerCertificate=True;Encrypt=True;Connect Timeout=60;Command Timeout=0"
```

## Real Backend Workflow (Tasks #59-#72)

**ВАЖНО:** Таскове #59-#72 (Wagon Management) работят с **реален backend и база данни**, НЕ с localStorage mock!

- **Frontend** извиква реален API endpoint (axios → apiClient)
- **Backend** обработва заявката чрез CQRS (Command/Query + Handler)
- **Database** — данните се четат/пишат в SQL Server база
- **FE unit тестове** мокват API слоя (`vi.mock('@/api/wagons/wagons.api')`)
- **E2E тестове** минават през реален FE → BE → DB

## Important Rules

### 🚨 Critical

1. **ONE TASK AT A TIME** - Never work on multiple tasks in parallel
2. **ONE STEP AT A TIME** - Execute steps sequentially, verify after each
3. **TESTS FIRST** (for TDD tasks) - Write failing test BEFORE implementation
4. **VISUAL FEEDBACK MANDATORY** (for designReference tasks) - Must screenshot and compare
5. **ITERATE UNTIL PASS** - Don't mark complete until tests pass AND design matches

### 🎯 Testing Commands

```bash
# Unit/Component tests
npm test

# E2E tests
npx playwright test

# Linter
npm run lint

# TypeScript
npm run type-check

# Dev server (for visual testing)
npm run dev
```

### 🎨 Visual Testing (cursor-ide-browser MCP)

**MUST use MCP server:** `cursor-ide-browser` (NOT cursor-browser-extension or playwright)

**Available tools:**
1. `browser_navigate` - Navigate to URL
2. `browser_screenshot` - Take screenshot (fullPage: true)
3. `browser_snapshot` - Get page structure (for debugging)

**Comparison Checklist:**

Reference `@docs/composition/designs/design-mapping.json`:

- ✅ **Layout**: Header, sidebar (25%), main (75%) positioning
- ✅ **Colors**: 
  - Status badges: gray (Draft), green (Active)
  - Wagon borders: green (active), gray (inactive)
  - Wagon backgrounds: blue (Compartment), purple (Sleeper), yellow (Bistro)
- ✅ **Typography**: h4 (title), h6 (placard), body1 (type), caption (capacity)
- ✅ **Spacing**: 16px gaps, 400px drawer, proper padding

### 📦 localStorage Mock Backend

**CRITICAL:** No real backend! Everything is in `localStorage['bdz_mockups']`.

```javascript
// Structure
localStorage['bdz_mockups'] = JSON.stringify({
  compositions: [...],
  wagons: [...],
  wagonTypes: [...],
  trains: [...],
  stations: [...]
});

// API methods read/write from localStorage
compositionsApi.getAll() // → reads localStorage
compositionsApi.create(data) // → writes localStorage
```

**Task #3** will setup auto-seed with sample data.

### ⏱️ Iteration Summary

**At END of iteration, output summary:**

```markdown
## Iteration Summary

**Task Worked On:** #{id} - {description}

**TDD Phase Completed:** {RED/GREEN/VISUAL/REFACTOR/DONE or N/A}

**Tests Status:**
- Unit tests: {PASSED/FAILED/N/A}
- E2E tests: {PASSED/FAILED/N/A}
- Linter: {PASSED/FAILED}

**Visual Status:**
- Screenshot taken: {YES/NO}
- Design matches: {YES/NO/N/A}

**Verification:**
- All steps completed: {YES/NO}
- Task marked passes: {true/false}
- Git committed: {YES/NO}

**Next Action:**
- {Continue to next task / Iterate on current task / All complete}
```

## Success Criteria

Mark `"passes": true` ONLY IF:

1. ✅ Tests pass (npm test AND npx playwright test)
2. ✅ Visual match (screenshot съвпада) - ако има designReference
3. ✅ No linter errors (npm run lint)
4. ✅ TypeScript compiles (npm run type-check)
5. ✅ Git committed
6. ✅ Logged in activity.md

**If ANY criteria fails → DO NOT mark passes: true → ITERATE!**

---

**Ralph, work on ONE task, follow TDD phases, verify everything, commit, report status, and STOP.**

**Remember:** 
- **ONE TASK per iteration — then STOP. Next task = next agent = clean context.**
- Steps ONE BY ONE
- Tests FIRST (for TDD tasks)
- Screenshot comparison MANDATORY (for designReference tasks)
- Iterate until ALL verifications pass
- Only then mark complete, commit, output XML, and STOP
