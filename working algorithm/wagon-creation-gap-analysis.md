# Gap Analysis: wagon-creation-spec.md → Текуща имплементация

> Какво трябва да се промени, за да отговаря системата на спецификацията

---

## Икони и визуализация — какво казва OSDM стандартът

### Откъде идват иконите?

**OSDM IRS-90918-10 не предоставя готови SVG/PNG файлове.**

Стандартът изрично записва:
> *„Графичните елементи трябва да бъдат предоставени от приложението за продажби на издателя, за да се гарантира уникален look and feel на конкретното приложение."*

Стандартът дефинира само:
1. **Числови кодове** (20=маса, 115=WC, 119=контакт, 135=прозорец, 179=врата...)
2. **Координати** (X/Y позиция върху решетката)
3. **Пропорции** — колко grid клетки заема всеки елемент (маса=1, голяма маса=2, малка стена=2, голяма стена=3 и т.н.)
4. **Референтни thumbnail картинки** — таблица в документацията с миниатюрни пикселизирани изображения за всеки код като **насока за дизайнерите** (не за директна употреба)
5. **Wireframe** — примерна схема с координатни оси, контурни седалки и стрелка за посока на движение

### Текущата имплементация — OSDM-съвместима ли е?

Текущото решение (frontend рендерерите рисуват елементите сами) е **напълно в съответствие с OSDM** — стандартът изисква точно това. Проблемът не е "дали да рисуваш сам", а **как е организирано** това рисуване.

### Какво трябва да се подобри

**Текущият проблем:** Frontend-ът има hardcoded рендерираща логика в компонентите (`OpenSaloonLayout.tsx` и др.), без ясна таблица с код → SVG файл. Елементите се инферират от `AccommodationType` вместо от OSDM graphic кодове от `osdm_layout_json`.

**OSDM-съвместим подход:**

```
Backend: osdm_layout_json → { icon: 115, coords: {x,y}, orientation: "RIGHT" }
Frontend: icons/osdm/115.svg  ← зарежда SVG по код
```

#### Нужни промени:

**1. Създай icon registry — таблица код → SVG файл**

```typescript
// Admin-App/src/app/features/compositions/constants/osdmIcons.ts
export const OSDM_ICON_MAP: Record<number, string> = {
  4:   '/assets/osdm/wheelchair.svg',
  20:  '/assets/osdm/table-small.svg',
  21:  '/assets/osdm/table-large.svg',
  23:  '/assets/osdm/wall-large.svg',
  26:  '/assets/osdm/wall-small.svg',
  30:  '/assets/osdm/wall-full.svg',
  115: '/assets/osdm/wc.svg',
  119: '/assets/osdm/power-socket.svg',
  131: '/assets/osdm/wc-prm.svg',
  135: '/assets/osdm/window.svg',
  136: '/assets/osdm/stairs-up.svg',
  137: '/assets/osdm/stairs-down.svg',
  171: '/assets/osdm/washbasin.svg',
  179: '/assets/osdm/door.svg',
  // ... всички кодове
};
```

**2. Попълни `osdm_layout_json` в CoachLayout с реални `internals`/`signs`**

```json
{
  "internals": [
    { "icon": 115, "coords": { "x": 0, "y": 0 }, "orientation": "RIGHT" },
    { "icon": 171, "coords": { "x": 1, "y": 0 }, "orientation": "RIGHT" }
  ],
  "signs": [
    { "icon": 135, "coords": { "x": 2, "y": 0 }, "orientation": "DOWN" },
    { "icon": 179, "coords": { "x": 6, "y": 2 }, "orientation": "TOP" }
  ]
}
```

**3. Рендерерите да четат `internals`/`signs` от JSON, не да ги хардкодват**

```tsx
// OpenSaloonLayout.tsx — вместо hardcoded WC/door логика:
{layout.osdmInternals.map(el => (
  <image
    key={`${el.icon}-${el.coords.x}-${el.coords.y}`}
    href={OSDM_ICON_MAP[el.icon]}
    x={el.coords.x * CELL_SIZE}
    y={el.coords.y * CELL_SIZE}
    width={CELL_SIZE}
    height={CELL_SIZE}
  />
))}
```

**4. SVG иконите — откъде да се вземат**

Тъй като OSDM не предоставя готови файлове, опциите са:
- **Ръчно нарисувани** по референтните thumbnails от документацията (текущият подход, само структуриран по-добре)
- **Open source транспортни икони**: [OpenMoji](https://openmoji.org/), [Material Symbols](https://fonts.google.com/icons) (train/seat/wc/wifi иконки)
- **UIC/ERA икони**: Union Internationale des Chemins de fer публикува официален набор от пиктограми за пътнически услуги — проверете [era.europa.eu](https://www.era.europa.eu) и [uic.org](https://uic.org) за TAP-TSI pictograms

### ⚠️ ВНИМАНИЕ — Висок риск от регресии

Текущите рендерери (`OpenSaloonLayout.tsx`, `CabinLayout.tsx`, `CompartmentLayout.tsx`) съдържат **обширна hardcoded логика** за:
- Автоматично детектиране на коридор (biggest Y gap)
- Позициониране на врати, стени, WC зони от координатите на местата
- Цветова схема директно в компонентите
- Инфериране на физическата структура от `AccommodationType`

**Преминаването към data-driven подход (четене от `osdm_layout_json`) е пълен рефакторинг на всички рендерери и ще счупи всички съществуващи вагони**, докато `osdm_layout_json` не е попълнен с коректни данни за всеки wagon type.

**Препоръчителна стратегия — не "big bang", а постепенно:**
1. Попълни `osdm_layout_json` за ЕДИН вагон тип
2. Направи рендерера да чете JSON ако е налично, иначе fallback към старата логика
3. Тествай, потвърди, добави следващия
4. Когато всички са мигрирани — премахни hardcoded fallback-а

Без тази стратегия — при директен рефакторинг всички 23+ вагон типа спират да работят.

### Засегнати файлове

| Файл | Промяна |
|------|---------|
| `Admin-App/src/app/features/compositions/constants/osdmIcons.ts` | **НОВ** — код → SVG path mapping |
| `Admin-App/public/assets/osdm/` | **НОВ** — директория с SVG икони |
| `Admin-App/src/app/features/compositions/components/layoutRenderers/OpenSaloonLayout.tsx` | **Висок риск** — пълен рефакторинг |
| `Admin-App/src/app/features/compositions/components/layoutRenderers/CabinLayout.tsx` | **Висок риск** — пълен рефакторинг |
| `Admin-App/src/app/features/compositions/components/layoutRenderers/CompartmentLayout.tsx` | **Висок риск** — пълен рефакторинг |
| `OSDM-Src/SQLProjects/RailRunServiceSQL/dbo/PostDeployment/Data/004_Coach_Layouts.sql` | Попълни `osdm_layout_json` с internals/signs за всеки wagon type |

---

## 1. Основни данни и идентификация

**Spec → `Wagon_Types` таблица**

| Spec поле | DB колона | Статус |
|-----------|-----------|--------|
| Наименование (Серия) | `series_name` | ✅ Съществува |
| Код (UIC) | `manufacturer_code` | ⚠️ Налично, но е `manufacturer_code` — не е уникален UIC код |
| Клас на вагона | `travel_class` | ✅ Съществува (FIRST/SECOND/BUSINESS) |
| Капацитет | `default_capacity` | ✅ Съществува |
| Тип конструкция | `compartment_type` | ✅ Съществува (SALOON/COUPE/SLEEPER/COUCHETTE) |

### Промени:
- **`manufacturer_code`** да се преименува/допълни с отделна колона `uic_code VARCHAR(12)` — или да се изясни дали `manufacturer_code` служи за това. Понастоящем е VARCHAR(50) и не е UNIQUE.

**Засегнати файлове:**
- `OSDM-Src/SQLProjects/RailRunServiceSQL/dbo/Tables/Wagon_Types.sql` — добави `uic_code` колона
- `OSDM-Src/DotNetServices/RailRunService/RailRunService.Domain/Entities/WagonType.cs` — добави `UicCode` property
- `OSDM-Src/DotNetServices/RailRunService/RailRunService.Application/DTOs/Nomenclatures/WagonTypeDto.cs` — добави `UicCode`
- `Admin-App/src/api/compositions/compositions.types.ts` — добави `uicCode` в WagonType interface

---

## 2. Удобства (Amenities) — 3 нива

### Ниво 1: Wagon-level amenity (глобален флаг)

**Текущо:** Съхранява се като JSON низ в `Wagon_Types.features` (напр. `["AC", "WIFI", "POWER_SOCKET"]`). `Attributes_Dictionary` има само 7 записа и не е свързана с `Wagon_Types` чрез junction таблица.

**Проблем:** Няма many-to-many релация между вагон и удобства — не може лесно да се филтрира или да се добавят нови атрибути.

**Нужна промяна:** Junction таблица `Wagon_Type_Amenities`:
```sql
CREATE TABLE Wagon_Type_Amenities (
    wagon_type_id BIGINT NOT NULL REFERENCES Wagon_Types(wagon_type_id),
    attribute_id  BIGINT NOT NULL REFERENCES Attributes_Dictionary(attribute_id),
    PRIMARY KEY (wagon_type_id, attribute_id)
);
```

**Допълни `Attributes_Dictionary` с липсващи amenities:**
- PET_TRANSPORT (Превоз на домашни любимци) — липсва
- BISTRO — съществува
- WIFI — съществува
- AC — съществува
- BIKE — съществува
- WHEELCHAIR — съществува
- POWER_SOCKET — съществува

**Засегнати файлове:**
- `OSDM-Src/SQLProjects/RailRunServiceSQL/dbo/Tables/Wagon_Type_Amenities.sql` — **нов файл**
- `OSDM-Src/SQLProjects/RailRunServiceSQL/dbo/PostDeployment/Data/002_Attributes_Dictionary.sql` — добави PET_TRANSPORT
- `OSDM-Src/DotNetServices/RailRunService/RailRunService.Domain/Entities/WagonType.cs` — добави `ICollection<AttributesDictionary> Amenities`
- `OSDM-Src/DotNetServices/RailRunService/RailRunService.Infrastructure/Data/SqlDbContext.cs` — конфигурирай Many-to-Many
- `OSDM-Src/DotNetServices/RailRunService/RailRunService.Application/DTOs/Nomenclatures/WagonTypeDto.cs` — замени `Features` string с `List<string> AmenityCodes`
- `Admin-App/src/api/compositions/wagons.api.ts` — обнови mapping-а
- `Admin-App/src/app/features/compositions/types/composition.types.ts` — обнови WagonType interface

### Ниво 2: Place Property `POWER` на конкретни места

**Текущо:** `SeatProperty.POWER_SOCKET` **вече съществува** в enum-а и в DB атрибутите на `Seat_Definitions.attributes`.

**Статус: ✅ Имплементирано** — само трябва да се попълва при въвеждане на вагон кои конкретни места имат контакт.

**Засегнати файлове (само при създаване на нови seed данни):**
- `OSDM-Src/SQLProjects/RailRunServiceSQL/dbo/PostDeployment/Data/005-033_Seat_Definitions_*.sql` — добави `POWER_SOCKET` към атрибутите на съответните места

### Ниво 3: Графичен елемент (код 119) в layout JSON

**Статус: ⛔ Не се ползва и не е нужно** — вж. бележката в началото. Frontend-ът рисува иконки сам.

---

## 3. Схема на местата (Seat Map Layout)

### 3.1 Координатна система

**Статус: ✅ Напълно имплементирана** — `Coach_Layouts` има `grid_width`, `grid_length`, `deck_count`. Frontend рендерерите използват `grid_x`, `grid_y` от `Seat_Definitions`.

### 3.2 Структурни елементи

**Текущо:** Елементите (стени, врати, WC, коридор) се моделират чрез специални `AccommodationType` стойности в `Seat_Definitions`:
- `WALL`, `WALL_H` → стени
- `WC` → тоалетна
- `CORRIDOR` → коридор
- `STAIRS` → стълби
- `GAP` → разделител
- `ZONE` → специална зона

**Проблем:** Прозорците и вратите **не са отделни записи** в `Seat_Definitions` — `OpenSaloonLayout.tsx` ги инферира от координатите (мин/макс Y). Няма явно дефинирани позиции за прозорци.

**Нужна промяна:** Добави `WINDOW` и `DOOR` като AccommodationType стойности, или ги моделирай в `osdm_layout_json`:
```json
{
  "windows": [{"x": 2, "y": 0}, {"x": 4, "y": 0}],
  "doors": [{"x": 0, "y": 2, "orientation": "TOP"}, {"x": 12, "y": 2}],
  "aisle": {"y": 2}
}
```

**Засегнати файлове:**
- `OSDM-Src/SQLProjects/RailRunServiceSQL/dbo/Tables/Coach_Layouts.sql` — документирай структурата на `osdm_layout_json`
- `Admin-App/src/app/features/compositions/types/seat.types.ts` — `WagonPhysicalStructure` interface вече съществува (`windows`, `doors`, `aisle`) — **попълни го в данните**
- `Admin-App/src/app/features/compositions/components/layoutRenderers/OpenSaloonLayout.tsx` — вече чете `physicalStructure`, ако е налично

---

## 4. Дефиниране на индивидуални места

**Текущо в `Seat_Definitions`:**

| Spec атрибут | DB/Frontend | Статус |
|---|---|---|
| Номер на мястото | `seat_number` | ✅ |
| Тип на мястото | `accommodation_type` (18 стойности) | ✅ |
| Позиция (WINDOW/AISLE/MIDDLE) | `attributes` JSON: `WINDOW`, `AISLE` | ✅ |
| Ориентация (RIGHT/LEFT/UP/DOWN) | `attributes` JSON: `FACING_LEFT/RIGHT/UP/DOWN` | ✅ |
| FACE_2_FACE / SIDE_BY_SIDE | ❌ Не е в enum-а | ❌ Липсва |
| TABLE | `attributes` JSON: `TABLE` | ✅ |
| POWER | `attributes` JSON: `POWER_SOCKET` | ✅ |
| SILENCE | `attributes` JSON: `QUIET_ZONE` | ✅ |
| WHEELCHAIR | `AccommodationType.WHEELCHAIR_SPACE` | ✅ |
| LOWER/MIDDLE/UPPER BED | `AccommodationType.BERTH/COUCHETTE` — но без номиране горе/долу | ⚠️ Частично |

### Нужни промени:

**1. Добави `FACE_2_FACE` и `SIDE_BY_SIDE` в `SeatProperty` enum:**
```typescript
// seat.types.ts
FACE_2_FACE = 'FACE_2_FACE',
SIDE_BY_SIDE = 'SIDE_BY_SIDE',
```

**2. Разграничи LOWER/MIDDLE/UPPER за легла:**
Понастоящем `BERTH` и `COUCHETTE` не правят разлика между горно/долно/средно легло. Нужно е или отделни AccommodationType стойности, или атрибут:
```typescript
LOWER_BED = 'LOWER_BED',
MIDDLE_BED = 'MIDDLE_BED',
UPPER_BED = 'UPPER_BED',
```

**Засегнати файлове:**
- `Admin-App/src/app/features/compositions/types/seat.types.ts` — добави enum стойности
- `OSDM-Src/SQLProjects/RailRunServiceSQL/dbo/Tables/Seat_Definitions.sql` — обнови CHECK constraint за `accommodation_type`
- `OSDM-Src/DotNetServices/RailRunService/RailRunService.Domain/Entities/SeatDefinition.cs` — обнови enum/constants
- `Admin-App/src/app/features/compositions/components/layoutRenderers/CabinLayout.tsx` — използвай новите типове за визуализация на легла

---

## 5. Типове вагони — специфика

**Текущо:** Типът се определя от `compartment_type` в `Wagon_Types` и `renderer_type` в `Coach_Layouts`. Renderer selection логиката е:
- `ROWS` → `OpenSaloonLayout`
- `COMPARTMENT` → `CompartmentLayout`
- `CABIN` → `CabinLayout` (auto-detect sleeper vs couchette)

**Проблем:** Мотрисата (EMU/DMU) **няма отделен renderer тип** — третира се като `ROWS` с допълнителни `STAIRS` елементи. Няма явна `MOTORISED_UNIT` стойност в `compartment_type`.

**Нужна промяна:**
```sql
-- Wagon_Types.sql
ALTER TABLE Wagon_Types
    ADD CONSTRAINT CK_WagonTypes_CompartmentType
    CHECK (compartment_type IN ('SALOON', 'COUPE', 'SLEEPER', 'COUCHETTE', 'EMU', 'DMU'));
```

**Засегнати файлове:**
- `OSDM-Src/SQLProjects/RailRunServiceSQL/dbo/Tables/Wagon_Types.sql`
- `Admin-App/src/api/compositions/coachLayouts.api.ts` — добави mapping за EMU/DMU

---

## 6. Backend JSON формат (CoachLayout)

**Текущо:** `Coach_Layouts.osdm_layout_json` съществува, но е **минимално попълнен**. `CoachLayoutDto` го предава as-is към frontend-а.

**Нужна структура според spec-а:**
```json
{
  "gridSize": { "x": 24, "y": 5 },
  "places": [...],
  "internals": [
    { "icon": 115, "coords": { "x": 0, "y": 0 }, "orientation": "RIGHT" }
  ],
  "signs": [
    { "icon": 135, "coords": { "x": 2, "y": 0 }, "orientation": "DOWN" }
  ],
  "compartments": [
    { "id": "A", "places": ["11", "12", "15", "16"] }
  ]
}
```

**Статус:** `places` и `compartments` се генерират динамично от `Seat_Definitions`. `internals`/`signs` с OSDM кодове **не се генерират** — но не е необходимо, тъй като frontend-ът използва собствена логика.

**Нужна промяна:** Попълни `osdm_layout_json` поне с `windows` и `doors` позициите за всеки wagon type (вж. раздел 3.2).

**Засегнати файлове:**
- `OSDM-Src/SQLProjects/RailRunServiceSQL/dbo/PostDeployment/Data/004_Coach_Layouts.sql` — добави windows/doors в JSON
- `OSDM-Src/DotNetServices/RailRunService/RailRunService.Application/DTOs/Nomenclatures/CoachLayoutDto.cs` — добави `OsdmLayoutJson` parsing

---

## 7. Визуално представяне

**Текущо:** ✅ Добре имплементирано — `OpenSaloonLayout.tsx`, `CabinLayout.tsx`, `CompartmentLayout.tsx` рендерират интерактивни SVG схеми с:
- Кликване за избор на място
- Цветово кодиране по статус (зелено=свободно, червено=заето, сиво=блокирано, синьо=locked)
- Gold/Green цветова схема за 1/2 клас — съвпада с wagon-creation-spec-а

**Липсващо:**
- ❌ Легенда за статусите (не се показва в admin view)
- ❌ Временно резервиране (lock) при admin операции — само при ticketing
- ❌ Групово предлагане на близки места

---

## Приоритизиран план за промени

### Висок приоритет (функционална непълнота)
1. **Junction таблица `Wagon_Type_Amenities`** + добави PET_TRANSPORT amenity
2. **`FACE_2_FACE` / `SIDE_BY_SIDE`** в SeatProperty enum
3. **`LOWER_BED` / `MIDDLE_BED` / `UPPER_BED`** в AccommodationType
4. **`uic_code`** колона в Wagon_Types

### Среден приоритет (данни и попълване)
5. **`osdm_layout_json`** — попълни с windows/doors за всички wagon types
6. **`POWER_SOCKET`** — добави към конкретни места в seed данните
7. **EMU/DMU** в compartment_type CHECK constraint

### Нисък приоритет (UI подобрения)
8. Легенда за статусите в seat map
9. Групово предлагане на места

---

## Пълен списък засегнати файлове

### База данни (SQL)
| Файл | Промяна |
|------|---------|
| `OSDM-Src/SQLProjects/RailRunServiceSQL/dbo/Tables/Wagon_Types.sql` | Добави `uic_code`, обнови `compartment_type` CHECK |
| `OSDM-Src/SQLProjects/RailRunServiceSQL/dbo/Tables/Wagon_Type_Amenities.sql` | **НОВ** — junction таблица |
| `OSDM-Src/SQLProjects/RailRunServiceSQL/dbo/Tables/Seat_Definitions.sql` | Обнови `accommodation_type` CHECK |
| `OSDM-Src/SQLProjects/RailRunServiceSQL/dbo/Tables/Coach_Layouts.sql` | Документирай `osdm_layout_json` структура |
| `OSDM-Src/SQLProjects/RailRunServiceSQL/dbo/PostDeployment/Data/002_Attributes_Dictionary.sql` | Добави PET_TRANSPORT |
| `OSDM-Src/SQLProjects/RailRunServiceSQL/dbo/PostDeployment/Data/004_Coach_Layouts.sql` | Попълни windows/doors JSON |
| `OSDM-Src/SQLProjects/RailRunServiceSQL/dbo/PostDeployment/Data/005-033_Seat_Definitions_*.sql` | Добави POWER_SOCKET към конкретни места |

### Backend C#
| Файл | Промяна |
|------|---------|
| `OSDM-Src/.../Entities/WagonType.cs` | Добави `UicCode`, `ICollection<AttributesDictionary> Amenities` |
| `OSDM-Src/.../Entities/SeatDefinition.cs` | Обнови constants за accommodation types |
| `OSDM-Src/.../DTOs/Nomenclatures/WagonTypeDto.cs` | Замени `Features` string с `List<string> AmenityCodes` |
| `OSDM-Src/.../DTOs/Nomenclatures/CoachLayoutDto.cs` | Добави `OsdmLayoutJson` parsing |
| `OSDM-Src/.../Data/SqlDbContext.cs` | Конфигурирай Many-to-Many за Wagon_Type_Amenities |

### Frontend React/TypeScript
| Файл | Промяна |
|------|---------|
| `Admin-App/src/app/features/compositions/types/seat.types.ts` | Добави `FACE_2_FACE`, `SIDE_BY_SIDE`, `LOWER_BED`, `MIDDLE_BED`, `UPPER_BED` |
| `Admin-App/src/api/compositions/compositions.types.ts` | Обнови WagonType interface с `uicCode`, `amenities` |
| `Admin-App/src/api/compositions/wagons.api.ts` | Обнови amenities mapping |
| `Admin-App/src/api/compositions/coachLayouts.api.ts` | Добави EMU/DMU mapping |
| `Admin-App/src/app/features/compositions/components/layoutRenderers/CabinLayout.tsx` | Поддръжка за LOWER/MIDDLE/UPPER_BED |
