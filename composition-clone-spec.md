# Спецификация: Клониране на композиция

> Модул "Композиране" — BP-COMP-05, UC-COMP-05
> Свързани Jira: [BDZR-89](https://ballisticcell-team.atlassian.net/browse/BDZR-89) (клониране), [BDZR-961](https://ballisticcell-team.atlassian.net/browse/BDZR-961) (управление на наличност)
> Tasks: #125–#139 в `tasks.json`

---

## 0. Защо съществува тази функционалност

Администраторът на композиции конфигурира **един път** влаков състав (вагони, поредност, плацкартни номера, блокирани/служебни места). Същата конфигурация трябва да върви всеки ден в разписанието — без ръчно повторение и без копиране на единични вагони.

**Бизнес правило (KEY):**
> При клониране се копира **физическата** конфигурация на композицията (тя пътува със състава), а **търговското** състояние (продажби, резервации) **не се копира** — то е тясно свързано с конкретния маршрут/дата.

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

### 2.1 Single clone — еднократно за един trip slot

```
POST /api/compositions/{id}/clone
Content-Type: application/json

{
  "targetTrainNumber": "8632",      // train number в таргет разписанието
  "targetDate": "2026-06-01",       // ISO дата
  "overwrite": false                 // ако true и има активна композиция → cascade delete + create
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

### 2.2 Period clone — за период + дни от седмицата

**Имплементация:** По подразбиране FE loop-ва `/clone` за всеки expanded date (виж §4.3). Specialized endpoint `/clone-for-period` се build-ва САМО ако вече съществува, или ако FE loop-ът се окаже твърде бавен (>5s за 60 дни). Решението се взима в Task #125 (audit phase).

Ако се build-ва server-side:
```
POST /api/compositions/{id}/clone-for-period
{
  "targetTrainNumber": "8632",
  "startDate": "2026-06-01",
  "endDate": "2026-08-31",
  "daysOfWeek": ["MON", "TUE", "WED", "THU", "FRI"],
  "overwrite": false
}
```

Response е agregate: `{ createdCompositionIds[], skipped[], totalRequested, totalCreated, totalSkipped }`.

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
  + CloneCompositionDto, CloneCompositionPeriodDto
  + CloneResponse, ClonePeriodResponse
  + DayOfWeek union
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
- `useCloneCompositionForPeriod` — мутация с прогрес callback. Ако BE не предоставя `/clone-for-period` → hook-ът вътрешно loop-ва над `useCloneComposition` за всеки expanded date и aggregate-ва резултата (включително `skipped`).
- `useClonePreview` — query който чете existing compositions filter-нати по trainNumber+dateRange и връща списък от тези в conflict.

### 4.4 UI — `CloneCompositionDialog`

Стъпков dialog (Stepper, MUI):

**Step 1 — Тип клониране:**
- Radio: "За един ден" / "За период"

**Step 2 — Параметри:**
- Train number autocomplete (от номенклатура)
- DatePicker(s) — single date или date range
- Ако period: ToggleButtonGroup за дни от седмицата (Пн, Вт, Ср, Чт, Пт, Сб, Нд) — по подразбиране всички избрани

**Step 3 — Conflict preview:**
- Извикай `useClonePreview` → ако има конфликти, покажи списъка
- Checkbox "Презапиши съществуващите композиции (cascade delete)" → задава `overwrite=true`

**Step 4 — Confirmation + execute:**
- Покажи summary: "Ще се създадат 60 композиции за периода 2026-06-01 → 2026-08-31, делнични дни"
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
compositions.clone.daysOfWeek
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
- `CloneCompositionDialog.test.tsx` — stepper navigation, form validation, days-of-week toggle, overwrite checkbox

### 5.3 E2E (Playwright)

- `tests/compositions/clone-single.spec.ts` — full flow single clone, verify on details page (carriage list + blocked seats present + sold seats не съществуват в новата композиция)
- `tests/compositions/clone-period.spec.ts` — period clone with days-of-week filter, conflict + overwrite flow

---

## 6. Acceptance criteria — пълен списък

✅ Single clone API работи (или вече съществува, или е build-нат в #125)
✅ Period clone се поддържа (server-side endpoint ИЛИ FE loop)
✅ Blocked seats се пренасят 1:1
✅ Sold/reserved seats **не** се пренасят
✅ Conflict detection работи при `overwrite=false` (409 / skip)
✅ `overwrite=true` cascade-изтрива и пресъздава
✅ Source composition не се мутира (read-only за source)
✅ Един `SaveChangesAsync` per target date (no multi-write transactions)
✅ FE dialog с stepper и conflict preview
✅ i18n bg + en
✅ Unit + integration + E2E тестове минават
✅ TypeScript clean, ESLint clean, dotnet build clean
✅ **Никакви промени в SQL проекта; никакви EF migrations**
