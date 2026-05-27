# Feedback from Previous Iteration

<!-- This file will be auto-updated after each iteration -->

## Last Iteration Summary

**Iteration:** Tasks #184-#188 завършени (segment-aware checks + FE palette/drop guard + dialog). Плюс inline fix: availability READ peer filter изравнен със save-проверката (махнат Status==ACTIVE).
**Status:** ✅ Single-composition конфликтите работят и при drop, и при save, и за DRAFT композиции. Следва: clone-for-period да пропуска конфликтни дни. Виж #189.

---

## Feedback for Next Iteration

<!-- Ralph will read this before next iteration -->

**Continue with:** Task #189 — [BE+FE] Clone-for-period — skip whole day on wagon conflict

**🧬 ЕТАП 13: clone-for-period conflict skip (Task #189)**

### Критично за #189

- **Reuse, не нова логика:** инжектирай съществуващия `ICarriageConflictDetector` (от #184) в `CloneCompositionForPeriodCommandHandler`. НЕ пиши нов overlap алгоритъм.
- **Skip целия ден:** при конфликт на който и да е вагон за дадена дата — пропусни датата изцяло (Reason='WAGON_CONFLICT'), не създавай частична композиция, не показвай диалог per конфликт. Това е продуктовото решение на user-а.
- **Skip-and-report вече съществува:** `CloneCompositionForPeriod.cs` трупа `SkippedClonePeriodItem` (Reason='TARGET_OCCUPIED'). Конфликтът е просто нов Reason. Surfacing е POST-RUN (съществуващото summary), без pre-flight dry-run.
- **Fail-closed:** `WagonSegmentConflictUnknown` от детектора → също skip на тази дата, не abort на целия период.
- **TripId null** → пропусни проверката, клонирай нормално (не блокирай trip-less композиции).

Пълен контекст: `ralph/activity.md` entry "[2026-05-26] - Queued Task #189". Regression: TARGET_OCCUPIED skip и happy-path clone тестовете остават зелени.

### ⚠️ Преди да тестваш ръчно #189 (или каквото и да е свързано с availability)

`rail-run-service` image трябва да е rebuild-нат след inline fix-а от 2026-05-27 (Status филтър махнат от availability READ). Ако drop guard-ът / clone-ът не виждат DRAFT peer-и — контейнерът е стар: `docker compose build rail-run-service && docker compose up -d --force-recreate rail-run-service`.

---

## ⏪ Историчен контекст: ЕТАП 12 финал — drop-time guard (Task #188, passes:true)

**Continue with:** Task #188 — [FE] Drop-time availability guard (QoL, timing-only — НЕ променяй check логиката)

**🚦 ЕТАП 12 (финал): drop-time guard (Task #188)**

### Критично за #188

Това е **timing/UX-only** промяна. Проверките вече са правилни (Tasks #182/#184/#185/#187). **НЕ пипай:** BE `CarriageConflictDetector`, `/wagon-types/available` query, `draftSegmentFit` overlap математиката. Само:
1. Свежест: `refetchOnMount:'always'` на availability query + invalidate `['wagon-types','available']` след save.
2. Нов тънък `WagonConflictDialog` (presentational).
3. Drop handler-ите четат СЪЩЕСТВУВАЩИТЕ `availabilityMap` + in-draft overlap helper; при конфликт → отваря диалог + abort на дропа (без мутация на draft-а).
4. Замества drop-time снакбара от #185 с диалога (без двоен feedback). Save-path снакбарите остават.

Пълен контекст: `ralph/activity.md` entry "[2026-05-26] - Queued Task #188". Regression guard: happy-path drop тестовете трябва да останат зелени.

---

## ⏪ Историчен контекст: SaveCompositionWagons parity (Task #187, passes:true)

**Continue with:** Task #187 — [BE] SaveCompositionWagons segment-aware conflict validation (parity with #184)

**🚂 ЕТАП 12 (продължение): SaveCompositionWagons parity (Task #187)**

### Защо още един таск след #184?

Task #184 поправи `AddCarriage.cs` (per-carriage POST `/api/compositions/{id}/wagons`), но FE "ЗАПАЗИ" бутонът извиква **`POST /api/compositions/{id}/save-wagons`** — batch endpoint, който минава през `SaveCompositionWagons.cs`. Този handler има СВОЯ собствена композиция-широка `HashSet<WagonTypeId>` проверка (lines 142-158) и emit-ва legacy `WAGON_ALREADY_IN_COMPOSITION` без segment context, без peer-composition check, и без within-batch detection (два NewCarriages в едно request с overlap минават).

Repro потвърден на 2026-05-26 от user-а: композиции 30290 (БВ 3624) + 30291 (ПВ 30157) на 23.05.2026 със същия WagonTypeId=2 в overlapping Карнобат-departing segments — save минава мълчешком.

### 📜 Задължително преди Task #187

1. **`C:/Users/kaloyan.georgiev/Projects/ralph/activity.md`** entry "[2026-05-26] - Queued Task #187" — пълен контекст за дупката и какво трябва.
2. **Tasks #182 + #184** в `tasks.json` (passes:true) — реюзваш `ICarriageConflictDetector` без нови услуги или DI промени. Сервисът е вече регистриран.
3. **`C:/Users/kaloyan.georgiev/Projects/OSDM-Src/DotNetServices/RailRunService/RailRunService.Application/Features/Compositions/Commands/SaveCompositionWagons.cs`** — handler-ът, в който променяш. Виж lines 99-205 (stop validation + delete + add + update + reorder секции).
4. **`C:/Users/kaloyan.georgiev/Projects/OSDM-Src/DotNetServices/RailRunService/RailRunService.Application/Services/CarriageConflictDetector.cs`** — service-ът, който инжектираш. Не пипай негова логика — само го извикваш.

### 🎯 Архитектурни правила за #187

- **Projected composition pattern.** Преди checks: клонирай `composition.CompositionCarriages` в memory, премахни `DeletedCarriageIds`, приложи `UpdatedCarriages` field updates. Това е "post-save state" на което се правят всички conflict checks. След като NewCarriage мине, append-ваш in-memory stub в projection-а, за да хване S5 (within-batch overlap).
- **excludeCarriageId за updates.** При проверка на `UpdatedCarriages`, подай `excludeCarriageId = update.CompCarriageId` — иначе carriage-ът ще конфликтва със собствения си pre-update сегмент.
- **Legacy fallback за TripId == null.** Запази съществуващия HashSet path само в този клон — преserve-ва Task #176 test surface.
- **Reuse, don't duplicate.** Целта е да routnem всичко през съществуващия `CarriageConflictDetector`. Не дублирай overlap логика inline в handler-а.

### 🚨 Червени линии за #187

- ❌ Не пипай `CarriageConflictDetector.cs` (тестван и заключен от #184).
- ❌ Не въвеждай нова public DTO / endpoint — само вътрешна handler промяна.
- ❌ Не пипай SQL.
- ✅ Pessimistic lock (`LockForUpdateAsync`) остава — checks се правят INSIDE the transaction.

### 📋 Подетапи (само #187 в този sub-stage)

- **12D: BE batch parity** (#187) — `SaveCompositionWagonsCommandHandler` injection + projected composition + per-NewCarriage detector loop + UpdatedCarriages mirror + tests update.

### 🛑 Не правиш #187 ако

- #184 не е passes:true → върни се и довърши него (споделяш `CarriageConflictDetector` оттам).

---

## ⏪ Историчен контекст: ЕТАП 12 initial (Tasks #184-#186) — passes:true

**Continue with:** Task #184 — [BE] AddCarriage/UpdateCarriage — segment-aware conflict validation (defense-in-depth)

**🚂 НАЧАЛО НА ЕТАП 12: Wagon Availability — WRITE-path + FE drop validation (Tasks #184–#186)**

### 📜 Задължително преди първия таск от Етап 12

Прочети **в този ред**:

1. **`C:/Users/kaloyan.georgiev/Projects/ralph/activity.md`** — entry-то "[2026-05-26] - Queued Tasks #184–#186" обяснява _защо_ са нужни (reproducible scenario с композиции 30290 + 30291 на dev DB).
2. **`C:/Users/kaloyan.georgiev/Projects/ralph/tasks.json`** — Task #182 (passes: true) е contextual reference: реюзваш `ITripScheduleService` + `TripStopExtensions.GetSegmentWindow` (вече съществуват в `RailRunService.Application/Extensions/` + `Application/Interfaces/`). НЕ ги преписваш.
3. **`C:/Users/kaloyan.georgiev/Projects/railrun-backend-structure.md`** §"Code Patterns" — `IUnitOfWork`, pessimistic lock pattern в AddCarriage остава.
4. (за #185) **`C:/Users/kaloyan.georgiev/Projects/admin-app-frontend-structure.md`** + React Query / Zustand snackbar pattern.

### 🎯 Архитектурни правила за Етап 12 (кратко)

- **Single source of truth за overlap detection:** новият `CarriageConflictDetector` в `RailRunService.Application/Services/` ще се инжектира в `AddCarriage` И `UpdateCarriage`. НЕ дублирай логиката inline в handler-ите.
- **Same-comp без TripId → legacy blanket reject** като fail-safe (запазва текущия test surface). Това избягва regression на seed data без trip-ове.
- **Touching boundaries = no overlap.** Wagon-ът, който detach-ва в Карнобат и attach-ва в Карнобат за друга композиция, **трябва да мине**. Тест S5 в 184.1 точно това проверява.
- **Fail-closed при липсваща schedule информация** (`ITripScheduleService` връща null, или липсва start/end stop в trip stops) → `WagonSegmentConflictUnknown` + audit warning. По-добре да забраним save-а отколкото мълчаливо да приемем conflict.
- **FE НЕ blanket-disable-ва от draft.** Replace `usedWagonTypeIds: Set<number>` с `draftSegmentFit: Record<number, {canFitAnywhere: boolean}>`. Палитрата дисейблва само ако: traction-incompat ИЛИ cross-composition `availability.isAvailable===false` ИЛИ `canFitAnywhere===false` (т.е. нЯма свободен сегмент в композицията).
- **Snackbar copy:** локализирано чрез errorCode + errorArgs interpolation (виж Task 182.7 за съществуващия pattern с `peerTrainNumber`/`segmentStartStationName`/…). НЕ hard-code-вай низове.

### 🚨 Червени линии за Етап 12

- ❌ Не сменяй existing public DTO shape извън `AvailableWagonTypeDto` (тя вече беше пипана в #182).
- ❌ Не пипай SQL схемата — никакви migrations нужни.
- ❌ Не разширявай scope-а до WagonInventory / cross-day check / GPS — те са out-of-scope (потвърдено в #182 notes).
- ✅ Реюзваш `TripStopExtensions.GetSegmentWindow` 1:1 — ако намериш бъг в него, добавяй RED тест в съществуващия `TripStopExtensionsTests.cs` преди да fix-ваш.

### 📋 Подетапи на Етап 12

- **12A: BE WRITE-path** (#184) — `CarriageConflictDetector` + `AddCarriage`/`UpdateCarriage` rewire + error codes + resx. Изисква 9 RED теста S1-S9 преди GREEN.
- **12B: FE drop validation** (#185) — `WagonPalette` props refactor, `CompositionEditorPage` `draftSegmentFit` derivation, `SubRouteComposition.onDrop` overlap guard, `useCompositionPersistence` 409 handling, i18n.
- **12C: E2E** (#186) — single Playwright spec, 4 сценария, real GTFS trip pair 199/201 + 601. Cleanup в `afterAll`.

### 🛑 Не правиш Етап 12 ако

- Task #182 не е с `passes: true` → върни се и довърши него (READ path е предусловие).
- Локалният dev DB не съдържа GtfsTrips replica за TripId-та 199, 201, 601 → провери в `RailRunServiceDB.GtfsTrips` (виж раздел "snapshot 2026-05-26" в auto-memory). При липсваща replica → ескалирай, а не сейдвай ad hoc.

---

**Continue with:** Task #113 — [AUDIT] OSDM spec compliance — field-by-field review (no code)

**🎨 НАЧАЛО НА ЕТАП 6: Renderer Unification (Tasks #113-#124)**

### 📜 Задължително преди да започнеш първия таск от Етап 6

Прочети **в този ред**:

1. **`C:/Users/kaloyan.georgiev/Projects/wagon-renderer-unification-plan.md`** — архитектурният plan. Цялостен контекст за:
   - Какво е текущото състояние (dual source of truth, дивергенция на визуализацията).
   - Каква е целевата архитектура (shared wagonGrid library + 2 orchestrator-а).
   - Кои задачи са в scope на Етап 6 vs в scope на Етап 7 (колегата).
2. **`C:/Users/kaloyan.georgiev/Projects/ralph/user-steps.md`**, секция **🎨 Етап 6** — архитектурни правила,
   TDD рутина, файлова структура, critical rules.
3. **`C:/Users/kaloyan.georgiev/Projects/Admin-App/docs/composition/osdm-audit.md`** —
   **ще бъде създаден в Task 113**. След Task 113, всеки следващ таск го
   чете за да знае кои полета трябва да reshape-не към OSDM.
4. **`C:/Users/kaloyan.georgiev/Projects/admin-app-frontend-structure.md`** — React/TS/MUI patterns.

### 🎯 Архитектурни правила за Етап 6 (кратко)

**Цел:** 2 renderer-а (OpenSaloonLayout + OsdmGrid), използващи shared OSDM структурата,
готови за работа, БЕЗ да чупят визуализацията на create / edit / composition / view.

**Scope IN:**
- Shared `src/app/shared/wagonGrid/` library (types, constants, parse, classify, osdmRenderers, gridFrame)
- OsdmGrid рефактор (≤500 реда, само orchestration + DnD + mutations)
- OpenSaloonLayout рефактор + full OSDM parity (≤250 реда)
- Tests — unit + component + E2E regression

**Scope OUT (в друга задача на друг колега — Етап 7):**
- Seed/DB cleanup на legacy structural pseudo-seats
- Миграция на спални/кушет/купе wagons към OSDM grid
- Изтриване на CabinLayout / SleeperLayout / CouchetteLayout / CompartmentLayout
- Изтриване на legacy AccommodationType enum стойности
- Премахване на pixel coordinate infrastructure
- DB check constraints

**Backward compatibility задължителна:** adapter в shared/wagonGrid/parse/
конвертира legacy Seat[] с isPhysicallyPresent=false + pixel coords към
synthetic OSDM elements. Markiran с `TEMP: remove after Etap 7 seed cleanup`.
Тази прослойка позволява Етап 6 да се merge-не преди Етап 7 да приключи.

### 🧪 TDD ритуал за всеки таск

1. **RED** → пиши тестове, пусни `npm run test:run`, **verify FAIL**
2. **GREEN** → минимална имплементация, verify PASS
3. **VISUAL** (само за Task 123) → screenshot compare чрез cursor-ide-browser
4. **DONE** → `npm run test:run && npm run type-check && npx eslint <files-changed-on-this-branch>` + (за Task 122, 124) + `npm run e2e`

### 📋 Последователност на таскове (не пропускай стъпки!)

**6A — Audit (#113):** read-only, произвежда osdm-audit.md
- #113 OSDM spec compliance audit

**6B — Foundation (#114-#116):** types, parse, classify
- #114 Shared types + constants
- #115 Shared parse + legacy adapter (backward-compat)
- #116 Преместване на wall classify/cells/shapes в shared

**6C — Element renderers (#117-#120):** per-element components
- #117 SeatRenderer + BerthRenderer + FoldingSeatRenderer
- #118 WallRenderer (всички 10 icon варианта)
- #119 WindowRenderer + DoorRenderer
- #120 Zone/Table/Stairs/Amenity/Placeholder renderers

**6D — Grid infrastructure (#121):**
- #121 GridContainer + GridCell + GridLayer + DragHighlightOverlay

**6E — Orchestrator migration (#122-#123):**
- #122 OsdmGrid → shared renderers (≤500 реда)
- #123 OpenSaloonLayout → shared + OSDM parity (≤250 реда)

**6F — Verification (#124):**
- #124 E2E renderer parity: create → view → edit → view round-trip

---

## Issues from Last Iteration

[None — Етап 5 завършен успешно; Tasks #96-#112 all passed]

---

## ⚠️ Важно за Етап 6

- **Legacy rendering НЕ се изтрива в този етап.** cellRenderers.tsx,
  osdmRenderers.tsx, wallRenderers.tsx, SeatCell.tsx, zonePanel.tsx,
  CabinLayout.tsx, SleeperLayout.tsx, CouchetteLayout.tsx, CompartmentLayout.tsx —
  всички остават като файлове. OpenSaloonLayout след рефактора просто
  не ги import-ва. Колегата ги трие в Етап 7.
  → **Преди да маркираш таск 123 като готов:** `gitnexus context OpenSaloonLayout`
  трябва да показва, че `cellRenderers`/`osdmRenderers`/`wallRenderers` НЕ са в
  outgoing calls. Ако има остатъчен incoming/outgoing edge към някой от тези
  legacy файлове — рефакторът не е приключен.

- **SeatMapCanvas dispatcher НЕ се пипа.** Който определя кой renderer да се
  ползва за коя серия (sleeper → CabinLayout etc.) — стои. Етап 6 променя само
  самите renderer-и, не тяхното маршрутизиране.

- **Visual regression проверка е задължителна за Task 123** — OpenSaloonLayout
  промените могат да счупят визуално възприятие. Използвай cursor-ide-browser
  MCP за screenshots. Сравнявай с wagon editor preview (drawer в WagonCreationPage)
  за паритет.

- **`osdm-audit.md` от Task 113 е входен артефакт за Task 114+** — полетата,
  маркирани като 'направено на око', в Task 114 получават TODO коментар в
  типовете и се адресират в **Етап 7** (не в Етап 6, за да не разширяваме scope).

- **Backward-compat adapter НЕ е опционален.** Адаптерът в Task 115 е
  задължителен за да не чупим композицията на legacy wagons.

---

**Next Action:** Find task #113 (first with `"passes": false`) and begin Етап 6.

Прочети `C:/Users/kaloyan.georgiev/Projects/wagon-renderer-unification-plan.md`, `user-steps.md §Етап 6`,
и (за #114+) `osdm-audit.md` ПРЕДИ да започнеш. Следвай TDD: RED → GREEN → DONE.
Commit с точния `description` от tasks.json. След това изведи XML status и **СПРИ**.

---

## 🔮 След Етап 6 — Етап 7: Composition Cloning (Tasks #125, #130–#139)

> **TIMING:** Тази секция влиза в сила КОГАТО всички задачи #113–#124 са с `"passes": true`.
> Преди това — игнорирай и работи по Етап 6.

Когато първият `passes:false` task в `tasks.json` е #125 (вместо #113-#124):

**Continue with:** Task #125 — [BE] Verify existing /clone endpoint(s); gap-fill само ако нещо липсва — НЕ пипай DB

### 📜 Задължително преди първия таск от Етап 7

Прочети **в този ред**:

1. **`C:/Users/kaloyan.georgiev/Projects/ralph/composition-clone-spec.md`** — single source of truth за clone feature-а.
   - §0 — бизнес правило (blocked carry, sold не)
   - §1 — скоуп: какво НЕ пишем (никакви DB промени, никакви migrations)
   - §2 — API контракти (POST /clone request/response shape, 409 conflict)
   - §3 — BE поведение (за #125 само: audit + conditional gap-fill)
   - §4 — FE архитектура (dialog, hooks, mock backend filter)
2. **`C:/Users/kaloyan.georgiev/Projects/ralph/user-steps.md`** §"🔁 Етап 7" — critical rules,
   подетапи, файлова структура, отворени въпроси.
3. **`C:/Users/kaloyan.georgiev/Projects/admin-app-frontend-structure.md`** — за FE задачите.
4. **`C:/Users/kaloyan.georgiev/Projects/ralph/PROMPT.md`** §"Existing aggregate repos" — само ако
   #125 fall-ва в Branch C (build handler).

### 🚨 Червени линии за Етап 7

- ❌ **Никакви SQL миграции, никакви EF migrations, никакви промени в SQL проекта**
- ❌ **Никакви нови или променени Domain entities**
- ✅ Чист consumer на existing schema; clone feature пише само нови handlers/DTOs (ако трябва)
- ✅ Default за period clone: FE loop над `/clone` endpoint, не нов server-side endpoint

Ако Task #125 audit покаже че бизнес правилото "blocked carry, sold не" не може
да бъде имплементирано **без** schema промяна → **STOP** и ескалирай. НЕ пиши
migration "за да заобиколиш".

### 🎯 Бизнес правило guard rails (за всеки таск)

Всеки таск с тестове ТРЯБВА да assert-не филтъра:
- #125 — integration test: POST /clone върху mixed-state composition → 0 bookings
- #131 — mock storage unit тест: seed (2 blocked + 3 sold + 1 reserved) → clone → assert (2 blocked, 0 sold, 0 reserved)
- #137 — full FE integration тест с mock backend
- #138 — Playwright E2E: GET /api/compositions/{newId} → bookings.length === 0

Ако seed-ът не съдържа sold seats → тестът е невалиден (не тества правилото).

### 📋 Подетапи на Етап 7

- **7A: BE audit + gap-fill** (#125) — verify, fix филтър ако грешен, build minimal handler ако липсва
- **7B: FE foundation** (#130-#132) — API layer + mock + hooks
- **7C: FE UI** (#133-#136) — dialog + wiring + i18n + conflict preview
- **7D: FE integration** (#137) — mock-backed test
- **7E: E2E** (#138-#139) — Playwright single + period

### 🛑 Не правиш Етап 7 ако

- Task #113-#124 не са завършени → продължи с Етап 6
- Task #125 audit показва schema проблем → STOP, ескалирай (не пиши migration)

---

## 🚂 Етап 8 — Self-propelled (мотриса) interlock (Tasks #150–#158)

> **TIMING:** Влиза в сила КОГАТО Етап 7 (Tasks #125, #130–#143) са с `"passes": true`.
> Преди това — игнорирай.

Когато първият `passes:false` task в `tasks.json` е #150 (вместо #125 или Етап 7 нещо):

**Continue with:** Task #150 — [BE] WagonType.IsSelfPropelled SQL колона + EF migration + seed за DMV серии

### 📜 Задължително преди първия таск от Етап 8

Прочети **в този ред**:

1. **`C:/Users/kaloyan.georgiev/Projects/ralph/DOCS/composition-self-propelled-plan.md`** — спецификацията.
   - §0–§2 — бизнес правило (без смес „мотриса + локомотив с вагони"); source of truth `WagonType.IsSelfPropelled`
   - §3 — SQL колона + seed update (DMV серии: 10, 31-1-4, 31-2-3)
   - §4 — Backend: entity/DTO/commands + integrity validation в AddCarriage (§4.1 е Critical)
   - §5 — Frontend: types, canvas hide-locomotive, palette disable, page orchestration, i18n
   - §6 — Tests matrix (6 unit + 1 API integration + E2E interlock)
   - §7 — отворени въпроси (read + apply решенията)
2. **`C:/Users/kaloyan.georgiev/Projects/railrun-backend-structure.md`** — за BE задачите (Aggregate Repositories, IUnitOfWork pattern).
3. **`C:/Users/kaloyan.georgiev/Projects/admin-app-frontend-structure.md`** — за FE задачите.

### ✅ Зелени линии за Етап 8

- ✅ **SQL Project схемата се обновява** — добавяме нова колона `IsSelfPropelled BIT` в `OSDM-Src/SQLProjects/RailRunServiceSQL/dbo/Tables/WagonTypes.sql` за нова domain функционалност. Това е различно от Етап 7 (clone) където schema промени бяха забранени.
- ✅ **Нов numbered script** `dbo/PostDeployment/Data/079_SetIsSelfPropelledForDmvSeries.sql` с UPDATE statement за DMV серии (Id=19, 27, 28). Регистрира се в `Seed.sql` **СЛЕД** `078_WagonsSnapshot.sql` (snapshot-ът overrides и би нулирал флага).
- ❌ **НЕ модифицирай `003_Wagon_Types.sql`** — той е initial INSERT seed, който НЕ ре-run-ва върху съществуващи редове в dev/prod DBs (Azure). Промени в него не достигат до съществуващи записи.
- ✅ DACPAC build + sqlpackage publish за прилагане на промяната към локалната DB
- ⚠️ **EF Core Power Tools** е канонично решение (database-first scaffold), но е GUI операция в VS/VS Code → НЕ е driver-able от ралф автономно. За автономно изпълнение: **manual property addition** в `WagonType.cs` (един ред: `public bool IsSelfPropelled { get; set; }`) + `WagonTypeConfiguration.cs` (един ред: `entity.Property(e => e.IsSelfPropelled).HasDefaultValue(false);`). Добави `// NOTE: Manual addition matching DB schema. Full re-scaffold may rewrite this file — re-add if missing.` за бъдеща safety. Това е exactly what Power Tools би генерирал; следващ re-scaffold от dev-а ще даде същия output.
- ❌ **НЕ пишем `dotnet ef migrations add`** — този проект е Database-First, не Code-First. Code-First migration ще се конфликтва с DACPAC source-а.

### 🎯 Бизнес правило guard rails (за всеки таск)

- #152 е Critical TDD task — 6 unit теста матрица + 1 API integration test (DevTools/curl bypass защита)
- #155 палитрата показва **ВСИЧКИ** wagonTypes — disable + tooltip за несъвместимите, не hide. Това е UX изискване от клиента.
- #154/#156 — локомотивът „изчезва" е чисто визуално (`!hasSelfPropelled` около статичната Card в WagonCanvas); няма entity промяна.

### 📋 Подетапи на Етап 8

- **8A: BE foundation** (#150-#151) — SQL колона + DTO propagation (entity + EF config през EF Power Tools)
- **8B: BE integrity** (#152) — AddCarriage validation + 409 + локализирано съобщение
- **8C: FE foundation** (#153) — types + API mapping
- **8D: FE UI — composition editor** (#154-#157) — canvas hide-locomotive, palette disable, page orchestration, i18n
- **8E: FE UI — wagon creation form** (#159) — toggle 'Самоходна' в metadata формата; може паралелно с 8D
- **8F: E2E** (#158) — full FE+BE interlock

### 🛑 Не правиш Етап 8 ако

- Етап 7 (Tasks #125, #130-#143) не е завършен → продължи с него
- Task #150 audit показва конфликт с други pending миграции → STOP, ескалирай
