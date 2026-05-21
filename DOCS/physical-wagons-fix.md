# Physical wagons — корекция на модела (Tasks #171–#180)

> **Status:** Planned (2026-05-21).
> **Replaces / completes:** [physical-wagons-plan.md](physical-wagons-plan.md). Първият проход (Tasks #160–#170) изгради скелета, но НЕ изпълни ключовия инвариант от изискването. Тоя план затваря дефицита.

---

## 0. Текущ дефицит (от user feedback 2026-05-21)

**Дефиниция от потребителя (потвърдена):**
> В списъка „Управление на вагони" се създава 1 физически вагон. Той се идентифицира с номерата си. Поставя се в композиция. Като се сложи веднъж — не може да се сложи пак, защото физически е зает. За втори от същата серия се клонира — създава се втори физически вагон с уникална идентификация.

**Какво е грешно сега:**

| # | Симптом | Корен |
|---|---------|-------|
| 1 | Clone на WagonType връща HTTP 500 (`CK_SeatDefinitions_AccommodationType` violation) | Constraint-ът в `Tables/SeatDefinitions.sql` не включва `STORAGE` / `BICYCLE_RACK`, а `CloneWagonType.cs` при `OverrideBicycleSpaces > 0` insert-ва SeatDefinitions с `AccommodationType=STORAGE`. |
| 2 | Drop на 15-63 в композицията 4 пъти produces #15-63-001..004 + W0001..W0004 (с повтарящи се W номера) | `CompositionEditorPage.generateUniquePlacard()` + `W${Math.abs(tempId).padStart(4,'0')}` — измислят идентификаторите при всеки drop, вместо да ги четат от физическия вагон. tempId не е global counter → дубликати на W номера между main + sub-routes. |
| 3 | Палитрата не disable-ва вагона след drop в текущата чернова | `WagonPalette.isCardDisabled` гледа само BE-availability (cross-composition). Не пита локалния state „кой `wagonTypeId` вече е в draft-а". |
| 4 | Един и същ `wagonTypeId` може да присъства многократно в една композиция | `AddCarriage` и `SaveCompositionWagons` handler-ите validate-ват уникалност само на placard-низа, не на `wagonTypeId`. |
| 5 | `PlacardNumber` + `InventoryNumber` на `WagonType` нямат unique constraint (нито NOT NULL за placard) | `WagonTypes` schema от Task #160 въведе тези колони като nullable без unique → не може да служат като физически identifier. |

**Желан модел (потвърден):**

- `WagonType` row = 1 физически вагон (template концепцията се изхвърля; legacy SeriesName става display-only).
- Всеки WagonType row има уникален, задължителен `PlacardNumber` + (препоръчително) уникален `InventoryNumber`.
- Carriage в композиция: чисто (`compositionId`, `wagonTypeId`, `sequenceNumber`, маршрут). Placard/UIC се ВЗИМАТ от `WagonType` — read-only за carriage row.
- Уникалност вътре в композиция: `wagonTypeId` веднъж. BE отхвърля повторение.
- Палитра: вагонът се disable-ва, ако (а) е в текущата draft композиция, ИЛИ (б) BE-availability го маркира зает от друга ACTIVE композиция на същия `StartDate`.
- За втори от серия: clone в „Управление на вагони" → нов WagonType row с инкрементиран placard → се появява в палитрата като отделна карта.

---

## 1. Backend промени

### 1.1 SQL — `Tables/SeatDefinitions.sql` CHECK constraint

```sql
CONSTRAINT CK_SeatDefinitions_AccommodationType CHECK (
    AccommodationType IN (
        'SEAT', 'FOLDING_SEAT', 'BERTH', 'COUCHETTE',
        'WHEELCHAIR_SPACE', 'COMPANION',
        'STORAGE', 'BICYCLE_RACK',           -- NEW: bicycle/storage retrofits via clone overrides
        'TABLE', 'BIG_TABLE', 'PLACEHOLDER', 'WALL', 'WC',
        'GAP', 'ZONE', 'GRID_LABEL', 'WALL_H', 'CORRIDOR', 'STAIRS'
    )
)
```

### 1.2 SQL — `Tables/WagonTypes.sql`

```sql
PlacardNumber NVARCHAR(20) NOT NULL,
InventoryNumber NVARCHAR(20) NULL,  -- остава nullable за legacy; uniqueness когато не е NULL

CONSTRAINT UQ_WagonTypes_PlacardNumber UNIQUE (PlacardNumber),
-- Филтриран unique за InventoryNumber (само non-NULL):
INDEX UX_WagonTypes_InventoryNumber UNIQUE NONCLUSTERED (InventoryNumber) WHERE InventoryNumber IS NOT NULL
```

### 1.3 Pre-deploy migration за backfill на placard на legacy WagonTypes

Преди да се enforce-не NOT NULL, populate `PlacardNumber` за съществуващите редове. Pattern: `{SeriesName}-{Id}` за template-и, а за clone-ове добавя инкрементиран суфикс по `ParentWagonTypeId`. Скриптът е idempotent (`_ApplyOnce`).

### 1.4 `CloneWagonType` handler

- Премахни `OverrideBicycleSpaces` / `OverrideWheelchairSpaces` от command-а (or move to a separate „Add accommodation" feature). Засега clone-ът копира SeatDefinitions 1:1.
- `PlacardNumber` става **задължително** поле в command + request.
- Default за UI: `${source.PlacardNumber}-${counter}` (counter = броя clones).
- Запази uniqueness check за `PlacardNumber` (additional до schema UQ — за по-чисто error message).

### 1.5 `AddCarriage` + `SaveCompositionWagons` handlers

- Премахни приемането на `PlacardNumber` + `UicNumber` от request body (или ги игнорирай). Placard/UIC се четат от `WagonType` при save-а.
- Добави validation: `wagonTypeId` в `request.NewCarriages` (за save) / `request.WagonTypeId` (за AddCarriage) не може да съвпада с `wagonTypeId` на ВЕЧЕ съществуващ carriage в композицията.
- Нов error code `RailRunErrorCodes.WagonAlreadyInComposition` (`"WAGON_ALREADY_IN_COMPOSITION"`).

### 1.6 `GetAvailableWagonTypesForCompositionQuery`

Без промени — продължава да връща cross-composition occupancy. (FE добавя локалния filter.)

---

## 2. Frontend промени

### 2.1 `CompositionEditorPage`

- Изтрий `generateUniquePlacard` (lines 112-119).
- Изтрий `wagonNumber: \`W${Math.abs(tempId).padStart(4, '0')}\`` от `handleWagonDrop` (line 547) и `handleSubRouteWagonDrop` (line 697).
- На drop вместо генерация:
  ```ts
  placardNumber: wagonType.placardNumber,
  wagonNumber: wagonType.inventoryNumber ?? '',
  ```
- Save flow: премахни placard/uic от DTO-то към BE (BE ги взима от wagonType).

### 2.2 `WagonPalette`

- Нов prop `usedWagonTypeIds: Set<number>` (или extend `availability` записите).
- `isCardDisabled` връща true ако `usedWagonTypeIds.has(card.id)` OR BE availability.
- Tooltip: `compositions.editor.palette.tooltipAlreadyInComposition` = „Вагонът е поставен в композицията".
- В `CompositionEditorPage`: подавай `usedWagonTypeIds = new Set(wagons.map(w => w.wagonTypeId).concat(subRoutes.flatMap(sr => sr.wagons.map(w => w.wagonTypeId))))`.

### 2.3 `WagonCreationPage` + `CloneWagonTypeDialog`

- `PlacardNumber` става **required** поле в формите.
- FE uniqueness check срещу loaded list.
- Default за clone: `${source.placardNumber}-${counter}` где counter = броят клонове на source-а.

### 2.4 `WagonPropertiesPanel`

- `PlacardNumber` + `WagonNumber` стават **read-only** (chip-style display).
- Малка бележка: „Идентификацията се управлява от вагона в [/wagons/{id}/edit](...)".

### 2.5 i18n + UI rename

- Sidebar/breadcrumb: „Wagon Types" / „Типове вагони" → „Управление на вагони" / „Wagon Management".
- `wagons.types.list.title` → `wagons.list.title = 'Управление на вагони'`.
- `wagons.creation.metadata.placardNumber = 'Плакатен номер *'` (required asterisk).

---

## 3. Извън scope (deferred)

- Premium accommodation (bicycle/wheelchair) retrofit UI — `CloneWagonTypeDialog`-ът от Task #165 имаше `OverrideBicycleSpaces`/`OverrideWheelchairSpaces` полета. Изхвърляме ги от clone path. Separate бъдеща feature: „Edit layout — добави bicycle/wheelchair места" в `WagonCreationPage` (вече има layout editor).
- Geographic-chain availability (Option D).
- Audit log на участието (BP-COMP-12).
- Decommissioning UX.
