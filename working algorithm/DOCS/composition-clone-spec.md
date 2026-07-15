# Спецификация: Клониране на композиция

> Модул "Композиране" — BP-COMP-05, UC-COMP-05
> Свързани Jira: [BDZR-89](https://ballisticcell-team.atlassian.net/browse/BDZR-89) (клониране), [BDZR-961](https://ballisticcell-team.atlassian.net/browse/BDZR-961) (управление на наличност)
> Tasks: #125–#139 в `tasks.json`

---

## 0. Защо съществува тази функционалност

Администраторът на композиции конфигурира **един път** влаков състав (вагони, поредност, плацкартни номера, блокирани/служебни места). Същата конфигурация трябва да върви всеки ден в разписанието — без ръчно повторение и без копиране на единични вагони.

**Бизнес правило (KEY):**
> При клониране се копира **физическата** конфигурация на композицията (тя пътува със състава), а **търговското** състояние (продажби, резервации) **не се копира** — то е тясно свързано с конкретния маршрут/дата.

### 0.1 Модел на „валидност на композиция" (KEY за разбиране на клонирането)

> **Една композиция = един ден.** Композициите при клиентите са **ден-за-ден**, а не multi-day с „operating days" филтър.
>
> - При **създаване** на нова композиция (manual) → потребителят избира **една дата** (single date picker). Композицията е валидна само за този ден.
> - При **клониране** → потребителят избира **дата от** и **дата до** (range). Резултатът **НЕ** е една композиция с период; резултатът е **N композиции**, по една за всеки ден от обхвата `[startDate, endDate]`, всяка валидна само за своя ден.
> - **Няма дни от седмицата.** Няма филтър „пн/вт/...". Range-ът е затворен интервал; всички дни в него получават композиция.
>
> Пример: clone от 2026-06-01 до 2026-06-05 → създават се 5 нови композиции с дати съответно 01, 02, 03, 04, 05 юни 2026. Това **не** е една композиция с `startDate=01, endDate=05`.

### 0.2 Последици за списъка и филтрите на композициите

Преходът от multi-day към ден-за-ден има директни UI последици в **списъка** на композициите ([CompositionsListPage](Admin-App/src/app/features/compositions/pages/CompositionsListPage.tsx) / [CompositionList.tsx](Admin-App/src/app/features/compositions/components/CompositionList.tsx) / [CompositionFilters.tsx](Admin-App/src/app/features/compositions/components/CompositionFilters.tsx)).

#### 0.2.1 Колоната „Период" → „Дата"

- В таблицата вече **няма** колона „Период" с диапазон `01.01.2025 - 31.12.2025`. Тя се заменя с колона **„Дата"** показваща **една** дата (`DD.MM.YYYY`) — деня, в който композицията е валидна.
- Засегнат файл: [CompositionList.tsx](Admin-App/src/app/features/compositions/components/CompositionList.tsx) — `formatDateRange` (ред 50) се премахва или заменя с `formatDate`; header-ът `compositions.list.table.period` → `compositions.list.table.date`; cell-ът чете `composition.date` (или сегашното `composition.startDate` ако backend оставя двете полета равни в migration phase).
- Сортиране: по подразбиране **по дата DESC** (най-новите композиции горе), със secondary sort по `trainNumber ASC`. Композициите ще станат много — sortable header задължителен.
- i18n: ключове `compositions.list.table.date` (bg: „Дата", en: „Date"); премахване на `compositions.list.table.period`.

#### 0.2.2 Филтри — да работят с „много много" композиции

Сегашните филтри ([CompositionFilters.tsx](Admin-App/src/app/features/compositions/components/CompositionFilters.tsx)) и техните проблеми (от потребителските скрийншоти):

1. **`Влак` autocomplete показва „No options"** — заявката за trains не зарежда данни (празен/счупен `trainsApi.getAll`). Трябва да се поправи зареждането: query да се изпълни на mount, loading индикатор, и empty state „Зареждане…/ Няма налични влакове" вместо tihиt „No options".
2. **Date picker-ите не отварят календар** — от скрийншота полето „От дата" изглежда като обикновен `TextField` с икона, не като MUI X `DatePicker`. Проверка: дали `LocalizationProvider` обвива страницата (нужен е на root level), дали `@mui/x-date-pickers` е импортнат коректно, и дали иконата е била clickable trigger за popper-а. Поправка: ползване на `DatePicker` (както вече е дефиниран в [CompositionFilters.tsx:121](Admin-App/src/app/features/compositions/components/CompositionFilters.tsx#L121)) и осигуряване на `LocalizationProvider` в най-външния layout.
3. **Дублирана семантика на range** — сегашните `dateFrom` / `dateTo` филтрираха „композиции които пресичат този период". Сега, в ден-за-ден модела, семантиката е **„композиции с дата в `[dateFrom, dateTo]`"** — много по-проста SQL заявка (`WHERE Date BETWEEN @from AND @to`). Backend филтърът трябва да се промени съответно.
4. **Допълнителен бърз филтър** — добавяне на quick chips: „Днес", „Утре", „Тази седмица", „Този месец" — задават съответен `[dateFrom, dateTo]` без потребителят да дига календарчета. С много дневни композиции това е критично UX.
5. **Pagination + server-side филтрация** — при ден-за-ден модел очакваме стотици/хиляди записи. Списъкът **не може** да се cache-ва целият на клиента. `compositionsApi.getAll` трябва да приема `page`, `pageSize`, и backend-ът да филтрира + paginate.
6. **Default филтър при отваряне на страницата** — отваряне без филтър ще върне твърде много записи. Препоръка: при mount автоматично се прилага `dateFrom = today`, `dateTo = today + 7 days` (с visible chip „Идващи 7 дни"); потребителят може да го изчисти.

#### 0.2.3 API промени по списъка

| Файл | Промяна |
|---|---|
| [compositions.api.ts](Admin-App/src/api/compositions/compositions.api.ts) | `getAll(filters)` приема `dateFrom`, `dateTo`, `trainId`, `status`, `page`, `pageSize` и ги изпраща като query params |
| [compositions.types.ts](Admin-App/src/api/compositions/compositions.types.ts) | В `Composition`: `date: string` (нов; един ден). `startDate` / `endDate` остават **само** за период на transition (или се премахват, ако backend-ът се reset-не) — виж §0.2.4. `CompositionsFilters` губи „range over period" семантика; запазва `dateFrom`/`dateTo` като чист date-in-range филтър върху `date` колоната |
| Backend ([RailRunService](OSDM-Src/DotNetServices/RailRunService/RailRunService.Application/Features/Compositions/Queries/)) | GET compositions handler-ът филтрира по `WHERE Composition.Date BETWEEN @from AND @to`; добавя pagination skip/take |

#### 0.2.4 Backend модел — `Composition.StartDate` / `EndDate` → `Date`

> **Това е извън scope-а на текущия PR (клонирането).** Описано тук за пълнота — следва да се обхване от отделен PR/спецификация „day-by-day composition model".

В сегашния модел `Composition` пази `StartDate` + `EndDate` + `OperationDays` (виж [Compositions.sql:6-7](OSDM-Src/SQLProjects/RailRunServiceSQL/dbo/Tables/Compositions.sql#L6)). За ден-за-ден моделът има няколко опции:

- **(a) Минимална промяна:** оставяме `StartDate` = `EndDate` = деня; `OperationDays` = всички дни. FE/BE филтрират и показват само `StartDate`. Никакви SQL migrations.
- **(b) Чист модел:** нова колона `Date DATE NOT NULL`, премахване на `StartDate`/`EndDate`/`OperationDays`. Изисква SQL migration + backfill + промени във всички handler-и.

Препоръка за **текущия clone PR**: вариант **(a)** — clone генерира композиции с `StartDate = EndDate = targetDate`, `OperationDays = "1111111"`. Това дава работещ ден-за-ден UX веднага, без SQL migrations (както изисква §1). Вариант (b) се обмисля отделно и не блокира клонирането.

| Какво се копира | Защо |
|-----------------|------|
| Вагони + поредност + плацкартни номера | Това е шаблонът на влака |
| Тип на вагона + конфигурации (купета, спално и т.н.) | Идват от номенклатурата |
| **Блокирани места** (счупена седалка, технически проблем) | Принадлежат на физическия вагон, не на маршрута |
| Служебни места (постоянна резервация за персонал на БДЖ) | Постоянна конфигурация на вагона |
| Маршрутни сегменти (per-wagon OSDM segment definition) | Шаблон на това кои вагони пътуват докъде |
| Активност на вагон (включен/изключен в продажбата) | Конфигурационна, не транзакционна |

| Какво НЕ се копира | Защо |
|---------------------|------|
| Продадени билети | Билетът е за конкретна дата + маршрут (Sofia→Burgas ≠ Burgas→Ruse) |
| Резервирани/заключени места | Резервацията е към конкретен trip + payment session |
| История на резервациите | Audit log per trip |
| Locked-during-payment записи | Кратколетящи; нямат смисъл на нова дата |

---

## 1. Скоуп — какво ПИШЕМ и какво НЕ пишем

**Тази feature пише:**
- Frontend: dialog, hooks, API client, i18n, тестове
- Backend (САМО ако endpoint-ите липсват): минимална имплементация на `POST /api/compositions/{id}/clone` като thin handler върху съществуващите Domain entities

**Тази feature НЕ пише:**
- Никакви SQL миграции
- Никакви промени в `RailRunServiceSQL` проекта
- Никакви промени по съществуващи Domain entities (`Composition`, `Carriage`, `BlockedSeat`, `Booking`)
- Никакви EF Core migrations

Структурата на базата вече съществува. Clone функционалността е чист **consumer** — чете source composition през existing repos, създава нова през EF (без `Include` на trip-scoped entities), записва. Това е всичко.

---

## 2. API контракти

### 2.1 Single clone — еднократно за един ден

```
POST /api/compositions/{id}/clone
Content-Type: application/json

{
  "targetTrainNumber": "8632",      // train number в таргет разписанието
  "targetDate": "2026-06-01",       // ISO дата — единственият ден за който е валидна новата композиция
  "overwrite": false                 // ако true и има активна композиция на тази дата → cascade delete + create
}
```

**200 OK:**
```json
{
  "newCompositionId": 4711,
  "carriagesCloned": 8,
  "blockedSeatsCloned": 5,
  "warnings": []
}
```

**409 CONFLICT (overwrite=false и има конфликт):**
```json
{
  "code": "TARGET_OCCUPIED",
  "existingCompositionId": 4623,
  "message": "Активна композиция вече съществува за {trainNumber} на {date}. Използвайте overwrite=true за презаписване."
}
```

### 2.2 Period clone — за период (всеки ден от обхвата)

**Семантика:** input-ът е range `[startDate, endDate]`. Резултатът е **N композиции, по една за всеки ден от обхвата** (включително начало и край). Всяка създадена композиция има `targetDate = X` и е валидна само за деня X. Няма филтър по дни от седмицата.

**Имплементация:** По подразбиране FE loop-ва `/clone` за всеки ден от обхвата (виж §4.3). Specialized endpoint `/clone-for-period` се build-ва САМО ако вече съществува, или ако FE loop-ът се окаже твърде бавен (>5s за 60 дни). Решението се взима в Task #125 (audit phase).

Ако се build-ва server-side:
```
POST /api/compositions/{id}/clone-for-period
{
  "targetTrainNumber": "8632",
  "startDate": "2026-06-01",
  "endDate": "2026-08-31",
  "overwrite": false
}
```

Response е aggregate: `{ createdCompositionIds[], skipped[], totalRequested, totalCreated, totalSkipped }`. `totalRequested` = `endDate - startDate + 1` (брой дни в затворения обхват).

### 2.3 Conflict detection — без specialized endpoint

Conflict preview-ът се прави client-side: FE извиква existing `GET /api/compositions?trainNumber=...&dateFrom=...&dateTo=...` и filter-ва локално. Без `/clone-preview`.

---

## 3. Backend поведение (за task #125)

**Single concentrated task #125** прави audit + gap-fill според нужда:

1. **Audit:** grep за `clone` в `Controllers/` и `Application/Features/Compositions/`. Документира контракта на съществуващите endpoint-и.
2. **Acceptance test:** integration test през TestServer — seed mixed state, POST /clone, assert blocked carry, sold не.
3. **Branch A** — endpoint работи правилно: nothing else to do, passes:true.
4. **Branch B** — endpoint съществува, но не филтрира правилно: поправи `Include` clauses в handler-а (премахни Include на `Bookings`/`SeatAvailability`).
5. **Branch C** — endpoint липсва: build minimal `CloneCompositionCommand` + handler + endpoint. Repo метод: `Include(Carriages.BlockedSeats).Include(Carriages.RouteSegments).AsNoTracking()` → manual deep-clone (нови PK, set parent←child nav properties) → `AddAsync` → handler вика `IUnitOfWork.SaveChangesAsync` веднъж.

**Не Include-вай и не пипай:** `Bookings`, `SeatAvailability`, `SeatReservations` — те са trip-scoped и не пътуват с клонинга.

**Conflict detection:** ако target slot (trainNumber+date) е зает + overwrite=false → 409. + overwrite=true → reuse existing `DeleteAsync` от ICompositionRepository → cascade-изтрий стария → създай нов.

**Един `SaveChangesAsync`** per single clone request. За period (ако е server-side) — един SaveChanges per date с try/catch на ниво date.

---

## 4. Frontend архитектура

### 4.1 API layer

```
src/api/compositions/compositions.api.ts
  + clone(sourceId, dto): Promise<CloneResponse>
  + cloneForPeriod(sourceId, dto): Promise<ClonePeriodResponse>      // ако endpoint съществува; иначе функцията loop-ва /clone

src/api/compositions/compositions.types.ts
  + CloneCompositionDto         { targetTrainNumber, targetDate, overwrite }
  + CloneCompositionPeriodDto   { targetTrainNumber, startDate, endDate, overwrite }   // НЯМА daysOfWeek
  + CloneResponse, ClonePeriodResponse
```

### 4.2 LocalStorage mock backend (за dev/тестове)

В `src/services/mockBackend/mockStorage.ts` имплементирай `cloneComposition(sourceId, dto)`:

1. `JSON.parse(JSON.stringify(source))` — deep clone.
2. **Filter rules:**
   - **Запази:** `carriages[]` (с тяхните `blockedSeats[]`, `serviceSeats[]`, `routeSegments[]`).
   - **Изтрий:** `bookings[]`, `reservations[]`, `seatAvailability[]`, `auditLog[]` (на ниво carriage и composition).
3. Замени `id` (нов nanoid), `trainNumber`, `date`, `status` ('Draft').
4. Persist в `localStorage['bdz_mockups'].compositions`.

> **Регресионна проверка:** Seed-ът трябва да съдържа поне една composition с **смесен** state: 2 blocked + 3 sold + 1 reserved seats. След clone — 2 blocked, 0 sold, 0 reserved.

### 4.3 React Query hooks

- `useCloneComposition` — `useMutation` с `invalidateQueries(['compositions'])`.
- `useCloneCompositionForPeriod` — мутация с прогрес callback. Ако BE не предоставя `/clone-for-period` → hook-ът вътрешно loop-ва над `useCloneComposition` за **всеки ден** от затворения обхват `[startDate, endDate]` и aggregate-ва резултата (включително `skipped`). Loop-ът е sequential (или ограничен parallel-ism), за да не претовари сървъра при дълги периоди.
- `useClonePreview` — query който чете existing compositions filter-нати по trainNumber+dateRange и връща списък от тези в conflict.

### 4.4 UI — `CloneCompositionDialog`

Стъпков dialog (Stepper, MUI):

**Step 1 — Тип клониране:**
- Radio: "За един ден" / "За период"

**Step 2 — Параметри:**
- Train number autocomplete (от номенклатура)
- DatePicker(s):
  - „За един ден" → **един** single date picker → ще се създаде **една** композиция за избраната дата.
  - „За период" → **два** date picker-а (`startDate`, `endDate`) → ще се създадат **N композиции, по една за всеки ден** в затворения обхват `[startDate, endDate]`.
- **Без ToggleButtonGroup за дни от седмицата.** Няма филтър по седмични дни — всички дни в обхвата получават композиция.
- Валидация: `endDate >= startDate`. Препоръчителен soft-limit на обхвата (напр. 92 дни) с warning, ако бъде надвишен.

**Step 3 — Conflict preview:**
- Извикай `useClonePreview` → ако има конфликти, покажи списъка с дати, които вече имат активна композиция
- Checkbox "Презапиши съществуващите композиции (cascade delete)" → задава `overwrite=true`

**Step 4 — Confirmation + execute:**
- Покажи summary: "Ще се създадат **N** композиции — по една за всеки ден от 2026-06-01 до 2026-08-31."
- Покажи warning: "Блокираните места ще бъдат пренесени. Продадените билети **няма** да бъдат пренесени (те са свързани с конкретен маршрут)."
- Бутон "Клонирай"

### 4.5 Routing / entry points

- В `CompositionsListPage` → row action "Клониране" (icon `ContentCopy`) → отваря `CloneCompositionDialog` с `sourceId`.
- В `CompositionDetailsPage` → header action "Клониране".
- Route не е необходим — dialog-ът е modal.

### 4.6 i18n ключове (`bg.json` + `en.json`)

```
compositions.clone.title
compositions.clone.singleDay
compositions.clone.period
compositions.clone.targetTrain
compositions.clone.targetDate
compositions.clone.startDate
compositions.clone.endDate
compositions.clone.overwriteWarning
compositions.clone.blockedSeatsCarriedOver
compositions.clone.soldSeatsNotCarriedOver
compositions.clone.confirmExecute
compositions.clone.success
compositions.clone.successPeriod
compositions.clone.conflictTitle
compositions.clone.conflictWarning
compositions.clone.errorSourceEmpty
compositions.clone.errorRangeTooLarge
```

---

## 5. Тестове

### 5.1 BE acceptance тест (Task #125)

- `CloneEndpoint_CarriesBlockedSeats_DropsBookings` — единственият задължителен BE тест. Seed-ва mixed state composition, POST /clone, GET и assert правилния филтър.

### 5.2 FE unit/component тестове

- `compositions.api.clone.test.ts` — POST shape correct, response типов
- `mockStorage.clone.test.ts` — **Този е критичният.** Seed mixed state, clone, assert: blocked count carried, sold/reserved count = 0.
- `useCloneComposition.test.ts` — invalidates `['compositions']` query
- `CloneCompositionDialog.test.tsx` — stepper navigation, form validation (range пълноценен и валиден, `endDate >= startDate`), overwrite checkbox. **Не** трябва да има тест за days-of-week — функционалността е премахната.

### 5.3 E2E (Playwright)

- `tests/compositions/clone-single.spec.ts` — full flow single clone, verify on details page (carriage list + blocked seats present + sold seats не съществуват в новата композиция)
- `tests/compositions/clone-period.spec.ts` — period clone: избор на range `[startDate, endDate]`, очаквай N композиции (по една на ден за всеки ден от обхвата); conflict + overwrite flow. **Няма** days-of-week стъпка в потока.

---

## 6. Acceptance criteria — пълен списък

✅ Single clone API работи (или вече съществува, или е build-нат в #125) — създава **една** композиция за **една** дата
✅ Period clone се поддържа (server-side endpoint ИЛИ FE loop) — създава **N композиции, по една за всеки ден** от затворения обхват `[startDate, endDate]`
✅ **Няма days-of-week филтър** в никой клонинг flow (премахнато съобразно ден-за-ден модела)
✅ Blocked seats се пренасят 1:1 за всяка генерирана композиция
✅ Sold/reserved seats **не** се пренасят
✅ Conflict detection работи при `overwrite=false` (409 / skip) — per дата
✅ `overwrite=true` cascade-изтрива и пресъздава
✅ Source composition не се мутира (read-only за source)
✅ Един `SaveChangesAsync` per target date (no multi-write transactions)
✅ FE dialog с stepper и conflict preview; single date picker за "един ден"; два date picker-а за "период"
✅ i18n bg + en
✅ Unit + integration + E2E тестове минават
✅ TypeScript clean, ESLint clean, dotnet build clean
✅ **Никакви промени в SQL проекта; никакви EF migrations**
