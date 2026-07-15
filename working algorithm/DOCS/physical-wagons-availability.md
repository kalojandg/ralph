# Physical wagons — segment-aware temporal availability (Task #182)

> **Status:** Planned (2026-05-22, revised v3).
> **Builds on:** [physical-wagons-fix.md](physical-wagons-fix.md) Task #174 (single-composition uniqueness) + Task #162 (date-only cross-composition check).
> **Scope reference:** [wagon-inventory-spec.md](../../wagon-inventory-spec.md) §0.5.3 approach β ("Temporal-only"), refined с **per-carriage segment** awareness.

---

## 0. Защо

Текущата `GetAvailableWagonTypesForCompositionQuery` блокира wagonType-а само по `StartDate` припокриване — too coarse. Нужно: блокирай само ако **wagon-овият segment** на peer композицията се припокрива темпорално с target trip-а.

**Ключово уточнение:** wagon-ът може да е в композиция от 09:00-13:00, но прикачен само на segment Burgas→Sofia, който завършва в 10:00. Тогава реално вагонът е „зает" 09:00-10:00, а не 09:00-13:00.

User изискване (потвърдено 2026-05-22):
> "той може да е в композиция от 9 до 13, но да е бил в подсегмент, който е откачен в 10. тогава той се е вижил от 9 до 10, а не от 9 до 13."

Tooltip изискване:
> „вагонът е в композиция БВ-2297 Бургас-Плевен от 9 до 13" — показваме trip name + segment маршрут + сегмент-времена.

→ Schedule-based + per-carriage segment derivation. **БЕЗ** geographic check между поредни trip-ове.

---

## 1. Алгоритъм

Дадено:
- Target composition `X` на дата `D`, TripId `Tx`. Target time window: `[t_x_start, t_x_end]` = (`firstStop.Departure`, `lastStop.Arrival`) от trip-а.
- За wagonType `W`, всички други ACTIVE композиции на дата `D` съдържащи carriage с `WagonTypeId == W` — naricame ги peer carriages `(P_i, C_ij)` (composition P_i, carriage C_ij).

За всяка peer carriage `C_ij`:

1. Ако `P_i.TripId == null` → skip.
2. Fetch P_i's trip stops (с times).
3. **Compute carriage segment window:**
   - Намери stop с `StopCode == C_ij.StartStationUic` → `t_seg_start = stop.DepartureSeconds` (когато carriage тръгва).
   - Намери stop с `StopCode == C_ij.EndStationUic` → `t_seg_end = stop.ArrivalSeconds` (когато carriage пристига и се откача).
   - Fallback: ако някоя станция липсва в trip stops → използвай trip's full window (conservative).
4. **Interval overlap check** target-vs-segment:
   - `t_x_start < t_seg_end AND t_seg_start < t_x_end` → TEMPORAL_OVERLAP.
5. При overlap → wagonType W е UNAVAILABLE за X. Запази conflict:
   - PeerCompositionId = P_i.Id
   - PeerTrainNumber = P_i.TrainNumber
   - SegmentStartStation = C_ij.StartStationUic (+ resolved name)
   - SegmentEndStation = C_ij.EndStationUic (+ resolved name)
   - SegmentStartTime = HH:mm от t_seg_start
   - SegmentEndTime = HH:mm от t_seg_end

Граничен случай: touching boundary (e.g. target.start == segment.end) → НЕ е overlap → разрешено.

Edge cases:
- Target composition с `TripId == null` → all available.
- Peer carriage's stations не съвпадат с trip stops (data inconsistency) → conservative fallback: full trip window.
- Multiple carriages на същия wagonType в SAME peer — взимаме НАЙ-РАННОТО припокриване (първото намерено). Theoretically не би трябвало да се случва (Task #174 reject duplicate wagonTypeId per composition).

---

## 2. Backend

### 2.1 NomenclatureService — без промени

`GetTripStopsResponse.TripStopDto` вече има `StopCode`, `StopName`, `ArrivalSeconds`, `DepartureSeconds`, `StopSequence`. Достатъчно.

### 2.2 RailRunService — нов `ITripScheduleService`

`RailRunService.Application/Interfaces/ITripScheduleService.cs`:

```csharp
public interface ITripScheduleService
{
    /// <summary>Returns ordered stops with times for the given trip, or null if missing/unreachable.</summary>
    Task<IReadOnlyList<TripStopInfo>?> GetStopsAsync(long tripId, CancellationToken ct = default);
}

public record TripStopInfo(
    string StopCode,
    string StopName,
    int? ArrivalSeconds,
    int? DepartureSeconds,
    int StopSequence);
```

Помощни extensions:
```csharp
public static class TripStopExtensions
{
    public static (int Start, int End)? GetFullTripWindow(this IReadOnlyList<TripStopInfo> stops)
    {
        if (stops.Count < 2) return null;
        var sorted = stops.OrderBy(s => s.StopSequence).ToList();
        var start = sorted.First().DepartureSeconds ?? sorted.First().ArrivalSeconds ?? 0;
        var end = sorted.Last().ArrivalSeconds ?? sorted.Last().DepartureSeconds ?? 86400;
        return (start, end);
    }

    public static (int Start, int End, string StartName, string EndName)? GetSegmentWindow(
        this IReadOnlyList<TripStopInfo> stops,
        string startStationUic,
        string endStationUic)
    {
        var startStop = stops.FirstOrDefault(s => s.StopCode == startStationUic);
        var endStop = stops.FirstOrDefault(s => s.StopCode == endStationUic);
        if (startStop is null || endStop is null) return null;
        var start = startStop.DepartureSeconds ?? startStop.ArrivalSeconds ?? 0;
        var end = endStop.ArrivalSeconds ?? endStop.DepartureSeconds ?? 86400;
        return (start, end, startStop.StopName, endStop.StopName);
    }
}
```

Имплементация `TripScheduleService.cs` (огледало на `StopPlaceService.cs`):
- `IRequestClient<GetTripStopsRequest>` за MassTransit RPC.
- `IMemoryCache` key `"TripStops:{tripId}"` + 1-час TTL.
- `GetStopsAsync` връща cached IReadOnlyList<TripStopInfo> или null.

### 2.3 Update `GetAvailableWagonTypesForCompositionQueryHandler`

```csharp
// Pseudo
var target = await _compositionRepo.GetByIdAsync(targetId);
if (target.TripId is null) return AllAvailable(allTypes);

var targetStops = await _tripScheduleService.GetStopsAsync(target.TripId.Value);
var targetWindow = targetStops?.GetFullTripWindow();
if (targetWindow is null) return AllAvailable(allTypes);  // conservative

var peers = await _compositionRepo.GetActiveOnDateExceptAsync(target.StartDate, target.Id);
var conflicts = new Dictionary<long, WagonAvailabilityConflictDto>();

foreach (var peer in peers)
{
    if (peer.TripId is null) continue;
    var peerStops = await _tripScheduleService.GetStopsAsync(peer.TripId.Value);
    if (peerStops is null) continue;

    foreach (var carriage in peer.CompositionCarriages.Where(c => c.IsActive))
    {
        // Per-carriage segment window (fallback to full trip if segment stations missing)
        var seg = peerStops.GetSegmentWindow(carriage.StartStationUic, carriage.EndStationUic)
                  ?? FallbackToFullWindow(peerStops);
        if (seg is null) continue;

        // Interval overlap target ∩ segment
        if (targetWindow.Value.Start < seg.Value.End && seg.Value.Start < targetWindow.Value.End)
        {
            conflicts.TryAdd(carriage.WagonTypeId, new WagonAvailabilityConflictDto
            {
                PeerCompositionId = peer.Id,
                PeerTrainNumber = peer.TrainNumber,
                SegmentStartStationUic = carriage.StartStationUic,
                SegmentStartStationName = seg.Value.StartName,
                SegmentEndStationUic = carriage.EndStationUic,
                SegmentEndStationName = seg.Value.EndName,
                SegmentStartTime = SecondsToHHmm(seg.Value.Start),
                SegmentEndTime = SecondsToHHmm(seg.Value.End),
            });
        }
    }
}

return allTypes.Select(wt => new AvailableWagonTypeDto
{
    WagonTypeId = wt.Id,
    IsAvailable = !conflicts.ContainsKey(wt.Id),
    Conflict = conflicts.GetValueOrDefault(wt.Id),
}).ToList();
```

### 2.4 DTO

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
    public string SegmentStartStationUic { get; set; } = "";
    public string SegmentStartStationName { get; set; } = "";
    public string SegmentEndStationUic { get; set; } = "";
    public string SegmentEndStationName { get; set; } = "";
    public string SegmentStartTime { get; set; } = "";  // HH:mm
    public string SegmentEndTime { get; set; } = "";
}
```

### 2.5 Tests

`GetAvailableWagonTypesForCompositionQueryHandlerTests` (10 cases):
- **T1** — Target trip без TripId → всички available.
- **T2** — Един peer на same date, segment-times НЕ припокриват target (segment 09-10, target 14-17) → available.
- **T3** — Един peer на same date, segment overlap (segment 09-10, target 09:30-12) → unavailable + conflict.
- **T4** — Peer composition 09-13, peer carriage segment 09-10, target 11-12 → available (carriage детачнат преди target).
- **T5** — Peer composition 09-13, peer carriage segment 09-10, target 09:30-10:30 → unavailable.
- **T6** — Touching boundary (segment ends 10:00, target starts 10:00) → available.
- **T7** — Peer carriage's stations не съвпадат с trip stops (corrupt data) → fallback to full trip window → overlap → unavailable.
- **T8** — Peer composition с TripId == null → ignored.
- **T9** — Peer на different date → ignored.
- **T10** — Tooltip data — conflict dto има SegmentStartStationName + SegmentEndStationName resolved correctly.

`TripScheduleServiceTests`:
- Cache hit → no RPC.
- RPC success → returns sorted stops list.
- RPC failure → null.

`TripStopExtensionsTests`:
- `GetFullTripWindow` — 3 stops sorted by sequence → correct (start.Dep, last.Arr).
- `GetSegmentWindow` — стартова + крайна uic → correct windows + names.
- `GetSegmentWindow` — missing start/end uic → null.

---

## 3. Frontend

### 3.1 `wagons.types.ts`

```ts
export interface AvailableWagonType {
  wagonTypeId: number;
  isAvailable: boolean;
  conflict?: WagonAvailabilityConflict;
}

export interface WagonAvailabilityConflict {
  peerCompositionId: number;
  peerTrainNumber: string;
  segmentStartStationUic: string;
  segmentStartStationName: string;
  segmentEndStationUic: string;
  segmentEndStationName: string;
  segmentStartTime: string;  // HH:mm
  segmentEndTime: string;
}
```

### 3.2 `WagonPalette` — tooltip

i18n key `compositions.editor.palette.tooltipOccupiedByComposition`:
- BG: „Вагонът е в композиция {peerTrainNumber} ({segmentStartStationName}-{segmentEndStationName}, {segmentStartTime}-{segmentEndTime})."
- EN: „Wagon is in composition {peerTrainNumber} ({segmentStartStationName}-{segmentEndStationName}, {segmentStartTime}-{segmentEndTime})."

Пример рендериран text:
> „Вагонът е в композиция БВ-2297 (Бургас-Плевен, 09:00-13:00)."

или ако wagon-ът е само на segment:
> „Вагонът е в композиция БВ-2297 (Бургас-София, 09:00-10:00)."

### 3.3 Tests update

`WagonPalette.test.tsx`: assert tooltip съдържа train number + segment stations + HH:mm-HH:mm.

---

## 4. Извън scope (deferred)

- **Geographic chain validation** — out of scope (dispatcher справя repositioning).
- **Buffer between trips** — без enforcement. Boundary touching OK.
- **Real-time GPS** — out of scope.
- **Multi-wagon shared composition group** — out of scope.

---

## 5. Verification checklist

- [ ] Unit tests (10 + service + extensions) зелени.
- [ ] Integration: GET `/api/wagon-types/available?compositionId=N` връща Conflict с правилни segment fields.
- [ ] FE tests за tooltip-а зелени.
- [ ] Manual e2e:
  1. Създай wagon W в /wagons.
  2. Композиция А: trip Бургас-Плевен 09-13, същата дата. W прикачен на segment Бургас-София (carriage stations). Активирай.
  3. Композиция B: trip Пловдив-София 11:30-13:00, същата дата. Отвори. **W трябва да е AVAILABLE** (W's segment в A е 09-10, target B е 11:30-13 → no overlap).
  4. Композиция C: trip Бургас-София 09:30-10:30, същата дата. Отвори. **W трябва да е UNAVAILABLE** с tooltip „W е в композиция А (Бургас-София, 09:00-10:00)."
  5. Композиция D: trip от другия ден. Отвори. **W трябва да е AVAILABLE** (different date).
