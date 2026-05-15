# User Defined Steps - TDD Visual Feedback

Това са допълнителни специфични инструкции за TDD workflow с visual testing.

---

## 🏗️ Backend Tasks (Tasks #59-#61)

### Архитектурен Reference

**Преди да започнеш BE таск, ЗАДЪЛЖИТЕЛНО прочети:**
- `C:/Users/kaloyan.georgiev/Projects/railrun-backend-structure.md` — .NET 8 Clean Architecture, CQRS pattern, Controllers, Domain, Infrastructure
- `C:/Users/kaloyan.georgiev/Projects/railrun-database-guide.md` — DB schema, WagonTypes таблица, migrations
- `C:/Users/kaloyan.georgiev/Projects/admin-app-frontend-structure.md` — за API contract с FE

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

## 🖥️ Frontend Tasks (Tasks #62-#71)

### Архитектурен Reference

**Преди да започнеш FE таск, ЗАДЪЛЖИТЕЛНО прочети:**
- `C:/Users/kaloyan.georgiev/Projects/admin-app-frontend-structure.md` — React 19, folder structure, routing, API layer, hooks, MUI, i18n, testing

### Реален API (НЕ localStorage!)

Таскове #59-#72 използват **реален backend**:
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
3. **Верифицирай:** `npm run type-check && npx eslint <files-changed-on-this-branch> && npm test`
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
- `C:/Users/kaloyan.georgiev/Projects/railrun-database-guide.md` — SQL Server schema, WagonTypes таблица, seed data, migrations

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
npm test

# 2. E2E Playwright tests
npx playwright test

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
- Re-run: `npm test`

#### E2E Test Fails
- Fix user interaction flow
- Fix localStorage mock data
- Fix navigation/routing
- Re-run: `npx playwright test`

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

**Example from Task #11 (Dashboard List Page):**

```markdown
Step 11.1 (RED): Write failing E2E test
  ↓
Run: npx playwright test
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

**Example:** Task #11 → `git commit -m "feat(compositions): Create Dashboard List Page with compositions table"`

**IF ANY ANSWER IS NO → DO NOT MARK COMPLETE!**

---

## 📊 Progress Tracking

### Check Remaining Tasks

```powershell
# Count tasks with passes: false
(Get-Content "docs/composition/tasks.json" | ConvertFrom-Json | Where-Object { $_.passes -eq $false }).Count
```

### Check Completed Tasks

```powershell
# Count tasks with passes: true
(Get-Content "docs/composition/tasks.json" | ConvertFrom-Json | Where-Object { $_.passes -eq $true }).Count
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
6. **Run test in isolation** → `npm test -- ComponentName.test.tsx`

### If Linter Fails

1. **Read linter errors** → specific line/column
2. **Fix formatting** → run auto-fix if available
3. **Remove unused code** → imports, variables
4. **Check ESLint rules** → understand what's required

---

## 🎯 Success Criteria Reminder

**Task is complete ONLY when:**

1. ✅ Tests written (for TDD tasks)
2. ✅ Tests pass (npm test && npx playwright test)
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

---

## 🏗️ Етап 4: Wagon Creation Feature (Tasks #73-#95)

**Фокус:** Рефакторинг на OpenSaloonLayout + нова страница "Създаване на вагон" с OSDM grid, drag-and-drop елементи, localStorage persistence, navigation guard и запис към backend.

### Под-етапи:

| Под-етап | Таскове | Какво прави |
|----------|---------|-------------|
| **4A: Рефакторинг** | #73-#77 | Разбиване на OpenSaloonLayout.tsx (~2139 линии) на модули. ZERO logic changes — само move + import |
| **4B: Backend CRUD** | #78-#81 | POST/PUT coach-layouts, POST seats, POST wagon-types |
| **4C: FE API + Hooks** | #82-#83 | API клиент + React Query hooks за новите endpoints |
| **4D: Creation UI** | #84-#94 | Страница /wagons/new, OSDM grid, palette, drag-drop, localStorage, nav guard, save |
| **4E: E2E** | #95 | Пълен workflow тест |

---

### 🔧 Рефакторинг правила (Tasks #73-#77) — КРИТИЧНО!

**Принцип: "Само местиш, не променяш"**

1. **ПРЕДИ** всяка стъпка: `npm test && npm run type-check` → запиши baseline
2. **ПРЕДИ** да извадиш функция/символ в нов файл: `gitnexus context <symbol>` → виж всички callers (incoming) и callees (outgoing). Ако броят е по-голям, отколкото очакваш — спри и преоцени scope-а. `gitnexus impact <symbol> --direction upstream --minConfidence 0.7` дава blast radius за смело преценяване колко refactor-а имаш.
3. **Извличай** код в нов файл, добавяй `export` там и `import` в оригиналния
4. **СЛЕД** всяка стъпка: `npm test && npm run type-check` → СЪЩИЯТ резултат. Плюс `gitnexus detect-changes` → засегнатите processes трябва да са СЪЩИТЕ като преди extract-а; ако са се появили нови flow-и — extract-ът е променил поведение, не просто организация.
5. Ако тест фейлва → **ВЕДНАГА rollback** → `gitnexus context <failing-test-target>` за да видиш точните callers/callees преди да гадаеш → поправи
6. **НИКОГА** не променяй rendering логика — само реорганизация на файлове

**Целева структура след рефакторинг:**
```
layoutRenderers/
├── OpenSaloonLayout.tsx   → ~400 линии (main component)
├── SeatCell.tsx            → ~180 линии
├── gridBuilder.ts          → ~450 линии (pure, unit-testable)
├── cellRenderers.tsx        → ~400 линии
├── osdmRenderers.tsx        → ~400 линии
├── wallRenderers.tsx        → ~100 линии
├── zonePanel.tsx            → ~100 линии
├── types.ts                 → типове и интерфейси
└── constants.ts             → цветове, GRID_UNIT, SEAT_SPAN
```

---

### 🏗️ Backend CRUD правила (Tasks #78-#81)

**Следвай CQRS pattern:**
1. Command/Query → Handler → Controller endpoint
2. Валидация в Handler-а
3. **Преди да добавиш нов Command/Query**, провери дали вече има подобен handler: `gitnexus query "<concept>" --repo Transport-OSDM-Src` (напр. `gitnexus query "duplicate placard validation"`). Ако намериш съществуващ handler за подобна функционалност — следвай патърна, не преоткривай.
4. **Преди да промениш съществуващ DTO или Repository interface**: `gitnexus impact <DtoName> --direction upstream --minConfidence 0.8` за да видиш кои handlers/controllers/tests ще тряба да обновиш.
5. `dotnet build && dotnet test` след всяка стъпка
6. **НЕ създавай миграции в SQL проекта** — таблиците вече съществуват (CoachLayouts, SeatDefinitions, WagonTypes)

**Нови endpoints:**
```
POST   /api/coach-layouts          → Create layout
PUT    /api/coach-layouts/{id}     → Update layout (OSDM JSON)
POST   /api/coach-layouts/{id}/seats → Batch save seats
POST   /api/wagon-types            → Create wagon type (Draft)
```

---

### 🖥️ Creation UI правила (Tasks #84-#94)

**Drag-and-drop:** @dnd-kit (вече инсталиран от Task #1)
- `DndContext` обвива цялата страница
- `useDraggable` за palette елементи
- `useDroppable` за grid клетки

**OSDM Grid:**
- CSS Grid с пунктирани линии (border: 1px dashed #ccc)
- Размер от gridSize prop (default 24x10)
- Клетка = GRID_UNIT (22px)
- Координатни labels по X и Y оси

**LocalStorage:**
- Key: `wagon_creation_draft`
- Записва се при ВСЯКА промяна (useEffect)
- При mount — restore от localStorage
- При успешен save към BE — изчисти localStorage

**Navigation guard:**
- React Router `useBlocker` за SPA навигация
- `window.onbeforeunload` за browser close
- Dialog с 3 бутона: Запази / Не запазвай / Отказ

**Save flow:**
1. createWagonType() → получи wagonTypeId
2. createCoachLayout({ wagonTypeId, osdmLayoutJson }) → получи layoutId
3. Изчисти localStorage draft
4. Navigate to /wagons
5. Snackbar за успех

---

## 🧱 Етап 5: Walls Feature (Tasks #96-#111)

**Фокус:** Resizeable OSDM стени (icon codes 23-32) в grid-а за създаване/edit
на вагон. Пълна OSDM спецификация (GraphicElement + RectangleGeometry).

### Подетапи

| Под-етап | Таскове | Какво прави |
|---------|---------|-------------|
| **5A: Domain & helpers** | #96-#101 | Type model, wallShapes registry, cell classifiers, mutation & collision helpers (pure, unit-testable) |
| **5B: Rendering** | #102-#104 | WallCellVisual компонент + OsdmGrid integration + cursors/drag handles |
| **5C: Interaction** | #105-#106 | Resize session + Move session + Esc cancel |
| **5D: Integration** | #107-#109 | Palette drop initial dimension + OSDM serialize/deserialize |
| **5E: Verification** | #110-#111 | Integration test + E2E Playwright |

### 📜 Задължителни reference файлове

Преди да започнеш **всеки** wall таск:

1. **`C:/Users/kaloyan.georgiev.AMEXIS/Downloads/walls.ini`** — визуалния модел,
   класификация на клетки, rendering подход, bounding box на L/T. Това е
   **single source of truth** за геометрията и UX поведението.
2. **`C:/Users/kaloyan.georgiev/Projects/Admin-App/docs/composition/frontend-requirements.md §5`** —
   формалните функционални изисквания (FR-1..FR-7), acceptance criteria,
   разбивка на таскове.
3. **`C:/Users/kaloyan.georgiev/Projects/admin-app-frontend-structure.md`** — React/TS/MUI patterns.

**Ако таскът засяга OSDM JSON формат** — прочети и
https://raw.githubusercontent.com/UnionInternationalCheminsdeFer/OSDM/master/specification/schemas/place.yml
(GraphicElement, RectangleGeometry, GridDimension).

### 🎯 Архитектурни правила за Етап 5

#### Grid инвариант (НЕПОКЛАТИМ)
**ВСИЧКИ клетки в OsdmGrid са единен размер (GRID_UNIT = 22px).** Няма
dedicated wall-tracks, няма по-тесни колони. Стените живеят **вътре** в
нормални клетки. Незаетата част от клетката остава празна.

(Open saloon има dedicated wall tracks — **НЕ** пренасяме този подход.
Заимстваме само визуалния стил: цвят `#546E7A`, 3px thickness, borderRadius 1px.)

#### Layering / zIndex
- **Walls: zIndex 1** (под седалки/зони на 2).
- Wrapper divs на wall клетки поемат mouse events (`position: absolute; inset: 0`).
- Линиите вътре (4-те half-line segments) са `pointer-events: none`.

#### Rendering подход
- **WallCellVisual** компонент — до 4 half-line segments (up/down/left/right)
  според посоките на продължение на стената от тази клетка.
- Corner клетка (L): две половини се срещат точно в центъра (`|` + `—`).
- Middle клетка: двете половини по оста на рамото → пълна линия top→bottom
  или left→right.

#### End vs Middle vs Internal
- **End** — последна клетка на рамо, resize-анчър. Cursor `col-resize` /
  `row-resize` според оста. Visual: малка drag handle точка (4-6 px) в
  ъгъла.
- **Middle** — между end-овете; move-анчър. Cursor `grab`.
- **Internal** — corner (L) или junction (T). Без cursor, без interaction.

#### Collision
- Прилага се при **resize** и **move**.
- `canPlaceWall` проверява: (1) всички wall клетки в grid границите;
  (2) нито една от wall клетки не пресича друг елемент.
- `clampWallToValid` връща последния валиден state (не преминава през пречка).
- По време на drag — червена полупрозрачна подсветка на crossing cells
  (преизползваме съществуващата логика).

### 🚨 Critical rules за Етап 5

1. **Pure helpers first** — таскове #96-#101 са pure utility functions (data
   transformations). Пишат се с unit тестове преди да се интегрират в UI.
   Няма DOM, няма state, само функции с pure input/output.

2. **Render integration после** — таск #103 подмена на съществуващата wall
   rendering логика (стари сиви правоъгълничета от DraggableElement) с
   WallCellVisual. Внимавай: трябва да се изключат wall icons (23-32) от
   съществуващия non-wall pipeline.
   *Преди подмяната:* `gitnexus context DraggableElement` за да видиш всички
   места, които зависят от стария rendering път — wall icons може да са
   рутирани там само по icon range, но е възможно да има и други callers.

3. **Mouse events ПОСЛЕ rendering** — таскове #105-#106. Не пипай
   interaction-ите преди да имаш стабилен rendering.

4. **OSDM JSON формат се ПРОМЕНЯ** — таск #108 добавя `dimension` в
   internals[] за walls. Load logic (#109) чете с fallback. Важно:
   non-wall internals НЕ се засягат.

5. **Backward compatibility задължителна** — стари wagon-и без dimension
   зареждат с default размер от wallShapes. Тест за това в #109.

6. **Не мигрирай `code` при resize** — WALL_LEFT_3 свит до 2-place си остава
   WALL_LEFT_3. OSDM позволява произволен dimension за всеки code.

7. **Няма rotate за v1** — ориентацията се избира при drop чрез конкретния
   палитра елемент (WALL_LEFT vs WALL_RIGHT; T-top vs T-bottom). Resize не
   променя orientation.

### 🧪 TDD за Етап 5

За всеки таск (#96-#111):

1. **RED** — напиши failing тест(ове). Пусни `npm test` → тестовете ФЕЙЛВАТ.
   Verify ФЕЙЛВАТ по правилната причина (модул липсва, тестван behavior
   не е имплементиран).
2. **GREEN** — минимална имплементация. Пусни `npm test` → всички ПАСВАТ.
3. **REFACTOR** (по желание) — подобрения без да чупят тестовете.
4. **VISUAL** (за UI таскове) — npm run dev + manual проверка (cursor-ide-browser
   MCP ако е наличен). Цвят, положение, cursor behavior.
5. **DONE** — `npm test && npm run type-check && npx eslint <files-changed-on-this-branch>` — чисто.

### 📁 Файлова структура

**Нови файлове (предвидени):**
```
src/app/features/wagons/components/
├── wallTypes.ts              # Task #96 — WallElement type, WallCode, WallOrientation, isWallElement
├── wallShapes.ts             # Task #97 — WALL_SHAPES registry, getDefaultDimension
├── wallCells.ts              # Task #98-99 — getWallCells, classifyCell, getCellDirections
├── wallMutations.ts          # Task #100 — resizeWallArm, moveWall
├── wallCollision.ts          # Task #101 — canPlaceWall, clampWallToValid
└── WallCellVisual.tsx        # Task #102 — React component with half-line segments
```

**Променени файлове (предвидени):**
```
src/app/features/wagons/components/OsdmGrid.tsx    # Task #96 (type extend), #103 (wall render), #104 (cursors), #105-106 (drag sessions)
src/app/features/wagons/pages/WagonCreationPage.tsx # Task #107 (palette drop), #108 (save), #109 (load)
src/app/features/wagons/components/ElementPalette.tsx  # (optional) per-orientation palette items за T-top vs T-bottom, ако се реши в #97
```

**Тестове:**
```
src/app/features/wagons/components/__tests__/wallTypes.test.ts             # #96
src/app/features/wagons/components/__tests__/wallShapes.test.ts            # #97
src/app/features/wagons/components/__tests__/wallCells.test.ts             # #98
src/app/features/wagons/components/__tests__/wallCellClassification.test.ts # #99
src/app/features/wagons/components/__tests__/wallMutations.test.ts         # #100
src/app/features/wagons/components/__tests__/wallCollision.test.ts         # #101
src/app/features/wagons/components/__tests__/WallCellVisual.test.tsx       # #102
src/app/features/wagons/components/__tests__/OsdmGrid.walls.test.tsx       # #103, #104, #105, #106
src/app/features/wagons/pages/__tests__/WagonCreationPage.wallDrop.test.tsx # #107
src/app/features/wagons/__tests__/buildOsdmLayoutJson.test.ts              # #108
src/app/features/wagons/__tests__/loadWagon.test.tsx                       # #109
src/app/features/wagons/__tests__/walls.integration.test.tsx               # #110
tests/wagons/walls-workflow.spec.ts                                        # #111 (Playwright E2E)
```

### ✅ Success criteria per task (final check)

Преди да маркираш `"passes": true` за wall таск, провери:

1. ✅ Тестовете от RED phase сега ПАСВАТ
2. ✅ `npm run type-check` чист
3. ✅ `npx eslint <files-changed-on-this-branch>` — няма нови errors (pre-existing warnings се игнорират)
4. ✅ Ако таскът има rendering/UI компонент — провери визуално с npm run dev
5. ✅ Acceptance criteria от frontend-requirements.md §5.7 приложими за таска
   са изпълнени
6. ✅ Актуализиран activity.md запис
7. ✅ Git commit с **точното** `description` от tasks.json

### ⚠️ Отворени въпроси (решават се в хода на Етап 5)

1. **Palette expansion за orientations** — дали T-top и T-bottom са отделни
   палитра елементи (препоръчано за v1) или един с orientation picker. За
   v1 се препоръчва два отделни елемента — по-просто UX.

2. **Clamp посока при resize** — когато end клетката на рамо е блокирана от
   пречка по ресайз, clamp-ва ли до последната valid клетка преди пречката
   (препоръчано) или връща towards originalWall-а (unclear visually). Изборът:
   clamp ДО пречката (consistent с "стената стига до пречката").

3. **Selection highlight** — по желание за v1: visual border около избрана
   стена след click. Не задължително, но подобрява UX. Решение: добавя се
   в полиране фаза след #111 ако има време.

---

## 🎨 Етап 6: Renderer Unification (Tasks #113-#124)

**Фокус:** Унификация на двата wagon renderer-а (OpenSaloonLayout за
композиция + OsdmGrid за редактор) над обща OSDM-съвместима shared library.
Elimination на dual source of truth. Визуален паритет — каквото editor-ът
може да създаде, composition-ът го рендира.

### Подетапи

| Под-етап | Таскове | Какво прави |
|---------|---------|-------------|
| **6A: Audit** | #113 | OSDM spec compliance одит (read-only, produce osdm-audit.md) |
| **6B: Foundation** | #114-#116 | Shared types + constants + parse + classify |
| **6C: Element renderers** | #117-#120 | Per-element React компоненти (Seat/Berth/Wall/Window/Door/Zone/Table/Stairs/Amenity) |
| **6D: Grid infrastructure** | #121 | GridContainer + GridCell + GridLayer + DragHighlightOverlay |
| **6E: Orchestrator migration** | #122-#123 | OsdmGrid (≤500 реда) + OpenSaloonLayout (≤250 реда) |
| **6F: Verification** | #124 | E2E round-trip (create → view → edit → view) |

### 📜 Задължителни reference файлове

Преди да започнеш **всеки** таск от Етап 6:

1. **`C:/Users/kaloyan.georgiev/Projects/wagon-renderer-unification-plan.md`** — архитектурният plan.
   **Single source of truth** за structure, scope, размерни цели, секции 0-10.
2. **`C:/Users/kaloyan.georgiev/Projects/Admin-App/docs/composition/osdm-audit.md`** —
   **създаден от Task 113**. След Task 113, всеки следващ таск го консултира
   за полета, които са "направени на око".
3. **`C:/Users/kaloyan.georgiev/Projects/admin-app-frontend-structure.md`** — React/TS/MUI patterns.

### 🎯 Архитектурни правила за Етап 6 (КРИТИЧНИ!)

#### Scope boundary

**IN scope:**
- Shared library `src/app/shared/wagonGrid/` (6 подпапки: types, constants, parse, classify, osdmRenderers, gridFrame)
- OsdmGrid.tsx рефактор (само rendering → shared; orchestration + DnD + mutations остават)
- OpenSaloonLayout.tsx рефактор + OSDM parity
- Tests — unit + component + E2E

**OUT of scope (в Етап 7 на друг колега):**
- Seed / DB cleanup на legacy structural pseudo-seats (WALL/WC/ZONE/PLACEHOLDER/STAIRS с isPhysicallyPresent=false)
- Миграция на спални/кушет/купе wagons към OSDM grid формат
- Изтриване на legacy renderers: CabinLayout, SleeperLayout, CouchetteLayout, CompartmentLayout
- Изтриване на legacy rendering файлове: cellRenderers, osdmRenderers, wallRenderers, SeatCell, zonePanel
- Изтриване на legacy AccommodationType enum стойности
- Премахване на pixel coordinate infrastructure (gridToPixel, pixelToGrid, LAYOUT_PADDING, Seat.coordinates pixel)
- DB check constraints / invariants

**Boundary verification:** преди да commit-неш new shared lib промени, пусни
`gitnexus query "CabinLayout|SleeperLayout|CouchetteLayout|CompartmentLayout"` и `gitnexus context cellRenderers` — увери се, че **новият** `shared/wagonGrid/` код няма incoming edges от legacy renderers (или обратно). Ако има — нарушаваш isolation principle-а и Етап 7 cleanup-ът ще се счупи.

#### Backward compatibility (НЕПОКЛАТИМ принцип)

**Legacy wagons продължават да работят.** Адаптерът в `shared/wagonGrid/parse/buildCanonicalInput.ts`
конвертира legacy Seat[] с isPhysicallyPresent=false + pixel coords към
synthetic OSDM elements на read-time. Това гарантира:
- Composition view на legacy wagon → стените, WC, zones продължават да се виждат.
- Create / edit flow-ът в wagon editor-а не е засегнат (OsdmGrid вече чете OSDM JSON).
- След като колегата изпълни Етап 7 (DB cleanup), adapter-ът ще бъде no-op за
  повечето wagons и ще може да бъде изтрит в следващ рефактор.

**Marker convention:** Целият legacy adapter код има коментар
```
// TEMP: remove after Etap 7 seed cleanup
```
за да е лесно за finding и изтриване.

#### Размерни цели (HARD targets)

- `OsdmGrid.tsx`: ~1500 реда → **≤ 500 реда** след Task 122.
- `OpenSaloonLayout.tsx`: ~300 реда + ~80KB поддържащи → **≤ 250 реда в 1 файл** след Task 123.

Ако превишиш цел → идентифицирай какво още може да се extract-не в shared.
Преминаване над таргета без обосновка = таскът не е готов.

#### Renderer API контракт (за shared/wagonGrid/osdmRenderers/)

Всеки shared renderer приема:
```typescript
{
  element: OsdmElement,            // unified type, discriminated by kind
  cellSize: number,                 // px per grid cell (default 22)
  state?: {                         // optional visual state
    selected?: boolean,
    highlighted?: boolean,
    dropTarget?: boolean,
    invalid?: boolean,
  },
  interaction?: {                   // optional callbacks — determines edit vs read-only mode
    onClick?: (element) => void,
    onContextMenu?: (element, position) => void,
    onDragStart?: (element) => void,
    onResize?: (element, delta) => void,   // resize handles appear ONLY if provided
    onHover?: (element, hovering) => void,
  },
}
```

**Read-only mode** (composition view) = без `interaction` callbacks → renderer не показва resize dots, drag handles, hover cursors.
**Edit mode** (wagon editor) = с `interaction` → renderer активира affordance-и.

#### Един elements type не може да има два renderer-а

Lint / code review правило: ако имаш нужда да рендираш OSDM елемент вътре
във feature (compositions/ или wagons/), **трябва** да ползваш shared renderer.
Никаква локална реимплементация. Дивергенцията е премахната by construction.

### 🧪 TDD за Етап 6

За всеки таск:

1. **RED** — напиши failing тест(ове). `npm test` → ФЕЙЛВАТ по правилната причина
   (модулът не съществува, компонентът не рендира expected element).
2. **GREEN** — минимална имплементация. `npm test` → ПАСВАТ.
3. **VISUAL** (само Task 123) — screenshot compare с editor preview чрез
   cursor-ide-browser MCP. Визуален паритет задължителен.
4. **DONE** — `npm test && npm run type-check && npx eslint <files-changed-on-this-branch>` + (за #122, #124) +
   `npx playwright test` — чисто.

### 📁 Файлова структура (целева след Етап 6)

**Нови файлове:**
```
src/app/shared/wagonGrid/
├── index.ts                                    # public barrel
├── types/
│   ├── index.ts                                 # OsdmElement union, ElementState, ElementInteraction, CanonicalInput
│   └── __tests__/types.test.ts                  # type-level assertions
├── constants/
│   ├── index.ts                                 # WAGON_COLORS, CELL_TOKENS, Z_INDEX
│   └── __tests__/constants.test.ts
├── parse/
│   ├── parseOsdmLayout.ts                       # JSON string → normalized elements
│   ├── buildCanonicalInput.ts                   # compose seats + osdmLayout (+ legacy adapter)
│   └── __tests__/
│       ├── parseOsdmLayout.test.ts
│       ├── buildCanonicalInput.test.ts
│       └── buildCanonicalInput.legacyWagons.test.ts
├── classify/                                    # преместено от wagons/components/
│   ├── wallCells.ts
│   ├── wallCellClassification.ts
│   ├── wallShapes.ts
│   ├── wallTypes.ts
│   └── __tests__/ (преместени от wagons/components/__tests__/)
├── osdmRenderers/
│   ├── SeatRenderer.tsx
│   ├── BerthRenderer.tsx
│   ├── FoldingSeatRenderer.tsx
│   ├── WallRenderer.tsx                         # мигрирано от wagons/components/WallCellVisual.tsx
│   ├── WindowRenderer.tsx
│   ├── DoorRenderer.tsx
│   ├── ZoneRenderer.tsx
│   ├── TableRenderer.tsx
│   ├── BigTableRenderer.tsx
│   ├── StairsRenderer.tsx
│   ├── AmenityRenderer.tsx
│   ├── PlaceholderRenderer.tsx
│   └── __tests__/ (по един тест на компонент)
└── gridFrame/
    ├── GridContainer.tsx
    ├── GridCell.tsx
    ├── GridLayer.tsx
    ├── DragHighlightOverlay.tsx
    └── __tests__/
```

**Променени файлове:**
```
src/app/features/wagons/components/OsdmGrid.tsx                   # Task 122 (свива до ≤500 реда)
src/app/features/compositions/components/layoutRenderers/OpenSaloonLayout.tsx  # Task 123 (свива до ≤250 реда)
src/api/compositions/coachLayouts.api.ts                          # Task 123 (може да отпадне pixel conversion при review)
```

**НЕ-изтрити файлове (Етап 7 ги трие):**
```
src/app/features/compositions/components/layoutRenderers/
├── cellRenderers.tsx         # остава, просто не се import-ва повече
├── osdmRenderers.tsx         # остава
├── wallRenderers.tsx         # остава
├── SeatCell.tsx              # остава
├── zonePanel.tsx             # остава (или минимално опростен)
├── gridBuilder.ts            # остава (или минимално опростен)
├── CabinLayout.tsx           # остава, dispatch-ът в SeatMapCanvas не е пипан
├── SleeperLayout.tsx         # остава
├── CouchetteLayout.tsx       # остава
└── CompartmentLayout.tsx     # остава

src/app/features/wagons/components/
└── WallCellVisual.tsx        # ще остане, но като re-export от shared/wagonGrid/osdmRenderers/WallRenderer
                              # (за да не се счупят external import-и; Етап 7 ще го премахне)
```

### 🚨 Critical rules за Етап 6

1. **Никакъв breaking change на API контракта.** `CoachLayoutDto` с `seats[]` +
   `osdmLayoutJson` остава. `rendererType` поле остава (игнорира се, но не се
   трие). Backend-ът не се пипа.

2. **SeatMapCanvas dispatcher остава непроменен.** Маршрутизирането между
   OpenSaloonLayout и CabinLayout (sleeper/couchette) не се пипа в Етап 6.
   Композицията за спални вагони продължава да минава през CabinLayout.
   Это е за Етап 7 — обединяването на всички типове под OpenSaloonLayout.

3. **Adapter задължителен, не опционален.** Task 115 е критичен — без него
   легаси wagons се чупят в композицията. Не се skip-ва.

4. **Shared renderers = SSOT за визуалното.** Ако намериш inline rendering
   в OsdmGrid или OpenSaloonLayout, което не е preselect-но за премахване —
   това е знак че не си доизкарал extraction-а.

5. **Visual regression за Task 123 е задължителен.** Screenshot compare
   OpenSaloonLayout vs editor preview (drawer в WagonCreationPage) за реални
   wagon серии: 21-43, 21-50. Ако не са идентични — не е passed.

6. **Нула регресия за съществуващи тестове.** Baseline брой passing тестове
   се записва в RED phase на всеки migration таск (#116, #122, #123) и след
   DONE трябва да е СЪЩИЯТ брой. Ако падне — rollback, debug, retry.

### ✅ Success criteria per task (final check)

Преди да маркираш `"passes": true` за Етап 6 таск, провери:

1. ✅ Тестовете от RED phase сега ПАСВАТ
2. ✅ Съществуващите тестове — същият брой passing (нула регресия)
3. ✅ `npm run type-check` чист
4. ✅ `npx eslint <files-changed-on-this-branch>` — няма нови errors
5. ✅ За Task 122/124: `npx playwright test` минава
6. ✅ За Task 123: визуален screenshot compare е okay
7. ✅ За Task 122/123: размерните таргети са постигнати (≤500 / ≤250 реда)
8. ✅ Актуализиран activity.md запис
9. ✅ Git commit с **точното** `description` от tasks.json

### ⚠️ Отворени въпроси (решават се в хода на Етап 6)

1. **Kакво става със zonePanel.tsx side-panel zones?** Те идват от orchestration
   props (`zones`, `leftZones`), не от osdmLayoutJson. Решение в Task 115:
   legacy adapter ги мапва в OSDM zones synthetic → renderer-ите ги виждат
   както normal zones. В Task 123 — zonePanel.tsx не се ползва повече.

2. **OpenSaloonLayout public props contract — breaking или backward-compat?**
   Текущият компонент приема много legacy props. В Task 123 — запазваме ги
   (приема същия interface) но вътрешно ги route-ваме през adapter. Public
   API не се чупи, callers в SeatMapCanvas не се пипат.

3. **Wall rendering в OpenSaloonLayout** (ново в Етап 6, не е имало досега) —
   след Task 118 + 123, legacy wagons със structural WALL pseudo-seats ще
   показват стени чрез shared WallRenderer, защото adapter-ът (Task 115) ги
   синтезира. Това може да изглежда РАЗЛИЧНО от текущия render (legacy
   wallAfterColumns 3px divider vs. full OSDM WallRenderer cell-by-cell).
   Това **не е регресия** — то е визуализиране на данни, които досега не са
   се показвали коректно. Visual check в Task 123.7 го валидира.

---

## 🔁 Етап 7: Composition Cloning (Tasks #125, #130–#139)

**Фокус:** Frontend "Клониране" workflow върху съществуваща композиция.
Click "Клониране" → dialog с параметри (target train + date / период + дни от
седмицата) → POST към existing `/api/compositions/{id}/clone` → нова композиция.
**Бизнес правило:** блокирани места се пренасят; продадени/резервирани —
**не** (те са обвързани с конкретен маршрут+дата).

### Подетапи

| Под-етап | Таскове | Какво прави |
|---------|---------|-------------|
| **7A: BE audit + gap-fill** | #125 | Verify existing /clone endpoint; ако филтърът е грешен → fix; ако endpoint липсва → build minimal handler. **БЕЗ DB промени.** |
| **7B: FE foundation** | #130–#132 | API layer + mock backend (с критичния blocked-vs-sold филтър) + React Query hooks |
| **7C: FE UI** | #133–#136 | CloneCompositionDialog (4-step Stepper) + wiring + i18n + conflict preview |
| **7D: FE integration** | #137 | Full mock-flow тест с mixed state seed (асерт: blocked carry, sold не) |
| **7E: E2E verification** | #138–#139 | Playwright single + period clone (FE→BE) |

### 📜 Задължителни reference файлове

Преди да започнеш **всеки** таск от Етап 7:

1. **`C:/Users/kaloyan.georgiev/Projects/ralph/composition-clone-spec.md`** — single source of truth.
   Секции: §0 бизнес правило, §1 скоуп (какво НЕ пишем), §2 API контракти,
   §3 BE поведение (за #125), §4 FE архитектура, §5 тестове, §6 acceptance.
2. **`C:/Users/kaloyan.georgiev/Projects/ralph/PROMPT.md`** §"Existing aggregate repos" — за #125 ако
   се build-ва handler (използвай `ICompositionRepository` pattern, **не**
   generic `IRepository<T>`).
3. **`C:/Users/kaloyan.georgiev/Projects/admin-app-frontend-structure.md`** — за #130-#139.

### 🚨 Critical rules за Етап 7 (червени линии)

#### ❌ Никакви DB промени

Schema-та вече съществува. Тази feature е **чист consumer**.
- ❌ Никакви `.sql` файлове в `RailRunServiceSQL` проект
- ❌ Никакви EF migrations
- ❌ Никакви нови или променени Domain entities
- ❌ Никаква промяна на съществуващи таблици
- ✅ Само нови handlers/endpoints/DTOs (ако трябват) върху existing entities

Ако в Task #125 audit-а покаже, че бизнес правилото "blocked carry, sold не"
не може да бъде имплементирано **без** schema промяна → **STOP** и ескалирай.
**НЕ** пиши migration "за да заобиколиш" проблема.

#### 🔁 Endpoint-consumer model

- Task #125 е BE audit + минимален gap-fill (1 endpoint maximum, ако липсва).
- Period clone (`/clone-for-period`) НЕ се build-ва server-side по подразбиране
  — FE loop-ва над `/clone` за всеки expanded date.
- Conflict preview НЕ се прави като нов endpoint — FE filter-ва existing
  `GET /api/compositions?trainNumber=...&dateFrom=...` локално.

#### 🎯 Бизнес правило guard rails

Всеки таск пише поне един assertion за филтъра (blocked carry / sold не):
- Task #125 — integration test през TestServer
- Task #131 — mock storage unit тест със смесен seed (2 blocked + 3 sold + 1 reserved)
- Task #137 — full FE integration тест
- Task #138 — Playwright E2E: GET /api/compositions/{newId} → 0 bookings

Ако някой от тези тестове PASS-ва **без** реално да тества филтъра (напр.
seed-ът няма sold seats) → тестът е невалиден, не е acceptance.

### 🧪 TDD за Етап 7

Стандартен RED → GREEN → DONE. Без VISUAL phase за повечето задачи (UI-то
е стандартно MUI Stepper, не custom рисуване). VISUAL само за #133.4 — screenshot
на dialog през cursor-ide-browser MCP за документиране в `clone-dialog-current.png`.

### 📁 Файлова структура (целева след Етап 7)

```
Admin-App/
├── src/
│   ├── api/compositions/
│   │   ├── compositions.api.ts          (+ clone, cloneForPeriod, getClonePreview)
│   │   └── compositions.types.ts        (+ CloneCompositionDto, CloneResponse, DayOfWeek)
│   ├── app/features/compositions/
│   │   ├── components/
│   │   │   ├── CloneCompositionDialog.tsx                 (NEW — Task 133)
│   │   │   └── ConflictPreviewStep.tsx                    (NEW — Task 136)
│   │   └── hooks/
│   │       ├── useCloneComposition.ts                     (NEW — Task 132)
│   │       ├── useCloneCompositionForPeriod.ts            (NEW — Task 132)
│   │       └── useClonePreview.ts                         (NEW — Task 132)
│   ├── services/mockBackend/
│   │   └── mockStorage.ts                                 (+ cloneComposition method)
│   ├── utils/
│   │   └── dateRange.ts                                   (NEW — expandDateRange helper)
│   └── locales/
│       ├── bg.json                                        (+ compositions.clone.* keys)
│       └── en.json                                        (+ compositions.clone.* keys)
└── tests/compositions/
    ├── clone-single.spec.ts                               (NEW — Task 138)
    └── clone-period.spec.ts                               (NEW — Task 139)

RailRunService/  (ОПЦИОНАЛНО — само ако Task 125 Branch C се случи)
├── Application/Features/Compositions/Commands/
│   └── CloneComposition.cs                                (Command + Handler)
├── API/Controllers/CompositionsController.cs              (+ POST {id}/clone endpoint)
└── API/DTOs/Compositions/
    ├── CloneCompositionRequest.cs
    └── CloneCompositionResponse.cs
```

### ⚠️ Отворени въпроси (решават се в #125)

1. **Дали /clone endpoint вече съществува?** Ще се изясни в Step 125.1 (audit).
   Ако ДА → Branch A (документирай contract). Ако НЕ → Branch C (build minimum).
2. **Period clone server-side или FE loop?** Default: FE loop. Build server-side
   само ако audit покаже че endpoint вече съществува, или ако FE loop е >5s.
3. **`status` на новата composition при clone — `Draft` или `Active`?** Spec казва
   `Draft` (admin преглежда преди да активира). Ако в audit (125.1) се види че
   existing endpoint го прави `Active`, документирай и потвърди с product owner-а.
