# Party Up — Architecture Reference

> Прочети този файл ПРЕДИ да пишеш код. Патърните тук са ПРАВИЛА, не препоръки.
> Приложение: TTRPG matchmaking (pull модел — играчите се публикуват на LFG борд,
> МАСИТЕ дърпат кандидати). Монорепо, TDD от commit 1. Пълната продуктова
> спека: `party-up.md` в D:\Downloads\monk\ (секции А–Е + Решения лога).
> **Състояние: board 1–42 (v0.1), 101–108, 201–213, 301–308, 401–431 и 501–517 са ЗАТВОРЕНИ и
> мерджнати в `main`; board 601–621 (деплой вълна), 701–705 (fix/finishing вълна) и 801 (fix) са
> ЗАТВОРЕНИ и мерджнати в `develop`, все още НЕ са слети в `main`.** Всички таскове са зелени през
> гейта (fix-цикли по code review след всяко от тези board-ове са си отделни комити, вече слети).
> Файлът описва РЕАЛНОСТТА след тях, не скелета.
> **Board 701–705 добави:** „Авто" тема на таб бара/датапикъра следва NativeWind вместо
> `Appearance`, за да съвпада с оцветеното от NativeWind съдържание на статичния web export (701);
> коренният route пуска нерезолвнат гост към `/showcase`, не `/login` (702), с гост линк обратно от
> `LoginScreen`; `GET/HEAD /healthz`, за да минат безплатните uptime pinger-и, които пращат HEAD
> (703); евикция на кешираната `tablesShowcase` при `setTableListing`, за да види витрината/„Моите
> маси" превключването без F5 (704); infinite scroll на витрината — `first`/`after`/`pageInfo` на
> `TablesShowcaseDocument` + скрол-до-дъното с бутон „Зареди още" fallback (705, огледално на борда
> от таск 411). Затваря §9 т.10 (витрината няма infinite scroll) изцяло — виж §7а5.
> **Board 801 добави (заменя подхода на 702, виж §7а6):** коренът (`app/index.tsx`) вече е
> ЕДИНСТВЕНИЯТ, който решава накъде отива посетителят — чете `useSession()` пряко, стои на `null`
> докато сесията пътува, `/board` за влязъл потребител, `/showcase` за всичко останало; `AuthGate`
> изгуби `isRoot` клона и пази само „защитен route + ясно «няма сесия» → `/login`", празните
> `segments` спряха да значат „това е коренът". Затваря прод бъг от 19.09 (React #185, бял екран при
> Back след гост вход от корена).
> Board 101–108 добави desktop/responsive полиране на екраните; 201–213 добави in-app навигация,
> logout, tab theming, LFG филтри и „Данни и поверителност" (deleteAccount, my-data export);
> 301–308 добави dev-login за multi-account тестване, живо потвърждение на subscriptions-a,
> privacy fix-ове (език-неутрален сентинел, преведени грешки при сваляне, ретеншън тестове) и
> продуктовата обиколка (tour). **401–431 (v0.5 SCOPE) добави:** отворени walk-in маси с мек
> лимит на местата (402/412), cursor пагинация (Relay connections) на борда и витрината, вкл.
> infinite scroll на борда (401/411), гео регистър на населени места с български seed и
> typeahead (403/414 — типаход-ът е ПОСТРОЕН, но СЪЗНАТЕЛНО не е закачен за формите, виж §9),
> публична витрина за отворени маси с гост CTA (413), preferences по категория известия,
> отгласени от фан-аута (404/415) и МОНТИРАНИ в `/settings` (431), rate limiting на auth/GraphQL/
> export (421), лифтнат `ProvisioningService` над login/dev-login (422) и опционален споделен
> token пред dev-login (423). **Board 501–517 (fix/finishing вълна) добави:** реално отворени
> WebSocket ъпгрейди за subscriptions (501 — иначе graphql-ws мълчаливо не се свързваше), поправка
> на витрината (502 — кандидатска маса без обява вече е скрита, отворената се вижда ВИНАГИ),
> `myCandidacies` заявка + екран „Моите кандидатури" на `/candidacies` (503/516), спрян Facebook
> бутон (513), logout директно в глобалния хедър (511), закачена `NotificationBell` в хедъра с
> врата към чатовете (512 — затваря половината от §9 т.4), write-through Apollo кеш дисциплина за
> борд/candidacy/my-tables списъците след мутации (514 — виж §1г), разкачване на дърпането от
> обявата + видим бадж „обявена/необявена" (515), и поправка на date/time picker-а да отваря на клик
> навсякъде в полето, не само на иконката (517). Секции §7а/§7б/§7в описват board 1–42 — детайлите на
> 101–308 живеят в §1а/§1б/§7/§7г, на 401–431 в §7а2, на 501–517 в §7а3, на 601–621 в §7а4, на
> 701–705 в §7а5, а на 801 в §7а6 по-долу, обновени на място.

## §1. Файлова карта (монорепо)

```
party-up/
├── backend/
│   ├── PartyUp.slnx              ← .NET 10 solution (СЛЪНЦЕТО Е .slnx, НЕ .sln!)
│   ├── src/PartyUp.Api/          ← единственият BE проект: minimal API + Hot Chocolate
│   │   ├── Program.cs            ← DI + GraphQL pipeline + RunWithGraphQLCommandsAsync (дава schema export)
│   │   ├── Domain/               ← ЦЕЛИЯТ модел (17 entity-та вкл. AppUser + Enums.cs, 10 enum-а)
│   │   │                            — фича таск по правило НЕ добавя тук; таск 402/403 са
│   │   │                            изричното изключение (AdmissionKind, Domain/Geo/Settlement)
│   │   ├── Data/PartyUpDbContext.cs  ← IdentityDbContext<AppUser, IdentityRole<Guid>, Guid>, 16 DbSet-а
│   │   ├── Common/               ← Results/ (Result, DomainError), GraphQL/MutationResult.cs,
│   │   │                            Notifications/INotifier.cs, Endpoints/IEndpointModule.cs,
│   │   │                            CurrentUser.cs, FrontendOptions.cs, TableRules.cs,
│   │   │                            RateLimiting/ (RateLimitingSetup, RateLimitingOptions — таск 421,
│   │   │                            класифицира по PATH, не по slice, затова живее в Common),
│   │   │                            Hosting/ (HostingSetup, CookieSecurityOptions — таск 602,
│   │   │                            cross-site бисквитки + forwarded headers, виж „Hosting в
│   │   │                            детайли" по-долу)
│   │   ├── GraphQL/              ← Query.cs (root, само `hello`) + TypeModule.cs
│   │   │                            ([assembly: Module("PartyUpTypes")] — котвата на генератора)
│   │   ├── Features/             ← ВСИЧКАТА фича логика, vertical slices (виж §1а), вкл.
│   │   │                            Health/HealthEndpoints.cs (таск 602 — `GET /healthz`, liveness;
│   │   │                            таск 703 добави `HEAD` на СЪЩИЯ path за безплатните uptime pinger-и)
│   │   ├── Migrations/           ← EF migrations (таск 601): DatabaseStartup.cs (решение среда→
│   │   │                            действие + изпълнение), PartyUpDbContextFactory.cs (design-time
│   │   │                            factory за `dotnet ef`), `<timestamp>_InitialCreate.cs` +
│   │   │                            `.Designer.cs` + `PartyUpDbContextModelSnapshot.cs` (генерирани,
│   │   │                            НЕ се пипат на ръка), README.md (правилото „миграция в СЪЩИЯ
│   │   │                            commit" + таблица среда→действие, виж §3.6)
│   │   └── Properties/launchSettings.json  ← портове 5001 (https) / 5000 (http) — OAuth redirect-ите са на 5001!
│   ├── Dockerfile                ← прод image (таск 603): SDK build stage → aspnet runtime stage,
│   │                                ENTRYPOINT сглобява ASPNETCORE_URLS от Render-овия $PORT
│   ├── .dockerignore
│   └── tests/
│       ├── PartyUp.UnitTests/        ← xUnit, бързи, БЕЗ Docker
│       └── PartyUp.IntegrationTests/ ← xUnit + Testcontainers.PostgreSql (истински Postgres в Docker)
│           ├── Foundation/           ← cross-cutting инфраструктурни тестове, извън Features/
│           │                           (RateLimitingTests, GraphQLWebSocketTests, DatabaseMigrationTests
│           │                           — таск 601, Hosting/ — CookiePolicyTests/FrontendOriginsTests/
│           │                           HealthEndpointTests, таск 602)
│           └── Support/              ← ApiFactory, ApiTestBase, PostgresCollectionFixture,
│                                        TestAuthHandler, TestSessionQueries (СПОДЕЛЕНИ — не се преправят)
├── .github/workflows/ci.yml      ← GitHub Actions (таск 621): frontend (typecheck+test) и backend
│                                    (dotnet test) на всеки push към develop/main + PR към main;
│                                    e2e (Playwright) само на push към main, след като горните минат
├── render.yaml                   ← Render Blueprint за бекенда (таск 603): Docker web service,
│                                    healthCheckPath /healthz, envVars със sync:false (секретите се
│                                    слагат ръчно в Render dashboard, НЕ тук)
├── frontend/                     ← Expo SDK 57 (web-first PWA + native)
│   ├── src/app/                  ← Expo Router — ТЪНКИ route файлове (виж §1б)
│   ├── src/features/<област>/    ← ЦЯЛАТА екранна логика: компоненти, hooks, *.gql.ts документи, тестове
│   ├── src/lib/                  ← apollo.ts, providers.tsx, auth-gate.tsx, theme.tsx, ui-store.ts,
│   │                                i18n.ts, session.ts, config.ts (`API_BASE_URL` от
│   │                                `EXPO_PUBLIC_API_URL` build-time env, fallback localhost:5000 —
│   │                                таск 611), user-name.ts (таск 304 — единственото
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
│   ├── schema.graphql            ← ЖИВИЯТ КОНТРАКТ BE↔FE (реален експорт от Hot Chocolate, 808 реда)
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

Схемата излиза с **22 query, 28 mutation, 2 subscription** (растежът от 19/27/2 е от board 401–431:
`settlements(search)` + `myNotificationPreferences` на query страната, `setNotificationPreference`
на mutation страната; `lfgBoard`/`tablesShowcase` останаха отделни полета, но смениха форма —
виж реда `Lfg` по-долу; таск 503 добави `myCandidacies` — 21→22). Кой slice какво издава:

| Slice | Use case папки | GraphQL операции |
|---|---|---|
| `Auth` | Login, Logout, Me, **DevLogin** (таск 301, опционален token таск 423) | HTTP `GET /auth/login/{provider}`, `GET /auth/callback`, `GET /auth/dev-login?user=&returnUrl=&token=` (НЕ GraphQL, само `Development`); `logout`; `me`; `ProvisioningService.cs` виси директно в `Features/Auth/` (плосък, таск 422 — споделен между Login и DevLogin, не собственост на нито един от двата) |
| `AuthLinking` | (плосък) | `linkedProviders`, `linkProviderUrl(provider)`, `unlinkProvider` |
| `Profiles` | MyProfile, UpdateProfile | `myProfile`, `updateProfile` |
| `MyTables` | (плосък) | `myTables` |
| `Tables` | CreateTable, Settings, Listing | `createTable`, `updateTableSettings`, `setTableListing` — и двата мутатора носят `admissionKind`/`slotsFirm` от таск 402/412 (walk-in маси, мек лимит на местата — `SlotLimitRules.AllowsSlots`) |
| `Geo` | Import, Search (таск 403/414) | `settlements(search)` — публичен typeahead reg. на населени места (БЕЗ `[Authorize]`, четe го и анонимната витрина); **няма mutation** — реестърът се пълни само през `settlements import` CLI команда, не през GraphQL |
| `Lfg` | Board, Publish, Showcase | `lfgBoard(filter, first, after, last, before): LfgBoardConnection`, `tablesShowcase(filter, first, after, last, before): TablesShowcaseConnection` — cursor connections от таск 401 (`[UsePaging]`, `LfgPagingDefaults`: `DefaultPageSize=20`, `MaxPageSize=50`); `myListing`, `publishMyListing`, `unpublishMyListing`, `table(id)`. **Таск 502:** `tablesShowcase` вече филтрира `AdmissionKind == Open OR ListingActive` (преди: само `Status != Disbanded`) — кандидатска маса без обява е скрита от витрината, отворената (walk-in) маса се вижда ВИНАГИ, независимо от `ListingActive`. **Таск 705 (FE):** `TablesShowcaseDocument` вече праща `first`/`after` и чете `pageInfo` — infinite scroll на витрината, огледално на борда |
| `Decisions` | (плосък) | `groupDecision(id)`, `castVote` |
| `DecisionAlerts` | (плосък) | `staleDecisions`, `snoozeDecision` |
| `Candidacies` | Pull, Contact, Verdict | `candidacy(id)`, `myTableCandidacies(tableId)`, `myCandidacies` (таск 503 — гледната точка на КАНДИДАТА, филтър по `CandidateUserId` вместо `membership.UserId`; изисква сесия, хвърля GraphQL грешка на анонимен викащ вместо тих празен списък), `pullCandidate`, `openContactChat`, `submitVerdict` |
| `Chats` | Messaging, Subscriptions | `myChats`, `chat(id)`, `sendMessage`, `onMessage(chatId)`, `onNotification` |
| `Notifications` | (плосък) | `notifications(unreadOnly)`, `markNotificationRead` |
| `Lifecycle` | Trial, Leave, Kick, Refound | `startTrial`, `startDecidingPhase`, `finalizeDeciding`, `stayOrLeave`, `leaveTable`, `proposeKick`, `refoundTable`, `acceptRefoundInvite` |
| `Push` | Subscriptions, Vapid, **Preferences** (таск 404) | `pushSubscribe`, `pushUnsubscribe`, `vapidPublicKey`, `myNotificationPreferences`, `setNotificationPreference(category, enabled)` |
| `PushSend` | (плосък) | **няма GraphQL** — инфраструктурен slice (FanoutNotifier, WebPushSender, `AddPushFanout()`); `FanoutNotifier` пита `NotificationPreferenceHandler.AllowsPushAsync` ПРЕДИ да прати Web Push (таск 404 — виж бележката за посоката на зависимостите по-долу) |
| `Privacy` | DeleteAccount, Export (board 211–213, полирана в 303–306) | `deleteAccount` (hard delete на личните данни + `AccountAnonymization.Scrub`); `myDataExport`, `requestDataExport` (mutation-ът пуска фонова обработка); `GET /privacy/export` (HTTP файл, НЕ GraphQL — сваля готовия архив на СЕСИЯТА, без `:id` аргумент) |

**`Common/RateLimiting/` в детайли (таск 421, инфраструктура над всички slice-ове, не свой slice):**
вграденият ASP.NET `PartitionedRateLimiter`, ЕДИН глобален лимитер (не именувани политики по
endpoint) — класификацията по път живее в `RateLimitingSetup.Classify`: `/auth/*` и
`/privacy/export` са строги fixed-window (10/мин, партиция по user id ако има сесия, иначе IP);
автентикираният `POST /graphql` е умерен sliding-window (60/мин); **анонимният** `POST /graphql`
(витрина, `settlements` typeahead) е ПО-ЩЕДЪР (300/мин) — IP партицията му е споделена зад NAT
(„QR кодът на бармана", cycle 2 находка). `Development` НИКОГА не се дросълва. Testing средата
взима щедри лимити по подразбиране (споделената интеграционна фикстура минава стотици заявки в
един прозорец); тестове, които искат РЕАЛНИТЕ лимити, ги завъртат надолу сами
(`Foundation/RateLimiting/RateLimitingTests.cs` — нова top-level папка в IntegrationTests за
инфраструктурни тестове, извън `Features/`).

**`Common/Hosting/` в детайли (таск 602, `HostingSetup.AddPartyUpHosting`, вика се от Program.cs
СЛЕД `AddIdentityCookies()` — именуваните options конфигуратори важат по ред на регистрация):**
две решения на едно място, защото и двете отговарят на въпроса „FE и BE не са на един origin":
(1) **cross-site бисквитки** — `CookieSecurityOptions.CrossSite` (конфиг `Cookies:CrossSite`,
`null` = средата решава: Production → `SameSite=None`+`Secure`, всичко друго → днешното `Lax`);
изрична стойност е за деплой, който не се казва „Production" (preview/Staging на същата
топология). (2) **forwarded headers** — Render терминира TLS-а пред контейнера, `UseForwardedHeaders()`
(първият middleware в Program.cs, ПРЕДИ CORS/cookie политиката/rate limiter-а) превежда
`X-Forwarded-Proto`/`X-Forwarded-For`; `KnownNetworks`/`KnownProxies` са изрично изпразнени —
безопасно САМО защото контейнерът е достъпен единствено през прокси-то на Render (виж §9, точката
за VM с отворен порт). Затваря §9 т.11 (rate limiter-ът вече вижда честно клиентско IP). CORS
origin-ите (`Frontend:Origins`) вече идват от конфигурация, не от твърд списък — СЪЩИЯТ списък е
whitelist-ът на OAuth `returnUrl` (`FrontendOptions.IsAllowedReturnUrl`), един източник за две
защити. `GET/HEAD /healthz` (`Features/Health/HealthEndpoints.cs`) е СЪЗНАТЕЛНО liveness БЕЗ db ping —
Neon free tier заспива/буди се за секунди, сонда която чака базата би обявила живото приложение за
мъртво точно при cold start. **Таск 703** добави `HEAD` на СЪЩИЯ path (`MapMethods`, не `MapGet`):
безплатните uptime мониторъри (UptimeRobot) пращат HEAD, а `MapGet` сам отговаря 405 на HEAD —
изглежда като „Down", докато GET-ът си е жив. Тялото се пропуска изрично на HEAD (Kestrel го прави
сам за статични файлове, но не за custom handler-и, а тестовият in-memory сървър изобщо не го прави).

**EF migrations в детайли (таск 601, `Migrations/`):** пълната процедура и таблицата
среда→действие живеят в `backend/src/PartyUp.Api/Migrations/README.md` — не се дублират тук.
Накратко: `Production` старт вика `DatabaseStartup.ApplyAsync` → `Database.MigrateAsync()` (прод
базата НИКОГА не се дропва/пресъздава); `Development` си остава `EnsureCreatedAsync` + settlements
seed (дев опитът е непроменен); тестовите хостове пропускат схемата изрично
(`Database:SkipSchemaStartup=true` — `ApiFactory` вдига схемата сама). Гейтът за drift между модела
и снимката: `Foundation/DatabaseMigrationTests.Model_MatchesTheMigrationSnapshot`. Правилото за
всеки следващ таск: пипаш `Domain/`/`OnModelCreating` → добавяш миграция в СЪЩИЯ commit.

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

**`Geo` в детайли** (таск 403/414, `Features/Geo/`): регистър на населени места, референтни
данни, НЕ потребителско съдържание (продуктова спека, Паркинг т.13 — списъкът идва от GeoNames,
не от админ панел). `Import/SettlementTsvParser` чете GeoNames TSV формата; `SettlementImporter`
прави upsert по естествен ключ (`SettlementKey`, изведен, НЕ раздаден от базата — оттам
идемпотентността на повторен импорт); `SettlementSeeder.SeedIfEmptyAsync` зарежда комитнатия
стартов набор (`Data/Seed/settlements-bg-core.tsv`, областните градове) на dev старт, но САМО ако
таблицата е празна — ръчно изтрит град остава изтрит, а внесеният от потребителя списък е
по-силен от seed-а. Пълният GeoNames списък е РЪЧНА операторска стъпка:
`dotnet run --project src/PartyUp.Api -- settlements import <geonames.tsv> [--replace]`
(`SettlementsImportCommand`, обслужва се в `Program.cs` ПРЕДИ `RunWithGraphQLCommandsAsync`, по
образеца на `schema export`). Търсенето (`SettlementQueries.settlementsAsync`) е ПУБЛИЧНО
(без `[Authorize]` — витрината без вход и typeahead-ът го викат анонимно), ILIKE по `Name` ИЛИ
`AsciiName` с escape-нати wildcard знаци (`SettlementSearch.ToContainsPattern`), таван 20 реда.
**FE компонентът `SettlementTypeahead` (`table-create/`) е ПОСТРОЕН и тестван, но СЪЗНАТЕЛНО
никъде не е монтиран** (`CreateTableInput`/`UpdateTableSettingsInput` още нямат `settlementId` в
контракта) — виж §9.

**`Push`→`Preferences` в детайли** (таск 404/415/431, `Features/Push/Preferences/`): превключвател
по `NotificationCategory` (Candidacies/Chat/Decisions/Lifecycle/Privacy — ЕДРО деление, не по
`Notification.type`, за да не се множи с всеки нов тип). `NotificationCategories.ByType` е
буквалната карта тип→категория (типовете са изписани буквално, НЕ взети от чужд slice — §7б.2).
Липсващ ред = включено (таблицата пази само отклоненията); непозната категория/липсваща
настройка → `AllowsPushAsync` връща `true` (заглушаването е ИЗРИЧЕН избор, мълчание по
подразбиране би угасило push слоя за всички при първата фича, забравила картата). Камбанката/
`Notifications` реда винаги се пише — превключвателят спира само Web Push пратката, не истината.
**TODO, отворено от code review 2026-08-31:** `NotificationPreference` живее временно в
`Features/Push/Preferences/`, което обръща посоката на зависимостите (`Data` internal-va слайс
код, `FanoutNotifier` от slice `PushSend` вика хендлъра на slice `Push`) — фундаментен таск в
началото на следващата фаза трябва да качи ентитито + `NotificationCategories` в `Domain`/`Common`.
Екранната част (`PushSettingsSection`/`NotificationPreferences`, таск 431) е МОНТИРАНА в
`/settings` — виж §1б.

**Домейн (17 entity-та вкл. `AppUser`, `Domain/`):** `AppUser`, `UserProfile`, `PlayerListing`, `Table`,
`TableMembership`, `Candidacy`, `GroupDecision`, `Vote`, `Chat`, `ChatParticipant`, `Message`,
`Notification`, `PushSubscription`, `PrivacyRequest`, `DataExport` (board 211–213, доброто пропуснато
преброяване на времето — наваксва се тук), `NotificationPreference` (таск 404), `Settlement`
(таск 403, `Domain/Geo/`). **10 enum-а в `Domain/Enums.cs`:** ExperienceLevel, GameFormat, TableStatus,
AdmissionMode, **AdmissionKind** (таск 402 — `Candidacy`/`Open`, по-едрото решение НАД `AdmissionMode`:
церемонията по прием е смислена само при `Candidacy`), MembershipRole, CandidacyStatus, DecisionTopic,
DecisionStatus, ChatType (+ `AuthProvider` и `PushDelivery` в своите slice-ове).

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
`/` (`src/app/index.tsx`, таск 801, §7а6) вече НЕ е литерален редирект — чете `useSession()` и решава
сам: `null` докато сесията пътува, `/board` за влязъл потребител, `/showcase` за всеки друг (гост,
мрежова грешка).

**Глобалният хедър** (`src/components/app-header.tsx`, извън `src/features/` — генерично споделено,
виж §1) вече носи, отляво надясно зад сесийния пазач (`isAnonymous` крие всичко): `NotificationBell`
(таск 512, `features/contact`) → врата-икона към `/chat` (таск 512) → theme toggle → език → logout
(таск 511, БЕЗ confirm диалог, `useLogout` — същият hook, който ползва `SessionSection` в
`/settings`) → settings gear. Всяка контрола е сама с уникален `testID`/роля — logout и камбанката
са `imagebutton`, не `button`, за да не се броят в кросекранните спекове, които броят
`getAllByRole('button')` за табовете.

| Маршрут | Екран | Област (`src/features/`) |
|---|---|---|
| `/login` | LoginScreen (3 OAuth бутона), **гост линк към `/showcase`** (таск 702 — `login.guestLink`, за госта, попаднал тук от защитен route, не иска вход) | `auth` |
| `/settings` | линкнати профили, тема, „Пусни обиколката отново" (таск 308), **секция „Известия"** (таск 431 — статус на push абонамента + тогъли по категория), изход, Данни и поверителност (export/delete) | `auth-linking` (+ `RestartTourSection` от `tour`, `PushSettingsSection` от `push`) |
| `/board` (таб) | LFG борд с филтри, player cards, publish CTA, **infinite scroll** (таск 411 — скрол до дъното дърпа следваща cursor страница, `pagination.loadMore` е fallback бутонът) | `board` |
| `/tables` (таб) | моите маси + status badges + **бадж „обявена/необявена"** (таск 515, `TableListingBadge` — отделна заявка `MyTablesListingDocument`, виж §1г бележката в `queries.ts`) + create CTA | `my-tables` |
| `/profile` (таб) | профилна форма (react-hook-form) | `profile` |
| `/table/create` | форма за нова маса (one-shot полета, обучителен таг, **`AdmissionKindField`** — candidacy/open + мек лимит на местата, таск 402/412) | `table-create` |
| `/table/[id]` | детайл на масата + кандидатури, **CTA „обяви масата"** за candidacy маса без обява (таск 515 — насочва към `/table/[id]/settings`, отворената маса никога не го вижда) | `candidacy` |
| `/table/[id]/settings` | admission mode + listing toggle (founder-only), **`AdmissionKindField`** преизползван непроменен (таск 412) | `table-settings` |
| `/table/[id]/lifecycle` | phase stepper, founder преходи, stay-or-leave | `lifecycle-trial` |
| `/table/[id]/actions` | danger zone: leave, kick, refound | `lifecycle-actions` |
| `/candidacy/[id]` | pull flow: решение чат, панел за гласуване, вердикт | `candidacy` |
| `/candidacies` | «Моите кандидатури» (таск 516) — гледната точка на КАНДИДАТА: маса + статус на церемонията, ред → `/candidacy/[id]`; вход от самоблока на борда, „Кандидатурите ми (N)" (само ЖИВИ, `isOpenCandidacyStatus`) | `candidacy` |
| `/chat`, `/chat/[chatId]` | списък чатове и нишка с realtime абонамент | `chat` |
| `/showcase`, `/showcase/[id]` | readonly витрина + състав на партито, **cursor connection с infinite scroll** (таск 401/705 — скрол до дъното дърпа следваща страница по `pageInfo.endCursor`, дедуп по `id`, `pagination.loadMore` fallback бутон, огледално на борда), open-табло бадж + `GuestCta` за анонимен посетител (таск 413) | `showcase` |
| `/notifications` | нотификационен център (неутрални текстове към кандидата) | `contact` |
| `/refound-invite` | приемане на покана след преосноваване | `lifecycle-actions` |

`push` (без свой маршрут — service worker, subscribe pipeline, iOS install подсказка) — **прогресивно
подобрение, вече закачено на ДВЕ места**: `PushSettingsSection`/`usePushSetup` е монтирана в
`/settings` (таск 431, ръчен вход — потребителят е дошъл нарочно), тогълите по категория
(`NotificationPreferences`, таск 404/415) висят под нея; `NotificationBell` е монтирана в ГЛОБАЛНИЯ
хедър (таск 512, `components/app-header.tsx`) заедно с врата-икона към `/chat` — вижда се на всеки
екран зад сесийния пазач, а не само в `/notifications` (`NotificationCenter`-ът вече не носи
собствено копие на камбанката — композира се, не се преписва). **`PushPrompt` (арматурираният
банер след смислено действие) СЕ ОСТАВА незакачен за екран** — остатъкът от §9 т.4.

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

### §1г. FE Apollo кеш write-through дисциплина (таск 514)

Проблемът, който затвори таска (12.09 на живо, F5 симптом): мутация публикува/дърпа/напуска, но
списъчният екран (бордът, «Моите маси», кандидатурите на маса) не виждаше промяната, докато
потребителят не презаредеше ръчно — `update()` callback-ът на мутацията пишеше само отделния
обект, не списъка, който го показва. Решението е СЪЩИЯТ образец, който `use-privacy` въведе по-рано:
payload-ът на мутацията се пише ПРАВО в засегнатите кешове, БЕЗ нов мрежов кръг/refetch.

Три нови модула, по един на засегнат списък — всеки експортира чифт чисти функции (взимат
`ApolloCache`+данни, връщат `void`), не hook-ове, тестват се без рендиране:

- `features/board/board-cache.ts` — `addListingToBoard`/`removeListingFromBoard`. Публикуваната
  обява влиза в НЕФИЛТРИРАНАТА страница на борда най-отгоре; филтрираните кеширани страници се
  ИЗТРИВАТ (`cache.modify` + `DELETE`), не се дописват — дали новата обява минава даден филтър
  знае сървърът, не клиентът. Свалянето маха ръба от ВСИЧКИ кеширани страници по `id`.
- `features/candidacy/candidacy-cache.ts` — `addCandidacyToMyTable`: дърпането от БОРДА пише
  новия кандидат в списъка на ЧУЖД екран (масата) веднага; ако масата още не е отваряна (не е в
  кеша), няма какво да се пипне — първото ѝ отваряне я дърпа цяла.
- `features/my-tables/my-tables-cache.ts` — `addMembershipToMyTables`/`removeMembershipFromMyTables`
  + `foundedTableEntry` (превежда payload-а на `createTable`/`refoundTable` — профил+състав — на
  формата на `MyTables` реда, вадейки основателското членство). Добавянето минава през
  `cache.updateQuery` (нов ред отгоре), махането — през `cache.modify` (пренаписване на по-къс
  масив с `updateQuery` вдига Apollo предупреждение за загуба на данни, липсва merge политика за
  `myTables` в споделената `lib/apollo.ts`).

**Кой мутатор пише къде** (`update()` callback на `useMutation`): `publishMyListing`/
`unpublishMyListing` → `board-cache`; `pullCandidate` → `candidacy-cache`; `createTable`,
`refoundTable`, `acceptRefoundInvite` (виж `RefoundInviteScreen`) → добавяне в `my-tables-cache`;
`leaveTable` → махане от `my-tables-cache`. За да не се разминат селекциите, `BoardListingFragment`
е СПОДЕЛЕН fragment между `LfgBoardDocument` и `PublishMyListingDocument` (`board.graphql.ts`) —
разминаване прави вписания ръб непълен и кешът спира да се чете.

Патърнът е ЗАДЪЛЖИТЕЛЕН за нова мутация, която ражда/маха ред от вече зареден списък — refetch
на цялата листваща заявка е позволен резервен вариант само когато формата на payload-а не съвпада
с листващата селекция и превод би бил по-крехък от нов мрежов кръг.

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
5. **EF migrations СЪЩЕСТВУВАТ от таск 601** (`Migrations/`, начална `InitialCreate`) — прод базата
   (Production старт) се надгражда САМО през `Database.MigrateAsync()`, никога EnsureCreated/дроп.
   Тестовете и dev машината продължават да вдигат схемата с `EnsureCreated` (пълната таблица
   среда→действие: `backend/src/PartyUp.Api/Migrations/README.md`, накратко и в §1а „EF migrations
   в детайли"). **Правило за всеки следващ таск:** пипаш `Domain/`/`OnModelCreating` → добавяш
   миграция в СЪЩИЯ commit — гейтът е `DatabaseMigrationTests.Model_MatchesTheMigrationSnapshot`.
6. **DbContext-ът е с 16 DbSet-а** плюс Identity таблиците (растежът от 12 е board 211–213:
   `PrivacyRequest`, `DataExport`; и board 401–431: `NotificationPreference`, `Settlement`).
   Ключови ограничения в `OnModelCreating`: уникален `Vote(DecisionId, VoterUserId)`, уникален
   `PushSubscription.Endpoint`, уникален `ChatParticipant(ChatId, UserId)`, `text[]` колони за
   `SessionLanguages`/`Systems`/`StyleTags`; `NotificationPreference` е съставен ключ
   `(UserId, Category)` без сурогатно Id (таск 404); `Settlement.Id` е ИЗВЕДЕН от естествения
   ключ (`SettlementKey`), не раздаден от базата — оттам идемпотентността на повторен импорт
   (таск 403).

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
| `backend/src/PartyUp.Api/Program.cs` | всяко DI/pipeline wiring минава оттук (изяден от таскове 1 и 26; таск 501 добави изричен `app.UseWebSockets()` фикс; таск 601/602 добавиха `DatabaseStartup.ApplyAsync`, `AddPartyUpHosting()` и `UseForwardedHeaders()` — документирани изключения, §7а4) |
| `backend/src/PartyUp.Api/PartyUp.Api.csproj` | нов пакет/reference |
| `backend/src/PartyUp.Api/Domain/*` + `Common/*` | целият модел е от таск 1 — фича таск по правило НЕ добавя entity (таск 402/403/421 са изрични, документирани изключения — §1) |
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
cd backend && dotnet run --project src/PartyUp.Api -- settlements import <geonames.tsv> [--replace]  # операторска, таск 403 — НЕ е в гейта, НЕ се вика от агент/тест
cd backend && dotnet ef migrations add <Име> --project src/PartyUp.Api/PartyUp.Api.csproj  # таск 601 — В СЪЩИЯ commit с Domain/OnModelCreating промяната
```

⚠ **`codegen` е префикс на `test` и `typecheck`** — гола `npx tsc --noEmit` пада, защото `src/gql` може да не
съществува. Винаги през npm скриптовете.

**Verify гейтът (`repos.json`, дословно):** `npm --prefix frontend install` → `typecheck` → `test` →
`dotnet test backend/PartyUp.slnx` → `git checkout -- frontend/package-lock.json`.
Последното е ЗАДЪЛЖИТЕЛНА хигиена (инцидентът от 16.08: `npm install` мърда lock-а → мръсен checkout →
MERGE SKIPPED за всички следващи таскове). **Таск 621 добави ОТДЕЛЕН GitHub Actions гейт**
(`.github/workflows/ci.yml`) за реалния `develop`/`main` push/PR поток — unit+typecheck на всеки
push/PR, Playwright e2e само на push към `main`. Двата гейта НЕ са едно и също: `repos.json` е
Ralph-ов merge гейт за swarm таскове (локален, без Docker в CI job-а за backend — GitHub Actions
хостовете си имат вграден Docker, но интеграционните тестове там вървят на всеки push, не само на
merge); GitHub Actions пази реалния `main`/`develop` след ВСЯКО сливане, вкл. ръчни комити извън
Ralph. Playwright все още НЕ е в `repos.json` гейта (§9 т.1 остава отворена за него).

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

### §7 (продължение). Тестово състояние след board 401–431 (файлово преброено от диф-а — ЧИСТО
ДОКУМЕНТАЦИОННА задача, без `dotnet test`/`npm test` прогон в тази сесия; следващият реален verify
гейт да освежи точните бройки по-долу с фактически изпълнения, не само файлове)

- **BE test suite файлове** (съдържащи `[Fact]`/`[Theory]`): unit **20 → 26** (+6: `Geo/BulgarianCoreSeedTests`,
  `Geo/SettlementKeyTests`, `Geo/SettlementSearchTests`, `Geo/SettlementTsvParserTests`,
  `Geo/SettlementsImportCommandTests`, `Tables/Settings/SlotLimitRulesTests`); integration
  **41 → 51** (+10: `Geo/SettlementImportTests`, `Geo/SettlementSeedTests`, `Geo/SettlementsQueryTests`,
  `Candidacies/OpenTableGuardTests`, `Push/NotificationPreferenceTests`,
  `PushSend/FanoutPreferenceTests`, `Tables/CreateTable/CreateTableWalkInTests`,
  `Tables/Settings/UpdateTableSettingsWalkInTests`, `Lfg/Showcase/TablesShowcaseWalkInTests`,
  `Foundation/RateLimiting/RateLimitingTests` — нова `Foundation/` папка в IntegrationTests за
  инфраструктурни тестове извън `Features/`). Плюс разширени файлове: `LfgBoardTests`,
  `TablesShowcaseTests` (cursor pagination/infinite scroll), `DevLoginEndpointsTests` (token guard).
- **FE test suite файлове:** `70 → 73` (нови: `push/__tests__/notification-preferences.test.tsx`,
  `push/__tests__/push-settings-section.test.tsx`, `table-create/settlement-typeahead.test.tsx`,
  `lib/auth-gate.test.tsx`; разширени: `board/__tests__/board-screen.test.tsx` (infinite scroll),
  `showcase/__tests__/showcase-screen.test.tsx` (walk-in бадж + гост CTA), `table-create-form.test.tsx`,
  `table-settings-form.test.tsx`).
- **Нова backend тест зона:** `Common/RateLimiting/RateLimitingTests.cs` живее под ново поддърво
  `Foundation/` в `PartyUp.IntegrationTests` (не `Features/`) — прецедент за бъдещи cross-cutting
  Common тестове (structure §7б.1 остава в сила: инфраструктурата се тества отделно от slice-овете).
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

### §7 (продължение 2). Тестово състояние след board 501–517 (файлово преброено от диф-а — ЧИСТО
ДОКУМЕНТАЦИОННА задача, без `dotnet test`/`npm test` прогон в тази сесия; следващият реален verify
гейт да освежи точните бройки по-долу с фактически изпълнения, не само файлове)

- **BE test suite файлове:** unit **непроменени, 26**; integration **51 → 53** (+2:
  `Candidacies/Pull/MyCandidaciesTests` — таск 503, `Foundation/GraphQLWebSocketTests` — таск 501,
  реален ws upgrade+съобщение round-trip срещу `WebApplicationFactory`). Плюс разширени файлове:
  `Lfg/Showcase/TablesShowcaseTests` и `TablesShowcaseWalkInTests` (таск 502 — видимост по
  `AdmissionKind`/`ListingActive`).
- **FE test suite файлове:** `73 → 80` (+7: `board/__tests__/board-cache.test.ts`,
  `candidacy/candidacy-cache.test.ts`, `candidacy/candidacy-status.test.ts`,
  `candidacy/my-candidacies-screen.test.tsx`, `my-tables/__tests__/my-tables-cache.test.ts`,
  `table-create/table-create-my-tables.test.tsx`, `table-create/table-form-fields.test.tsx`).
  Значително разширени: `app-header.test.tsx` (logout + камбанка + чат врата, таск 511/512),
  `board-screen.test.tsx` (кеш вписване + самоблок кандидатури, таск 514/516),
  `pull-targets.test.ts` (разкачване от `listingActive`, таск 515), `table-screen.test.tsx`
  (listing CTA, таск 515), `notification-bell.test.tsx`/`notification-center.test.tsx` (преместена
  камбанка, таск 512), `leave-table-action.test.tsx`/`refound-invite-screen.test.tsx`/
  `refound-table-action.test.tsx` (кеш update, таск 514), `table-create-form(-web).test.tsx`
  (кеш update, таск 514), `table-listing-section.test.tsx`/`table-settings-screen.test.tsx`
  (преномерирана обява, таск 515), `oauth.test.ts`/`login-screen.test.tsx` (facebook спрян, таск 513).
- **BE integration тест за WebSockets** живее в `Foundation/` (не `Features/`) редом до
  `RateLimitingTests` — вторият прецедент за cross-cutting инфраструктурни тестове там (§7б.1
  остава в сила: инфраструктурата се тества отделно от slice-овете).

### §7 (продължение 3). Тестово състояние след board 601–621 (деплой вълна, файлово преброено от
диф-а — ЧИСТО ДОКУМЕНТАЦИОННА задача, без `dotnet test`/`npm test` прогон в тази сесия; следващият
реален verify гейт да освежи точните бройки по-долу с фактически изпълнения, не само файлове)

- **BE test suite файлове:** unit **непроменени, 26**; integration **53 → 57** (+4, всичките нови
  под `Foundation/`): `DatabaseMigrationTests` (таск 601 — създава/прилага миграцията срещу празна
  Testcontainers база, доказва идемпотентност на повторен `MigrateAsync`, модел↔снимка гейт, и
  unit-стил тестове за `DatabaseStartup.Decide` по среда/CLI команда/липсващ connection string),
  `Hosting/CookiePolicyTests`, `Hosting/FrontendOriginsTests`, `Hosting/HealthEndpointTests` (таск
  602 — cross-site/`SameSite` политика по среда, CORS origin-и от конфигурация, `GET /healthz`
  връща 200 анонимно). Разширен файл: `Foundation/GraphQLWebSocketTests` (регресия срещу
  forwarded-headers wiring-а от 602, за да не се счупи WebSocket upgrade-ът от таск 501 повторно).
- **FE test suite файлове:** `80 → 81` (+1: `lib/config.test.ts` — таск 611, покрива
  `EXPO_PUBLIC_API_URL` override, localhost fallback, и trailing-slash нормализацията).
- **CI (`.github/workflows/ci.yml`, таск 621) е НОВ, ОТДЕЛЕН от `repos.json` гейт** — виж §6 за
  разликата между двата. Не сменя нито една бройка по-горе, само ги пуска автоматично на реалния
  `develop`/`main` push/PR поток.

### §7 (продължение 4). Тестово състояние след board 701–705 (файлово преброено от диф-а — ЧИСТО
ДОКУМЕНТАЦИОННА задача, без `dotnet test`/`npm test` прогон в тази сесия; следващият реален verify
гейт да освежи точните бройки по-долу с фактически изпълнения, не само файлове)

- **BE test suite файлове:** unit **непроменени, 26**; integration **непроменени, 57** — таск 703
  разшири СЪЩЕСТВУВАЩИЯ `Foundation/Hosting/HealthEndpointTests.cs` (нов случай за HEAD), не добави
  нов файл.
- **FE test suite файлове:** `81 → 82` (+1 нов: `table-settings/table-listing-cache.test.ts`, таск
  704). Значително разширени: `tabs-icons.test.tsx` (таск 701 — `resolveTabBarIsDark` unit случаи),
  `table-form-fields.test.tsx` (таск 701 fix-цикъл — вторият консуматор на темата), `auth-gate.test.tsx`
  (нов файл в предишно броене, тук разширен за `isRoot`/`segments.length`, таск 702),
  `login-screen.test.tsx` (гост линк, таск 702), `showcase-screen.test.tsx` (infinite scroll, таск 705).
- **Няма нови BE/FE тестови зони** (`Foundation/`, `test-utils/` и т.н.) — вълната пипа съществуващи
  slice-ове/области, не добавя инфраструктура.

### §7 (продължение 5). Тестово състояние след board 801 (файлово преброено от диф-а — ЧИСТО
ДОКУМЕНТАЦИОННА задача, без `dotnet test`/`npm test` прогон в тази сесия; следващият реален verify
гейт да освежи точните бройки по-долу с фактически изпълнения, не само файлове)

- **BE test suite файлове:** непроменени — таск 801 е чист FE fix, бекендът не е пипнат.
- **FE test suite файлове:** непроменени, **82** — нито един нов файл, значително разширени:
  `src/__tests__/navigation.test.tsx` (нов `describe('входът на приложението')` +
  `describe('пазачът през реалния рутер')`, сесията вече е мокната през `useSession`, а маршрутът се
  мери през РЕАЛНИЯ рутер), `src/lib/auth-gate.test.tsx` (празни `segments` вече НЕ пренасочват,
  отделен тест за „сегментите дойдоха"), `src/__tests__/auth-error-routing.test.tsx` (returnUrl
  случаят обновен за новата дестинация на корена). E2e (`frontend/e2e/smoke.spec.ts`/`support.ts`,
  извън `repos.json` гейта — §9 т.1): стъбът мина от един отговор на `**/graphql` към отговор ПО
  ОПЕРАЦИЯ, нов Back-регресионен спек за React #185.
- **Няма нови BE/FE тестови зони** — вълната пипа съществуващи файлове, не добавя инфраструктура.

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

## §7а2. Амендменти за board 401–431 — ИСТОРИЯ, всички ЗАТВОРЕНИ

1. **Пагинацията (§7а.1 по-горе, „без пагинация") е ЧАСТИЧНО отменена (таск 401).** `lfgBoard` и
   `tablesShowcase` вече са Relay connections (`LfgBoardConnection`/`TablesShowcaseConnection`,
   вграденото Hot Chocolate `[UsePaging]`, споделени граници в `Features/Lfg/LfgPagingDefaults`:
   `DefaultPageSize=20`, `MaxPageSize=50`). `myChats`, `chat.messages`, `notifications` си остават
   плоски списъци — не са пипани. Истинското infinite scroll (скрол до дъното дърпа `after: endCursor`,
   дедупликация по `id`) стигна само до борда (таск 411); витрината показва само първата страница.
2. **Отворени (walk-in) маси, мек лимит на местата (таск 402/412).** `AdmissionKind` (`Candidacy`/`Open`)
   е по-едрото решение НАД `AdmissionMode` — церемонията по прием е смислена само при `Candidacy`,
   отворената маса няма кандидатски flow изобщо. `SlotsFirm` (default `true`) е независим флаг:
   твърдият лимит пази старото желязно правило (не смаляваш под текущия състав — изгонването е
   групово решение, настройка няма право да го предизвиква мълчаливо); мекият го отменя САМО за
   walk-in маси (`SlotLimitRules.AllowsSlots` — чиста функция, тества се без база).
3. **Гео регистър на населени места (таск 403/414)** — виж „`Geo` в детайли" по-горе. Ключовото
   решение: списъкът е референтни данни от GeoNames (seed + операторски импорт), НЕ потребителско
   съдържание и НЕ админ панел; FE компонентът е построен, но съзнателно НЕ монтиран, докато
   контрактът няма `settlementId` поле (виж §9).
4. **Публична витрина за отворени маси с гост CTA (таск 413).** Анонимен посетител на витрината
   вижда `OpenBadge`/`formatOpenInvite` (кога/къде, вместо кандидатски бутон) и `GuestCta`
   (readonly витрина + „Влез, за да…" ЛИНК, не бутон — витрината няма право да носи действие по
   маса). `useIsGuest` чете ЯСНИЯ отговор на сесията (`resolved && !user`), не липсата на отговор —
   мрежова грешка не е гост, същият рефлекс като `AuthGate`.
5. **Per-category push preferences (таск 404/415), монтирани в екрана (таск 431)** — виж
   „`Push`→`Preferences` в детайли" по-горе за схемата/фан-аута и §1б за екранния wiring. Отвореният
   TODO (временният адрес на `NotificationPreference` в `Features/Push/Preferences/`, обратна
   посока на зависимостите) остава за фундаментен таск в следваща фаза.
6. **Rate limiting (таск 421).** Вграден ASP.NET лимитер, класифициран по PATH в `Common/RateLimiting/`
   (не именувани policy-та по endpoint) — виж пълното описание в §1а по-горе. Deploy бележка,
   записана в кода: честното клиентско IP зад reverse proxy (`ASPNETCORE_FORWARDEDHEADERS_ENABLED`
   / `UseForwardedHeaders`) е грижа на deploy таска, НЕ на този.
7. **`ProvisioningService` лифтнат над Login/DevLogin (таск 422).** Класът за „кой влезе → кой акаунт
   е това" (email-ключуван акаунт, авто-linking на провайдъри) стоеше дублиран/вътре в login slice-а;
   вдигнат е директно в `Features/Auth/` (плосък файл, не UseCase папка) — И `Login`, И `DevLogin` го
   инстанцират наравно, никой от двата не му е собственик.
8. **Опционален споделен token пред dev-login (таск 423).** `DevLogin:Token` конфиг ключ
   (user-secrets/env, НЕ в git); ако е зададен, заявката носи `?token=` (constant-time сравнение);
   грешен/липсващ токен → 404, НЕРАЗЛИЧИМО от изключен endpoint (не издава дали пътят съществува).
   Незададен ключ → старото поведение (само `IsDevelopment()` гейт) — нулево търкане за локален dev.
   Не затваря §9 т.7 напълно — endpoint-ът все още няма rate limit/аудит от само себе си (сега го
   покрива общият `/auth/*` лимитер от таск 421).

## §7а3. Амендменти за board 501–517 (fix/finishing вълна) — ИСТОРИЯ, всички ЗАТВОРЕНИ

1. **WebSocket ъпгрейдите бяха реално ИЗКЛЮЧЕНИ (таск 501).** `app.UseWebSockets()` липсваше в
   `Program.cs` — HotChocolate никога не виждаше upgrade заявката, `graphql-ws` на FE удряше
   `ws://…/graphql` и просто увисваше, subscriptions (`onMessage`/`onNotification`) не се
   свързваха. Редът има значение: `UseWebSockets()` е ПРЕДИ `UseAuthentication()`/`MapGraphQL()` —
   точката, която приема upgrade-а. `Program.cs` е отровен файл (§5), но е точно от типа изричен
   инфраструктурен фикс, за който съществува изключението.
2. **Витрината криеше грешните маси (таск 502).** `TablesShowcaseAsync` филтрираше само по
   `Status != Disbanded` — candidacy маса БЕЗ обява се виждаше на витрината, противно на текста в
   `table-listing-section.tsx` („маса без обява не се показва на никого"). Поправено на
   `AdmissionKind == Open OR ListingActive`: отворената (walk-in) маса е обява по природа и се
   вижда ВИНАГИ, кандидатската — само с активна обява.
3. **`myCandidacies` (таск 503/516) — гледната точка на КАНДИДАТА, за първи път.** Съществуващите
   „мои ..." заявки бяха всички от гледната точка на масата/членството; кандидатът нямаше начин да
   провери в какво е кандидатствал. Контрактът тук е СТРОГ (не тих празен списък на анонимен
   викащ, а top-level GraphQL грешка, `NOT_AUTHENTICATED`) — образецът на subscription-refusal, не
   на обикновен query resolver. Query 21→22 (виж §1а). FE екранът `/candidacies` (таск 516) и
   самоблокът на борда „Кандидатурите ми (N)" (само ЖИВИ статуси, `isOpenCandidacyStatus`) четат
   от нея.
4. **Facebook логинът е спрян временно (таск 513, решение на потребителя 12.09).** FB редиректът
   иска https + app review бюрокрация, отложено още от prerequisites; провайдърът е ИЗВАДЕН от
   `AUTH_PROVIDERS` (`['google', 'discord']`), не изтрит — бутонният цвят стои закоментиран в
   `login-screen.tsx` за връщане без ровене в git history. Backend страната (§3.4 — OAuth
   провайдър се регистрира само ако е конфигуриран) не е пипана.
5. **Logout в глобалния хедър (таск 511)** — вижте §1б, `useLogout` (същият hook, който вече
   ползваше `SessionSection` в `/settings`). Без confirm диалог: изходът е безобиден, навигацията
   към `/login` минава само след УСПЕШЕН изход.
6. **`NotificationBell` мигрира от екрана на центъра в глобалния хедър (таск 512)** — заедно с нова
   врата-икона към `/chat`. Затваря половината от §9 т.4 (старата версия на тази точка):
   `PushPrompt` остава единственото незакачено парче push прогресивното подобрение.
7. **FE Apollo кеш write-through дисциплина (таск 514)** — виж §1г за пълното описание. Затваря
   класа бъгове „мутацията мина, но списъчният екран показва старото до F5" за борда, «Моите маси»
   и кандидатурите на маса.
8. **Дърпането разкачено от обявата (таск 515, решение на потребителя 12.09: „нечекването и
   неможенето да дърпаш е много асоциално").** Старото правило искаше АКТИВНО членство И `table.
   listingActive`; сцепването правеше невъзможен легитимния случай „частна маса кани конкретен
   човек, без да виси на витрината". `pull-targets.ts` вече филтрира само по `membership.active`.
   Отворената (walk-in) маса продължава да няма кандидатски flow — BE guard-ът
   (`CandidacyService.WalkInGuard`, таск 402) си остава единствената защита, ако все пак се
   опиташ (`TABLE_IS_OPEN`). Обявата стана ЧИСТО маркетингов превключвател: видима като бадж
   „обявена/необявена" в «Моите маси» (`TableListingBadge`, отделна `MyTablesListingDocument` —
   виж бележката в `queries.ts`, §1б) и като CTA в `/table/[id]`, когато кандидатска маса няма
   обява.
9. **Date/time picker-ите отваряха само на клик върху миниатюрната иконка (таск 517).** На тъмна
   тема иконката е трудна за виждане И уцелване. Клик/фокус върху ЦЯЛОТО поле сега вика
   `input.showPicker()` (user-gesture изисква, guard-нато в try/catch — тих fallback към старото
   поведение, ако браузърът откаже). Нов `useIsDarkColorScheme()` в `lib/theme.tsx` дава РЕЗОЛВНАТАТА
   (light/dark) тема на нативен web `<input>`, който няма собствен `dark:` className.

## §7а4. Амендмънти за board 601–621 (деплой вълна) — ИСТОРИЯ, всички ЗАТВОРЕНИ

Първата вълна, насочена директно към прод deploy (не фича/полиране). Затваря §9 т.5 и т.11 изцяло.
⚠ Вълната е мерджната в `develop`, все още НЕ в `main` (виж бележката в началото на файла) — а
`render.yaml`/CI e2e сочат `main`, тоест реалният деплой и Playwright-по-push стъпват в сила чак
след `develop`→`main` сливането.

1. **EF migrations, начална baseline (таск 601).** `§3.5` вече НЕ важи — миграции СЪЩЕСТВУВАТ.
   `DatabaseStartup` (нов `Migrations/` namespace) решава средата вместо флаг: `Production` →
   `MigrateAsync` (идемпотентно, никога drop/recreate), `Development` → непроменен `EnsureCreated`+
   seed, тестов хост → изричен `Database:SkipSchemaStartup=true`. Непознат CLI аргумент/липсващ
   connection string в `Production` е fail-fast (`InvalidOperationException`), не мълчание — иначе
   `/healthz` (liveness, не db ping) би минал „успешен" деплой, който гърми при първия потребител.
   Виж „EF migrations в детайли" (§1а) и `Migrations/README.md` за пълната процедура.
2. **Прод-готов hosting: cross-site бисквитки, forwarded headers, CORS от конфигурация, health
   endpoint (таск 602).** `Common/Hosting/HostingSetup.AddPartyUpHosting` — виж „Hosting в детайли"
   (§1а) за пълното описание на двете решения (cookie SameSite/Secure по среда,
   `UseForwardedHeaders()` с изпразнени `KnownNetworks`/`KnownProxies`, безопасно САМО зад
   Render-овия прокси). CORS origin-ите минаха от твърд списък към `Frontend:Origins` конфигурация
   — СЪЩИЯТ списък пази и OAuth `returnUrl` whitelist-а. Нов `GET /healthz` (`Features/Health/`) —
   liveness БЕЗ db ping, съзнателно (Neon free tier заспива/буди се, readiness с реална база е
   отделно решение, не взето тук). Затваря §9 т.11 (rate limiter-ът вече вижда честно клиентско IP).
3. **`backend/Dockerfile` + `render.yaml` (таск 603).** Двустъпков build (SDK restore+publish →
   aspnet runtime, тестовете НЕ влизат в образа); ENTRYPOINT сглобява `ASPNETCORE_URLS` от Render-овия
   рънтайм `$PORT` (fallback 8080 за локален `docker run`). Render Blueprint е `plan: free`,
   `runtime: docker`, `healthCheckPath: /healthz`, `branch: main`; всички секрети (`ConnectionStrings__PartyUp`,
   OAuth/VAPID ключове, `Frontend__Origins__0`) са `sync: false` — слагат се РЪЧНО в Render dashboard,
   никога в git.
4. **FE `API_BASE_URL` от `EXPO_PUBLIC_API_URL` build-time env (таск 611).** Cloudflare Pages build-ът
   го подава за прод; без него остава днешният `http://localhost:5000` dev fallback. Trailing slash
   се маха преди конкатенацията (`GRAPHQL_HTTP_URL` и т.н.), за да не се дублира.
5. **GitHub Actions CI (таск 621).** Нов, ОТДЕЛЕН от Ralph-овия `repos.json` merge гейт (виж §6):
   frontend (`typecheck`+`test`) и backend (`dotnet test`) на всеки push към `develop`/`main` и PR
   към `main`; Playwright e2e (`e2e:export` + `test:e2e`) само на push към `main`, СЛЕД като горните
   две минат — първото място, където Playwright реално се изпълнява автоматично (все още НЕ е в
   `repos.json`, §9 т.1 остава отворена за ТОЗИ гейт конкретно).

## §7а5. Амендмънти за board 701–705 (fix/finishing вълна) — ИСТОРИЯ, всички ЗАТВОРЕНИ

Мерджната в `develop`, все още НЕ в `main` — на тази вълна ѝ предхожда 601–621 (виж бележката в
началото на файла). Фиксира два живи прод бъга от 18.09 (таб бар/пикър черен под светла тема на
static export, гостите удрят login wall) и една инфраструктурна дупка (HEAD на `/healthz`), плюс
две поведенчески подобрения (cache eviction, витрина infinite scroll).

1. **„Авто" темата на таб бара/пикъра следваше грешния източник (таск 701).** И двата консуматора
   (`app/(tabs)/_layout.tsx`, `lib/theme.tsx`) четяха `useColorScheme` от React Native
   (`Appearance`) за режим `'system'`, а СЪДЪРЖАНИЕТО се боядисва от NativeWind. На **web** статичен
   export това разминаване е фатално: `tailwind.config.js` е `darkMode:'class'`, което не емитва
   `prefers-color-scheme` CSS правила изобщо — „Авто" съдържание там е ВИНАГИ светло (класът `dark`
   идва само от изричен `colorScheme.set('dark')`), но `Appearance` продължава да пита ОС-та. На
   тъмна машина резултатът е тъмен бар/пикър под светло съдържание — точно обратното на очакваното.
   Поправката е нова чиста функция `resolveTabBarIsDark(themeMode, nativewindScheme)` (изнесена и
   тествана отделно от компонента): изричен режим ('light'/'dark') печели винаги (таск 201-правилото
   непокътнато); `'system'` на web връща твърдо `false` (NativeWind никога не носи `dark` клас там
   без изричен избор); `'system'` на native пита `useColorScheme` от **nativewind**, не от
   react-native. Огледалната поправка мина и в `useIsDarkColorScheme()` (`lib/theme.tsx`, вторият
   консуматор — нативния web `<input>` picker). **Не сливай обратно двете правила в едно `||`
   изречение** — коментарите на място обясняват защо са отделни клонове, не козметика.
2. **Гостите удряха login wall на корена вместо витрината (таск 702).** `AuthGate` пренасочваше
   ВСЕКИ нерезолвнат-без-сесия route (вкл. `/`) към `/login`; QR/чат/CV линк, сочещ към корена,
   showcase acquisition каналът (413) никога не отваряше. Поправка: `isRoot` клон в `AuthGate` —
   САМО коренът (`segments.length === 0`) пренасочва към `/showcase`, дълбоките защитени route-ове
   (`chat`, `table/…`) продължават към `/login` непроменени. `LoginScreen` получи обратен гост линк
   (`login.guestLink`) към `/showcase`, за госта, попаднал ТУК от дълбок защитен route. Код ревю
   находка cycle 1: първата версия сравняваше `segments[0] === ''`, което е невярно за истински
   празен масив (`useSegments()` на `/` връща `[]`, не `['']`) — сменено на `segments.length === 0`.
   **ЗАМЕНЕНО от таск 801 (§7а6):** `isRoot` клонът се оказа половината от прод бъг (React #185,
   бял екран) — премахнат изцяло, решението за корена се пренесе в `app/index.tsx`.
3. **`/healthz` не отговаряше на HEAD (таск 703).** `MapGet` сам връща 405 на HEAD заявка;
   безплатните uptime pinger-и (UptimeRobot) пращат HEAD, защото GET им е зад paywall — Render
   инстанцията изглежда „Down", докато приложението си е живо. Поправка: `MapMethods(Path, [GET,
   HEAD], ...)`, тялото се пропуска изрично на HEAD (Kestrel го прави сам за статични файлове, НЕ за
   custom handler-и, а тестовият in-memory сървър изобщо не го прави).
4. **Кеш класът, случай №4: `setTableListing` не пипаше витрината (таск 704).** Обявяваш/сваляш
   обявата на маса → «Моите маси» се обновява веднага (badge-ът, таск 515, чете `listingActive` през
   нормализирания `Table:id`, Apollo го пренаписва сам), но `/showcase` показва старото до F5 —
   `tablesShowcase` е Connection (списък), не поле на един обект, значи хирургично вписване като
   `board-cache` (§1г) би трябвало да знае дали новата стойност минава ТЕКУЩИЯ филтър на екрана, който
   я гледа. Нов модул `features/table-settings/table-listing-cache.ts` (`evictShowcaseListing`) прави
   вместо това пълна евикция на ВСИЧКИ кеширани `tablesShowcase` страници (`cache.evict` +
   `cache.gc()`), закачена в `update()` на `SetTableListingDocument`; следващото отваряне на
   `/showcase` я дърпа наново от сървъра, който преценява правилно. **Разширява §1г патерна:**
   евикция е легитимна алтернатива на хирургично вписване точно когато видимостта на новия ред
   зависи от произволна клиентска филтърна комбинация, която кеш кодът не би трябвало да преизчислява.
5. **Витрината получи infinite scroll (таск 705), огледално на борда (411).** `TablesShowcaseDocument`
   вече праща `first`/`after` и чете `pageInfo{hasNextPage, endCursor}`; скрол до дъното
   (`onScroll`, праг 200px) или бутонът „Зареди още" (fallback за платформи/входове, при които
   скролът не отработва чисто) дърпат следваща страница през `fetchMore` + `updateQuery`, дедуп по
   `id`. За разлика от борда, витрината пипа `nodes` директно (не `edges`) — няма локален кеш запис,
   за който `edge.cursor` да е нужен. Нови ключове: `showcase.pagination.{loadMore,loadingMore,end}`
   (bg/en). **Кросов lane конфликт с 704** (двете лани се докоснаха до `tablesShowcase`-свързан код
   успоредно): `pageInfo` става ЗАДЪЛЖИТЕЛНО поле на генерирания connection тип → `showcasePage()`
   мокът в `table-listing-cache.test.ts` (704) остана без него след merge на `develop` — довършено
   по образеца на `board-cache.test.ts`, отделен последващ комит (0d32a78).

**Код ревю cycle 1 находка (fix-цикъл, отделен комит 4559c79):** `useIsDarkColorScheme` не
покриваше втория консуматор на 701-формулата (native web `<input>` пикър, таск 517) — добавен
регресионен тест (`table-form-fields.test.tsx`) + огледалната поправка в `lib/theme.tsx` (виж т.1
по-горе). Единственият cycle за тази вълна — гейтът мина на първо ревю след него.

## §7а6. Амендмънти за board 801 (fix) — ИСТОРИЯ, ЗАТВОРЕН

Мерджнат в `develop`, все още НЕ в `main` — следва директно след 701–705 (виж бележката в началото
на файла). Затваря прод бъг от 19.09: гост отваря корена, стига до витрината, удря Back и виси на
бял екран (React #185, „Maximum update depth exceeded"). Коренната причина беше РАЗМИНАВАНЕ между
ДВАМА решаващи едно и също нещо — `app/index.tsx` (безусловен `<Redirect href="/board" />`) и
`AuthGate` (`isRoot` клонът от таск 702, §7а5.2) — не самият `isRoot` клон по себе си.

1. **Коренът вече е ЕДИНСТВЕНИЯТ, който решава накъде отива посетителят.** `app/index.tsx` чете
   `useSession()` направо: докато `loading`, връща `null` и никъде не навигира (преди това
   безусловното `<Redirect href="/board" />` вкарваше госта за кадър в защитен екран, оставяше
   `/board` в историята и Back-ът въртеше цикъл от пренасочвания); влязъл потребител → `/board`;
   всичко останало (анонимен, мрежова грешка) → `/showcase`. Чака се `loading`, НЕ `resolved` —
   мрежова грешка също е КРАЙ на пътуването на сесията, само без отговор; чакането на `resolved`
   оставяше acquisition URL-а (QR кодът от 413/702) празен до ръчно презареждане, защото
   `lib/apollo.ts` няма HTTP retry link, а покривалото на `AuthGate` пада заедно с `loading`.
2. **`AuthGate` изгуби `isRoot` клона — замества таск 702 (§7а5.2), не го допълва.** Гейтът пази
   ЕДНО правило: защитен route + ясно „няма сесия" → `/login`; къде отива посетителят от корена вече
   не е негова работа. Празните `segments` (`useSegments() === []`) спряха да се четат като „това е
   коренът" — те са ДВУСМИСЛЕНИ: `[]` идва и на `/`, И при първия рендер на всеки друг route, докато
   навигаторът се монтира. Преди фикса гост на `/board` с още празни `segments` минаваше за „корен" и
   завършваше на `/showcase` вместо на `/login` — точно тази комбинация с безусловния редирект на
   корена въртеше Back в цикъла от т.1. Проверката вече чака `segments.length > 0`, значи отработва
   един рендер по-късно, щом сегментите дойдат.
3. **`LoginScreen` загуби третия OAuth ключ от локала.** `auth.json` (bg/en) вече няма
   `login.providers.facebook` — Facebook продължава да е СПРЯН, не изтрит (§9 т.12 непроменена,
   `oauth.ts`/`AUTH_PROVIDERS` непипнати); махнат е само осиротял превод, който правеше проверката за
   трите бутона в `smoke.spec.ts` кух пас.
4. **E2e стъбът стана операционен.** `stubAnonymousSession` (`e2e/support.ts`) вече отговаря ПО
   `operationName` (`Me`/`TablesShowcase`/`UnreadNotifications`, `STUBBED_DATA`), не с един фиксиран
   `{ me: null }` за всяка `/graphql` заявка — коренът вече дърпа витрината, значи стъбът трябва да ѝ
   отговори с ПРАВИЛНАТА форма (иначе Apollo кешът пише конзолни грешки на всяко зареждане).
   Неочаквана операция получава честна GraphQL грешка, не чужда форма. Нов регресионен спек пази
   точно прод симптома: гост от корена → `/login` → Back → жив екран на `/showcase`, нула хвърлени
   грешки (`pageErrorsIn`).

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
8. **Без сортиране, без глобален relay `node(id)`** — `UUID` вместо `ID` навсякъде. Пагинацията вече
   НЕ е универсално отсъстваща (виж §7а2.1): `lfgBoard`/`tablesShowcase` са Relay connections от
   таск 401; `myChats`, `chat.messages(skip, take)`, `notifications` си остават плоски списъци
   (`chat.messages` е опционални аргументи с таван, не Relay connection).
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

## §9. Известни отворени точки след board 701–705 (кандидати за следваща фаза)

Не са бъгове — съзнателно оставени. Всяка иска свой таск и решение на ЧОВЕКА. Списъкът е от board
1–42 и остана непроменен през 101–308; board 401–431 ЗАТВОРИ т.4 (частично) и т.7 (частично) отдолу
и добави три нови точки (9–11); board 501–517 ЗАТВОРИ т.4 ОСТАНАЛОТО (NotificationBell), но добави
две нови точки (12–13); board 601–621 ЗАТВОРИ т.5 (EF migrations) и т.11 (forwarded headers за
rate limiter-а) ИЗЦЯЛО и ЧАСТИЧНО облекчи т.1 (виж бележката там) — не добави нови точки; **board
701–705 ЗАТВОРИ т.10 (витрината без infinite scroll) ИЗЦЯЛО** — не добави нови точки.

1. **Playwright не е в `repos.json` verify гейта** (Ralph-овия merge гейт). Влизането му иска първо
   чистене на Metro замърсяването (§6): `frontend/tsconfig.json` + root `nativewind-env.d.ts`.
   `repos.json` НЕ е пипан нито от board 1–42, нито от следващите. **ЧАСТИЧНО облекчено от таск 621:**
   отделен GitHub Actions гейт (`.github/workflows/ci.yml`) вече ЗАВЪРТА Playwright автоматично на
   всеки push към `main` (release branch) — виж §6/§7а4.5. Точката остава отворена конкретно за
   Ralph-овия `repos.json` merge гейт, който продължава да не включва e2e.
2. **Full-stack e2e** (жив BE + Testcontainers compose) — сегашните 3 спека са неавтентикирани пътеки с един стъб.
3. **Локализиран `src/app/+not-found.tsx`** — 404 сега е вграденият англоезичен екран на expo-router,
   извън root layout-а и без пазач. Спекът описва ТЕКУЩОТО, не желаното поведение.
4. **Push прогресивното подобрение — ПОЧТИ ЗАКАЧЕНО (таск 431/512).** `PushSettingsSection` (статус +
   тогъли по категория) е монтирана в `/settings` (431); `NotificationBell` е монтирана в
   ГЛОБАЛНИЯ хедър с врата към `/chat` (512, виж §1б/§7а3). Само `PushPrompt` (арматурираният
   банер след смислено действие) СИ ОСТАВА незакачен. Обиколката (§1в, board 307–308) вече МОЖЕ да
   гради `bell` стъпката около реален изрез — все още не е обновена да го ползва (`tour-content.ts`
   пада на затъмнение без изрез за тази стъпка; закачването е еднодневен таск, чака решение).
5. **~~EF migrations (§3.5) — иска се преди първи прод deploy.~~ ЗАТВОРЕНО от таск 601** — виж §3.5
   и §7а4.1.
6. **`metro.config.js` tslib резолвърът** беше единствената промяна извън обхвата на таск 42. Ревертът му
   чупи `expo export --platform web` и с това целия e2e — ревюирайте съзнателно.
7. **`dev-login` (таск 301) вече ИМА защита отвъд `IsDevelopment()` — ЧАСТИЧНО затворена.** Опционален
   споделен token (таск 423, `DevLogin:Token`) + общият `/auth/*` rate limiter (таск 421, 10/мин)
   покриват брутфорса. Все още НЯМА собствен аудит лог на dev-login опитите — ако някога влезе в
   shared dev deploy, тази точка остава за решение.
8. **`NotificationPreference` живее временно в грешния слой (таск 404, code review TODO).**
   `Features/Push/Preferences/` вместо `Domain`/`Common` — обръща посоката на зависимостите
   (`Data` internal-va слайс код; `FanoutNotifier` от slice `PushSend` вика хендлъра на slice
   `Push`). Планираният фикс: фундаментен таск в началото на следващата фаза изкачва ентитито +
   `NotificationCategories` нагоре, преди втори такъв прецедент да се появи.
9. **`SettlementTypeahead` (таск 414) е построен и тестван, но НИКЪДЕ не е монтиран.** Точно като
   старата push история (т.4 по-горе): `CreateTableInput`/`UpdateTableSettingsInput` още нямат
   `settlementId` в контракта, а видим контрол, чийто избор мълчаливо се губи, е UI, който лъже.
   Формите го монтират, когато BE таск добави полето и изборът реално пътува към сървъра.
10. ~~**Витрината няма infinite scroll**~~ ЗАТВОРЕНО от таск 705 — виж §7а5.1.
11. **~~Rate limiter деплой допускането е недовършено.~~ ЗАТВОРЕНО от таск 602** — `HostingSetup`
    включва `UseForwardedHeaders()` с изпразнени `KnownNetworks`/`KnownProxies` (безопасно зад
    Render-овия прокси, виж „Hosting в детайли" §1а и §7а4.2); `RateLimitingSetup.Subject` вече
    вижда честен клиентски IP.
12. **Facebook логинът е спрян, не изтрит (таск 513).** За да се върне: добави `'facebook'` обратно
    в `AUTH_PROVIDERS` (`frontend/src/features/auth/oauth.ts`) И конфигурирай
    `Authentication:Facebook:ClientSecret` (backend user-secrets/env) — провайдърът се регистрира
    само ако е конфигуриран (§3.4). Иска решение на потребителя (https redirect + app review при
    Meta), не е технически дълг.
13. **`MyTablesListingDocument` е ВТОРА заявка само за баджа „обявена/необявена" (таск 515).**
    Нарочен избор (виж бележката в `queries.ts`, §1б/§1г): каноничната `MyTablesDocument` селекция
    остава непипната, за да не задължи трите ѝ чужди писачи в кеша (`createTable`/`refoundTable`/
    `acceptRefoundInvite`) да носят и полето. Ако „Моите маси" някога стане тежък екран, обединяването
    на двете заявки в едно поле е задача за отделен таск, не за случаен рефакторинг покрай друга фича.
