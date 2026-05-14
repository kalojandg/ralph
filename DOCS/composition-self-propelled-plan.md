# План: Избягване на смес „мотриса + локомотив с вагони" в композиция

**Цел.** Когато композицията има мотриса (самоходна) — локомотивът изчезва и не могат да се добавят обикновени вагони. Когато има локомотив с обикновени вагони — не може да се добави мотриса. Промените са **само визуални** (фронтенд); базата и `CompositionCarriage` не се променят като поведение, освен добавянето на нов флаг към `WagonType`.

---

## 1. Сегашно състояние

- **Локомотивът** в композицията е статична червена `Card` в [WagonCanvas.tsx:292-320](Admin-App/src/app/features/compositions/components/WagonCanvas.tsx#L292) — няма модел, няма state, винаги се рендерира.
- **WagonPalette** ([WagonPalette.tsx:67-74](Admin-App/src/app/features/compositions/components/WagonPalette.tsx#L67)) филтрира само по `category` и `code` — няма понятие за „мотриса".
- **`WagonType`** на бекенда ([WagonType.cs](OSDM-Src/DotNetServices/RailRunService/RailRunService.Domain/Entities/WagonType.cs), [WagonTypes.sql](OSDM-Src/SQLProjects/RailRunServiceSQL/dbo/Tables/WagonTypes.sql)) има `CompartmentType` (SALOON / COUPE / SLEEPER / COUCHETTE) и `Features` JSON, в който мотрисите носят таг `"DMV"` (серии 10, 31-1-4, 31-2-3) — но няма структурирано поле.
- **`CompositionCarriage`** ([AddCarriage.cs](OSDM-Src/DotNetServices/RailRunService/RailRunService.Application/Features/Carriages/Commands/AddCarriage.cs)) — поддържа всички видове вагони еднакво; няма проверка за смес.
- В [composition-locomotive-spec.md](composition-locomotive-spec.md) вече има предложение за `isSelfPropelled` на `WagonType`.

---

## 2. Източник на истината за „мотриса"

Препоръка: `WagonType.IsSelfPropelled BIT` (флаг на ниво серия), **не** на ниво `CoachLayout`. Причина: дали серия 31 е мотриса е свойство на серията, не на конкретното разположение на местата. Една серия има един отговор „самоходна или не" — затова `WagonType` е правилното място. (Ако държиш на лейаута, може и там, но дублира информация.)

Бизнес правило за визуалния филтър — композицията е в едно от 3 състояния:

- **празна** — без вагони
- **„локомотив + вагони"** — има поне един `wagon` чийто `WagonType.isSelfPropelled = false`
- **„мотриса"** — има поне един `wagon` чийто `WagonType.isSelfPropelled = true`

Преходи между „локомотив + вагони" и „мотриса" не са позволени, докато композицията не се изпразни.

---

## 3. Промени в базата

| Файл | Промяна |
|---|---|
| [OSDM-Src/SQLProjects/RailRunServiceSQL/dbo/Tables/WagonTypes.sql](OSDM-Src/SQLProjects/RailRunServiceSQL/dbo/Tables/WagonTypes.sql) | Добавяне на колона `IsSelfPropelled BIT NOT NULL CONSTRAINT DF_WagonTypes_IsSelfPropelled DEFAULT 0` |
| [003_Wagon_Types.sql](OSDM-Src/SQLProjects/RailRunServiceSQL/dbo/PostDeployment/Data/003_Wagon_Types.sql) | В MERGE-а: `IsSelfPropelled = 1` за Id 19 (серия 10, DMV), 27 (31-1-4), 28 (31-2-3); 0 за останалите |
| Нова EF Core миграция в [RailRunService.Infrastructure/Migrations](OSDM-Src/DotNetServices/RailRunService/RailRunService.Infrastructure/) | `AddIsSelfPropelledToWagonTypes` — `AddColumn<bool>("IsSelfPropelled", "WagonTypes", defaultValue: false, nullable: false)` |

---

## 4. Промени в бекенда (RailRunService)

| Файл | Промяна |
|---|---|
| [WagonType.cs](OSDM-Src/DotNetServices/RailRunService/RailRunService.Domain/Entities/WagonType.cs) | `public bool IsSelfPropelled { get; set; }` |
| [WagonTypeConfiguration.cs](OSDM-Src/DotNetServices/RailRunService/RailRunService.Infrastructure/Data/Configurations/WagonTypeConfiguration.cs) | `entity.Property(e => e.IsSelfPropelled).HasDefaultValue(false);` |
| [WagonTypeDto.cs](OSDM-Src/DotNetServices/RailRunService/RailRunService.Application/DTOs/Nomenclatures/WagonTypeDto.cs) | `public bool IsSelfPropelled { get; set; }` |
| [CreateWagonType.cs](OSDM-Src/DotNetServices/RailRunService/RailRunService.Application/Features/Nomenclatures/Commands/CreateWagonType.cs), [UpdateWagonType.cs](OSDM-Src/DotNetServices/RailRunService/RailRunService.Application/Features/Nomenclatures/Commands/UpdateWagonType.cs) | Добавяне на полето в команда → entity → DTO mapping |
| [GetWagonTypes.cs](OSDM-Src/DotNetServices/RailRunService/RailRunService.Application/Features/Nomenclatures/Queries/GetWagonTypes.cs), [GetWagonTypeById.cs](OSDM-Src/DotNetServices/RailRunService/RailRunService.Application/Features/Nomenclatures/Queries/GetWagonTypeById.cs) | Връщане на `IsSelfPropelled` в DTO |
| [WagonTypeRequests.cs](OSDM-Src/DotNetServices/RailRunService/RailRunService.API/DTOs/WagonTypeRequests.cs) | Поле в Create/Update API DTO-та |
| [WagonTypesController.cs](OSDM-Src/DotNetServices/RailRunService/RailRunService.API/Controllers/WagonTypesController.cs) | Прокарване на полето в командите |

**Не променяме** `CompositionCarriage`, `AddCarriage`, `UpdateCarriage` — правилото остава визуално (по изричното изискване). Бекендът ще приема всякаква смес; UI просто няма да позволи добавянето ѝ.

---

## 5. Промени във фронтенда (Admin-App)

### 5.1 Типове и API mapping

| Файл | Промяна |
|---|---|
| [compositions.types.ts](Admin-App/src/api/compositions/compositions.types.ts) | В `WagonType`: `isSelfPropelled: boolean` |
| [wagons.api.ts](Admin-App/src/api/compositions/wagons.api.ts) (`BackendWagonTypeDto`, `mapWagonTypeFromBackend`) | Добавяне на полето в backend DTO и в mapping функцията |

### 5.2 Визуална логика на канваса

Файл: [WagonCanvas.tsx](Admin-App/src/app/features/compositions/components/WagonCanvas.tsx)

- Извежда се derived state от `wagons` (получено като prop):
  ```
  hasSelfPropelled  = wagons.some(w => wagonTypeById(w.wagonTypeId)?.isSelfPropelled)
  hasRegularWagon   = wagons.some(w => !wagonTypeById(w.wagonTypeId)?.isSelfPropelled)
  ```
- **Локомотивна карта** (ред 292-320): рендерира се само ако `!hasSelfPropelled`. Когато има мотриса — картата изчезва. При изпразване на композицията — се появява отново.
- **`handleDrop`** (ред 222-233): преди да извика `onWagonDrop`, проверява съвместимост спрямо текущото състояние. Ако несъвместимо — не извиква callback-а (или извиква нов `onIncompatibleDrop` за snackbar).
- **`handleDragOver`** (ред 235-238): когато текущо влаченият елемент е несъвместим — `dropEffect = 'none'` и визуален feedback (червена рамка вместо синя).

### 5.3 Палитра — филтриране на наличните типове

Файл: [WagonPalette.tsx](Admin-App/src/app/features/compositions/components/WagonPalette.tsx)

Нов prop: `disabledRule: 'none' | 'self-propelled' | 'regular'` (изчислява се от родителя). Логика в `filteredWagonTypes` (ред 68):

- `disabledRule === 'self-propelled'` → disable картите с `isSelfPropelled === true` (мотрисите); композицията вече е „локомотив + вагони"
- `disabledRule === 'regular'` → disable картите с `isSelfPropelled === false` (обикновените); композицията вече е „мотриса"
- `disabledRule === 'none'` → всичко налично

**Препоръка:** disable (не скривай) + tooltip с обяснение — потребителят разбира защо не може. Карта с `cursor: 'not-allowed'`, `opacity: 0.4`, `draggable={false}`.

### 5.4 Оркестрация в страницата

Файл: [CompositionEditorPage.tsx](Admin-App/src/app/features/compositions/pages/CompositionEditorPage.tsx)

- Изчисляване на `compositionKind`:
  ```
  const compositionKind: 'empty' | 'self-propelled' | 'regular' = (() => {
    const live = wagons.filter(w => !deletedWagonIds.includes(w.id));
    if (live.length === 0) return 'empty';
    const hasSP = live.some(w => wagonTypes.find(wt => wt.id === w.wagonTypeId)?.isSelfPropelled);
    return hasSP ? 'self-propelled' : 'regular';
  })();
  ```
- В `handleWagonDrop` (ред 444): guard преди добавяне:
  - ако `compositionKind === 'self-propelled'` и новият тип НЕ е self-propelled → блокирай + `dispatch(showSnackbar({severity:'warning', message: t('compositions.errors.cannotAddRegularToSelfPropelled')}))`
  - ако `compositionKind === 'regular'` и новият Е self-propelled → същата проверка с обратен текст
- Подава `disabledRule` към `WagonPalette` и `hideLocomotive={compositionKind === 'self-propelled'}` към `WagonCanvas`.

### 5.5 Локализация

| Файл | Нови ключове |
|---|---|
| [src/locales/bg.json](Admin-App/src/locales/bg.json), [src/locales/en.json](Admin-App/src/locales/en.json) | `compositions.errors.cannotAddRegularToSelfPropelled` („Мотрисата не може да се комбинира с обикновени вагони"), `compositions.errors.cannotAddSelfPropelledToTrain` („Мотрисата не може да се добави към влак с локомотив и вагони"), `compositions.editor.palette.disabledSelfPropelled` (tooltip), `compositions.editor.palette.disabledRegular` (tooltip) |

---

## 6. Тестове

| Файл | Покритие |
|---|---|
| [WagonCanvas.test.tsx](Admin-App/src/app/features/compositions/components/__tests__/) (нов или разширен) | Локомотив скрит при `hasSelfPropelled`; drop отказан при несъвместимост |
| [WagonPalette.test.tsx](Admin-App/src/app/features/compositions/components/__tests__/) (нов или разширен) | Disable на карти според `disabledRule`; tooltip съдържание |
| [CompositionEditorPage.test.tsx](Admin-App/src/app/features/compositions/pages/__tests__/CompositionEditorPage.test.tsx) | Поток: drop мотриса в празна → локомотивът изчезва; drop обикновен → snackbar; обратна посока; премахване на единствената мотриса → локомотивът се появява |
| Backend: разширяване на [WagonTypesControllerTests.cs](OSDM-Src/DotNetServices/RailRunService/RailRunService.API.Tests/Controllers/WagonTypesControllerTests.cs) | `IsSelfPropelled` round-trip през Create/Get/Update |

---

## 7. Отворени въпроси, преди да започне работа

1. **Disable vs. hide в палитрата?** — препоръчвам disable + tooltip, за да е ясно защо.
2. **Какво става със съществуващи активни композиции в БД, които вече смесват серия 10 с обикновени вагони?** — UI правилото е само за нови edit-ове. Стари смесени композиции ще се рендерират както са (но потребителят не може да добавя още). Това приемливо ли е, или искаме „migration banner" в редактора?
3. **„Локомотивът изчезва" — само визуално или маркираме нещо?** — тъй като локомотивът сега е статична карта без entity, „изчезва" = просто `if (!hasSelfPropelled)` около картата. Когато композицията се изпразни обратно, локомотивът пак се появява.
4. **CompositionCarriage флаг?** — да добавим ли denormalized `IsSelfPropelled` и на ниво carriage за бързо филтриране в SQL, или винаги да join-ваме `WagonType`? Препоръка: join, без денормализация.
5. **Бекенд валидация?** — потвърдено: НЕ добавяме (само визуално). Това оставя място за бъдеща защита, ако някой друг клиент удари API-то директно.

---

## 8. Ред на изпълнение

1. БД миграция + seed update (точка 3)
2. Бекенд: entity → DTO → команди → API (точка 4)
3. Фронтенд типове и mapping (5.1)
4. Фронтенд визуална логика — `WagonCanvas`, `WagonPalette`, `CompositionEditorPage` (5.2–5.4)
5. Локализация (5.5)
6. Тестове (раздел 6)

Стъпки 1–2 могат да се мерж-нат отделно от 3–6 (бекендът работи и без визуалното ограничение).
