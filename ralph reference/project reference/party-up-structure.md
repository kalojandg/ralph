# Party Up — Architecture Reference

> Прочети този файл ПРЕДИ да пишеш код. Патърните тук са ПРАВИЛА, не препоръки.
> Приложение: TTRPG matchmaking (pull модел — играчите се публикуват на LFG борд,
> МАСИТЕ дърпат кандидати). GREENFIELD монорепо, TDD от commit 1. Пълната продуктова
> спека: `party-up.md` в D:\Downloads\monk\ (секции А–Е + Решения лога).

## §1. Файлова карта (монорепо)

```
party-up/
├── backend/
│   ├── PartyUp.slnx              ← .NET 10 solution (СЛЪНЦЕТО Е .slnx, НЕ .sln!)
│   ├── src/PartyUp.Api/          ← единственият BE проект: minimal API + Hot Chocolate
│   │   ├── Program.cs            ← DI + GraphQL pipeline + RunWithGraphQLCommandsAsync (дава schema export)
│   │   ├── GraphQL/              ← Query.cs (+ Mutation/Subscription типове като се появят)
│   │   └── Properties/launchSettings.json  ← портове 5001 (https) / 5000 (http) — OAuth redirect-ите са регистрирани на 5001!
│   └── tests/
│       ├── PartyUp.UnitTests/        ← xUnit, бързи, БЕЗ Docker
│       └── PartyUp.IntegrationTests/ ← xUnit + Testcontainers.PostgreSql (истински Postgres в Docker)
├── frontend/                     ← Expo SDK 57 (create-expo-app default template)
│   ├── src/app/                  ← Expo Router файлове (_layout.tsx, index.tsx, explore.tsx)
│   ├── src/components|constants|hooks/  ← template код (темизация и т.н.)
│   ├── src/__tests__/            ← jest-expo + RNTL спекове
│   ├── package.json              ← preset jest-expo; scripts: test, typecheck, web
│   ├── tsconfig.json             ← strict, types:["jest"], paths @/* → ./src/*
│   └── expo-env.d.ts             ← НАРОЧНО в git (против Expo конвенцията): без него tsc пада на чист clone
├── contracts/
│   ├── schema.graphql            ← ЖИВИЯТ КОНТРАКТ BE↔FE (експорт от Hot Chocolate)
│   └── schema-settings.json      ← Hot Chocolate export метаданни
├── global.json                   ← пин SDK 10.0.400 (rollForward latestFeature)
└── .gitignore                    ← bin/obj, node_modules, .expo, .env*, playwright-report, test-results
```

## §2. Стек (ФИКСИРАН — агентите НЕ избират депендънсита)

- **BE:** .NET 10 + Hot Chocolate 16.6 + EF Core/Npgsql 10 + ASP.NET Identity (САМО external logins). Пакетите за Google/Facebook/Discord auth са инсталирани.
- **FE:** TypeScript (strict) + Expo Router + Apollo Client (graphql-ws за subscriptions) + Zustand (само UI state; сървърният state е Apollo кешът) + NativeWind + react-hook-form + react-i18next (+ expo-localization). БЕЗ Redux. Инсталирани, още не са wired.
- **Codegen:** @graphql-codegen/cli + client-preset (dev deps, конфиг още няма — първи FE таск).
- Нов пакет = решение на потребителя, НЕ на агент.

## §2а. BE патърни (РЕШЕНИ 14.08 — агентите ги СЛЕДВАТ, не ги предоговарят)

1. **Vertical slices, БЕЗ MVC/контролери**: use case = папка Features/<Област>/<UseCase>/ (handler + HC type extension). Никакви „дебели" сървиси-чували.
2. **CQRS-lite, НЕ пълен CQRS**: query и mutation handler-ите са разделени по конструкция (GraphQL). Отделни read модели/проекции/шини НЕ се строят — отрицателна стойност на този мащаб.
3. **Интерфейс САМО при реална подмяна** (INotifier, IPushSender). Двойки IXxxService/XxxService по инерция = шум, не се пишат. БЕЗ repository слой над EF (DbContext-ът Е repository+UoW; тестовете подменят през Testcontainers, не през мок на данни).
4. **Read дисциплина от ден 1 (проектът се цели в read-intensive)**: всеки query handler ползва AsNoTracking() + Select проекция ПРАВО в GraphQL типа (не зарежда цели entities); вложените колекции в GraphQL (състав на маса, последни съобщения) минават през Hot Chocolate DataLoader срещу N+1. Кеш слой на сървъра — БЕЗ (чак при реални метрики).
5. **Result pattern** (§4.5) — очакваните провали са стойности; exceptions само за програмни грешки.

## §3. Модел на персистенция / живи контракти

1. **`contracts/schema.graphql` е ЖИВ КОНТРАКТ** — единственият договор BE↔FE. НЕ се пише на ръка: променя се САМО през C# кода + ре-експорт (`schema_export` командата). BE task-ове коммитват новия експорт; FE task-ове го ЧЕТАТ (codegen), никога не го редактират.
2. **Прод базата е Neon Postgres** — connection string-ът е СЕКРЕТ, съществува само в password manager-а на потребителя / dotnet user-secrets / прод .env. НИКОГА в git, НИКОГА в тест.
3. **Тестовете ползват САМО Testcontainers** — вдигат си истински Postgres в Docker. Никаква връзка към Neon/жива база от тест или агент.
4. **Секрети:** dev = `dotnet user-secrets` (UserSecretsId вече е init-нат в PartyUp.Api). Конфиг ключовете (напр. `Authentication:Google:ClientSecret`) се четат от IConfiguration — стойностите ги слага ПОТРЕБИТЕЛЯТ. Публичните OAuth client ID-та НЕ са секрети (стоят в appsettings.json): Google `438566552589-bqbid79l39j6j8g1j0dhmdtoebgv9bu5.apps.googleusercontent.com`, Discord `1537485903222673490`, Facebook `2139533033575936`.

## §4. ЧЕРВЕНИ ЛИНИИ (нарушение = failed таск)

1. **Никакви секрети в git** — нито в appsettings, нито в тестове, нито в коментари. Празни placeholder ключове в appsettings.Development.json са ОК; стойности — НЕ. (gitleaks мисленето важи и без gate.)
2. **`contracts/schema.graphql` не се редактира на ръка** (виж §3.1). FE не го пипа изобщо.
3. **Тест никога не докосва външен ресурс**: без Neon, без реални OAuth провайдъри, без мрежа. Integration = Testcontainers, точка.
4. **Dev сървъри НЕ се пускат от агенти** (`dotnet run`, `expo start`) — портове 5001/8081 са едни. Гейтът пуска само тестовите команди.
5. **Result pattern в бекенда (решение 13.08):** очакваните провали (зает слот, невалиден вот, липсващо право) са СТОЙНОСТИ (Result), не exceptions. Exceptions = само програмни грешки. GraphQL слоят мапва Result грешките към типизирани error полета (Hot Chocolate mutation conventions) → FE показва човешки съобщения през i18n ключове. Никакъв raw stack trace до UI.
6. **i18n от ден 1:** всички UI низове през react-i18next ключове (BG/EN). Хардкоднат низ в компонент = failed таск. UI езикът е ОТДЕЛЕН от профилното поле „език на сесиите".
7. **Тестовите инфраструктурни файлове** (jest конфиг, tsconfig, мокове, helpers) се създават от инфраструктурни таскове и се КОНСУМИРАТ от останалите — фича таск не ги преправя.
8. **`git push` не се прави от агент** — merge/push е работа на оркестратора/потребителя.

## §5. ОТРОВЕН СПИСЪК (споделени файлове → диктуват соло lanes)

Едновременна редакция от два таска = merge конфликт = загорели retry бюджети. Тези файлове ги пипа само ЕДИН таск наведнъж (фундаментен таск в началото на фаза ги изяжда, после фича lanes не ги докосват):

| Файл | Защо е отрова |
|------|---------------|
| `backend/PartyUp.slnx` | нов проект = редакция тук |
| `backend/src/PartyUp.Api/Program.cs` | всяко DI/pipeline wiring минава оттук |
| `backend/src/PartyUp.Api/PartyUp.Api.csproj` | нов пакет/reference |
| `contracts/schema.graphql` | ре-експортира се при ВСЯКА схема промяна — BE фаза го променя серийно |
| `frontend/package.json` + `package-lock.json` | нов пакет/скрипт |
| `frontend/tsconfig.json` | компилаторни опции |
| `frontend/src/app/_layout.tsx` | root layout — provider-и (Apollo, i18n, тема) се wire-ват тук |
| `frontend/src/global.css` + NativeWind конфиг (като се появи) | глобални стилове |
| i18n locale файловете (като се появят) | всяка фича добавя ключове — конвенция: по един namespace файл per фича ИЛИ серийни таскове |
| `.gitignore`, `README.md`, `global.json` | root мета |

## §6. Команди и портове

```
dotnet test backend/PartyUp.slnx --nologo          # пълен BE suite (иска Docker Desktop!)
dotnet test backend/tests/PartyUp.UnitTests        # само unit, без Docker
npm --prefix frontend test                          # jest-expo
npm --prefix frontend run typecheck                 # tsc --noEmit
cd backend && dotnet run --project src/PartyUp.Api -- schema export --output ../../../contracts/schema.graphql
```

**Портове (флотска сверка):** 45279 (inventory/hero/spells) и 45278 (combat) са ЗАЕТИ от другите репота. Party Up ползва: **5001/5000** (BE dev, OAuth redirect-ите сочат 5001) и **8081** (Expo dev). Няма колизии. Dev сървърите — НЕ от агенти (§4.4).

**Worktree бележка:** `npm --prefix frontend install` е ЗАДЪЛЖИТЕЛНА първа стъпка в нов worktree (node_modules не пътуват). NuGet пакетите идват от глобалния кеш — `dotnet restore` става имплицитно. Docker Desktop трябва да е СТАРТИРАН преди run (интеграционните тестове иначе падат с named pipe грешка).

## §7. Тестово състояние (към 13.08.2026)

- BE: 1 unit smoke (Query.Hello) + 1 integration smoke (Testcontainers Postgres SELECT 1 — доказано зелен на машината). Пълен BE suite: ~12 сек (postgres image-ът е кеширан).
- FE: 1 RNTL smoke (render на <Text>). jest ~3 сек, tsc ~3 сек.
- **Пълен verify: ~20 сек.** (verify_timeout_min 45 е с огромен запас.)
- Playwright e2e ОЩЕ НЯМА — verify е БЕЗ e2e; e2e bootstrap е отделен бъдещ таск (изисква и решение как Playwright стартира Expo web — webServer конфиг).
- ВНИМАНИЕ: RNTL v14 — `render` е ASYNC (`await render(...)`); `screen` API-то от v12/13 го НЯМА. TS 6.0 НЕ включва @types автоматично — types:["jest"] е вече в tsconfig.

## §7а. Амендмънти за фаза v0.1 (board 1-42)

1. **§3.1 екзепция:** таск 2 РЪЧНО пише целевата schema.graphql (contract-first — FE строи срещу нея с мокове, BE я ползва като спека). Таск 41 я замества с реалния Hot Chocolate експорт и затваря екзепцията. Междувременно НИКОЙ друг таск не пипа contracts/.
2. **Vertical slice архитектура (решение на board-а):** всеки use case = папка `Features/<Област>/<UseCase>/` (handler + HC type extension). Регистрация през source generator (`AddTypes()`) + IEndpointModule reflection котва — Program.cs се пипа САМО от таскове 1 и 26. Feature таск НЕ добавя entities (моделът е изцяло в таск 1), НЕ пипа csproj/Program.cs/Domain/Common.
3. **FE codegen:** src/gql/ е GITIGNORED, генерира се в typecheck/test скриптовете — генерираният код никога не се комитва (нулеви конфликти между паралелни FE таскове). Locale ns файловете и route placeholder-ите се създават ВСИЧКИ от таск 3 — фича таскът пълни само своите.
4. **DomainErrorType патерицата (открита от таскове 4/5/6 на 16.08):** `Common/GraphQL/DomainErrorType.cs` регистрира `[ObjectType<DomainError>]`, който се СБЛЪСКВА с `ErrorObjectType<DomainError>`, генериран от mutation conventions за всяка mutation с `FieldResult<T, DomainError>` → "The name 'DomainError' was already registered". Файлът е bootstrap патерица (нужен само докато няма НИКАКВИ други анотирани типове). Премахването е КООРДИНИРАНО: първите mutation слайсове (4/5/6) са авторизирани да го изтрият в собствения си commit (delete/delete merge е безконфликтен). Ако вече ГО НЯМА в твоя worktree — проблемът е решен, не го връщай. НЕ регистрирай ръчно DomainError тип — конвенцията го произвежда сама.
5. **⚠ КОНВЕНЦИЯ ЗА QUERY ПОЛЕТА: `[ObjectType<Query>]`, НЕ `[QueryType]`.** `[QueryType]` extension-ите се ИЗХВЪРЛЯТ БЕЗШУМНО (Program.cs вика AddQueryType<Query>() → генераторският TryAddRootType no-op-ва и operation-keyed конфигурацията не се закача) — полетата липсват от схемата БЕЗ никаква грешка. Всеки query таск задължително ползва `[ObjectType<Query>]` (потвърдено работещо от таскове 5 и 6). Mutation root-ът НЕ е засегнат.

## §7б. REVIEW КРИТЕРИИ (за finishing review stage — ревюърът оценява diff-а СПРЯМО ТЯХ)

**BE (C# / Hot Chocolate):**
1. Vertical slice дисциплина: нова логика живее в `Features/<Област>/<UseCase>/`; фича diff НЕ пипа Domain/Common/Program.cs/csproj (изкл. таскове 1/26). Нарушение = Блокер.
2. Зависимости навътре: slice не reference-ва типове на друг slice директно (само през Domain модела); без „сървиси-чували"; интерфейс само при реална подмяна (§2а.3) — двойка IXxx/Xxx по инерция = Важно.
3. Read дисциплина (§2а.4): query handler без AsNoTracking/Select проекция = Важно; вложена колекция без DataLoader (N+1) = Важно.
4. Result pattern (§4.5): очакван провал като exception = Блокер; raw exception, стигащ до GraphQL error без мапване = Блокер.
5. Тестове: нов use case без unit тест = Важно; персистенция без integration (Testcontainers) тест = Важно.

**FE (Expo / Apollo):**
6. Контрактът е закон: ръчно писани типове, дублиращи schema.graphql (вместо codegen от src/gql) = Важно; редакция на contracts/ от FE = Блокер.
7. Server state само в Apollo кеша, UI state само в Zustand (§2) — смесване = Важно.
8. i18n: хардкоднат UI низ = Блокер (§4.6); ключ в грешен namespace = Препоръка.
9. Форми през react-hook-form; тестове с RNTL v14 async render (`await render`) — old-style = Важно (флейки).

**Общи (проверявай ПЪРВО):**
10. Секрети в diff-а (connection strings, client secrets, токени) = БЛОКЕР, винаги.
11. Несъответствие код ↔ contracts/schema.graphql (поле/тип в кода, липсващо в контракта или обратно) = Блокер до таск 41, Важно след него.
12. Мъртъв код, закоментирани блокове, TODO без референция = Препоръка.

**Калибровка на приоритетите:** Блокер = нарушена червена линия (§4) / счупена логика / секрет. Важно = нарушен патърн (§2а/§8а) с реален риск. Препоръка = стил и бъдещи подобрения. НЕ инфлирай: стилово мнение, маскирано като Важно, съсипва acceptance цикъла.

## §8. Правила за декомпозиция (за /ralph-plan)

- Lanes по зони: `contracts/BE` тасковете (C# + експорт) са СЕРИЙНИ помежду си (schema.graphql е отрова); FE тасковете се паралелизират срещу ЗАМРАЗЕН контракт.
- Фундаментен таск на фаза изяжда отровните файлове (DI wiring, provider-и, пакети), фича тасковете после не ги пипат.
- Всеки таск декларира `repo: "partyup"` (полето е задължително, дефолт НЯМА).
- Verify е общ за монорепото (BE+FE) — счупен FE тест блокира merge на BE таск и обратно. Това е НАРОЧНО (контрактът е общ).
