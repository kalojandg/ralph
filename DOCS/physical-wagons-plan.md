# Physical wagons — implementation plan (Option B+)

> **Status:** Planned (2026-05-21).
> **Source spec:** [wagon-inventory-spec.md](../wagon-inventory-spec.md) §0 (Super-MVP Option B chosen).
> **Scope decision:** Option B (clone WagonType, no new tables) **plus** a lightweight placard-availability filter in the composition palette — strictly less than Option C (temporal validation). BP-COMP-12 audit log remains explicitly OUT of scope (Option D, future).

---

## 1. Business framing

### 1.1 What changes conceptually

| Today | After this work |
|---|---|
| `WagonType` = "series" — abstract template (e.g. "21-43"). | Each `WagonType` row represents either a **template** (the series prototype) or a **specific physical wagon** (a clone of the template, identified by its own placard / inventory number). |
| Two wagons of series 21-43 share one `WagonType.Id` and one `CoachLayout`. | A retrofitted unit of series 21-43 gets its **own** `WagonType` row + `CoachLayout` + `SeatDefinitions` (cloned, then editable). |
| Composition palette lists *types* — the dispatcher manually avoids re-using the same physical wagon. | Composition palette lists the **physical instances**; ones already used in another composition with overlapping dates show as **disabled with a tooltip**, so the dispatcher can no longer pick them by accident. Same composition cannot list the same placard twice (already enforced). |
| `CompositionCarriage.PlacardNumber` is just a sticker — unrelated to inventory. | `PlacardNumber` is the *operational identifier* of the physical instance. Cloning a wagon **requires** picking a new placard. |

### 1.2 Out of scope (explicit)

- New tables (`PhysicalWagon`, `WagonAssignment`, `WagonRouteOperation`, `WagonTechnicalIncident`) — Option D only.
- Geographic chain validation (`prev.endStation == curr.startStation`) — Option D only.
- Full audit log for BP-COMP-12 — Option D only.
- Bicycle / wheelchair "ancillary" sales flow — handled organically by adding `SeatDefinition` rows with `AccommodationType=STORAGE`/`WHEELCHAIR_SPACE` to the cloned layout (no new code path).

---

## 2. Backend (RailRunService)

### 2.1 Clone command (`Application/Features/Nomenclatures/Commands/CloneWagonType.cs`)

```csharp
public class CloneWagonTypeCommand : IRequest<Result<WagonTypeDto>>
{
    public long SourceWagonTypeId { get; set; }
    public string NewSeriesName { get; set; } = null!;   // displayed identifier, unique
    public string? InventoryNumber { get; set; }         // optional UIC, unique if set
    public string? Operator { get; set; }
    public string? HomeDepot { get; set; }
    public int? ManufactureYear { get; set; }
    public string? Notes { get; set; }
    public int? OverrideBicycleSpaces { get; set; }
    public int? OverrideWheelchairSpaces { get; set; }
}
```

Handler responsibilities:
1. Load source `WagonType` + `CoachLayout` + `SeatDefinitions` via `Include` from the aggregate repo (single read).
2. Copy `WagonType` row (overrides applied, `Status='Active'`, `ParentWagonTypeId=source.Id`).
3. Copy `CoachLayout` row (same JSON / grid sizes / renderer).
4. Copy every `SeatDefinition` (new `LayoutId`, identical seat numbers / coordinates / attributes).
5. If `OverrideBicycleSpaces` / `OverrideWheelchairSpaces` are set, append/replace `SeatDefinition` rows with `AccommodationType=STORAGE` + `AccommodationSubType=BICYCLE`, or `AccommodationType=WHEELCHAIR_SPACE`.
6. One `SaveChangesAsync` via the aggregate repo (single backend transaction — per `railrun-backend-structure.md` "one logical write → one SaveChanges").

Validation (handler-side, in addition to DataAnnotations):
- `SourceWagonTypeId` exists and is `Status='Active'`.
- `NewSeriesName` is unique (case-insensitive) across `WagonTypes`.
- `InventoryNumber`, if set, is unique across `WagonTypes` (case-insensitive, trimmed).
- `OverrideBicycleSpaces + OverrideWheelchairSpaces <= GridWidth * GridLength - other-cells-in-use`.

### 2.2 Schema additions (single declarative migration)

`WagonTypes` table:
- `ParentWagonTypeId BIGINT NULL` — self-FK to the template row. Lets list/reporting UIs group "21-43 + 21-43 #001 + 21-43 #002".
- `InventoryNumber NVARCHAR(20) NULL` — optional UIC string. No unique constraint yet (legacy series can't satisfy it); FE/BE enforce uniqueness in application code, with the option to add a `UNIQUE WHERE InventoryNumber IS NOT NULL` filtered index in a follow-up once legacy data is backfilled.
- `Operator NVARCHAR(10) NULL`, `HomeDepot NVARCHAR(50) NULL`, `ManufactureYear INT NULL`, `Notes NVARCHAR(MAX) NULL` — administrative fields surfaced in the clone dialog.

### 2.3 Placard-availability query (`GetAvailableWagonTypesForComposition`)

Returns the wagon types that *can* be added to the given composition without colliding with another **active** composition that shares operating days within `[StartDate, StartDate]` (single-day model). A "collision" means: the same `WagonType.Id` is already on a `CompositionCarriage` of another `Status='Active'` composition with the same `StartDate`.

Pseudo:
```csharp
var sameDayCompositionIds = await _compositionRepo.GetQueryable()
    .Where(c => c.Status == "ACTIVE" && c.StartDate == targetStartDate && c.Id != currentCompositionId)
    .Select(c => c.Id)
    .ToListAsync(ct);

var occupiedTypeIds = await _carriageRepo.GetQueryable()
    .Where(cc => sameDayCompositionIds.Contains(cc.CompositionId) && cc.IsActive)
    .Select(cc => cc.WagonTypeId)
    .Distinct()
    .ToListAsync(ct);

var allTypes = await _wagonTypeRepo.GetQueryable().Where(t => t.Status == "Active").ToListAsync(ct);
return allTypes.Select(t => new AvailableWagonTypeDto
{
    WagonTypeId = t.Id,
    IsAvailable = !occupiedTypeIds.Contains(t.Id),
    OccupiedByCompositionId = occupiedTypeIds.Contains(t.Id) ? /* lookup */ : null,
});
```

The endpoint returns ALL types with an `isAvailable` flag (so palette can render the disabled ones with tooltip). No `Composition.Status='DRAFT'` involvement — drafts don't reserve physical wagons.

### 2.4 Endpoint surface

- `POST /api/wagon-types/{id}/clone` → `CloneWagonTypeCommand`.
- `GET /api/wagon-types/available?compositionId=N` → `IReadOnlyList<AvailableWagonTypeDto>`.

### 2.5 Test coverage (unit + integration)

- `CloneWagonTypeCommandHandlerTests`: happy path copies all seat defs, isolated references, override-bicycle adds correct seat defs, conflict on duplicate `NewSeriesName`, conflict on duplicate `InventoryNumber`.
- `GetAvailableWagonTypesForCompositionTests`: returns all-available on draft composition, marks occupied types for same-date active comp, ignores DRAFT compositions.

---

## 3. Frontend (Admin-App)

### 3.1 Wagon types list — clone button

`src/app/features/wagons/pages/WagonTypesListPage.tsx` (or the equivalent list page — confirm via GitNexus before implementation): add a row-level action menu with **"Клонирай"** that opens `CloneWagonTypeDialog`.

### 3.2 `CloneWagonTypeDialog`

Sections (per spec §0.4.B-E):
- **Source preview (read-only):** series name, travel class, compartment type, capacity, seat count.
- **Mandatory identification:**
  - `seriesName` — text, default `${source.seriesName} #${counter}`; FE checks uniqueness against loaded list.
  - `inventoryNumber` — text, **recommended** but not required for now; if filled, FE validates format + uniqueness.
- **Per-physical metadata (optional):** `operator` (dropdown), `homeDepot`, `manufactureYear`, `notes`.
- **Retrofit overrides (optional):** `bicycleSpaces` (number), `wheelchairSpaces` (number) — handler will append matching `SeatDefinition` rows.
- **Action:** "След клониране, отвори в layout редактор" checkbox, default ON → navigate to `/wagons/${newId}/edit` after success.

Validation surfaces both FE pre-submit checks and BE error codes (`WagonTypeSeriesNameDuplicate`, `WagonTypeInventoryNumberDuplicate`).

### 3.3 API + hook

- `wagonsApi.clone(sourceId: number, dto: CloneWagonTypeDto): Promise<ApiResponse<WagonType>>`.
- `useCloneWagonType(sourceId)` — React Query mutation; invalidates `['wagon-types']` on success.

### 3.4 Composition editor — palette filtering

Replace the current "every wagon type, always" palette source (`wagonTypesApi.getAll`) with `wagonTypesApi.getAvailable(compositionId)` driven by `useQuery({ enabled: composition?.id != null })`. Map the BE response to the existing `WagonPalette` props by:

- Keeping every type in the list (so the dispatcher sees what *would* be available if it weren't taken).
- Using `disabledRule='occupied'` (new enum entry) or wiring through `isCardDisabled` directly with a per-card boolean from the BE response.
- Tooltip i18n key `compositions.editor.palette.tooltipOccupiedByComposition` (with `{compositionId}`/`{trainNumber}` interpolation).

The existing traction-mix logic from §3.x stays untouched — both filters compose (a wagon type is enabled only if it passes BOTH `canAddWagonType` and `isAvailable`).

### 3.5 i18n keys

```
wagons.list.clone = "Клонирай"
wagons.clone.dialog.title = "Клониране на вагон"
wagons.clone.dialog.sourcePreview = "Източник: {seriesName} ({capacity} места)"
wagons.clone.dialog.newSeriesName = "Нова серия / идентификатор"
wagons.clone.dialog.inventoryNumber = "UIC номер"
wagons.clone.dialog.operator = "Превозвач"
wagons.clone.dialog.homeDepot = "Опорно депо"
wagons.clone.dialog.manufactureYear = "Година на производство"
wagons.clone.dialog.bicycleSpaces = "Места за велосипед"
wagons.clone.dialog.wheelchairSpaces = "Места за инвалидна количка"
wagons.clone.dialog.openLayoutAfter = "Отвори в layout редактора"
wagons.clone.success = "Вагонът е клониран успешно"
wagons.clone.errors.seriesDuplicate = "Серия с това име вече съществува"
wagons.clone.errors.inventoryDuplicate = "Този UIC номер вече е регистриран"
compositions.editor.palette.tooltipOccupiedByComposition = "Този вагон е зает от композиция {trainNumber}"
```

Mirror in `en.json`.

### 3.6 Tests

- `CloneWagonTypeDialog.test.tsx` — render, default series name, submit calls API with full DTO, error mapping, retrofit-overrides submit, "open in layout editor" navigation.
- `WagonPalette.test.tsx` — extend to verify the new "occupied" disabled state with tooltip.
- `CompositionEditorPage.test.tsx` — palette receives `compositionKind` AND `availability` and respects both.

---

## 4. E2E (Playwright)

- `e2e/tests/wagons/clone-wagon-type.spec.ts` — happy-path clone flow ending with a redirect to the layout editor; verify the new wagon type is queryable via `GET /api/wagon-types`.
- `e2e/tests/compositions/palette-availability.spec.ts` — seed two compositions on the same date, assign WagonType X to composition A, open editor for composition B, assert WagonType X card is disabled with the localized tooltip; revert the assignment, assert it re-enables on refetch.

---

## 5. Open issues / follow-ups

1. **Reporting "колко вагона от серия 21-43" still uses `WHERE SeriesName LIKE '21-43%'`** — acceptable for MVP. Move to `ParentWagonTypeId` join when a reporting page is built.
2. **InventoryNumber uniqueness in SQL** — deferred until legacy series are backfilled.
3. **Geographic availability (Option D)** — not in scope. When a production incident shows time-non-overlapping but geographically impossible reuses (cf. `wagon-inventory-spec.md §0.5.1`), revisit with full Trip start/end station data.
4. **Decommissioning UX** — clone metadata fields are settable but there is no admin flow to retire a physical instance. Cover in a separate PR if needed.
