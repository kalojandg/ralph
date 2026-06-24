# Spec — Справка „Заетост на вагон“ (Wagon Occupancy Matrix Report) — SYS-OPS-COMP-04

> Референтен одит: `../wagon-occupancy-report-audit.md`. Този spec е източникът, който Ralph чете в RECON стъпките.

## 1. Резюме / решение

- **Тип:** Каталог справка в `reporting-service`, нов `ReportCode = SYS-OPS-COMP-04`.
- **Изход:** ЕДИН xlsx за цялата композиция, **по 1 sheet на вагон**. Цъкане на трите точки (kebab) на който и да е вагон → същият файл (маха объркването „цъкам на вагон 1, за да видя вагон 2“).
- **На всеки sheet:** хедър (серия на вагона, влак №, дата), ред „Заетост на вагона: X %“, после **матрица**: колони = спирки/сегменти по маршрута, редове = № на място, индикатор в клетката (2 различни: „зает“ vs „блокиран“).
- **Параметри:** `trainNumber` (string) + `date` (single travel date, ISO `YYYY-MM-DD`). Композицията е single-day модел; `trainNumber` = `Composition.DisplayName` (виж памет reference_composition_displayname).
- **Тригери (и двата викат един и същ export endpoint):**
  1. Reports секция (Операции) → стандартен param form → export.
  2. Композиция → kebab на вагон → „Справка за натовареност“ → подава влак№+дата на текущата композиция.
- **Permission:** `REPORTS` (както всички каталог справки). Kebab item се скрива/disable-ва, ако потребителят няма `REPORTS`.

## 2. Матрица — точна семантика (по старата система)

- **Колони** = всички спирки по маршрута, подредени по `stopSequence` (напр. СОФИЯ, ПОДУЯНЕ, … БУРГАС).
- **Ред × колона:** клетката под спирка `K` отразява състоянието на мястото за **сегмента `K → K+1`**. Последната спирка (крайна) няма следващ сегмент → колоната ѝ е празна (в стария файл БУРГАС е празен за всички места).
- **Редове** = № на място (`SeatDefinitions.SeatNumber`), само физически присъстващи (`IsPhysicallyPresent = 1`).
- **Индикатори в клетка (default, потвърди с PO):**
  - „зает“ = статус `SOLD` / `LOCKED` / `CHECKED_IN` → символ `✓`
  - „блокиран“ = статус `BLOCKED` → символ `Б` (различен от заетото)
  - `AVAILABLE` → празна клетка
- **Заетост % (на вагон, в хедъра):** брой места с поне един сегмент в (зает ∨ блокиран) / брой физически места × 100, закръглено до 2 знака (стара система показва „11.76 %“).

## 3. Източници на данни (от одита)

- **Серия / влак № / дата / капацитет:** `Admin-App/src/api/compositions/compositions.types.ts` (`Wagon.placardNumber`, `Train.number`, `Composition.startDate`, `Wagon.capacity`).
- **Спирки (колони):** `trainSchedulesApi.getTripStops(tripId)` → `TripStopTime[]` (`stopName`, `stopSequence`, `stopCode`=UIC).
- **Заетост per място/сегмент (клетки):** RailRun `SeatAvailability` (`CompCarriageId`, `SeatDefId`, `TravelDate`, `SegmentStartUic`, `SegmentEndUic`, `Status`) ⨝ `SeatDefinitions` (`SeatNumber`, `IsPhysicallyPresent`) ⨝ `CompositionCarriages` (`SequenceNumber`, `PlacardNumber`, `WagonTypeId`) ⨝ `Compositions` (`DisplayName`, `TripId`, `StartDate`). FE еквивалент за справка: `seatsApi.getSeatStates(wagonId, {fromStationUic,toStationUic})`.

## 4. Бекенд план (OSDM-Src)

> Съществуващите партиали `railrun.wagon-occupancy` / `railrun.seat-map-by-segment` носят само **агрегирани броячи** — НЕ per-seat детайл (изрично записано в SQL описанията на COMP-01/02/03 като „follow-up wave“). Затова е нужен **нов per-seat партиал**.

1. **Нов RailRun партиал `railrun.seat-map-detail`:**
   - `RailRunService.Application/Features/Reporting/SeatMapDetailRowDto.cs` (нов) — поля: `trainNumber, travelDate, wagonSequence, placardNumber, wagonType, seatNumber, accommodationType, isPhysicallyPresent, segmentIndex, segmentStartUic, segmentEndUic, segmentStartName, status`.
   - `IRailRunReportingRepository.GetSeatMapDetailAsync(displayName, travelDate)` + имплементация (SQL join по §3; подреждане на сегменти по trip `stopSequence`, за да съвпадат с колоните).
   - `GetSeatMapDetailQuery.cs` + handler; регистрация в `RailRunReportingPartialGateway.cs`.
   - Mirror: `GetSeatMapBySegmentQuery.cs`, `SeatMapBySegmentRowDto.cs`, `RailRunReportingPartialGatewayTests.cs`.
2. **Reporting handler SYS-OPS-COMP-04:**
   - `ReportingService.Infrastructure/Services/SysOpsComp04WagonOccupancyMatrixLocalRunner.cs` (нов, `ILocalReportRunner`, `OwningServiceKey = RailRunService`, `ProviderCode = SYS_OPS_WAGON_OCCUPANCY_MATRIX`, `UpstreamPartialId = railrun.seat-map-detail`). Single-source pass-through (mirror `SysOpsComp02SeatMapOccupancyBySegmentLocalRunner.cs`).
   - DI: `ReportingService.Infrastructure/Extensions/ServiceCollectionExtensions.cs`.
3. **SQL seed:** ред в `SQLProjects/ReportingServiceSQL/dbo/PostDeployment/Data/003_ReportCatalog_SysAcc.sql`:
   `SYS-OPS-COMP-04`, ProviderCode `SYS_OPS_WAGON_OCCUPANCY_MATRIX`, Name `Справка за натовареност (схема по места)`, ReportGroup `Операции`, Permission `REPORTS`, ProviderType `1` (LOCAL), OwningServiceKey `RailRunService`, ParameterSchemaJson:
   `{"type":"object","required":["trainNumber","date"],"properties":{"trainNumber":{"type":"string"},"date":{"type":"string","format":"date"}}}`, IsActive `1`.
4. **Custom matrix xlsx builder + export routing:**
   - `ReportingService.Application/Reporting/WagonOccupancyMatrixXlsxBuilder.cs` (нов, ClosedXML) — групира редовете по вагон → 1 sheet/вагон (име `Вагон {sequence}`); пише хедъра, „Заетост: X %“, и матрицата (колони=сегменти/спирки, редове=места, клетки=индикатор). НЕ ползва `GenericTabularXlsxBuilder`.
   - Routing: `ExportReportByCodeCommand.cs` да насочи `SYS-OPS-COMP-04` към новия builder. **Прецедент: `Mkt03TicketsByTypeXlsxBuilder.cs`** (MKT-03 вече е custom builder в същия pipeline) — следвай неговото вграждане.

## 5. Фронтенд план (Admin-App)

1. **Reports секция:** каталогът авто-листва COMP-04 под „Операции“ (`reportSections.ts` мапва `Операции → operational`). Param form (`ReportParameterForm.tsx`) рендира `trainNumber` + `date`. Export през `reportingApi.downloadReportExport('SYS-OPS-COMP-04', { trainNumber, date }, 'xlsx')`.
2. **Композиция kebab:**
   - `compositions/components/WagonCanvas.tsx` — нов `<MenuItem>` „Справка за натовареност“ след Delete (ред ~449); нов prop `onExportOccupancyReport?` в `WagonCanvasProps`; handler по образец на `handleEdit/handleDelete` (ред ~199-216).
   - `compositions/pages/CompositionEditorPage.tsx` — подава callback → нов hook `useExportWagonOccupancyReport(trainNumber, date)` (в `compositions/hooks/`) който вика `downloadReportExport` + `reports/utils/downloadBlob.ts`. Pattern: `chief-cashier/hooks/useExportDailyReport.ts`.
   - Disable/hide ако няма `trainNumber`/`tripId` или липсва `REPORTS` permission.
   - i18n: `compositions.editor.properties.occupancyReport` в `src/locales/bg.json` И `en.json`.

## 6. Тестови данни / e2e

- Памет `project_railrun_db_state`: локалната DB няма продадени места → справката ще е празна. Нужен **dev seed**: композиция с `trainNumber` + дата + няколко `SOLD` и `BLOCKED` реда в `SeatAvailability` по различни сегменти.
- E2E (Playwright, real FE→BE→DB, per feedback_tdd_includes_e2e): от композиция → kebab на вагон → „Справка за натовареност“ → asserт сваляне на `.xlsx`; + Reports секция → run COMP-04. Изисква вдигнати `reporting-service` и `rail-run-service` с ребилднати образи.

## 7. Отворени въпроси за PO

- Точни символи/цветове за „зает“ vs „блокиран“ (default `✓` / `Б`).
- Заетост % само на вагон (default) или и ред per колона/сегмент?
- Включваме ли не-физически места като скрити редове?
- Sheet ред/именуване — по `SequenceNumber`; име `Вагон {seq}` или серия?
