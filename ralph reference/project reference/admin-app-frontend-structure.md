# Admin-App — Frontend Structure & Conventions

## Architecture

**React 19 + TypeScript + Vite** SPA with MUI, React Query, Zustand/Redux, React Router v7.

```
Admin-App/src/
├── api/              → HTTP clients, API functions per microservice
├── app/
│   ├── core/         → AuthGuard, auth.service, notification.service
│   ├── features/     → One folder per business feature (self-contained)
│   ├── layout/       → MainLayout (sidebar+header), AuthLayout
│   ├── routes/       → router.tsx (all route definitions)
│   └── shared/       → Reusable UI components, hooks, utils, types
├── hooks/            → App-level hooks (useTranslation, useApi)
├── store/            → Zustand stores + Redux slices
├── locales/          → bg.json, en.json
├── services/         → Business logic (seat allocation)
├── types/            → Global TypeScript types
└── tests/            → Vitest setup, mocks
```

---

## Routing

**File**: `src/app/routes/router.tsx` (React Router v7)

```
/login                    → LoginPage (public, AuthLayout)
/                         → HomePage (protected, MainLayout)
/compositions             → CompositionsListPage
/compositions/new         → CompositionEditorPage (create)
/compositions/:id/edit    → CompositionEditorPage (edit)
/users                    → UsersListPage
/roles                    → RolesListPage
/nomenclatures            → NomenclaturesPage
/tariffing/*              → Tariffing sub-routes
/iasutd/*                 → IASUTD sub-routes
```

All protected routes wrapped in `<AuthGuard>`.
E2E test mode: `localStorage.getItem('e2e_test_mode') === 'true'` bypasses auth.

---

## API Layer

### HTTP Clients

| File | Purpose |
|------|---------|
| `api/clients.ts` | Main `apiClient` for most services |
| `api/httpClient.ts` | Dedicated `httpClient` for RailRunService (compositions) |
| `api/config.ts` | Endpoint constants, timeouts |
| `api/interceptors.ts` | Token injection, 401 refresh |

Dev mode: baseURL = '' (Vite proxy in vite.config.ts routes to backends).

### API Subfolders

```
api/
├── compositions/          → RailRunService (compositions, wagons, seats, layouts)
│   ├── compositions.api.ts
│   ├── wagons.api.ts
│   ├── seats.api.ts
│   ├── coachLayouts.api.ts
│   ├── compositions.types.ts
│   ├── index.ts
│   └── __tests__/         → 15+ integration tests
├── roles/                 → UserService
├── users/                 → UserService
├── groups/                → UserService
├── nomenclatures/         → NomenclatureService
├── tariff/                → PricingService
├── iasutd/                → CashOperationsService
├── news/                  → News
└── schedule/              → Schedule
```

### Compositions API Functions

**compositionsApi** (`api/compositions/compositions.api.ts`):

| Function | HTTP | Endpoint | Notes |
|----------|------|----------|-------|
| `getAll(filters)` | GET | `/api/compositions` | Paginated, maps backend DTO |
| `getById(id)` | GET | `/api/compositions/{id}` | Returns composition + wagons |
| `create(dto)` | POST | `/api/compositions` | |
| `update(id, dto)` | PUT | `/api/compositions/{id}` | Partial update |
| `delete(id)` | DELETE | `/api/compositions/{id}` | |
| `updateStatus(id, status)` | POST | `/api/compositions/{id}/set-status` | Body: `{ status: "ACTIVE" }` |
| `activate(id)` | — | Calls `updateStatus(id, 'active')` | Convenience |
| `archive(id)` | — | Calls `updateStatus(id, 'archived')` | Convenience |

**wagonsApi** (`api/compositions/wagons.api.ts`):

| Function | HTTP | Endpoint |
|----------|------|----------|
| `getAll(compositionId)` | GET | `/api/compositions/{id}` (extracts carriages) |
| `add(compositionId, dto)` | POST | `/api/compositions/{id}/wagons` |
| `update(compositionId, wagonId, dto)` | PUT | `/api/compositions/{id}/wagons/{wagonId}` |
| `delete(compositionId, wagonId)` | DELETE | `/api/compositions/{id}/wagons/{wagonId}` |
| `reorder(compositionId, dto)` | PUT | `/api/compositions/{id}/wagons/reorder` |

**Other APIs**: `wagonTypesApi.getAll()`, `stationsApi.getAll()`, `trainsApi.getAll()`, `seatsApi.blockSeats/unblockSeats/getSeatStates`, `coachLayoutsApi.getBySeriesName/getById`

### Backend → Frontend Mapping

```
Backend BackendCompositionDto      →  Frontend Composition
─────────────────────────────────────────────────────────
compositionId                      →  id
trainNumber                        →  trainNumber, trainName
trainScheduleId                    →  trainId
validFrom / validTo                →  startDate / endDate
operationDays "1111100"            →  operatingDays (array or string)
status "ACTIVE"                    →  status "active" (lowercase)
allocationRules                    →  description
wagonCount                         →  totalWagons
```

All API functions return `ApiResponse<T>`: `{ data: T, success: boolean, message?: string }`

Backend wraps in `{ data: { data: T } }` (double-wrapped). API functions read `response.data.data`.
Exception: `stationsApi.getAll()` reads `response.data` directly.

---

## Compositions Feature

### File Structure

```
src/app/features/compositions/
├── components/
│   ├── CompositionList.tsx          → Table with edit/delete actions
│   ├── CompositionFilters.tsx       → Name, date range, status filters
│   ├── CreateCompositionModal.tsx   → Form: train, dates, operating days
│   ├── EditorHeader.tsx             → Editable name, status dropdown, save button
│   ├── WagonPalette.tsx             → Draggable wagon type list (left panel)
│   ├── WagonCanvas.tsx              → Sortable wagon list (center, dnd-kit)
│   ├── WagonCard.tsx                → Individual wagon card
│   ├── WagonPropertiesPanel.tsx     → Drawer: placard, stations, status
│   ├── SeatManagementPanel.tsx      → Fullscreen dialog for seat operations
│   ├── SeatMapCanvas.tsx            → Layout dispatcher → renderer
│   ├── SeatLegend.tsx               → Status colors + property icons
│   ├── SeatActionsToolbar.tsx       → Block/unblock buttons
│   ├── BlockSeatDialog.tsx          → Reason + description form
│   ├── SeatDetailsDialog.tsx        → View seat info
│   ├── SeatContextMenu.tsx          → Right-click menu
│   ├── layoutRenderers/
│   │   ├── OpenSaloonLayout.tsx     → Bezkupeen/EMU wagons (row-based)
│   │   ├── CabinLayout.tsx          → Sleeper/couchette/compartment
│   │   ├── CompartmentLayout.tsx    → Legacy compartment
│   │   ├── CouchetteLayout.tsx      → Legacy couchette
│   │   ├── SleeperLayout.tsx        → Legacy sleeper
│   │   └── layoutUtils.ts           → Shared rendering helpers
│   └── __tests__/
├── pages/
│   ├── CompositionsListPage.tsx     → List + filters + create modal
│   ├── CompositionEditorPage.tsx    → Drag-drop editor + save logic
│   └── SeatMapDemoPage.tsx          → Dev-only layout testing
├── types/
│   ├── composition.types.ts         → DraftWagon, editor props
│   └── seat.types.ts                → OSDM enums, Seat, CoachLayout
├── constants/
│   └── gridConstants.ts             → GRID_UNIT=22px, seat sizes
└── index.ts                         → Public exports
```

### Key Pages

**CompositionsListPage**: Fetches paginated compositions, renders filters + table + create modal. Delete with confirmation dialog. Filters stored in URL params.

**CompositionEditorPage**: Main editor. Layout: WagonPalette (left 25%) + WagonCanvas (center 75%). State tracking: `deletedWagonIds`, `modifiedWagonIds`, `newWagonIds`, `isReordered`. Save batches: delete → add → update → reorder. Name saves on blur (immediate API call). Status saves on dropdown change (immediate API call). Unsaved changes warning on navigation.

### Key Types

```typescript
// DraftWagon — local editor state for a wagon
interface DraftWagon {
  id: number              // Negative = unsaved new wagon
  compositionId: number
  wagonTypeId: number
  placardNumber: string
  wagonNumber: string
  position: number        // 1-based
  status: 'active' | 'inactive'
  capacity: number
  startStation: string
  endStation: string
  type: string
  category: string
  backgroundColor: string
  borderColor: string
}

// Seat — OSDM-compliant seat representation
interface Seat {
  id: number
  number: string
  coordinates: { gridX: number, gridY: number }
  type: AccommodationType   // SEAT, BERTH, COUCHETTE, TABLE, etc.
  properties: SeatProperty[] // WINDOW, AISLE, POWER_SOCKET, etc.
  status: SeatStatus        // AVAILABLE, BLOCKED, LOCKED, BOOKED
  wagonId: number
  blockInfo?: { reason, description, blockedAt, blockedBy }
}

// AccommodationType enum
SEAT | FOLDING_SEAT | BERTH | COUCHETTE | WHEELCHAIR_SPACE |
TABLE | BIG_TABLE | WALL | WC | GAP | ZONE | CORRIDOR | STAIRS

// SeatStatus enum
AVAILABLE | BLOCKED | LOCKED | BOOKED

// SeatProperty enum
WINDOW | AISLE | TABLE | FACING_LEFT | FACING_RIGHT |
QUIET_ZONE | POWER_SOCKET | FIRST_CLASS
```

### Layout Renderers

**SeatMapCanvas** dispatches to renderer based on `layout.rendererType`:
- `ROWS` → **OpenSaloonLayout** (bezkupeen/EMU wagons, corridor detection, bay groups)
- `CABIN` → **CabinLayout** (auto-detects sleeper/couchette/compartment from seat types)

**Grid system**: `GRID_UNIT = 22px`, seats span 2×2 units. Coordinates from backend `SeatDefinition.gridX/gridY`.

---

## State Management

### What Goes Where

| State type | Where | Example |
|------------|-------|---------|
| Server data (lists) | React Query or Redux thunks | Composition list, pagination |
| Auth | Zustand `useAuthStore` | User, tokens |
| i18n | Zustand `useI18nStore` | Locale, translations |
| UI (snackbar, sidebar) | Redux `ui.slice` | Theme, notifications |
| Editor session | Local state in page component | Wagons, dirty tracking |
| Seat selection | Local state in SeatManagementPanel | selectedSeatIds[] |

### CompositionEditorPage State

```typescript
// API data
composition: Composition | null
wagons: Wagon[]
train: Train | null
wagonTypes: WagonType[]
stations: Station[]

// Change tracking
isDirty: boolean
deletedWagonIds: number[]
modifiedWagonIds: Set<number>
newWagonIds: Set<number>          // Negative temp IDs
isReordered: boolean
nextTempIdRef: useRef(-1)         // Counter for new wagon IDs

// UI state
selectedWagonId: number | null
isPropertiesPanelOpen: boolean
isSeatPanelOpen: boolean
isSaving: boolean
saveError: string | null
```

---

## i18n

### Hook Usage

```typescript
const { t } = useTranslation()
t('compositions.status.draft')           // → "Чернова"
t('compositions.train', { number: '2601' }) // → "Влак 2601"
```

### Translation Key Convention

`domain.component.element`:
```
compositions.title
compositions.list.filters.name
compositions.list.table.name
compositions.status.draft / .active / .archived
compositions.editor.header.save / .saving / .back
compositions.editor.palette.title / .classFilter / .allClasses
compositions.editor.palette.categories.compartment / .secondClass / .sleeper / .bistro
compositions.editor.canvas.title
compositions.editor.properties.placardNumber / .startStation / .endStation
compositions.dialogs.unsavedChanges.title / .message / .save / .discard / .cancel
```

Always add keys to **both** `bg.json` AND `en.json`.

---

## Testing

### Framework

Vitest + React Testing Library + jsdom

```bash
npm run test         # watch mode
npm run test:run     # single run (CI)
npm run type-check   # tsc --noEmit
npx eslint .         # lint
```

### Vitest Config (vite.config.ts)

```typescript
test: {
  globals: true,
  environment: 'jsdom',
  setupFiles: './src/tests/setup.ts',
  css: true,
  testTimeout: 15000,
  pool: 'forks',
  maxWorkers: 2,
  poolOptions: { forks: { maxForks: 4 } }
}
```

### Test Patterns

**Component test**:
```typescript
vi.mock('@/hooks/useTranslation', () => ({
  useTranslation: () => ({
    t: (key: string) => {
      const translations: Record<string, string> = {
        'compositions.editor.header.save': 'Запази',
        // ...
      }
      return translations[key] || key
    }
  })
}))

describe('ComponentName', () => {
  it('should render', () => {
    render(<BrowserRouter><Component {...props} /></BrowserRouter>)
    expect(screen.getByTestId('xxx')).toBeInTheDocument()
  })
})
```

**API integration test** (mocks httpClient):
```typescript
vi.mock('@/api/httpClient', () => ({
  httpClient: { get: vi.fn(), post: vi.fn(), put: vi.fn(), delete: vi.fn() }
}))

// Mock response: double-wrapped
mockedHttpClient.post.mockResolvedValueOnce({
  data: { data: backendDto }    // response.data.data
})

// Exception: stationsApi uses single wrap
mockedHttpClient.get.mockResolvedValueOnce({
  data: stationsArray            // response.data
})
```

### Mock Data Conventions

- Composition mocks need ALL required fields: `id, trainId, trainNumber, trainName, startDate, endDate, operatingDays, status, description, totalWagons, createdAt, updatedAt`
- WagonType mocks: `id, type, code, category, capacity, backgroundColor, borderColor`
- Station mocks: `{ id, name, code }`

---

## Component Conventions

### File Naming

| What | Convention | Example |
|------|-----------|---------|
| Components | PascalCase `.tsx` | `CompositionList.tsx` |
| Pages | PascalCase `Page.tsx` | `CompositionsListPage.tsx` |
| Hooks | camelCase `use*.ts` | `useTranslation.ts` |
| API modules | camelCase `.api.ts` | `compositions.api.ts` |
| Types | camelCase `.types.ts` | `composition.types.ts` |
| Tests | `ComponentName.test.tsx` | `EditorHeader.test.tsx` |
| Redux slices | kebab-case `.slice.ts` | `ui.slice.ts` |
| Zustand stores | camelCase `.store.ts` | `auth.store.ts` |

### Import Paths

Always use `@/` alias (maps to `src/`):
```typescript
import { compositionsApi } from '@/api/compositions'
import { useTranslation } from '@/hooks/useTranslation'
import type { Composition } from '@/api/compositions/compositions.types'
```

Cross-feature imports: only through feature's `index.ts`.

### Component Patterns

- Functional components only
- Pages: data fetching + layout. Sub-components: presentational
- Always handle loading, empty, error states
- MUI components throughout (Button, TextField, Select, Dialog, Paper, etc.)
- Drag-drop: `@dnd-kit/core` + `@dnd-kit/sortable`
- Forms: `react-hook-form` + `zod` resolver

### Error Handling in API

```typescript
catch (error: any) {
  const errorData = error?.response?.data as ApiResponse<unknown> | undefined
  const errorMessage = errorData?.message
    || (errorData as any)?.error      // backend uses .error field
    || error?.message
    || 'Default fallback message'
  return { data: null, success: false, message: errorMessage }
}
```

---

## Vite Proxy (Development)

```typescript
// vite.config.ts proxy routes
'/api/compositions'    → http://localhost:6011
'/api/wagon-types'     → http://localhost:6011
'/api/trains'          → http://localhost:6011
'/api/stations'        → http://localhost:6011
'/api/coach-layouts'   → http://localhost:6011
'/api/carriages'       → http://localhost:6011
'/nomenclature-service/api/*' → http://localhost:6005
'/user-service/api/*'  → http://localhost:6006
'/pricing-service/api/v1/*' → http://localhost:6001
'/cash-operations-service/api/v1/*' → http://localhost:6013
'/accounting-service/api/v1/*' → http://localhost:6002
```

---

## Build & Run

```bash
npm run dev          # Start dev server (port 3000)
npm run build        # Production build
npm run type-check   # TypeScript check
npm run lint         # ESLint
npm run test         # Vitest (watch)
npm run test:run     # Vitest (single run)
```
