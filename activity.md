## 📚 Етап 2: Advanced Seat Management & TDD Mastery (Tasks #44-#80)

**Фокус:** Пълна seat management система с TDD workflow и визуално тестване

---

## 🛠️ Инфраструктура и подготовка

### Task #1: Multi-Select Mode Infrastructure (COMPLETE)

**Какво е:**
- Checkbox mode за селектиране на множество седалки
- Orange border около вагона когато е активен
- Controls: Select All, Clear Selection
- Batch операции (Block/Unblock множество седалки)

**Защо преди другите:**
1. Нужен за Task #48 (да може да се тестват batch operations)
2. Нужен за Task #50 (да се записват bulk операции в историята)
3. По-лесно се тества функционалността с multi-select

**Имплементация:**
1. Add `isMultiSelectMode` state в SeatManagementPanel
2. Show orange border когато е true
3. Checkboxes вместо click selection
4. Select All Available / Clear Selection buttons
5. Enable Block/Unblock само ако има селекция

### Task #45: Seat History Tracking (localStorage) (COMPLETE)

**Какво е:**
- Запис на всяка операция в localStorage
- Структура: `{ timestamp, action: 'BLOCK'|'UNBLOCK', seatIds, reason?, performedBy }`
- Показва се в Task #49 (Seat Details Dialog)

**Защо сега:**
- Нужен преди #49 защото dialog чете от историята
- Нужен преди #50 защото то е само UI за показване

**Имплементация:**
1. `localStorage['seat_history_wagonId'] = JSON.stringify([])`
2. При block/unblock → push нов запис
3. Keep last 100 entries per wagon
4. Add helper функции за четене/писане

---

## 📋 Core Seat Management Features

### Task #46: Block Seats with Reasons (COMPLETE)

**TDD фази:** RED → GREEN → REFACTOR → DONE
- RED: Write dialog tests first
- GREEN: Create dialog component
- REFACTOR: Style to match designs
- DONE: Full integration test

**Компоненти:**
1. BlockSeatDialog с 4 predefined reasons + custom
2. Shows selected seat numbers
3. Custom reason textarea (ако е избран "Other")
4. Confirmation → API call → Update UI

### Task #47: Unblock Seats Functionality (COMPLETE)

**Процес:**
1. Enable Unblock button when BLOCKED seats selected
2. Simple confirmation dialog
3. API call to unblock
4. Update UI + history

### Task #48: Batch Seat Operations (COMPLETE)

**Функции:**
- Block/Unblock multiple seats едновременно
- Използва multi-select mode от Task #1
- Single API call с всички seat IDs
- Progress indicator за големи селекции

### Task #49: Seat Details Dialog (COMPLETE)

**Показва:**
- Seat number, type, status, properties
- Block reason (ако е блокирана)
- История на операциите от Task #45
- Close button

### Task #50: Seat History Display in Details (COMPLETE)

**Компонент:**
- Timeline показваща всички операции
- Взима данни от localStorage (Task #45)
- Shows: timestamp, action, user (placeholder)
- Chronological order

---

## 🔐 API Integration (Backend Ready)

### Task #84-#87: API Setup & Integration

**Task #84:** Proxy config `/api/*` → RailRunService
**Task #85:** Create SeatMap component wrapper
**Task #86:** Fetch layouts от `/api/coach-layouts`
**Task #87:** Store/retrieve seat states

---

## 📝 TDD Workflow за всеки таск

### RED фаза (Write Failing Tests)
```typescript
// Example за Task #46
test('should show block dialog when Block button clicked', () => {
  render(<BlockSeatDialog .../>);
  expect(screen.getByRole('dialog')).toBeInTheDocument();
});
// RUN → Expect FAIL ❌
```

### GREEN фаза (Make Tests Pass)
```typescript
// Implement BlockSeatDialog component
function BlockSeatDialog({...}) {
  return <Dialog role="dialog">...</Dialog>
}
// RUN → Tests PASS ✅
```

### REFACTOR фаза (Match Designs)
- Compare с mockups от `designs/`
- Adjust colors, spacing, typography
- Use exact MUI theme values

### DONE фаза (Integration)
- Connect всички части
- Test full user flow
- Verify с visual snapshot

---

## 🎨 Visual Test Process

### За всеки UI task:

1. **Implement компонента** (TDD)
2. **Start dev server**: `npm run dev`
3. **Open Playwright**: Navigate to component
4. **Screenshot**: Save as `actual_${taskId}.png`
5. **Compare**: Open `designs/${taskId}.png`
6. **Iterate**: Докато не са ~95% еднакви

### Checklist за визуално съвпадение:
- [ ] Цветове (exact hex values)
- [ ] Typography (h6, body1, caption)
- [ ] Spacing (8px, 16px, 24px)
- [ ] Shadows (MUI elevation levels)
- [ ] Border radius (4px, 8px)
- [ ] Icons (Material Icons)
- [ ] Hover states

---

## 🚀 Implementation Order

### Phase 1: Infrastructure
1. ✅ Task #1: Multi-Select Mode
2. ✅ Task #45: History Tracking

### Phase 2: Core Features
3. ✅ Task #46: Block with Reasons
4. ✅ Task #47: Unblock
5. ✅ Task #48: Batch Operations
6. ✅ Task #49: Details Dialog
7. ✅ Task #50: History Display

### Phase 3: Polish & Testing
8. Task #41: Final Visual Refinements

---

## 📋 Verification за всеки task

След като task е "complete":

1. **Unit tests pass**: `npm test`
2. **E2E tests pass**: `npx playwright test`
3. **Linter clean**: `npm run lint`
4. **TypeScript compiles**: `npm run type-check`
5. **Visual match**: Screenshot comparison ✅
6. **Git commit**: With descriptive message
7. **Update activity.md**: Log какво беше направено

---

## 💡 Tips & Tricks

### localStorage Keys
- `seat_history_${wagonId}` - операции за вагон
- `bdz_auth` - user session (за performedBy)

### API Endpoints
- `POST /api/seats/block` - block seats
- `POST /api/seats/unblock` - unblock seats
- `GET /api/wagons/${id}/seats` - get seat states

### Component Reuse
- `SeatLegend` - използвай за всички статуси
- `ConfirmDialog` - generic за всички confirmations
- `SeatStatusChip` - consistent status display

---

## 🎨 Design System Values

**Colors:**
- Primary Green: #2e7d32
- Available: #4caf50
- Blocked: #9e9e9e
- Booked: #f44336
- Selected: #2196f3

**Spacing:**
- xs: 4px
- sm: 8px
- md: 16px
- lg: 24px
- xl: 32px

**Typography:**
- h4: Page titles
- h6: Card titles, dialog titles
- body1: Main content
- body2: Secondary content
- caption: Helper text

**Elevations:**
- Card: elevation={2}
- Dialog: elevation={24}
- Hover: elevation={4}

---

## 🔄 State Management

За всеки таск помни:
1. Update Zustand store правилно
2. Sync с localStorage when needed
3. Pessimistic updates (wait for API)
4. Error handling с toast messages
5. Loading states

---

## 🎯 Final Checklist за Етап 2

- [ ] Всички 15 таска complete
- [ ] 100% test coverage
- [ ] Visual regression tests
- [ ] Performance audit
- [ ] Accessibility audit
- [ ] Documentation updated
- [ ] Git history clean
- [ ] Ready за production

---

## Activity Log

### Visual Testing Setup

1. **Screenshot comparison process:**
   - После GREEN фаза (tests pass)
   - `npm run dev` → отвори компонента
   - Playwright screenshot
   - Сравни с `designs/${taskId}.png`
   - Iterate до match

2. **Playwright screenshot example:**
```javascript
// Navigate
await page.goto('http://localhost:5173/seat-management');
// Screenshot
await page.screenshot({
  path: `screenshots/actual_task46.png`,
  fullPage: false
});
```

3. **Visual diff checklist:**
   - Colors ✅
   - Spacing ✅
   - Typography ✅
   - Shadows ✅
   - Alignment ✅

4. **Visual validation checklist:**
   - ✅ Seat numbers visible and correct
   - ✅ Colors match status (green/red/gray/blue)
   - ✅ Layout matches CoachLayout coordinates
   - ✅ Missing seats not rendered
   - ✅ Legend overlay positioned correctly
   - ✅ Icons for properties (window, power socket)

---

## 🎨 Task #41: Final UI Refactoring

> **Критичен таск:** След всички TDD имплементации, този таск гарантира 100% визуално съответствие с дизайните

### Защо е нужен:

TDD workflow гарантира:
- ✅ Функционалност (тестовете минават)
- ✅ Бизнес логика (правилата работят)

НО не винаги гарантира:
- ❌ 100% визуално съвпадение с дизайните
- ❌ Точни цветове, spacing, typography
- ❌ Shadows, borders, elevations

### Task #41 process:

**AUDIT фаза:**
1. Отвори ВСИЧКИ 14 design files
2. Отвори app в browser
3. Сравни side-by-side всеки компонент
4. Създай checklist с discrepancies

**REFACTOR фаза:**
5. Fix colors (primary #2e7d32)
6. Fix wagon cards (colored backgrounds)
7. Fix badges (green #2e7d32)
8. Fix spacing (16px gaps)
9. Fix typography (h6/body1/caption)
10. Fix seat map (green header, bright seats)
11. Fix shadows (MUI elevations)

**VISUAL фаза:**
12. Screenshot comparison за всички компоненти
13. Verify 95%+ visual match

**DONE фаза:**
14. Run all tests (verify nothing broke)
15. Final inspection
16. Commit

---

**Ralph, start logging Етап 2 work here! Update after EVERY completed task.** 📝

## [2026-03-24 11:18] - Task #51: Update osdm_layout_json for wagon_type_id=2 (series 15-63) with OSDM internals/signs

**Status:** ✅ Complete

**What was done:**
- Read 004_Coach_Layouts.sql seed file and located wagon_type_id=2 entry
- Read wagon migration reference 02_series_15-63.md to get OSDM JSON structure
- Updated osdm_layout_json with complete OSDM data including:
  - gridSize: 40x10
  - internals: 2 WCs (code 115), 8 tables (code 20), 1st class zone (code 101)
  - signs: 2 doors (code 179), 4 windows (code 135)
  - aisle: y=6
- Validated JSON structure using Node.js JSON.parse()

**Files modified:**
- C:\Projects\BDZ Project\OSDM-Src\SQLProjects\RailRunServiceSQL\dbo\PostDeployment\Data\004_Coach_Layouts.sql

**Git commit:**
- feat(db): Update osdm_layout_json for series 15-63 with OSDM internals/signs

---

## [2026-03-24 12:03] - Task #52: Add OSDM icon registry and data-driven rendering support to OpenSaloonLayout

**Status:** ✅ Complete

**TDD Phase:** RED → GREEN → DONE

**What was done:**
### RED Phase
- Step 52.1: Created OSDM rendering tests in OpenSaloonLayout.osdm.test.tsx
- Step 52.2-52.6: Added tests for WC, table, door, window, and zone rendering
- Step 52.7: Added test for OSDM icon map existence
- Ran tests - 6 FAILED ✅ (as expected in RED phase)

### GREEN Phase
- Added OsdmLayoutJson interface to seat.types.ts
- Updated CoachLayout interface to include osdmLayoutJson property
- Modified coachLayoutsApi.ts to parse and map osdmLayoutJson from backend
- Created osdmIcons.ts with OSDM_ICON_MAP registry
- Updated OpenSaloonLayout to accept osdmLayoutJson prop
- Implemented data-driven rendering logic for OSDM internals and signs
- Fixed coordinate mapping to include OSDM element positions
- Ran tests - ALL PASSED ✅

### Verification Phase
- All OSDM tests: PASSED ✅
- Backward compatibility tests: PASSED ✅
- Linter: PASSED (warnings only) ✅
- TypeScript: PASSED ✅

**Files modified:**
- src/app/features/compositions/types/seat.types.ts (added OsdmLayoutJson interface)
- src/api/compositions/coachLayouts.api.ts (added osdmLayoutJson mapping)
- src/app/features/compositions/constants/osdmIcons.ts (created new file)
- src/app/features/compositions/components/layoutRenderers/OpenSaloonLayout.tsx
- src/app/features/compositions/components/SeatMapCanvas.tsx
- src/app/features/compositions/components/layoutRenderers/__tests__/OpenSaloonLayout.osdm.test.tsx

**Git commit:**
- `feat(compositions): Add OSDM icon registry and data-driven rendering support to OpenSaloonLayout`

---

## [2026-03-24 12:12] - Task #53: Remove hardcoded table/WC/door positions from OpenSaloonLayout for series 15-63

**Status:** ✅ Complete

**TDD Phase:** Verification → DONE

**What was done:**
### Analysis Phase
- Analyzed OpenSaloonLayout implementation to understand data-driven vs hardcoded rendering
- Verified that `hasOsdmData()` function correctly detects OSDM data presence
- Confirmed that when OSDM data is present, only OSDM elements are rendered

### Test Phase
- Added tests to verify NO hardcoded elements when OSDM data is present
- Tests verify exactly 2 tables, 2 WCs, and 2 doors from OSDM data only
- Tests ensure all structural elements have `osdm-` prefix in their test IDs

### Verification Phase
- All tests PASSED immediately - implementation was already correct from Task #52
- The data-driven rendering implementation already excludes hardcoded elements
- No code changes needed - Task #52 implementation already satisfied Task #53 requirements

**Key findings:**
- OpenSaloonLayout renders structural elements from two sources:
  1. Seats with AccommodationType.WC/TABLE from database (when no OSDM data)
  2. OSDM internals/signs arrays (when OSDM data is present)
- When OSDM data exists, only OSDM elements are rendered for structural items
- Regular seats are always rendered from the database seats array

**Files modified:**
- src/app/features/compositions/components/layoutRenderers/__tests__/OpenSaloonLayout.osdm.test.tsx (added Task #53 tests)

**No commit needed** - functionality already implemented in Task #52

---

## [2026-03-24 13:00] - Task #54: Wire osdmLayoutJson from API to OpenSaloonLayout

**Status:** ✅ Complete

**TDD Phase:** RED → GREEN → DONE

**What was done:**
### RED Phase
- Created comprehensive test suite in OpenSaloonLayout.wiring.test.tsx
- Tests verified:
  - osdmLayoutJson prop is received by OpenSaloonLayout
  - OSDM elements render when data is present
  - No OSDM elements render when data is absent
  - Data flows through SeatMapCanvas correctly
  - Legacy rendering works when osdmLayoutJson is undefined
  - Legacy hardcoded rendering is disabled when OSDM data is present

### GREEN Phase
- Discovered that wiring was already implemented:
  - coachLayoutsApi.ts already parses osdmLayoutJson from backend (lines 166-173)
  - SeatMapCanvas already passes osdmLayoutJson to OpenSaloonLayout (line 195)
  - OpenSaloonLayout already receives and uses the prop
- Fixed test coordinate issues to match grid system
- Added guard to prevent duplicate WC rendering from seats array when OSDM data is present

### Verification Phase
- All tests: PASSED ✅
- No TypeScript errors ✅
- Linter warnings only ✅
- Implementation is fully functional

**Files modified:**
- src/app/features/compositions/components/layoutRenderers/__tests__/OpenSaloonLayout.wiring.test.tsx (created)
- src/app/features/compositions/components/layoutRenderers/OpenSaloonLayout.tsx (added WC rendering guard)

**Key findings:**
- The wiring infrastructure was already in place from Task #52
- Only needed to add a guard condition to prevent duplicate WC rendering
- Task #54 requirements were essentially satisfied by the Task #52 implementation

**Git commit:**
- `test(compositions): Add comprehensive tests for osdmLayoutJson wiring to OpenSaloonLayout`
- `fix(compositions): Add guard to prevent duplicate WC rendering when OSDM data is present`

---