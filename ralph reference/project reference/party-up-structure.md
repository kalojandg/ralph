# Party Up — Architecture Reference

> Прочети този файл ПРЕДИ да пишеш код. Патърните тук са ПРАВИЛА, не препоръки.
> Приложение: TTRPG matchmaking (pull модел — играчите се публикуват на LFG борд,
> МАСИТЕ дърпат кандидати). Монорепо, TDD от commit 1. Пълната продуктова
> спека: `party-up.md` в D:\Downloads\monk\ (секции А–Е + Решения лога).
> **Състояние: board 1–42 (v0.1) е ЗАТВОРЕН и мерджнат в `main`.** Всички 42 таска са зелени
> през гейта. Файлът описва РЕАЛНОСТТА след него, не скелета.

## §1. Файлова карта (монорепо)

```
party-up/
├── backend/
│   ├── PartyUp.slnx              ← .NET 10 solution (СЛЪНЦЕТО Е .slnx, НЕ .sln!)
│   ├── src/PartyUp.Api/          ← единственият BE проект: minimal API + Hot Chocolate
│   │   ├── Program.cs            ← DI + GraphQL pipeline + RunWithGraphQLCommandsAsync (дава schema export)
│   │   ├── Domain/               ← ЦЕЛИЯТ модел (13 entity-та + Enums.cs) — фича таск НЕ добавя тук
│   │   ├── Data/PartyUpDbContext.cs  ← IdentityDbContext<AppUser, IdentityRole<Guid>, Guid>, 12 DbSet-а
│   │   ├── Common/               ← Results/ (Result, DomainError), GraphQL/MutationResult.cs,
│   │   │                            Notifications/INotifier.cs, Endpoints/IEndpointModule.cs,
│   │   │                            CurrentUser.cs, FrontendOptions.cs, TableRules.cs
│   │   ├── GraphQL/              ← Query.cs (root, само `hello`) + TypeModule.cs
│   │   │                            ([assembly: Module("PartyUpTypes")] — котвата на генератора)
│   │   ├── Features/             ← ВСИЧКАТА фича логика, vertical slices (виж §1а)
│   │   └── Properties/launchSettings.json  ← портове 5001 (https) / 5000 (http) — OAuth redirect-ите са на 5001!
│   └── tests/
│       ├── PartyUp.UnitTests/        ← xUnit, бързи, БЕЗ Docker
│       └── PartyUp.IntegrationTests/ ← xUnit + Testcontainers.PostgreSql (истински Postgres в Docker)
│           └── Support/              ← ApiFactory, ApiTestBase, PostgresCollectionFixture,
│                                        TestAuthHandler, TestSessionQueries (СПОДЕЛЕНИ — не се преправят)
├── frontend/                     ← Expo SDK 57 (web-first PWA + native)
│   ├── src/app/                  ← Expo Router — ТЪНКИ route файлове (виж §1б)
│   ├── src/features/<област>/    ← ЦЯЛАТА екранна логика: компоненти, hooks, *.gql.ts документи, тестове
│   ├── src/lib/                  ← apollo.ts, providers.tsx, auth-gate.tsx, theme.tsx, ui-store.ts,
│   │                                i18n.ts, session.ts, config.ts
│   ├── src/locales/{bg,en}/      ← по 15 namespace JSON файла на език (виж §7г)
│   ├── src/components/           ← само placeholder-screen.tsx (generic споделеното е малко — по дизайн)
│   ├── src/test-utils/           ← render.tsx (renderWithProviders), subscription.ts, css-mock.js
│   ├── src/gql/                  ← ГЕНЕРИРАН codegen изход — GITIGNORED, никога не се комитва
│   ├── src/__tests__/            ← крос-екранни спекове (navigation, placeholder-routes, smoke, ui-store)
│   ├── src/global.css            ← NativeWind вход (metro го подава на tailwind)
│   ├── e2e/                      ← Playwright: smoke.spec.ts, support.ts, prepare-static.mjs
│   ├── public/                   ← sw.js (service worker), manifest.json, icons/ — сервират се 1:1 от статиката
│   ├── playwright.config.ts      ← порт 45280, статичен export (без dev сървър)
│   ├── codegen.ts                ← схема ../contracts/schema.graphql → src/gql (client-preset)
│   ├── metro.config.js           ← withNativeWind + resolveRequest: bare `tslib` → tslib/tslib.es6.mjs
│   │                                (БЕЗ него `expo export --platform web` пада → e2e отпада)
│   ├── tailwind.config.js        ← darkMode:'class', цветове surface/ink/brand
│   ├── app.json                  ← web.output:"static", PWA полета, typedRoutes, reactCompiler
│   ├── package.json              ← jest конфигът е ВЪТРЕ в него (няма jest.config.js)
│   ├── tsconfig.json             ← strict, types:["jest"], paths @/* → ./src/*
│   └── expo-env.d.ts             ← НАРОЧНО в git (против Expo конвенцията): без него tsc пада на чист clone
├── contracts/
│   ├── schema.graphql            ← ЖИВИЯТ КОНТРАКТ BE↔FE (реален експорт от Hot Chocolate, 629 реда)
│   ├── DESIGN-NOTES.md           ← конвенции, карта operation→таск, съзнателните опростявания на v0.1
│   ├── README.md                 ← процедурата по ре-експорт
│   └── schema-settings.json      ← Hot Chocolate export метаданни
├── rules/                        ← ОБВЪРЗВАЩИ ревю правила на репото
│   ├── architecture-rules.md     ← BE vertical slices + FE слоеве
│   └── i18n-rules.md             ← класификация на i18n нарушенията
├── global.json                   ← пин SDK 10.0.400 (rollForward latestFeature)
└── .gitignore                    ← bin/obj, node_modules, .expo, dist, .env*, playwright-report, test-results
```

### §1а. BE slice инвентар (`Features/<Област>/<UseCase>/`)

Схемата излиза с **18 query, 25 mutation, 2 subscription**. Кой slice какво издава:

| Slice | Use case папки | GraphQL операции |
|---|---|---|
| `Auth` | Login, Logout, Me | HTTP `GET /auth/login/{provider}`, `GET /auth/callback` (НЕ GraphQL); `logout`; `me` |
| `AuthLinking` | (плосък) | `linkedProviders`, `linkProviderUrl(provider)`, `unlinkProvider` |
| `Profiles` | MyProfile, UpdateProfile | `myProfile`, `updateProfile` |
| `MyTables` | (плосък) | `myTables` |
| `Tables` | CreateTable, Settings, Listing | `createTable`, `updateTableSettings`, `setTableListing` |
| `Lfg` | Board, Publish, Showcase | `lfgBoard(filter)`, `myListing`, `publishMyListing`, `unpublishMyListing`, `tablesShowcase(filter)`, `table(id)` |
| `Decisions` | (плосък) | `groupDecision(id)`, `castVote` |
| `DecisionAlerts` | (плосък) | `staleDecisions`, `snoozeDecision` |
| `Candidacies` | Pull, Contact, Verdict | `candidacy(id)`, `myTableCandidacies(tableId)`, `pullCandidate`, `openContactChat`, `submitVerdict` |
| `Chats` | Messaging, Subscriptions | `myChats`, `chat(id)`, `sendMessage`, `onMessage(chatId)`, `onNotification` |
| `Notifications` | (плосък) | `notifications(unreadOnly)`, `markNotificationRead` |
| `Lifecycle` | Trial, Leave, Kick, Refound | `startTrial`, `startDecidingPhase`, `finalizeDeciding`, `stayOrLeave`, `leaveTable`, `proposeKick`, `refoundTable`, `acceptRefoundInvite` |
| `Push` | Subscriptions, Vapid | `pushSubscribe`, `pushUnsubscribe`, `vapidPublicKey` |
| `PushSend` | (плосък) | **няма GraphQL** — инфраструктурен slice (FanoutNotifier, WebPushSender, `AddPushFanout()`) |

**Домейн (13 entity-та, `Domain/`):** `AppUser`, `UserProfile`, `PlayerListing`, `Table`, `TableMembership`,
`Candidacy`, `GroupDecision`, `Vote`, `Chat`, `ChatParticipant`, `Message`, `Notification`, `PushSubscription`.
**9 enum-а в `Domain/Enums.cs`:** ExperienceLevel, GameFormat, TableStatus, AdmissionMode, MembershipRole,
CandidacyStatus, DecisionTopic, DecisionStatus, ChatType (+ `AuthProvider` и `PushDelivery` в своите slice-ове).

**Интерфейси — точно ТРИ (§2а.3 се спазва):** `IEndpointModule` (единствена имплементация `AuthEndpoints`,
намира се с reflection), `INotifier` (`DefaultNotifier` → декориран от `FanoutNotifier`, който публикува топик
и праща Web Push), `IPushSender` (`WebPushSender`; тестови двойници `StubPushSender`/`RecordingPushSender`).

**⚠ НЯМА hosted/background services.** Авто-поведенията са МЪРЗЕЛИВИ, задействат се при заявка:
`TableDelistService` (сваля обявата при пълна маса), `UnpublishService` (сваля LFG обявата при приемане),
`StaleDecisionFinder` + `StaleDecisionRules` (заспал гласоподавател: 3 дни праг, 3 дни макс. snooze,
`DECISION_STALE`). Не въвеждай `BackgroundService` без решение на потребителя.

### §1б. FE маршрути и области

**Табове — точно 3** (`src/app/(tabs)/_layout.tsx`, `Tabs` от `expo-router/js-tabs`): `board`, `tables`, `profile`.
`/` пренасочва към `/board`.

| Маршрут | Екран | Област (`src/features/`) |
|---|---|---|
| `/login` | LoginScreen (3 OAuth бутона) | `auth` |
| `/settings` | тема + UI език + линкнати профили | `auth-linking` |
| `/board` (таб) | LFG борд с филтри, player cards, publish CTA | `board` |
| `/tables` (таб) | моите маси + status badges + create CTA | `my-tables` |
| `/profile` (таб) | профилна форма (react-hook-form) | `profile` |
| `/table/create` | форма за нова маса (one-shot полета, обучителен таг) | `table-create` |
| `/table/[id]` | детайл на масата + кандидатури | `candidacy` |
| `/table/[id]/settings` | admission mode + listing toggle (founder-only) | `table-settings` |
| `/table/[id]/lifecycle` | phase stepper, founder преходи, stay-or-leave | `lifecycle-trial` |
| `/table/[id]/actions` | danger zone: leave, kick, refound | `lifecycle-actions` |
| `/candidacy/[id]` | pull flow: решение чат, панел за гласуване, вердикт | `candidacy` |
| `/chat`, `/chat/[chatId]` | списък чатове и нишка с realtime абонамент | `chat` |
| `/showcase`, `/showcase/[id]` | readonly витрина + състав на партито | `showcase` |
| `/notifications` | нотификационен център (неутрални текстове към кандидата) | `contact` |
| `/refound-invite` | приемане на покана след преосноваване | `lifecycle-actions` |

Плюс `push` (без свой маршрут — service worker, subscribe pipeline, iOS install подсказка) — **прогресивно
подобрение**: `PushPrompt`/`usePushSetup` още не са закачени за екран, `NotificationBell` също. Това е
осъзнато състояние от таск 40, не пропуск на wiring.

**Няма `src/hooks/`** — hook-овете живеят в своята област (`use-session`, `use-logout`, `use-auth-linking`,
`use-danger-action`, `use-push-setup`) или в `src/lib` (`useThemeMode`, `useUiLanguage`, `useUiStore`).

## §2. Стек (ФИКСИРАН — агентите НЕ избират депендънсита)

- **BE:** .NET 10 + Hot Chocolate 16.6 (`AspNetCore`, `CommandLine`, `Subscriptions.InMemory`,
  `Types.Analyzers`) + EF Core/Npgsql 10.0.3 + ASP.NET Identity 10.0.11 (САМО external logins:
  Google, Facebook, `AspNet.Security.OAuth.Discord`) + `Lib.Net.Http.WebPush` 3.3.0.
- **FE:** TypeScript 6 (strict) + Expo/Expo Router 57 + Apollo Client 4 (graphql-ws за subscriptions)
  + Zustand 5 (само UI state; сървърният state е Apollo кешът) + NativeWind 4 / tailwindcss 3
  + react-hook-form 7 + i18next 26 / react-i18next 17 (+ expo-localization). БЕЗ Redux. ВСИЧКО е wired.
- **Codegen:** `@graphql-codegen/cli` 7 + `client-preset` 6 → `src/gql` (gitignored, регенерира се от скриптовете).
- **e2e:** `@playwright/test` 1.61 + `http-server` 14 (статичен export, не dev сървър).
- ⚠ **`DropGreenDonutImplicitUsing` таргет в csproj-а**: маха `global using GreenDonut;`, който HC инжектира,
  защото `GreenDonut.Result<T>` се блъска (CS0104) с `Common/Results/Result.cs`. Не го пипай.
- Нов пакет = решение на потребителя, НЕ на агент.

## §2а. BE патърни (РЕШЕНИ 14.08 — агентите ги СЛЕДВАТ, не ги предоговарят)

1. **Vertical slices, БЕЗ MVC/контролери**: use case = папка Features/<Област>/<UseCase>/ (handler + HC type extension). Никакви „дебели" сървиси-чували.
2. **CQRS-lite, НЕ пълен CQRS**: query и mutation handler-ите са разделени по конструкция (GraphQL). Отделни read модели/проекции/шини НЕ се строят — отрицателна стойност на този мащаб.
3. **Интерфейс САМО при реална подмяна** (INotifier, IPushSender). Двойки IXxxService/XxxService по инерция = шум, не се пишат. БЕЗ repository слой над EF (DbContext-ът Е repository+UoW; тестовете подменят през Testcontainers, не през мок на данни).
4. **Read дисциплина от ден 1 (проектът се цели в read-intensive)**: всеки query handler ползва AsNoTracking() + Select проекция ПРАВО в GraphQL типа (не зарежда цели entities); вложените колекции в GraphQL (състав на маса, последни съобщения) минават през Hot Chocolate DataLoader срещу N+1. Кеш слой на сървъра — БЕЗ (чак при реални метрики).
   Живите DataLoader-и: `CandidacyDataLoaders`, `ChatDataLoaders`, `DecisionDataLoaders`, `ShowcaseDataLoaders`,
   `MyTablesDataLoaders`, `Lfg/Board/PlayerListingType`. Нова вложена колекция → нов DataLoader, не `Include`.
5. **Result pattern** (§4.5) — очакваните провали са стойности; exceptions само за програмни грешки.
6. **Статични pure services за домейн правилата** (`TableDelistService`, `UnpublishService`, `VoteTally`,
   `TrialTransitions`, `PushFanout`, `StaleDecisionRules`) — така се тестват unit, без база. Handler-ът
   само оркестрира около тях.

## §3. Модел на персистенция / живи контракти

1. **`contracts/schema.graphql` е ЖИВ КОНТРАКТ** — единственият договор BE↔FE. НЕ се пише на ръка: променя се САМО през C# кода + ре-експорт (`schema_export` командата). BE task-ове коммитват новия експорт; FE task-ове го ЧЕТАТ (codegen), никога не го редактират. **Екзепцията на таск 2 е ЗАТВОРЕНА от таск 41** — файлът вече е реален HC експорт (виж `contracts/DESIGN-NOTES.md` §0).
2. **Прод базата е Neon Postgres** — connection string-ът е СЕКРЕТ, съществува само в password manager-а на потребителя / dotnet user-secrets / прод .env. НИКОГА в git, НИКОГА в тест.
3. **Тестовете ползват САМО Testcontainers** — вдигат си истински Postgres в Docker. Никаква връзка към Neon/жива база от тест или агент.
4. **Секрети:** dev = `dotnet user-secrets` (UserSecretsId вече е init-нат в PartyUp.Api). Конфиг ключовете (напр. `Authentication:Google:ClientSecret`) се четат от IConfiguration — стойностите ги слага ПОТРЕБИТЕЛЯТ. Публичните OAuth client ID-та НЕ са секрети (стоят в appsettings.json): Google `438566552589-bqbid79l39j6j8g1j0dhmdtoebgv9bu5.apps.googleusercontent.com`, Discord `1537485903222673490`, Facebook `2139533033575936`.
   OAuth провайдър се регистрира в Program.cs **само ако ClientId И ClientSecret са конфигурирани** — иначе
   приложението (и `schema export`) тръгва без него, вместо да гърми.
5. **⚠ НЯМА EF migrations.** Схемата в тестовете се вдига с `EnsureCreated`; migrations са deploy грижа и
   идват със свой таск, когато има прод deploy. Не генерирай migrations „в движение".
6. **DbContext-ът е с 12 DbSet-а** плюс Identity таблиците. Ключови ограничения в `OnModelCreating`:
   уникален `Vote(DecisionId, VoterUserId)`, уникален `PushSubscription.Endpoint`, уникален
   `ChatParticipant(ChatId, UserId)`, `text[]` колони за `SessionLanguages`/`Systems`/`StyleTags`.

## §4. ЧЕРВЕНИ ЛИНИИ (нарушение = failed таск)

1. **Никакви секрети в git** — нито в appsettings, нито в тестове, нито в коментари. Празни placeholder ключове в appsettings.Development.json са ОК; стойности — НЕ. (gitleaks мисленето важи и без gate.)
2. **`contracts/schema.graphql` не се редактира на ръка** (виж §3.1). FE не го пипа изобщо.
3. **Тест никога не докосва външен ресурс**: без Neon, без реални OAuth провайдъри, без мрежа. Integration = Testcontainers, точка. Playwright спековете също са БЕЗ жив BE — стъбват `**/graphql`.
4. **Dev сървъри НЕ се пускат от агенти** (`dotnet run`, `expo start`) — портове 5001/8081 са едни. Гейтът пуска само тестовите команди. Същото важи за `npm run e2e:serve` (45280).
5. **Result pattern в бекенда (решение 13.08):** очакваните провали (зает слот, невалиден вот, липсващо право) са СТОЙНОСТИ (Result), не exceptions. Exceptions = само програмни грешки. GraphQL слоят мапва Result грешките към типизирани error полета (Hot Chocolate mutation conventions) → FE показва човешки съобщения през i18n ключове. Никакъв raw stack trace до UI. FE рендерира `t(error.i18nKey)`; показването на `DomainError.message` в UI също е блокер.
6. **i18n от ден 1:** всички UI низове през react-i18next ключове (BG/EN). Хардкоднат низ в компонент = failed таск. UI езикът е ОТДЕЛЕН от профилното поле „език на сесиите". Класификацията е в `rules/i18n-rules.md`.
7. **Тестовите инфраструктурни файлове** (jest конфиг, tsconfig, мокове, helpers, `src/test-utils/`, IntegrationTests `Support/`, `e2e/support.ts`) се създават от инфраструктурни таскове и се КОНСУМИРАТ от останалите — фича таск не ги преправя.
8. **`git push` не се прави от агент** — merge/push е работа на оркестратора/потребителя.
9. **`src/gql/` не се комитва** — генерира се. Комит на генериран код = конфликтна мина между FE lanes.

## §5. ОТРОВЕН СПИСЪК (споделени файлове → диктуват соло lanes)

Едновременна редакция от два таска = merge конфликт = загорели retry бюджети. Тези файлове ги пипа само ЕДИН таск наведнъж (фундаментен таск в началото на фаза ги изяжда, после фича lanes не ги докосват):

| Файл | Защо е отрова |
|------|---------------|
| `backend/PartyUp.slnx` | нов проект = редакция тук |
| `backend/src/PartyUp.Api/Program.cs` | всяко DI/pipeline wiring минава оттук (изяден от таскове 1 и 26) |
| `backend/src/PartyUp.Api/PartyUp.Api.csproj` | нов пакет/reference |
| `backend/src/PartyUp.Api/Domain/*` + `Common/*` | целият модел е от таск 1 — фича таск НЕ добавя entity |
| `contracts/schema.graphql` | ре-експортира се при ВСЯКА схема промяна — BE фаза го променя серийно |
| `frontend/package.json` + `package-lock.json` | нов пакет/скрипт + jest конфигът живее вътре |
| `frontend/tsconfig.json` | компилаторни опции — И: **всеки Metro прогон го преформатира** (виж §6) |
| `frontend/metro.config.js`, `tailwind.config.js`, `app.json`, `codegen.ts`, `playwright.config.ts` | билд/тул конфиг |
| `frontend/src/app/_layout.tsx` + `(tabs)/_layout.tsx` | root layout и табовете — provider-и и навигация |
| `frontend/src/lib/*` (apollo, providers, theme, ui-store, i18n) | споделена инфраструктура от таск 3 |
| `frontend/src/global.css` | глобални стилове |
| `frontend/src/locales/{bg,en}/*.json` | по един namespace на област — фича таск пипа САМО своя файл |
| `frontend/public/*` (sw.js, manifest.json, icons) | PWA артефактите са от таск 40 |
| `.gitignore`, `README.md`, `rules/*.md`, `global.json` | root мета |

## §6. Команди и портове

```
dotnet test backend/PartyUp.slnx --nologo          # пълен BE suite (иска Docker Desktop!)
dotnet test backend/tests/PartyUp.UnitTests        # само unit, без Docker
npm --prefix frontend test                          # codegen + jest-expo
npm --prefix frontend run typecheck                 # codegen + tsc --noEmit
npm --prefix frontend run codegen                   # само регенерация на src/gql
npm --prefix frontend run test:e2e                  # Playwright (сам си вдига статиката) — НЕ е в гейта
cd backend && dotnet run --project src/PartyUp.Api -- schema export --output ../../../contracts/schema.graphql
```

⚠ **`codegen` е префикс на `test` и `typecheck`** — гола `npx tsc --noEmit` пада, защото `src/gql` може да не
съществува. Винаги през npm скриптовете.

**Verify гейтът (`repos.json`, дословно):** `npm --prefix frontend install` → `typecheck` → `test` →
`dotnet test backend/PartyUp.slnx` → `git checkout -- frontend/package-lock.json`.
Последното е ЗАДЪЛЖИТЕЛНА хигиена (инцидентът от 16.08: `npm install` мърда lock-а → мръсен checkout →
MERGE SKIPPED за всички следващи таскове).

**Портове (флотска сверка):** 45279 (inventory/hero/spells) и 45278 (combat) са ЗАЕТИ от другите репота.
Party Up ползва: **5001/5000** (BE dev, OAuth redirect-ите сочат 5001), **8081** (Expo dev) и **45280**
(Playwright статичен http-server). Няма колизии. Dev сървърите — НЕ от агенти (§4.4).

**Worktree бележка:** `npm --prefix frontend install` е ЗАДЪЛЖИТЕЛНА първа стъпка в нов worktree (node_modules не пътуват). NuGet пакетите идват от глобалния кеш — `dotnet restore` става имплицитно. Docker Desktop трябва да е СТАРТИРАН преди run (интеграционните тестове иначе падат с named pipe грешка).

**⚠ Metro замърсява checkout-а.** Всеки `expo export` / Metro прогон (значи и `e2e:export`, и `test:e2e`)
преформатира `frontend/tsconfig.json` (nativewind добавя `nativewind-env.d.ts` в include) и създава
`frontend/nativewind-env.d.ts` в корена. И двете трябва да се върнат ръчно:
`git checkout -- frontend/tsconfig.json` + изтриване на root-овия `nativewind-env.d.ts`.
(Комитнатият `src/lib/nativewind-env.d.ts` е ДРУГ файл — той остава.) Именно затова Playwright НЕ е в
гейта: добавянето му иска първо решение как се чисти това.

## §7. Тестово състояние (към 19.08.2026, след board 1–42)

- **BE: 429 теста зелени** — 129 unit (15 файла с тестове; 88 `[Fact]`/`[Theory]` + `[InlineData]` редове)
  + 300 integration (37 файла с тестове; 291 атрибута). Integration-ите са срещу истински Postgres
  в Testcontainers, споделен през `PostgresCollectionFixture`; автентикацията минава през `TestAuthHandler`.
- **FE: 268 jest теста в 48 suite-а** — 4 крос-екранни в `src/__tests__/`, останалите в областите
  (`__tests__/` подпапка или до файла). Топъл прогон ~8 сек, СТУДЕН (след промяна на jest конфига) ~21 сек.
- **Пълен verify гейт (install + typecheck + jest + dotnet): порядък минути**, доминиран от `dotnet test`
  с Testcontainers. `verify_timeout_min 45` остава с достатъчен запас.
- **e2e: Playwright съществува от таск 42 — 3 смоук спека, зелени на 45280, но НЕ са в гейта.**
  `playwright.config.ts`: `testDir e2e/`, `reuseExistingServer:false`, `workers:1`, `locale:'bg-BG'`
  (детерминирани i18n текстове), `webServer` = `npm run e2e:serve` = `codegen` + `expo export --platform web`
  + `prepare-static.mjs` + `http-server dist -p 45280`. **Няма dev сървър и няма жив BE** — `e2e/support.ts`
  стъбва `**/graphql` с `{ me: null }` (мрежова грешка НЕ е анонимен потребител за `AuthGate`).
  Спековете: (1) анонимен `/` → `/login` с трите провайдъра; (2) нула console error/pageerror при зареждане;
  (3) непознат маршрут → HTTP 404 + not-found екранът.
- **`jest.testTimeout: 30000`** (в `package.json`) е СЪЗНАТЕЛЕН — при студен babel кеш или натоварена машина
  дефолтните 5000 ms дават фалшиви таймаути (таскове 41 и 42 удариха точно това). Не го връщай надолу.
- ВНИМАНИЕ: RNTL v14 — `render` е ASYNC (`await render(...)`); `screen` API-то от v12/13 го НЯМА.
  TS 6.0 НЕ включва @types автоматично — types:["jest"] е вече в tsconfig.

## §7а. Амендмънти за фаза v0.1 (board 1-42) — ИСТОРИЯ, всички ЗАТВОРЕНИ

1. **§3.1 екзепция — ЗАТВОРЕНА.** Таск 2 ръчно написа целевата schema.graphql (contract-first, за да строи FE
   срещу нея с мокове). Таск 41 я замени с реалния Hot Chocolate експорт. Изравняването намери разминаване на
   **три операции**, всичките липсващи от BE-то (`myListing`, `notifications`, `markNotificationRead`) — контрактът
   беше прав, кодът ги нямаше; имплементирани са в 41. Останалото беше козметика (ред на полета, `@cost`,
   `@specifiedBy`) и се прие реалната страна. От тук нататък ръчна редакция = failed таск, без изключения.
2. **Vertical slice архитектура:** всеки use case = папка `Features/<Област>/<UseCase>/` (handler + HC type
   extension). Регистрация през source generator (`AddPartyUpTypes()`, котва `GraphQL/TypeModule.cs`)
   + IEndpointModule reflection. Program.cs беше пипан САМО от таскове 1 и 26.
3. **FE codegen:** `src/gql/` е GITIGNORED, генерира се в `test`/`typecheck`/`e2e:export` — генерираният код
   никога не се комитва (нулеви конфликти между паралелни FE таскове). Locale ns файловете и route
   placeholder-ите бяха създадени ВСИЧКИ от таск 3; фича таскът пълнеше само своите.
4. **DomainErrorType патерицата — МАХНАТА.** `Common/GraphQL/DomainErrorType.cs` вече НЕ съществува
   (изтрит координирано от първите mutation слайсове 4/5/6, защото се блъскаше с
   `ErrorObjectType<DomainError>` от mutation conventions). НЕ регистрирай ръчно `DomainError` тип —
   конвенцията го произвежда сама. (В `GraphQL/TypeModule.cs` е останал коментар, който сочи изтрития файл.)
5. **⚠ КОНВЕНЦИЯ ЗА QUERY ПОЛЕТА: `[ObjectType<Query>]`, НЕ `[QueryType]`.** `[QueryType]` extension-ите се
   ИЗХВЪРЛЯТ БЕЗШУМНО (Program.cs вика `AddQueryType<Query>()` → генераторският `TryAddRootType` no-op-ва) —
   полетата липсват от схемата БЕЗ никаква грешка. Всеки query таск задължително ползва `[ObjectType<Query>]`.
   Mutation root-ът НЕ е засегнат. **Това правило остава в сила и за следващите фази.**
6. **`[UseMutationConvention(PayloadFieldName = "...")]`** е ЗАДЪЛЖИТЕЛЕН, когато името на data полето в
   payload-а трябва да е различно от camelCase на върнатия C# тип (`success`, `linkedProviders`,
   `pushSubscription`). Иначе следващият ре-експорт вкарва drift. Детайлите: `contracts/DESIGN-NOTES.md` §1.2.

## §7б. REVIEW КРИТЕРИИ (за finishing review stage — ревюърът оценява diff-а СПРЯМО ТЯХ)

> Обвързващият текст живее в самото репо: `rules/architecture-rules.md` + `rules/i18n-rules.md`.
> Долното е същото, кондензирано за ревю стейджа.

**BE (C# / Hot Chocolate):**
1. Vertical slice дисциплина: нова логика живее в `Features/<Област>/<UseCase>/`; фича diff НЕ пипа Domain/Common/Program.cs/csproj. Нарушение = Блокер.
2. Зависимости навътре: slice не reference-ва типове на друг slice директно (само през Domain модела); без „сървиси-чували"; интерфейс само при реална подмяна (§2а.3) — двойка IXxx/Xxx по инерция = Важно.
3. Read дисциплина (§2а.4): query handler без AsNoTracking/Select проекция = Важно; вложена колекция без DataLoader (N+1) = Важно.
4. Result pattern (§4.5): очакван провал като exception = Блокер; raw exception, стигащ до GraphQL error без мапване = Блокер.
5. Тестове: нов use case без unit тест = Важно; персистенция без integration (Testcontainers) тест = Важно.

**FE (Expo / Apollo):**
6. Контрактът е закон: ръчно писани типове, дублиращи schema.graphql (вместо codegen от src/gql) = Важно; редакция на contracts/ от FE = Блокер.
7. Server state само в Apollo кеша, UI state само в Zustand (§2) — смесване = Важно.
8. i18n: хардкоднат UI низ = Блокер (§4.6); ключ в грешен namespace = Препоръка; ключ само в единия език = Важно.
9. Форми през react-hook-form; тестове с RNTL v14 async render (`await render`) — old-style = Важно (флейки).
10. Route файловете в `src/app/` са ТЪНКИ — бизнес логика в route файл = Важно.

**Общи (проверявай ПЪРВО):**
11. Секрети в diff-а (connection strings, client secrets, токени) = БЛОКЕР, винаги.
12. Несъответствие код ↔ contracts/schema.graphql = Важно (схемата вече е генерирана; drift значи че някой
    е пропуснал ре-експорт). Ръчна редакция на schema.graphql = Блокер.
13. Комитнат `src/gql/` или друг генериран артефакт = Блокер.
14. Мъртъв код, закоментирани блокове, TODO без референция = Препоръка.

**Калибровка на приоритетите:** Блокер = нарушена червена линия (§4) / счупена логика / секрет. Важно = нарушен патърн (§2а/§8а) с реален риск. Препоръка = стил и бъдещи подобрения. НЕ инфлирай: стилово мнение, маскирано като Важно, съсипва acceptance цикъла.

## §7в. Продуктови решения, вкоренени в кода (не ги предоговаряй от глава)

Пълният списък е в `contracts/DESIGN-NOTES.md` §4–§5. Най-често забравяните:

1. **Прагът 4 (`AdmissionThreshold`) е СЪРВЪРЕН** — константа в `Common/TableRules.cs`. `pullCandidate` връща
   `Candidacy.decision = null` при founder fast-path и попълнено при групово решение; FE ЧЕТЕ резултата,
   не преизчислява правилото.
2. **Гласовете са ЯВНИ** — `GroupDecision.votes` носи `voter: User!`. Никаква анонимизация.
3. **`GroupDecision.excludedUser`** покрива kick-а: засегнатият не гласува за собственото си махане.
4. **Кандидатът вижда НЕУТРАЛЕН резултат** — само `Notification` („не се получи мач"), никога кой и защо.
   Това е авторизационно правило на BE-то, не отделен тип в схемата.
5. **Листването не се „заключва" при дърпане** — `PlayerListing.active` пада само при приемане или ръчно.
   Няколко маси могат да гледат един човек паралелно.
6. **`stayOrLeave` НЕ е `GroupDecision`** — само „оставам"/„напускам".
7. **`refoundTable` връща НОВАТА маса**; старата остава на founder-а, поканите тръгват като нотификации.
8. **Без пагинация, без сортиране, без relay `node(id)`** — плоски списъци, `UUID` вместо `ID`.
   Единственото отклонение: `chat.messages(skip, take)` — опционални аргументи с таван, не Relay connection.
9. **`Notification.type` е `SCREAMING_SNAKE` низ**, payload-ът е `payloadJson: String!`. Живите типове:
   `DECISION_STALE`, `REFOUND_INVITE`, `NEW_MESSAGE`, `CANDIDACY_ACCEPTED`, `CANDIDACY_CLOSED`,
   `MEMBER_KICKED`, `MEMBER_LEFT`, `STAY_OR_LEAVE_PROMPT`.
10. **`hello` остава в схемата** — интеграционният smoke на таск 1 го ползва.

## §7г. i18n инвентар

`src/lib/i18n.ts`: i18next + react-i18next, език от `expo-localization` или ръчен override в ui-store-а;
`fallbackLng: 'en'`, `DEFAULT_NAMESPACE = 'common'`, нов инстанс при смяна на език (без `changeLanguage`).
**15 namespace-а × 2 езика (bg/en) = 30 файла** в `src/locales/`:
`common`, `auth`, `authLinking`, `profile`, `tables`, `tableForm`, `tableSettings`, `board`, `showcase`,
`candidacy`, `contact`, `chat`, `lifecycle`, `lifecycleActions`, `push`.
`domainErrorMessage(t, i18nKey)` мапва BE `DomainError.i18nKey` → текст, с fallback `common:errors.unknown`.

## §8. Правила за декомпозиция (за /ralph-plan)

- Lanes по зони: `contracts/BE` тасковете (C# + експорт) са СЕРИЙНИ помежду си (schema.graphql е отрова); FE тасковете се паралелизират срещу ЗАМРАЗЕН контракт.
- Фундаментен таск на фаза изяжда отровните файлове (DI wiring, provider-и, пакети), фича тасковете после не ги пипат.
- Всеки таск декларира `repo: "partyup"` (полето е задължително, дефолт НЯМА).
- Verify е общ за монорепото (BE+FE) — счупен FE тест блокира merge на BE таск и обратно. Това е НАРОЧНО (контрактът е общ).

## §9. Известни отворени точки след board 1–42 (кандидати за следваща фаза)

Не са бъгове — съзнателно оставени. Всяка иска свой таск и решение на ЧОВЕКА:

1. **Playwright не е в verify гейта.** Влизането му иска първо чистене на Metro замърсяването (§6):
   `frontend/tsconfig.json` + root `nativewind-env.d.ts`. `repos.json` НЕ е пипан от board-а.
2. **Full-stack e2e** (жив BE + Testcontainers compose) — сегашните 3 спека са неавтентикирани пътеки с един стъб.
3. **Локализиран `src/app/+not-found.tsx`** — 404 сега е вграденият англоезичен екран на expo-router,
   извън root layout-а и без пазач. Спекът описва ТЕКУЩОТО, не желаното поведение.
4. **Push прогресивното подобрение не е закачено за екран** — `PushPrompt`/`usePushSetup` и `NotificationBell`
   съществуват и са тествани, но никой екран не ги монтира.
5. **EF migrations** (§3.5) — иска се преди първи прод deploy.
6. **`metro.config.js` tslib резолвърът** беше единствената промяна извън обхвата на таск 42. Ревертът му
   чупи `expo export --platform web` и с това целия e2e — ревюирайте съзнателно.
