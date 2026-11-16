# rwclab: разузнаване за board 5 — орязване на RoC (смоли, принтери, слоеве, appliance profiles)

_16.11.2026, след board 4. Решение на потребителя (15–16.11): няма да има интеграция с принтери → смолите и принтерите (4-те RoC платформи 55/95/55S/95S) не трябват; „платформата" става обикновена работна плоча; плочи за FDM/SLA принтери са отделна, далечна тема. Условие на потребителя: НЕ „махни всеки излаз към RoC и половината полета остават неактивни, защото трябва избрана смола" — първо картата на гейтинга, после орязване, което оставя формата валидна и рендерера работещ. Пътищата по-долу са относителни към `app/frontend/src/app/` (FE), `app/backend/` (BE) и корена на репото (worker/infra/gates)._

## 0. Изводите в десет реда

1. **Във FE има два гейта за валидност и двата искат смола + слой + принтер.** (а) Template формата `#applianceForm` (`platform-print-setup.component.html:4`) → **NEXT: UPLOAD FILES** (`:271 [disabled]="!applianceForm.valid"`) и **IMPORT** (`:276`). (б) ngrx селекторът `getArePrintSettingsValid` (`core/store/states/print-list.states.ts:136-159`: `treatmentTypeId && applianceType ∈ enum && resinId && layerThicknessId && printerPlatformId && hasValidOrientation`) → Save (`platform-setup.component.html:146`), Save Print Job / Send to Printer (`platform-setup.component.ts:392-409`), **смяната на табовете** (`:411-417`) и избор на модел в рендерера при dirty настройки (`:347-353`).
2. `[disabled]` на custom контролите е plain `@Input` (`shared/components/forms/f-base.component.ts:17`) — НЕ изключва form control-а, т.е. „disabled" required поле пак прави формата невалидна. Затова днешната картина: празен Material → Next сив.
3. **Три места хвърлят TypeError при празни списъци**, не само деактивират: `selectDefaultProfile` (PPS.ts:912-922, `profile.id` при липсващ default appliance profile — това беше #4400), `initApplianceProfile` (PPS.ts:608-645, `.find(...).printerTypeId` при празен `last-appliance-platforms`, после `selectedApplianceProfile.profile.*`), `treatmentTypeSelected` (PPS.ts:863, `filteredApplianceTypes[0].id`). Плюс `BP.platformTypes` (`base-platform.component.ts:207-214`) при `null` от reducer-а и `searchResins`/`layerThicknesses$` при принтер id извън enum-а (`PrinterPlatform[id].toLowerCase()`).
4. **Има код, който ТРИЕ стойности при всеки update на модела**: `handleMissingResin` (PPS.ts:1234-1241, викан от :353 и :529) нулира `resinId`, ако не минава `searchResins`; `selectDefaultPlatformType` (:890-894) нулира принтера; `selectRecommendedThickness` (:896-910) нулира слоя. Всеки seed, който не минава филтрите, се изтрива пак → половинчато „оставяме данните, махаме RoC" не работи.
5. **Геометрията на плочата във FE има ЕДИН източник**: таблицата `getPlatformPrinterTypeDetailByPlatformSize` (`core/helpers/common/platform-printer-type-helper.ts:134-165`): Size55 = 105.6×59.4 mm (`assets/models/p55-top/bottom.drc`), **Size95/default = 182.4×102.6 mm (`p95-*.drc`)**, CrownKit 34×52, ArchKit55/95. Всички помощници (`getPlatformSize*`, `getPrinterPlatformId`) падат по подразбиране на **Size95**, така че рендерерът работи и без принтер; двата входа, които го местят, са `currentPlatformJobModel.printerPlatformId` (`renderer.component.ts:554/566`) и `printDetails.printerModel` от метаданните (`:859`).
6. **Извън приложението RoC само минава транзитно**: worker-ът записва `LayerThickness/ResinName/PrinterModel/PrinterPlatformId` като низове в реда на платформата (`workers/algorithms/src/platform-process-logic.mjs:32-44`), нищо не смята от тях; `gridLayout` (`:54-71`) няма граници на плочата; `platformSize: "Size55"` е в FIFO съобщението, но никой не го чете; callback-bridge няма нито едно съвпадение; compose/env нямат RoC.
7. Гейтовете кодират RoC на 4 места: `lab-pipeline.mjs:249-252, 264-267` (`GET rwc-resin` → `resinId`, `printerPlatformId 1`, `layerThicknessId 1`), `:334-342` (`printDetails.printerModel === 'pro55'` твърд FAIL), `lab-ui.mjs:325-367` (принтер бутон, Material с Enter, слой), `be-smoke.mjs:47-75` (стартовият списък: `rwc-resin`, `ds-resin`, `layer-thickness`, `printer-type`, `printer-platform`, `printer/all`, `appliance-profile`, `last-appliance-platforms`).
8. Edit пътят (`POST platform-job/{id}/edit`, `core/utils/platform-job-utils.ts:5-36`) **не носи RoC полета** — трансформации, supports, cut, annotation. Орязването не го пипа.
9. `treatment-type` (job type / appliance type) НЕ е RoC, но е задължителна зависимост на формата (`treatmentTypeId` required, appliance type за два типа). Остава до денталното орязване на FE (board 6+), освен ако не се реши формата да падне до име + upload.
10. Fit offset (`sliceOffset`, -250…250 µm, „Expert guidance required") не е гейт; `sliceOffset` е 0 по подразбиране — маха се безопасно.

## 1. FE: контроли и бутони, гейтвани от RoC данни

PPS = `app-modules/delta/components/platform-print-setup/platform-print-setup.component`, PS = `.../platform-setup/platform-setup.component`, BP = `.../base-platform/base-platform.component.ts`, R = `.../renderer/renderer.component`.

| Файл:ред | Символ | Условие / роля | Какво се чупи при празен източник |
|---|---|---|---|
| PPS.html:191-193 | `f-button-group name="platformType"` → `model.printerPlatformId` | `[required]="true"`, `[source]="filterPlatformTypes"` | Няма бутони → `printerPlatformId` null → **формата невалидна** |
| PPS.ts:1187-1202 | `get filterPlatformTypes` | от `platformTypes`; при избрана смола маркира платформа disabled по `resin.p55s/p55/p95s/p95.length` (:1243-1259); `PrintersOrigin.Registered` → само `registeredPrinterIds` | Празен списък при празни printer-platform list-options |
| BP:207-214 | `get platformTypes` | `allPlatformTypes.filter(p => … p.parentId === treatmentTypeId && p.treatmentApplianceType === applianceType …)` | `allPlatformTypes` от `printerTypeSelectors.getPrinterPlatformTypesListOptions` (BP:165-176); reducer-ът (`printer-type.reducers.ts:20`) дава `null` при null payload → `.filter` **хвърля** |
| PPS.ts:890-894 | `selectDefaultPlatformType` | нулира `printerPlatformId`, ако не е в `filterPlatformTypes` и enabled | Трие принтера при празен списък / несъвместима смола |
| PPS.html:213-216 | `f-button-group name="crownPlatform"` → `printerPlatformType` | `*ngIf="isTypeS && filterPlatformOptions.length > 1"`, required | Скрит без P55S/P95S |
| PPS.html:220-222 | `f-autocomplete-v2 name="resin"` → `model.resinId` | `[required]="true"`, `[search]="searchResins"` | **Формата невалидна** |
| PPS.ts:750-755 | `searchResins` | `allResins.filter(r => term && model.printerPlatformId && r[PrinterPlatform[pid].toLowerCase()]?.length > 0 && (platformType !== CrownKit \|\| r.forCrownKit))` | Нищо без принтер; id извън enum → хвърля |
| PPS.ts:1234-1241 | `handleMissingResin` | нулира `resinId`, ако не е в `searchResins('')`, dispatch `SetCurrentPlatformJobModel` | **Трие всеки seed-нат resinId** при всеки update (:353, :529) |
| PPS.html:224-226 | `f-select name="layerThickness"` → `layerThicknessId` | `[required]`, `[disabled]="!model.resinId"`, `[source]="layerThicknesses$"` | **Формата невалидна** |
| PPS.ts:703-721 | `get layerThicknesses$` | `combineLatest(allResins$, allLayerThicknesses$)`; без смола/принтер → `[]`; иначе `thicknesses.filter(t => res[PrinterPlatform[pid].toLowerCase()].includes(getLayerThicknessRoC(t.id)))` | Празен списък |
| PPS.ts:896-910 | `selectRecommendedThickness` | профилният `layerThicknessId`, иначе единствения, иначе null | Нулира слоя |
| PPS.ts:883-888 | `selectDefaultMaterial` | `resinId = selectedApplianceProfile?.profile.resinId` → `selectDefaultPlatformType()` → `selectRecommendedThickness()` | Без профил: трите стават null |
| PPS.html:41-53 | `f-select name="applianceProfile"` → `profileId` | `[hidden]="!applianceProfileFeatureFlag"`, не е required | не е гейт |
| PPS.html:55-64, PPS.ts:1102-1157 | профилни бутони / `saveProfile` | `*ngIf="haveProfileSettingsChanged"`; `saveProfile` чете `defaultProfile.profile.supportSettings` (:1127) | хвърля без default профил |
| **PPS.ts:912-922** | **`selectDefaultProfile`** | `profile = lastUsedProfile \|\| defaultProfile; model.profileId = profile.id` | **хвърля** без default профил за appliance type (#4400); викан от `setCurrentApplianceProfile` (:688-697) при всяка смяна на job/appliance type, от `onModelUpdated`, profile-list subscription (:249-251), `processModelChanges` (:945-947) |
| **PPS.ts:608-645** | **`initApplianceProfile`** | `lastUsedAppliancePlatforms.find(ap => ap.applianceType === …).printerTypeId` (:620), после `selectedApplianceProfile.profile.*` (:625-642) | **хвърля** при празен `last-appliance-platforms` или без профил; източник на printer id/type (:622-623) и на всички `parameters.*` дефолти + `sliceOffset` |
| PPS.html:27-37 | `print-job-type` → `treatmentTypeId` (required), `treatmentApplianceType` (required за RemovableDentures/CrownAndBridge) | `treatmentTypes$` (PPS.ts:224-237), `filteredApplianceTypes` (:789-800) | **Формата невалидна** без job type (не е RoC) |
| PPS.ts:844-881 | `treatmentTypeSelected` | задава appliance type по job type, иначе `filteredApplianceTypes[0].id` (:863) → `setCurrentApplianceProfile` → `initApplianceProfile` → `selectDefaultMaterial` | хвърля при празен списък; веригата от т.3 тръгва при избор на job type |
| PPS.html:146, PPS.ts:999-1001 | `autoLayoutType` (template layout) | само при `isSize95` | скрит без P95 |
| PPS.html:229-249, PPS.ts:1159-1177 | Fit offset (`f-number-slider name="fitOffset"` → `sliceOffset`), `showExpertGuidance` | не е required; стъпки от `core/constants/support-settings.ts:30` | не е гейт; маха се |
| PPS.html:181-189 | чипове All / My printers | `registerSelectors.getRegisteredPrintersListOptions` (PPS.ts:384-397) | козметика |
| **PPS.html:271** | **NEXT: UPLOAD FILES** | `[disabled]="!applianceForm.valid"` | невалидна при празно: job type, appliance type (ако се показва), **platformType, resin, layerThickness**, crownPlatform (при isTypeS), orientation/isModelAligner за техните типове |
| **PPS.html:276**, PPS.ts:422, :531 | **IMPORT (SPR)**, `isSprImportFull` | `!applianceForm.valid \|\| files.length === 0`; full = `treatmentTypeId && applianceType && resinId` | същият гейт |
| PS.html:146 | **Save** след edit на print settings | `[disabled]="!arePrintSettingsValid"` | сив |
| PS.ts:392-409 | `isPrintButttonDisabled` → Save Print Job / Send to Printer (PS.html:153-154) | `… \|\| (activeTab === PrintSetup && (!arePrintSettingsValid \|\| currentJob.printerPlatformId !== model?.printerPlatformId …)) \|\| (!currentJob.resinId \|\| !currentJob.layerThicknessId \|\| !currentJob.printerPlatformId) \|\| areFilesUploading` | **сив завинаги** за job без смола/слой/принтер |
| PS.ts:411-417 | `isSwitchingTabsDisabled` | `activeTab === PrintSetup && !arePrintSettingsValid` | **табовете Print Setup / Model List заключени** |
| PS.ts:347-353 | избор на модел при dirty настройки | `arePrintSettingsValid ? confirm… : ResetSelectedModelList` | изборът се губи |
| PS.ts:703-711, 751-762 | `moveItemToNewGroupJob` / `moveItemsToPlatformJob` | целта трябва да съвпада по resin/printer/thickness | null == null → минава |
| PS.ts:1256-1259 | след `savePlatformJob` | пише `ApplianceTypeProfilePair` / `ApplianceTypePlatformPair` в defaults store | храни `lastUsedAppliancePlatforms` |
| `print-list.states.ts:136-159` | `getArePrintSettingsValid` | `treatmentTypeId && TreatmentApplianceType ∋ applianceType && resinId && layerThicknessId && printerPlatformId && hasValidOrientation` | вторият гейт |
| `print-list.states.ts:109-134` | `getHavePrintSettingsUpdated` | сравнява resinId (пропуска при празен), layerThicknessId, printerPlatformId, printerPlatformType, sliceOffset, profileId | dirty флагът |

## 2. FE: потокът на данните (endpoint → effect → state → селектор)

Всички зареждания тръгват от `components/app/app.component.ts:264-290`; профили, last-used платформи и регистрирани принтери (:285-287) само за роля doctor.

| Файл:ред | Endpoint | Верига | При празно |
|---|---|---|---|
| `core/services/resin/rwc-resin.service.ts:9,14` | `GET rwc-resin` → `ResinInfo {data, recommendedResins, recommendedLayerThicknesses}` | `effects/resin.effects.ts:21-28` → `reducers/resin.reducers.ts:27-33` → `states/resin.states.ts:20-23` | смолата никога не е валидна; pipes `resin-id`/`resin-name` дават „missing resin" |
| `core/services/resin/ds-resin.service.ts:9` | `GET ds-resin` | `dsListOptions` (само pipes) | — |
| `core/services/appliance-profile.service.ts:10-25` | `GET appliance-profile`, `POST appliance-profile/save`, `DELETE appliance-profile/{id}` | `effects/appliance-profile.effects.ts:30-37` → `states/appliance-profile.states.ts:15`; `fillMissingDefaultValues$` (:40-81) пълни resinId/layerThicknessId на default профилите от `recommendedResins/Thicknesses` | `selectDefaultProfile` хвърля |
| `core/services/platform-job.service.ts:155-157` | `GET platform-job/last-appliance-platforms` | `effects/appliance-platform.effects.ts:21-25` → `reducers/defaults.reducers.ts:58-60` → `states/defaults.states.ts:28` → `DefaultsStoreService.appliancePlatformSettings$` → PPS.ts:295-301 | `initApplianceProfile` хвърля (:620) |
| `core/services/printer-platform.service.ts:7` | `GET printer-platform/list-options` (`http-object.service.ts:42-50`) | `effects/noms/printer-type.effects.ts:35-42` → `reducers/noms/printer-type.reducers.ts:17-21` → `states/noms/printer-type.states.ts:19` → BP:165-176 (`ChildApplianceModel`: id, parentId=treatmentTypeId, treatmentApplianceType) | няма принтер бутони |
| `core/services/noms/printer-type.service.ts:9` | `GET printer-type/list-options` | `getPrinterTypeListOptions` | формата не го ползва |
| `core/services/noms/layer-thickness.service.ts:9` | `GET layer-thickness/list-options` | `effects/noms/layer-thickness.effects.ts:24-31` → `states/noms/layer-thickness.states.ts:15` → PPS.ts:239-241 | празен списък |
| `core/services/noms/treatment-type.service.ts:14` | `GET treatment-type/list-options`, `treatment-type/appliance-type-list-options` | `effects/noms/treatment-type.effects.ts:20-47` → `states/noms/treatment-type.states.ts:20,22` → PPS.ts:224-237, 262-267 | няма job types — **не е RoC, но е задължителна зависимост** |
| `register.effects.ts:23` | регистрирани принтери | `registerSelectors.getRegisteredPrintersListOptions` | само чип |

Enums/модели: `core/enums/printer-platform.enum.ts` (`PrinterPlatform` P55=1, P95=2, P55S=3, P95S=4, P55SCrown=5, P95SCrown=6, P55SArch=7, P95SArch=8; `SPRMetadataPrinterPlatform` 'pro55'/'pro95'/'pros55'/'pros95'; `SPRExportMetadataPrinterPlatform`; `PrinterPrefixes`; `PrintersOrigin`), `core/constants/printer-types.ts` (`SprintRayPrinterTypes` Pro95=1, Pro95S=7, Pro55=5, Pro55S=8, MoonRay=3, Other=6; `SprintRayPrinterPlatformTypes` Standard=1, CrownKit=2, ArchKit=3), `core/enums/printer-type.enum.ts`, `core/constants/platform-options.ts:6`, слоеве: `core/enums/treatment/layer-thickness.enum.ts` (Micron50=1, Micron100=3, Micron170=4), `layer-thickness-roc.enum.ts` (50/100/170), `core/constants/layer-thicknesses-numeric.ts`, `core/helpers/common/layer-thickness-roc-helper.ts` (дефолт 100 µm); `core/models/resin/resin.ts:3-24` (`Resin.p55/p95/p55s/p95s/mr: number[]`, `forCrownKit`, `treatmentTypeIds`, `applianceTypes`; `ResinInfo`); appliance profile модели в `core/models/print-list/` (`appliance-profile.ts`: printerTypeId, resinId, layerThicknessId, sliceOffset, флагове, supportSettings; `appliance-profile-options.ts`, `user-appliance-profile.ts`, `appliance-type-platform-pair.ts`, `appliance-type-profile-pair`); `core/helpers/common/printer-type-helper.ts` (`getPrinterTypeByPlatformType` :132 → id 5-8 за CrownKit/ArchKit, `getPrinterTypePrinterPlatformId` :41, `getPlatformTypeByPrinterPlatformType` :153, `getShortDeviceModel` :22, картинки :74/:89).

## 3. FE: геометрията на плочата в рендерера

| Файл:ред | Символ | Роля | При празно |
|---|---|---|---|
| `core/helpers/common/platform-printer-type-helper.ts:134-165` | `getPlatformPrinterTypeDetailByPlatformSize` | **единствената таблица с размери**: Size55 105.6×59.4 (`p55-top/bottom.drc`), CrownKit 34×52 (`crown-platform.drc`), ArchKit55 105.6×59.4, ArchKit95 105.6×75 (`arch-platform.drc`), **Size95/default 182.4×102.6 (`p95-*.drc`)** | default → 95, безопасно |
| същият:5-23 | `getPlatformPrinterTypeDetail(SPRMetadataPrinterPlatform)` | дубликат по 'pro55'-стрингове, default 95 | plane-cut (R.ts:1032) |
| същият:25-35 / 37-54 | `getPlatformSize(SPRMetadataPrinterPlatform)` / `getPlatformSizeByPrinterPlatformId(id)` | → `PlatformSizeType`, default **Size95** | null id → 95 |
| същият:85-132 | `isSize55`, `isSize95` (P95/P95S), `isTypeS` (P55S/P95S), `isCrownKit`, `isArchKit`, `getPrinterPlatformType`, `getNormalizedPrinterPlatform` (5/7→3, 6/8→4), `getPrinterPlatformId(string)` (default P95), `PrinterPlatformToPrinterPrefix`, `isBoltModeAvailable` | помощници | `isSize95(null)` false → скрива template layout |
| `core/models/print-list/platform-printer.ts:13-19` | `PlatformSizeType` | Size55=1, Size95=2, CrownKit=3, ArchKit55=4, ArchKit95=5 | — |
| R.ts:205 | `platformSizeType = PlatformSizeType.Size95` | начална стойност | — |
| R.ts:553-570 | `setPlatform(printerPlatformType, useMetadataId)` | CrownKit/ArchKit по `currentPlatformJobModel.printerPlatformId`; иначе `useMetadataId ? getPlatformSize(currentPrinterPlatform) : getPlatformSizeByPrinterPlatformId(currentPrinterPlatformId)` → `platformHelperObjectsService.show(...)` | null → 95 |
| R.ts:321-334, 454-465 | subscriptions към current model/job | `setPlatform`, `positionRange`, `checkBoundingWallsAndCollisional` | — |
| R.ts:833-869 | `getMetadata` | без метаданни `currentPrinterPlatform = P95`; с метаданни `printDetails.printerModel as SPRMetadataPrinterPlatform` (:859) → `setPlatform(…, true)` | **два източника могат да се разминават** (model.printerPlatformId vs metadata.printerModel); без `printerModel` → 95 |
| `core/services/renderer/platform-helper-objects.service.ts:56-72, 75-191` | 5 платформени меша + 5 грида + 5 комплекта стени от размерната таблица (:269, :296, :338, :372); `show`, `checkBoundingWalls` (`mesh.positionRange`), `getCurrentPlatformBoundingBox`, `getCurrentPlatform`, `getCurrentGridPlatform`, `_getWalls` | out-of-bounds стени | — |
| R.ts:1426-1440, 2135-2138 (+1716, 1970) | `getMeshPositionRange` (±width/2, ±depth), `isOutOfBound` → `onModelOutOfBoundChanged` | граници | — |
| R.ts:770-778, 1143, 1883-1886, 916-959 | дублиране (`getCurrentPlatformBoundingBox`), `rendererHelpersService.simpleAutoLayout(meshes, platformSizeType)` (`renderer-helpers.service.ts:63-67` чете width/depth), raycast по платформата, `takeSnapshot` (само платформи с `userData.subtype === platformSizeType`) | клиентски auto layout, клик, снимка | — |
| PPS.ts:1267-1275 | `autoLayoutTriggeredByPrinterPlatformSizeChanged` | `autoLayout = true` при смяна на размера | — |

## 4. FE: какво се праща при save/edit и какво се чете обратно

| Файл:ред | Символ | Роля |
|---|---|---|
| `core/models/print-list/save-platform-job-input-model.ts:6-31` | `SavePlatformJobInputModel` | `treatmentTypeId`, `treatmentApplianceType`, **`printerPlatformId`, `resinId`, `layerThicknessId`**, `sliceOffset = 0`, `profileId`, **`printerPlatformType = Standard`**, `parameters` (`new PlatformJobParameters()`), `inboxFileIds`, `groupId`, `saveManualEditing`, `editModel`; null се праща като null |
| `core/services/platform-job.service.ts:56-66, 183-188` | `savePlatformJob` (`POST platform-job`), `savePlatformJobAsync` (apig), `importSpr` | `preprocessModel` пренаписва `printerPlatformId = getPrinterTypeByPlatformType(id, type)` (CrownKit/ArchKit → 5-8); null минава непроменен |
| PS.ts:1247-1264 | `onFilesUploaded` | нов job чрез `savePlatformJob(this.model)` |
| `core/store/effects/print-list.effects.ts:233-262` | `savePlatformJobDetails$` | целият модел + `editModel` |
| `core/utils/platform-job-utils.ts:5-36`, `platform-job.service.ts:84-90`, `print-list.effects.ts:594-643` | `mapToEditModel` → `POST platform-job/{id}/edit` | **без RoC полета** (per-STL transform, support, cut, annotation); ефектът (:628) пак мапва `currentJob.printerPlatformId` през `getPrinterTypeByPlatformType` |
| `core/store/reducers/print-list.reducers.ts:445-466, 551-556` | job → model; `populatePlatformData` | копира resinId, layerThicknessId, printerPlatformId, printerPlatformType, profileId; 5-8 → base id + type |
| `core/models/print-list/platform-job.ts:7-30` | `PlatformJob` (четене) | `layerThicknessId`, `layerThickness` (string), `resinId`, `resinName`, `printerPlatformId`, `printerPlatform` (име), `printerPlatformCapacity`, `profileId`, `sliceOffset`, `printerPlatformType` |
| `core/models/print-list/platform-metadata.ts:63-111` | `PlatformMetadataPrintDetails` | `layerThickness`, `resinId`, `resinName`, `printTime`, `legacyPrintTime`, `boltModePrintTime`, `printVolume`, **`printerModel`** (размер на рендерера), `sliceOffset`, `applianceTypeId`, `printProfileId`, `printJobTypeId`, `printerPlatformId`, `occupiedAreaPercent` |
| PPS.ts:482-533 | `initPlatformFromSpr` | чете printDetails: `printerPlatformId \|\| getPrinterPlatformId(printerModel)`, `resinId \|\| resinIdPipe(resinName)`, `getLayerThicknessIdFromNumeric(+layerThickness)`, `printProfileId`, `sliceOffset` |
| R.ts:233-248 / R.html:26-44; `print-list.states.ts:75-80` | `printTimeLabel` (`duration @ layerThickness`), bolt време, „Resin volume" | „N / A" или 0 — не блокира |
| `platform-model-list.component.ts:779` | `currentResinName = currentJob.resinName` | само показ |

## 5. FE: други RoC места

| Файл:ред | Символ | Роля |
|---|---|---|
| `platform-print-preview.component.ts:394-410` | `disablePrintActions` / `disableDirectPrintActions` | `!platformJob.id \|\| !resinName \|\| !layerThickness \|\| !entity?.printerId \|\| !selectedPrinter \|\| Offline \|\| isSlicing` → Print / Queue (html:118, 121) — принтерният поток, отива си |
| същият:156-180, 412-436; html:11, 28, 33 | съвместими принтери по `PrinterPlatformToPrinterPrefix`; bolt/print time по `isBoltModeAvailable`; показ Printer/Material/обем | — |
| същият:237, `platform-file-download.component.ts:119` | `sendForSliceAndPrint` → `POST platform-job/{id}/slice` | маха се с принтерите |
| `platform-file-download.component.ts:197-198` | суфикс `(sliceOffset µm)` в име на файл | козметика |
| `platform-print-confirmation.component.ts:96`, `app-modules/common/printer-list/printer/printer.component.ts:54` | `getShortDeviceModel`, `isProSPrinter = isTypeS(...)` | принтерен UI |
| `app-modules/delta/components/new-appliance-profile/*` | модал „create profile" | маха се с профилния UI |
| `shared/pipes/resin-id.pipe.ts`, `resin-name.pipe.ts` | lookup в RWC/DS списъците | `general.missingResin` |
| `platform-model-list.component.ts:93, 438`, PS.ts:1055 | `sliceOffsetSteps` (без употреба в html), Halloween „pumpkin" смола | козметика |

## 6. Бекенд

Три главни факта: (1) **липсваща смола НЕ проваля create-а** — `POST api/platform-job` минава с непознат resinId, провалът идва при четене (`GetAllDetailsByIdAsync` → RoC 404 → 500); (2) **липсваща смола или слой спира pipeline-а мълчаливо** — `PlatformJobChangedPostQueueMessageEH.cs:85-89` връща рано и platform-process съобщение не се праща; (3) **`LayerThicknessId` е plain `int`** в input модела — пропуснат → 0 → FK → DbUpdateException → 500. Error middleware (`Web/Infrastructure/Middleware/ErrorHandlingMiddleware.cs:54-107`): ArgumentException/InvalidOperationException → 400, DbUpdateException и всичко друго → 500; `[ApiController]` ModelState → 400.

### 6.1 RoC повърхност

| Елемент | Файл:ред | Роля | Вид |
|---|---|---|---|
| `ResinOnCloudOptions.Url` | `Common/Options/ResinOnCloudOptions.cs:5`; `Startup.cs:126`; `appsettings.Development.json:58-59` (`http://127.0.0.1:45281/api/local-roc/`); `appsettings.json:98` | base URL | config |
| `ResinOnCloudConfig` rwc/ds | `Common/Configs/ResinOnCloudConfig.cs:5-6` | `x-spr-user-agent` | config |
| `IRoCService`/`RoCService` | `ServiceLayer/Services/RoC/RoCService.cs:36-56` | `GetResinsAsync` = HTTP GET `{Url}resin`, не-2xx → `throw new Exception` (:44-47) = 500; `GetResinByResinIdAsync` = `FirstOrDefault` (непознат id → null) | catalog fetch; викан от ResinService, PlatformJobService:363/710, AITreatmentService:264 |
| `IRWCRoCService`/`RWCRoCService` | `Services/RoC/RWCRoCService.cs:30-44` | `GetSupportParamByResinAsync` GET `{Url}resin/support-params/{id}`, не-2xx throw | PlatformJobService:777, PrintListService:338 |
| `IDSRoCService`/`DSRoCService` | `Services/RoC/DSRoCService.cs:29-33` | `GetResinsByResinIdsAsync` | TreatmentService:2124, AITreatmentService:264 |
| `ResinService`, `RWCResinService`, `DSResinService` | `Services/Resins/ResinService.cs:26-43` | RoC → `ResinInfoViewModel`; Unset → `ResinIds.SprintRayOnX`/`m100` | catalog |
| `RWCResinController` `api/rwc-resin`, `DSResinController` `api/ds-resin` | `Web/Controllers/Resins/*.cs:9/16` | GET | endpoint |
| `LocalRocController` `api/local-roc` | `Web/Controllers/Local/LocalRocController.cs:19-66` | stub от embedded `Web/LocalStubs/roc-resins.json`; 404 извън Development | stub (board 3/4120) |
| `RoCViewModel`/`RoCDataViewModel` | `DTOs/ViewModels/RoC/RoCViewModel.cs` | JSON ключове `ri, rn, at, 55/95/55s/95s/mr (микрони), sp, atdr/rlt` | DTO |
| `ResinInfoViewModel`/`ResinViewModel` | `DTOs/ViewModels/Resins/ResinViewModel.cs:20-22, 59-60` | `int.Parse(rgn/ck)` хвърля при лоши данни | DTO |
| `PrintSettingsVerifier` | `ServiceLayer/Utilities/PrintSettingsVerifier.cs:12-53` | смола↔appliance type, смола↔принтер (`PrinterTypes.Other`=6 винаги минава), слой↔смола | **логика**, TreatmentService:2138-2150 |
| `GetApplicableLayerThicknessesFromRoC` | `PlatformJobService.cs:1601-1615` | `resin.P55/P95/P55s/P95s` по `PrinterPlatforms`, default P95 | **логика**, :367 |
| `RoCSupportParametersUtils.GetSupportParamsByPreset`; private копие `GetSupportParametersByPreset` | `ServiceLayer/Utilities/RoCSupportParametersUtils.cs:8-20`; `PlatformJobService.cs:1795-1804` | preset 1/2/3 → MaxStrength/Balanced/MaxDensity | PrintListService:370; `SetEditPlatformParameters`:1211 |
| `LayerThicknessIds` 1/3/4, `LayerThicknesses`, `MapLayerThickeness`/`MapLayerThicknessToRoC` | `Common/Configs/LayerThicknessIds.cs:5-7`, `LayerThicknesses.cs:5-15`, `Common/Extensions/LayerThicknessExtensions.cs:7-35` | id → mm (default 0.1) / микрони (default 100) | const + логика |
| `PrinterPlatforms` 1..8, `PrinterTypes` | `Common/Configs/PrinterPlatforms.cs:5-12`, `PrinterTypes.cs:9-61` | платформи 55/95/55S/95S/+CrownKit/ArchKit; принтери Pro95=1, Pro55=5, Pro95S=7, Pro55S=8, MoonRay=3, Form=4, Other=6; кодове pro95/pro55/pros95/pros55; серийни префикси; size tokens (:45-53) | const |
| `PrinterPlatformExtensions` | `Common/Extensions/PrinterPlatformExtensions.cs:7-67` | `MapPrinterPlatformToPrinterModel`, `…ToRoCPrefix` (без извиквания), `…ToPlatformSize`, `SizeEquals`; всички default-ват към 95, не хвърлят | логика |
| `ResinIds` | `Common/Configs/ResinIds.cs` | hard-coded resin id-та | ResinService:34, TreatmentService:2058-2071 |
| `IPrinterPlatformService`/`PrinterPlatformService` | `Services/PrintList/PrinterPlatformService.cs:32-98` | `GetListOptionsAsync` (Postgres); `GetByIdAsync` → `EnsureExist` → 400 „Entity {0} not found."; `GetIdAsync(null, printerTypeId)` → всеки не-SprintRay тип стига до `GetByIdAsync(0)` → **400** (fallback-ът `?? Platform95` на :72 никога не се изпълнява) | логика + catalog; PlatformJobService:108/176/283/332 |
| `PrinterPlatformController` `api/printer-platform/list-options/{parentId?}` | `Web/Controllers/PrintList/PrinterPlatformController.cs:20` | | endpoint |
| `LayerThicknessService`/`LayerThicknessController` `api/layer-thickness` | `Services/Treatments/Noms/…`, `Controllers/Treatments/Noms/…` | Postgres lookup | catalog |
| `ApplianceProfileService`/`ApplianceProfileController` `api/appliance-profile` | `Services/PrintList/ApplianceProfileService.cs:35-78`; `Controllers/PrintList/ApplianceProfileController.cs:25-44` | Dynamo default + user профили; GET/POST save/DELETE; също `IotProxyController:47-50`, PrintListService:333 | catalog + user data |
| `RwcDefaultApplianceProfile`/`RwcUserApplianceProfile`/`ApplianceProfile` | `DTOs/Models/DynamoDb/RwcApplianceProfile.cs:9-85` | `ResinId, LayerThicknessId, PrinterTypeId, SupportSettings, SliceOffset`, bool флагове, AutoLayout/TemplateLayout/AutoOrient/AutoMeshRepair | Dynamo |
| `PrinterService` (fleet) | `ServiceLayer/Services/PrinterService.cs:58, 82` | OfficePrinter (Postgres) + Dynamo `PrinterIdToThingName` | принтерна интеграция, не RoC; PlatformJobService:345 (`ForwardToPrinterId`), :1351 |
| „FitOffset" | — | не съществува под това име в BE; най-близко: AI Night Guard `offsets[resinId][fitment]`/`slots[resinId]` (`TreatmentService.cs:2058-2100`, непознат resin → KeyNotFoundException) | дентална логика |

### 6.2 Валидации и lookup-и в `POST api/platform-job` (`SavePlatformJobAsync`, `PlatformJobService.cs:330`)

Входове: `PlatformJobController.cs:51` (POST ""), `:58` (import-spr), `IotProxyController.cs:32`, `POST {id}/slice` със `SavePrintSettingsChanges` (:1042).

| # | Къде | Условие | Резултат |
|---|---|---|---|
| 1 | `DTOs/InputModels/PrintList/PlatformJobInputModel.cs:15` | `[Required] string ResinId` | 400 ModelState |
| 2 | същият `:18, :20, :24` | `int LayerThicknessId`, `int PrinterPlatformId`, `int TreatmentTypeId` (не nullable, default 0) | виж 3, 4, 11 |
| 3 | `PlatformJobService.cs:332` | `printerPlatformService.GetByIdAsync(PrinterPlatformId)` → EnsureExist | 400 при 0 / неseed-нато id |
| 4 | `:333` | `treatmentTypeService.GetDetailAsync(TreatmentTypeId → appliance mapping)` → null при непознат → `treatmentType.Id` на :452 | NRE → 500 |
| 5 | `:343-350` | `ForwardToPrinterId` извън `GetUsedPrinterIdsAsync()` | 400 PRINTER_UNREGISTERED_ERROR |
| 6 | `:363` | `rocService.GetResinByResinIdAsync(ResinId)` — HTTP при всеки save | 500 при недостъпен RoC; null при непознат id |
| 7 | `:365-371` | `if (resin != null) … !layerThicknessesByPrinterId.Contains(LayerThicknessId.MapLayerThicknessToRoC()) → ArgumentException` | 400 LAYER_THICKNESS_NOT_APPLICABLE_TO_RESIN (пропуска се при непозната смола) |
| 8 | `:389-408` | SmileDesign → orientation правила; CrownAndBridge → NeedRaft=false | — |
| 9 | `:422-444` | `printSettingsUpdated` (platform/resin/thickness/sliceOffset/grayscale/template), `platformSizeUpdated = !SizeEquals`, `treatmentSettingsUpdated` | кое събитие се публикува |
| 10 | `:454-475` | пише ResinId, LayerThicknessId, ProfileId (без валидация на ProfileId); копира в групата | — |
| 11 | `:497` SaveAsync | `PlatflormJob.ResinId` NOT NULL; `LayerThicknessId=0` → FK | DbUpdateException → 500 |
| 12 | `:519-522` | `SaveManualEditing` → `EditPlatformAsync` → `GetAllDetailsByIdAsync` (:777 RoC support-params, непозната смола → 404 → throw) | 500 |
| 13 | `:490-494` | `InboxFileIds` → `AddFilesToPlatformJobAsync` → `PrintListItemAddedEvent` → `PrintListService.PreprocessPrintListItemAsync` :338 RoC + :370 `resin.SupportParameters` | фонов провал, items остават „processing" |
| 14 | `:517/:527` | `PlatformJobTreatmentSettingsUpdatedEvent` → `ReprocessItemsEH.cs:34/38`; `PlatformJobPrintSettingsUpdatedEvent` → `PlatformJobChangedPostQueueMessageEH:45/71` | фонови RoC извиквания |

Edit/move: `POST {id}/edit` → `EditPlatformAsync` (:1050): `:1073 GetAllDetailsByIdAsync` (RoC → 500 при непозната смола), `:1211 GetSupportParametersByPreset` (NRE при null SupportParameters), `:1243-1260` съобщението; `PlatformEditInputModel` няма RoC полета. `GET api/platform-job/{id}` → `:777-780 resin.Name` (RoC всеки път). `POST {dest}/move-items` → `AddItemsToJobAsync` (:153): 400 при несъвпадение на appliance type (:205), printer platform (:210), resin (:215), layer thickness (:220); `:193 PrintDetails.OccupiedAreaPercent` NRE без metadata ред. `PUT move-item-to-new` → `:283 GetIdAsync` (400 при не-SprintRay PrinterTypeId), `:287-289` 400 PLATFORM_JOB_PRINTER_PLATFORM_NOT_CONFIGURED. `AddItemToJobAsync` (:103-131) търси draft job по PrinterPlatformId+ResinId+LayerThicknessId.

Treatment print settings (дентално, пада с board 6): `PATCH api/treatment/{id}/print-settings` → `SavePrintSettingsAsync` (`TreatmentService.cs:686`) → `VerifyPrintSettingsAsync` (:2121): RoC :2124; :2127-2134 400 ENTITY_ID_NOT_FOUND без printer type/resin/thickness; :2136-2152 400 RESIN_NOT_APPLICABLE_TO_APPLIANCE_TYPE/_PRINTER, LAYER_THICKNESS_NOT_APPLICABLE_TO_RESIN; :299-303 мълчаливо трие print settings при 0/празно.

### 6.3 Геометрия и съобщенията към опашките

- **В бекенда няма милиметри** — само size token: `MapPrinterPlatformToPlatformSize` (`PrinterPlatformExtensions.cs:43-62`) → `Size55/Size95/SizeCrownKit/SizeArch55Kit/SizeArch95Kit` (`PrinterTypes.cs:45-53`).
- **Platform-process FIFO** (`PlatformJobChangedPostQueueMessageEH.cs:113-167`): `:71 GetAllDetailsByIdAsync` (RoC); **`:85-89` гейт `if (Items.Any(IsProcessing) || ResinId.IsNullOrEmpty() || !LayerThicknessId.HasValue) return true;`** — без съобщение; полета `layerThickness = MapLayerThickeness()` (mm), `resinId`, `resinName` (RoC), `printerModel = MapPrinterPlatformToPrinterModel()`, `printerPlatformId`, `platformSize`, `noGrayScale`, `printProfileId`, `sliceOffset`, `printJobTypeId`, `applianceTypeId`, `isAligner`, `needRaft`, `platformOrientation`, run* флагове, `individualModels`, `patients`.
- **Edit step function**: `SetEditPlatformParameters` (`PlatformJobService.cs:1188-1279`), същите полета :1243-1263 + `supportParameters` per модел (:1211, RoC).
- **Slice FIFO** (`PlatformJobSlicePostQueueMessageEH.cs:40-63`): :40 RoC; праща `printerPlatformId, noGrayScale, offsetHoleOnly`, appliance полета; без resin/thickness/size.
- **Preprocess step function** (`PrintListService.cs:361-381`): `resinId`, `supportPreset` (от appliance profile `SupportSettings`, иначе Balanced :340-343), `supportParameters` (RoC :370), `customParams`.
- DTO `PlatformMetadataPrintDetails` (`DTOs/Models/DynamoDb/PlatformMetadata.cs:37-85`): LayerThickness, ResinName, PrinterModel, PrinterPlatformId, NoGrayScale (bool), OccupiedAreaPercent, PrintTime…; сервира се от `GET {id}/platform-metadata-print-details` (`PlatformJobService:952-967`).

### 6.4 База данни

Postgres (`DataLayer/Migrations/SprintRayContextModelSnapshot.cs`):

| Таблица | Колони / FK | Snapshot |
|---|---|---|
| `PlatflormJob` (`DTOs/Models/Printers/PlatformJob.cs`) | `LayerThicknessId int?` (FK optional :5346-5348); **`ResinId text NOT NULL`** (:2096-2098; entity :29 `[Required]`, без FK); **`PrinterPlatformId int NOT NULL`** FK required cascade (:5350-5354); **`TreatmentTypeId int NOT NULL`** FK required (:5356-5360); `ProfileId uuid?` (:2093); `Parameters jsonb` | :2055-2124 |
| `PrintListItem` | без FK към платформа/смола/слой (FileId, PatientId, PlatformJobId cascade, UserId) | :5402-5424 |
| `PrinterPlatform` (Id, Name) | | :2311-2324 |
| `PrinterPlatformTreatmentType` | PK (PrinterPlatformId, TreatmentTypeId, TreatmentApplianceType) + Capacity (`SprintRayContext.cs:478-479`); и двата FK required | :2327-2345, :5435-5448 |
| `TreatmentPrintSettings` | LayerThicknessId FK **required**; PrinterPlatformId optional; PrinterTypeId **required**; `ResinId [Required]` | :3876-3912, :5856-5879 |
| `TemplateTreatmentPrintSettings` | всичките FK optional | :3168-3203, :5623-5642 |
| `TreatmentTypeDefaultValue` | `ResinId NOT NULL`, LayerThicknessId FK **required** | :4338-4365, :5988-6001 |
| `LayerThickness`, `PrinterType`, `TreatmentType` | lookup | :1403-1420, ~:2371, ~:4335 |
| `StoreMaterial`, `MaterialUsageStatistics` | legacy, само MasterDashboard | :2902, :1489 |

Миграции по темата (нови → стари): `20230307130028_PlatformJobApplianceProfile` (ProfileId), `20230207143342_AddPrinterPlatformIdInTemplateTreatmentPrintSettings`, `20230202143659_AddPrinterPlatformIdInTreatmentPrintSettings`, `20220727081139_NullableColumnsInTemplateTreatmentPrintSettings`, `20220712121404_RemoveMaterialAndTreatmentTypeMaterialTables`, `20220711130535_PrinterPlatformTreatmentApplianceType`, `20220418142127_DropMaterialFromRWC` (ResinId в PlatflormJob), `20211117091740_AddDefaultLayerThickness`, `20211008124938_AddTreatmentTypeDefaultValue`, `20210924072829_PlatformJobNullablePrintSettings` (LayerThicknessId nullable), `20210609150912_PlatformJobStructure`.

Локални seed-ове (`DataLayer/Scripts/LocalSeed/`): `020-printers.sql:6-24` PrinterType 1/7/5/8/3/4/6 + PrinterPlatform 1-8 („Pro 55" … „Pro 95 S Arch Kit"); `030-treatment-types.sql` :9-12 LayerThickness 1/3/4, :15-21 TreatmentType 1,2,4,8,10,100, :24-30 SprModelCount, :36-47 PrinterPlatformTreatmentType (1-4 всички типове; Crown Kit 5-6 само 11/17; Arch Kit 7-8 само 3; capacity placeholder), :52-56 TreatmentTypeDefaultValue (смоли '2003','3010', слоеве 3/1).

Dynamo: `RWC_DEFAULT_APPLIANCE_PROFILE_LOCAL`/`RWC_USER_APPLIANCE_PROFILE_LOCAL` (`appsettings.Development.json:96-97`, `DynamoDbConfig.cs:41-43`), seed от `infra/bootstrap.mjs` (§7).

### 6.5 Стартовите endpoint-и на print-setup (RoC-производни)

| Endpoint | Controller → service | Източник |
|---|---|---|
| `GET api/rwc-resin` | RWCResinController → ResinService | **RoC stub** |
| `GET api/appliance-profile` (+ iot-proxy) | ApplianceProfileController:25 → ApplianceProfileService.GetAllAsync | **Dynamo** |
| `GET api/printer-platform/list-options/{parentId?}` | PrinterPlatformController:20 | Postgres PrinterPlatformTreatmentType ⋈ PrinterPlatform |
| `GET api/printer-type/list-options` | PrinterTypeController (`Noms/NomController.cs:21`) | Postgres PrinterType |
| `GET api/layer-thickness/list-options` | LayerThicknessController | Postgres LayerThickness |
| `GET api/treatment-type/list-options`, `appliance-type-list-options/{parentId?}`, `default-values` | TreatmentTypeController / TreatmentTypeService:94 / TreatmentTypeDefaultValueService | Postgres TreatmentType / код (TreatmentHelperService) / TreatmentTypeDefaultValue |
| `GET api/platform-job/last-appliance-platforms` | PlatformJobService:1320 | Postgres PlatflormJob + OfficePrinter префикс; default `Platform95S` (:1336) |
| `GET api/platform-job` / `{id}` | GetUnfinishedAsync :678 (RoC имена :710-714) / GetAllDetailsByIdAsync :758 (RoC :777) | Postgres + **RoC** |

### 6.6 Тестове, които пинват поведението

`Tests/Controllers/Local/LocalRocStubTests.cs:32, 44`; `Tests/Controllers/LocalRocControllerTests.cs:46, 69`; `Tests/Mapping/AutoMapperProfileTests.cs:81` (RoC resins), `:112, :137` (print details); `Tests/Services/TreatmentServiceTests.cs:56/197/236` (mock IDSRoCService), `:364, :376` (print settings 400); worker `test/platform-process.test.mjs:12-17, 32`. **Няма тестове за PlatformJobService create.**

### 6.7 Ако RoC данните изчезнат — 11 места хвърлят/отказват

1. `PlatformJobService.cs:363` → `RoCService.cs:44-47` → 500 на всеки POST (при провал на извикването; непозната смола минава). 2. `:710 GetUnfinishedAsync` → 500 / NRE при null `Data`. 3. `:777 GetAllDetailsByIdAsync` → 500 на `GET {id}`, `POST {id}/edit`, `POST {id}/slice`, POST "" със `SaveManualEditing`. 4. Същото в `PlatformJobChangedPostQueueMessageEH:71`, `PlatformJobSlicePostQueueMessageEH:40`, `…ReprocessItemsEH:34` — фонов провал, без съобщение. 5. `PrintListService.cs:338/370` — няма preprocess, items остават „processing". 6. `PlatformJobService.cs:1211/1795` NRE при null SupportParameters. 7. `TreatmentService.cs:2124, 2136-2152`. 8. `AITreatmentService.cs:264` (резултатът не се ползва). 9. `ResinService.cs:28/32` → `rwc-resin`/`ds-resin` 500. 10. `PlatformJobService.cs:367-371` 400 при смола без слоя за платформата. 11. `PlatformJobChangedPostQueueMessageEH.cs:85-89` мълчаливо спира pipeline-а при празен ResinId / null LayerThicknessId.

### 6.8 Най-малкият набор промени за platform job без смола/слой/принтер

- `PlatformJobInputModel.cs`: махни `[Required]` (:15); `LayerThicknessId` → `int?` (:18); `PrinterPlatformId` (:20): seed-нато id или `int?` = „generic".
- Entity + миграция: `PlatformJob.ResinId` без `[Required]` (:29) + миграция, която маха NOT NULL на `PlatflormJob.ResinId`; `LayerThicknessId` вече е nullable; `PrinterPlatformId` и `TreatmentTypeId` са NOT NULL с required FK — за PrinterPlatform: един generic seed ред ИЛИ миграция към nullable (тогава и `PlatformJobViewModel.cs:69/74` `PrinterPlatform.Name/.TreatmentTypes`, `SizeEquals`).
- `SavePlatformJobAsync`: `:363-372` RoC само при непразен ResinId или изтрий блока; `:332` пропусни при липса на платформа.
- `GetAllDetailsByIdAsync :777-792`: без RoC при липса на смола, `ResinName`/`SupportParameters` null; null-guard на `GetSupportParametersByPreset` (:1795)/:1211.
- `GetUnfinishedAsync :710`: guard или махни.
- **`PlatformJobChangedPostQueueMessageEH.cs:86`**: махни `(ResinId.IsNullOrEmpty() || !LayerThicknessId.HasValue)` — иначе никога няма platform-process съобщение. `MapLayerThickeness(null)` = 0.1 и `MapPrinterPlatformTo*` default-ват към 95 → builder-ите не хвърлят.
- `PrintListService.cs:338/370`: без RoC при липса на смола, `supportParameters: null` (worker `input.mjs` вече приема null).
- Опционално: `AddItemToJobAsync`/`AddItemToNewJobAsync` → `GetIdAsync` (`PrinterTypeId=Other` → 400); `VerifyPrintSettingsAsync :2127-2134` и :299-303, ако и treatment print settings трябва да допускат без смола (дентално → board 6).

### 6.9 Чист каталог (изтриваемо)

| Таблица | Присъда |
|---|---|
| `TreatmentTypeDefaultValue` | чист RoC каталог (само `default-values` + includes) → изтриваема |
| `LayerThickness` | каталог; след FK-тата: PlatflormJob (optional), TemplateTreatmentPrintSettings (optional), TreatmentPrintSettings (**required**), TreatmentTypeDefaultValue (**required**) |
| `PrinterPlatform` + `PrinterPlatformTreatmentType` | SprintRay каталог; блокиран от **required** FK `PlatflormJob.PrinterPlatformId`; Capacity се ползва от `PlatformJobViewModel.cs:74` и list-options |
| `PrinterType` | каталог + OfficePrinter/регистрация + `TreatmentPrintSettings.PrinterTypeId` required → пада с принтерната интеграция |
| `StoreMaterial`, `MaterialUsageStatistics` | legacy, MasterDashboard |
| `TreatmentType` | **остава** (домейн, дентално → board 6) |
| Dynamo `RWC_DEFAULT_APPLIANCE_PROFILE_*` / `RWC_USER_APPLIANCE_PROFILE_*` | каталог / user data; изтриваеми, щом FE спре `api/appliance-profile`, `IotProxyController:47-50` падне и `PrintListService.cs:333-343` не ги чете (fallback Balanced). Профилите носят и не-RoC настройки (SliceOffset, AutoLayout, NeedRaft…), всичките дублирани във формата → без загуба |

## 7. Worker, инфраструктура, гейтове, документи (извън приложението RoC само минава транзитно)

| Файл:ред | Какво кодира |
|---|---|
| `workers/algorithms/src/platform-process-logic.mjs:4-7, 17-21` | коментари с формата на FIFO съобщението (`parameters: {platformId, individualModels[], runAutoLayout, individualModelsUpdated, runSlicer, layerThickness, resinName, printerModel, printerPlatformId, …}`) и на `printDetails` (= BE `PlatformMetadataPrintDetails`, всичко string освен `NoGrayScale` bool; PrintTime/PrintVolume/NumberOfSlices нарочно не се измислят) |
| `platform-process-logic.mjs:32-44` | `parsePipelineMessage` → `printDetails`: `LayerThickness, ResinName, PrinterModel, PrinterPlatformId, PrintJobTypeId, ApplianceTypeId, IsAligner, NeedRaft, PlatformOrientation, SliceOffset` (низове), `NoGrayScale` (bool) |
| `platform-process-logic.mjs:54-71` | `gridLayout(models, gap=5)`: квадратна решетка в XZ около (0,0), стъпка = най-голям footprint + 5 — **без граници на плочата, без clamp** |
| `steps/platform-process.mjs:1-9, 19-26, 28-47, 58-59, 68-71`; `steps/slice.mjs` | `writePlatformRow` (UpdateItem: LastModified, Version "local-1", IsSprReduced "false", PrintDetails); autoLayout пише `STL.Position` (plate-agnostic); лог `(${PrinterModel}, ${LayerThickness} mm)`; `runSlicer` → slice 500 `SLICER_NOT_AVAILABLE_LOCALLY` |
| `src/input.mjs:5-7`, `steps/import.mjs:31`, `plane-cut.mjs`, `edit-logic.mjs` | preprocess масивът носи `applianceType, resinId, supportPreset, …`, четат се само `fileKey/friendlyName/printListItemId/platformId`; import слага модела на y=0; edit няма RoC полета (:16-24 изброява логваните, но неизпълнявани операции) |
| `test/platform-process.test.mjs:7-21, 32-50, 94-100`; `test/input.test.mjs:8-9` | уловеното FIFO съобщение (15.11) и assert-ите за `PrinterModel "pro55"`, `LayerThickness "0.05"`, `PrinterPlatformId "1"`, `ResinName "Die and Model 2 Gray (local stub)"`, `platformSize: "Size55"` (в съобщението, **никой не го чете**) |
| `infra/resources.mjs:9-16`, `infra/bootstrap.mjs:47-69, 152-156` | таблици `RWC_DEFAULT_APPLIANCE_PROFILE_LOCAL` / `RWC_USER_APPLIANCE_PROFILE_LOCAL` (GSI `USER_ID-APPLIANCE_TYPE-index`); seed `defaultApplianceProfiles: 1..20` (по един на FE `TreatmentApplianceType`), `PROFILE` = {Abbreviation "LOCAL", SliceOffset 0, Orientation 0, SupportSettings 0, IsAligner false, NeedRaft false, NoGrayScale false, GenerateSupports false, AutoLayout true, TemplateLayout false, AutoOrient false, AutoMeshRepair false}; без resin/layer/printer стойности (FE ги пълни от RoC stub-а през `fillMissingDefaultValues$`) |
| `infra/resources.mjs:23-26, 71-77` | FIFO `RaywareCloudSPRSlicerLocal.fifo`, `RaywareCloudPlatformProcessLocal.fifo`; placeholder машина `PlatformJobLocal` |
| `scripts/gate/lab-pipeline.mjs:16-17, 249-252, 258-290, 322, 334-344` | `GET api/rwc-resin` → `[0].id`; POST тяло `treatmentTypeId 1, printerPlatformId 1, resinId, layerThicknessId 1, sliceOffset 0, profileId null, parameters{…}` (без `treatmentApplianceType` → 400 от enum binder-а); metadata stage: `printDetails.printerModel === 'pro55'` твърд FAIL |
| `scripts/gate/lab-ui.mjs:32-40, 53-67, 325-367, 397` | upload stage: принтер `f-button-group[name="platformType"]` (първия enabled), Material `f-autocomplete-v2[name="resin"]` (click/focus/ArrowDown/**Enter** — заобиколка на UI бъг), слой `f-select[name="layerThickness"]`; FAIL текст „NEXT: UPLOAD FILES stays disabled (applianceForm invalid)" |
| `scripts/gate/be-smoke.mjs:41-75` | стартовите 28 заявки, всички 2xx: `api/appliance-profile`, `platform-job/last-appliance-platforms`, `printer-platform/list-options`, `printer/all?term=`, `treatment-type/appliance-type-list-options`, `layer-thickness/list-options`, `printer-type/list-options`, `ds-resin`, `rwc-resin`, `treatment-type/list-options`, … |
| `scripts/e2e.mjs:81, 83, 89` | сам пише платформен ред `{ID, Name "e2e platform", PrintDetails: {}, LastModified}`; preprocess/edit входовете без RoC полета → **нищо за промяна** |
| `workers/callback-bridge/**`, `docker-compose.yml`, env | нула съвпадения; единственото „sprintray" е Postgres user/db |
| `README.md` :26, :59 („All 28 REST calls"), :85, :129, :138-148, :158, :173, :175 | treatment-type номенклатури; lab-ui upload; „the resin comes from the local RoC stub"; „What the lab cannot do yet" (slicing, print details, screenshot, no-op edit ops, „Printers: the printer list is empty"); таблицата ResinOnCloud → `api/local-roc/`; troubleshooting за appliance profiles 1-20 и „400 layer thickness is not applicable" |
| `PLAN.md` :30, :48, :50-51, :92, :104-105, :109, :120 | local ResinOnCloud, RoC stub в микрони, какво не може лабораторията, #4400 бележки, „resin/printer profiles are local JSON", DLPSlicerApp, отворен въпрос за типа принтер/изход |
| `RENDERER-AUDIT.md` :42-43, :48-54, :59, :90, :103-106, :123, :126 (**платформата е DRACO от `assets/models/{p55,p95,crown,arch-*}.drc`**), :148-149, :195-196, :201, :219-220, :248-253, :288, :295-296 | инвентарът на RoC файловете/endpoint-ите — за docs таска |

## 8. Опции и препоръка

**Какво е „платформа" без принтер.** Днес платформата = SprintRay printer platform (4 + Crown/Arch варианти), от която произлизат: размерът на плочата в рендерера (единствено място с милиметри: FE таблицата §3), филтърът на смолите, филтърът на слоевете, `printerModel` в метаданните, `platformSize` в pipeline съобщението, FK `PlatflormJob.PrinterPlatformId` NOT NULL. Без принтер остава само първото: **размер на плочата за рендерера**.

| Опция | Какво значи | Цена | Присъда |
|---|---|---|---|
| **A. Една фиксирана плоча сега** | Махат се смоли, слоеве, appliance profiles, fit offset, принтерен избор и RoC повърхността от FE, BE, worker и гейтове. Плочата остава с днешната default геометрия (Size95: 182.4×102.6 mm, `p95-*.drc`), преименувана неутрално; FE рендерерът спира да чете `printerPlatformId`/`printerModel` и ползва една константа. BE: `PlatflormJob.PrinterPlatformId` остава NOT NULL към **един** seed ред (днешния id 2, преименуван „Default plate"; редове 1, 3-8 и техните `PrinterPlatformTreatmentType` се трият от seed-а), `ResinId` → nullable (една миграция), `LayerThicknessId` → `int?` в input модела, RoC lookup-ите падат, гейтът в `PlatformJobChangedPostQueueMessageEH:86` пада. Формата: job type (+ appliance type за 2 типа) → име → Next. | Средна. Без нова абстракция, без нови мешове. Една миграция. | **Препоръка за board 5.** |
| **B. BuildPlate абстракция сега** | Ново entity/модел вместо PrinterPlatform: име, ширина, дълбочина, височина, форма (правоъгълна/кръгла); FE рисува плочата параметрично (box/plane + grid + стени от размерите, без DRACO), избор на плоча в формата; seed 1-3 плочи (generic, SLA-подобна, FDM-подобна). | Висока: пренаписва `platform-helper-objects.service.ts` (5 меша/5 грида/5 комплекта стени по `PlatformSizeType`), `takeSnapshot` subtype, `getMeshPositionRange`, `simpleAutoLayout`, плюс BE entity + миграция + ViewModel + FE store. Това е вече „Hero Forge" работа и ще се повтори при денталното орязване на FE (job type още е в формата). | За board 7, когато job type-ът е паднал и FE се реже. Потребителят: FDM/SLA са „много нататък". |
| C. Половинчато (каталогът остава, полетата се крият) | `[required]` махнато, данните seed-нати | Не работи: `handleMissingResin`/`selectDefaultPlatformType`/`selectRecommendedThickness` трият всяка seed-ната стойност, селекторът `getArePrintSettingsValid` пак иска трите id-та, BE пак вика RoC при всеки GET. | Отхвърлена (условието на потребителя). |

**Ред на промяната (адитивно → смяна → триене), за да не е гейтът червен по конструкция:**
1. **BE приема без RoC** (контракт): `ResinId`/`LayerThicknessId` nullable в input/entity (миграция), RoC lookup само при непразна смола (после се трие), `:86` гейтът пада, `GetAllDetailsByIdAsync`/`GetUnfinishedAsync` без RoC при null, `PrintListService` праща `supportParameters: null`. Старият payload на гейтовете още минава → нищо червено.
2. **Гейтове и worker** минават на новия контракт: `lab-pipeline` POST без `resinId/layerThicknessId` (с `printerPlatformId` = default ред), metadata stage без `printerModel === 'pro55'`; worker спира да пише `LayerThickness/ResinName/PrinterModel/PrinterPlatformId`; `lab-ui` upload stage без принтер/Material/слой стъпки (ще минава чак след FE стъпка 3 → този stage се включва като gating в FE таска, не по-рано).
3. **FE**: формата (двата гейта, трите throw места, четирите „триещи" метода), рендерерът на една константа, store/услуги/pipes/печатни бутони се трият (барели = poison → една серийна lane).
4. **BE триене**: RoC services/controllers/stub/`LocalRocController` + тестове, `PrinterPlatformController`/`LayerThicknessController`/`ApplianceProfileController` + Dynamo таблици + bootstrap seed, консти (`PrinterPlatforms` остава с един член или пада заедно със `SizeEquals`), seed-овете, `TreatmentTypeDefaultValue`, `be-smoke` списъкът (28 → ~18).
5. Docs (README/PLAN/RENDERER-AUDIT редовете от §7).

**Какво остава умишлено след board 5** (пада в board 6 = дентално орязване): `TreatmentType` + job type/appliance type в формата (FK NOT NULL + orientation правила), `TreatmentPrintSettings`/`TemplateTreatmentPrintSettings`/`PrintSettingsVerifier` (дентален код, не се вика от print-setup), `PrinterType`/`OfficePrinter` (принтерна интеграция: `printer/all`, `PrinterService`, `ForwardToPrinterId`, IoT proxy) — ако потребителят иска, принтерната интеграция може да падне още в board 5 като отделна BE lane (`PrinterController`, `PrinterService`, `PrinterStateService`, `IotProxyController`, Device/CloudTab), защото RoC и „send to printer" са двете половини на едно и също.

## 9. Отворени решения за потребителя (преди авторство на board 5)

1. **A или B** (§8). Препоръка: A.
2. **Job type picker**: остава видим (препоръка; пада в board 6 с TreatmentType) ИЛИ се скрива още сега с фиксиран `treatmentTypeId = 100` („Custom", appliance Unset, без orientation правила) → формата става само име + Next. Второто е евтино във FE (един default в `SavePlatformJobInputModel` + `[hidden]`), но оставя дентален код жив и невидим.
3. **Appliance profiles**: изтриване изцяло (препоръка: настройките им са дублирани в акордеона на формата) ИЛИ запазване като „settings profile" без resin/thickness/printer полета.
4. **`PlatflormJob.PrinterPlatformId`**: един seed ред „Default plate" без схема промяна (препоръка) ИЛИ nullable миграция.
5. **Принтерната интеграция** (fleet, `printer/all`, send to printer, IoT proxy): в board 5 като отделна lane ИЛИ в board 6.
6. В board 5 влизат ли и двата UI дълга от 15.11: стиловете на акордеона (да, малък FE таск) и Material autocomplete бъгът (пада сам с полето).

## 10. Скица на board 5 (ПРЕДИ решенията; оставена за история — авторитетният борд е `ralph/tasks.json` 5000–5600 след решенията от §9: B (BuildPlate сега), job type остава, принтерите падат в борд 5, профилите се трият; 13 таска / 8 lanes / K 7)

| Lane | Зона (files) | Таскове (ред) |
|---|---|---|
| `be-contract` | `DTOs/InputModels/PrintList/PlatformJobInputModel.cs`, `DTOs/Models/Printers/PlatformJob.cs`, `DataLayer/Migrations/*` (poison → соло), `ServiceLayer/Services/PrintList/PlatformJobService.cs`, `PrintListService.cs`, `EventHandlers/PlatformJob/*`, `Tests/Services/PlatformJob*` | 1. nullable resin/thickness + миграция + RoC-guard-ове + `:86` гейтът + тестове (heavy, TDD) |
| `gate-pipeline` | `scripts/gate/lab-pipeline.mjs`, `scripts/gate/be-smoke.mjs` | 2. нов payload + metadata без pro55 (dependsOn 1); по-късно: списъкът на be-smoke (dependsOn BE триенето) |
| `worker` | `workers/algorithms/**` | 3. без RoC полета в platform row + тестове (dependsOn 1; паралелно с 2) |
| `fe-form` (серийна, poison барели) | `platform-print-setup/**`, `platform-setup/**`, `base-platform/**`, `core/store/states/print-list.states.ts`, `core/models/print-list/save-platform-job-input-model.ts`, `app.component.ts`, `core/store/**` (resin, appliance-profile, appliance-platform, printer-type, layer-thickness slices), `core/services/{resin,appliance-profile,printer-platform,noms/printer-type,noms/layer-thickness}`, pipes, print-preview/печатни бутони, `scripts/gate/lab-ui.mjs` | 4. формата: двата гейта, throw местата, триещите методи, fit offset, профилен UI; lab-ui upload stage на новата форма (dependsOn 1, 2) → 5. триене на store/услуги/pipes/печат (dependsOn 4) |
| `fe-renderer` | `renderer/**`, `core/services/renderer/platform-helper-objects.service.ts`, `core/helpers/common/platform-printer-type-helper.ts`, `renderer-helpers.service.ts` | 6. една константна плоча (без `printerPlatformId`/`printerModel` входове); Size55/Crown/Arch клонове и `.drc` ассети падат (паралелно с 4; няма общи файлове) |
| `fe-ui` | `platform-setup` акордеон стилове (scss на компонента) | 7. accordion fix (easy) — само ако файловете не се пресичат с 4; иначе в `fe-form` след 5 |
| `be-cut` | `Services/RoC/**`, `Services/Resins/**`, `Controllers/Resins/**`, `Controllers/Local/LocalRocController.cs`, `Web/LocalStubs/`, `Controllers/PrintList/{PrinterPlatform,ApplianceProfile}Controller.cs`, `Services/PrintList/{PrinterPlatform,ApplianceProfile}Service.cs`, `Common/Configs/{LayerThickness*,PrinterPlatforms,ResinIds,ResinOnCloudConfig}.cs`, `Common/Options/ResinOnCloudOptions.cs`, `DataLayer/Scripts/LocalSeed/*`, `Tests/Controllers/Local*`, `Startup.cs`/`ServiceCollectionExtenstions.cs` (poison → същата lane) | 8. триене на RoC повърхността + seed на един Default plate ред + Dynamo appliance таблици от bootstrap/resources (dependsOn 1, 3, 5) |
| `seed` | `infra/bootstrap.mjs`, `infra/resources.mjs`, `DataLayer/Scripts/LocalSeed/*` (застъпва се с 8 → същата lane или dependsOn) | 9. „какво трябва при първи старт" (потребителят, 15.11): преглед на Postgres/Dynamo seed-а след орязването; Dynamo appliance seed пада |
| `docs` | README.md, PLAN.md, RENDERER-AUDIT.md, `rwclab-structure.md` (ralph) | 10. (dependsOn всичко) + пълен verify |

Критичен път ≈ 1 → 2 → 4 → 5 → 8 → 10 (6). Паралелни от старта: нищо (всичко зависи от контракта 1) → затова таск 1 е малък и първи, като скелетен таск.
