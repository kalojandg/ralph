# Party Up — Architecture Reference

> Прочети този файл ПРЕДИ да пишеш код. Патърните тук са ПРАВИЛА, не препоръки.
> Приложение: TTRPG matchmaking (pull модел — играчите се публикуват на LFG борд,
> МАСИТЕ дърпат кандидати). Монорепо, TDD от commit 1. Пълната продуктова
> спека: `party-up.md` в D:\Downloads\monk\ (секции А–Е + Решения лога).
> **Състояние: board 1–42 (v0.1), 101–108, 201–213 и 301–308 са ЗАТВОРЕНИ и мерджнати в
> `main`.** Всички таскове са зелени през гейта (fix-цикли по code review след 201–213 и
> след 301–308 са си отделни комити, вече слети). Файлът описва РЕАЛНОСТТА след тях, не скелета.
> Board 101–108 добави desktop/responsive полиране на екраните; 201–213 добави in-app навигация,
> logout, tab theming, LFG филтри и „Данни и поверителност" (deleteAccount, my-data export);
> 301–308 добави dev-login за multi-account тестване, живо потвърждение на subscriptions-a,
> privacy fix-ове (език-неутрален сентинел, преведени грешки при сваляне, ретеншън тестове) и
> продуктовата обиколка (tour). Секции §7а/§7б/§7в все още описват предимно board 1–42 —
> детайлите на 101–308 живеят в §1а/§1б/§7/§7г по-долу, обновени на място.

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
│   │                                i18n.ts, session.ts, config.ts, user-name.ts (таск 304 — единственото
│   │                                място, което познава `__deleted__` сентинела и го превежда)
│   ├── src/locales/{bg,en}/      ← по 16 namespace JSON файла на език (виж §7г)
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

Схемата излиза с **19 query, 27 mutation, 2 subscription** (растежът от 18/25/2 е от board 211–213:
`myDataExport`, `deleteAccount`, `requestDataExport`). Кой slice какво издава:

| Slice | Use case папки | GraphQL операции |
|---|---|---|
| `Auth` | Login, Logout, Me, **DevLogin** (таск 301) | HTTP `GET /auth/login/{provider}`, `GET /auth/callback`, `GET /auth/dev-login?user=&returnUrl=` (НЕ GraphQL, само `Development`); `logout`; `me` |
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
| `Privacy` | DeleteAccount, Export (board 211–213, полирана в 303–306) | `deleteAccount` (hard delete на личните данни + `AccountAnonymization.Scrub`); `myDataExport`, `requestDataExport` (mutation-ът пуска фонова обработка); `GET /privacy/export` (HTTP файл, НЕ GraphQL — сваля готовия архив на СЕСИЯТА, без `:id` аргумент) |

**`Privacy` в детайли** (структурата не беше документирана след board 211–213, наваксва се тук):
- `DeleteAccount/AccountAnonymization.cs` — статичните правила „какво остава от изтрит човек":
  профилният ред и identity полетата се ОБЕЗЛИЧАВАТ на място (relational следите — членства,
  реплики, гласове — трябва да останат валидни FK-та), самият `AppUser` ред оцелява гол.
  `DeletedDisplayName = "__deleted__"` (**от таск 303**: беше literal `"Изтрит потребител"` —
  сменено на език-неутрален сентинел, защото displayName е СТОЙНОСТ на данни, не UI низ, и FE
  трябва да го разпознае и преведе, не да го покаже суров на англоезичен потребител). Отказва
  изтриване, ако акаунтът все още държи основател на жива маса (`FOUNDER_HAS_ACTIVE_TABLE`) —
  насочва към „преоснови"/„напусни", не exception.
- `Export/` — `requestDataExport` пуска заявка (Pending), `DataExportWorker` я сглобява асинхронно
  (виж по-долу за background service изключението), `myDataExport` чете разписката, `GET
  /privacy/export` сваля готовия JSON. **Таск 305** премести UI грешките от суров JSON в браузъра
  към преведени съобщения в екрана (fetch + credentials вместо навигация, освен на native, където
  няма `fetch`/`Blob`/DOM за programmatic download). **Таск 306** покри ретеншън суийпа
  (`DataExportRetention.ForgetExpiredAsync`) с unit + integration тестове.

**Домейн (13 entity-та, `Domain/`):** `AppUser`, `UserProfile`, `PlayerListing`, `Table`, `TableMembership`,
`Candidacy`, `GroupDecision`, `Vote`, `Chat`, `ChatParticipant`, `Message`, `Notification`, `PushSubscription`.
**9 enum-а в `Domain/Enums.cs`:** ExperienceLevel, GameFormat, TableStatus, AdmissionMode, MembershipRole,
CandidacyStatus, DecisionTopic, DecisionStatus, ChatType (+ `AuthProvider` и `PushDelivery` в своите slice-ове).

**Интерфейси — точно ТРИ (§2а.3 се спазва):** `IEndpointModule` (единствена имплементация `AuthEndpoints`,
намира се с reflection), `INotifier` (`DefaultNotifier` → декориран от `FanoutNotifier`, който публикува топик
и праща Web Push), `IPushSender` (`WebPushSender`; тестови двойници `StubPushSender`/`RecordingPushSender`).

**⚠ Почти няма hosted/background services — но вече ИМА ЕДНО, изрично решение, не пропуск.**
Повечето авто-поведения си остават МЪРЗЕЛИВИ, задействат се при заявка: `TableDelistService`
(сваля обявата при пълна маса), `UnpublishService` (сваля LFG обявата при приемане),
`StaleDecisionFinder` + `StaleDecisionRules` (заспал гласоподавател: 3 дни праг, 3 дни макс. snooze,
`DECISION_STALE`). **Изключението: `DataExportWorker` (board 211–213, `Features/Privacy/Export/`)
е ПЪРВИЯТ `BackgroundService`** — регистриран през `PrivacyExportServices.AddPrivacyExport()`
(Program.cs не е пипан за това). Върши две неща едновременно: (1) чете `DataExportQueue` канал и
сглобява заявените архиви асинхронно — прекалено бавно за GraphQL заявка, която браузърът чака;
(2) на `PeriodicTimer` (6 часа, `DataExportRetention.SweepInterval`) забравя съдържанието
(`Json = null`, без да материализира редове) на архиви с изтекъл `ExpiresAt` — статусът остава
`Ready`/`Expired` е прочит на часовника, редът оцелява като разписка. Не въвеждай СЛЕДВАЩ
`BackgroundService` без решение на потребителя — този е обоснованото изключение, не прецедент.

### §1б. FE маршрути и области

**Табове — точно 3** (`src/app/(tabs)/_layout.tsx`, `Tabs` от `expo-router/js-tabs`): `board`, `tables`, `profile`.
`/` пренасочва към `/board`.

| Маршрут | Екран | Област (`src/features/`) |
|---|---|---|
| `/login` | LoginScreen (3 OAuth бутона) | `auth` |
| `/settings` | линкнати профили, тема, „Пусни обиколката отново" (таск 308), изход, Данни и поверителност (export/delete) | `auth-linking` (+ `RestartTourSection` от `tour`) |
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

**`/auth/dev-login?user=<име>&returnUrl=<път>` (таск 301) НЯМА FE екран/линк** — гол backend URL,
хвърлен ръчно в браузъра от разработчика за многоакаунтово тестване (виж §1а `Auth`); маршрутизира се
само в `Development`. FE-то не знае за него.

**Няма `src/hooks/`** — hook-овете живеят в своята област (`use-session`, `use-logout`, `use-auth-linking`,
`use-danger-action`, `use-push-setup`) или в `src/lib` (`useThemeMode`, `useUiLanguage`, `useUiStore`).

### §1в. Продуктова обиколка (`src/features/tour/`, board 307–308)

Спотлайт-гид върху цялото приложение — 8 стъпки: борд → филтри → витрина → моите маси → камбанка →
тема/език/настройки в header-а. Овърлеят виси в `AppShell` (§1б — извън центрираната web колона,
координатите му са спрямо целия прозорец), не в отделен route, за да преживее навигацията между
стъпките.

- `tour-store.ts` — Zustand машина: `steps`/`index`/`active`, чисто UI състояние (§7б.7), нищо
  персистиращо. И довършена, и пропусната обиколка вдига `tourSeen` в `ui-store` (персистиращия
  стор) — иначе „Пропусни" би я връщала при всяко влизане.
- `tour-content.ts` — самите 8 стъпки (`TOUR_STEPS`), всяка сочи `targetTestId` (съществуващ testID
  за spotlight изрез) или `null` (центриран панел без изрез — за CTA-та без testID на екрани извън
  files зоната на този таск: публикувай се, отвори филтрите, „виж масите"). `bell`-стъпката пада на
  затъмнение без изрез, докато `NotificationBell` не бъде закачена за екран (виж §9 т.4 — все още
  чака).
- `tour-geometry.ts` / `tour-target.ts` / `use-tour-target.ts` — смятат spotlight изреза (банди
  затъмнение около правоъгълника на таргета) и позицията на тултипа; мерят реалния DOM с ретраи
  (елементът може все още да не е monut-нат при навигация между стъпки).
- `tour-overlay.tsx` / `tour-mount.tsx` — видимата част: затъмнен фон + изрез + тултип с
  „Назад / Напред / Пропусни" (`TOUR_CONTROL_KEYS`); `TourMount` е фасадата, монтирана в
  `AppShell`.
- `tour-autostart.ts` — автостарт при първи вход: САМО за истинска сесия (`resolved && user`),
  пази от старт докато сесията се проверява, спира при вече видяна обиколка (`tourSeen`).
- `restart-tour-section.tsx` — картата в `/settings` (`RestartTourSection`, таск 308):
  единственият начин обиколката да се види пак ръчно, след като автостартът е замлъкнал.
- `tour.json` (bg/en, нов namespace) — заглавия/текстове на стъпките + бутоните на овърлея.

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

7. **Защо НЕ clean architecture с отделни проекти (питано 19.08, отговорът е финален):** прилика има —
   дисциплината е същата (домейнът отделен, read дисциплина, handler per use case) — но подредбата е
   НАРОЧНО един проект: `Features/*` са вертикални отрези (таск = папка = lane = зона на собственост за
   swarm паралелизма), а `Domain/Data/Common/GraphQL` са shared kernel, НЕ слоеве, през които се минава.
   Отделни Application/Infrastructure/Domain проекти биха купили csproj+DI церемония и mapping шум срещу
   нула полза на този мащаб, а всяка фича би пипала няколко проекта → отровните файлове се множат →
   паралелизмът пада. Границите ВЕЧЕ са начертани по slice-ове, затова изваждане на проекти по-късно е
   механичен еднодневен таск — прави се ЧАК когато се появи втори процес/хост (worker за фонови job-ове,
   отделен realtime хъб), който трябва да сподели Domain+Data. Дотогава: не предлагай и не прави
   разслояване по проекти.

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

## §7. Тестово състояние (към 22.08.2026, след board 301–308 — преброено с реален прогон, не оценка)

- **BE: 508 теста зелени** — 157 unit (20 файла с `[Fact]`/`[Theory]`) + 351 integration (41 файла).
  Integration-ите са срещу истински Postgres в Testcontainers, споделен през `PostgresCollectionFixture`;
  автентикацията минава през `TestAuthHandler`. Ръстът спрямо board 1–42 (429 теста) идва от board
  101–213 (settings/lifecycle полиране, privacy) и 301–308 (`DevLoginEndpointsTests`,
  `DataExportRetentionTests` unit+integration, `AccountAnonymizationTests`).
- **FE: 436 jest теста в 70 suite-а** — расте спрямо board 1–42 (268/48) най-вече от `features/tour/`
  (7 нови suite-а) и privacy/apollo/user-name покритието на 301–308. Топъл прогон ~30 сек в CI
  контейнер (по-бавно от старите ~8 сек локално — машинно-зависимо, не регресия).
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

## §7а1. Амендмънти за board 211–308 — ИСТОРИЯ, всички ЗАТВОРЕНИ

Board 101–108 и 201–210 бяха предимно UI полиране (desktop grid, header навигация, tab theming,
LFG филтри) без нови архитектурни решения извън вече записаните по-горе. Следните са изричните:

1. **Първият `BackgroundService` (board 211–212, потвърдено изключение).** `DataExportWorker`
   чупи „няма hosted services" — виж §1а по-горе за пълното описание. Решено съзнателно (коментар
   в кода цитира точно тази структурна забрана), не пропуск.
2. **Анонимизираното displayName е език-неутрален сентинел, не BG литерал (таск 303, поправя board
   211).** `AccountAnonymization.DeletedDisplayName` тръгна като `"Изтрит потребител"` — стигаше
   необработено до англоезичен UI. Сменено на `"__deleted__"`; FE-то (`user-name.ts`, таск 304) е
   ЕДИНСТВЕНОТО място, което го разпознава и превежда (`t('user.deleted')`, `common` namespace).
   Договорът е буквалният низ между двете lanes — не се преизчислява.
3. **Файлово сваляне (`GET /privacy/export`) с преведени грешки, не сурова навигация (таск 305).**
   На web свалянето минава през `fetch({credentials:'include'})` + `Blob` вместо browser navigation
   към endpoint-а — иначе провал (410 изтекъл архив, 401 изгубена сесия) показва суров JSON
   директно в браузъра. Native остава на обикновено пренасочване (няма `fetch`/DOM там).
   Endpoint-ът сам сяда с `Cache-Control: no-store` — личен архив не бива да оцелее в дисков кеш.
4. **`dev-login` е чист development escape hatch, не auth провайдър (таск 301).**
   Мапва се от `IEndpointModule` само ако `IHostEnvironment.IsDevelopment()` — 404 по конструкция
   на рутера извън dev, не runtime проверка. Провайдър-таг `"dev"` НЕ е в затвореното
   `ExternalAuthProviders` множество (§2а.7/DESIGN-NOTES §1.4) и не трябва да е.
5. **`onMessage`/`onNotification` subscriptions бяха жични от по-рано (3cc4a2e, 724d8b2) — таск 302
   само добави недостигащия regression тест** (`apollo.test.ts`): split link избира ws транспорт за
   subscription и HTTP+credentials за query/mutation; счупен split link не гърми, пада обратно на
   HTTP.
6. **Продуктова обиколка (`tour`, board 307–308)** — виж §1в по-горе за пълното описание.

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
**16 namespace-а × 2 езика (bg/en) = 32 файла** в `src/locales/` (`tour` е нов, board 307–308):
`common`, `auth`, `authLinking`, `profile`, `tables`, `tableForm`, `tableSettings`, `board`, `showcase`,
`candidacy`, `contact`, `chat`, `lifecycle`, `lifecycleActions`, `push`, `tour`.
`domainErrorMessage(t, i18nKey)` мапва BE `DomainError.i18nKey` → текст, с fallback `common:errors.unknown`.

## §8. Правила за декомпозиция (за /ralph-plan)

- Lanes по зони: `contracts/BE` тасковете (C# + експорт) са СЕРИЙНИ помежду си (schema.graphql е отрова); FE тасковете се паралелизират срещу ЗАМРАЗЕН контракт.
- Фундаментен таск на фаза изяжда отровните файлове (DI wiring, provider-и, пакети), фича тасковете после не ги пипат.
- Всеки таск декларира `repo: "partyup"` (полето е задължително, дефолт НЯМА).
- Verify е общ за монорепото (BE+FE) — счупен FE тест блокира merge на BE таск и обратно. Това е НАРОЧНО (контрактът е общ).

## §9. Известни отворени точки след board 301–308 (кандидати за следваща фаза)

Не са бъгове — съзнателно оставени. Всяка иска свой таск и решение на ЧОВЕКА. Списъкът е от board
1–42 и остава непроменен през 101–308 — никоя от точките не е засегната или затворена от по-новите
board-ове:

1. **Playwright не е в verify гейта.** Влизането му иска първо чистене на Metro замърсяването (§6):
   `frontend/tsconfig.json` + root `nativewind-env.d.ts`. `repos.json` НЕ е пипан нито от board 1–42,
   нито от следващите.
2. **Full-stack e2e** (жив BE + Testcontainers compose) — сегашните 3 спека са неавтентикирани пътеки с един стъб.
3. **Локализиран `src/app/+not-found.tsx`** — 404 сега е вграденият англоезичен екран на expo-router,
   извън root layout-а и без пазач. Спекът описва ТЕКУЩОТО, не желаното поведение.
4. **Push прогресивното подобрение не е закачено за екран** — `PushPrompt`/`usePushSetup` и `NotificationBell`
   съществуват и са тествани, но никой екран не ги монтира. Обиколката (§1в, board 307–308) вече го
   знае и си трае: `bell` стъпката пада на затъмнение без изрез, докато `NotificationBell` не се
   закачи — тогава ще проблесне сама, без промяна в `tour-content.ts`.
5. **EF migrations** (§3.5) — иска се преди първи прод deploy.
6. **`metro.config.js` tslib резолвърът** беше единствената промяна извън обхвата на таск 42. Ревертът му
   чупи `expo export --platform web` и с това целия e2e — ревюирайте съзнателно.
7. **`dev-login` (таск 301) няма rate limit/аудит и НЕ е защитен от нищо друго освен
   `IsDevelopment()`.** Достатъчно за локално multi-account тестване; ако някога влезе в shared dev
   deploy (не само localhost), иска собствено решение (auth пред него или премахване).
