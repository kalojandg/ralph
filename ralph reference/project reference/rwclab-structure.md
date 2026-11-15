# rwclab: structure reference

Repo: `D:\Downloads\monk\sprintray`, remote `kalojandg/rwc-renderer-lab` (private). Integration branch: **`ralph/standalone`**.
Read these first: `RENDERER-AUDIT.md` (full map of the renderer, calls, flow and pipeline), `PLAN.md`, `README.md`, `aws-emulator/README.md`.

## Goal of the board
_Статус (2026-11-15): бордовете 2000–2320, 2500–2650 и 3000–3300 са изпълнени и слети в `ralph/standalone`. Фронтендът е standalone, офлайн (само localhost) и на Angular 22.2; бекендът е на **.NET 10**, пуска се локално в docker-compose с Postgres и AWS емулатора, но още НЕ е орязан от дентален код. Следва **board 4** (realtime, PlatformJob pipeline, денталното орязване)._

_Board 3 (изпълнен; решения на оператора след проби): цел .NET **10** (LTS; SDK 10 и 11 са на хоста, образ `sdk:10.0` изтеглен), AWSSDK 3.7 (не v4), AutoMapper ≤14 (лиценз), SaaS библиотеките на денталните зони (Stripe.net, Auth0, PowerBI, NPOI…) остават на версиите си до денталното орязване. Локалният AWS за бекенда минава през **обикновен HTTP nginx proxy** (`aws-http`, 127.0.0.1:45284, в network namespace-а на емулатора) — пробвано: presigned PUT/GET през proxy-то работят, затова нито бекендът, нито браузърът виждат самоподписания CA, който емулаторът пресъздава при всеки старт. Емулаторът **не доставя SNS→HTTP** (subscription остава PendingConfirmation) → бекендовите callback-и се хранят от SQS `rwc-backend-callbacks-local` през мост `workers/callback-bridge`. SecretsManager работи (Stripe секретът се създава локално). Postgres 16 в compose с `POSTGRES_HOST_AUTH_METHOD=trust` (без парола в git), порт 127.0.0.1:45283; миграции + seed при старт с `Database:MigrateOnStartup=true`. Локалният токен: без подпис (`header.payload.`), `aud ["rwclab-local"]`, `sub local-stub|doctor`, Organization/Office с фиксирани GUID-и — договорът е дословно в tasks 3030/3140/3150. Realtime (AppSync заместител), пълният PlatformJob pipeline и денталното орязване на бекенда са **board 4**._
_Roadmap (решение на потребителя, 2026-11-14): **board 2** (2500–2650) = (а) ЗАПУШВАНЕ на всички външни пътища на фронтенда — само localhost, без GTM/Stripe/Calendly/Fonts/Sentry/LaunchDarkly, AppSync клиентът става „изключен" клиент със същата повърхност; заявки към `localhost:45281` ПАДАТ нарочно, НЯМА локален API и НЯМА нова логика; банерът „Not connected to SprintRay Cloud" ОСТАВА и се показва (той казва истината: няма бекенд); (б) rxjs-compat → pipe, мъртви пакети, Angular 10 → 22 по един мажор на таск. **Board 3** = .NET ъпгрейд „както идва", закачане бекенд↔фронтенд и пренасочване на бекенда към локалния AWS емулатор — бекендът се ПАЗИ, не се заменя и не се трие. Разузнаването за board 3 е в `rwclab-local-aws-recon.md` (същата папка)._
Turn the copied SprintRay "Design Service" (RayWare Cloud) into a **standalone app**. Starting the app opens straight into the 3D renderer (`''` и `'**'` → `/print-setup` → `DeltaModule` → `<delta-renderer>`; останалите рутове: `/login`, `/not-authorized`, `/error`). Everything unrelated to RayWare/delta is **deleted**: treatments, patients, messenger, billing, dashboards, fleet, sync-box, campaigns, AI, and so on.
- Frontend: Angular 22.2 in `app/frontend` (беше Angular 9; ъпгрейд по един мажор на таск, #2630–#2644).
- Backend: .NET 10 in `app/backend` (беше .NET Core 3.1), още не е орязан до API-тата на рендъра (board 4). Върви в compose.
- AWS: the local AWS Emulator (`aws-emulator/`, `infra/`, `workers/`), never real AWS.

## File map
```
RENDERER-AUDIT.md / PLAN.md / README.md   docs (audit = the source of truth for what to keep)
aws-emulator/        Dockerfile, env.sh, probes. Local AWS on https://127.0.0.1:9297 (за бекенда и браузъра: plain HTTP през aws-http на :45284)
infra/               resources.mjs (names, state machines), bootstrap.mjs (idempotent)
workers/algorithms/  Docker worker: native mesh binaries via Step Functions Activities (+ src/input.mjs: приема входа на бекенда за preprocess, публикува bind payload)
workers/callback-bridge/ SQS `rwc-backend-callbacks-local` → HTTP callback-ите на бекенда (slice-done, bind-print-list-item), до 5 опита (SNS→HTTP не работи в емулатора)
scripts/gate/        + be-build/be-test/be-exec/be-image/_be-env (образ от app/backend/.dotnet-image = sdk:10.0), be-config-offline (.cmd+.mjs), compose-config, fe-smoke (.cmd+.mjs, headless Chromium), lab-e2e
scripts/local-stack.cmd  една команда за целия стек (compose up + bootstrap)
scripts/gate/        fe-npm-ci.cmd, fe-typecheck.cmd, fe-test.cmd [pattern], fe-build.cmd [dev|ci] (Docker; Node образът е от `app/frontend/.node-image`, сега Node 22; `production` конфигурацията е махната в #2500)
scripts/e2e.mjs      upload → import → plane cut → events → download (npm run e2e)
docker-compose.yml   aws-emulator + aws-http (nginx, 127.0.0.1:45284) + postgres 16 (:45283, volume rwc-pg-data) + backend (:45281, app/backend/Dockerfile) + algorithms-worker + callback-bridge
app/frontend/        Angular 22 (copied from Design-Service/Frontend, Angular 9; + .node-image, .npmrc, patches/)
scripts/fe-serve.cmd dev сървър в Docker на :45280 (build конфигурация ci, т.е. environment.dev.ts)
scripts/gate/        + _fe-env.cmd (чете .node-image), fe-exec.cmd, no-external-hosts.cmd
app/backend/         .NET 10 solution Backend.sln (copied from Design-Service/Backend; + Dockerfile, docker-entrypoint.sh, .dotnet-image)
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

### Офлайн фронтенд (#2500, #2510)
- Всички хостове в `src/environments/*` са `localhost` (API и файлове → `http://localhost:45281/api/`, `/files/`; app → `:45280`). Няма GTM/analytics, Google Fonts, Stripe, Calendly, Sentry, LaunchDarkly (празен `launchDarkly.clientKey` = локални feature-flag дефолти). Остават само `environment.ts` и `environment.dev.ts` (staging/prod/production конфигурациите са махнати).
- REST заявките към `localhost:45281` стигат до локалния бекенд (board 3), когато стекът е вдигнат; без него падат с refused. Банерът „Not connected to SprintRay Cloud" остава.
- `appsync.service.ts` е „изключен" клиент със същата повърхност (query/subscribe), без мрежа: subscriptions не излъчват, query връща празни списъци.
- Гейт `scripts\gate\no-external-hosts.cmd`: пада, ако `app\frontend\src` (ts/js/html/scss/json) именува външен хост. Умишлени изключения по име: `claim-keys.ts`, `privacy-term-links*`, три html с маркетинг линкове, `assets/i18n/*`.

### Ъпгрейдът Angular 9 → 22 (#2610–#2650)
- rxjs беше `~6.6` (сега 7.8, виж по-долу), rxjs-compat и всички `rxjs/add/*` patch импорти са махнати: само pipeable оператори (#2610–#2615). Karma, Protractor, TSLint и неизползваните библиотеки са изтрити (#2620).
- Bootstrap 5.3 + ng-bootstrap (#2634); Angular Material е на MDC (#2638, преди Angular 17); ngrx 22, TypeScript 6, Jest 30, jest-preset-angular 17, zone.js 0.15, three.js ^0.125.
- Модулите остават NgModule-базирани (`standalone: false` не е пипан).
- `.npmrc` е изтрит (#3040): rxjs 7.8 (`firstValueFrom`, observer обекти), `graphql-tag` 2.12.7, `@types/node ^22.20.5`, lodash 4.18.1; `npm ci` без `legacy-peer-deps`. `patches/ngx-toastr+19.1.0.patch` (patch-package в `postinstall`) остава: няма ngx-toastr релийз за Angular 22.
- Node образ и volume: `app/frontend/.node-image` (`<image> <volume>`), сега `node:22-bookworm rwc-fe-nm-ng22`; всички `scripts\gate\fe-*.cmd` и `fe-serve.cmd` го четат през `_fe-env.cmd`. Старите volume-и `rwc-fe-nm-ng10…ng21` са изтрити.
- `scripts\fe-serve.cmd` подава `--build-target` (kebab-case; CLI 22 отхвърля `--buildTarget`) и `--poll 2000`; проверен в браузър на 2026-11-15. `src/polyfills.ts` слага `window.global = window`.
- Board 3 по фронтенда: #3000 без signal записи/state flips в първия render pass (NG0600, NG0100); #3010 ефектите диспатчват съществуващите `*_ERROR` actions, dev action logger е махнат; #3020 smoke гейт `fe-smoke` (headless браузър, офлайн, пада на runtime грешки); #3040 distinct environments.

### Auth: локален stub (#2200)
`useLocalAuthStub` в `src/environments/*`: **true** в `environment.dev.ts` (конфигурации `dev` и `ci`), **false** в `environment.ts` (default serve/build и jest), staging, prod. `Auth0Service.fetchTokens()` връща unsigned фалшива сесия (един фиксиран потребител) и не вика Auth0. От #3030 токенът е в точния вид, който локалният бекенд приема: `header.payload.` (alg none), `aud ["rwclab-local"]`, `sub local-stub|doctor`, Organization/Office с фиксирани GUID-и (договорът е в README). Това НЕ е автентикация; не се включва в staging/prod.

### app/backend
_Board 3: ъпгрейд до .NET 10 (EF Core 10, Npgsql 10, AutoMapper 14, MSTest 3, AWSSDK 3.7 с endpoint override и path-style S3, без ръчно строени AWS клиенти) и офлайн Development режим. Денталното орязване още НЕ е направено (board 4)._
- Нови: `Web/Controllers/Local/LocalRocController` (само Development, 404 иначе; данни от `Web/LocalStubs/roc-resins.json`), `Web/Infrastructure/LocalDatabase/LocalDatabaseBootstrap.cs` (`Database:MigrateOnStartup=true`: миграции + seed от `DataLayer/Scripts/LocalSeed/*.sql`), `JwtBearerOptionsExtensions` (`Auth0:LocalUnsignedTokens`, само Development, иначе бекендът отказва да стартира), `Services/AWS/AwsEndpoint.cs` (Development пада, ако няма `AWS:ServiceURL`/`AWS_ENDPOINT_URL`). AppSync, LaunchDarkly и Stripe са неутрализирани в Development (`appsettings.Development.json`).
- Projects: Web, ServiceLayer, DataLayer (EF Core + Npgsql, 266 миграции), DTOs, Common, SprintRay.EventBus (in-process), SprintRay.Logger, Tests (MSTest), SprintRay.IntegrationTest, Database (sqlproj), CodeDeploy.
- **Keep:** `Web/Controllers/PrintList/*` (PlatformJob, PrintList, PrinterPlatform, ApplianceProfile), `PrinterController`, `Feedback/*`, `Inbox/FileController`, `Resins/*`, `HealthController`, plus the auth/user/feature-flag pieces the shell needs; `PlatformJobService`, `PrintListService`, `Services/AWS/*`, `Services/Files/*`, `EventHandlers/PlatformJob/*`, `EventHandlers/PrintList/*`.
- **Delete** (RENDERER-AUDIT.md §2.3): Billing, Campaign, CustomerSupport, Dashboard, Factory, Import, Integration, Lab, Manager, MasterDashboard, Noms (check what the frontend lookup lists use first!), Notifications, Organization, Payments, PowerBI, Privacy, Product, RayApp, SyncBox, Conversation, DocumentLink, LiabilityApproval, ScheduledTask, `Treatments/*`, Device/CloudTab/IotProxy/PrintJob (if "send to printer" goes).
- Every deletion must also remove its DI registration in `Web/Infrastructure/Extensions/ServiceCollectionExtenstions.cs` and in `Startup.cs`.

## Persistence and external contracts
| What | Where | Status |
|---|---|---|
| Postgres 16 (EF Core, Npgsql) | `SprintRayWriteConnection`/`ReadConnection`, compose service `postgres` (127.0.0.1:45283, trust auth, без парола, volume `rwc-pg-data`) | Локален; миграции + идемпотентен seed при старт (`Database:MigrateOnStartup=true`) |
| S3 / DynamoDB / SQS / SNS / Step Functions | AWS SDK | **only** through the AWS Emulator: workers `https://127.0.0.1:9297`; бекендът `AWS_ENDPOINT_URL=http://127.0.0.1:45284` (aws-http proxy), AWSSDK 3.7, path-style S3, имена `*_LOCAL` от `infra/resources.mjs` (appliance-profile таблици, FIFO опашки, Stripe secret, `rwc-backend-callbacks-local`, placeholder машина `PlatformJobLocal`) |
| AppSync (job logs/subscriptions) | frontend `appsync.service.ts`, backend `AwsAppSyncService.cs` | изключен и във фронтенда, и в бекенда (Development). Заместителят (WebSocket gateway, SNS→SQS `rwc-platform-job-logs-local`) е board 4 |
| Auth0, LaunchDarkly, ResinOnCloud, Sentry, Stripe | environment/appsettings | external SaaS от SprintRay. Auth0: фронтенд stub (#2200/#3030) + unsigned токени в бекенда; ResinOnCloud: `api/local-roc/`; LaunchDarkly: изключен (флаговете false); Stripe: `Stripe:ApiBase=http://127.0.0.1:45281/local-stripe`; Sentry: махнат. Гейт `be-config-offline` |
| Job log message | `{algorithm, platformId, status(102/200/4xx/500), errorCode, timestamp}` | **live contract** between worker → events → frontend (`PlatformJobAlgorithm`/`PlatformJobAlgorithmStatus` enums) |

## RED LINES (violation = failed task)
1. **Never touch `Design-Service/`.** Don't edit it, don't `git add` it, don't copy secrets from it. It is read-only reference.
2. **No secrets in git.** Every secret value in config is `<set-locally>`. Never put back `appsettings.Production.json`, `Staging.json` or `DevelopmentAWS.json`, and don't add real keys, passwords or connection strings.
3. **Never real AWS.** Every AWS client has an explicit emulator endpoint (or `AWS_ENDPOINT_URL`). Code that would fall back to the real AWS default endpoint is forbidden. Tests never talk to the network outside localhost.
4. **Never commit the binaries.** `workers/algorithms/vendor/` stays git-ignored.
5. Фронтендът не вика нищо различно от localhost (гейт `no-external-hosts`): без външни хостове, analytics, шрифтове или feature-flag услуга.
6. Don't break `npm run e2e` (the emulator flow) unless the task is explicitly about it.
7. Delete for real. Don't comment code out, don't leave dead routes or modules "for later".

## POISON LIST (shared files → solo lane, one task at a time)
- **Frontend:** `src/app/app.module.ts`, `app.routing.ts`, `core/core.module.ts`, `core/index.ts`, `core/services/index.ts`, `core/store/reducers/index.ts`, `core/store/states/index.ts`, `core/store/effects/*` index, `shared/shared.module.ts`, `shared/index.ts`, `app-modules/common/common.module.ts`, `components/common/header/*`, `app.component.ts`, `angular.json`, `package.json`/`package-lock.json` (+ `.npmrc`, `patches/`, `.node-image`), `src/environments/*`.
- **Backend:** `Web/Startup.cs`, `Web/Infrastructure/Extensions/ServiceCollectionExtenstions.cs`, `Backend.sln`, all `*.csproj`, `DataLayer/*DbContext*`, `DataLayer/Migrations/*`, `Common/Configs/*`, `Web/appsettings*.json`.
- **Root:** `docker-compose.yml`, `infra/resources.mjs`, `.gitignore`.

Deleting a feature module almost always touches the frontend barrels, modules and routing at the same time. So deletions go **in sequence in one lane**; parallel work is only possible across zones (frontend ↔ backend ↔ infra).

## Commands and ports
- **Toolchain:** Node 24 on the host. Бекендът: Docker `app/backend/.dotnet-image` = `mcr.microsoft.com/dotnet/sdk:10.0` + volume `rwc-nuget-net10`. Angular 22 needs Node `^22.22.3 || ^24.15.0`, so the frontend runs in Docker `node:22-bookworm` with `node_modules` in volume `rwc-fe-nm-ng22` (и двете от `app/frontend/.node-image`; не ги хардкодвай).
- **Gate скриптове (препоръчителни):** `scripts\gate\fe-npm-ci.cmd` (~1 мин, веднъж/при смяна на deps; никога два паралелно върху един volume), `fe-typecheck.cmd` (~21 s), `fe-test.cmd [pattern]` (jest 30, `--testPathPatterns`, 2 CPU/2 workers, ~4:10), `fe-build.cmd [dev|ci]`, `no-external-hosts.cmd` (<1 s). Бърза конфигурация **`ci`** (AOT, без optimization/source maps, #2010): 2:59 vs `dev` 3:54 (Angular 9: 4:31 / 8:08). Измерено 2026-11-15 (#2650).
- **Frontend build (gate):** `docker run --rm -v "<fe>:/w" -v rwc-fe-nm-ng22:/w/node_modules -w /w node:22-bookworm sh -c "npm ci && npx ng build --configuration=dev"` (за предпочитане през `scripts\gate\fe-*.cmd`, които четат `.node-image`)`.
- **Backend build/test (gate):** `docker run --rm -v "<be>:/src" -v rwc-nuget-net10:/root/.nuget/packages -w /src mcr.microsoft.com/dotnet/sdk:10.0 sh -c "dotnet build Backend.sln && dotnet test Tests --no-build"`. Последни мерени времена (sdk:3.1, преди .NET 10): restore 101 s, build 154 s, `Tests` 148/148 за 15 s; .NET 10 мина зелено (0 грешки), но нови времена не са мерени; `SprintRay.IntegrationTest` е извън гейта (Docker socket + Postgres 10 + истински Auth0). Гейтовете са `scripts\gate\be-build.cmd` / `be-test.cmd [filter]` / `be-image.cmd` (build на Dockerfile, не го пуска) / `be-config-offline.cmd` / `compose-config.cmd`.
- **Local stack:** `scripts\local-stack.cmd` (compose up + bootstrap; след `compose restart/down` се пуска пак, емулаторът държи състоянието в памет). e2e: `source aws-emulator/env.sh` → `npm run e2e` (или `scripts\gate\lab-e2e.cmd`). ⚠ Uses 127.0.0.1:9297.
- **Ports:**
  - ⚠ The backend's `launchSettings` has 5000/5001/44352, and **5001 is taken** by party-up `be_dev`. Assign new ones: backend **45281**, frontend `ng serve` **45280** (task).
  - Портове на лабораторията: 45280 фронтенд, 45281 бекенд, 45283 Postgres, 45284 aws-http, 9297 емулатор. Fleet ports already taken: 45277–45279, 8081, 5001.
- **Dev сървър (за потребителя):** `scripts\fe-serve.cmd` → http://localhost:45280/ (ng serve с build конфигурация `ci`, контейнер `rwc-fe-serve`; един наведнъж).
- **Forbidden for agents:** `ng serve`, `dotnet run`, `docker compose up` of long-running servers. Those belong to the gate and the user only.

## Test state
Измерено 2026-11-15 след board 2 (#2650), всичко зелено: tsc, jest, `fe-build ci`, `fe-build dev`, `no-external-hosts`. След board 3 гейтовете са минали зелено в борда; финалните времена и общият брой тестове не са пре-мерени (финалният агент не пуска тестове). Builds: 0 errors, само Sass/CommonJS предупреждения.
- Frontend: тестовете са на **Jest** (`jest 30`, `jest-preset-angular 17`, `jest.config.js`, `jest-ng-transformer.js`, `src/setup-jest.ts`; Karma е изтрит; `npm run test:ci` = `jest --ci`). **110 spec файла** (+app/picture/register effects спекове; при последното мерене преди board 3: 107 файла / 1394 теста, всички зелени) (~4 мин 10 s; беше 99 / 1361 след #2320; в спековете `HttpClientTestingModule` → `provideHttpClient(withInterceptorsFromDi())` + `provideHttpClientTesting()`). Characterization покритие: core utils/helpers/constants/enums/mappers, renderer services (13 spec), store reducers/effects/states (print-list, platform-job-renderer, print-job, defaults, resin, noms, feature-flag, appliance-profile, info-box, loading-mask), http services (platform-job, print-list, printer-platform, s3-file, api, apig, appsync, aws-http-api, auth*), shared components/pipes/directives, delta компоненти (print-setup-page, renderer host, model-list, print-preview, print-confirmation и др.), `app.routing.spec.ts`, `local-auth-stub.spec.ts`, `environments.spec.ts` (офлайн environments), `appsync.service.spec.ts` (изключен клиент).
- Gate за frontend: `fe-typecheck` → `fe-test` → `fe-build ci` (milestone) / `dev`.
- Backend: `Tests` (MSTest 3), ~170 тестови метода (148 при последното мерене; нови: `LocalRocControllerTests`, `AwsServicesRegistrationTests`, `LocalDatabaseBootstrapTests`, `LocalUnsignedTokensTests`, `AwsS3ServiceTests`, `OfflineExternalServicesTests`).
- Workers: node тестове в `workers/algorithms/test/input.test.mjs` и `workers/callback-bridge/test/route.test.mjs`.
- Smoke: `fe-smoke` (след `fe-build ci`, ~16 s): пада на page errors, `NG0xxx` в конзолата, липса на canvas или заявка към не-локален хост. `SprintRay.IntegrationTest` needs the Docker socket and real Auth0, so it is NOT in the gate.
