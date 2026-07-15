# RailRunService — Database & Seat Layout Guide

How to create wagon seed data that renders correctly in the frontend.

---

## Overview: Data → Visual Pipeline

```
SQL Seed Data (WagonTypes + CoachLayouts + SeatDefinitions)
    ↓
Backend API: GET /api/coach-layouts?seriesName=21-43
    ↓ Returns: { layoutId, gridWidth, gridLength, rendererType, seats[] }
    ↓
Frontend: SeatMapCanvas dispatcher
    ↓ rendererType = "ROWS" → OpenSaloonLayout
    ↓ rendererType = "CABIN" or "COMPARTMENT" → CabinLayout
    ↓
CSS Grid rendering at GRID_UNIT = 22px per coordinate unit
```

---

## Tables & Relationships

```
WagonTypes 1──M CoachLayouts 1──M SeatDefinitions
                                       │
                                       ↓ (runtime)
CompositionCarriages ──M SeatAvailability M──1 SeatDefinitions
         │
         ├──M BlockedSeats
         └──M SeatAuditLog
```

---

## 1. WagonTypes

Defines a wagon series (e.g. "21-43", "70-71").

```sql
INSERT INTO WagonTypes (SeriesName, TravelClass, DefaultCapacity, CompartmentType, Features, ManufacturerCode)
VALUES ('21-43', 'SECOND', 83, 'SALOON', '["TABLE","MIDDLE_DOORS","AISLE"]', 'B-2143');
```

| Column | Type | Values |
|--------|------|--------|
| SeriesName | VARCHAR(50) | "21-43", "15-63", "70-71", "19-40", etc. |
| TravelClass | VARCHAR(10) | `FIRST`, `SECOND` |
| DefaultCapacity | INT | Actual seat count (excluding non-physical) |
| CompartmentType | VARCHAR(15) | `SALOON`, `COUPE`, `SLEEPER`, `COUCHETTE` |
| Features | NVARCHAR(MAX) | JSON array of wagon features |
| ManufacturerCode | VARCHAR(50) | Internal code |

### Existing Wagon Types (28 total)

| Series | Class | Capacity | Type | Description |
|--------|-------|----------|------|-------------|
| 21-43 | SECOND | 83 | SALOON | Безкупеен II клас, маси, средни врати |
| 15-63 | FIRST | 58 | SALOON | Безкупеен I клас, 2+1 подредба |
| 70-71 | FIRST | 30 | SLEEPER | Спален WLAB, 10 кабини × 3 легла |
| 19-40 | FIRST | 54 | COUPE | Купеен I клас, 9 купета × 6 места |
| 21-50 | SECOND | 66 | COUPE | Купеен II клас, 11 купета × 6 места |
| 20-47 | SECOND | 80 | COUPE | Купеен II клас, 10 купета × 8 места |
| 30-40 | FIRST | 60 | COUPE | Купеен I клас |
| 29-74 | SECOND | 72 | COUPE | Купеен II клас |
| 25-63 | SECOND | 78 | SALOON | Безкупеен II клас |
| 31-1-4 | SECOND | 58 | SALOON | Desiro EMU (мотриса), клима, ниско |
| 31-2-3 | SECOND | 64 | SALOON | Desiro EMU вагон |
| 10 | SECOND | 120 | SALOON | DMV локомотив-вагон, смесен клас |
| BC | SECOND | 54 | COUCHETTE | Кушет, 9 купета × 6 кушетки |
| WLAB-UIC | FIRST | 30 | SLEEPER | Спален UIC стандарт |
| 76 | SECOND | 30 | SALOON | Теснолинейка |
| 84-44 | SECOND | 65 | SALOON | ТПЛ (инвалидни места) |
| 84-80 | FIRST | 22 | COUPE | ТПЛ I клас, инвалидни, велосипеди |
| 84-33 | SECOND | 11 | SALOON | ТПЛ салон, велосипеди |
| 85-97 | FIRST | 18 | SALOON | Бистро/ресторант |

---

## 2. CoachLayouts

Defines the grid dimensions and renderer for a wagon type.

```sql
INSERT INTO CoachLayouts (WagonTypeId, GridWidth, GridLength, DeckCount, RendererType, OsdmLayoutJson)
VALUES (@wagonTypeId, 72, 14, 1, 'ROWS', '{}');
```

| Column | Type | Purpose |
|--------|------|---------|
| WagonTypeId | BIGINT FK | Which wagon series |
| GridWidth | INT | Horizontal grid units (X axis range) |
| GridLength | INT | Vertical grid units (Y axis range) |
| DeckCount | INT | 1 = single deck, 2 = double |
| RendererType | VARCHAR(20) | **`ROWS`** or **`CABIN`** or **`COMPARTMENT`** |
| OsdmLayoutJson | NVARCHAR(MAX) | Reserved for OSDM JSON (currently `{}`) |

### RendererType → Frontend Component

| RendererType | Frontend Component | Used For |
|--------------|-------------------|----------|
| `ROWS` | OpenSaloonLayout | Безкупейни (21-43, 15-63, 25-63, EMU) |
| `CABIN` | CabinLayout (sleeper mode) | Спални (70-71, WLAB-UIC) |
| `COMPARTMENT` | CabinLayout (compartment mode) | Купейни (19-40, 21-50, 20-47, 30-40) |

### Grid Dimensions by Series

| Series | GridWidth | GridLength | RendererType | Notes |
|--------|-----------|------------|--------------|-------|
| 21-43 | 72 | 14 | ROWS | 10 групи × ~7 колони + стени + врати |
| 15-63 | 40 | 10 | ROWS | 10 групи × 4 колони (2+1) |
| 70-71 | 24 | 10 | CABIN | 10 кабини × 2 колони |
| 19-40 | 56 | 10 | COMPARTMENT | 9 купета × 6 колони |
| 21-50 | 68 | 10 | COMPARTMENT | 11 купета × 6 колони |

---

## 3. SeatDefinitions

Every element in the wagon layout — seats, tables, walls, corridors, zones.

```sql
INSERT INTO SeatDefinitions (LayoutId, SeatNumber, GridX, GridY, AccommodationType, Attributes, IsPhysicallyPresent)
VALUES (@layoutId, '42', 5, 8, 'SEAT', '["WINDOW","FACING_LEFT"]', 1);
```

| Column | Type | Purpose |
|--------|------|---------|
| LayoutId | BIGINT FK | Which CoachLayout |
| SeatNumber | VARCHAR(10) | Human label: "42", "T15", "WC_1", "W1" |
| GridX | INT | Horizontal position (0-based) |
| GridY | INT | Vertical position (0-based) |
| AccommodationType | VARCHAR(20) | Element type (see below) |
| Attributes | NVARCHAR(MAX) | JSON array of properties |
| IsPhysicallyPresent | BIT | 1 = real element, 0 = placeholder/missing |

---

## 4. AccommodationType — All Element Types

### Actual Seats (interactive, clickable)

| Type | Visual | Description |
|------|--------|-------------|
| `SEAT` | 40×40px green box | Regular passenger seat |
| `FOLDING_SEAT` | 28×28px dashed blue | Клапа (fold-down extra seat) |
| `BERTH` | 40×40px | Легло в спален вагон |
| `COUCHETTE` | 40×40px | Кушетка |
| `WHEELCHAIR_SPACE` | 40×40px solid blue border | Инвалидно място |
| `COMPANION` | 40×40px orange | Придружител до инвалидно |

### Structural Elements (non-interactive)

| Type | Visual | Description |
|------|--------|-------------|
| `TABLE` | 26×40px brown | Малка маса между места |
| `BIG_TABLE` | 40×(3 rows) brown | Голяма маса |
| `PLACEHOLDER` | Invisible spacer | Запазва grid позиция, не се рендерира |
| `WALL` | 4px вертикална линия | Стена/преграда между секции |
| `WALL_H` | Хоризонтална граница | Долна граница на клетка |
| `WC` | Labeled zone box | Тоалетна (spans multiple cells) |
| `GAP` | 16px празнина | Разделител между групи |
| `ZONE` | Side panel с текст | WC/коридор/врата зона до grid-а |
| `GRID_LABEL` | Overlay текст в grid-а | Етикет (инвалидни, клапи) |
| `CORRIDOR` | Сива линия | Маркер за позицията на коридора |
| `STAIRS` | Дървена текстура | Стъпало (EMU мотриса) |

---

## 5. Attributes JSON — What Properties Mean

### Seat Properties

| Attribute | Meaning | Visual Effect |
|-----------|---------|---------------|
| `WINDOW` | До прозореца | — |
| `AISLE` | До пътеката | — |
| `FACING_LEFT` | Гърбът е вдясно (гледа наляво) | Облегалка вдясно |
| `FACING_RIGHT` | Гърбът е наляво (гледа надясно) | Облегалка наляво |
| `FACING_UP` | Гърбът е долу | Облегалка долу |
| `FACING_DOWN` | Гърбът е горе | Облегалка горе |
| `FIRST_CLASS` | Първи клас | Златист фон (#FFF8E1) |
| `TABLE` | Има маса | — |
| `QUIET_ZONE` | Тиха зона | — |
| `POWER_SOCKET` | Контакт 220V | — |
| `SECOND_CLASS` | Втори клас | — |

### Berth Properties (sleeper/couchette)

| Attribute | Meaning |
|-----------|---------|
| `UPPER_BED` | Горно легло |
| `MIDDLE_BED` | Средно легло |
| `LOWER_BED` | Долно легло |

### PLACEHOLDER Properties

| Attribute | Meaning | Example |
|-----------|---------|---------|
| `PH_W:20` | Width in pixels | `["PH_W:20","PH_H:40"]` |
| `PH_H:40` | Height in pixels | |

### WC/ZONE Properties

| Attribute | Meaning | Example |
|-----------|---------|---------|
| `ROW_SPAN:3` | Spans 3 rows | WC cell |
| `COL_SPAN:2` | Spans 2 columns | Large WC |
| `LABEL:WC` | Display text (BG) | Zone panel |
| `LABEL_EN:Toilet` | Display text (EN) | Zone panel |
| `WIDTH:40` | Panel width | Zone panel |
| `SIDE:LEFT` or `SIDE:RIGHT` | Panel position | Zone panel |
| `ZONE_STYLE:service` | Color scheme | service/corridor/door |

### WALL Properties

| Attribute | Meaning | Example |
|-----------|---------|---------|
| `WALL_MOD_TYPE:door` | Has door opening | Wall with door |
| `WALL_MOD_TYPE:hide` | Wall hidden at row | Wall modification |
| `WALL_MOD_GRID_Y:5` | Row where mod applies | |

### GRID_LABEL Properties

| Attribute | Meaning | Example |
|-----------|---------|---------|
| `COLUMNS:2,3,4` | Grid columns covered | `["COLUMNS:2,3,4","GRID_Y:0","LABEL:♿","TYPE:wheelchair"]` |
| `GRID_Y:0` | Row position | |
| `LABEL:♿` | Display text | |
| `TYPE:wheelchair` | Label type | wheelchair/folding/corridor/info |
| `FOLDING_COUNT:5` | Number of folding seats | |
| `ROW_SPAN:1` | Height in rows | |

### WALL_H Properties

| Attribute | Meaning |
|-----------|---------|
| `TO_X:15` | Horizontal border extends to column 15 |

---

## 6. Grid Coordinate System

### How GridX/GridY Map to Pixels

```
Frontend pixel = LAYOUT_PADDING + gridValue × GRID_UNIT
               = 20 + gridValue × 22

Example: GridX=5, GridY=3
  → x = 20 + 5×22 = 130px
  → y = 20 + 3×22 = 86px
```

### Orientation

```
GridX → horizontal (left to right along the wagon length)
GridY → vertical (top to bottom across the wagon width)

   GridY=0 ──── window side (top)
   GridY=2 ──── seat row
   GridY=4 ──── seat row
   GridY=6 ──── CORRIDOR
   GridY=8 ──── seat row
   GridY=10 ─── seat row
   GridY=12 ─── window side (bottom)
```

### Facing Direction (OSDM standard — absolute, NOT relative to travel)

```
FACING_RIGHT → backrest is on LEFT, passenger faces RIGHT (→ higher X)
FACING_LEFT  → backrest is on RIGHT, passenger faces LEFT (← lower X)
```

---

## 7. Layout Patterns by Wagon Type

### SALOON / ROWS — Безкупеен (21-43, 15-63)

**Structure**: Groups of seats separated by walls/gaps. Corridor runs horizontally.

```
  Group 10        Wall    Group 20        Wall    Group 30
  ┌─────────┐     │     ┌─────────┐     │     ┌─────────┐
  │15 T 16  │     │     │25 T 26  │     │     │35   36  │
  │17   14  │     │     │23   24  │     │     │33   34  │
  │═════════│ corridor  │═════════│ corridor  │═════════│
  │13   18  │     │     │21 T 22  │     │     │31   38  │
  │11 T 12  │     │     │         │     │     │         │
  └─────────┘     │     └─────────┘     │     └─────────┘
```

**Column breakdown per group** (21-43):
- 2 seat columns (left/right of table)
- 1 table column (between seats, or placeholder if no table)
- Seats use FACING_RIGHT (top half) and FACING_LEFT (bottom half) for vis-à-vis

**Corridor**: Explicit CORRIDOR entry at fixed GridY, or auto-detected from largest Y gap.

**Example group seed** (Group 10 of 21-43):
```sql
-- Window seats with table (top, above corridor)
INSERT INTO SeatDefinitions VALUES (@lid, '15', 2, 2, 'SEAT', '["WINDOW","TABLE","FACING_RIGHT"]', 1);
INSERT INTO SeatDefinitions VALUES (@lid, 'T15', 4, 2, 'TABLE', NULL, 1);
INSERT INTO SeatDefinitions VALUES (@lid, '16', 5, 2, 'SEAT', '["WINDOW","TABLE","FACING_LEFT"]', 1);
-- Aisle seats (top)
INSERT INTO SeatDefinitions VALUES (@lid, '17', 2, 4, 'SEAT', '["AISLE","FACING_RIGHT"]', 1);
INSERT INTO SeatDefinitions VALUES (@lid, '14', 5, 4, 'SEAT', '["AISLE","FACING_LEFT"]', 1);
-- Corridor
INSERT INTO SeatDefinitions VALUES (@lid, 'CORR', 0, 6, 'CORRIDOR', '["CORRIDOR_MARKER"]', 0);
-- Aisle seats (bottom)
INSERT INTO SeatDefinitions VALUES (@lid, '13', 2, 8, 'SEAT', '["AISLE","FACING_RIGHT"]', 1);
INSERT INTO SeatDefinitions VALUES (@lid, '18', 5, 8, 'SEAT', '["AISLE","FACING_RIGHT"]', 1);
-- Window seats with table (bottom, below corridor)
INSERT INTO SeatDefinitions VALUES (@lid, '11', 2, 10, 'SEAT', '["WINDOW","TABLE","FACING_RIGHT"]', 1);
INSERT INTO SeatDefinitions VALUES (@lid, 'T11', 4, 10, 'TABLE', NULL, 1);
INSERT INTO SeatDefinitions VALUES (@lid, '12', 5, 10, 'SEAT', '["WINDOW","TABLE","FACING_RIGHT"]', 1);
```

**Walls between groups**:
```sql
INSERT INTO SeatDefinitions VALUES (@lid, 'W1', 7, 0, 'WALL', NULL, 0);
```

**Vestibule doors** (middle doors on 21-43):
```sql
-- Walls at vestibule X positions + WALL_MOD for door openings
INSERT INTO SeatDefinitions VALUES (@lid, 'WV1', 18, 0, 'WALL', '["WALL_MOD_TYPE:door","WALL_MOD_GRID_Y:4"]', 0);
```

### 15-63 First Class — Same ROWS pattern but 2+1 seating

- 3 columns per group instead of 4 (2 seats + 1 seat across aisle)
- FIRST_CLASS attribute on all seats
- Golden styling in frontend

---

### SLEEPER / CABIN — Спален (70-71)

**Structure**: 10 cabins, each with 3 berths (upper/middle/lower).

```
  Cabin 1    Cabin 2    Cabin 3   ...
  ┌──────┐  ┌──────┐  ┌──────┐
  │ 13 U │  │ 23 U │  │ 33 U │   U = upper berth
  │ 12 M │  │ 22 M │  │ 32 M │   M = middle berth
  │ 11 L │  │ 21 L │  │ 31 L │   L = lower berth
  └──────┘  └──────┘  └──────┘
```

**Numbering**: Cabin N → seats N1 (lower), N2 (middle), N3 (upper).

**Example seed**:
```sql
-- Cabin 1
INSERT INTO SeatDefinitions VALUES (@lid, '11', 2, 6, 'BERTH', '["LOWER_BED","WINDOW"]', 1);
INSERT INTO SeatDefinitions VALUES (@lid, '12', 2, 4, 'BERTH', '["MIDDLE_BED","WINDOW"]', 1);
INSERT INTO SeatDefinitions VALUES (@lid, '13', 2, 2, 'BERTH', '["UPPER_BED","WINDOW"]', 1);
-- Cabin 2
INSERT INTO SeatDefinitions VALUES (@lid, '21', 5, 6, 'BERTH', '["LOWER_BED","WINDOW"]', 1);
INSERT INTO SeatDefinitions VALUES (@lid, '22', 5, 4, 'BERTH', '["MIDDLE_BED","WINDOW"]', 1);
INSERT INTO SeatDefinitions VALUES (@lid, '23', 5, 2, 'BERTH', '["UPPER_BED","WINDOW"]', 1);
-- ... Cabins 3-10

-- Service zones
INSERT INTO SeatDefinitions VALUES (@lid, 'ZN-WC', 0, 0, 'ZONE', '["LABEL:WC","LABEL_EN:Toilet","WIDTH:40","SIDE:LEFT","ZONE_STYLE:service"]', 0);
INSERT INTO SeatDefinitions VALUES (@lid, 'ZN-CORR', 0, 4, 'ZONE', '["LABEL:Коридор","LABEL_EN:Corridor","WIDTH:40","SIDE:LEFT","ZONE_STYLE:corridor"]', 0);
```

---

### COMPARTMENT — Купеен (19-40, 21-50)

**Structure**: N compartments, each with 6 seats (3 per side, face-to-face).

```
  Comp 1         Wall    Comp 2         Wall    Comp 3
  ┌─────────┐    │      ┌─────────┐    │      ┌─────────┐
  │15 PH 16 │    │      │25 PH 26 │    │      │35 PH 36 │  window
  │13    14 │    │      │23    24 │    │      │33    34 │  middle
  │11    12 │    │      │21    22 │    │      │31    32 │  aisle
  └─────────┘    │      └─────────┘    │      └─────────┘
```

**Column layout per compartment**: 5 grid units — left(2) + PH(1) + right(2), then 1 unit WALL.

**Numbering**: Compartment N → seats N1-N6 (left side 1,3,5 / right side 2,4,6).

**Example seed**:
```sql
-- Compartment 1 (GridX starts at 2)
INSERT INTO SeatDefinitions VALUES (@lid, '15', 2, 2, 'SEAT', '["WINDOW","COMPARTMENT","FACING_RIGHT"]', 1);
INSERT INTO SeatDefinitions VALUES (@lid, 'PH4', 4, 2, 'PLACEHOLDER', NULL, 0);
INSERT INTO SeatDefinitions VALUES (@lid, '16', 5, 2, 'SEAT', '["WINDOW","COMPARTMENT","FACING_LEFT"]', 1);
INSERT INTO SeatDefinitions VALUES (@lid, '13', 2, 4, 'SEAT', '["MIDDLE","COMPARTMENT","FACING_RIGHT"]', 1);
INSERT INTO SeatDefinitions VALUES (@lid, '14', 5, 4, 'SEAT', '["MIDDLE","COMPARTMENT","FACING_LEFT"]', 1);
INSERT INTO SeatDefinitions VALUES (@lid, '11', 2, 6, 'SEAT', '["AISLE","COMPARTMENT","FACING_RIGHT"]', 1);
INSERT INTO SeatDefinitions VALUES (@lid, '12', 5, 6, 'SEAT', '["AISLE","COMPARTMENT","FACING_LEFT"]', 1);
-- Wall after compartment 1
INSERT INTO SeatDefinitions VALUES (@lid, 'W7', 7, 0, 'WALL', NULL, 0);

-- Compartment 2 (GridX starts at 8)
INSERT INTO SeatDefinitions VALUES (@lid, '25', 8, 2, 'SEAT', '["WINDOW","COMPARTMENT","FACING_RIGHT"]', 1);
-- ... etc
```

---

## 8. Checklist: Creating a New Wagon Layout

### Step 1: Add WagonType
```sql
INSERT INTO WagonTypes (SeriesName, TravelClass, DefaultCapacity, CompartmentType, Features, ManufacturerCode)
VALUES ('XX-YY', 'SECOND', 72, 'SALOON', '["TABLE","AC"]', 'B-XXYY');
```

### Step 2: Add CoachLayout
Decide RendererType:
- Безкупеен → `ROWS`
- Купеен → `COMPARTMENT`
- Спален → `CABIN`

```sql
DECLARE @wtId BIGINT = (SELECT Id FROM WagonTypes WHERE SeriesName = 'XX-YY');
INSERT INTO CoachLayouts (WagonTypeId, GridWidth, GridLength, DeckCount, RendererType, OsdmLayoutJson)
VALUES (@wtId, 72, 14, 1, 'ROWS', '{}');
```

### Step 3: Add SeatDefinitions

For each element:
1. **Real seats**: `IsPhysicallyPresent = 1`, AccommodationType = `SEAT`/`BERTH`/`COUCHETTE`
2. **Tables**: `IsPhysicallyPresent = 1`, AccommodationType = `TABLE`
3. **Walls**: `IsPhysicallyPresent = 0`, AccommodationType = `WALL`
4. **Placeholders**: `IsPhysicallyPresent = 0`, AccommodationType = `PLACEHOLDER`
5. **Corridor marker**: `IsPhysicallyPresent = 0`, AccommodationType = `CORRIDOR`
6. **Zones**: `IsPhysicallyPresent = 0`, AccommodationType = `ZONE`

### Step 4: Verify

1. `DefaultCapacity` in WagonType = count of seats where `IsPhysicallyPresent = 1` and type is `SEAT`/`BERTH`/`COUCHETTE`/`WHEELCHAIR_SPACE`
2. All GridX values within [0, GridWidth)
3. All GridY values within [0, GridLength)
4. One `CORRIDOR` entry exists (for ROWS renderer) or corridor auto-detected from Y gaps
5. Walls placed at correct X positions between seat groups
6. Each seat has valid facing direction attribute

---

## 9. Frontend Color Scheme

### Seat Status Colors

| Status | Background | Border |
|--------|-----------|--------|
| AVAILABLE | #E8F5E9 | #43A047 |
| BOOKED | #EF9A9A | #D32F2F |
| BLOCKED | #BDBDBD | #757575 |
| LOCKED | #BBDEFB | #1565C0 |

### Element Type Colors

| Type | Background | Border |
|------|-----------|--------|
| FIRST_CLASS seat | #FFF8E1 | #F9A825 (gold) |
| FOLDING_SEAT | #E3F2FD | #1565C0 (dashed) |
| WHEELCHAIR_SPACE | #BBDEFB | #1565C0 (2px solid) |
| COMPANION | #FFF3E0 | #E65100 (orange) |
| TABLE / BIG_TABLE | #EFEBE9 | #8D6E63 (brown) |
| WC | #f5f5f5 | #BDBDBD |
| CORRIDOR | #f5f5f5 | — |
| STAIRS | #EFEBE9 | — |

---

## 10. AttributesDictionary

Wagon-level features (not seat-level):

| Code | BG | EN | OSDM Mapping |
|------|----|----|--------------|
| WIFI | Wi-Fi Интернет | WiFi Available | WIFI_OFFERED |
| AC | Климатик | Air conditioning | AIR_CONDITIONED |
| SILENCE | Тиха зона | Silence Area | SILENCE_COMPARTMENT |
| BISTRO | Бистро/Ресторант | Bistro/Restaurant | BISTRO |
| WHEELCHAIR | Място за инвалиди | Wheelchair space | WHEELCHAIR_SPACE |
| POWER_SOCKET | Контакт 220V | Power socket | POWER_SUPPLY |
| BIKE | Превоз на велосипеди | Bicycle transport | BICYCLE_TRANSPORT |

---

## 11. SQL File Locations

| Content | Path |
|---------|------|
| Table definitions | `OSDM-Src/SQLProjects/RailRunServiceSQL/dbo/Tables/` |
| Seed data | `OSDM-Src/SQLProjects/RailRunServiceSQL/dbo/PostDeployment/Data/` |
| EF Configurations | `OSDM-Src/DotNetServices/RailRunService/RailRunService.Infrastructure/Data/Configurations/` |
| EF Migrations | `OSDM-Src/DotNetServices/RailRunService/RailRunService.Infrastructure/Migrations/` |
| Backup seed SQL | `.ralph_composition/.ralph/.ralph/seed-data-wagon-*.sql` |

---

## 12. Quick Reference: Seat Numbering Conventions

| Pattern | Meaning | Example |
|---------|---------|---------|
| 11-18 | Group 10 seats | 21-43 безкупеен |
| 21-28 | Group 20 seats | |
| N1-N6 | Compartment N (6-seat) | 19-40 купеен |
| N1-N8 | Compartment N (8-seat) | 20-47 купеен |
| N1-N3 | Cabin N berths (low/mid/up) | 70-71 спален |
| T15 | Table near seat 15 | All saloon wagons |
| W1, W7 | Wall number | Dividers |
| PH4, PA17 | Placeholder | Grid spacers |
| CORR | Corridor marker | Position marker |
| ZN-WC | Zone: WC | Side panel |
| WC_1 | WC element in grid | Grid cell |
