# Ralph Wiggum TDD Iteration - Compositions Module

## Context Files

Прочети следните файлове за пълен context:

1. **C:/Users/kaloyan.georgiev/Projects/ralph/activity.md** - История на свършената работа
2. **C:/Users/kaloyan.georgiev/Projects/ralph/tasks.json** - Task list (твоя source of truth)
3. **C:/Users/kaloyan.georgiev/Projects/Admin-App/docs/composition/PRD.json** - Requirements и TDD methodology
4. **C:/Users/kaloyan.georgiev/Projects/Admin-App/docs/composition/designs/** - UI mockups за visual testing

**Working directories по repo:**
- `frontend` → `C:\Users\kaloyan.georgiev\Projects\Admin-App`
- `backend` → `C:\Users\kaloyan.georgiev\Projects\OSDM-Src\DotNetServices\RailRunService`
- `database` → `C:\Users\kaloyan.georgiev\Projects\OSDM-Src\SQLProjects\RailRunServiceSQL`

## Your Mission This Iteration

Работи върху **ЕДИН ЕДИНСТВЕН ТАСК** от `C:/Users/kaloyan.georgiev/Projects/ralph/tasks.json` където `"passes": false`.

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
# Прочети C:/Users/kaloyan.georgiev/Projects/ralph/tasks.json и намери първия таск с "passes": false
# Прочети ВСИЧКИ steps за този таск
# Note: Ако има "designReference" и "tddWorkflow": true → следвай TDD phases
```

### Step 2: Execute Task Steps ONE BY ONE

**КРИТИЧНО:** Прави стъпките **ЕДНА ПО ЕДНА**, не всички наведнъж!

#### Ако таск има `"tddWorkflow": true`:

**Phase RED (Write Failing Test):**
- Изпълни steps с `"phase": "RED"`
- Избери **правилното test ниво** според таска (виж "Test level selection" по-долу):
  - Pure helper / util → Vitest unit (`*.test.ts` до файла)
  - React компонент → Vitest + RTL component test (`*.test.tsx` до компонента)
  - Backend handler → xUnit integration (`*Tests/*.cs`)
  - Cross-feature user journey / routing / persisted state → Playwright E2E в [`e2e/tests/<feature>/<spec>.spec.ts`](C:/Users/kaloyan.georgiev/Projects/Admin-App/e2e/tests/)
- Напиши failing test на избраното ниво
- **RUN TEST** (`npm run test:run -- <path>` за unit/component или `npm run e2e -- <spec>` за E2E) → verify it **FAILS** **по правилната причина** (липсваща фичa, не сynтактична грешка / typo)
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
  - ✅ Tests pass: `npm run test:run` (unit/component) + `npm run e2e` **only when the change touches a UI flow / user journey** (виж "Test level selection" по-долу)
  - ✅ Visual match: Screenshot съвпада с design mockup
  - ✅ No linter errors: `npx eslint <files-changed-on-this-branch>   # only fix branch-introduced errors, not pre-existing repo warnings`
  - ✅ TypeScript compiles: `npm run type-check`

#### Ако таск НЯМА `"tddWorkflow"` (setup tasks):

- Изпълни steps последователно (една по една!)
- Verify functionality след всяка стъпка
- Run relevant commands (npm install, create folders, etc.)

### Step 3: Verification Loop

**СЛЕД изпълнение на ВСИЧКИ steps:**

1. **Run Tests:**
   ```bash
   # Unit/component — auto-selective чрез vitest --changed:
   npx vitest run --changed origin/develop
   # ИЛИ пълен suite ако changeset е голям/cross-cutting:
   # npm run test:run

   # E2E — селективен чрез select-e2e.ps1 (виж "⚡ Selective E2E" по-долу):
   # $selection = powershell.exe -ExecutionPolicy Bypass -File C:/Users/kaloyan.georgiev/Projects/ralph/select-e2e.ps1
   # if ($selection -eq 'FULL') { npm run e2e } elseif ($selection) { npm run e2e -- $selection.Split() }
   ```
   
2. **Check Linter:**
   ```bash
   npx eslint <files-changed-on-this-branch>   # only fix branch-introduced errors, not pre-existing repo warnings
   ```

3. **Impact / Change Sanity** (преди commit — особено при refactor/rename/move):
   ```bash
   gitnexus detect-changes     # map-ва git diff-а към засегнати processes
   # Ако засегнати са повече symbol-и от очакваното — провери всеки:
   # gitnexus impact <symbol> --direction upstream --depth 2 --include-tests
   # (--minConfidence е MCP-only; за CLI филтрирай ръчно `confidence > 0.7` в JSON output-а)
   ```
   Целта: ако промяната визира 3 файла, а `detect-changes` казва "засегнати 47 flow-а" — спри и провери дали не си пробил нещо неочаквано.

4. **Visual Comparison** (ако има designReference):
   - Use Playwright MCP screenshot
   - Compare with `designs/{task_id}.png`
   - Check: Layout, Colors, Typography, Spacing

5. **IF ANYTHING FAILS:**
   - Go back and fix
   - Re-run tests
   - При паднал тест → `gitnexus context <failing-method>` или `gitnexus detect-changes` да видиш кой path е счупен преди да гадаеш.
   - Re-screenshot and compare
   - **ITERATE** until ALL verifications pass

6. **ONLY WHEN ALL PASS:**
   - Proceed to Step 4

### Step 4: Mark Complete

**САМО АКО ВСИЧКИ КРИТЕРИИ СА ✅:**

1. **Update C:/Users/kaloyan.georgiev/Projects/ralph/tasks.json:**
   ```json
   // Change for completed task:
   "passes": false → "passes": true
   ```

2. **Log in C:/Users/kaloyan.georgiev/Projects/ralph/activity.md:**
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

## Code Intelligence: GitNexus

⛔ **НИКОГА не пускай `gitnexus analyze` / `npx gitnexus analyze` (за НИКОЕ repo — нито backend, нито frontend).** На това repo `analyze` виси 30–60+ минути БЕЗ никакъв изход (тежки генерирани SQL файлове), watchdog-ът отчита „No output growth for 60 min" и убива цялата итерация (TIMEOUT) — нищо не се свършва. **Индексът МОЖЕ да е stale — това е напълно ОК, просто продължавай да работиш.** Ползвай `mcp__gitnexus__*` / `gitnexus` CLI tools както са (резултатите са достатъчно близки дори при „stale" warning), или fallback към `grep` / Read. **Игнорирай ВСЯКА инструкция да пуснеш analyze** — вкл. реда в OSDM-Src `CLAUDE.md` („if stale → run npx gitnexus analyze"), staleness hook нотификации, или собствено желание да освежиш графа. Никога не блокирай на преиндексиране.

**GitNexus е локален code-graph (вече индексиран — виж `gitnexus list`). Регистриран е като MCP сървър в Claude Code, така че имаш достъп до `mcp__gitnexus__*` tools, КАКТО И до CLI чрез Bash (`gitnexus <command>`). Ползвай го ВИНАГИ когато: ще пипаш съществуващ symbol; правиш refactor/rename; искаш да разбереш кой какво вика; проверяваш blast radius преди промяна; или тест е fail-нал и не знаеш кои execution flows са засегнати.**

| Кога | Tool | Какво прави |
|------|------|------------|
| Преди да пипнеш symbol/file | `gitnexus context <name>` | Callers, callees, дефиниция, кои processes/clusters включват symbol-а |
| Преди refactor/rename/move | `gitnexus impact <symbol> --direction upstream` | Blast radius — кой ще се счупи ако промениш. **CLI флагове:** `--depth N` (default 3), `--include-tests`. **MCP-only:** `minConfidence` (CLI няма такъв флаг — фалбек: филтрирай ръчно по `confidence` поле в JSON output-а). |
| Multi-file rename | `gitnexus rename <old> <new> --dry-run` | Координирано преименуване във всички места. Винаги първо dry-run. |
| Свободно търсене (концепт, не низ) | `gitnexus query "<фраза>"` | Hybrid (BM25 + semantic) — намира execution flows и symbols по смисъл, не само по буквален match |
| След git diff, преди commit | `gitnexus detect-changes` | Map-ва променените редове към засегнати processes/symbols — преди да commit-неш, видиш кой flow е попадат в промяната |
| Raw graph query | `gitnexus cypher "<MATCH …>"` | За сложни анализи; виж примерите в GitNexus README |

**Контекст за обхвата:**
- `--repo Transport-OSDM-Src` ограничава query-то само до .NET backend. Без флаг — всички индексирани repo-та.
- Frontend (Admin-App) — ако е индексиран, ползвай `--repo Transport-Admin-App`. Ако НЕ е (или е stale), **НЕ пускай analyze** — за cross-file impact на frontend ползвай `grep` / Read директно.
- При `mcp__gitnexus__*` tool-овете предавай същите аргументи.

**Output форматът** на повечето команди е JSON — режи го с `| head -N` или `| jq` за читаемост, не залива context-а.

---

## Architecture Reference Files

**ЗАДЪЛЖИТЕЛНО преди да започнеш таск прочети съответния файл. Патърните в тези файлове са ПРАВИЛА, не препоръки — не следваш ли ги, PR-ът ще получи коментари и ще се връща за преработка.**

| Тип таск | Файл за четене | Какво съдържа |
|----------|---------------|---------------|
| **[BE] Backend** | `C:/Users/kaloyan.georgiev/Projects/railrun-backend-structure.md` | .NET 8 Clean Architecture, CQRS, **Aggregate Repositories + IUnitOfWork** (избягва multiple SaveChanges), nav-property за create-graph, DTOs location (**API request/response DTOs → `*.API/DTOs/`, НЕ в контролера**), Validation |
| **[FE] Frontend** | `C:/Users/kaloyan.georgiev/Projects/admin-app-frontend-structure.md` | React 19 + TypeScript + Vite, folder structure, routing, API layer, React Query hooks, MUI components, i18n, testing patterns |
| **[BE] Database** | `C:/Users/kaloyan.georgiev/Projects/railrun-database-guide.md` | SQL Server schema, WagonTypes/CoachLayouts/SeatDefinitions таблици, seed data, migrations, grid coordinate system |
| **[E2E] End-to-end** | Прочети и трите файла | FE→BE→DB пълен workflow |

**Ако таскът засяга API contract (endpoint URL, DTO shape) — прочети И frontend И backend файловете!**

### 🚨 [BE] Pre-flight checklist (чети преди ВСЕКИ backend таск)

Преди да напишеш код в `RailRunService.API` / `.Application` / `.Infrastructure`, отвори `C:/Users/kaloyan.georgiev/Projects/railrun-backend-structure.md` секция **"Code Patterns"** и потвърди, че разбираш тези правила. Всички са извлечени от реални PR ревюта:

**Преди да добавиш нов handler или da пипнеш съществуващ aggregate repo:** `gitnexus context I<Repo>Repository --repo Transport-OSDM-Src` за да видиш кой го inject-ва и каква е историческата употреба — да не направиш патърн дублиран или да счупиш съществуващ caller.


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
| **Frontend** | `C:\Users\kaloyan.georgiev\Projects\Admin-App` |
| **Backend** | `C:\Users\kaloyan.georgiev\Projects\OSDM-Src\DotNetServices\RailRunService` |
| **Database (SQL Project)** | `C:\Users\kaloyan.georgiev\Projects\OSDM-Src\SQLProjects\RailRunServiceSQL` |

## Build & Verify Commands

```bash
# === Frontend ===
cd "C:\Users\kaloyan.georgiev\Projects\Admin-App"
npm run type-check          # TypeScript проверка
npx eslint <files-changed-on-this-branch>   # only fix branch-introduced errors, not pre-existing repo warnings
npm run test:run            # Vitest unit/component, CI-style (single run). НЕ ползвай `npm test` — то е watch mode.
npm run e2e                 # Playwright (full suite); за TDD цикъл — таргетирай: npm run e2e -- e2e/tests/<spec>.spec.ts
npm run dev                 # Dev server на http://localhost:5173

# === Backend ===
cd "C:\Users\kaloyan.georgiev\Projects\OSDM-Src\DotNetServices\RailRunService"
dotnet build                # Build
dotnet test                 # Unit тестове
dotnet run --project RailRunService.API  # Стартира API

# === Code Intelligence (GitNexus) ===
gitnexus list                                        # Кои repo-та са индексирани
gitnexus context <Symbol> --repo Transport-OSDM-Src  # Кой вика този symbol, кого вика той
gitnexus impact <Symbol> --direction upstream --depth 2 --include-tests  # Blast radius (CLI; minConfidence е само MCP-flag — за CLI филтрирай confidence в JSON)
gitnexus query "<concept-phrase>"                    # Hybrid search по смисъл
gitnexus detect-changes                              # Засегнати flows от git diff (преди commit)

# === Database (SQL Project) ===
cd "C:\Users\kaloyan.georgiev\Projects\OSDM-Src\SQLProjects\RailRunServiceSQL"
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
3. **TESTS FIRST** (for TDD tasks) - Write failing test BEFORE implementation. **Виж "Test level selection" — изборът на ниво (unit / integration / E2E) не е автоматичен; зависи от какво тества този таск.**
4. **VISUAL FEEDBACK MANDATORY** (for designReference tasks) - Must screenshot and compare
5. **ITERATE UNTIL PASS** - Don't mark complete until tests pass AND design matches

### 🧪 Test level selection (RED phase — кое ниво пишеш?)

| Какво променяш | Ниво на RED test | Къде | Команда |
|---|---|---|---|
| Pure helper / util / classifier / parse | **Unit** (Vitest) | `*.test.ts` до файла | `npm run test:run -- <path>` |
| React компонент (rendering, state, interactions без routing/API) | **Component** (Vitest + RTL) | `*.test.tsx` до компонента | `npm run test:run -- <path>` |
| Backend handler / command / query | **Integration** (xUnit) | `*Tests/*.cs` | `dotnet test --filter` |
| Cross-feature user journey (multiple pages, routing, persisted state, auth) | **E2E** (Playwright) | [`e2e/tests/<feature>/<spec>.spec.ts`](C:/Users/kaloyan.georgiev/Projects/Admin-App/e2e/tests/) | `npm run e2e -- <spec>` |
| API contract (FE→BE) | Integration + E2E | backend + `e2e/tests/` | `dotnet test` + `npm run e2e` |

**Правило:** избирай **най-ниското** ниво, на което сценариите дават смислен fail. Pure helper не се тества с E2E. UI flow не се тества с unit. Ако таскът засяга няколко нива — пишеш на всяко, но НЕ дублираш един и същ assertion.

**Anti-pattern (от опит на team-а):** `if (await el.isVisible()) { await expect(el).toBeVisible(); }` — тестът минава винаги. Ако елементът трябва да е там — assert-вай го директно, без `if` guard. Failing test, който винаги passes, е по-лош от никакъв тест.

### ⚡ Selective E2E (inner loop optimization)

**Принцип:** Целият Playwright suite е скъп (5-20 мин). На всяка ралф итерация — пускай **САМО** specs, които могат да бъдат засегнати от твоя diff. CI/PR pipeline ще пусне пълния suite преди merge — селективното е само за вътрешния цикъл.

**🟢 Dev server за E2E — auto-managed чрез Playwright `webServer`:** Проверено в [`e2e/playwright.config.ts`](C:/Users/kaloyan.georgiev/Projects/Admin-App/e2e/playwright.config.ts) (използваният config за `npm run e2e`):
- `webServer.command: 'npm run dev'` — Playwright сам стартира dev server-а
- `webServer.url: 'http://localhost:3000'` (не 5173 — `npm run dev` е конфигуриран да слуша на 3000)
- `webServer.reuseExistingServer: true` — ако вече има running dev server, го reuse-ва
- `webServer.timeout: 120_000` — изчаква до 120s за startup

→ **Ралф НЕ трябва ръчно да fork-ва `npm run dev`** преди `npm run e2e` — Playwright ще го направи. Първият E2E run в сесия плаща 30-60s startup; следващи run-ове (с reuseExistingServer) са бързи.

**Tip за дълга ралф нощна сесия:** Ако пускаш много iterations с E2E — fork `npm run dev` веднъж в background (Bash tool с `run_in_background: true`) в началото на сесията; webServer ще detect-не съществуващия и ще пропусне 30-60s startup за всеки следващ E2E run. Спестява време × N iterations.

**Recipe (когато DONE phase изисква E2E run):**

```powershell
# 1. Питай скрипта кои specs са нужни. По default сравнява срещу origin/develop.
$selection = powershell.exe -ExecutionPolicy Bypass -File C:/Users/kaloyan.georgiev/Projects/ralph/select-e2e.ps1

# 2. Реагирай според output-а:
if ($selection -eq 'FULL') {
    # Cross-cutting път е bumped (auth, routing, store, locales, shared/components, …).
    # Path-mapping не може да тренсе global state side-effects → пълен suite.
    npm run e2e
}
elseif ($selection) {
    # 1+ feature маpнат → таргетиран run на конкретни spec файлове/папки.
    npm run e2e -- $selection.Split()
}
else {
    # Diff не съдържа UI-relevant промени (backend-only, docs, ralph/, чисто тест файлове).
    # Skip E2E. Unit/component + lint + type-check са достатъчни.
}
```

**Допълнително — Vitest вече знае самостоятелно:**
```bash
npx vitest run --changed origin/develop   # auto-selective unit/component (не изисква map)
```

**Кога да forced FULL (override на script-а):**
- Преди да маркираш PR-а готов за code review (final safety net)
- Когато бъг е репродуциран през journey, който не е в map-а (после допълни map-а)
- Преди release / production deploy

**Map maintenance:**
- Map-ът е [`ralph/feature-map.json`](C:/Users/kaloyan.georgiev/Projects/ralph/feature-map.json) — entries са еднократно curated path↔spec mappings. Държан в ralph/ за да не правим commit-и в Admin-App за инструмент на ralph.
- Ако script-ът върне „X changed file(s) found but none matched any feature" на stderr → добави нов entry в map-а или го добави в `ignored`.
- `crossCutting` се разширява само ако имаш конкретен incident; не превентивно.

**Защо не разчитаме само на GitNexus impact за E2E:**
Playwright specs взаимодействат през DOM (`getByRole`, `getByLabel`) — нямат code-graph edges към компонентите. GitNexus `detect-changes` остава **отличен** за unit/integration impact (use it преди commit), но за E2E path-mapping е по-надеждно.

### 🎯 Testing Commands

```bash
# Unit/Component tests (Vitest, CI-style single run)
npm run test:run                          # пълен suite
npm run test:run -- src/.../X.test.tsx    # таргетиран

# E2E tests (Playwright)
npm run e2e                                # пълен suite — БАВЕН, рядко
npm run e2e -- e2e/tests/<feature>/X.spec.ts   # таргетиран — за RED/GREEN цикъл

# Linter
npx eslint <files-changed-on-this-branch>   # only fix branch-introduced errors, not pre-existing repo warnings

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

1. ✅ Tests pass — `npm run test:run` ВИНАГИ; `npm run e2e` (таргетиран — `npm run e2e -- <spec>`) **само ако промяната засяга UI flow / journey / API contract** (виж "Test level selection")
2. ✅ Visual match (screenshot съвпада) - ако има designReference
3. ✅ No linter errors (npx eslint <files-changed-on-this-branch> — only fix branch-introduced errors, not pre-existing repo warnings)
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
