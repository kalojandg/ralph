# План: Избягване на смес „мотриса + локомотив с вагони" в композиция

**Цел.** Когато композицията има мотриса (самоходна) — локомотивът изчезва и не могат да се добавят обикновени вагони. Когато има локомотив с обикновени вагони — не може да се добави мотриса.

**Защита на правилото — на двa слоя:**

- **Frontend (UX).** Палитрата показва всички типове, но disable-ва несъвместимите с tooltip — потребителят разбира защо не може да ги добави (виж §5.3). Drag-and-drop guard в канваса (виж §5.2) за защита от stale drag state.
- **Backend (integrity).** `AddCarriage` валидира съвместимостта и отказва несъвместими добавяния — иначе правилото е заобиколимо чрез DevTools / curl / Postman и базата може да се пълни с невалидни композиции (виж §4.1). Това НЕ нарушава първоначалното изискване „без търговска логика върху композицията" — добавя се само integrity check, без промяна на статус/state machine.

Добавя се също нов флаг към `WagonType.IsSelfPropelled` като source of truth.

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
| [GetWagonTypes.cs](OSDM-Src/DotNetServices/RailRunService/RailRunService.Application/Features/Nomenclatures/Queries/GetWagonTypes.cs), [GetWagonTypeById.cs](OSDM-Src/DotNetServices/RailRunService/RailRunService.Application/Features/Nomenclatures/Queries/GetWagonTypeById.cs) | Връщане на `IsSelfPropelled` в DTO (за client-side disable логиката в §5.3) |
| [WagonTypeRequests.cs](OSDM-Src/DotNetServices/RailRunService/RailRunService.API/DTOs/WagonTypeRequests.cs) | Поле в Create/Update API DTO-та |
| [WagonTypesController.cs](OSDM-Src/DotNetServices/RailRunService/RailRunService.API/Controllers/WagonTypesController.cs) | Прокарване на полето в командите. **Нов endpoint за filtering не се изисква** — depo-то показва всичко и frontend-ът disable-ва локално. |

### 4.1 Backend валидация при добавяне на вагон (integrity)

**Защо.** Без валидация на сървъра frontend-правилото е заобиколимо. Всеки клиент (DevTools, curl, друго приложение) може директно да POST-не несъвместим вагон. Базата ще се пълни с „невалидни" композиции, които UI впоследствие няма как да рендерира коректно. Това е integrity слой, не business logic.

**Къде.**

| Файл | Промяна |
|---|---|
| [AddCarriage.cs](OSDM-Src/DotNetServices/RailRunService/RailRunService.Application/Features/Carriages/Commands/AddCarriage.cs) | Преди `_carriageRepo.AddAsync` — нова проверка: ако вече има carriage(s) в композицията, чийто `WagonType.IsSelfPropelled` се различава от този на добавяния тип → `Result.Fail(ErrorKind.Conflict, RailRunErrorCodes.CompositionTractionMix)`. Спецификата изисква зареждане на `WagonType` за всеки съществуващ carriage (вече се прави `Include(c => c.CompositionCarriages)` чрез `CompositionWithCarriagesSpec` — разширява се с `ThenInclude(cc => cc.WagonType)`). |
| [UpdateCarriage.cs](OSDM-Src/DotNetServices/RailRunService/RailRunService.Application/Features/Carriages/Commands/) | Ако `wagonTypeId` е mutable (трябва да се провери): същата проверка преди save. Ако не е mutable — пропускаме. |
| [RailRunErrorCodes.cs](OSDM-Src/DotNetServices/RailRunService/RailRunService.Application/Constants/RailRunErrorCodes.cs) | Нов код: `CompositionTractionMix` (BG: „Не може да се смесват мотрисa и обикновен локомотив с вагони в една композиция.", EN: „Cannot mix self-propelled and regular wagons in the same composition.") |
| [SharedErrors.resx](OSDM-Src/DotNetServices/SharedSrc/Common/Resources/SharedErrors.resx), [SharedErrors.en.resx](OSDM-Src/DotNetServices/SharedSrc/Common/Resources/) | Локализирани съобщения за новия код |

**Алгоритъм:**

```
1. fetch composition with CompositionCarriages.WagonType (спецификация)
2. fetch wagonType for request.WagonTypeId
3. let existingHasSelfPropelled = composition.CompositionCarriages.Any(cc => cc.WagonType.IsSelfPropelled)
4. let existingHasRegular       = composition.CompositionCarriages.Any(cc => !cc.WagonType.IsSelfPropelled)
5. if wagonType.IsSelfPropelled and existingHasRegular       → fail(CompositionTractionMix)
6. if not wagonType.IsSelfPropelled and existingHasSelfPropelled → fail(CompositionTractionMix)
7. иначе → продължи с AddAsync (както сега)
```

**Concurrency.** Two concurrent `AddCarriage` калове в една композиция теоретично могат да минат и двата (всеки чете state-а преди някой да е писал). Опции:

- (a) Приемливо за първа итерация — race-овете са много рядки в реалния admin workflow.
- (b) `SERIALIZABLE` transaction scope около проверката + AddAsync. По-сигурно, но overhead.

Препоръка: **(a)** за първа итерация. Документирай в коментар; ако се види реален race в логовете — мине се на (b).

### 4.2 Клониране — без нова валидация

Клониращата команда (виж [composition-clone-spec.md](composition-clone-spec.md)) копира съществуващи carriages 1:1. Ако source композицията е валидна (минала е през §4.1 при оригиналното добавяне), резултатът също е валиден. **Не се изисква отделна валидация в clone handler-а.**

**Изключение — legacy данни.** Ако в БД има композиция с pre-existing смес (направена преди тази валидация), clone-ът ѝ ще възпроизведе сместа. Това е acceptable за първа итерация. Виж §7 за решение какво правим с legacy mixed композиции.

### 4.3 Не променяме

- **Status state machine** на `Composition` (Draft/Active/Archived) — не пипаме.
- **`Composition` entity** — не пипаме.
- **Read endpoints** — не филтрират; легитимни legacy mixed композиции остават видими.

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

### 5.3 Палитра — показване на ВСИЧКИ типове + disable на несъвместимите

Файл: [WagonPalette.tsx](Admin-App/src/app/features/compositions/components/WagonPalette.tsx)

**Принцип.** „Депото" показва **всички** активни типове вагони — потребителят винаги вижда какво съществува. Несъвместимите спрямо текущата композиция са **disable-нати** с tooltip, който обяснява защо. Това отговаря на UX въпроса „защо го имам в депото, а не мога да го добавя".

**КОГА.** Disable състоянието е derived от `compositionKind` (виж §5.4) и се преизчислява при всяка промяна на композицията чрез React reactivity. **Няма нужда от backend refetch на всяка промяна** — данните в депото не зависят от композицията; зависи само кои карти са активни. Един query на mount е достатъчен.

**КАК.** `WagonPalette` получава целия списък типове + prop `disabledRule`:

```ts
type DisabledRule = 'none' | 'self-propelled' | 'regular';
```

Логика в `WagonPalette.tsx` (на мястото на сегашното `filteredWagonTypes`, ред 68):

- `disabledRule === 'self-propelled'` → картите с `isSelfPropelled === true` (мотрисите) са disable-нати. Композицията е „локомотив + вагони".
- `disabledRule === 'regular'` → картите с `isSelfPropelled === false` (обикновените) са disable-нати. Композицията е „мотриса".
- `disabledRule === 'none'` → всички активни.

#### 5.3.1 Визуално представяне на disable-натите карти

- `opacity: 0.4`, `cursor: 'not-allowed'`, `draggable={false}`
- `onDragStart` short-circuit-ва (не зарежда `dataTransfer`)
- `Tooltip` обвивка (MUI `<Tooltip>` с `placement="right"`) — текст според причината:
  - Когато композицията е „локомотив + вагони" и потребителят hover-ва мотриса:
    > „Мотриса не може да се добави към влак с локомотив и вагони. Премахнете всички вагони, за да добавите мотриса."
    (i18n key: `compositions.editor.palette.tooltipSelfPropelledBlocked`)
  - Когато композицията е „мотриса" и потребителят hover-ва обикновен вагон:
    > „Обикновените вагони не могат да се комбинират с мотриса. Премахнете мотрисата, за да добавите обикновени вагони."
    (i18n key: `compositions.editor.palette.tooltipRegularBlocked`)
- За achievability: `aria-disabled="true"` + `role="option"` се запазва (skreen-readers).

#### 5.3.2 Зареждане на типовете — един query на mount

В [CompositionEditorPage.tsx](Admin-App/src/app/features/compositions/pages/CompositionEditorPage.tsx) (или нов hook `useWagonTypes`):

```ts
const { data: wagonTypes = [] } = useQuery({
  queryKey: ['wagon-types', 'all'],
  queryFn: () => wagonTypesApi.getAll(),
  staleTime: 5 * 60_000,   // 5 мин — типовете рядко се променят
});
```

- Един път при отваряне на редактора (или след инвалидация при CRUD върху номенклатурата от друго място).
- **Без** refetch при промяна на композицията — депото не се променя в зависимост от това какво е в композицията; променя се само какво е disable-нато, което е чиста client-side логика.
- React Query stale-while-revalidate отговаря за случаите когато админ е добавил нов тип в номенклатурата по време на работа.

#### 5.3.3 Guard в `WagonCanvas.handleDrop` остава

Като защита срещу stale drag state (напр. ако потребителят е започнал drag върху карта която междувременно е станала disabled), guard-ът в [`WagonCanvas.handleDrop`](Admin-App/src/app/features/compositions/components/WagonCanvas.tsx#L222) проверява `compositionKind` спрямо вида на дропвания тип и при несъвместимост отказва drop-а + показва snackbar.

### 5.4 Оркестрация в страницата

Файл: [CompositionEditorPage.tsx](Admin-App/src/app/features/compositions/pages/CompositionEditorPage.tsx)

- Изчисляване на `compositionKind` (memo-нато през `useMemo` спрямо `wagons` + `wagonTypes`):
  ```ts
  const compositionKind: 'empty' | 'self-propelled' | 'regular' = useMemo(() => {
    const live = wagons.filter(w => !deletedWagonIds.includes(w.id));
    if (live.length === 0) return 'empty';
    const hasSP = live.some(w => wagonTypes.find(wt => wt.id === w.wagonTypeId)?.isSelfPropelled);
    return hasSP ? 'self-propelled' : 'regular';
  }, [wagons, deletedWagonIds, wagonTypes]);

  const disabledRule: DisabledRule =
    compositionKind === 'self-propelled' ? 'self-propelled' :
    compositionKind === 'regular'        ? 'regular'        : 'none';
  ```
- Подаване към компонентите:
  - `<WagonPalette wagonTypes={wagonTypes} disabledRule={disabledRule} … />` — палитрата получава **целия** списък типове (един query на mount, §5.3.2) и решава disable-а локално.
  - `<WagonCanvas hideLocomotive={compositionKind === 'self-propelled'} … />`
- В `handleWagonDrop` (ред 444) — guard срещу stale drag state (напр. drag започнат преди disable-а да се приложи):
  - ако `compositionKind === 'self-propelled'` и новият тип НЕ е self-propelled → блокирай + `dispatch(showSnackbar({severity:'warning', message: t('compositions.errors.cannotAddRegularToSelfPropelled')}))`
  - ако `compositionKind === 'regular'` и новият Е self-propelled → същата проверка с обратен текст

**Сценарий — добавяне на първа мотриса в празна композиция:**

1. Drop на мотриса → `handleWagonDrop` добавя локално → `wagons` се променя.
2. `useMemo` преизчислява `compositionKind`: `'empty'` → `'self-propelled'`.
3. `disabledRule` става `'self-propelled'`.
4. `WagonPalette` re-render-ва — картите на обикновени вагони стават `opacity: 0.4`, `draggable=false`; hover показва tooltip „Обикновените вагони не могат да се комбинират с мотриса".
5. `WagonCanvas` скрива локомотивната карта (§5.2).
6. **Няма network call** — всичко е client-side.

**Сценарий — премахване на единствената мотриса:**

1. Delete → `wagons` остава празен (или само deleted).
2. `compositionKind`: `'self-propelled'` → `'empty'`; `disabledRule` → `'none'`.
3. Всички карти стават отново активни (без tooltip).
4. Локомотивната карта се появява обратно.

### 5.5 Локализация

| Файл | Нови ключове |
|---|---|
| [src/locales/bg.json](Admin-App/src/locales/bg.json), [src/locales/en.json](Admin-App/src/locales/en.json) | Snackbar при stale drop: `compositions.errors.cannotAddRegularToSelfPropelled`, `compositions.errors.cannotAddSelfPropelledToTrain`. Tooltip-и за disable-нати карти: `compositions.editor.palette.tooltipSelfPropelledBlocked` („Мотриса не може да се добави към влак с локомотив и вагони. Премахнете всички вагони, за да добавите мотриса."), `compositions.editor.palette.tooltipRegularBlocked` („Обикновените вагони не могат да се комбинират с мотриса. Премахнете мотрисата, за да добавите обикновени вагони.") |

---

## 6. Тестове

| Файл | Покритие |
|---|---|
| [WagonCanvas.test.tsx](Admin-App/src/app/features/compositions/components/__tests__/) (нов или разширен) | Локомотив скрит при `hasSelfPropelled`; drop отказан при несъвместимост |
| [WagonPalette.test.tsx](Admin-App/src/app/features/compositions/components/__tests__/) (нов или разширен) | Всички активни типове са визуализирани (нищо не се скрива); disable + tooltip за несъвместимите спрямо `disabledRule`; `draggable={false}` и `aria-disabled` за disable-натите карти |
| [CompositionEditorPage.test.tsx](Admin-App/src/app/features/compositions/pages/__tests__/CompositionEditorPage.test.tsx) | Поток: drop мотриса в празна → локомотивът изчезва; drop обикновен → snackbar; обратна посока; премахване на единствената мотриса → локомотивът се появява |
| Backend: [WagonTypesControllerTests.cs](OSDM-Src/DotNetServices/RailRunService/RailRunService.API.Tests/Controllers/WagonTypesControllerTests.cs) | `IsSelfPropelled` round-trip през Create/Get/Update |
| Backend: [AddCarriageCommandHandlerTests.cs](OSDM-Src/DotNetServices/RailRunService/RailRunService.Application.Tests/) (нов или разширен) | **Critical:** §4.1 валидация — (a) добавяне на self-propelled в празна → OK; (b) добавяне на regular в празна → OK; (c) добавяне на regular в композиция с само self-propelled → Conflict + `CompositionTractionMix`; (d) добавяне на self-propelled в композиция с само regular → Conflict; (e) добавяне на още self-propelled при вече self-propelled → OK; (f) симетрично за regular |
| Backend: API integration test (напр. в [IntegrationTests.cs](OSDM-Src/DotNetServices/RailRunService/RailRunService.API.Tests/Controllers/IntegrationTests.cs)) | POST към реалния endpoint с несъвместим тип → HTTP 409 с error code `CompositionTractionMix` (защита срещу DevTools/curl bypass от UI правилото) |

---

## 7. Отворени въпроси, преди да започне работа

1. **Disable vs. hide в палитрата?** — РЕШЕНО: disable + tooltip (потвърдено от клиента — „defaultно показвам, но обяснявам защо не може").
2. **Legacy mixed композиции в БД.** — UI правилото и backend валидацията кикват само за нови `AddCarriage` извиквания. Стари смесени композиции:
   - Read-only — рендерират се както са.
   - При следващ `AddCarriage` върху тях — валидацията ще откаже всяко добавяне (защото вече има и self-propelled, и regular в composition.CompositionCarriages). Това е „заключване" на legacy композицията — admin трябва първо да премахне един тип, после да добавя.
   - Опция: миграционен скрипт който маркира такива композиции като `Archived`. Решение: **отложено** до първа реална среща с такива данни.
3. **„Локомотивът изчезва" — само визуално или маркираме нещо?** — тъй като локомотивът сега е статична карта без entity, „изчезва" = просто `if (!hasSelfPropelled)` около картата. Когато композицията се изпразни обратно, локомотивът пак се появява.
4. **CompositionCarriage флаг?** — да добавим ли denormalized `IsSelfPropelled` и на ниво carriage за бързо филтриране в SQL, или винаги да join-ваме `WagonType`? Препоръка: join, без денормализация.
5. **Бекенд валидация?** — РЕШЕНО: ДА. Frontend-only правило е заобиколимо от DevTools/curl → integrity на БД не е гарантирана. Виж §4.1. (Първоначалното решение „само визуално" беше преразгледано.)
6. **Concurrency на §4.1?** — (a) acceptable за първа итерация / (b) SERIALIZABLE transaction. Препоръка: (a), документирано в код; (b) ако се види реален race в логовете.
7. **`UpdateCarriage` валидация?** — зависи дали `wagonTypeId` е mutable полето. Трябва да се провери при имплементация и съответно да се добави същата проверка или не.

---

## 8. Ред на изпълнение

1. БД миграция + seed update (точка 3)
2. Бекенд: entity → DTO → команди → API (точка 4)
3. Бекенд валидация в `AddCarriage` + нов error code + локализирани съобщения (§4.1)
4. Фронтенд типове и mapping (5.1)
5. Фронтенд визуална логика — `WagonCanvas`, `WagonPalette`, `CompositionEditorPage` (5.2–5.4)
6. Локализация (5.5)
7. Тестове (раздел 6) — критични са §4.1 backend тестовете

Стъпки 1–3 могат да се мерж-нат отделно от 4–7 (бекендът осигурява integrity и без визуалното ограничение; UI правилото подобрява UX, но не е задължително за data safety). Препоръчителен ред: бекенд преди фронтенд, за да не може фронтендът да изпрати валиден request, който бекендът да отхвърли с грешен текст.
