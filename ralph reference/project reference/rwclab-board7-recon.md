# rwclab board 7 recon: the non-renderer cut of the backend + build plates with a type and a custom size

Read-only recon, 22.11.2026 (4 Explore agents + own reads). Repo `rwc-renderer-lab`, branch `ralph/standalone`,
HEAD 7dc0d4a. Paths are relative to the repo root; `BE/` = `app/backend/`, `FE/` = `app/frontend/src/app/`,
`GATE/` = `scripts/gate/`. Goal of the board: the backend keeps ONLY what the standalone renderer path uses
(upload STL -> project on a build plate -> edit -> export/delete), plus build plates get a technology (SLA | FDM)
and a user-defined size. Board 8 (character customization) comes after; nothing here anticipates it except the
three.js note in §9.

## 0. Decisions taken by the author (the user can veto any of them in the hand-over)

1. **Migrations are squashed.** 269 migrations + snapshot (540 files) go; one `Initial` is scaffolded from the
   trimmed model. Reason: 147 Designer files reference dental CLR types (`List<TreatmentInfoResponse>`,
   `List<TreatmentInfoSection>`, `TreatmentTypeFileGroup`), so the dental classes cannot be deleted while the
   history stays (§3). There is no production database; the only volumes are local and throwaway.
2. **`RWC_DB_RESET_ON_UNKNOWN_MIGRATIONS` defaults to `true` in docker-compose.yml** (the appsettings default
   stays `false`). Every existing `rwc-pg-data` volume holds the 269 old ids; without the flag the backend refuses
   to start after the squash, and the swarm's worktrees share ONE Postgres volume (old-branch gates and
   squashed-branch gates alternate during the run). The data lost is local test jobs; S3 objects in the
   in-memory emulator never survive a restart anyway.
3. **The app shell stops calling the backend for anything but preferences and build plates.** `users/info`,
   `users/idle-period`, `users/update-login-date`, `users/{id}/profile-picture`, `organization/*`,
   `stripe/.../exp-days`, `user-notification/*`, the 4 dental list-options, `auth/is-missing-linked-dso-user`
   all go (§2, §5). The page needs none of them to render (FE recon §2: the org/office reads only feed booleans
   nobody uses). The stub token keeps its claims (4 copies of the contract; `is_promo_user`/`reg_completed` are
   JSON-parsed by the auth reducer and must exist).
4. **Deleted with the cut (not renderer features):** Feedback (controller, service, SES mail handler, tables,
   `<app-feedback>` widget), notifications (banner, new-feature, halloween, exp-days alert, notification center),
   the cloud-drive modal + patients (reachable only through `hasDexisFiles`), `.spr` import/export (SprintRay's
   encrypted print-job format: needs a decrypt Lambda the lab does not have; its header button is what confused
   the user on 20.11), privacy/terms links and the "resin / resin volume" labels in the renderer footer,
   LaunchDarkly backend service (flags are FE-local since board 2), the prod Auth0/AppSync classes
   (`LocalAuth0Service` and `LocalRealtimeAppSyncService` become the only registrations).
5. **Build plates:** `BuildPlate.Technology` (Sla = 1, Fdm = 2) + `IsPreset`; presets: 1 "SLA 182 x 103 mm"
   (today's default geometry, SprintRay Pro95), 2 "SLA 128 x 80 mm", 3 "FDM 220 x 220 mm". The form becomes
   two steps: technology, then size (the presets of that technology + "Custom size" with width/depth/height in
   mm); a custom size is `POST api/build-plate` (a real row, reusable, listed under its technology);
   `DELETE api/build-plate/{id}` removes a custom plate when no job uses it (409 otherwise; presets 409 always).
6. **Renderer "swag" (user, 22.11):** the SLA plate is drawn as a hanging metal platform with a mounting
   bracket/arm to the Z mechanism at its back edge; the FDM plate as a flat bed. The printing surface stays at
   y = 0 and the models are NOT flipped (usability over realism; the bracket sits outside the printable footprint).

## 1. Routes: KEEP / DELETE by consumer evidence (FE services, gates, bridge)

Consumers: FE `ApiService` (`FE/core/services/common/api.service.ts`) to `http://localhost:45281/api/`;
be-smoke (`GATE/be-smoke.mjs:49-74`), lab-pipeline, lab-ui stages, callback-bridge (`workers/callback-bridge/src/route.mjs:10-11,46`).
No global `[Authorize]` fallback (`BE/Web/Startup.cs`): controllers without a class attribute are anonymous.

**KEEP (every action has a consumer after the FE cut):**
- `BuildPlateController.cs` `api/build-plate` GET (+ new POST/DELETE, §6).
- `Local/LocalRealtimeController.cs` (`[AllowAnonymous]`, Development only): GET `platform-job-logs/{guid}`, POST `platform-job-log` (bridge).
- `HealthController.cs` GET.
- `PrintList/PlatformJobController.cs` (`api/platform-job`): GET ``, GET `{id}`, POST ``, POST `{id}/move-items`, POST `{id}/files`, PATCH `{id}`, DELETE `{id}`, POST `{id}/download-links`, GET `{id}/platform-metadata`, GET `{id}/platform-metadata-print-details`, GET `{groupId}/multi-platform-space`, POST `{id}/edit`, GET `platform-image-upload-link`, POST `slice-done` (`[AllowAnonymous]`, bridge).
  - DELETE: PUT `{id}/print-job-to-rwc` :44, PUT `move-item-to-new` :79, GET `{id}/download-link` :100, POST `{id}/status-change` :183, POST `create-halloween` :203, POST `import-spr` :58, GET `{id}/spr-download-link` :191, GET `extract-spr-metadata` :197 (decision 0.4).
- `PrintList/PrintListController.cs`: POST `bind-print-list-item` (`[AllowAnonymous]`, bridge), POST `remove`. DELETE: POST `` :27, GET `` :34, PATCH `{itemId}/rename` :85.
- `Inbox/FileController.cs`: GET `upload-link` :137, POST `direct-upload` :45, GET `new` :129 (FE reads `hasDexisFiles` only; after the FE cut `file/new` can go too - keep it out of the FE start-up and delete the route).
  - DELETE: GET `{id}` :29, POST `upload` :54, POST `scanner-upload` :64, POST `confirm` :74 (`[AllowAnonymous]`, no local caller), GET `download-link` :144, the cloud-drive actions (POST `page` :37, PATCH `assign-patient/{pid}` :111, PATCH `delete` :120, GET `user-files-size` :151, POST `cloud-drive-enhanced-page` :158) and `FileController.CloudDrive.cs`.
- `Users/UserController.cs` (47 actions): KEEP only GET `{userId}/preferences` :408 (the FE crashes on null preferences). DELETE the other 46 incl. anonymous `register`, `forgot-password`, `{userId}/email`, `confirm-email`, `resend-code`, `check-if-confirmed`.

**DELETE whole controllers (no consumer after the FE cut):** Billing, StripeFile, StripeWebHook, Stripe (28),
Product, Promo, Campaign, Item, Treatment (81), TemplateTreatment, TreatmentDesignAction, TreatmentRatingReview(+Question),
TreatmentTag, TreatmentTypeFile, TreatmentSubType, TreatmentType, Tag, AITreatment, LiabilityApproval, DocumentLink,
Conversation, RayWareCloud, RayApp, SyncBoxDevice, FullContour, DynamicPassword, Lab, LabSlot, LabAssignmentRule, Office,
Manager, MasterDashboard (21), Dashboard, CustomerSupport, OrganizationExternalLab, OrganizationRegion, Organization,
StateRegion, Country, AbutmentBrand, ImplantBrand, ImplantLine, Role, UserPrivacy, PrivacyPreference, ExternalProvider,
Notification, NotificationEvent, NotificationPreference, UserNotification, Import, ImportOffice, ImportOrgRegion, ImportUser,
ScheduledTask, Integration, Integration3Shape, IntegrationMedit, BaseIntegrationProviderController, Patient, Auth,
PrinterType, CoverageType, Scanner, Tightness, TreatmentStatus, Feedback, NomController (base of the nom lists).
Base classes kept: `BaseController`. Tests pinning controllers: only `BuildPlateControllerTests`, `LocalRealtimeControllerTests`
(keep); `Tests/Controllers/PrinterRoutesGoneTests.cs:81` asserts `api/printer-type/` EXISTS -> flip to "gone".

**Gate facts:** be-smoke asserts 22 REST routes (header comment says 24, stale), 7 of them dental/printer lookups
(`treatment-type/list-options`, `treatment-type/appliance-type-list-options`, `printer-type/list-options`,
`coverage-type|scanner|tightness|treatment-status/list-options`) and the shell set (`users/info`, `idle-period`,
`update-login-date`, `profile-picture`, `organization/*`, `stripe exp-days`, `user-notification/*`, `file/new`).
After the board it asserts: `health`, `build-plate`, `platform-job`, `users/{sub}/preferences`,
`local-realtime/platform-job-logs/{guid}`, the WS hello/pong and the OPTIONS preflight. lab-pipeline (`GATE/lab-pipeline.mjs:263-288`)
and `GATE/lab-ui-stages/65-pending-form.mjs:99-123` POST `treatmentTypeId: 100, patientId: null, label: null, sliceOffset: 0`
and `parameters.{isAligner,needRaft,isSprImport,noGrayScale}`: Newtonsoft ignores unknown members (`BE/Web/Startup.cs:99`
defaults), so dropping the input properties cannot break them; they are cleaned anyway. `scripts/e2e.mjs` never calls the backend.

## 2. DI, services, event handlers (what the kept code pulls in)

- `AddDomainServices` (`BE/Web/Infrastructure/Extensions/ServiceCollectionExtenstions.cs:39-54`) registers by
  convention every `I{ClassName}` in ServiceLayer: deleting a service + interface deletes its registration. Explicit
  registrations: `AddLocalAuth0IfEnabled` (Startup:143), `AddLocalRealtimeIfEnabled` (:144), AWS clients
  (`AddAwsServices` :95-118: Cognito :95 and KMS :118 have no consumer), options Startup:102-127, generic repos :129-139,
  `IDynamoDBClient<>` :134 (RayApp only), Dashboard dynamo :138-139 (PrintRecords only), `StripeServiceFactory` :174,
  event handlers `AddEventHandlers` :202-248 (34) + `UseEventSubscriptions` :264-323 (44 Subscribe lines).
- `EventBus.Publish` is a no-op without a subscriber (`BE/SprintRay.EventBus/EventBus.cs:29-38`): unsubscribing is always safe.
- No Hangfire / IHostedService; "scheduled" work = `ScheduledTaskController` (delete).
- One AutoMapper profile by reflection (`BE/Web/Infrastructure/Mapping/AutoMapperProfile.cs:16-73`, `IMapFrom<>`,
  `IHaveCustomMapping`, `INom<>`); explicit maps :77 (Auth0 token -> delete), :83-84 (platform metadata, keep).
- **Handlers KEEP (8):** `EventHandlers/PlatformJob/*` (PlatformJobUpdatedUpdateAppSyncEH, PlatformJobChangedPostQueueMessageEH,
  ReprocessItemsEH, PlatformJobModelChangeSettingsEH), `EventHandlers/PrintList/*` minus PatientChanged
  (PrintListItemPreprocessedAddToPlatformJobEH, PrintListItemAddedPreprocessFilesEH, PrintListItemRemovedFromJobDeleteJobIfEmptyEH).
  DELETE 26 (incl. `PrintListItemPatientChangedRegenerateSupportsEH`: its publisher is the item rename route that goes,
  and `Feedback/FeedbackSendEmailEH`). `Tests/EventBus/EventBusWiringTests.cs:70` asserts `34` handlers -> 8.
  Event classes with neither publisher nor subscriber: `PrintListItemPreprocessedEvent`, `PlatformJobModelTranslated`.
- **Dental services pulled only through constructors of kept code (unhook first, then delete):**
  - `ITreatmentTypeService` in `PlatformJobService.cs:67`, used only at `:308` (`GetDetailAsync` -> SprModelCount); drops the chain
    TreatmentTypeService -> IPricingPlanItemService -> IStripeService -> StateRegion/Country/CampaignPromoCode/UserRegion/SecretsManager.
  - `IPatientService` in `Inbox/FileService.cs:47` (:70 assign-patient, :103 `DeleteAsync` patient guard, :202 enhanced page, :303/:307 upload);
    `ITreatmentFileService` :50 (:106 `IsUsedInTreatmentsAsync` in `DeleteAsync`); `IAuth0ApplicationService` :51 and `IExternalProviderService` :49 (:315-:320, upload route).
  - `IFeedbackService` in `PlatformJobService.cs:78` (field :46, never used).
  - `IFeatureFlagService` in `PrintListService` (only `:335`, the UVBleed flag -> delete the branch; LD goes).
  - PlatformJobService/PrintListService read `S3File.TreatmentFile.Treatment.TreatmentType` and `Patient` at
    PlatformJobService:109,114,258,630-634,1272-1274,1350-1387; PrintListService:75-76,313-318,362 (view models:
    `DTOs/ViewModels/Printer/PlatformJobViewModel.cs:22-28,51`, `PrintListItemViewModel.cs:28-38,64-69`).
  - `PlatformJobChangedPostQueueMessageEH.cs:127-158` sends `printJobTypeId`, `applianceTypeId`, `patientId` in the queue
    message; the worker echoes them (`workers/algorithms/src/platform-process-logic.mjs:50-51`).
- **Closure of kept services (25 files):** PrintList 3 (PlatformJob, PrintList, BuildPlate), Files 3, Inbox/FileService,
  FeatureFlag 2 (goes with LD), AWS 8 (S3, Sns(+IHttpClientFactory), Sqs, StepFunctions, Lambda, Ses(goes with Feedback),
  DynamoDb repo, Firehose log manager), Local 1, Auth0 3 (-> only LocalAuth0Service), RWCMetadataService, BaseService.
  Shell set (UserService, AuthService, AdminService, UserPreferenceService, DynamoUserService, OfficeService,
  OrganizationService, OrganizationRegionService, UserNotificationService): only `UserPreferenceService` survives.
  At least 77, up to 107 of 132 service files go; 122 interfaces follow; 64 of 78 controllers; 25-26 of 34 handlers.
- **Configs/options to delete:** Common/Configs AICrown3Shape*, AINightGuardConfig, NightGuardConfig, AppProps, RayAppConfig,
  CampaignConfig, CloseOldTreatmentsConfig, CommonStrings, DefaultLocale, DSOTenants, PasswordConfig, FCCase*, Import,
  Integration*, PatientDeletionConfig, PrinterTypes, StateRegionKeys, Stripe, TimeZones, TreatmentFileNames,
  TreatmentMandatoryInfo, UserAnonymousValues, VerificationCodeKeys, GrantTypes, EmailTemplateNames (whole, Feedback goes) and the
  zero-consumer ones (APIKeySources, CureDevices, Currencies, DeviceTypes, Integration, MaterializedViewNames,
  PlatformJobAlgorithmErrorCodes, QueryStringKeys, SqlColumnTypes, TokenKeys, WashDevices - check Tests first).
  Common/Options: AICrown3Shape(+SecretKeys), Auth3Shape, AuthFullContour, AuthMedit, ExternalAuthOptions, AwsKeyManagement,
  AwsS3LogFiles, AwsS3StripeFiles, Dashboard, RayWareCloud, JwtOptions, Stripe(+SecretKeys), Settings, AWSSecretsManager,
  SeasonalEvents, LaunchDarkly, AwsSes, Default, DomainSettings (CORS reads it: check `Startup.cs:192` before deleting).
  appsettings.json sections: Auth3Shape :32, AuthFullContour :46, AuthMedit :65, AICrown3Shape :76, AWSS3LogFiles :112,
  AWSS3StripeFiles :117, AWSSecretsManager :148, AWSKeyManagement :157, RayWareCloud :192, Stripe :195, Settings :226,
  Dashboard :245, SeasonalEvents :248, DesignLabService :257 (+ the Development copies :33-146) and the dental DynamoDB table
  names (prod :126, dev :73). Resources: `GraphQLResource.resx` keep `PlatformJobUpdateMutation` only; `EmailTemplateResource.resx` goes.
- **Projects:** `Backend.sln:22,113-122` `SprintRay.IntegrationTest` is compiled by be-build but not tested (needs Docker socket +
  real Auth0; `utils/TestDBInitializer.cs` has 11 dental references) -> remove from the solution and delete the folder.
  `Database/*.sqlproj` is not in the sln (delete the folder). `CodeDeploy/` is a legacy EC2 deploy (delete). Dockerfile publishes
  `Web/SprintRay.Web.csproj` only.
- **Poison files (one task at a time):** `ServiceCollectionExtenstions.cs`, `Startup.cs`, `AuthorizationOptionsExtensions.cs:17-151`
  (~30 policies; `PolicyNames.cs` used in 54 files), `Common/Configs/{Messages,EntityNames,NotificationEvents,PolicyNames}.cs`,
  resx files, `appsettings*.json`, `DataLayer/SprintRayContext.cs`, `Backend.sln`, `README.md`.

## 3. Data model and migrations

- `BE/DataLayer/SprintRayContext.cs` (693 lines): 134 DbSets, 139 entity types (133 tables + 6 keyless `ToView` :398-420).
  All migrations bind `SprintRayWriteContext`; `SprintRayWriteContextDesignTimeFactory.cs` (keeps `Npgsql.EnableLegacyTimestampBehavior`,
  without it a scaffold emits 272 timestamp->timestamptz AlterColumns) stays.
- **Entities that survive:** PlatformJob (DbSet `PlatflormJob`, table "PlatflormJob"), PrintListItem, PrintListItemIndividualModel,
  BuildPlate, S3File, S3Folder, File, User, UserPreference, Role, UserRole. Everything else (incl. Doctor, Office, Organization,
  Country, StateRegion, CloudTabFile, ExternalProvider, PrinterType, TreatmentType(+SprModelCount), Feedback*, UserNotification*,
  Notification*, Patient*, Treatment*, Lab*, Product*, Campaign*, Import*, the 6 views) goes.
- **Columns to drop on kept tables:** `PlatflormJob.TreatmentTypeId` (FK, `DTOs/Models/Printers/PlatformJob.cs:29-32`),
  `TreatmentApplianceType` (:34), navs `RwcFeedbacks`/`LiabilityApprovals` (:45,52), `[NotMapped] IndividualModelCount` (:55-63 uses
  TreatmentType.SprModelCount); `PrintListItem.PatientId` (`PrintListItem.cs:44-47`), `Label` (:42, also raft text at
  `PrintListService.cs:380` - decide: keep Label out), `[NotMapped] TreatmentApplianceType/IndividualModelCount` (:52-71);
  `File.PatientId` (`DTOs/Models/Inbox/File.cs:34-37`), `ExternalProviderId` (:29-32), `IntegrationFile` nav (:47), `AppointmentDate`,
  `DeviceId` (:39,45), custom map (:59-67); `UserPreference.DentalNotation` (`User/UserPreferences.cs:23`, seed 060); `User` navs
  Doctor/Designer/Admin/OrganizationRegion/PromoCodes/NotificationPreferences/UserPartnerTokens/LiabilityApprovals/Feedbacks/Tags
  (`User/User.cs:39-74`, fluent `SprintRayContext.cs:315-325`); `S3File` navs Billing/TreatmentFile/LiabilityApprovalFiles/
  FeedbackFiles/TreatmentPayments (`S3/S3File.cs:39-57`; Source enum converter :426-431 stays).
  Fluent config that stays: `SprintRayContext.cs:333-345` (PrintListItem->PlatformJob cascade, PLIIM composite key), :347-358
  (UserRole), :580-595 (PlatformJob.GroupId default `UUID_GENERATE_V4()`, BuildPlate FK restrict, BuildPlate HasData).
- **Why squash:** 269 migrations, each with a Designer; 147 Designers reference `List<TreatmentInfoResponse>` /
  `List<TreatmentInfoSection>` (`DTOs/Models/Treatment/JsonMapping/TreatmentInfo.cs:7,56`) and 22 reference
  `TreatmentTypeFileGroup`. 25 migrations run raw SQL: `CREATE EXTENSION "uuid-ossp"` (`20211015210609_AddProductOnCloudSchema.cs:12`,
  needed by `GroupId`), views `TreatmentsPage`, `CloudTabPage` (`20220614090146_ChangeFriendlyNameColumn.cs:20`, reads
  File.PatientId - a drop migration would have to drop the views first), procedures `close_old_treatments`, `refresh_master_dashboard_mv`.
  `DataLayer/SprintRay.DataLayer.csproj` has 134 dead `<Compile Remove="Migrations\...">` entries.
- **How board 5 scaffolded:** dotnet-ef 10.0.15 installed inside `mcr.microsoft.com/dotnet/sdk:10.0` through `GATE/be-exec.cmd`
  (the repo's `Web/.config/dotnet-tools.json` pins dotnet-ef 3.1.3, useless on net10); `-c SprintRayWriteContext`; Up/Down then
  hand-edited (`20261116080713_BuildPlate.cs:10-15,49`: InsertData + `ALTER TABLE "BuildPlate" ALTER COLUMN "Id" RESTART WITH 4`).
  The exact command is not recorded in the repo: `dotnet tool install --global dotnet-ef --version 10.0.15` then
  `dotnet ef migrations add <Name> -p DataLayer -s DataLayer -c SprintRayWriteContext` (the design-time factory makes `-s DataLayer` work).
- **Bootstrap:** `BE/Web/Infrastructure/LocalDatabase/LocalDatabaseBootstrap.cs` (Development + `Database:MigrateOnStartup=true`,
  compose :132): compares applied vs known migrations (:118-119); unknown + flag false = log error and continue -> `Migrate()` fails
  on "relation already exists" -> backend refuses to start (:143-146); flag true = `DROP SCHEMA public CASCADE; CREATE SCHEMA public`
  (:56, :90-96); then `Migrate()` :123 and every `DataLayer/Scripts/LocalSeed/*.sql` in ordinal order in one transaction (:125-135).
  Compose: `RWC_DB_RESET_ON_UNKNOWN_MIGRATIONS:-false` (`docker-compose.yml:134`), volume `rwc-pg-data` (:99) shared by every worktree.
- **Seeds:** `010-local-stub-identity.sql` (Country, StateRegion, Organization, Office, Role Doctor, User `local-stub|doctor`, Doctor,
  UserRole) -> trim to Role, User, UserRole; `020-printers.sql` (PrinterType) delete; `030-treatment-types.sql` delete;
  `040-s3-folders.sql` (S3Folder "inbox") keep; `050-list-options.sql` delete; `060-local-stub-preferences.sql` keep, drop DentalNotation.
  `Tests/Extensions/LocalDatabaseBootstrapTests.cs:117-126` requires the seed text to contain `'local-stub|doctor'`, `'doctor@local-stub.test'`,
  both GUIDs and `'inbox'` (:85-113: INSERT-only, `ON CONFLICT DO NOTHING`, no braces); :49-61 instantiates
  `Migrations.SwitchPatientFromDoctorToOffice` (goes with the squash; rewrite); `Tests/BuildPlate/MigrationSnapshotTests.cs:98-107`
  requires an id ending `_BuildPlate` (rewrite to "exactly one migration, named Initial"), :50-96 keep (HasData, BuildPlateId required/restrict).
- **Tests touching dental entities:** `Tests/PlatformJob/PlatformJobServiceCreateTests.cs:110-111,136-137,152,191-192,218-219`,
  `PlatformProcessMessageTests.cs:54-55`, `PrintListServicePreprocessTests.cs:40`, `Tests/Mapping/AutoMapperProfileTests.cs:30,38-43,173`,
  `Tests/Services/FileServiceTests.cs:36,87-88,131-132,280,350-360,660-665`, `PrintRecordsServiceTests.cs`, `TreatmentServiceTests.cs`,
  `TreatmentFileServiceTests.cs`, `TreatmentHelperServiceTest.cs`, `PatientServiceTests.cs`, `UserServiceTests.cs`,
  `ConversationServiceTests.cs`, `CampaignPromoCodeServiceTests.cs`, `UserConversationServiceTests.cs`, `BillingServiceTests.cs`,
  `OfflineExternalServicesTests.cs`, `Extensions/StripeExtensionsTest.cs`, `Tests/PlatformJob/ServiceFactory.cs`.

## 4. Frontend leftovers (what still sends or shows dental/printer data)

- Save payload `FE/core/models/print-list/save-platform-job-input-model.ts:9-13` (`treatmentTypeId = Custom`, `treatmentApplianceType = Unset`,
  `sliceOffset = 0`, `label`), `platform-job-parameters.ts:8-11` (`isAligner`, `needRaft`, `isSprImport`, `noGrayScale`);
  `platform-job.ts:12-15,21`; `platform-job-details.ts:7-9` (dead class); `print-list-item.ts:8-10,14-15,31-35`
  (`patientName`, `label` USED by `print-list-item.component.html:19,21,24` as the item title fallback -> filename only);
  `platform-metadata.ts:76-81,100-105` (SPR metadata printDetails); `renderer/model-info.ts:8`, `model-mesh.ts:9,15,20` (`applianceTypeId`
  drives `RenderingColors.appliance(id)` `FE/core/constants/renderer-constants.ts:26-39,82-84`: `applianceColors[0]` is white, so every
  "Other Print" job is WHITE today while the pre-upload preview at `renderer.component.ts:1073-1076` is blue -> replace the helper by one
  model colour, a deliberate visual decision: keep white for models); `base-model.ts:1,19-25,45-46`; `file-input.ts:6`; enums
  `FE/core/enums/treatment/treatment-type.enum.ts`, `treatment-appliance-type.enum.ts` (imported by the save model, `renderer-constants.ts:2`,
  `platform-metadata.ts:1`, `platform-job.ts:1`, `platform-job-details.ts:1`, `base-model.ts:1`, `info-box-visibility.states.ts:2`, `file-helper.ts:1`).
- Store: `print-list.reducers.ts:413-418` (RESET model copies the fields), `print-list.states.ts:114,120-123,138` (compare/valid rules on
  sliceOffset/isAligner/noGrayScale/needRaft), `info-box-visibility.*` dead slice (`showTreatmentInfoNotes{treatmentTypeId}`).
- Components: `platform-print-setup.component.ts:240-262` (`initPlatformFromSpr`), `.html:46` (`isAligner` label), `:95-97` timer button (SPR 15 s);
  `platform-setup.component.ts:259-269` (fallback model), `:330-336` (dead comparisons), `:597-606` (move guards by appliance type -> delete),
  `.html:15-17` (SPR icon-btn + drop), `.html:35` (`treatmentApplianceTypeName | translateValue` subtitle -> created date only);
  `platform-setup.component.ts:357-400,903-912` (SPR mode), `print-setup-page.component.ts:30,74-79,95` (appliance map), `renderer.component.ts:593,
  1216,1307,1359,1382,1514-1539` (colour by appliance), `:1073-1076`, `renderer.component.html:40` (resin/resinVolume), `:46,50` (privacy/terms ->
  `FE/core/constants/privacy-term-links*.ts`), `:53` `<app-feedback>`, `:62` `<new-feature-notification>`; `printability-check.service.ts:71`;
  `platform-model-list.component.ts:477-484` (`setAnnotation` prefills from `patientName`), `:1034-1047` + `.html:16,64` (Cloud Drive link,
  `hasDexisFiles`), `platform-file-download.component.ts:54,68` (platform image + spr-download-link).
- Shell: `app.component.ts:98-123,174-178,227-262` (init: 4 list-options, `file/new`, banner-latest, has-unread, build-plate, preferences,
  `idle-period`, DSO check), `auth.effects.ts:153-187` (`users/info`, stripe exp-days, `GetIsConnectedAction` and
  `TemplateTreatmentActions.GetRegionListOptions` = no-op dispatches, `platform-job`, `organization/*`, preferences, `update-login-date`),
  `picture.effects.ts:24` (profile picture), `notification.effects.ts:40-61`, `app.component.html:4-7` (`<exp-days-alert>`, `<notification-banner>`,
  network-disconnected = keep), header `components/common/header/header.component.ts:60,85-104` (cloud icon, avatar), `auth.reducers.ts:59-110,141-157`
  (`isMissingDoctorClaims`), guards `auth.guard.ts:24-28`, `reg-auth.guard.ts:23` (`appAccounts` redirect), `auth0.service.ts:28-51,56-64,78-102`
  (stub token; real `auth0.WebAuth` still constructed), `auth.service.ts:29-43` (dead account/* routes), `app.service.ts:18`, `item.service.ts`,
  smart-table (`SmartTableService`, no template uses it), `TreatmentSubTypeEffects` registered at `app.module.ts:98` and never triggered.
- Feature flags: `feature-flag-store.service.ts:13-21` emits `default-feature-flags.ts:29-52` (all false; `stream-syncing` false => plain REST,
  the APIG `api/g/` path `apig.service.ts:8` is dead). Flags read: cloud-drive, cloud-drive-upload, unblock-manual-editing-menu,
  upload-model-preview, collision-detection, stream-syncing, halloween; 15 never read.
- Modules to delete wholesale: `FE/app-modules/cloud-drive/**`, patient components (`app-modules/common/version-2/patient-modal-v2/`,
  `patient-v2/`, `assign-patient`, `patient-search`, `cloud-drive-patients`), `notification-templates/**` (halloween, new-feature,
  new-version, banner, exp-days-alert, notification-center), feedback dialog/components, `sub-type-templates/**`, 2d-viewer / 2d-viewer-v2 /
  tooth-note, `core/constants/treatment/*`, `treatment-viewer-constants.ts`, `treatment-type-preview-images.ts`, `core/helpers/common/new-treatment-helper.ts`,
  `file-helper.ts:3-133` (keep `dataURLtoBlob`), `core/models/treatment/*`, `core/models/patient/*`, services patient/user-notification/stripe/
  organization/item/app/auth(dead parts), store slices coverage-type/scanner/tightness/treatment-status/treatment-sub-type/template-treatment/
  organization/notification/picture/stripe/info-box-visibility, `timer-button`.
- i18n: `node scripts/i18n-orphans.mjs` (2471 keys, 1575 unreferenced today; it counts spec references, so negative-assertion keys look used).
  Keys named in surviving templates that go with the features: `general.importSavedPrintJobSpr`, `general.resin`, `general.resinVolume`,
  `general.privacyPolicy`, `general.termsConditions`, `general.generateStandingBase`, `general.cloudDrive`,
  `messages.platformJobDifferentApplianceTypeError(Title)`, `messages.platformJobDifferentAlignerTypeError(Title)`,
  `messages.notConnectedToSprintRayCloud` (network banner text, rename to the backend wording of 6300: `messages.notConnectedToBackend`).
- Spec files pinning the fields (edit with the code): platform-print-setup, platform-setup, print-setup-page, print-list.reducers,
  print-list.states, platform-job.service, platform-file-download, platform-model-list, header, file-helper, info-box-visibility.reducers,
  local-auth-stub, auth-helper.service, and the renderer service specs constructing `ModelMesh` with `applianceTypeId: 0`.

## 5. The stub token and start-up after the board

- Token: `FE/core/services/common/auth0.service.ts:28-51` builds the unsigned JWT; copies in `GATE/be-smoke.mjs:91-110`,
  `GATE/lab-pipeline.mjs:62-84`, `GATE/lab-ui-stages/65-pending-form.mjs:27-40`, `BE/Common/Auth/LocalStubToken.cs`,
  `BE/Tests/Extensions/LocalUnsignedTokensTests.cs`. UNCHANGED by this board (claims stay, incl. org/office ids).
- Start-up REST after the board: `GET build-plate`, `GET users/{sub}/preferences`, `GET platform-job`, the WS; when a job is open:
  `local-realtime/platform-job-logs/{id}`, platform-metadata, download-links. be-smoke asserts exactly that set.
- Backend policies: keep `Doctor` (PolicyNames) for the kept controllers; `AuthorizationOptionsExtensions.cs` keeps only the policies
  the kept controllers reference (grep `[Authorize(Policy` in the 6 kept controllers before trimming).

## 6. Build plates: contract (BE 7020, FE 7320, renderer 7330)

- Entity `BE/DTOs/Models/Printers/BuildPlate.cs` (board 5): `{Id, Name, WidthMm, DepthMm, HeightMm, Shape}`; HasData in
  `SprintRayContext.cs:592-595`; `BuildPlateService`, `BuildPlateController` GET; FE `core/models/build-plate`, store feature `buildPlate`
  (`build-plate.effects.ts:23`, dispatched at `app.component.ts:257`), form control `f-button-group[name="buildPlate"]`
  (`platform-print-setup.component.html`), `PLATE` selector in `GATE/lab-ui-stages/_ctx.mjs:12`, `30-upload.mjs:37-53` (`fillRequired`),
  `65-pending-form.mjs:163-167`; renderer `core/services/renderer/platform-helper-objects.service.ts` (`show(scene, camera, plate, view, ...)`,
  draws Box/Cylinder + grid + walls of HeightMm), `renderer.component.ts:554-562` (`setPlatform`, `resolveBuildPlate`), worker message field
  `buildPlate {id,name,widthMm,depthMm,heightMm,shape}` (`PlatformJobChangedPostQueueMessageEH`), lab-pipeline asserts
  `printDetails.buildPlateName` and `buildPlateWidthMm == "182.4"` (`GATE/lab-pipeline.mjs:334-345`).
- **New contract:** `BuildPlate.Technology` enum `BuildPlateTechnology { Sla = 1, Fdm = 2 }` (int column, NOT NULL), `IsPreset` bool.
  Presets (HasData): 1 `{Sla, "SLA 182 x 103 mm", 182.4, 102.6, 200, Rectangle, IsPreset}`, 2 `{Sla, "SLA 128 x 80 mm", 128, 80, 150, Rectangle}`,
  3 `{Fdm, "FDM 220 x 220 mm", 220, 220, 250, Rectangle}` (heights: keep whatever board 5 seeded for 1-3; do not invent new numbers for existing rows).
  `GET api/build-plate` -> `[{id, name, technology: "Sla"|"Fdm" (string enum, Newtonsoft StringEnumConverter like `shape`), widthMm, depthMm,
  heightMm, shape, isPreset}]` ordered by technology, isPreset desc, name. `POST api/build-plate` body
  `{technology, widthMm, depthMm, heightMm, shape}` -> 201 + the row; validation 400: each mm in [10, 1000], shape Rectangle|Circle
  (Circle: widthMm = depthMm = diameter), technology Sla|Fdm; name generated `"{SLA|FDM} {W} x {D} mm"` (integers when whole, else one
  decimal; a duplicate of an existing plate of the same technology/size/shape returns the existing row with 200, no new row).
  `DELETE api/build-plate/{id}` -> 204; 404 unknown; 409 when `IsPreset` or when any PlatflormJob (any status) references it.
  Worker message unchanged. FE model gains `technology` + `isPreset`; the form = technology buttons (`f-button-group[name="technology"]`,
  values `Sla`/`Fdm`) then size buttons (`f-button-group[name="buildPlate"]` filtered by technology, last option "Custom size"
  = three `f-input` mm fields `customWidth/customDepth/customHeight` + "Add" -> POST -> the new plate is selected); a job's existing
  plate preselects both steps. i18n keys (added by 7320 itself; nobody else edits en.json in parallel because the FE lane is serial):
  `general.technology` "Technology", `general.sla` "SLA (resin)", `general.fdm` "FDM (filament)", `general.plateSize` "Plate size",
  `general.customSize` "Custom size", `general.widthMm` "Width (mm)", `general.depthMm` "Depth (mm)", `general.heightMm` "Height (mm)",
  `general.addPlate` "Add plate", `general.deletePlate` "Delete plate", `messages.plateInUse` "This plate is used by a project and cannot be deleted.",
  `messages.plateSizeRange` "Each size must be between 10 and 1000 mm".
- **Renderer (7330):** `platform-helper-objects.service.ts` draws per technology: SLA = a thinner metal-looking plate (height ~6 mm slab,
  darker metallic material) with a mounting bracket at the BACK edge (a vertical arm + a mount block rising above the slab, outside the
  printable footprint, width ~40% of the plate, no collision with the walls/grid), FDM = a thicker bed (~10 mm slab, lighter/matte) with no
  bracket. Printing surface stays y = 0; walls/grid/bounds unchanged; `getCurrentPlatform/getCurrentGridPlatform` keep returning the groups
  the raycaster uses (`renderer.component.ts:1846-1849`). Unit test: group children by name per technology (`bracket` present for Sla,
  absent for Fdm; slab thickness; printable bounds identical). lab-ui `30-upload`/`65-pending-form` keep picking the first enabled plate;
  a new stage `70-plate.mjs` covers the form (technology -> custom size -> Add -> selected -> upload -> print details show the custom width ->
  DELETE plate 409 while used -> after the project is deleted, DELETE 204).

## 7. Gates and sequencing facts for the board

- Full-stack gates (be-smoke, lab-pipeline, lab-ui) recreate the SHARED compose containers (`rwc-backend-1` etc.) from the running
  worktree: two tasks running them concurrently fight over the stack. The board puts them only on the last task of each lane and on the
  integration/docs tasks; intermediate tasks use be-build/be-test/fe-typecheck/fe-test.
- `be-build.cmd` builds `Backend.sln` (so IntegrationTest must compile until it is removed from the solution - do that first).
- `be-test.cmd [filter]` = `dotnet test Tests --filter`; `EventBusWiringTests` pins the handler count; `RoutesGoneTests`/`PrinterRoutesGoneTests`
  pin routes; `MigrationSnapshotTests` pins the model-vs-snapshot and the migration id; `LocalDatabaseBootstrapTests` pins seeds + a migration class.
- `fe-test.cmd [pattern]` (jest `--testPathPatterns`), ~4 min full; `fe-typecheck.cmd` ~21 s; `fe-build.cmd ci`.
- Worker: `workers/algorithms/src/platform-process-logic.mjs:50-51` echoes `printJobTypeId/applianceTypeId/patientId` into PrintDetails;
  tests `workers/algorithms/test/platform-process.test.mjs`. Bridge untouched.

## 8. Explicitly OUT of this board

Design-Service/ (never), the frontend three.js upgrade (board 8 prerequisite), any character/preset work (board 8), the worker's
algorithm set, the stub token contract, the realtime protocol, the S3 key layout, `scripts/e2e.mjs`.

## 9. Note for board 8 (so the author does not rediscover it)

three.js is `^0.125.2` (`app/frontend/package.json:57`); `three-stl-loader` npm, vendored `shared/libs/TransformControls.js` and
`DRACO-loader.tool`; `THREE.Math.degToRad` used (renamed `MathUtils` in r113, still aliased at 0.125). The migration guide r125 -> r188 has
~40 relevant breaking changes (colour management r152, `outputEncoding` -> `outputColorSpace`, WebGL1 removed r163, `three/addons` imports,
TransformControls derives from `Controls` r169 with `getHelper()`, DRACO decoder path `examples/jsm/libs/draco/` r148, `Raycaster` recursive default
true r133, morph targets: material `morphTargets` flag removed r131). The Actors project pins `three >= 0.180` (devDependency 0.186.1).
