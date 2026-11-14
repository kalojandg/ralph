# rwclab: structure reference

Repo: `D:\Downloads\monk\sprintray`, remote `kalojandg/rwc-renderer-lab` (private). Integration branch: **`ralph/standalone`**.
Read these first: `RENDERER-AUDIT.md` (full map of the renderer, calls, flow and pipeline), `PLAN.md`, `README.md`, `aws-emulator/README.md`.

## Goal of the board
_Статус (2026-11-13): бордът 2000–2320 е изпълнен и слят в `ralph/standalone`. Фронтендът е вече standalone; бекендът още НЕ е орязан._
_Roadmap (решение на потребителя, 2026-11-14): **board 2** (2500–2650) = (а) ЗАПУШВАНЕ на всички външни пътища на фронтенда — само localhost, без GTM/Stripe/Calendly/Fonts/Sentry/LaunchDarkly, AppSync клиентът става „изключен" клиент със същата повърхност; заявки към `localhost:45281` ПАДАТ нарочно, НЯМА локален API и НЯМА нова логика; банерът „Not connected to SprintRay Cloud" ОСТАВА и се показва (той казва истината: няма бекенд); (б) rxjs-compat → pipe, мъртви пакети, Angular 10 → 22 по един мажор на таск. **Board 3** = .NET ъпгрейд „както идва", закачане бекенд↔фронтенд и пренасочване на бекенда към локалния AWS емулатор — бекендът се ПАЗИ, не се заменя и не се трие. Разузнаването за board 3 е в `rwclab-local-aws-recon.md` (същата папка)._
Turn the copied SprintRay "Design Service" (RayWare Cloud) into a **standalone app**. Starting the app opens straight into the 3D renderer (`''` и `'**'` → `/print-setup` → `DeltaModule` → `<delta-renderer>`; останалите рутове: `/login`, `/not-authorized`, `/error`). Everything unrelated to RayWare/delta is **deleted**: treatments, patients, messenger, billing, dashboards, fleet, sync-box, campaigns, AI, and so on.
- Frontend: Angular 9 in `app/frontend`.
- Backend: .NET Core 3.1 in `app/backend`, cut down to the APIs the renderer uses.
- AWS: the local AWS Emulator (`aws-emulator/`, `infra/`, `workers/`), never real AWS.

## File map
```
RENDERER-AUDIT.md / PLAN.md / README.md   docs (audit = the source of truth for what to keep)
aws-emulator/        Dockerfile, env.sh, probes. Local AWS on https://127.0.0.1:9297
infra/               resources.mjs (names, state machines), bootstrap.mjs (idempotent)
workers/algorithms/  Docker worker: native mesh binaries via Step Functions Activities
scripts/gate/        fe-npm-ci.cmd, fe-typecheck.cmd, fe-test.cmd [pattern], fe-build.cmd [dev|ci|production] (Docker, Node 14)
scripts/e2e.mjs      upload → import → plane cut → events → download (npm run e2e)
docker-compose.yml   aws-emulator + algorithms-worker
app/frontend/        Angular 9 (copied from Design-Service/Frontend)
app/backend/         .NET Core 3.1 solution Backend.sln (copied from Design-Service/Backend)
Design-Service/      ORIGINAL SprintRay repo. Git-ignored, READ-ONLY reference. Never edit, never copy secrets from it.
```

### app/frontend: what stays (СЛЕД борда: това е останало; details: RENDERER-AUDIT.md §1.3–1.7)
- `src/app/app-modules/delta/**` (19 components; `renderer` is the 3D view).
- `src/app/core/services/renderer/**` (14 three.js services).
- `platform-job*.service.ts`, `print-list.service.ts`, `printer-platform.service.ts`, `s3-file.service.ts`, `inbox/inbox.service.ts`, `common/*` (api, appsync, aws-http-api, auth…).
- Store: print-list, platform-job-renderer, print-job, appliance-profile, defaults, resin, register, noms, feature-flag, auth, info-box-visibility, loading-mask.
- `src/app/shared/libs/*` (DRACO-loader, OrbitControls, TransformControls, OBJLoader, STLExporter).
- `src/assets/models/*.drc`, `assets/images/lighting/*`, `assets/fonts/helvetiker_regular.typeface.json`, `assets/i18n/*`.
- Partly kept: `app-modules/common` (renderer-instructions, feedback-dialog, notification templates, print-jobs-list/printer-card, network-disconnected-notification), `cloud-drive` v1 (only `CloudDriveModalComponent`), `login`.

### app/frontend: what went (ИЗТРИТО с борда #2240–#2310, RENDERER-AUDIT.md §1.6)
`version-2` (+ route `cloud-design`), `treatments`, `new-treatment`, `patients`, `cloud-drive-v2`, `dashboard`, `devices`, `fleet-management`, `administration`, `+inbox` (module only), `messenger`, `notification`, `support`, `+customer-support`, `registration`, `user-profile`, `integrations`, `+sync-box`, `+master-dashboard`, `+campaigns`, `+selective-updater`, `+factory`, `shared/components/model-viewer`, `shared/services/stl-loader.service.ts`.
`inbox.service` и inbox store/`InboxEffects` остават (delta model list чете броя нови файлове). `app-modules` сега съдържа само: `cloud-drive`, `common`, `delta`, `login`.

### Какво остава умишлено „дентално“ (README.md, секция standalone)
- `cloud-drive` v1 + `app-modules/common/version-2` patient компонентите, които то отваря (`PatientVersion2Component`, `PatientModalV2Component`) + `shared/components/version-2/forms` (`f-input-v2`, `f-select-v2`, …).
- `TreatmentType` enums и `treatmentType` store (print-setup appliance-type picker).
- `SetDSOOfficeComponent` и останалите noms list-option slices: извън renderer пътя, за по-късно почистване заедно с бекенда.

### Auth: локален stub (#2200)
`useLocalAuthStub` в `src/environments/*`: **true** в `environment.dev.ts` (конфигурации `dev` и `ci`), **false** в `environment.ts` (default serve/build и jest), staging, prod. `Auth0Service.fetchTokens()` връща unsigned фалшива сесия (един фиксиран потребител) и не вика Auth0. Това НЕ е автентикация; не се включва в staging/prod.

### app/backend
_Бекендът не е пипан от борда 2000–2320._
- Projects: Web, ServiceLayer, DataLayer (EF Core + Npgsql, 533 migrations), DTOs, Common, SprintRay.EventBus (in-process), SprintRay.Logger, Tests (MSTest), SprintRay.IntegrationTest, Database (sqlproj), CodeDeploy.
- **Keep:** `Web/Controllers/PrintList/*` (PlatformJob, PrintList, PrinterPlatform, ApplianceProfile), `PrinterController`, `Feedback/*`, `Inbox/FileController`, `Resins/*`, `HealthController`, plus the auth/user/feature-flag pieces the shell needs; `PlatformJobService`, `PrintListService`, `Services/AWS/*`, `Services/Files/*`, `EventHandlers/PlatformJob/*`, `EventHandlers/PrintList/*`.
- **Delete** (RENDERER-AUDIT.md §2.3): Billing, Campaign, CustomerSupport, Dashboard, Factory, Import, Integration, Lab, Manager, MasterDashboard, Noms (check what the frontend lookup lists use first!), Notifications, Organization, Payments, PowerBI, Privacy, Product, RayApp, SyncBox, Conversation, DocumentLink, LiabilityApproval, ScheduledTask, `Treatments/*`, Device/CloudTab/IotProxy/PrintJob (if "send to printer" goes).
- Every deletion must also remove its DI registration in `Web/Infrastructure/Extensions/ServiceCollectionExtenstions.cs` and in `Startup.cs`.

## Persistence and external contracts
| What | Where | Status |
|---|---|---|
| Postgres (EF Core, Npgsql) | `Startup.cs:65-68`, `SprintRayWriteConnection`/`ReadConnection` | Values are `<set-locally>`. Local Postgres in docker-compose is a future task |
| S3 / DynamoDB / SQS / SNS / Step Functions | AWS SDK | **only** through the AWS Emulator (`AWS_ENDPOINT_URL=https://127.0.0.1:9297`) |
| AppSync (job logs/subscriptions) | frontend `appsync.service.ts`, backend `AwsAppSyncService.cs` | the emulator has no data plane, so it gets replaced (WebSocket gateway, SNS→SQS `rwc-platform-job-logs-local`) |
| Auth0, LaunchDarkly, ResinOnCloud, Sentry, Stripe | environment/appsettings | external SaaS from SprintRay; unreachable or not ours. Auth0 е заменен във фронтенда от `useLocalAuthStub` (#2200); останалите още чакат local stub/flags файл |
| Job log message | `{algorithm, platformId, status(102/200/4xx/500), errorCode, timestamp}` | **live contract** between worker → events → frontend (`PlatformJobAlgorithm`/`PlatformJobAlgorithmStatus` enums) |

## RED LINES (violation = failed task)
1. **Never touch `Design-Service/`.** Don't edit it, don't `git add` it, don't copy secrets from it. It is read-only reference.
2. **No secrets in git.** Every secret value in config is `<set-locally>`. Never put back `appsettings.Production.json`, `Staging.json` or `DevelopmentAWS.json`, and don't add real keys, passwords or connection strings.
3. **Never real AWS.** Every AWS client has an explicit emulator endpoint (or `AWS_ENDPOINT_URL`). Code that would fall back to the real AWS default endpoint is forbidden. Tests never talk to the network outside localhost.
4. **Never commit the binaries.** `workers/algorithms/vendor/` stays git-ignored.
5. Don't break `npm run e2e` (the emulator flow) unless the task is explicitly about it.
6. Delete for real. Don't comment code out, don't leave dead routes or modules "for later".

## POISON LIST (shared files → solo lane, one task at a time)
- **Frontend:** `src/app/app.module.ts`, `app.routing.ts`, `core/core.module.ts`, `core/index.ts`, `core/services/index.ts`, `core/store/reducers/index.ts`, `core/store/states/index.ts`, `core/store/effects/*` index, `shared/shared.module.ts`, `shared/index.ts`, `app-modules/common/common.module.ts`, `components/common/header/*`, `app.component.ts`, `angular.json`, `package.json`/`package-lock.json`, `src/environments/*`.
- **Backend:** `Web/Startup.cs`, `Web/Infrastructure/Extensions/ServiceCollectionExtenstions.cs`, `Backend.sln`, all `*.csproj`, `DataLayer/*DbContext*`, `DataLayer/Migrations/*`, `Common/Configs/*`, `Web/appsettings*.json`.
- **Root:** `docker-compose.yml`, `infra/resources.mjs`, `.gitignore`.

Deleting a feature module almost always touches the frontend barrels, modules and routing at the same time. So deletions go **in sequence in one lane**; parallel work is only possible across zones (frontend ↔ backend ↔ infra).

## Commands and ports
- **Toolchain:** Node 24 on the host. Angular 9 needs **Node 14**, so the frontend runs in Docker `node:14-bullseye` with `node_modules` in volume `rwc-fe-node_modules`. .NET 3.1 runs in Docker `mcr.microsoft.com/dotnet/sdk:3.1` with NuGet cache volume `rwc-nuget`.
- **Gate скриптове (препоръчителни):** `scripts\gate\fe-npm-ci.cmd` (~8 мин, веднъж/при смяна на deps; никога два паралелно върху един volume), `fe-typecheck.cmd` (~70 s), `fe-test.cmd [pattern]` (jest, 2 CPU/2 workers), `fe-build.cmd [dev|ci|production]`. Бърза конфигурация **`ci`** (AOT, без optimization/source maps, #2010): 4:31 vs `dev` 8:08 (baseline преди борда 24:28 студено); `production` 7:29, зелен, извън gate.
- **Frontend build (gate):** `docker run --rm -v "<fe>:/w" -v rwc-fe-node_modules:/w/node_modules -w /w node:14-bullseye sh -c "npm ci && NODE_OPTIONS=--max_old_space_size=6144 npx ng build --configuration=dev"`.
- **Backend build/test (gate):** `docker run --rm -v "<be>:/src" -v rwc-nuget:/root/.nuget/packages -w /src mcr.microsoft.com/dotnet/sdk:3.1 sh -c "dotnet build Backend.sln && dotnet test Tests --no-build"`.
- **Local AWS:** `docker compose up -d --build` → `source aws-emulator/env.sh` → `npm run e2e`. ⚠ Uses 127.0.0.1:9297.
- **Ports:**
  - ⚠ The backend's `launchSettings` has 5000/5001/44352, and **5001 is taken** by party-up `be_dev`. Assign new ones: backend **45281**, frontend `ng serve` **45280** (task).
  - Fleet ports already taken: 45277–45279, 8081, 5001.
- **Forbidden for agents:** `ng serve`, `dotnet run`, `docker compose up` of long-running servers. Those belong to the gate and the user only.

## Test state
Измерено 2026-11-13 след борда (#2320), 0 errors / 0 warnings.
- Frontend: тестовете минаха от Karma/Chrome на **Jest** (`jest 26`, `jest-preset-angular 8.4`, `jest.config.js`, `src/setup-jest.ts`; `npm run test:ci` = `jest --ci`). **99 spec файла, 1361 теста, всички зелени** (~3 мин). Characterization покритие: core utils/helpers/constants/enums/mappers, renderer services (13 spec), store reducers/effects/states (print-list, platform-job-renderer, print-job, defaults, resin, noms, feature-flag, appliance-profile, info-box, loading-mask), http services (platform-job, print-list, printer-platform, s3-file, api, apig, appsync, aws-http-api, auth*), shared components/pipes/directives, delta компоненти (print-setup-page, renderer host, model-list, print-preview, print-confirmation и др.), `app.routing.spec.ts`, `local-auth-stub.spec.ts`.
- Gate за frontend: `fe-typecheck` → `fe-test` → `fe-build ci` (milestone) / `dev`.
- Backend: `Tests` (MSTest). `SprintRay.IntegrationTest` needs a real DB, so it is NOT in the gate.
