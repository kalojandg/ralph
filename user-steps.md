# User Defined Steps - TDD Visual Feedback

Това са допълнителни специфични инструкции за TDD workflow с visual testing.

---

## 🏗️ Backend Tasks

### Архитектурен Reference

**Преди да започнеш BE таск, ЗАДЪЛЖИТЕЛНО прочети:**
- `C:/Users/kaloyan.georgiev/Projects/ralph/ralph reference/project reference/railrun-backend-structure.md` — .NET 8 Clean Architecture, CQRS pattern, Controllers, Domain, Infrastructure
- `C:/Users/kaloyan.georgiev/Projects/ralph/ralph reference/project reference/railrun-database-guide.md` — DB schema, WagonTypes таблица, migrations
- `C:/Users/kaloyan.georgiev/Projects/ralph/ralph reference/project reference/admin-app-frontend-structure.md` — за API contract с FE

### BE TDD Workflow

1. **Напиши тест** (unit или integration) — тестът ТРЯБВА да ФЕЙЛВА
2. **Имплементирай** минимален код за да минава тестът
3. **Билдни:** `dotnet build`
4. **Пусни тестовете:** `dotnet test`
5. **Publish DB:** SqlPackage (виж команди в PROMPT.md)
6. **Верифицирай** — endpoint отговаря правилно

### CQRS Pattern (следвай го!)

За нов endpoint:
1. **Domain** — Entity/Enum (напр. WagonStatus)
2. **Application/Queries или Application/Commands** — Query/Command + Handler
3. **API/Controllers** — Endpoint в съответния Controller
4. **Infrastructure** — DbContext update ако е нужен

### Миграции

- Seed files (005-035) са в Azure — НЕ ги пипай!
- За промени по WagonTypes: създай НОВА миграция (071+)
- За нови номенклатури: добави в NomenclatureService

---

## 🖥️ Frontend Tasks

### Архитектурен Reference

**Преди да започнеш FE таск, ЗАДЪЛЖИТЕЛНО прочети:**
- `C:/Users/kaloyan.georgiev/Projects/ralph/ralph reference/project reference/admin-app-frontend-structure.md` — React 19, folder structure, routing, API layer, hooks, MUI, i18n, testing

### Реален API (НЕ localStorage!)

Когато таск работи с **реален backend** (не mock), пример:
- `wagonsApi.getWagonTypes()` → GET /api/wagon-types
- `wagonsApi.setStatus(id, status)` → PATCH /api/wagon-types/{id}/status
- Номенклатури за WagonStatus → GET /api/nomenclatures/wagon-statuses

### FE Architecture Pattern (следвай го!)

За нов feature:
1. **API layer** — `src/api/wagons/wagons.api.ts` + `wagons.types.ts` (endpoints, DTOs)
2. **React Query hooks** — `src/app/features/wagons/hooks/useWagonTypes.ts` (query key factory, useQuery/useMutation)
3. **Components** — `src/app/features/wagons/components/` (MUI компоненти)
4. **Pages** — `src/app/features/wagons/pages/WagonsPage.tsx` (route-level)
5. **Routing** — `src/app/routes/router.tsx` (добави route)
6. **Sidebar** — `src/app/layout/MainLayout.tsx` (добави menu item)
7. **i18n** — `src/locales/bg.json` + `en.json` (винаги и двата!)
8. **API config** — `src/api/config.ts` (endpoint константи)

### FE тестове мокват API слоя:
```typescript
vi.mock('@/api/wagons/wagons.api', () => ({
  wagonsApi: {
    getWagonTypes: vi.fn(),
    setStatus: vi.fn(),
  }
}));
```

### FE TDD Workflow

1. **Напиши тест** — тестът ТРЯБВА да ФЕЙЛВА
2. **Имплементирай** минимален код за да минава тестът
3. **Верифицирай:** `npm run type-check && npx eslint <files-changed-on-this-branch> && npm run test:run`
4. **Всичко минава** → таскът е готов

### Snackbar / Toaster pattern:
```typescript
import { useDispatch } from 'react-redux';
import { showSnackbar } from '@/store/slices/ui.slice';

const dispatch = useDispatch();
dispatch(showSnackbar({ message: t('wagons.featureComingSoon'), severity: 'info' }));
```

### E2E тестове минават през реален BE+DB

---

## 🗄️ Database Tasks

### Архитектурен Reference

**Преди да работиш по DB таск, ЗАДЪЛЖИТЕЛНО прочети:**
- `C:/Users/kaloyan.georgiev/Projects/ralph/ralph reference/project reference/railrun-database-guide.md` — SQL Server schema, WagonTypes таблица, seed data, migrations

### DB Rules

- **Seed files (005-035) са в Azure — НЕ ги пипай!**
- За промени по WagonTypes: създай НОВА миграция (071+) в SQL Project
- За нови номенклатури: добави в NomenclatureService И seed data
- Билдни и публикувай:
```bash
cd "C:\Users\kaloyan.georgiev\Projects\OSDM-Src\SQLProjects\RailRunServiceSQL"
dotnet build -c Release --no-incremental
SqlPackage /Action:Publish /SourceFile:bin/Release/RailRunServiceDb.dacpac /TargetConnectionString:"Server=localhost,14430;Database=RailRunServiceDB;User Id=sa;Password=YourStrong@Passw0rd;TrustServerCertificate=True;Encrypt=True;Connect Timeout=60;Command Timeout=0"
```

---

## 🎯 Visual Feedback Loop (КРИТИЧНО!)

### cursor-ide-browser MCP Setup

**Server:** `cursor-ide-browser` (Chrome DevTools Protocol browser automation)
**Purpose:** Navigate pages, take screenshots, interact with UI

### Visual Testing Workflow

След имплементация на UI компонент (VISUAL phase):

#### 1. Start Dev Server

```bash
npm run dev
# Server ще стартира на http://localhost:5173
```

#### 2. Navigate to Component/Page

```javascript
CallMcpTool({
  server: "cursor-ide-browser",
  toolName: "browser_navigate",
  arguments: {
    url: "http://localhost:5173/compositions"  // Adjust based on task
  }
})
```

#### 3. Take Screenshot

```javascript
CallMcpTool({
  server: "cursor-ide-browser",
  toolName: "browser_screenshot",
  arguments: {
    fullPage: true
  }
})
// Screenshot автоматично се запазва
```

#### 4. Compare with Design Mockup

**Референтен дизайн:** `@docs/composition/designs/{task_id}.png`

**Comparison Checklist:**

```markdown
### Layout Structure
- [ ] Header position и alignment правилни
- [ ] Sidebar width (25% за editor) правилна
- [ ] Main content width (75% за editor) правилна
- [ ] Grid/Flex layout съвпада с mockup

### Colors (виж design-mapping.json)
- [ ] Status badges: gray (#757575) за Draft, green (#4caf50) за Active
- [ ] Wagon backgrounds: blue (#e3f2fd) за Compartment, purple (#f3e5f5) за Sleeper, yellow (#fff9c4) за Bistro
- [ ] Wagon borders: green (#4caf50) за active, gray (#bdbdbd) за inactive
- [ ] Locomotive: red (#c62828)
- [ ] Primary button: blue (#1976d2)

### Typography (виж design-mapping.json)
- [ ] Page title: Typography variant="h4"
- [ ] Wagon placard: Typography variant="h6" (#1, #2, #3)
- [ ] Wagon type: Typography variant="body1" (Купе, Спален)
- [ ] Capacity: Typography variant="caption" color="textSecondary" (54 места)

### Spacing (виж design-mapping.json)
- [ ] Filter gap: 16px
- [ ] Wagon gap: 16px
- [ ] Card padding: 16px
- [ ] Drawer width: 400px (properties panel)
- [ ] Sidebar width: 25% (wagon palette)
```

#### 5. If Design Doesn't Match → REFACTOR

**Common fixes:**

| Issue | Fix |
|-------|-----|
| Wrong status badge color | `<Chip color="success" />` за Active, `color="default"` за Draft |
| Wrong spacing | Use MUI `spacing()`: `gap: theme.spacing(2)` за 16px |
| Wrong typography | Check Typography `variant`: `<Typography variant="h6">` |
| Wrong wagon border | Use `sx`: `sx={{ borderLeft: '4px solid #4caf50' }}` |
| Wrong layout | Check Grid `xs` values: `<Grid xs={3}>` sidebar, `<Grid xs={9}>` canvas |

#### 6. Re-Screenshot and Compare

```javascript
// After fixes, take new screenshot
CallMcpTool({
  server: "cursor-ide-browser",
  toolName: "browser_screenshot",
  arguments: { fullPage: true }
})

// Compare again with mockup
// Iterate until matches ✅
```

---

## 🧪 Testing Loop (КРИТИЧНО!)

### Test Execution Order

```bash
# 1. Unit/Component tests
npm run test:run

# 2. E2E Playwright tests
npm run e2e

# 3. Linter
npx eslint <files-changed-on-this-branch>

# 4. TypeScript check
npm run type-check
```

### If ANY Test Fails

**DO NOT proceed!**

1. **Read error message carefully**
2. **Fix the issue**
3. **Re-run the failed test**
4. **Repeat until ALL tests pass**

### Test-Specific Actions

#### Unit Test Fails
- Fix component logic
- Fix props handling
- Fix state management
- Re-run: `npm run test:run`

#### E2E Test Fails
- Fix user interaction flow
- Fix localStorage mock data
- Fix navigation/routing
- Re-run: `npm run e2e`

#### Linter Fails
- Fix code style issues
- Remove unused imports
- Fix formatting
- Re-run: `npx eslint <files-changed-on-this-branch>`

#### TypeScript Fails
- Fix type errors
- Add missing types
- Fix interface mismatches
- Re-run: `npm run type-check`

---

## 📋 Step-by-Step Execution (КРИТИЧНО!)

### ONE Step at a Time

**Илюстративен пример (методология стъпка-по-стъпка, номерата са примерни):**

```markdown
Step 11.1 (RED): Write failing E2E test
  ↓
Run: npm run e2e
  ↓
Verify: TEST FAILS ✅
  ↓
Step 11.2 (RED): Continue...

Step 11.3 (GREEN): Create CompositionsListPage.tsx
  ↓
Step 11.4 (GREEN): Import hooks
  ↓
Step 11.5 (GREEN): Create layout
  ↓
...
  ↓
Step 11.10 (GREEN): Run test
  ↓
Verify: TEST PASSES ✅
  ↓
Step 11.11 (VISUAL): Start dev server
  ↓
Step 11.12 (VISUAL): Navigate with cursor-ide-browser MCP
  ↓
Step 11.13 (VISUAL): Screenshot
  ↓
Step 11.14 (VISUAL): Compare with design 9.png
  ↓
IF NOT MATCH:
  ↓
Step 11.15 (REFACTOR): Adjust styles
  ↓
Step 11.16 (REFACTOR): Re-screenshot
  ↓
LOOP until MATCH ✅
  ↓
Step 11.17 (DONE): Final verification
```

### Verification After Each Phase

**After RED:**
- ✅ Test written?
- ✅ Test FAILS? (expected)

**After GREEN:**
- ✅ Code implemented?
- ✅ Test PASSES?

**After VISUAL:**
- ✅ Screenshot taken?
- ✅ Design matches mockup?

**After REFACTOR:**
- ✅ All adjustments made?
- ✅ Design now matches?

**After DONE:**
- ✅ ALL tests pass?
- ✅ ALL verifications pass?
- ✅ Ready to commit?

---

## 🚨 Critical Checkpoints

### Before Marking Task Complete

**ASK YOURSELF:**

1. Did I write the test FIRST (for TDD tasks)?
2. Did ALL tests pass?
3. Did I take a screenshot (for designReference tasks)?
4. Does the screenshot MATCH the mockup?
5. Did I check layout, colors, typography, spacing?
6. Did npx eslint <files-changed-on-this-branch> pass?
7. Did npm run type-check pass?
8. Did I update tasks.json ("passes": true)?
9. Did I log in activity.md?
10. Did I git commit with **EXACT task description** as commit message?

**Git Commit Format:**
```bash
git commit -m "feat(compositions): {exact task.description from tasks.json}"
```

**Пример (илюстративен):** таск с description „Create Dashboard List Page with compositions table" → `git commit -m "feat(compositions): Create Dashboard List Page with compositions table"`

**IF ANY ANSWER IS NO → DO NOT MARK COMPLETE!**

---

## 📊 Progress Tracking

### Check Remaining Tasks

```powershell
# Count tasks with passes: false
(Get-Content "C:/Users/kaloyan.georgiev/Projects/ralph/tasks.json" | ConvertFrom-Json | Where-Object { $_.passes -eq $false }).Count
```

### Check Completed Tasks

```powershell
# Count tasks with passes: true
(Get-Content "C:/Users/kaloyan.georgiev/Projects/ralph/tasks.json" | ConvertFrom-Json | Where-Object { $_.passes -eq $true }).Count
```

---

## 💡 Debugging Tips

### If Screenshot Doesn't Match Mockup

1. **Open design-mapping.json** → check color palette, typography, spacing
2. **Compare side-by-side** → screenshot vs mockup
3. **Identify specific differences** → layout? colors? spacing?
4. **Make targeted fixes** → adjust specific properties
5. **Re-screenshot** → verify fix worked
6. **Iterate** → repeat until matches

### If Tests Keep Failing

1. **Read error message** → what exactly failed?
2. **Check test expectations** → are they correct?
3. **Check implementation** → does it match test?
4. **Check imports** → everything imported correctly?
5. **Check data** → localStorage mock data correct?
6. **Run test in isolation** → `npm run test:run -- ComponentName.test.tsx`

### If Linter Fails

1. **Read linter errors** → specific line/column
2. **Fix formatting** → run auto-fix if available
3. **Remove unused code** → imports, variables
4. **Check ESLint rules** → understand what's required

---

## 🎯 Success Criteria Reminder

**Task is complete ONLY when:**

1. ✅ Tests written (for TDD tasks)
2. ✅ Tests pass (npm run test:run && npm run e2e)
3. ✅ Screenshot taken (for designReference tasks)
4. ✅ Design matches mockup (visual comparison ✅)
5. ✅ Linter passes (npx eslint <files-changed-on-this-branch>)
6. ✅ TypeScript compiles (npm run type-check)
7. ✅ tasks.json updated ("passes": true)
8. ✅ activity.md logged
9. ✅ Git committed
10. ✅ Status output (XML tags)

**NO SHORTCUTS! Follow TDD workflow completely!**

---

## 📝 Output Format

**At end of iteration:**

```xml
<task-complete>
  <task-id>11</task-id>
  <description>Create Dashboard List Page with compositions table</description>
  <tests>PASSED</tests>
  <visual>MATCHED</visual>
  <committed>YES</committed>
  <commit-message>feat(compositions): Create Dashboard List Page with compositions table</commit-message>
</task-complete>

<status>CONTINUE</status>
<next-task>12</next-task>
```

**Or if all complete:**

```xml
<promise>COMPLETE</promise>
<total-tasks>30</total-tasks>
<all-passed>true</all-passed>
```

---

**These user-defined steps ensure quality through TDD and visual verification!** ✅
