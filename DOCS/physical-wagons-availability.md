# Physical wagons — geographic + temporal availability (Task #182)

> **Status:** Planned (2026-05-22).
> **Builds on:** [physical-wagons-fix.md](physical-wagons-fix.md) Task #174 (single-composition uniqueness) + Task #162 (date-only cross-composition check).
> **Scope reference:** [wagon-inventory-spec.md](../../wagon-inventory-spec.md) §0.5.3 approach γ ("Geographic chain"), §0.5.5 (algorithm sketch).

---

## 0. Защо

Текущата `GetAvailableWagonTypesForCompositionQuery` блокира wagonType-а само по `StartDate` припокриване. Прекалено грубо:

- Блокира wagon-а в композиция А (Пловдив → София 09:00-12:00) от **всяка** друга композиция на същия ден, дори и тя да е след 12:00 със смислен chain (примерно София → Варна 14:00-19:00 — възможен continue).
- Не блокира **геометрично невъзможни** scenario-та като композиция Б (Бургас → Пловдив 14:00-17:00) ако А завършва в София в 12:00 — теmporally A → Б е OK, но физически вагонът не може да телепортира от София до Бургас.

User изискване (потвърдено 2026-05-22):
> разписание... не искаме да блокираме потенциално „телепортация" — да тръгне от Бургас в 14:00, при положение че в 12:00 е пристигнал в София... все още няма да е с данните в реално време.

→ Използваме **schedule-based** chain check (НЕ GPS / real-time).

---

## 1. Алгоритъм (за всеки candidate wagonType при composition X)

Дадено:
- Target composition `X` на дата `D`, с TripId `Tx`, стартова станция `S_x_start` (от първия стоп), крайна станция `S_x_end` (от последния стоп), времена `t_x_start` / `t_x_end`.
- Buffer `B` = 30 мин (configurable константа).
- За wagonType `W`, всички други ACTIVE композиции на дата `D` съдържащи `W` — наречени „peer compositions" `P1, P2, ..., Pn`.

Стъпки:
1. Сортирай {X, P1..Pn} хронологично по `t_start`.
2. За всяка съседна двойка `(prev, curr)` в подредицата:
   - Ако `prev.t_end > curr.t_start` → **TEMPORAL_OVERLAP** (същия класически интервал-овлап).
   - Ако `prev.t_end + B > curr.t_start` → **BUFFER_VIOLATION** (време за манипулация).
   - Ако `prev.station_end != curr.station_start` → **GEOGRAPHIC_MISMATCH** (вагонът не е там).
3. Ако някоя проверка falsey → wagonType `W` е UNAVAILABLE за `X` (даже когато `X` е enter-ващ елемент). Запази причината + конфликтния peer (id, trainNumber, времена, станции) за tooltip.

Edge cases:
- Composition с `TripId == null` (manual draft без трип): не може да участва в chain check → consider it ALWAYS available (no constraints). Може и да е „always unavailable" — TBD; **препоръка: always available**, потребителят е свободен ръчно да реши.
- Trip съществува но няма stops в GtfsStopTimes: fallback — третирай trip-а като да заема целия ден `00:00-24:00`. (Conservative — блокира всичко на тая дата за тоя wagon.)
- Сглобяване на trips от различни feed-versions: вземаме само active feed-version (text query `WHERE FeedVersion = current`).

---

## 2. Backend

### 2.1 NomenclatureService — без промени

`GetTripStopsResponse` (в `SharedSrc/Common/DTOs/Gtfs`) вече съдържа `TripStopDto { StopCode, StopName, ArrivalSeconds, DepartureSeconds, StopSequence }`. Reusing existing RPC.

### 2.2 RailRunService — нов `ITripScheduleService`

`RailRunService.Infrastructure/Services/TripScheduleService.cs`:

```csharp
public interface ITripScheduleService
{
    Task<TripScheduleWindow?> GetWindowAsync(long tripId, CancellationToken ct = default);
}

public record TripScheduleWindow(
    long TripId,
    string StartStationUic,
    string EndStationUic,
    int StartSeconds,
    int EndSeconds);
```

Имплементация (огледало на `StopPlaceService.cs`):
- `IRequestClient<GetTripStopsRequest>` за MassTransit RPC.
- `IMemoryCache` с key `"TripSchedule:{tripId}"` + 1-час TTL.
- Логика:
  1. Issue `GetTripStopsRequest(tripId)`.
  2. Ако response.Success && response.Stops.Count >= 2 → derive window:
     - Sorted by StopSequence.
     - StartSeconds = first.DepartureSeconds ?? first.ArrivalSeconds ?? 0
     - EndSeconds = last.ArrivalSeconds ?? last.DepartureSeconds ?? 86400
     - StartStation = first.StopCode, EndStation = last.StopCode
  3. Cache + return.

### 2.3 Update `GetAvailableWagonTypesForCompositionQueryHandler`

Текущо: filter по `StartDate == targetStartDate AND Status == 'ACTIVE' AND Id != currentCompositionId`.

Ново:
1. Get target composition. Ако `TripId == null` → return all available (no chain check).
2. `var targetWindow = await _tripScheduleService.GetWindowAsync(target.TripId);`
3. За всеки candidate peer composition със same date + ACTIVE:
   - Ако `peer.TripId == null` → skip (manual draft не участва).
   - `var peerWindow = await _tripScheduleService.GetWindowAsync(peer.TripId);`
   - Run chain check (target ↔ peer):
     - Случай а: peer ends преди target starts. Проверка: `peer.EndSeconds + BufferSeconds <= target.StartSeconds AND peer.EndStation == target.StartStation`.
     - Случай б: target ends преди peer starts. Огледално.
     - Случай в: overlap. Винаги unavailable.
   - Ако който и да е check falsey → wagonType-овете в peer.compositionCarriages са UNAVAILABLE за target. Save conflict details.
4. Project to `AvailableWagonTypeDto`, добавяйки `ConflictReason` enum + `ConflictPeerComposition` info (id, trainNumber, начален стоп, краен стоп, часове).

Constants:
```csharp
public static class WagonAvailabilityConstants
{
    public const int BufferMinutes = 30;
    public const int BufferSeconds = BufferMinutes * 60;
}
```

### 2.4 Update DTO

`AvailableWagonTypeDto` (`RailRunService.Application/DTOs/Nomenclatures/`):
- Запази `WagonTypeId`, `IsAvailable`.
- Замени `OccupiedByCompositionId`/`OccupiedByTrainNumber` (от Task #162) с richer `Conflict` object:

```csharp
public class AvailableWagonTypeDto
{
    public long WagonTypeId { get; set; }
    public bool IsAvailable { get; set; }
    public WagonAvailabilityConflictDto? Conflict { get; set; }
}

public class WagonAvailabilityConflictDto
{
    public long PeerCompositionId { get; set; }
    public string PeerTrainNumber { get; set; } = "";
    public string Reason { get; set; } = "";  // TEMPORAL_OVERLAP | BUFFER_VIOLATION | GEOGRAPHIC_MISMATCH
    public string PeerStartStation { get; set; } = "";
    public string PeerEndStation { get; set; } = "";
    public string PeerStartTime { get; set; } = "";  // HH:mm
    public string PeerEndTime { get; set; } = "";    // HH:mm
}
```

### 2.5 Tests

`GetAvailableWagonTypesForCompositionQueryHandlerTests`:
- T1 — Target trip без TripId → всичко available.
- T2 — Един peer на same date с НЕ-припокриващ time + same end-start station + buffer OK → wagonType-а на peer-а IS available (chain OK).
- T3 — Един peer на same date с НЕ-припокриващ time + НЕ-mismatched станция → unavailable, `Reason="GEOGRAPHIC_MISMATCH"`.
- T4 — Един peer на same date с временен overlap → unavailable, `Reason="TEMPORAL_OVERLAP"`.
- T5 — Един peer на same date с прав chain station, но buffer < 30min → unavailable, `Reason="BUFFER_VIOLATION"`.
- T6 — Peer с `TripId == null` → ignored (always considered no-conflict).
- T7 — Peer trip with missing stops → conservative: blocks (treat as full-day occupation).
- T8 — Different date → peer is ignored.

---

## 3. Frontend

### 3.1 `wagons.types.ts` — extended DTO type

```ts
export interface AvailableWagonType {
  wagonTypeId: number;
  isAvailable: boolean;
  conflict?: WagonAvailabilityConflict;
}

export interface WagonAvailabilityConflict {
  peerCompositionId: number;
  peerTrainNumber: string;
  reason: 'TEMPORAL_OVERLAP' | 'BUFFER_VIOLATION' | 'GEOGRAPHIC_MISMATCH';
  peerStartStation: string;
  peerEndStation: string;
  peerStartTime: string;  // HH:mm
  peerEndTime: string;
}
```

### 3.2 `WagonPalette` — context-aware tooltip

Сега tooltip-ът показва само composition-а. Разшири за reason-specific текст:

- `TEMPORAL_OVERLAP` → „Вагонът е в композиция {peerTrainNumber} ({peerStartTime}-{peerEndTime}, {peerStartStation}→{peerEndStation})."
- `BUFFER_VIOLATION` → „Вагонът пристига в {peerEndStation} в {peerEndTime}; няма достатъчно време преди новия trip ({BufferMinutes} мин минимум за prikachvane/откачване)."
- `GEOGRAPHIC_MISMATCH` → „Вагонът е в {peerEndStation} в {peerEndTime}, не може да тръгне от {targetStartStation} в {targetStartTime}."

### 3.3 Tests update

`WagonPalette.test.tsx` + `CompositionEditorPage.test.tsx`: добави cases за всеки `reason` → tooltip съдържа правилния substring.

---

## 4. Извън scope (deferred)

- **Deadhead movements** — explicit empty-runs „from A to B" between trips. Spec §0.5.5 ги споменава, но Phase 1 ги няма. Conservative: ако chain е broken — забрана. Бъдеща feature.
- **Real-time GPS** — изрично OUT of scope per user feedback.
- **Configurable buffer per train/station** — засега hardcoded 30 мин.
- **Multi-wagon shared composition group** — когато два влака се движат заедно (двойна композиция) → out of scope.

---

## 5. Verification checklist (за Ralph DONE phase)

- [ ] Unit tests (8 cases) зелени.
- [ ] Integration test през Swagger / curl: GET `/api/wagon-types/available?compositionId=N` връща правилно populated `conflict` поле за тестов scenario.
- [ ] FE tests за tooltip-а зелени.
- [ ] Manual e2e:
  1. Създай wagon W в /wagons.
  2. Създай комп A: Пловдив-София 09-12. Активирай. Добави W.
  3. Създай комп B: София-Варна 14-19, същата дата. Отвори. Уверете се W е available (chain OK).
  4. Създай комп C: Бургас-Пловдив 14-17, същата дата. Отвори. W трябва да е disabled с tooltip „вагонът е в София 12:00, не може да е в Бургас 14:00".
  5. Създай комп D: Пловдив-Бургас 12:15-16 (с по-малко от 30мин buffer след A). Отвори. W трябва да е disabled с BUFFER_VIOLATION reason.
