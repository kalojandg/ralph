# Имплементационен план: Data-driven вагони

> Ред на изпълнение и пълен списък от промени

---

## Стратегия

**Не "big bang" — хибриден подход:**

```
Фаза 0 → Фундамент (DB + типове)
Фаза 1 → Мигрирай 1 съществуващ вагон (21-43) до data-driven
Фаза 2 → Строй Creation UI върху доказания модел
Фаза 3 → Мигрирай останалите вагони
Фаза 4 → Премахни hardcoded fallback
```

---

## Фаза 0 — Фундамент

### 0.1 SVG икони — набор и източници

Трябват икони за следните OSDM графични кодове. Ред на търсене:

> ⚠️ **ERA и UIC не предоставят готови SVG файлове за сваляне.** Пиктограмите са дефинирани само в PDF спецификации като референция. Практически опции:

**1. ERA TAP-TSI — само за справка (PDF, не SVG)**
- Код листа с описания: https://www.era.europa.eu/system/files/2022-11/era_tap_passenger_code_list_1.4.2.pdf
- Технически документи: https://www.era.europa.eu/domains/technical-specifications-interoperability/telematics-applications-passenger-service-tsi_en
- Teleref портал (изисква регистрация): https://teleref.era.europa.eu/
- Употреба: провери кои кодове отговарят на кои услуги, после нарисувай/намери SVG

**2. UIC — само за справка (платен стандарт)**
- Стандарт EN 45545 / UIC пиктограми (платен): https://shop.uic.org/en/505-rolling-stock/14572-railway-applications-markings-pictograms-tactile-signs-and-controls-destination-boards-and-number-plates-seat-reservation-indicators-to-be-affixed-to-passenger-vehicles-used-in-international-traffic.html
- Употреба: само ако организацията има достъп до документа

**3. Material Symbols (Google) — ПРЕПОРЪЧИТЕЛНО за повечето икони**
- URL: https://fonts.google.com/icons
- Лиценз: Apache 2.0 — свободно за търговска употреба
- Покрива: `power`, `wc`, `wifi`, `accessible`, `pedal_bike`, `restaurant`, `luggage`, `stairs`, `door_front`, `shower`, `volume_off`, `child_care`, `baby_changing_station`, `ac_unit`, `usb`

**4. SVG Repo — за липсващите**
- URL: https://www.svgrepo.com
- Лиценз: проверявай за всяка икона (повечето са CC0/MIT)
- Употреба: намери конкретна икона по търсене

**5. Flaticon / Freepik — алтернатива**
- https://www.flaticon.com/free-icons/railway (15 000+ жп икони)
- https://www.freepik.com/icons/train
- Лиценз: безплатно с атрибуция (или платен план без)

**Препоръчителен подход за БДЖ:**
1. Свали Material Symbols SVG файловете за стандартните икони (WC, wifi, power, wheelchair...)
2. За специфично жп съдържание (легло, купе, вагон) — вземи от SVG Repo или нарисувай
3. Стените, коридорът и прозорците са геометрични фигури — рисувай директно в SVG/JSX, не са нужни икони

**Пълна таблица: OSDM код → SVG файл → Material Symbols икона**

> Кодовете в системата са OSDM числови кодове (не се менят).
> SVG файловете се именуват по кода. Material Symbols е визуалният източник.

| OSDM код | Елемент | SVG файл | Material Symbols икона |
|----------|---------|----------|------------------------|
| **4** | Инвалидна количка | `004_wheelchair.svg` | `accessible` |
| **20** | Малка сгъваема масичка (до стената, между лице-в-лице места) | `020_table_small.svg` | *(SVG rect — малък правоъгълник)* |
| **21** | Голяма маса (тясна и дълга — бистро/ресторант вагон) | `021_table_large.svg` | *(SVG rect — тясен дълъг правоъгълник)* |
| **23** | Стена 3 клетки | `023_wall_3.svg` | *(SVG правоъгълник — не е икона)* |
| **26** | Стена 2 клетки | `026_wall_2.svg` | *(SVG правоъгълник)* |
| **29** | Стена 2 клетки (вариант) | `029_wall_2b.svg` | *(SVG правоъгълник)* |
| **30** | Стена цяла дължина | `030_wall_full.svg` | *(SVG линия)* |
| **32** | Стена 1 клетка | `032_wall_1.svg` | *(SVG правоъгълник)* |
| **100** | Зона 2-ри клас | `100_zone_2nd.svg` | *(SVG текст "2")* |
| **101** | Зона 1-ви клас | `101_zone_1st.svg` | *(SVG текст "1")* |
| **102** | Бар зона | `102_bar.svg` | `local_bar` |
| **105** | PRM зона | `105_prm_zone.svg` | `accessibility_new` |
| **106** | Семейна зона | `106_family.svg` | `family_restroom` |
| **107** | Ресторант | `107_restaurant.svg` | `restaurant` |
| **108** | Велосипеди | `108_bicycle.svg` | `pedal_bike` |
| **109** | Багаж | `109_luggage.svg` | `luggage` |
| **113** | Гардероб | `113_wardrobe.svg` | `checkroom` |
| **114** | Кошче | `114_trash.svg` | `delete` |
| **115** | WC | `115_wc.svg` | `wc` |
| **116** | Тиха зона | `116_silence.svg` | `volume_off` |
| **117** | Детски кът | `117_kids.svg` | `child_care` |
| **119** | Електрически контакт | `119_power_socket.svg` | `power` |
| **130** | Wi-Fi | `130_wifi.svg` | `wifi` |
| **131** | WC за хора с увреждания | `131_wc_prm.svg` | `accessible` + `wc` |
| **132** | Климатик | `132_ac.svg` | `ac_unit` |
| **133** | USB порт | `133_usb.svg` | `usb` |
| **135** | Прозорец (1 клетка) | `135_window_1.svg` | *(SVG правоъгълник)* |
| **136** | Стълби нагоре | `136_stairs_up.svg` | `stairs` + стрелка нагоре |
| **137** | Стълби надолу | `137_stairs_down.svg` | `stairs` + стрелка надолу |
| **163** | Душ | `163_shower.svg` | `shower` |
| **168** | Маса за повиване | `168_baby.svg` | `baby_changing_station` |
| **171** | Мивка | `171_washbasin.svg` | `water_drop` |
| **174** | Прозорец 2 клетки | `174_window_2.svg` | *(SVG правоъгълник)* |
| **175** | Прозорец 3 клетки | `175_window_3.svg` | *(SVG правоъгълник)* |
| **179** | Врата | `179_door.svg` | `door_front` |

> **Стени, прозорци, коридор** нямат Material икона — рисуват се като геометрични SVG фигури (rect/line) в съответния цвят/стил.

**Местоположение в проекта:**
```
Admin-App/public/assets/osdm/
  ├── 004_wheelchair.svg
  ├── 020_table_small.svg
  ├── 021_table_large.svg
  ├── 115_wc.svg
  ├── 119_power_socket.svg
  ├── 130_wifi.svg
  ├── 131_wc_prm.svg
  ├── 135_window.svg
  ├── 179_door.svg
  └── ... (всички кодове)
```

**Файл с registry:**
```typescript
// Admin-App/src/app/features/compositions/constants/osdmIcons.ts
export const OSDM_ICON_MAP: Record<number, string> = {
  4:   '/assets/osdm/004_wheelchair.svg',
  20:  '/assets/osdm/020_table_small.svg',
  21:  '/assets/osdm/021_table_large.svg',
  23:  '/assets/osdm/023_wall_3.svg',
  26:  '/assets/osdm/026_wall_2.svg',
  29:  '/assets/osdm/029_wall_2b.svg',
  30:  '/assets/osdm/030_wall_full.svg',
  32:  '/assets/osdm/032_wall_1.svg',
  100: '/assets/osdm/100_zone_2nd.svg',
  101: '/assets/osdm/101_zone_1st.svg',
  102: '/assets/osdm/102_bar.svg',
  105: '/assets/osdm/105_prm_zone.svg',
  106: '/assets/osdm/106_family.svg',
  107: '/assets/osdm/107_restaurant.svg',
  108: '/assets/osdm/108_bicycle.svg',
  109: '/assets/osdm/109_luggage.svg',
  113: '/assets/osdm/113_wardrobe.svg',
  114: '/assets/osdm/114_trash.svg',
  115: '/assets/osdm/115_wc.svg',
  116: '/assets/osdm/116_silence.svg',
  117: '/assets/osdm/117_kids.svg',
  119: '/assets/osdm/119_power_socket.svg',
  130: '/assets/osdm/130_wifi.svg',
  131: '/assets/osdm/131_wc_prm.svg',
  132: '/assets/osdm/132_ac.svg',
  133: '/assets/osdm/133_usb.svg',
  135: '/assets/osdm/135_window_1.svg',
  136: '/assets/osdm/136_stairs_up.svg',
  137: '/assets/osdm/137_stairs_down.svg',
  163: '/assets/osdm/163_shower.svg',
  168: '/assets/osdm/168_baby.svg',
  171: '/assets/osdm/171_washbasin.svg',
  174: '/assets/osdm/174_window_2.svg',
  175: '/assets/osdm/175_window_3.svg',
  179: '/assets/osdm/179_door.svg',
};

// Пропорции (брой grid клетки по X)
export const OSDM_ICON_WIDTH: Record<number, number> = {
  20: 1, 21: 2,         // маси
  23: 3, 26: 2, 29: 2, 30: 999, 32: 1,  // стени (30 = цяла дължина)
  135: 1, 174: 2, 175: 3,               // прозорци
  default: 1,
};
```

---

### 0.2 DB промени — нови полета и таблици

#### 0.2.1 `Wagon_Types` — добави `uic_code`

```sql
-- OSDM-Src/SQLProjects/RailRunServiceSQL/dbo/Tables/Wagon_Types.sql
ALTER TABLE Wagon_Types
    ADD uic_code VARCHAR(12) NULL;
-- (не UNIQUE засега — съществуващите редове нямат стойност)

-- Обнови compartment_type CHECK:
ALTER TABLE Wagon_Types DROP CONSTRAINT CK_WagonTypes_CompartmentType;
ALTER TABLE Wagon_Types ADD CONSTRAINT CK_WagonTypes_CompartmentType
    CHECK (compartment_type IN ('SALOON', 'COUPE', 'SLEEPER', 'COUCHETTE', 'EMU', 'DMU'));
```

#### 0.2.2 Нова таблица `Wagon_Type_Amenities` (many-to-many)

```sql
-- НОВО: OSDM-Src/SQLProjects/RailRunServiceSQL/dbo/Tables/Wagon_Type_Amenities.sql
CREATE TABLE Wagon_Type_Amenities (
    wagon_type_id BIGINT NOT NULL
        REFERENCES Wagon_Types(wagon_type_id) ON DELETE CASCADE,
    attribute_id  BIGINT NOT NULL
        REFERENCES Attributes_Dictionary(attribute_id),
    CONSTRAINT PK_WagonTypeAmenities PRIMARY KEY (wagon_type_id, attribute_id)
);
```

#### 0.2.3 `Attributes_Dictionary` — добави липсващи amenities

```sql
-- OSDM-Src/SQLProjects/RailRunServiceSQL/dbo/PostDeployment/Data/002_Attributes_Dictionary.sql
INSERT INTO Attributes_Dictionary (code, description_bg, description_en, icon_url, osdm_mapping)
VALUES
    ('PET_TRANSPORT', N'Превоз на домашни любимци', 'Pet transport', '/assets/osdm/108_pets.svg', 'PET_TRANSPORT'),
    ('POWER_SOCKET',  N'Електрически контакт',      'Power socket',  '/assets/osdm/119_power_socket.svg', 'POWER_SUPPLY'),
    ('AC',            N'Климатик',                  'Air conditioning', '/assets/osdm/132_ac.svg', 'AIR_CONDITIONED'),
    ('WIFI',          N'Wi-Fi интернет',             'Wi-Fi',         '/assets/osdm/130_wifi.svg', 'WIFI_OFFERED');
-- (проверете кои вече съществуват преди INSERT)
```

#### 0.2.4 `Seat_Definitions` — разшири `accommodation_type` CHECK

```sql
-- OSDM-Src/SQLProjects/RailRunServiceSQL/dbo/Tables/Seat_Definitions.sql
ALTER TABLE Seat_Definitions DROP CONSTRAINT CK_SeatDefinitions_AccommodationType;
ALTER TABLE Seat_Definitions ADD CONSTRAINT CK_SeatDefinitions_AccommodationType
    CHECK (accommodation_type IN (
        'SEAT', 'FOLDING_SEAT',
        'BERTH', 'LOWER_BED', 'MIDDLE_BED', 'UPPER_BED',
        'COUCHETTE',
        'WHEELCHAIR_SPACE', 'COMPANION',
        'TABLE', 'BIG_TABLE',
        'PLACEHOLDER', 'WALL', 'WALL_H',
        'WC', 'GAP', 'ZONE',
        'GRID_LABEL', 'CORRIDOR', 'STAIRS',
        'WINDOW', 'DOOR'
    ));
```

#### 0.2.5 `Coach_Layouts` — дефинирай структурата на `osdm_layout_json`

Документирай очаквания JSON формат (не се променя колоната — само се попълва правилно):

```json
{
  "gridSize": { "x": 24, "y": 5 },
  "internals": [
    { "icon": 115, "coords": { "x": 0, "y": 0 }, "orientation": "RIGHT", "width": 1 }
  ],
  "signs": [
    { "icon": 135, "coords": { "x": 2, "y": 0 }, "orientation": "DOWN",  "width": 1 },
    { "icon": 179, "coords": { "x": 6, "y": 2 }, "orientation": "TOP",   "width": 1 }
  ],
  "aisle": { "y": 2 },
  "compartments": [
    { "id": "A", "places": ["11", "12", "15", "16", "21", "22"] }
  ]
}
```

> `internals` = вградени елементи (WC, маса, стена)
> `signs` = наслагвания върху контура (прозорец, врата)
> Полето `places` в compartments се генерира динамично от `Seat_Definitions`

---

### 0.3 Backend C# промени

**Файл: `WagonType.cs`**
```csharp
public string? UicCode { get; set; }
public ICollection<AttributesDictionary> Amenities { get; set; } = new List<AttributesDictionary>();
```

**Файл: `WagonTypeDto.cs`**
```csharp
// Замени:
public string? Features { get; set; }
// С:
public List<string> AmenityCodes { get; set; } = new();
public string? UicCode { get; set; }
```

**Файл: `SeatDefinition.cs`** — добави константи за новите типове:
```csharp
public const string LOWER_BED = "LOWER_BED";
public const string MIDDLE_BED = "MIDDLE_BED";
public const string UPPER_BED = "UPPER_BED";
public const string WINDOW = "WINDOW";
public const string DOOR = "DOOR";
```

**Файл: `SqlDbContext.cs`** — конфигурирай Many-to-Many:
```csharp
modelBuilder.Entity<WagonType>()
    .HasMany(w => w.Amenities)
    .WithMany()
    .UsingEntity("Wagon_Type_Amenities",
        l => l.HasOne(typeof(AttributesDictionary)).WithMany().HasForeignKey("attribute_id"),
        r => r.HasOne(typeof(WagonType)).WithMany().HasForeignKey("wagon_type_id"));
```

---

### 0.4 Frontend TypeScript промени

**Файл: `seat.types.ts`** — добави в enum-ите:
```typescript
// В AccommodationType:
LOWER_BED = 'LOWER_BED',
MIDDLE_BED = 'MIDDLE_BED',
UPPER_BED = 'UPPER_BED',
WINDOW = 'WINDOW',
DOOR = 'DOOR',

// В SeatProperty:
FACE_2_FACE = 'FACE_2_FACE',
SIDE_BY_SIDE = 'SIDE_BY_SIDE',
```

**Файл: `composition.types.ts`** — обнови WagonType interface:
```typescript
interface WagonType {
  // Съществуващи...
  uicCode?: string;           // ново
  amenityCodes: string[];     // замества features: string
}
```

**Нов файл: `osdmLayout.types.ts`** — типове за layout JSON:
```typescript
export interface OsdmCoords { x: number; y: number; }
export interface OsdmElement {
  icon: number;
  coords: OsdmCoords;
  orientation: 'TOP' | 'RIGHT' | 'BOTTOM' | 'LEFT';
  width?: number;  // брой grid клетки; default 1
}
export interface OsdmLayoutJson {
  gridSize: OsdmCoords;
  internals: OsdmElement[];
  signs: OsdmElement[];
  aisle?: { y: number };
  compartments?: Array<{ id: string; places: string[] }>;
}
```

---

## Фаза 1 — Пилотна миграция: вагон 21-43

Цел: доказване на end-to-end data-driven flow, без да се счупят другите вагони.

### 1.1 Попълни `osdm_layout_json` за серия 21-43

```sql
-- OSDM-Src/SQLProjects/RailRunServiceSQL/dbo/PostDeployment/Data/004_Coach_Layouts.sql
UPDATE Coach_Layouts
SET osdm_layout_json = '{
  "gridSize": { "x": 24, "y": 4 },
  "internals": [
    { "icon": 115, "coords": { "x": 0,  "y": 0 }, "orientation": "RIGHT" },
    { "icon": 115, "coords": { "x": 23, "y": 0 }, "orientation": "LEFT"  }
  ],
  "signs": [
    { "icon": 135, "coords": { "x": 2,  "y": 0 }, "orientation": "DOWN", "width": 2 },
    { "icon": 135, "coords": { "x": 5,  "y": 0 }, "orientation": "DOWN", "width": 2 },
    { "icon": 179, "coords": { "x": 0,  "y": 2 }, "orientation": "TOP"  },
    { "icon": 179, "coords": { "x": 23, "y": 2 }, "orientation": "TOP"  }
  ],
  "aisle": { "y": 2 }
}'
WHERE wagon_type_id = (SELECT wagon_type_id FROM Wagon_Types WHERE series_name = '21-43');
```

### 1.2 Добави fallback логика в рендерера

```typescript
// OpenSaloonLayout.tsx
// Ако osdm_layout_json има internals/signs → рисувай от тях
// Иначе → стара hardcoded логика (запазена непроменена)

const hasOsdmData = layout.osdmLayoutJson?.internals?.length > 0
                 || layout.osdmLayoutJson?.signs?.length > 0;

if (hasOsdmData) {
  // data-driven path
  renderFromOsdmJson(layout.osdmLayoutJson, OSDM_ICON_MAP);
} else {
  // legacy path — непроменена логика
  renderLegacy(layout);
}
```

### 1.3 Тествай визуализацията на 21-43

- Всички останали вагони → legacy path → непроменени
- 21-43 → data-driven path → валидирай визуално

---

## Фаза 2 — Creation UI

> Започва само след като Фаза 1 е потвърдена.

### 2.1 Нова страница/модал: "Създай вагон тип"

**Форма стъпка 1 — Основни данни:**
- Series name (текст)
- UIC code (текст, незадължително)
- Travel class (dropdown: FIRST / SECOND / BUSINESS / MIXED)
- Default capacity (число)
- Compartment type (dropdown: SALOON / COUPE / SLEEPER / COUCHETTE / EMU / DMU)

**Форма стъпка 2 — Удобства (Amenities):**
- Checkbox list от `Attributes_Dictionary` → записва в `Wagon_Type_Amenities`

**Форма стъпка 3 — Grid размер:**
- Grid width (X) и Grid length (Y) → `Coach_Layouts.grid_width/length`
- Renderer type (auto-select по compartment_type, може да се override)

**Форма стъпка 4 — Seat Map Editor:**
- Интерактивен grid редактор
- Drag & drop или click-to-place елементи от палитра (sedan, WC, маса, коридор...)
- Palette items → OSDM кодове → OSDM_ICON_MAP за визуализация
- Генерира `Seat_Definitions` записи + `osdm_layout_json`

**Форма стъпка 5 — Преглед и запис:**
- Preview на вагона чрез data-driven рендерер (от Фаза 1)
- Валидация: брой дефинирани места == default_capacity
- Запис → `Wagon_Types` + `Coach_Layouts` + `Seat_Definitions` + `Wagon_Type_Amenities`

### 2.2 API endpoints (ако липсват)

```
POST /api/wagon-types              → създай WagonType + CoachLayout
GET  /api/wagon-types              → списък за dropdown
GET  /api/wagon-types/:id/layout   → CoachLayout с seats за preview
POST /api/wagon-types/:id/seats    → bulk insert Seat_Definitions
GET  /api/attributes               → списък amenities за checkbox-ите
```

---

## Фаза 3 — Миграция на останалите вагони

Ред по сложност (от прост към сложен):

| Приоритет | Серия | Тип | Бележка |
|-----------|-------|-----|---------|
| 1 | 21-43 | SALOON | ✅ Пилот (Фаза 1) |
| 2 | 15-63, 25-63 | SALOON | Подобни на 21-43 |
| 3 | 21-45, 84-33 | SALOON | Прости безкупейни |
| 4 | 21-50, 19-40 | COUPE | Купейни |
| 5 | 20-47, 84-80 | COUPE | Купейни |
| 6 | BC кушет | COUCHETTE | 6 легла/кабина |
| 7 | 70-71 | SLEEPER | Спален, сложна бизнес логика |
| 8 | Desiro 31 | EMU | Стълби, нисък/висок под |
| 9 | ДМВ 10 | DMU | Мотриса |

За всеки вагон:
1. Попълни `osdm_layout_json` с коректни `internals`/`signs`
2. Потвърди визуално → data-driven path
3. Премахни данните от hardcoded fallback за този тип

---

## Фаза 4 — Cleanup

Само след като **всички** вагони са мигрирани:

1. Премахни legacy hardcoded пътя от всички рендерери
2. Изтрий `features` JSON колоната от `Wagon_Types` (данните вече са в `Wagon_Type_Amenities`)
3. Обнови тестовете — ~30 теста в `__tests__/` трябва да се актуализират
4. Документирай финалния data формат

---

## Обобщена таблица на всички промени

### Нови файлове

| Файл | Описание |
|------|----------|
| `Admin-App/public/assets/osdm/*.svg` | ~35 SVG икони по OSDM кодове |
| `Admin-App/src/.../constants/osdmIcons.ts` | Registry: код → SVG path + ширина |
| `Admin-App/src/.../types/osdmLayout.types.ts` | TypeScript типове за osdm_layout_json |
| `OSDM-Src/SQLProjects/.../Tables/Wagon_Type_Amenities.sql` | Junction таблица |

### Променени файлове

| Файл | Промяна |
|------|---------|
| `Wagon_Types.sql` | + `uic_code`, обнови `compartment_type` CHECK |
| `Seat_Definitions.sql` | + `LOWER_BED`, `MIDDLE_BED`, `UPPER_BED`, `WINDOW`, `DOOR` в CHECK |
| `002_Attributes_Dictionary.sql` | + PET_TRANSPORT и останалите липсващи |
| `004_Coach_Layouts.sql` | Попълни `osdm_layout_json` за всеки wagon type |
| `005-033_Seat_Definitions_*.sql` | + `POWER_SOCKET` на конкретни места |
| `WagonType.cs` | + `UicCode`, + `Amenities` collection |
| `WagonTypeDto.cs` | `Features` → `AmenityCodes`, + `UicCode` |
| `SeatDefinition.cs` | + константи за нови типове |
| `SqlDbContext.cs` | Many-to-Many конфигурация |
| `seat.types.ts` | + `LOWER_BED`, `MIDDLE_BED`, `UPPER_BED`, `WINDOW`, `DOOR`, `FACE_2_FACE`, `SIDE_BY_SIDE` |
| `composition.types.ts` | `features` → `amenityCodes`, + `uicCode` |
| `coachLayouts.api.ts` | + EMU/DMU mapping, + OsdmLayoutJson parsing |
| `OpenSaloonLayout.tsx` | + data-driven path с fallback |
| `CabinLayout.tsx` | + data-driven path, + LOWER/MIDDLE/UPPER_BED |
| `CompartmentLayout.tsx` | + data-driven path с fallback |
