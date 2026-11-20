# rwclab board 6 recon (20.11.2026, read-only, HEAD 89a7d6c on `ralph/standalone`)

Authoritative board = `tasks.json` 6000–6700. Paths are repo-relative unless a section says otherwise.
User decisions (20.11.2026): (1) "Previous projects" panel + real delete (DB status + S3 objects), one
active project in the editor, "New" asks "if you confirm, this discards your unsaved changes";
(2) brand = "RWC Lab" (text, no image) in the header and the tab title; (3) SprintRay logo and word go;
(4) Print Job Type picker goes, every job is `TreatmentType.Custom` (100) + `TreatmentApplianceType.Unset` (0);
(5) "Assign Print Job to Patient" goes; (6) STL export must be reachable (it exists, hidden);
(7) accordion styles fixed (diagnosis in §7); (8) event wiring without the second DI container (§1).
Out of this board: dental backend tables/services cut (board 7, needs its own recon), cloud-drive modal,
privacy/terms footer links (sprintray.com URLs, text is generic), `f-autocomplete-v2` click bug (no field
left on /print-setup uses it after the patient typeahead goes).

## §0 Facts that shape the board

1. The AWS emulator is **in-memory**: `aws-emulator --help` has no persistence option; the bucket
   `rwc-files-local` is re-created by `infra/bootstrap.mjs` on every start. Postgres (`rwc-pg-data` volume)
   keeps the `PlatflormJob` rows. So a project row can outlive its files.
2. `DELETE api/platform-job/{id}` is a **soft delete**: `ServiceLayer/Services/PrintList/PlatformJobService.cs:710-717`
   sets `PrintJobStatus = Deleted`; `DeleteGroupJobAsync` :719-728, `DeleteAllAsync` :730-741 same. Nothing
   touches S3. No `DeleteObject` call exists in that service.
3. There is **no `/files/` endpoint** in the backend (`Web/Startup.cs:240-252`: `UseRouting` + `MapControllers`,
   every controller is `api/...`). The screenshot 404s are FE requests to a URL nobody serves and a key nobody
   writes (§6).
4. **STL export exists**: `renderer.component.ts:2050-2069` `exportComposedSTLFile()` (vendored
   `shared/libs/STLExporter.js`, binary, `downloadFile(..., 'platform.stl', 'text/plain')`). Triggers: the
   hidden button `platform-setup.component.html:137-141` (`*ngIf="false"`) → `exportSTL()` :1244-1246 →
   `ExportSTLAction` counter → renderer subscription :414-419; and Ctrl/Cmd+E :2146-2149 (gated by `canViewDelta`).
5. The "Add" button makes no HTTP call: `selectNewJob()` → `SetCurrentPlatformJobIdAction(null)`; the job is
   created by `POST api/platform-job` only when files are uploaded (`platform-setup.component.ts:1199-1211`).
   The current job id is store state persisted to localStorage (`core/store/reducers/index.ts:58-62`), no route param.
6. `resetPlatformJob$` (`core/store/effects/print-list.effects.ts:411-480`) **auto-selects** a job whenever the
   current id is null and the list is not empty (:453-464) → "deselect only" is unstable while other jobs exist.
   This is the one effect the single-project flow must change.
7. `EventBus` (`SprintRay.EventBus/EventBus.cs`): handlers are **instances captured at Subscribe time** in a
   **static** list (:11-12, :34-42); `Publish` (:23-32) never touches the provider. `IEventBus` and all 34
   handlers are `Scoped` (`Startup.cs:186`, `ServiceCollectionExtenstions.cs:201-247`), resolved today from the
   root of a throwaway `BuildServiceProvider()` (:256-257) that has no scope validation. Moving the
   subscriptions to the app container means changing those lifetimes (every handler injects only
   `IServiceScopeFactory`, so Singleton is correct) or resolving inside a scope.

## §1 Backend event wiring (task 6000)

- `SprintRay.EventBus/`: `EventBus.cs` (static `handlers` list :11-12; ctor captures `IServiceProvider` :16-21;
  `Publish` :23-32 sync, no try/catch, matches on `GetType().Name`; `Subscribe<T,TH>` :34-42 resolves `TH` once;
  `Unsubscribe` :44-50 compares with `nameof(T)` = literal "T", never matches, no callers), `IEventBus.cs`
  (Publish :5, Subscribe :7-9, Unsubscribe :11-13), `IDynamicIntegrationEventHandler.cs:5` (`bool Handle(dynamic)`),
  `IIntegrationEventHandler.cs` (unused by the bus), `IntegrationEvent.cs`, `EventRecord.cs`, csproj (M.E.DI 10.0.15).
- `Web/Infrastructure/Extensions/ServiceCollectionExtenstions.cs`: `AddEventHandlers` :199-252 (34 × `AddScoped<X>()`),
  `AddEventSubscriptions` :254-321 (`BuildServiceProvider()` :256-257, 40 `Subscribe<Event, Handler>()` lines :259-318).
  Every handler class and event class exists (events in `DTOs/EventModels/`); two file-name oddities:
  `EventHandlers/PrintList/PrintListItemAddedAddToPlatformJobEH.cs` holds class `PrintListItemPreprocessedAddToPlatformJobEH`,
  and `EventHandlers/PrintList/PrintListItemPatientChangedRegenerateSupportsEH .cs` has a trailing space in the name.
- Call site `Web/Startup.cs:185-188`: `services.AddScoped<IEventBus, EventBus>().AddEventHandlers().AddEventSubscriptions();`.
  Second `BuildServiceProvider()` in Web: `Startup.cs:90-92` inside `ConfigureApiBehaviorOptions` (resolves `ILogService`).
- Handlers: all 34 ctors take only `IServiceScopeFactory`; `Handle` opens `CreateScope()` and blocks with
  `RunSync()` (`Common/Extensions/TaskExtensions.cs:18,32`). `PrintListItemRemovedFromJobDeleteJobIfEmptyEH.cs:31,41`
  resolves `IEventBus` inside its scope and publishes again (so the bus must be resolvable from a scope too).
- Hub workaround (board 4): `Web/Infrastructure/Extensions/LocalRealtimeServiceCollectionExtensions.cs:29-51`
  (closure-shared `LocalRealtimeHub` :37-45, `ILocalRealtimePublisher` :46, `IAwsAppSyncService` scoped :47),
  called from `Startup.cs:146`. Consumers: `LocalRealtimeWebSocketMiddleware.cs:28,32`, `LocalRealtimeController.cs:28,32`,
  `ServiceLayer/Services/Local/LocalRealtimeAppSyncService.cs:19,23` (publishes when variables carry `{platformJobId,userId}`),
  handlers `PlatformJobUpdatedUpdateAppSyncEH.cs:43,50` and `PlatformJobChangedPostQueueMessageEH.cs:99,103`.
- `Startup.Configure` :225-262 does no DI work today (`UseLocalRealtimeIfEnabled` :235, `UseRouting` :240,
  `UseEndpoints` :250-253). `Program.cs:17-20` builds the host then `LocalDatabaseBootstrap.Run(host.Services)`;
  `Host.CreateDefaultBuilder` (:26) validates scopes in Development.
- Tests: no test builds the bus or calls `AddEventSubscriptions`/`AddEventHandlers`; 8 service tests use
  `Mock<IEventBus>`; `Tests/LocalRealtime/LocalRealtimeRegistrationTests.cs:84-95`
  `Development_EveryProviderBuiltFromTheCollection_SharesOneHub` simulates the two-container situation (it
  asserts the symptom's workaround; adapt it per ralph-plan rule 10, do not keep it as a fossil);
  `RoutesGoneTests.cs:23-39` builds a bare `ServiceCollection` (route table only). No WebApplicationFactory / Mvc.Testing.

## §2 Backend delete + S3 cleanup (task 6010)

- Controller `Web/Controllers/PrintList/PlatformJobController.cs` (route `api/platform-job` :18): `DELETE {id}`,
  `DELETE {groupId}/delete-group-job`, `DELETE delete-all` (service :70-80 on the FE side: `platform-job.service.ts:70-80`).
- S3: `ServiceLayer/Services/AWS/AwsS3Service.cs` (presign :88-106; client setup with ForcePathStyle/SigV4/emulator
  `ServiceCollectionExtenstions.cs:70-143`); folders in `Common/Configs/AwsS3Keys.cs` (`delta`, `individual`, `platform`,
  `platform-screenshot`, `merge`, `shared`, `inbox` :7, `export` :50). Key shapes: upload `inbox/{guid}{ext}`
  (`ServiceLayer/Services/Inbox/FileService.cs:430-432`); per model `delta/individual/{individualId}/{preprocessed|shared|cutted}/{id}.drc`
  (worker `workers/algorithms/src/steps/import.mjs:25-26`, `plane-cut.mjs:62-63`); per job `delta/platform/{jobId}/...`
  (`PlatformJobService.cs:1182-1191` PlatformImage.png, :893-912 .spr) and `delta/platform-screenshot/{jobId}/`
  (only copied at :1531-1534). `individualId` = the print-list item id used by `download-links`
  (`PlatformJobService.GetDownloadLinks` :814-835 presigns whatever key the client sends).
- Item/file relations: `AddFilesToPlatformJobAsync` :1209-1238 writes `PrintListItem` + `File` rows
  (`DTOs/Models/.../PrintListItem.cs`, `Inbox/File.cs`); the task reads these to list the keys of a job.
- Gate: `scripts/gate/lab-pipeline.mjs` (stages create/metadata/logs/edit; `treatmentTypeId: 1` :263, `patientId: null` :266-267);
  presigned URLs resolve through `http://127.0.0.1:45284/rwc-files-local/...` (aws-http), so "key gone" is observable
  as HTTP 404 on the presigned GET after the delete.
- `Tests/Controllers/PrinterRoutesGoneTests.cs:15,59` asserts `download-links` exists (keep).

## §3 Frontend: platform-job list, add, delete, save (task 6320)

Paths relative to `app/frontend/src/app`.
- Routes: `app.routing.ts:10-13,22-28,34-37`; `app-modules/delta/delta.routing.ts:17-22` (`PrintSetupPageComponent`,
  `canDeactivate: [CanDeactivateGuard]`). Page: `app-modules/delta/components/print-setup-page/print-setup-page.component.html:2-5`
  (`<delta-renderer>` + `<platform-setup>`).
- Three list widgets: (1) group tabs with hover screenshot `platform-setup.component.html:5-43` (`side-button`,
  `selectGroup`, `deleteGroupJob`, preview img :32-37 from `setSelectedScreenshotSrc` ts:1281-1297, base string ts:157);
  (2) vertical platform list `grouped-platform-jobs-vertical-pagination/**` mounted at `renderer/renderer.component.html:4`
  (shows only for groups > 1 platform; builds the screenshot URL ts:37,128); (3) "Platforms: 1 2 3 [+] [trash]"
  `grouped-platform-jobs-pagination/**` mounted at `platform-setup.component.html:127-130` (`createNewJob(true)`, `deleteCurrentJob()`).
- Header bar `platform-setup.component.html`: ⋮ `#deleteAllJobs` :46-57 → `deleteAllJobs()` ts:809-825; Import SPR :58-62
  → `selectNewJob(true)` (KEEP, SPR import is renderer territory); **Add** :63-67 (`icon-add-circle`, gtm
  `start-new-platform-job`) → `selectNewJob()` ts:463-470 → `selectJob(null)` ts:443-461; per-job ⋮ :85-98 Rename
  (`setTitleEditMode`), `#deleteMultiPLatform` → `deleteGroupJob`, `#deletePLatformJob` → `deleteCurrentJob()` ts:778-807
  (confirm `messages.areYouSureDeletePlatformJob` / `messages.deletePlatformJob`, then `DeletePlatformJobAction`).
- Store: `core/store/states/print-list.states.ts` (`currentPlatformJobId` :15, `getCurrentPlatformJob` :63-65, dirty selectors
  `getHavePrintSettingsUpdated` :109, `getHaveManualSettingsChanged` :157, `getShouldShowSaveEditingButtons` :177-180);
  reducers `core/store/reducers/print-list.reducers.ts` (`SET_CURRENT_PLATFORM_JOB_ID` :73-81, `RESET_PRINT_SETUP` :148-162,
  note the `platformJobTimers` typo there, delete-all optimistic clear in effects :391-393); effects
  `core/store/effects/print-list.effects.ts` (`GetPlatformJobs` :48-56 → `GET platform-job`, set-current side effects
  :483-489, `checkInitialPlatformJobsState$` :400-409, `resetPlatformJob$` :411-480 with auto-select :453-464 and
  empty-list reset :467-468, delete :328-350 (+toast :353-366), delete-group :369-385, delete-all :388-398,
  `refreshItems$` :579-590, save details :232-272, edit :593-640). `platform-job-updates.service.ts:62` dispatches
  `GetPlatformJobsAction` on every realtime user-job update (so the list refreshes by itself).
- Service `core/services/platform-job.service.ts`: list :34-36, get :38-40?, save POST :54-56, import-spr :62-64,
  rename PATCH :66-68, delete :70-72, delete-group :74-76, delete-all :78-80, download-links POST :95-98.
- Confirm dialog: `dialogs/modal.service.ts:54-84` `confirm(type, textKey, title, size, confirmText, cancelText, textAlign, ...)`
  → `ConfirmDialogComponent` (Enter = yes, Esc = no); worked example with custom buttons `platform-setup.component.ts:894-916`;
  `icon-btn [isConfirm] [confirmMsg]` (`shared/components/buttons/icon-btn.component.ts:20-46`).
- Fresh-job state: `clearPlatform()` runs on job change (`renderer.component.ts:451-464`, defined :1451); component
  cleanup on null `platform-setup.component.ts:547-572`; `ResetPrintSetupAction` resets most of the slice but not
  `groupedPlatformJobs`, `filesDropped`/`cloudDriveFiles`, `selectedModelIds`, `currentPlatformJobOperation`.
- Unsaved-changes plumbing that exists: `core/guards/can-deactivate.guard.ts:12-18` (`messages.unsavedInfo`),
  `print-setup-page.component.ts:92-100` beforeunload.
- Specs: `platform-setup.component.spec.ts` (init/tabs :102-140, :387-405; onNavChange :213-385; onFilesUploaded :539-545;
  no tests for selectNewJob/createNewJob/delete*), `print-list.effects.spec.ts` (delete* :152-160, :333-370; reset :464-478;
  set-current null :388), `print-list.reducers.spec.ts:212-242`, `platform-job.service.spec.ts` (:174-190, :214-230),
  `print-setup-page.component.spec.ts:233-260`, `platform-job-updates.service.spec.ts:140-142`. No specs for
  `grouped-platform-jobs-pagination`, `grouped-platform-jobs-vertical-pagination`, `side-button`, `can-deactivate.guard`.
- Known pin: `platform-setup.component.spec.ts:405` (clearing the job before the realtime client resolves throws on `currentJob.id`).

## §4 Branding (tasks 6300 i18n values, 6310 header/title)

Paths relative to `app/frontend/src`.
- Logo = icomoon glyph: `app/components/common/header/header.component.html:4-6` (`a.navbar-brand > span.icon-sprintray-logo.white`,
  authenticated header shown on /print-setup) and :103-105 (guest header); scss :17-19; glyph `assets/fonts/icomoon/style.css:684-686`
  (leave the font alone). Header mounted at `app/components/app/app.component.html:2`.
- Unreferenced logo files (delete): `assets/images/sprintray-logo.png`, `sprintray-logo-black.png`, `sprintray-favicon-png.png`,
  `assets/images/font-icons/sprintray-logo.svg`, `sprintray-logo-white.svg`, `assets/images/sprintray-pro-printer.svg`.
  `assets/images/logo-final.gif` is used only by `app-modules/delta/components/renderer-progress/**` (selector `.renderer-progress`,
  declared `delta.module.ts:38`, never placed in a template → dead; its per-type timing helpers are dead too) → deleted in 6340.
- `index.html:6` `<title>SprintRay Cloud</title>`, :9-10 meta description; no `Title` service usage; `favicon.ico` via `angular.json:21`.
- Banner `app/components/app/app.component.html:7` + ts:88-94,211-213 (`showReconnectBanner`), template
  `app/app-modules/common/notification-templates/network-disconnected-notification/network-disconnected-notification.component.html:6`
  key `messages.notConnectedToSprintRayCloud` (`assets/i18n/en.json:2508`). The banner is correct behaviour (board 4) — only the text changes.
- i18n values with "SprintRay" that templates use: `messages.notConnectedToSprintRayCloud` (2508), `general.cloudDriveWelcomeContent` (293),
  `messages.feedbackExperienceOne` (2117); unused ones at en.json lines 23, 291, 316, 324, 376, 807, 1508-1515, 1882, 2014, 2050, 2055, 2175,
  2345, 2348, 2408, 2432, 2441, 2444, 2452 (and `messages.youWillPerformTheSurgeryOnTheSelectedDay` 2496 used only by treatment UI).
- Specs: `header.component.spec.ts:90-99` (brand href `/print-setup`, no external links), `renderer-progress.component.spec.ts:55-58`.

## §5 Print Job Type picker (task 6340) and patient block (task 6350)

Paths relative to `app/frontend/src/app`.
- Picker component `app-modules/delta/components/print-job-type/**` (CVA, tiles `.print-job-type-card` html:6-18, no spec,
  declared `delta.module.ts:18,40`). Used in `platform-print-setup.component.html:27-37` (`[(ngModel)]="model.treatmentTypeId"`,
  `required`, `name="selectedPrintJobType"`; appliance sub-picker :33-36 for RemovableDentures/CrownAndBridge); :39 and :47 hide
  the build plate and the accordion while `!model.treatmentTypeId && !inSprImportMode`; NEXT `[disabled]="!applianceForm.valid"` :168.
- Data: `app.component.ts:251-252` dispatches `TreatmentTypeActions.GetListOptions` + `GetApplianceTypeListOptions`;
  `core/store/effects/treatment-type.effects.ts:20-47` → `GET api/treatment-type/list-options` + `appliance-type-list-options`
  (`http-object.service.ts:42-43,62-63`; both in `be-smoke.mjs:53,69` — the BE endpoints stay until the dental cut);
  states `treatment-type.states.ts:20,22`; `platform-print-setup.component.ts:77-84` `allowedTypes`, :140-152 sort/filter;
  `core/helpers/common/appliance-type-helper.ts` names :96-121, images :156-182 (`assets/images/print-job-types/`, 13 files).
- Flow: `treatmentTypeSelected()` ts:468-500 (Custom → `Unset`), `applyNewJobDefaults()` :504-526, `selectDefaultBuildPlate()` :528-532,
  `initializeForInexistingPlatform` :431-434 (no default type today), model `core/models/print-list/save-platform-job-input-model.ts:8-9`.
- Validity: `core/store/states/print-list.states.ts:132-153` (`getArePrintSettingsValid`, expression :144-149: treatmentTypeId &&
  applianceType in enum && buildPlateId && orientation); consumers `platform-setup.component.ts:260-265,371-386` (`isPrintButttonDisabled`
  also compares `currentJob.treatmentTypeId !== model.treatmentTypeId` :377-378), `renderer.component.ts:389-394`;
  `getHavePrintSettingsUpdated` compares type/appliance :113-114.
- Branches on type on /print-setup: `platform-print-setup.component.ts:400-414` getters (`isCustomJobType`, `isModelJobType`,
  `isCrownAndBridgeJobType`, `showCrownRaft`) used by html:73-79 (supports slider: Custom/SmileDesign/CrownAndBridge), :90-103
  (orientation input, Custom only → always on), :105-126 (SmileDesign only → dead), :128-147 (CrownAndBridge raft → dead);
  ts:340-350 SPR import defaults, :549-553, :595-603, :385-387, :370 (`isSprImportFull`, Unset is falsy), :326-334 SPR metadata type.
  `platform-model-list.component.html:245-259` raft (dead), ts:636-640 `shouldSortFiles` (SmileDesign), ts:1154-1160 `supportsLabel`
  (compares a treatment-type id with an appliance enum value — dead with Custom), presets ts:236-244 do not branch.
  `renderer-progress.component.ts:65-100` per-type timings (dead component). `renderer.component.ts:1073-1076` colour by appliance (0 → default).
  `platform-setup.component.ts:308-316,600-616` copy type from the job (harmless), :676-681,722-724 move-items checks (go with 6320).
  `print-list.reducers.ts:436-451` resets the model from `currentJob.treatmentTypeId`.
- Backend already accepts 100: seed `app/backend/DataLayer/Scripts/LocalSeed/030-treatment-types.sql:9-25` (`(100,'Custom/User Defined')`,
  `SprModelCount (6,100,1)`), `MapApplianceTypeId` passes 100 through (`Common/Extensions/TreatmentTypeExtentions.cs:5-26`),
  `PlatformJobInputModel.cs:18` `int TreatmentTypeId` non-nullable, entity FK `PlatformJob.cs:29-32`.
- Specs: `platform-print-setup.component.spec.ts:33,113-144,169-235`, `print-list.states.spec.ts:34-60` (null type → false :50-53),
  `platform-setup.component.spec.ts:430`, `appliance-type-helper.spec.ts`, `renderer-progress.component.spec.ts:250-290`.
  Gates: `lab-ui.mjs:28-34,80,200-227,280-281,338-343` (banner stage needs `.print-job-type-card`; upload clicks the first card),
  `lab-pipeline.mjs:263` `treatmentTypeId: 1`.
- Patient: template `platform-print-setup.component.html:12-25` (`f-typeahead name="patient"`, inside `[hidden]="currentJob"`;
  keys `general.patientName`, `general.assignPrintJobToPatient`); handlers ts:556-564; base `base-platform.component.ts:299-311`
  (`searchPatients` → `PatientService.search` + fake id 0 "Add New Patient"), :313-343 (`onPatientSelected` → id 0 opens
  `PatientDialogComponent` via `core/services/patient-helper.service.ts:18-31`, sets `model.patientId` :330; existing patient →
  `RenamePrintListItemAction` PATCH `api/print-list/{id}/rename`). Per-item patient rename on the model list:
  `platform-model-list.component.html:136-138` → `print-list-item.component.ts:192-196` / html:21-22.
  `patient-modal-v2`/`patient-v2` are NOT this flow (cloud-drive only). `PatientService` (`core/services/patient.service.ts:24-31`)
  stays (cloud-drive uses it); `PatientHelperService` injected in `grouped-platform-jobs-pagination`, `platform-setup`,
  `platform-model-list`, registered `core.module.ts:143`. Payload: `save-platform-job-input-model.ts:12-13` (`patientId?`, `patientName`),
  reducer `print-list.reducers.ts:445-446`, BE `PlatformJobInputModel.cs:24` `int? PatientId` (optional; stays until the dental cut).
  Specs: `base-platform.component.spec.ts:255-275,203`, `print-list.service.spec.ts:89-93`.

## §6 Screenshot 404 (folds into 6320)

- URL built twice: `grouped-platform-jobs-vertical-pagination.component.ts:37,128` and `platform-setup.component.ts:157,1293`
  from `environments/environment.ts:22` / `environment.dev.ts:22` `platformScreenshotBucketUrl: 'http://localhost:45281/files/'`
  (trailing slash + `/platform-screenshot/` → `files//`). `printPreviewBucketUrl` :21 is unused.
- Nobody writes `delta/platform-screenshot/{id}/screenshot.png` locally: worker `steps/platform-process.mjs:3,9` says so; backend
  only copies the folder (:1531-1534); the renderer snapshot goes to `delta/platform/{id}/shared/PlatformImage.png` through the
  "Save print job" modal (`platform-file-download.component.ts:41-65`). Gate `lab-ui.mjs:259-263` ignores `/files/` responses.
- Decision: the two widgets that request it are deleted with the single-project UI; the environment keys go; lab-ui stops
  ignoring `/files/` and asserts there are no such requests.

## §7 Accordion styles (task 6370, diagnosis proven 16.11.2026)

- Commit 6d15ead (board 2, Angular 17) migrated `ngb-accordion`/`ngb-panel cardClass="panel-card"` to the directive API.
  ng-bootstrap 21 host classes: `accordion-item` / `accordion-header` / `accordion-button` (only with `ngbAccordionButton`) /
  `accordion-collapse` / `accordion-body` (`node_modules/@ng-bootstrap/ng-bootstrap/fesm2022/ng-bootstrap-ng-bootstrap-accordion.mjs:81,118,175,199,378`).
- Stylesheets still target the old DOM: `base-platform.component.scss:115-187` (`.settings-accordion .accordion ::ng-deep .panel-card
  .card-header / .card-body / &.panel-active .card-header .icon.toggle-arrow::before`), `platform-setup.component.scss:291-342`
  (`.editing-menu .accordion ::ng-deep .editing-panel-card .card-header / .card-body`), `platform-print-setup.component.scss:40-48`.
- Six headers: `platform-model-list.component.html:163,227,278,392,440`, `platform-print-setup.component.html:52`; each is
  `<div ngbAccordionHeader><button type="button" class="w-100">` (no `ngbAccordionButton`, no `.btn`) → browser default button look.
  Global `styles.scss`/`scss/` have no `accordion` rules. Fix = `.card-header` → `.accordion-header`, `.card-body` → `.accordion-body`.

## §8 Gates and the stage split (task 6200)

- `scripts/gate/lab-ui.mjs`: `STAGES = ['load','banner','upload']` :65, `run = {load, banner, upload}` :466, CLI check :85-91,
  stages run in order and only the selected ones can fail; `browser.newContext({ serviceWorkers:'block', viewport })` :432
  (`acceptDownloads` default true); `page.route('**/*')` :435-449; failure screenshot `dist/lab-ui-<stage>.png` :231-239;
  `stageUpload` :332-415 ends with one uploaded 20 mm box job (12 triangles → binary STL = 84 + 50·12 = 684 bytes) and its
  `.drc` fetched from `:45284`; header comment block :25-43. `page.waitForEvent('download')` is not used anywhere yet.
- Four tasks need new or changed stages (accordion, export, projects, job-type-less banner/upload) → one registry file
  would serialize them; 6200 turns the stages into `scripts/gate/lab-ui-stages/NN-<name>.mjs` modules loaded in filename order.
- `scripts/gate/lab-pipeline.mjs`: `treatmentTypeId: 1` :263 → 100 in 6200 (the BE accepts 100 today, so the gate is green
  before and after the FE change); the `delete` stage is added by 6010.
