# Spec: RBAC за Номенклатури и Композиции (Ralph tasks 236–247)

> Прецизна спецификация — всички файлове, редове и snippet-и са проверени. **Не разследвай**, следвай я.
> Пълен наратив: `C:/Users/kaloyan.georgiev/Projects/rbac-nomenclatures-compositions-plan.md`.

## Цел
Менютата/действията за **Номенклатури** (`NOMENCLATURES`) и **Композиции** (`COMPOSITION`) да зависят от
ролите. Frontend: видимост + достъп; Backend: реална авторизация **само на write** операциите.

## Инвариант на нивата (ВАЖНО)
- Frontend enum: `src/api/roles/roles.types.ts` → `AccessLevel { NoAccess=0, ReadOnly=1, CanEdit=2 }`.
- Backend enum: `OSDM-Src/DotNetServices/SharedSrc/Common/Enums/AccessLevel.cs` → `NoAccess/ReadOnly/CanEdit`.
- Ниво за **редакция** = `AccessLevel.CanEdit` (НЕ `ReadWrite` — стари таскове грешат с това име).
- Кодове на ресурси (вече дефинирани, не създавай нови):
  - FE: `src/api/permissions/permissions.types.ts` → `ResourceCodes.Nomenclatures`, `ResourceCodes.Composition`.
  - BE: `SharedSrc/Common/Constants/ResourceCodes.cs` → `ResourceCodes.Nomenclatures` (`"NOMENCLATURES"`), `ResourceCodes.Composition` (`"COMPOSITION"`).
- Тъй като проверката е `userLevel >= required`, една `ReadOnly` проверка покрива „преглед ИЛИ редакция“.

## Решени въпроси
- Composition **GET reads остават ПУБЛИЧНИ** (ползват се от продажби/букинг) — backend гард само на writes.
- `compositions/:id/edit` route = `ReadOnly` (преглед позволен), мутации вътре под `canEdit`.
- `wagons*` е подменю на Композиции → ресурс `COMPOSITION`.
- `SeatsController`/`TripSeatsController` (block/unblock/seat-map) се споделят с продажби → **backend НЕ се пипа**; блокиране на места се ограничава само на FE.

---

## BACKEND

Working dirs:
- RailRun: `C:/Users/kaloyan.georgiev/Projects/OSDM-Src/DotNetServices/RailRunService`
- Nomenclature: `C:/Users/kaloyan.georgiev/Projects/OSDM-Src/DotNetServices/NomenclatureService`

Атрибут (вече съществува): `Common.Authorization.AuthorizePermissionsAttribute`.
Образец за употреба: `PricingService.API/Controllers/AdminTariffVersionController.cs` (GET→ReadOnly, writes→CanEdit).
Нужни usings в контролера: `using Common.Authorization;`, `using Common.Constants;`, `using Common.Enums;`
(сверявай как ги пише образецът; copy exact namespace-ите от него).

### B1. `RailRunService.API/Controllers/CompositionsController.cs`
Сложи **per-action** `[AuthorizePermissions(ResourceCodes.Composition, AccessLevel.CanEdit)]` НАД (write):
- `CreateComposition` (POST, ~64)
- `UpdateComposition` (PUT, ~87)
- `DeleteComposition` (DELETE, ~107)
- `CloneCompositionForPeriod` (POST, ~120)
- `SaveCompositionWagons` (POST, ~143)
- `SetCompositionStatus` (POST, ~185)
- GET-овете (`GetCompositions` ~29, `GetCompositionById` ~55) **остават без атрибут** (публични).

### B2. `RailRunService.API/Controllers/CarriagesController.cs`
- `AddCarriage` (POST, ~33) → `CanEdit`
- `UpdateCarriage` (PUT, ~61) → `CanEdit`
- `GetCarriages` (GET, ~24) → без атрибут.

### B3. `RailRunService.API/Controllers/CoachLayoutsController.cs`
- `CreateCoachLayout` (POST, ~43) → `CanEdit`
- `UpdateCoachLayout` (PUT, ~67) → `CanEdit`
- `SaveSeatDefinitions` (POST, ~87) → `CanEdit`
- `GetBySeriesName` (~26), `GetById` (~35) GET → без атрибут.

> Провери дали `AddCustomAuthorization()` е извикан в `RailRunService.API/Program.cs`. Ако ЛИПСВА — добави
> го (както е в `PricingService.API/Program.cs:143`), иначе `[AuthorizePermissions]` няма да се прилага.

### B4. `NomenclatureService.API/Controllers/NomenclatureController.cs`
- **Публични (БЕЗ гард, ползват се от други модули/клиентски приложения):** `GetGroupTypes` (~52),
  `Get` (~61), `GetMultiple` (~111), `GetAll` (~143), `GetById` (~168) — детайлите на единичен запис се
  четат и от клиенти, затова остават публични (PR review).
- **ReadOnly:** само `GetAllForAdmin` (~74, admin листинг) → `[AuthorizePermissions(ResourceCodes.Nomenclatures, AccessLevel.ReadOnly)]`.
- **CanEdit:** `Create` (POST, ~205), `Update` (PUT, ~282), `Delete` (DELETE, ~373).

> Провери дали `AddCustomAuthorization()` е в `NomenclatureService.API/Program.cs`; export/import контролерите
> вече ползват `[AuthorizePermissions(...)]`, значи най-вероятно е регистрирано — потвърди.

### B5. Backend authorization тестове
По образец на съществуващ auth тест (търси `AuthorizePermissions` в `*.API.Tests`, напр.
`AdminTariff*AuthorizationTests`). Reflection-тест, който проверява, че изброените write actions носят
`[AuthorizePermissions(ResourceCodes.X, AccessLevel.CanEdit)]`, а публичните GET-ове на композиции и
`Get/GetAll/GetMultiple/GetGroupTypes` на номенклатурите **нямат** атрибут.

---

## FRONTEND
Working dir: `C:/Users/kaloyan.georgiev/Projects/Admin-App`. Конвенции: `Admin-App/CLAUDE.md`.

### F1. Permission hooks (образец: `src/app/features/tariffing/hooks/useTariffingPermissions.ts`)
`src/app/features/nomenclatures/hooks/useNomenclaturePermissions.ts`:
```ts
import { usePermissions } from '@/app/shared/hooks/usePermissions';
import { AccessLevel } from '@/api/roles/roles.types';
import { ResourceCodes } from '@/api/permissions/permissions.types';

export function useNomenclaturePermissions() {
  const { getPermissionLevel } = usePermissions();
  const level = getPermissionLevel(ResourceCodes.Nomenclatures);
  return { canRead: level >= AccessLevel.ReadOnly, canEdit: level >= AccessLevel.CanEdit, level };
}
```
`src/app/features/compositions/hooks/useCompositionPermissions.ts` — същото с `ResourceCodes.Composition`.
Експортирай ги от съответния feature `index.ts` ако там се експортират hooks. Unit тестове до файла
(mock `usePermissions` / `authService.getUserPermissions`).

### F2. Меню — `src/app/layout/MainLayout.tsx`
Добави до другите `canSee*` (около ред 110-116):
```ts
const canSeeNomenclatures = hasPermission(ResourceCodes.Nomenclatures, AccessLevel.ReadOnly);
const canSeeCompositions  = hasPermission(ResourceCodes.Composition, AccessLevel.ReadOnly);
```
- **Номенклатури:** направи `bottomMenuItems` условен: `const bottomMenuItems = canSeeNomenclatures ? [ ... ] : [];`
  (дефиницията е ~210-212; рендерът ~444-454 ще е празен при липса).
- **Композиции:** обвий целия блок „заглавие ListItem + `<Collapse>`“ (~455-492) в `{canSeeCompositions && ( ... )}`
  (образец: IASUTD `{showIasutdNavSection && (...)}` ~553-586).

### F3. Route guards — `src/app/routes/router.tsx`
`PermissionGuard` и `ResourceCodes`/`AccessLevel` вече са импортнати (ред 8-10). Замени:
- `nomenclatures/:type?` (~193-195, махни TODO коментара) → обвий `<NomenclaturesPage/>` в
  `<PermissionGuard resourceCode={ResourceCodes.Nomenclatures} requiredLevel={AccessLevel.ReadOnly} redirectTo="/">`.
- Композиции/вагони (~241-272):

| Route | requiredLevel |
|-------|---------------|
| `compositions` | `ReadOnly` |
| `compositions/history` | `ReadOnly` |
| `compositions/wagon-history` | `ReadOnly` |
| `compositions/new` | `CanEdit` |
| `compositions/:id/edit` | `ReadOnly` |
| `wagons` | `ReadOnly` |
| `wagons/new` | `CanEdit` |
| `wagons/:id/edit` | `CanEdit` |

Образец за обвиване: group-trips маршрутите в същия файл (`<PermissionGuard ... redirectTo="/">`).

### F4. Номенклатури — action gating
В `src/app/features/nomenclatures/components/NomenclatureTable.tsx` извикай `useNomenclaturePermissions()`
и под `canEdit` скрий/disable:
- **Add** бутон (~174-180)
- row **Edit** (~266-272)
- row **Delete** (~275-283)

Образец на gating: `NomenclaturesPage.tsx:65` (`{canExport && <Button.../>}`).

### F5. Композиции — action gating (`src/app/features/compositions/`)
Извикай `useCompositionPermissions()` (`canEdit`) и скрий/disable всяка мутираща контрола:
| Файл | Контроли |
|------|----------|
| `pages/CompositionsListPage.tsx` | Create бутон; delete/clone тригери |
| `components/CompositionList.tsx` | row Edit (~152), Clone (~160), Delete (~167) |
| `components/CreateCompositionModal.tsx` | submit/create |
| `components/EditorHeader.tsx` | Save (~335), Clone (~325), Status dropdown (~226), Name edit (~195), Link Trip (~296) |
| `pages/CompositionEditorPage.tsx` | Add Sub-Route |
| `components/WagonPalette.tsx` | drag-add (disable палитрата при !canEdit) |
| `components/WagonPropertiesPanel.tsx` | Save (~114), Delete (~124) |
| `components/SeatActionsToolbar.tsx` | Block (~110), Unblock (~122) |
| `components/BlockSeatDialog.tsx` | Block submit |
| `components/SubRoutesPanel.tsx` | wagon sub-route edit |

> Подавай `canEdit` като prop надолу където компонентът е презентационен (виж как `BaseTariffCrudPage`
> подава `canEdit` към таблиците), за да не вика всеки leaf компонент hook-а.

### F6. Вагони — action gating (`src/app/features/wagons/`)
Под `useCompositionPermissions().canEdit` скрий Create/Edit/Delete контролите в списъка/детайла на вагоните.

### F7. E2E (Playwright, `Admin-App/e2e/`)
Сценарии (реален FE→BE→DB) с три роли (seed чрез UserService — виж reference за grant):
1. Роля **без** `NOMENCLATURES`/`COMPOSITION` → менютата Номенклатури и Композиции **липсват**.
2. Роля само-`ReadOnly` → менютата се **виждат**, но Add/Edit/Delete (номенклатури) и Create/Save/Delete
   (композиции) **липсват/disabled**; директна навигация към `/compositions/new` редиректва към `/`.
3. Роля `CanEdit` → извършва успешно create/edit/delete (номенклатура и композиция).
Добави нужните `data-testid` по бутоните, които тестваш.

---

## Готовност за merge (per екипна конвенция)
Unit/component (Vitest+RTL) **и** Playwright e2e (реален FE→BE→DB) — не само unit. Backend: `dotnet test`.
Lint: `npx eslint <changed-files>` (само branch-introduced грешки). `npm run type-check` зелено.
