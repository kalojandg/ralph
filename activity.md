# Activity Log

Наративен дневник на свършената работа. **Подредба: най-новият запис ОТГОРЕ** (prepend).
Агентът добавя по един запис на завършен таск (Step 4 от PROMPT.md). Пълна спецификация на формата:
`ralph reference/tasks-and-progress-reference.md` §2.3.

Шаблон на запис (копирай, попълни, сложи най-отгоре):

```markdown
## [YYYY-MM-DD HH:MM] - Task #<id>: <description дословно от tasks.json>

**Status:** ✅ Complete

**TDD Phase:** RECON → RED → GREEN → (VISUAL →) (REFACTOR →) DONE   ← само при tddWorkflow

**Problem:** <какъв е бил проблемът / контекст>   ← по избор

**What was done:**
- RED: <какъв failing тест е добавен, verify че fail-ва>
- GREEN: <минимална имплементация, verify че pass-ва>

**Verification:**
- <тест файл> → X/Y pass
- eslint → 0 errors | type-check → clean

**Files modified:**
- <path 1>
- <path 2>

**Git commit:** `<hash>` — `<commit message>`

---
```

<!-- Записите започват под тази линия — най-новият веднага след нея. -->

## [2026-08-18 20:14] - Task #26: feat(push): add notifier fan-out decorator sending web push and publishing notification topic

**Repo:** partyup (backend) · **Lane:** be-push-send · **Commit:** `f2a244e`

**Status:** ✅ Complete

**TDD Phase:** RECON → RED → GREEN → DONE

**Problem:** Таск 25 остави адресната книга, таск 20 — абоната на `onNotification`, но по личната тема никой не публикуваше и до нито един endpoint не тръгваше пратка. `INotifier` (фундаментът) беше интерфейс точно заради този момент: слоят се закача като ДЕКОРАТОР, без нито един от handler-ите, които вече викат `NotifyAsync`, да разбере.

**What was done:**
- RED: 8 unit спека (`PushFanout` — разпраща до всяко устройство, връща за изтриване САМО мъртвите (410), временният провал НЕ маха адреса, хвърлил sender се гълта и следващото устройство пак получава; `PushEnvelope` — носи id/тип и payload-а ДОСЛОВНО) + 8 integration спека (`INotifier` резолвва към декоратора; редът в базата оцелява; публикува ПЕРСИСТИРАНИЯ ред по `NotificationTopics.User`; push до всички свои устройства и до ничии чужди; пратката == `PushEnvelope` на реда; 410 → записът пада, живият остава; аварирал push сървис НЕ проваля `NotifyAsync`). Червени по правилната причина — `NotImplementedException` от скелетите, а останалите 121 unit-а зелени.
- GREEN: `Features/PushSend/` — `IPushSender`/`PushDelivery` (Delivered/Skipped/Expired/Failed), `WebPushSender` (Lib.Net.Http.WebPush; 410/404 → Expired, всичко друго → Failed с лог), `VapidCredentials` (публичният ключ през СЪЩАТА константа, с която `vapidPublicKey` го раздава на браузъра — разминаване тук е мълчаливо смъртоносно; липсващ ключ = push слоят не съществува в тази среда), `PushFanout` (чиста логика, без база), `PushEnvelope` (вгражда `PayloadJson` като JSON, за да са push и `onNotification` два канала на ЕДНО известие), `FanoutNotifier` и `PushSendServices.AddPushFanout()`.
- Program.cs: ЕДИН ред — `AddScoped<INotifier, DefaultNotifier>()` → `AddPushFanout()` (цялото wiring живее в слайса, за да не се връща никой в отровния файл).

**Verification:**
- `dotnet test backend/PartyUp.slnx` → 129/129 unit + 287/287 integration, 0 failed, 0 skipped (пълна регресия — Program.cs е пипнат)
- contracts/schema.graphql НЕПИПНАТ — слоят не добавя нито едно GraphQL поле (`onNotification` вече го има от таск 20)
- никакви секрети: `Push:VapidPrivateKey`/`Push:VapidSubject` се четат от конфигурацията, стойности в git НЯМА

**⚠ ИЗЛЯЗОХ ИЗВЪН `files` С ЕДНА ПРОМЯНА (за преглед):** `backend/tests/PartyUp.IntegrationTests/Foundation/NotifierTests.cs` от таск 1 твърдеше `Assert.IsType<DefaultNotifier>(INotifier)` — точно регистрацията, която ТОЗИ таск е дефиниран да замени (файлът сам казва „таск 26 закача push fan-out декоратор около него"). Спекът е обновен НАЙ-МИНИМАЛНО и със запазено намерение (името му е `INotifier_IsResolvableAsAScopedService`): веригата се резолвва + дефолтът е още жив като услуга. Другият спек във файла (записва непрочетена нотификация със сериализиран payload) е непипнат и вече минава ПРЕЗ декоратора. Без тази промяна пълният suite е червен и merge-ът пада.

**Files modified:**
- backend/src/PartyUp.Api/Program.cs
- backend/src/PartyUp.Api/Features/PushSend/IPushSender.cs
- backend/src/PartyUp.Api/Features/PushSend/FanoutNotifier.cs
- backend/src/PartyUp.Api/Features/PushSend/PushFanout.cs
- backend/src/PartyUp.Api/Features/PushSend/PushEnvelope.cs
- backend/src/PartyUp.Api/Features/PushSend/WebPushSender.cs
- backend/src/PartyUp.Api/Features/PushSend/VapidCredentials.cs
- backend/src/PartyUp.Api/Features/PushSend/PushSendServices.cs
- backend/tests/PartyUp.UnitTests/Features/PushSend/PushFanoutTests.cs
- backend/tests/PartyUp.UnitTests/Features/PushSend/PushEnvelopeTests.cs
- backend/tests/PartyUp.UnitTests/Features/PushSend/StubPushSender.cs
- backend/tests/PartyUp.IntegrationTests/Features/PushSend/FanoutNotifierTests.cs
- backend/tests/PartyUp.IntegrationTests/Features/PushSend/RecordingPushSender.cs
- backend/tests/PartyUp.IntegrationTests/Foundation/NotifierTests.cs (вж. бележката горе)

**Git commit:** `f2a244e` — `feat(push): add notifier fan-out decorator sending web push and publishing notification topic`

---


## Task 32 — feat(fe-tables): add create table form with one-shot event fields and training tag

**Repo:** partyup · **Lane:** fe-table-create · **Commit:** `d12cd1c`

### Какво е направено

Екранът „Създай маса" (А3, founder flow) — една react-hook-form форма върху `createTable`:

- **`features/table-create/table-form-values.ts`** — стойностите на формата (низове, както `TextInput` ги връща) + `toCreateTableInput` мапингът към контракта: тагове „с запетаи" → `[String!]`, дата+час → ISO UTC, празен текст → `null`. `founderIsGm: !seekingGm` (половин мач, ядка №3). `fieldForErrorKey` реши коя типизирана грешка при кое поле сяда.
- **`table-form-fields.tsx`** — `TextField` / `RadioGroup` / `CheckboxField`. Етикетите влизат ГОТОВИ преведени, за да не се крият i18n ключове в презентационния слой (§4.6).
- **`table-create-form.tsx`** — всички полета по `CreateTableInput`: име, система, формат, място (свободен текст, Б), език на сесиите (отделен от езика на UI, Е.9), тагове, описание, слотове 2–10, „търсим DM", и **„ОБУЧИТЕЛЕН ONE-SHOT"** чекбокс с визуално открояване (Е.8 — сърцето на клина: „ела да те научим, 0 опит"). Времето е **радио** (Б): ONE-SHOT (дата+час+място на събитието) ↔ ПОСТОЯНЕН (свободен график „сряда 19:00") — режимът решава кои полета изобщо съществуват, затова се `watch`-ва.
- **Result pattern (§4.5)** — `payload.errors` са СТОЙНОСТИ: всяка сяда при полето си по `i18nKey`, непознатите остават над бутона. Никога `message` (той е за разработчици). Успех → `router.replace('/tables')`.
- **`table-create.gql.ts`** — тясна селекция (масата вече съществува; „Моите маси" си дърпа своя списък).
- **`app/table/create.tsx`** — placeholder-ът заменен с реалния екран.
- **i18n ns `tableForm` (BG+EN, 63 ключа, пълен паритет)** — включително всички `tables.*` ключове, които `CreateTableValidator` реално емитва.

### TDD

RED първо (6 спека, RNTL v14 async `render`/`fireEvent`): радиото сменя полетата за време · валиден submit праща верния input (вкл. обучителния таг) и препраща към „Моите маси" · постоянна маса праща график вместо дата · слотове = 1 блокира записа · one-shot без дата блокира · типизирана грешка от сървъра се показва при съответното поле.

### Верификация

`npm --prefix frontend run typecheck` ✅ · `npm --prefix frontend test` ✅ **15 suites / 59 теста зелени**.

### Бележки

Итерацията е ПРОДЪЛЖЕНИЕ на провален опит (API 529 Overloaded уби предшественика след GREEN, преди commit-а и result файла). Работата в worktree-то беше ревюирана срещу контракта и червените линии, намерена за коректна и пълна, и комитната без пренаписване. При първия тестов пуск два ПРЕДХОДНИ спека (profile-screen, settings-screen) паднаха с 5s timeout заради натоварване веднага след `npm install` — минават стабилно при всеки следващ пуск и не са пипани от този таск. `src/gql/` остава gitignored, `package-lock.json` — непроменен.


## [2026-08-18 19:52] - Task #25: feat(push): add pushSubscribe and pushUnsubscribe mutations with vapid public key query

**Repo:** partyup (backend) · **Lane:** be-push-subscribe · **Commit:** `4d5fb8a`

**Status:** ✅ Complete

**TDD Phase:** RECON → RED → GREEN → DONE

**Problem:** След таск 20 subscriptions-ите носят realtime, докато приложението е отворено. За затворения браузър (Е, Web Push в v0.1) трябва адресна книга: на кои endpoint-и да се звънне за даден човек — без самото пращане (таск 26).

**What was done:**
- RED: 12 integration спека в `Features/Push/` — subscribe регистрира адреса; повторен subscribe оставя ТОЧНО един ред и обновява ключовия материал; второ устройство пази два адреса; смяна на собственика на устройството; unsubscribe — свой/непознат (тих успех)/чужд (непокътнат); анонимен викащ → FORBIDDEN; theory спек че `p256dh`/`auth`/`userId` НЕ съществуват в схемата; vapidPublicKey от config override / празен без ключ / четим анонимно. Червени — полетата ги нямаше в схемата.
- GREEN: `PushRegistrationHandler` (upsert по endpoint — ключът е ИНСТАЛАЦИЯТА на service worker-а, не потребителят; unique индексът от таск 1 го пази), `PushSubscriptionMutations` (mutation conventions → Input/Payload двойките от контракта, Result pattern), `PushSubscriptionGraphQLType` (Ignore на P256dh/Auth/UserId/User) и `VapidQueries` с `[ObjectType<Query>]`.

**Verification:**
- `dotnet test backend/PartyUp.slnx` → 121/121 unit + 252/252 integration, 0 failed, 0 skipped
- експортираната HC схема (в temp, не в contracts/) съвпада дословно с `contracts/schema.graphql` за целия push разрез (операции, Input-и, Payload-и, error union-и, `PushSubscription` без ключов материал)
- Program.cs/csproj НЕПИПНАТИ — регистрацията е през source generator-а

**Files modified:**
- backend/src/PartyUp.Api/Features/Push/Subscriptions/PushRegistrationHandler.cs
- backend/src/PartyUp.Api/Features/Push/Subscriptions/PushSubscriptionMutations.cs
- backend/src/PartyUp.Api/Features/Push/Subscriptions/PushSubscriptionGraphQLType.cs
- backend/src/PartyUp.Api/Features/Push/Vapid/VapidQueries.cs
- backend/tests/PartyUp.IntegrationTests/Features/Push/PushSeed.cs
- backend/tests/PartyUp.IntegrationTests/Features/Push/PushSubscriptionTests.cs
- backend/tests/PartyUp.IntegrationTests/Features/Push/VapidPublicKeyTests.cs

**⚠ РЪЧНА СТЪПКА ПРИ DEPLOY:** реална VAPID двойка НЕ е генерирана и НЕ влиза в git. `Push:VapidPublicKey` е ПРАЗЕН placeholder — докато е такъв, `vapidPublicKey` връща празен стринг и FE го чете като „няма push слой" (progressive enhancement). При deploy: генерирай двойката, публичният в config, частният САМО в user-secrets/deploy тайни.

**Git commit:** `4d5fb8a` — `feat(push): add pushSubscribe and pushUnsubscribe mutations with vapid public key query`

---


## [2026-08-18 19:40] - Task #30: feat(fe-tables): add my tables list with status badges and create entry point

**Repo:** partyup (frontend) · **Lane:** fe-my-tables · **Commit:** `c312806`

**Status:** ✅ Complete

**TDD Phase:** RECON → RED → GREEN → DONE

**Problem:** Предишният опит е бил прекъснат между GREEN и DONE: целият slice беше написан, но некомитнат и `typecheck` падаше. Retry отчетът беше от друг проект (monk_combat_app / flavor tab) — нерелевантен, диагнозата е направена от самия worktree.

**What was done:**
- RECON: `git status`/`git diff` — запазено е всичко коректно от предшественика; сверка срещу `contracts/schema.graphql` (`myTables: [TableMembership!]!`).
- RED/GREEN (от предишната сесия, прието): `features/my-tables/` — `queries.ts` (codegen документ `MyTables`), `my-tables-screen.tsx`, `table-card.tsx` (име, система, роля, GM индикатор, линк → `/table/[id]`), `status-badge.tsx` (преведен статус, никога суров enum), `empty-state.tsx` (двоен CTA: създай / публикувай се), `(tabs)/tables.tsx` вече рендерира екрана вместо placeholder, `tables` ns попълнен BG/EN.
- FIX: хелпърът `myTablesMocks` беше типизиран като `(typeof FOUNDED_TABLE)[]`, което заковава `role: 'FOUNDER'`/`status: 'TRIAL'` като литерали и отхвърля `JOINED_TABLE` (TS2322 × 2). Сменен с генерирания `MyTablesQuery['myTables']` — контрактът е законът, не фикстурата.

**Verification:**
- `npm --prefix frontend run typecheck` → codegen + tsc clean (0 errors)
- `npm --prefix frontend test` → 14/14 pass, 5 suites; `my-tables-screen.test.tsx` → 5/5 (карти, линкове, empty state, EN превод, грешка)
- Чист working tree след commit — `src/gql/` остава gitignored, `package-lock.json` непипнат.

**Files modified:**
- frontend/src/features/my-tables/{index.ts,queries.ts,my-tables-screen.tsx,table-card.tsx,status-badge.tsx,empty-state.tsx}
- frontend/src/features/my-tables/__tests__/my-tables-screen.test.tsx
- frontend/src/app/(tabs)/tables.tsx
- frontend/src/locales/{bg,en}/tables.json

**Git commit:** `c312806` — `feat(fe-tables): add my tables list with status badges and create entry point`

---


## Task #29 — feat(fe-profile): add profile form with react-hook-form covering all player fields

**Repo:** partyup (frontend) · **Lane:** fe-profile · **Commit:** `6bfafd0`

### Какво е направено
Профил табът е реален екран вместо placeholder. Вертикален FE слайс в `frontend/src/features/profile/`:

- **`profile.gql.ts`** — `ProfileFields` фрагмент + `MyProfile` query + `UpdateProfile` mutation; типовете идват от codegen-а (`@/gql`), нищо не е писано на ръка (§7б.6). Мутацията чете `errors { ... on DomainError { code i18nKey } }` — Result pattern-ът, не exceptions.
- **`profile-form-values.ts`** — чистата логика: `toFormValues` / `toUpdateProfileInput` (форма ↔ контракт), `parseSystems` (запетайки → списък), `toggleInList` (мултиселект в каноничен ред, пази непознати стойности), `fieldForErrorCode` (машинният `DomainError.code` → полето, което да светне).
- **`profile-fields.tsx`** — `FormField` / `TextField` / `ToggleGroup` (radio за „едно от", checkbox за мултиселект; RN няма `<select>`, затова натискаеми чипове с `accessibilityState.checked`).
- **`profile-form.tsx`** — RHF форма с всички полета от А3: DisplayName, опит, тип игра (свободен текст), формат, **езици на ИГРА** (съзнателно отделени от UI езика — Е.9, подсказката го казва), **DM/играч мултиселект** (двете едновременно е валидно), системи, Bio. Типизираните грешки сядат при полето си през `t(i18nKey)`; непознат код → грешка над бутона. Успехът е „✓ Записано" **на бутона** (установеният патърн, без toast) и се извежда от `saved && !isDirty`, не се синхронизира ръчно.
- **`profile-screen.tsx`** — `myProfile` → loading / грешка / форма с готови дефолти (формата се монтира чак след заявката, за да не се ресетва под пръстите на потребителя).
- **`(tabs)/profile.tsx`** — тънък route, който само рендерира `<ProfileScreen />`.
- **`locales/{bg,en}/profile.json`** — попълнен САМО profile namespace-ът (нула конфликт с паралелните FE таскове). Нито един хардкоднат низ в компонент (§4.6).

### Тестове
- `profile-form-values.test.ts` — чистите трансформации.
- `profile-form.test.tsx` — init от профил; празен профил → празни дефолти; **двете роли off → блокиран запис**; submit праща точния `UpdateProfileInput` и бутонът казва „✓ Записано"; типизирана грешка от сървъра → съобщението при полето, бутонът НЕ показва успех.
- `profile-screen.test.tsx` — myProfile → форма; null профил; loading; грешка.

**Verify:** `npm --prefix frontend run typecheck` ✅ · `npm --prefix frontend test` ✅ 22/22 в 7 suite-а.

### Бележка (continuation)
Итерацията беше рестарт след прекъснат run — цялата работа беше в worktree-то, но некомитната. Сверих я срещу `contracts/schema.graphql` (`UserProfile`, `UpdateProfileInput`, `UpdateProfilePayload` съвпадат поле по поле), пуснах двата гейта и я комитнах. Единственият ми опит за промяна — махане на `await` пред `fireEvent`, за да замлъкнат React `act` предупрежденията — счупи два теста (изтекъл act scope изпразва дървото на СЛЕДВАЩИЯ тест) и го върнах: async `fireEvent` идиомът е правилният за RNTL v14 и коментарът в теста вече го документира.


## Task 24 — feat(lifecycle): add refoundTable mutation cloning profile and auto-inviting active members

**Repo:** partyup (branch `ralph/task-24`, commit `a0e51f1`)

**Какво е направено:**
- `backend/src/PartyUp.Api/Features/Lifecycle/Refound/` — нов вертикален слайс:
  - `RefoundTableHandler` — клонира ПРОФИЛА на масата (име/система/формат/място/език/тагове/описание/слотове/seekingGm/one-shot/график/режим на прием) в нова маса със `Status=Forming` и `ListingActive=false`; founder = викащият (с пренесен `IsGm` от старото му членство). Право има ВСЕКИ активен член (А5 — механизмът е точно за заспал founder), не само основателят. Старата маса не се пипа; чатовете не се клонират.
  - `RefoundInvite` — типът на известието `REFOUND_INVITE` + сглобяване/разчитане на payload-а на едно място. Поканата Е известието (отделна таблица „покани" не се строи).
  - `AcceptRefoundInviteHandler` — лек прием без церемония (пресъздаване, не прием — А2 не важи тук): проверява поканата, създава/възкресява членство `Member`, пренася GM ролята, идемпотентен при повторен клик; без покана → `FORBIDDEN`.
  - `RefoundMutations` — `refoundTable(tableId, name?)` → payload `table`, `acceptRefoundInvite(tableId)` → payload `membership`; регистрация през source generator-а, Program.cs непипнат.
- `backend/tests/PartyUp.IntegrationTests/Features/Lifecycle/Refound/` — 12 спека: клониране на всички полета + ново основателство, покани към останалите активни (вкл. стария founder, БЕЗ напусналия и БЕЗ викащия), старата маса непроменена, ново име само на клонинга, FORBIDDEN за външен/напуснал, NOT_FOUND, приемане на покана (без decision/candidacy), пренесена GM роля, външен → FORBIDDEN, двоен accept → едно членство.

**TDD:** RED (спековете не компилират — слайсът липсва) → GREEN (12/12).

**Тестове:** `dotnet test backend/PartyUp.slnx` — 121 unit + 237 integration, всичко зелено. FE не е пипан (BE-only diff).


## [2026-08-18] - Task #23: feat(lifecycle): add kick flow through group decision excluding the affected member

**Status:** ✅ Complete

**TDD Phase:** RECON → RED → GREEN → DONE

**Problem:** Kick-ът е единственото действие, за което А4/А5/А7 говорят в три различни секции наведнъж: винаги групов (никакъв founder fast-path, дори когато режимът на прием е „founder одобрява"), винаги без засегнатия във вота и в чата, и никога срещу founder-а (там пътят е exodus/„Преоснови", не превземане). Примитивът от таск 14 вече умее всичко това — липсваше входът към него и мястото, където одобреният вот реално маха човека.

**What was done:**
- RECON: merged 14 (`DecisionService.OpenAsync` + `excludedUserId` механиката, `DueVoterIdsAsync`, pendingVoters DataLoader-ът вече изключва засегнатия) и merged 16 (`CandidacyService` — Apply-ът е ПРИ ЧЕТЕНЕ: изходът живее върху решението и се пренася идемпотентно, а зоната на решенията не знае за консуматорите си). А4 (kick = групово, алармата само стартира процеса), А5 (founder-ът е постоянен; напускането е лично право), А7 (kick е ВИНАГИ групов, режимът пипа само приема) — прочетени дословно.
- RED: `ProposeKickTests` — 15 спека през реалната схема: решение без засегнатия (subject/excludedUser/чат/pendingVoters = останалите), единодушие → неактивно членство + едно неутрално MEMBER_KICKED, „не" → нищо не се случва, пренасяне на изхода преди правата, founder → FORBIDDEN, режим „founder одобрява" → пак вот, под 3 активни (вкл. с напуснали) → TOO_SMALL_FOR_KICK, втори kick → ALREADY_PROPOSED, self-kick → VALIDATION, чужд/анонимен → FORBIDDEN, липсваща маса/член → NOT_FOUND. Червени на компилация (слайсът не съществува).
- GREEN: `Features/Lifecycle/Kick/` — `ProposeKickHandler` (порти в реда: маса → sync → права → self → founder → член → праг 3 → отворена церемония → `OpenAsync(Kick, subject=excluded=member)`; `ShouldUseFounderApprove` НЕ се пита нарочно), `KickService.SyncFromDecisionsAsync` (Approved kick решения → `Active=false` + `LeftAt`, запис ПРЕДИ известията, после по едно `MEMBER_KICKED` с payload само `{ tableId }`; пипа само АКТИВНИ членства → идемпотентно), `ProposeKickMutations` (`[MutationType]` + `PayloadFieldName = "decision"` — Program.cs непипнат).
- Синхронизаторът се вика от mutation-а ПРЕДИ правата: иначе вече изключен човек би предлагал нови kick-ове, а прагът би броял хора, които вече не са на масата. Public/static е нарочно — всеки бъдещ прочит на състава го вика без DI регистрация.

**Verification:**
- `dotnet test backend/tests/PartyUp.IntegrationTests --filter ProposeKickTests` → 15/15 pass
- `dotnet test backend/PartyUp.slnx` → 121/121 unit + 226/226 integration, 0 failed
- Обхват: само `Features/Lifecycle/Kick/**` + `tests/.../Features/Lifecycle/Kick/**`; contracts/schema.graphql, Program.cs, csproj и Domain — непипнати

**Files modified:**
- backend/src/PartyUp.Api/Features/Lifecycle/Kick/KickService.cs (нов)
- backend/src/PartyUp.Api/Features/Lifecycle/Kick/ProposeKickHandler.cs (нов)
- backend/src/PartyUp.Api/Features/Lifecycle/Kick/ProposeKickMutations.cs (нов)
- backend/tests/PartyUp.IntegrationTests/Features/Lifecycle/Kick/ProposeKickTests.cs (нов)

**Git commit:** `558624a` — `feat(lifecycle): add kick flow through group decision excluding the affected member`

---


## Task 22 — feat(lifecycle): add unilateral leaveTable mutation

**Репо:** partyup (`backend/src/PartyUp.Api/Features/Lifecycle/Leave/`) · **Branch:** ralph/task-22 · **Commit:** `52e0227`

**RECON.** Прочетен party-up.md А5 дословно: напускането е едностранно право (противоположността на kick-а), решението е exodus, НЕ превземане → founder-ът е постоянен като роля, но напуска като всеки друг и никаква succession логика не влиза в модела. Съседният слайс `Lifecycle/Trial` даде патърна (mutation conventions + Result pattern + INotifier), а `StayOrLeaveHandler` — умишления контраст: там founder-ът получава FORBIDDEN, защото това е ДРУГ вход (отговор на въпроса на групата), не А5.

**RED.** `Features/Lifecycle/Leave/LeaveTableTests.cs` + собствен `LeaveSeed.cs` (границата на слайса важи и за тестовете) — 12 спека: напускане на място, нула GroupDecision/Vote, работи във ВСЯКА фаза (Theory над 4-те статуса), известия само към останалите, founder напуска без грешка и без прехвърляне на ролята, не-член / вече напуснал / липсваща маса → NOT_MEMBER. Червени по правилната причина: `The field 'leaveTable' does not exist on the type 'Mutation'`.

**GREEN.** Три файла в `Features/Lifecycle/Leave/`: `LeaveTableMutations.cs` (`[MutationType]`, `PayloadFieldName = "membership"` — контрактът от contracts/schema.graphql), `LeaveTableHandler.cs` (едно запитване за активно членство → NOT_MEMBER при липса, Active=false + LeftAt, после известия) и `LeaveNotifications.cs` (`MEMBER_LEFT`). Известията тръгват СЛЕД записа — тогава „останалите" е просто активният състав и напусналият вече не е в него, без изключение, което да се разсинхронизира.

**Верификация.** `dotnet test backend/PartyUp.slnx` → **121 unit + 223 integration, 0 червени**. Program.cs / csproj / Domain / contracts непипнати (§7а.2 — регистрацията минава през source generator-а); никакви секрети; целият diff е вътре в `files` обхвата на таска.


## Task #18 — feat(candidacy): add submitVerdict mutation with membership, auto-delist and neutral notifications

**Репо:** partyup (BE) · **Lane:** be-candidacy-verdict · **Commit:** `bdd4aa0`

### Какво е направено

- **RED:** `backend/tests/PartyUp.IntegrationTests/Features/Candidacies/Verdict/` — `VerdictSeed.cs` (маса с контролируеми `SlotsTotal`/`ListingActive`/`SeekingGm` + кандидатура преди verdict, стъпило върху `DecisionSeed`/`CandidacySeed`) и `SubmitVerdictTests.cs` с 14 спека. Червено по правилната причина: слайсът `Features/Candidacies/Verdict` не съществуваше.
- **GREEN:** `backend/src/PartyUp.Api/Features/Candidacies/Verdict/`
  - `SubmitVerdictHandler.cs` — права (активен член на масата) → валиден статус (`ApprovedForContact` | `InContact`) → изход. **ACCEPT:** `TableMembership` (`Member`, `Active`, `IsGm = asGm && table.SeekingGm`), после `UnpublishService.UnpublishAsync` (таск 12) и `TableDelistService.DelistIfFullAsync` (таск 10) — обявите се свалят от собствениците си, не се преписват тук; накрая `INotifier` → `CANDIDACY_ACCEPTED`. **REJECT:** `Rejected` + `CandidacyService.CandidacyClosedNotification` (`CANDIDACY_CLOSED`) с payload САМО `candidacyId`.
  - `SubmitVerdictMutations.cs` — `[MutationType]` + `[UseMutationConvention(PayloadFieldName = "candidacy")]`, разгънати аргументи `candidacyId/accepted/asGm` точно по `contracts/schema.graphql`. Program.cs непипнат (§7а.2).

### Решения

- **Контрактът бие notes-а:** taskът пише `accept`, схемата — `accepted: Boolean!` + `asGm: Boolean`. Следван е контрактът (§7б.11), contracts/ не е пипан.
- **Неутралността (А2) е тествана като payload, не като тип:** спекът изброява ключовете на JSON-а и иска точно `["candidacyId"]` — нито маса, нито гласували, нито причина.
- **Повторен и подранил verdict = един и същ `INVALID_STATE`:** и двете са невалиден преход, а не липсващо право.
- **Съществуващо неактивно членство се възкресява, не се дублира** — два реда за един човек биха счупили точно броенето, по което пада обявата на масата.

### Верификация

- `dotnet test backend/PartyUp.slnx` → **121 unit + 207 integration, 0 fail** (~18 сек, Testcontainers).
- FE не е пипан (BE-only diff), `frontend/node_modules` липсва в worktree-то → FE командите остават за post-merge гейта; `package-lock.json` нарочно не е мутиран.


## Task #17 — feat(candidacy): add openContactChat mutation creating the private face-to-candidate chat

- **Repo:** partyup (`D:\Downloads\monk\party-up`), branch `ralph/task-17`, commit `c435b4c`
- **Lane:** be-candidacy-contact · **dependsOn:** 16 (CandidacyService merged)

### Какво е направено

Нов vertical slice `backend/src/PartyUp.Api/Features/Candidacies/Contact/`:

- **`OpenContactChatHandler`** — правата първо (активен член на масата на кандидатурата; кандидатът удря в същата проверка, защото не е член), после `CandidacyService.SyncFromDecisionAsync` (изходът на вота живее върху решението и се пренася при четене — иначе единодушното „да“ се препъва в „още се обсъжда“), после статусна порта: само `ApprovedForContact`/`InContact`, иначе `INVALID_STATE`. Създава `Chat { Type = Direct, TableId = null }` с ТОЧНО двама участници — отварящият + кандидатът (Отворени 18.07: „чист 1:1, личен“ — групата НЕ вижда съдържанието). Кандидатурата минава в `InContact`, а `ContactChatId` пази ПЪРВИЯ разговор (`??=`).
- **Идемпотентност без ново понятие:** разговорът се търси по самите двама участници (генеричен 1:1 между потребители), а не по кандидатурата — затова повторното отваряне от СЪЩИЯ човек връща същата нишка, а ДРУГ член получава свой отделен 1:1 (А2 т.3: „лицето“ не е формална роля; ако всички решат да пишат — тяхно право).
- **`OpenContactChatMutations`** — `[MutationType]` + `[UseMutationConvention(PayloadFieldName = "chat")]`, регистрация през source generator-а, Program.cs непипнат (§7а.2). Формата съвпада 1:1 с `contracts/schema.graphql` (`OpenContactChatInput`/`OpenContactChatPayload`/`OpenContactChatError`) — контрактът НЕ е пипан.

### Тестове (TDD, RED първо)

`backend/tests/PartyUp.IntegrationTests/Features/Candidacies/Contact/` — `ContactTestBase` (seed-ва маса + кандидат на борда през съществуващия `CandidacySeed`, кандидатура в зададен статус, по избор с групово решение) + 10 спека: чист 1:1 с точно 2-ма и без маса, идемпотентност за същия човек, отделен чат за друг член с непроменен `ContactChatId`, пренасяне на одобрен вот преди статусната проверка, `INVALID_STATE` при Discussing и при затворена кандидатура, `FORBIDDEN` за външен/за самия кандидат/без сесия, `NOT_FOUND` за липсваща кандидатура.

RED потвърден за правилната причина („The field `openContactChat` does not exist on the type `Mutation`“) преди имплементацията.

### Верификация

`dotnet test backend/PartyUp.slnx` → **101 unit + 189 integration, 0 failed**. Обхватът е точно `files` списъкът — никакви други файлове (contracts/, Program.cs, Domain, FE) не са докоснати.


## Task 20 — feat(chat): add onMessage and onNotification GraphQL subscriptions with authorization

**Репо:** partyup (be-chat-subscriptions lane) · **Commit:** `cbe6eba` · **Тестове:** 101 unit + 155 integration ✅

### Какво е направено

- `Features/Chats/Subscriptions/ChatSubscriptions.cs` — `onMessage(chatId): Message!` през `[Subscribe(With = ...)]`. Абонира се за `ChatTopics.Messages(chatId)` (класът от merged таск 19 — низът е контракт между двата слайса и не се преписва наум). Авторизацията е при абонирането, защото веднъж отворен потокът пропуска всяко следващо съобщение без нов въпрос: липсващ чат → `NOT_FOUND`, чужд чат → `NOT_PARTICIPANT` (същият код, който връща и `sendMessage`), без сесия → `FORBIDDEN`.
- `Features/Chats/Subscriptions/NotificationSubscriptions.cs` — `onNotification: Notification!`. Полето НЯМА аргумент и това е самата авторизация: темата (`user:<userId>`) се извежда от сесията, тоест чуждият поток е недостижим по КОНСТРУКЦИЯ. Публикуването по нея идва от таск 26.
- `Features/Chats/Subscriptions/SubscriptionRefusal.cs` — отказът като GraphQL грешка с `code` + `i18nKey`. Subscription-ите нямат error канал в payload-а (контрактът е `Message!`/`Notification!`), тоест mutation conventions тук нямат къде да сложат отказа; мълчаливо празен поток обаче би бил по-лош — клиентът не може да го различи от тих разговор и би чакал вечно.
- `Features/Chats/Subscriptions/NotificationGraphQLType.cs` — `[ObjectType<Notification>]` със скрити `UserId` (потокът е личен — получателят е винаги викащият) и навигацията `User` (зад нея стои Identity ентитито `AppUser`).
- Интеграционни спекове: 5 за `onMessage` (доставка вкл. `sender` през DataLoader-а, изолация между темите, трите отказа) + 3 за `onNotification`.

### Открито и поправено от предишния опит

Предшественикът беше оставил тестовете и `NotificationTopics.cs`, но `SubscriptionTestBase` НЕ компилираше: в Hot Chocolate 16.6 `OperationResult.Data` е `OperationResultData`, а не речник — индексирането по име на поле не съществува. Вместо да се рови във вътрешното представяне, всяко събитие сега се форматира до JSON със СЪЩИЯ `JsonResultFormatter`, който сериализира и по мрежата → тестът твърди нещо за това, което вижда клиентът, и ползва общите `GraphQLResponseExtensions` helper-и като останалия suite.

### Сверка със схемата

Експорт на реалната HC схема (във временен файл, БЕЗ да се пипа `contracts/schema.graphql` — §7а.1 го пази за таск 41) потвърди дословно съвпадение с контракта: `Subscription { onMessage(chatId: UUID!): Message!, onNotification: Notification! }` и `Notification { id, type, payloadJson, createdAt, readAt }`. Никакви странични полета от source generator-а — subscribe резолверите са `internal` точно затова.

### Бележки

- Program.cs / csproj / Domain / Common — НЕПИПНАТИ (§7а.2); двата `[SubscriptionType]` класа се регистрират сами през `AddPartyUpTypes()`.
- FE не е докосван — `npm` командите не са пускани в това worktree (verify гейтът ги пуска след merge).


## Task #21 — feat(lifecycle): add trial-to-permanent transitions with stay-or-leave choice

**Repo:** partyup (backend, lane be-lifecycle-trial) · **Commit:** `4a86021`

**Какво е направено:**
- `Features/Lifecycle/Trial/TrialTransitions.cs` — пътеката от А6 като ЧИСТА функция: разрешени са само Forming→Trial, Trial→Deciding, Deciding→Permanent. Прескачане на фаза, връщане назад, повторен същ статус и Disbanded (в двете посоки) → `INVALID_STATE`.
- `TrialPhaseHandler.cs` — трите фазови прехода: само founder (`FORBIDDEN`), липсваща маса → `NOT_FOUND`, невалиден преход → `INVALID_STATE`. При влизане в Deciding праща `STAY_OR_LEAVE_PROMPT` през `INotifier` към активните членове БЕЗ founder-а (той е задал въпроса).
- `StayOrLeaveHandler.cs` — отговорът НЕ е вот (Решения 18.07): `stay=false` деактивира членството ВЕДНАГА (+`LeftAt`), `stay=true` не записва нищо (няма кворум за броене). Извън фаза Deciding → `INVALID_STATE`; не-член → `FORBIDDEN`; founder → `FORBIDDEN` (А5 exodus е отделен, паркиран flow — масата не остава без основател мълчаливо).
- `TrialLifecycleMutations.cs` — `startTrial` / `startDecidingPhase` / `finalizeDeciding` / `stayOrLeave` по mutation conventions, точно по contracts/schema.graphql. Регистрация през source generator-а — Program.cs непипнат.
- `TrialLifecycleNotifications.cs` — типът `STAY_OR_LEAVE_PROMPT`.

**Тестове:**
- Unit (наследен RED спек от предишния опит, оставен непроменен): 6 theory групи върху преходния валидатор.
- Integration (нови, Testcontainers): пълната пътека Forming→Trial→Deciding→stayOrLeave(false)→finalizeDeciding→Permanent с проверка кой остава активен; нотификациите отиват при членовете, не при founder-а; „оставам" не създава решение/глас; невалиден преход, не-founder, не-член, липсваща маса, повторен startTrial, founder+stayOrLeave.
- `dotnet test backend/PartyUp.slnx` — **121 unit + 178 integration, 0 fail**.

**Обхват:** само `Features/Lifecycle/Trial/**` + собствените тестови папки. Domain/Common/Program.cs/csproj/contracts непипнати.


## Task 16 — feat(candidacy): add pullCandidate mutation opening admission decision or founder fast-path

**Repo:** partyup · **Lane:** be-candidacy-pull · **Commit:** `1f6199e`

### Контекст
Итерацията е RESUME на прекъснат опит (quota exceeded). Worktree-то съдържаше ПЪЛНИЯ слайс като uncommitted untracked файлове. Подходът беше диагностичен, не пренаписващ: прочетох предшественика, сверих го срещу `contracts/schema.graphql` и §4/§7б червените линии, пуснах suite-а — всичко зелено → запазих кода и го комитнах.

### Какво има в слайса
- **`PullCandidateHandler`** — PULL моделът (А): масата дърпа, играчът не кандидатства. Реди проверките по приоритет: маса → `NOT_FOUND`; викащият активен член → `FORBIDDEN` (правата ПРЕДИ причината — извън масата дори отказът не е чужда работа); после `NOT_LISTED` (бордът е единственият вход), `ALREADY_MEMBER`, `ALREADY_PULLED`.
- **Двете пътеки на приема** — коя важи НЕ се решава тук: пита се `DecisionService.ShouldUseFounderApproveAsync` (merged 14), за да не съществуват две копия на праговата логика. Лек прием (А6/А7) → `ApprovedForContact` без решение/чат/вот, и дърпа САМО founder-ът (член → именуваната `FOUNDER_APPROVES_MODE`, не глухо „нямаш право"). Пълна церемония → `DecisionService.OpenAsync(Admission, subject=кандидата)` → `Discussing` + `DecisionId`.
- **`CandidacyService`** (public, за таскове 17/18) — `SyncManyFromDecisionsAsync`: изходът на вота живее върху решението и се пренася върху кандидатурата ПРИ ЧЕТЕНЕ, така зоната на решенията остава непипната и не знае, че кандидатури съществуват. Approved → `ApprovedForContact`; Rejected → `Rejected` + ЕДНА неутрална `CANDIDACY_CLOSED` нотификация. Идемпотентно по конструкция (пипа само `Discussing`), статусът се записва ПРЕДИ известията.
- **`CandidacyQueries`** — `candidacy(id)` / `myTableCandidacies(tableId)`, видими само отвътре на масата (кандидатът и външният получават `null`/празен списък — груповите работи не са витрина, А2). Правото се проверява ПРЕДИ sync-а, за да не задвижва чуждо четене чужда кандидатура.
- **`CandidacyType` + `CandidacyDataLoaders`** — домейн ентитито Е GraphQL типът (без паралелен DTO); FK-тата и EF навигациите са `Ignore`-нати, полетата минават през DataLoader-и срещу N+1 (§2а.4).

### Червени линии — сверени
- Обхватът е точно `files` списъкът: САМО `Features/Candidacies/Pull/**` + огледалните тестове. `Program.cs` / `csproj` / `Domain` / `Common` / `contracts/` / `frontend/` — НЕПИПНАТИ (§7а.2). Регистрацията е автоматична през source generator-а.
- `[ObjectType<Query>]`, НЕ `[QueryType]` (§7а.5 — иначе полетата изчезват от схемата БЕЗШУМНО).
- Result pattern навсякъде; очакваните провали са стойности, не exceptions (§4.5). `AsNoTracking()` + изрични Select проекции.
- Кодът съвпада с контракта: `PullCandidateInput`/`PullCandidatePayload{candidacy,errors}`, `Candidacy{decision,contactChat,resolvedAt}` — без разминаване (§7б.11). Никакви секрети, никакви build артефакти в commit-а.
- Неутралността е ПРОВЕРИМА в теста: payload-ът на `CANDIDACY_CLOSED` не съдържа нито масата, нито гласувалите.

### Тестове
`dotnet test backend/PartyUp.slnx` → **101 unit + 140 integration, 0 failed, 0 skipped**. 15 от интеграционните са на този слайс: двете пътеки на приема, авто-spawn-натият чат с точния състав на дължимите гласове (кандидатът отвън), четирите типизирани грешки, „листването остава на борда за други маси", единодушие → `ApprovedForContact`, отказ → неутрално затваряне, известието само веднъж, скритост от кандидата/външния.


## Task #15 — feat(decisions): add stale voter founder alert and snooze mutation

**Repo:** partyup (backend, lane be-decision-alerts) · **Branch:** ralph/task-15 · **Commit:** 3d53f7a

### Какво е направено
- **RECON:** прочетени merged Decision API-то от таск 14 (DecisionService/DecisionDataLoaders/GroupDecisionType), party-up.md А4 дословно и секциите на контракта за `staleDecisions`/`snoozeDecision`.
- **RED:** `backend/tests/PartyUp.IntegrationTests/Features/DecisionAlerts/StaleDecisionTests.cs` — 17 спека, всичките червени с правилната причина (`The field 'staleDecisions' does not exist on the type 'Query'`).
- **GREEN:** `backend/src/PartyUp.Api/Features/DecisionAlerts/` — `StaleDecisionRules` (3 дни праг / 3 дни таван на отлагането / `DECISION_STALE`), `StaleDecisionFinder` (мързеливо откриване при заявка, без hosted service; едно запитване за имената на негласувалите за ВСИЧКИ решения — без N+1), `StaleDecisionQueries` (`[ObjectType<Query>]`, §7а.5), `SnoozeDecisionHandler` + `SnoozeDecisionMutations` (mutation conventions, `PayloadFieldName = "decision"`).

### Продуктови решения
- **А4 границата се пази от тест:** алармата САМО стартира процеса — спек `StaleDecisions_NeverKicksAnyoneByItself` доказва, че членството остава активно и никакво Kick решение не се отваря.
- **Алармата звъни ВЕДНЪЖ на решение** (панелът се отваря по десет пъти на ден); отлагането я пре-зарежда, тоест след изтекъл snooze тя звъни отново.
- **`until` е изричен вход, не фиксирана стъпка** — така го иска контрактът; продуктовите „+3 дни" от notes-а остават като ГРАНИЦА на избора (минал момент или > 3 дни → `VALIDATION`).
- Чужд поглед към `staleDecisions` получава празен списък, а не грешка (дискретността от А2).

### Проверки
- `dotnet test backend/PartyUp.slnx` → **235/235 зелени** (101 unit + 134 integration, Testcontainers).
- Схемата, експортирана от кода (във временен файл), съвпада точка по точка с `contracts/schema.graphql`: `staleDecisions: [GroupDecision!]!`, `SnoozeDecisionInput { decisionId, until }`, `SnoozeDecisionPayload { decision, errors }`, `union SnoozeDecisionError = DomainError`.
- Червени линии: без секрети, `contracts/` непипнат, Program.cs/csproj/Domain/Common непипнати, diff-ът е строго в `Features/DecisionAlerts/**` + тестовете му.


## Task #19 — feat(chat): add sendMessage mutation, chat queries and topic event publish

**Repo:** partyup · **Lane:** be-chat-messaging · **Branch:** ralph/task-19 · **Commit:** 85e9adc

### Какво е направено
Нов vertical slice `Features/Chats/Messaging/` (Е.6) — целият чат обмен без subscription resolver-а (той е таск 20).

- **`sendMessage(chatId, text)`** — mutation conventions + Result pattern. Редът на проверките е нарочен: сесия → чатът съществува (`NOT_FOUND`) → участник ли съм (`NOT_PARTICIPANT`) → текстът (`VALIDATION`, trim + 1–2000, колкото е и колоната). Правото се гледа ПРЕДИ съдържанието — какво е написал човек без право да пише е без значение (А2).
- **Publish на `chat:<chatId>`** през `ITopicEventSender`, СЛЕД записа в базата. Името на темата живее в `ChatTopics` — то е контракт между този таск и таск 20, който се абонира за същия низ.
- **`INotifier` NEW_MESSAGE** към ОСТАНАЛИТЕ участници (payload: chatId/messageId/senderUserId — къде и кое, не готов текст). На подателя не се праща нищо.
- **`myChats`** — подредба по ПОСЛЕДНО СЪОБЩЕНИЕ (чат без реплики пада по CreatedAt), **`chat(id)`** — нишката; и двете видими само за участник, чуждият чат връща null, а не грешка.
- **Типовете:** `Chat`/`Message` са домейн ентитита с скрити навигации (`ChatParticipant.User` → Identity ентитито би изсипало passwordHash в публичната схема). `participants`/`sender`/`lastMessage`/`table` минават през 4 DataLoader-а — всяко от тях виси на всеки ред от `myChats`, тоест наивен resolver = N+1 (§2а.4). `messages` е с offset пагинация, страницата се брои от най-новото назад и се връща в четивен ред.

### Тестове
22 нови integration теста (Testcontainers), вкл. отделен тест че publish-ът стига до `chat:<chatId>` — иначе счупена тема би останала невидима и за двата таска. Пълен BE suite: **90 unit + 126 integration, 0 червени**.

### Бележки
- `sender`/`participants` връщат СЪЩИЯ контрактен `User` тип, който въведе LFG бордът — паралелен запис би се регистрирал под същото име и би съборил схемата.
- Program.cs/csproj/Domain/Common са НЕПИПНАТИ — слайсът се регистрира сам през source generator-а (§7а.2).
- `contracts/schema.graphql` не е пипан (§3.1); `messages(skip/take)` е добавка спрямо дизайнерската схема — реконсилира се в таск 41.


## Task #13 - feat(lfg): add readonly tables showcase query with party composition

**Repo:** partyup (backend) - branch `ralph/task-13`, commit `3f3848d`

### Какво стана
Заявката/витрината си беше написана от предишния опит и е коректна - счупен беше **интегрираният** свят, не слайсът. Гейтът върна 111 от 112 интеграционни теста червени, включително `Foundation` тестовете, което е подписът на **счупен старт на хоста**, а не на бъгава фича. Причината, дословно от Hot Chocolate:

```
The name `User` was already registered by another type.
(HotChocolate.Types.ObjectType<PartyUp.Api.Features.Lfg.Showcase.User>)
```

Двама паралелни агента са стигнали до един и същи извод независимо: контрактният `type User` не бива да е Identity ентитито (иначе `passwordHash`/`securityStamp` влизат в ПУБЛИЧНАТА схема), значи трябва тесен запис. Таск #11 (`Features/Lfg/Board/User.cs`) го е написал и е мърджнат пръв; таск #13 е написал втори, свой. В C# това са два различни типа в два namespace-а и компилаторът мълчи - **GraphQL името обаче е глобално**, така че схемата пада още при warmup-а и с нея цялото приложение.

### Поправка (в границите на `Features/Lfg/Showcase/**`)
- Изтрит `Showcase/User.cs`; трите файла, които го ползваха, минават през `using User = PartyUp.Api.Features.Lfg.Board.User;`.
- `User.From(id, profile)` → частен `Publicly(id, profile)` в `ShowcaseDataLoaders` (типът на Board изнася `Empty(id)`, не `From`); поведението е същото - липсващ профил дава ПРАЗЕН профил, защото контрактът обявява `profile: UserProfile!` и `null` тук би съборил цялата заявка вместо да покаже един беден ред.
- Alias, а не `using` на цялото пространство: заемката е ЕДИН тип и се вижда на реда. Съзнателна отстъпка от §7б.2 („слайс не reference-ва чужд тип") - дублирането е Блокер (счупена схема), alias-ът е Важно, а трети вариант в рамките на моя обхват няма: собственик на типа е Board, защото витрината е втората, която го поиска.

### Верификация
Worktree-ът е от преди #11 и #9, тоест сам по себе си НЕ възпроизвежда провала. Затова тестовете вървяха срещу **истинското интегрирано състояние**: единайсетте файла, с които main е избягал напред (`Lfg/Board/**`, `Tables/Settings/**` + спековете им), бяха положени в worktree-а като untracked overlay, пуснат беше целият suite, после overlay-ът беше изчистен ПРЕДИ коммита (`git clean -fd` по изрични пътища; `git status` показва само моите 4 файла).

- `dotnet test backend/PartyUp.slnx` → **90 unit + 112 integration, 0 failed** (същите 112, които гейтът върна червени).
- Преди поправката, същият overlay: `Hello_IsServedThroughTheRealPipeline` пада с горната `SchemaException` - тоест диагнозата е доказана, не предположена.
- `schema export` към временен път ИЗВЪН репото: `type User`, `input TablesShowcaseFilter`, `tablesShowcase(filter:)`, `table(id:)` и `TableMembership.user` съвпадат поле по поле с `contracts/schema.graphql` (който остава непипнат - §3.1, таск 41 го притежава).

### ⚠ За мърджъра
Клонът НАРОЧНО не компилира самостоятелно - `User` вече живее в мърджнатия Board слайс. Мърджва се върху main (където е зелен), не се билдва изолирано.


## Task 14 — feat(decisions): add group decision primitive with unanimous voting, threshold rule and auto-spawned chat

**Repo:** partyup · **Lane:** be-decisions · **Commit:** `59449a9`

### Какво е направено
- **RED:** unit спекове за единодушието (`VoteTallyTests`) и за прага/церемонията (`AdmissionCeremonyTests`); интеграционни спекове за откриването на решение с авто-чат (`DecisionServiceTests`) и за вота през GraphQL (`CastVoteTests`). Червени по правилната причина — слайсът не съществуваше.
- **GREEN — `Features/Decisions/`:**
  - `VoteTally.Evaluate(dueVoterIds, votes)` — ЧИСТА функция: всички дължими с „да" → `Approved`; едно „не" → `Rejected` НЕЗАБАВНО; гласове от недължими (изключения при kick, външни хора) не се броят; празен състав остава `Open`.
  - `DecisionService.OpenAsync` — GroupDecision + АВТО-spawn групов `Chat` с участници активните членове минус `excludedUserId` (А2: чатът се ражда заедно с темата; субектът стои отвън). `DueVoterIdsAsync` се чете при ВСЯКО броене, не се снима при откриване — напусналият не блокира решението.
  - `DecisionService.ShouldUseFounderApprove(status, mode, activeMembers)` — праговата логика на ЕДНО място (таск 16 пита оттук): лек прием при режим „founder одобрява" (А7), под прага 4 (А2) ИЛИ докато масата не е `Permanent` (А6 дословно: „церемонията се включва чак при постоянна група").
  - `CastVoteHandler` + `castVote` mutation по Result pattern: `NOT_FOUND`, `INVALID_STATE` (затворено решение), `FORBIDDEN` (недължим глас — външен или изключен при kick, А4), `ALREADY_VOTED` (вотът е КРАЕН, не се преиграва).
  - `groupDecision(id)` query — видимо САМО за активните членове на масата (чуждият поглед получава `null`, не грешка); проекция + `AsNoTracking`.
  - GraphQL типове: `GroupDecisionType` (table/chat/subject/excludedUser/votes/**pendingVoters** — всички през DataLoader-и заради списъчното четене от таск 15), `VoteType` (`voter: User!` — вотът е ЯВЕН, А2), `ChatGraphQLType` (първото изнасяне на чата в схемата; скрити са навигациите, зад които стои Identity ентитито).
- **DONE:** `dotnet test backend/PartyUp.slnx` → 101 unit + 103 integration, 0 fail.

### Решения по пътя
- **Прагът включва и жизнения цикъл.** Notes-ът на таска дава само „под 4 ИЛИ FounderApproves", но А6 е изричен („прием в пробната фаза: лек — церемонията се включва чак при постоянна група") и contracts коментарът също казва „below the admission threshold / **in TRIAL**". Затова сигнатурата е `(TableStatus, AdmissionMode, int)` — статусът е видим за таск 16, който ще сее `Permanent` маси, когато иска реален вот.
- **Публичният `User` тип се преизползва** от слайса на борда, вместо да се регистрира втори със същото име (схемата не би се построила). Същото важи за `Chat`: тук влиза минималната безопасна регистрация, а `participants`/`messages`/`lastMessage` ги добавя таск 19, който ги притежава.
- **`pendingVoters` е част от типа**, не отделна заявка — А2 прозрачността („виси заради Гошо") е и входът на алармата от А4, така таск 15 няма да си преписва логиката.

### Червени линии
✅ Никакви секрети · ✅ `contracts/schema.graphql` непипнат · ✅ нищо извън `Features/Decisions/**` + тестовите му папки (Program.cs / csproj / Domain / Common — недокоснати) · ✅ Result pattern, никакви exceptions за очакван провал · ✅ `AsNoTracking` + DataLoader-и (без N+1)


## Task #9 — feat(tables): add updateTableSettings mutation restricted to the founder

**Repo:** partyup · **Lane:** be-table-settings · **Commit:** a8e9a81

### Какво е направено

Вертикален слайс `Features/Tables/Settings/` (нищо извън него + собствената му тестова папка):

- **`UpdateTableSettingsMutations`** — `[MutationType]` с разгънати аргументи, точно по `UpdateTableSettingsInput` от контракта; `PayloadFieldName = "table"`. Регистрира се сам през source generator-а, Program.cs остава непипнат.
- **`TableSettingsPatch`** — входът като стойност, ЧАСТИЧЕН по конструкция: `null` = „не го пипай" (същата конвенция като merged `setTableListing`), празен низ = „изчисти свободния текст". Умишлено НЯМА режим на изгонване — kick-ът е ВИНАГИ групово решение (А7), затова не е настройка.
- **`TableSettingsValidator`** — валидира САМО подаденото и го канонизира (език `"EN "` → `"en"`, тагове trim/dedupe, `OneShotAt` → UTC заради `timestamptz`). Границите повтарят тези на създаването нарочно: слайс не reference-ва чужд слайс (§7б.2), а правилата на масата не бива да зависят от това през коя операция е минала.
- **`UpdateTableSettingsHandler`** — NOT_FOUND → FORBIDDEN (проверява ОСНОВАТЕЛСТВО, не членство: ролята е постоянна) → валидация → времеви режим → слотове. Подадена дата значи „масата Е събитие" и графикът пада със същата заявка (Б: смяната на режим е едно решение, не двустъпков ритуал); дата И график наведнъж е единствената истинска двусмислица → VALIDATION.
- **Слотове под състава = CONFLICT**, не VALIDATION: числото е законно, но масата вече е приела повече хора — настройка няма право да предизвика изгонване мълчаливо (А7). Броят е на АКТИВНИТЕ членства; напусналият не държи слот.
- **`TableSchemaGuard`** — слайсът е първият, който изнася `Table` в схемата на този клон, а инференцията следва `Memberships → TableMembership.User` и изнася ЦЯЛОТО Identity ентити публично (`passwordHash`, `securityStamp`). Навигацията е скрита; дублираният `Ignore` при merge е идемпотентен и никой слайс не бива да разчита на реда на появяване.

### Тестове

TDD: 14 интеграционни спека през Testcontainers написани ПЪРВО и потвърдени червени по правилната причина (`The field 'updateTableSettings' does not exist on the type 'Mutation'`), после зелени. Покриват: пълна смяна + канонизация, непипнати пропуснати полета, смяна на церемонията (А7), FORBIDDEN за член и без сесия, NOT_FOUND, CONFLICT при свиване под състава, свиване точно до състава, игнориране на напусналите, смяна към one-shot, двата режима наведнъж, изчистен график без дата, празно име, слотове извън диапазона.

**Пълен BE suite: 63 unit + 57 integration — зелени.** Frontend не е пипан.


## [2026-08-18 15:20] - Task #11: feat(lfg): add lfgBoard query with format, language, system and DM filters

**Status:** ✅ Complete

**TDD Phase:** RECON → RED → GREEN → DONE

**Problem:** Бордът (А3) е query върху АКТИВНИТЕ листвания, не отделна структура — листва ХОРА, защото масите са активната страна и дърпат оттам (PULL моделът). Две предишни итерации бяха прекъснати: кодът беше написан, но НИКОГА не беше комитнат (стоеше само като untracked файлове в worktree-то).

**What was done:**
- RED: `LfgBoardTests` — 10 integration теста върху seed от 5 души (4 на борда + 1 свалила се): пълен борд най-нови първо, скрити неактивни, профилен снапшот, формат в двете посоки, език, система, onlyDm, комбиниране с И, публичен достъп без сесия.
- GREEN: `Features/Lfg/Board/` — `LfgBoardQueries` (`[ObjectType<Query>]` по §7а.5, join listing↔profile, `AsNoTracking` + `Select` проекция по §2а.4), `LfgBoardFilter` + изричен `LfgBoardFilterType`, `PlayerListingType` (профилът през DataLoader срещу N+1), тесен `User` запис вместо Identity ентитито.
- Ключова находка на предшественика, запазена: Hot Chocolate лепи суфикса „Input" СЛЕД `[GraphQLName]`, тоест типът се регистрира като `LfgBoardFilterInput` и се разминава с контракта. Изричен `InputObjectType<T>` с `descriptor.Name("LfgBoardFilter")` заобикаля конвенцията.
- Семантиката на „и двете": `Both` не ограничава в НИТО една посока — нито когато търсещият е гъвкав, нито когато листнатият е. `onlyDm: false` също не ограничава, иначе бордът би скрил всички DM-и.

**Verification:**
- `LfgBoardTests` → 10/10 pass
- `dotnet test backend/PartyUp.slnx` → 86 unit + 66 integration, 0 failed, 0 skipped
- build → 0 errors (2 pre-existing NU1903 warnings от SSH.NET, вън от обхвата)

**Files modified:**
- backend/src/PartyUp.Api/Features/Lfg/Board/LfgBoardQueries.cs
- backend/src/PartyUp.Api/Features/Lfg/Board/LfgBoardFilter.cs
- backend/src/PartyUp.Api/Features/Lfg/Board/PlayerListingType.cs
- backend/src/PartyUp.Api/Features/Lfg/Board/User.cs
- backend/tests/PartyUp.IntegrationTests/Features/Lfg/Board/LfgBoardTests.cs

**Git commit:** `975851d` — `feat(lfg): add lfgBoard query with format, language, system and DM filters`

---


## Task #12 - feat(lfg): add publish and unpublish listing mutations with auto-unpublish service

**Repo:** partyup | **Lane:** be-lfg-publish | **Commit:** `f550817`

### What was done

This was a RETRY of an interrupted run. The retry report's log tail was stale (it described a `quests.spec.js` task from another repo entirely), so the worktree was inspected directly: `git status` showed the previous agent had built the whole slice but **never committed it** - `backend/src/PartyUp.Api/Features/Lfg/` and `backend/tests/PartyUp.IntegrationTests/Features/Lfg/` sat untracked, with zero commits on the branch. Per continuation mode the existing work was kept and verified, not rewritten.

**Slice `Features/Lfg/Publish/` (4 files):**
- `PublishListingHandler.cs` - profile gate (`DisplayName` non-blank **and** (`IsDm` || `IsPlayer`)) -> `PROFILE_INCOMPLETE` so the FE can route to the profile instead of showing an error. Idempotent: an existing listing is re-activated in place rather than duplicated (a duplicate = the same person twice on the board).
- `UnpublishService.cs` - **public** entry `UnpublishAsync(db, userId, ct)`, the single agreed cross-slice door required by the task notes so task 18 can auto-unpublish on final accept. Idempotent and failure-free; keeps the row (listing is a toggle, not a delete, so `createdAt` survives re-publishing).
- `MyListingMutations.cs` - both argument-less mutations per the contract, with explicit `PayloadFieldName = "listing"` (convention would otherwise emit `playerListing`). Anonymous callers get `FORBIDDEN` as a Result value, not an exception (§4.5).
- `PlayerListingType.cs` - binds the domain entity directly (no parallel DTO), ignoring `UserId` and the `User` navigation so Identity's `passwordHash`/`securityStamp` cannot leak into the public schema via auto-inference.

**Spec `MyListingTests.cs` - 14 integration tests (Testcontainers):** empty/nameless/role-less profile -> `PROFILE_INCOMPLETE` + nothing listed; DM-only is enough; publish -> active listing persisted; double publish -> same id, one row; unpublish -> inactive but row kept; double unpublish and never-published unpublish -> idempotent no-ops; re-publish reactivates the same id; both mutations `FORBIDDEN` without a session; and `UnpublishService` exercised directly for the accept flow (both the hit and the no-op path).

### Verification

- `dotnet test backend/PartyUp.slnx` -> **156 passed / 0 failed** (86 unit + 70 integration, 14 of them new).
- Targeted `--filter MyListingTests` -> 14/14 green.
- Assertions confirmed non-vacuous: the `Data()` helper asserts there are no top-level GraphQL errors, so these tests could not pass if the mutations were missing from the schema.
- Scope clean: `git diff HEAD --stat` empty - only the 5 new in-scope files were added. `Program.cs`, `PartyUp.Api.csproj`, `Domain/`, `Common/` and `contracts/schema.graphql` were all left untouched (§7а.2; the contract is re-exported by task 41).


## Task #10 — feat(tables): add table listing toggle with GM slot flag and auto-delist service

**Repo:** partyup (`backend/`) · **Lane:** be-table-listing · **Commit:** `8a84eed`

### Какво е направено

**RED → GREEN (TDD).** Първо спековете, потвърдено червени (слайсът не съществува), после минималната имплементация.

- `Features/Tables/Listing/SetTableListingMutations.cs` — `[MutationType]` + `[UseMutationConvention(PayloadFieldName = "table")]`; аргументите са разгънати, за да произведе конвенцията точно `SetTableListingInput` от контракта. Регистрацията е автоматична през `AddPartyUpTypes()` — Program.cs остава непипнат.
- `Features/Tables/Listing/SetTableListingHandler.cs` — `NOT_FOUND` за липсваща маса, `FORBIDDEN` за не-founder (А7: обявата е негова настройка; ролята е постоянна, проверява се `FounderId`), иначе вдига/сваля флаговете. Всичко през Result, нула exceptions.
- `Features/Tables/Listing/TableDelistService.cs` — public static, за да го вика таск 18 без DI регистрация и без reference към чужд slice: `ShouldDelist(listingActive, activeMembers, slotsTotal)` (чиста функция, ≥ не ==) + `DelistIfFullAsync(db, tableId, ct)`.

### Решения

- **`seekingGm` е nullable в контракта → пропуснатата стойност значи „не го пипай", не „изгаси го".** Ядка №3: няма отделна GM витрина, half-match опашката са масите със `seekingGm`, така че двата флага се вдигат и падат независимо.
- **Авто-свалянето брои САМО активните членства** — напусналият не държи слот, иначе обявата пада на призрачен състав.
- **Липсваща маса / вече свалена обява = no-op, не грешка.** Викащият (таск 18) е вътрешен код в средата на друга операция, а не потребителско намерение (§4.5).
- Не е въведено CONFLICT правило при вдигане на обява на пълна маса — спеката на таска не го иска, а измислени кодове извън контракта са по-скъпи от липсващи.

### Тестове

- Unit (`UnitTests/Features/Tables/Listing/`): 4 спека на `ShouldDelist` — пълна, свободен слот, пресилен състав, вече свалена обява. Без Docker, чиста функция.
- Integration (`IntegrationTests/Features/Tables/Listing/`): 10 спека — вдигане на двата флага, сваляне, пропуснат `seekingGm`, member → FORBIDDEN, без сесия → FORBIDDEN, непозната маса → NOT_FOUND, delist при пълна/непълна маса, игнориране на напусналите, no-op при свалена/липсваща.
- `dotnet test backend/PartyUp.slnx` → **67 unit + 57 integration, 0 failed**.

### Обхват

Само `Features/Tables/Listing/**` + двете тестови папки. Domain/Common/Program.cs/csproj/contracts — непипнати. FE — непипнат (без `npm install`, за да не мърда `package-lock.json`).


## [2026-08-18 14:05] - Task #8: feat(tables): add createTable mutation with full table profile and founder membership

**Status:** ✅ Complete

**TDD Phase:** RECON → RED → GREEN → DONE

**Problem:** „Създай маса" е едната от двете равностойни входни функционалности (А3, founder flow). Масата се ражда с ПЪЛНИЯ си профил (Е.3) и веднага с членството на създателя — маса без founder не съществува дори за миг. Двата времеви режима на Б (събитие с дата ИЛИ постоянна група със свой график) са взаимно изключващи се и точно един от тях е задължителен.

**Забележка (continuation):** таскът беше прекъснат два пъти от quota limit. Worktree-то съдържаше вече комитната работа на предшественика (`495fe31`, чисто работно дърво) — тя е ВЕРИФИЦИРАНА, а не пренаписана; липсваше само result файлът. Нов commit не се наложи.

**What was done:**
- RECON: merged таск 1 (`Domain.Table`/`TableMembership`, `TableStatus`/`MembershipRole`/`AdmissionMode`/`GameFormat`, `PartyUpDbContext`, `Result`/`DomainError`, `CurrentUser.GetUserId`), merged таск 2 (`createTable(input: CreateTableInput!): CreateTablePayload!` + `input CreateTableInput`), слайсовете на 5/6 като образец за mutation конвенциите, structure §2а (vertical slices, Result pattern), §4.5, §7а.2/§7а.4 и party-up.md А3/А6/А7, Б, Е.3, Е.8.
- RED: 8 интеграционни спека (`Features/Tables/CreateTable/CreateTableTests.cs`) срещу истинския пайплайн — happy path с целия профил + `FORMING` + `GROUP_DECISION` дефолт + `listingActive:false`; създателят като `Founder` membership с `IsGm` от входа; отворен GM слот при `founderIsGm:false`; постоянна група със свой график; слотове = 1 → VALIDATION и НИЩО записано; без име → VALIDATION; и двата времеви режима → VALIDATION; нито един времеви режим → VALIDATION; без сесия → FORBIDDEN. Плюс 16 unit спека на валидатора (`CreateTableValidatorTests.cs`) — граници 2/10, дължини 120/80/8, канонизация, UTC нормализация.
- GREEN: `Features/Tables/CreateTable/` — `TableDraft` (входът като една стойност, откъснат от GraphQL слоя, за да е валидаторът тестваем без Docker); `CreateTableValidator` (име/система/език, слотове 2–10, ТОЧНО един времеви режим, канонизация: trim, lowercase език, дедуп на style таговете, празен свободен текст → null, `OneShotAt` → UTC защото Postgres `timestamptz` не приема отместване ≠ 0, `OneShotPlace` отпада без събитие); `CreateTableHandler` (валидация → проверка за съществуващ founder като СТОЙНОСТ вместо raw FK exception → `Table` със `Status=Forming` + `TableMembership{Role=Founder, IsGm}` в една `SaveChangesAsync`); `CreateTableMutations` (`[MutationType]`, разгънати аргументи → conventions ги събират точно в `CreateTableInput`, `FieldResult<Table, DomainError>`); `TableGraphQLType`.

**Решения по обхвата:**
- `AdmissionMode` дефолт `GroupDecision` (А7) — прагът под 4 така или иначе дава founder-approve, затова дефолтът не е загуба.
- `ListingActive` остава `false`: „търсим хора" е ОТДЕЛЕН toggle (А3, таск 10), създаването на маса не е обява.
- `Table.Memberships` е скрито през дескриптора: инференцията я следва до `TableMembership.User` и изнася ЦЯЛОТО Identity ентити (`passwordHash`, `securityStamp`, lockout полетата) в публичната схема. Съставът по контракт е `members` през проекция към `User` (таск 13).
- Незадължителните флагове са `bool?` — контрактът ги обявява nullable; липсващ флаг значи „не".

**Verification:**
- `dotnet test backend/PartyUp.slnx --nologo -v q` → PartyUp.UnitTests **55/55**, PartyUp.IntegrationTests **34/34**, 0 skipped, 0 failed
- `contracts/schema.graphql` (`CreateTableInput`, ред 595–614) съвпада поле по поле с аргументите на мутацията — контрактът НЕ е пипан (червена линия §4.2)
- Обхват: пипнати са само `Features/Tables/CreateTable/**` и двете тестови папки. `Program.cs`, `PartyUp.Api.csproj`, `Domain/`, `Common/`, `contracts/`, `frontend/` и паралелните `Tables/Settings` + `Tables/Listing` — непипнати
- Без секрети в diff-а; работното дърво е чисто, без untracked артефакти

**Files modified:**
- `backend/src/PartyUp.Api/Features/Tables/CreateTable/TableDraft.cs`
- `backend/src/PartyUp.Api/Features/Tables/CreateTable/CreateTableValidator.cs`
- `backend/src/PartyUp.Api/Features/Tables/CreateTable/CreateTableHandler.cs`
- `backend/src/PartyUp.Api/Features/Tables/CreateTable/CreateTableMutations.cs`
- `backend/src/PartyUp.Api/Features/Tables/CreateTable/TableGraphQLType.cs`
- `backend/tests/PartyUp.UnitTests/Features/Tables/CreateTable/CreateTableValidatorTests.cs`
- `backend/tests/PartyUp.IntegrationTests/Features/Tables/CreateTable/CreateTableTests.cs`

**Git commit:** `495fe31` — `feat(tables): add createTable mutation with full table profile and founder membership`

---


## [2026-08-17 18:20] - Task #7: feat(profile): add myTables query listing memberships with table snapshots

**Status:** ✅ Complete

**TDD Phase:** RECON → RED → GREEN → DONE

**Problem:** „Моите маси" (А3) е следствие от мултичленството: един и същ човек може да е founder+GM на едната маса и обикновен играч на другата, затова екранът листва ЧЛЕНСТВА, а не маси. Чист query таск — първият, който изкарва `Table`/`TableMembership` в схемата.

**What was done:**
- RECON: merged таск 1 (Domain.Table/TableMembership, PartyUpDbContext, CurrentUser.GetUserId), merged таск 2 (`myTables: [TableMembership!]!`, `type Table`, `type TableMembership`), слайсът на таск 5 като образец за конвенциите, structure §2а.4 (read дисциплина) и §7а.5 (`[ObjectType<Query>]`, НЕ `[QueryType]`).
- RED: 4 интеграционни спека (`Features/MyTables/MyTablesTests.cs`) — активните членства с ролите, последно joined първо (2 активни + 1 напусната → 2); table снапшотът с брой АКТИВНИ членове (напусналият не държи слот); чужди членства не изтичат; без сесия → празен списък. Червени по правилната причина: `The field 'myTables' does not exist on the type 'Query'`.
- GREEN: `Features/MyTables/` — `MyTablesQueries` (`[ObjectType<Query>]`, AsNoTracking + изрична проекция право в GraphQL типа, `Where(Active)` + `OrderByDescending(JoinedAt)`); `TableMembershipType` и `TableType` (`[ObjectType<T>]` върху ДОМЕЙН ентитата — не собствени record-и, иначе схемата би получила втори тип със същото име при слайсовете 8/9/13); `MyTablesDataLoaders.ActiveMemberCount` (source-generated `[DataLoader]`) захранва изчислимото `slotsFilled` с един SQL за целия списък (§2а.4, срещу N+1).

**Решения по обхвата (за таск 41):**
- Скрити са полетата, които контрактът няма и които биха изтекли: `TableMembership.User` стои зад Identity ентитито `AppUser` — авто-инференцията му би сложила `passwordHash`/`securityStamp` в публичната схема; също `TableId`/`UserId`/`Table.FounderId`/`Table.Memberships`.
- Контрактните `TableMembership.user`, `Table.founder` и `Table.members` изискват публичния `User` тип, който идва със слайса на витрината (таск 13) — оттам и липсват тук. За „моите маси" няма смислова загуба: членството е винаги на викащия.
- `table: Table!` е изрично не-nullable през дескриптора (навигацията в ентитито е nullable, членство без маса не съществува).

**Verification:**
- `dotnet test backend/PartyUp.slnx` → PartyUp.UnitTests **20/20**, PartyUp.IntegrationTests **20/20** (беше 16 — четирите нови спека), 0 skipped
- `schema export` (в TEMP, `contracts/` НЕ е пипано — червена линия §4.2): `myTables: [TableMembership!]!`, `type TableMembership { id table role isGm active joinedAt leftAt }`, `type Table { … slotsFilled … }` — съвпада с контракта поле по поле (без `founder`/`members`, виж по-горе)
- `frontend/`, `contracts/`, `Program.cs`, `csproj`, `Domain/`, `Common/` — непипнати

**Files modified:**
- backend/src/PartyUp.Api/Features/MyTables/MyTablesQueries.cs
- backend/src/PartyUp.Api/Features/MyTables/TableMembershipType.cs
- backend/src/PartyUp.Api/Features/MyTables/TableType.cs
- backend/src/PartyUp.Api/Features/MyTables/MyTablesDataLoaders.cs
- backend/tests/PartyUp.IntegrationTests/Features/MyTables/MyTablesTests.cs

**Git commit:** `5254294` — `feat(profile): add myTables query listing memberships with table snapshots`

**Note за следващите таскове (8/9/10/13):** `Table` и `TableMembership` ВЕЧЕ са в схемата като разширения на домейн ентитата (`[ObjectType<Domain.Table>]`). Добавяй полета към СЪЩИТЕ типове от своята папка (`founder`, `members`, …) — собствен C# тип с име `Table` би дал „name already registered". `slotsFilled` вече съществува, не го дублирай. Генераторът кръщава DataLoader класа на метода (`GetActiveMemberCountAsync` → `ActiveMemberCountDataLoader`), затова контейнерният клас трябва да се казва другояче, иначе билдът пада с CS0708.

---


## Task #4 — feat(auth): add OAuth challenge endpoints, email-keyed user provisioning and me query

**Repo:** partyup · **Lane:** be-auth · **Branch:** ralph/task-4 · **Commit:** `d591ce7`

### What was wrong
The previous attempt shipped a complete, correct `Features/Auth/` slice but the post-merge verify gate came back red with **42 of 43 integration tests failing** — including tests that have nothing to do with auth (`DomainModelTests`, `NotifierTests`, `GraphQLPipelineTests`, `ProfileTests`). That breadth was the tell: the failure was not in a resolver, it was the application refusing to boot.

Reconstructing the merged tree locally (copying main's task 5 + task 6 files into the worktree as untracked files — the merge is add-only on both sides, so this reproduces it exactly) surfaced the real error:

```
HotChocolate.SchemaException:
1. The name `UserProfile` was already registered by another type.
   (HotChocolate.Types.ObjectType<PartyUp.Api.Features.Auth.Me.UserProfile>)
```

Task 4 declared its own `record UserProfile` as the type of `CurrentUser.profile`. Task 6 — merged to `main` in the meantime — registers the **domain entity** as that GraphQL type via `[ObjectType<UserProfile>]` and hides its internal `Id`/`User` members there. Two CLR types, one GraphQL name → schema build throws → `ApiFactory` can't start the host → every integration test fails at fixture initialisation. In isolation neither branch is wrong; only their merge is.

### The fix
`CurrentUser.Profile` is now the domain `UserProfile`, with no parallel DTO — one line of type change plus the removal of the shadow record. This is not a workaround: §7б.2 says slices meet **through the Domain model**, never through each other's types, and task 6's own `UserProfileType.cs` documents the expectation verbatim — *"Така и другите slice-ове (User.profile, CurrentUser.profile) връщат просто UserProfile"*. The Profiles slice owns the type; Auth consumes it. A missing profile row still yields an empty-but-present profile (`profile` is non-null in the contract), so `AccountWithoutAProfileRow_StillAnswers` keeps its meaning.

I left the reason in a doc comment on `Profile`, because the failure mode is invisible locally and catastrophic globally — the next slice that wants a profile-shaped DTO needs to know why it must not write one.

Everything else from the predecessor was kept untouched: the OAuth challenge/callback endpoint module, the verified-email gate, email-keyed provisioning with multi-provider auto-linking, the redirect whitelist, `me` and `logout`. Its `[QueryType]` → `[ObjectType<Query>]` correction (§7а.5) and the centrally-authorised deletion of the `Common/GraphQL/DomainErrorType.cs` bootstrap crutch (§7а.4 — `main` already lacks it via task 5, so it is a conflict-free delete/delete) both stand.

### Verification
- **Reconstructed merged tree** (branch + main's task 5/6 slices): `dotnet test backend/PartyUp.slnx` → **63 unit + 43 integration, 0 failures**. The 43 matches the gate's own `42 failed + 1 passed = 43`, so this is the same suite the gate ran.
- **Exported the live Hot Chocolate schema** to a temp path (`contracts/` untouched) from that merged tree: `CurrentUser` and `UserProfile` match `contracts/schema.graphql` field-for-field, `UserProfile` is registered exactly once, and the entity's internal `id`/`user` do not leak.
- **Isolated branch**: 51 unit + 27 integration green.
- Simulation files removed before committing (`git clean -fd` listed exactly the five copied directories); the diff is a single file.
- FE untouched (C#-only diff) — and the failing gate run reached `dotnet test`, i.e. it had already passed FE typecheck and jest, so FE was never implicated.

### Scope
`backend/src/PartyUp.Api/Features/Auth/Me/CurrentUser.cs` only, inside the task's `files` boundary.

### Note carried forward
The task notes ask for a `hasListing` flag on `me`, but `contracts/schema.graphql` does not define it. A code↔contract mismatch is a Blocker until task 41 (§7б.11), so the contract wins and the flag is deliberately absent — task 41 is the place to reconcile it.


## [2026-08-17 16:52] - Task #6: feat(profile): add myProfile query and updateProfile mutation with validation

**Status:** ✅ Complete

**TDD Phase:** RECON → RED → GREEN → DONE

**Problem:** Предишният опит написа целия слайс правилно (комит `fd0703e`), но таскът беше блокиран от фундаментален дефект ИЗВЪН обхвата му: `Common/GraphQL/DomainErrorType.cs` регистрира `DomainError` ръчно през `[ObjectType<DomainError>]`. При ПЪРВАТА реална мутация Hot Chocolate mutation conventions регистрират `ErrorObjectType<DomainError>` под същото име → `SchemaException: The name 'DomainError' was already registered by another type` → хостът не стартира и падат ВСИЧКИ интеграционни тестове, вкл. заварените foundation тестове. Централно решение от 16.08 авторизира изтриването на файла като част от този слайс.

**What was done:**
- RECON: `git log/status/diff` — запазена е цялата работа на предшественика (8 файла, 639 реда); нищо не е преписвано.
- RED (от предишната итерация): 12 unit спека за валидатора + интеграционни спекове (update+четене, празно име → VALIDATION, двете роли false → VALIDATION).
- GREEN: `Features/Profiles/` — `UserProfileType` ([ObjectType<UserProfile>], скрива Id/User), `MyProfile/MyProfileQueries` (AsNoTracking + изрична проекция), `UpdateProfile/` (Draft, Validator, Handler — upsert през Result pattern, Mutations с `[UseMutationConvention(PayloadFieldName = "profile")]`).
- FIX (тази итерация): изтрит `backend/src/PartyUp.Api/Common/GraphQL/DomainErrorType.cs` (11 реда). Патерицата съществуваше само защото source generator-ът не емитва `AddPartyUpTypes()` при НУЛА анотирани типа — този слайс носи три такива, така че билдът върви и без нея, а конвенцията сама произвежда правилния `DomainError` тип.

**Verification:**
- `dotnet build backend/PartyUp.slnx` → Build succeeded, 0 errors (доказва, че генераторът все още емитва `AddPartyUpTypes()`)
- `dotnet test backend/PartyUp.slnx` → PartyUp.UnitTests **32/32** pass · PartyUp.IntegrationTests **18/18** pass (преди фикса: 1/18)
- `schema export` (в temp, `contracts/` НЕ е пипано — червена линия §4.2) → съвпада точно с замразения контракт: `myProfile: UserProfile`, `updateProfile(input: UpdateProfileInput!): UpdateProfilePayload!`, `type DomainError implements Error`, `union UpdateProfileError = DomainError`, `type UserProfile` с 10-те А3 полета

**Files modified:**
- backend/src/PartyUp.Api/Features/Profiles/UserProfileType.cs
- backend/src/PartyUp.Api/Features/Profiles/MyProfile/MyProfileQueries.cs
- backend/src/PartyUp.Api/Features/Profiles/UpdateProfile/ProfileDraft.cs
- backend/src/PartyUp.Api/Features/Profiles/UpdateProfile/UpdateProfileValidator.cs
- backend/src/PartyUp.Api/Features/Profiles/UpdateProfile/UpdateProfileHandler.cs
- backend/src/PartyUp.Api/Features/Profiles/UpdateProfile/UpdateProfileMutations.cs
- backend/tests/PartyUp.UnitTests/Features/Profiles/UpdateProfileValidatorTests.cs
- backend/tests/PartyUp.IntegrationTests/Features/Profiles/ProfileTests.cs
- backend/src/PartyUp.Api/Common/GraphQL/DomainErrorType.cs *(ИЗТРИТ — централно авторизиран fix извън обхвата)*

**Git commit:** `fd0703e` — `feat(profile): add myProfile query and updateProfile mutation with validation` (слайсът)
**Git commit:** `fa44c3e` — `feat(profile): add myProfile query and updateProfile mutation with validation` (блокерът)

**Note за следващите таскове:** генераторният `[QueryType]` НЕ се закача, когато `Program.cs` вика `AddQueryType<Query>()` — конфигурацията виси по име на операцията. Ползвай `[ObjectType<Api.GraphQL.Query>]` за query разширенията. Мутациите не са засегнати (Mutation root-а го създава генераторът).

---


## Task #5 - feat(auth): add linked providers query with link and unlink mutations

**Repo:** partyup (`backend/`) - lane `be-auth-linking` - branch `ralph/task-5` - commit `10c00c0`

### What was done

Retry/continuation. The predecessor had already built the slice correctly but reported `failed` because a foundation file outside the `files` boundary broke schema construction. The operator authorised the cross-boundary fix centrally, so this iteration kept every line of the slice, applied that fix, re-verified and squashed to a single commit.

**The slice** (`backend/src/PartyUp.Api/Features/AuthLinking/`):
- `AuthProvider` enum (Google/Facebook/Discord) + `AuthProviderSchemes` bridging it to Identity through the handlers' own scheme constants (`GoogleDefaults.AuthenticationScheme` etc.) rather than hand-copied strings - `LoginProvider` in the DB *is* the scheme name, so a transcription slip would diverge silently from what the callback writes. `FromScheme` returns `null` for unknown schemes so a stale login cannot break the whole query.
- `LinkedProvider` projection - `ProviderKey` deliberately never leaves the server (it identifies the account at the provider, it is not UI data).
- `AuthLinkingHandler` - static, dependencies as parameters (Hot Chocolate injects them, so no DI registration and Program.cs stays untouched). Read path is `AsNoTracking` + `Select` straight into the GraphQL type. Unlink refuses to remove the last login (`CANNOT_UNLINK_LAST` as a `DomainError` value, not an exception) and goes through `UserManager.RemoveLoginAsync` so the security stamp rotates and live sessions do not survive the detach.
- `AuthLinkingQueries` (`linkedProviders`, `linkProviderUrl`) and `AuthLinkingMutations` (`unlinkProvider` via `FieldResult<T, DomainError>` + mutation conventions). `linkProviderUrl` only builds the `/auth/login/{scheme}?intent=link` address - the OAuth ceremony and the email-based attach in the callback belong to task 4, which was left untouched.
- 7 integration specs (Testcontainers Postgres, logins seeded through `UserManager` exactly as the callback would write them - no real OAuth): list is caller-scoped; empty without a session; link URL carries the intent; unlink one of two succeeds and returns the remainder; the last one returns `CANNOT_UNLINK_LAST`; an unlinked provider is `NOT_FOUND`; anonymous is `FORBIDDEN`.

**The authorised cross-boundary fix:** deleted `backend/src/PartyUp.Api/Common/GraphQL/DomainErrorType.cs`. Its `[ObjectType<DomainError>]` collided with the `ErrorObjectType<DomainError>` that `AddMutationConventions()` generates for any mutation returning `FieldResult<T, DomainError>` (`SchemaException: The name 'DomainError' was already registered`). The file was a bootstrap crutch so the source generator would emit `AddPartyUpTypes()` when nothing else was annotated; this slice now supplies annotated types, so the generator works without it.

### Notes for later tasks

- `[QueryType]` type extensions are **silently dropped** - `Program.cs` calls `AddQueryType<Query>()`, so the generator's `TryAddRootType` no-ops and the operation-keyed configuration never attaches. No error, no warning; the fields simply are not in the schema. `[ObjectType<Query>]` merges correctly and is what this slice uses. Every query-adding task needs this.
- `DomainErrorType.cs` is deleted on this branch. Other branches deleting it too is a conflict-free delete/delete merge.

### Verification

- `dotnet test backend/PartyUp.slnx` - **20/20 unit, 16/16 integration, 0 skipped**.
- Schema export diffed against `contracts/schema.graphql`: `linkedProviders`, `linkProviderUrl`, `unlinkProvider`, `LinkedProvider`, `UnlinkProviderInput`, `UnlinkProviderPayload` and `AuthProvider` match the contract exactly.
- `frontend/` and `contracts/` untouched.


## [2026-08-17 12:35] - Task #1: feat(be): add domain model, DbContext, Result primitives, Identity external auth, GraphQL module registration and test fixtures

**Status:** ✅ Complete

**TDD Phase:** RECON → RED → GREEN → DONE

**Problem:** Фундаментът на бекенда. Този таск изяжда всички отровни BE файлове (Program.cs, csproj, Domain/, Common/), за да могат 20+ feature таска после да вървят паралелно като вертикални slice-ове, без никой от тях да пипа споделен файл. Предишният опит беше прекъснат след успешния commit, но преди записа на result файла — тази итерация продължи от съществуващото състояние (запази всичко, ре-верифицира, затвори таска), вместо да пренаписва.

**What was done:**
- RED: спекове за Result/DomainError и FromResult мапинга (UnitTests/Common/), за ApiFactory + { hello } през Testcontainers Postgres, за TestAuthHandler (userId header → сесия) и за домейн модела (seed AppUser+UserProfile+Table+Membership → прочитане, доказва модела + EnsureCreated) — червени по правилната причина.
- GREEN: пакетите (HotChocolate.Subscriptions.InMemory, HotChocolate.Types.Analyzers, Lib.Net.Http.WebPush; Mvc.Testing в IntegrationTests); Domain/ — пълният v0.1 модел (13 entity-та + 9 enum-а, feature таск НЕ добавя entities); Data/PartyUpDbContext — DbSet-ове + fluent конфиг (List<string> → text[], read индекси, уникален (DecisionId, VoterUserId): вотът е един на човек); Common/ — Results (Result, Result<T>, DomainError{Code, I18nKey} + фабриките), GraphQL/MutationResult.FromResult (Result → typed GraphQL error), Notifications/INotifier + DefaultNotifier, AdmissionThreshold=4 като константа, IEndpointModule reflection механиката; Program.cs — DbContext, IdentityCore (само external), OAuth схемите, CORS с AllowCredentials, AddGraphQLServer().AddPartyUpTypes().AddMutationConventions().AddInMemorySubscriptions(), MapPartyUpEndpoints, RunWithGraphQLCommandsAsync (schema export остава жив); appsettings — публичните client ID-та + ПРАЗНИ secret placeholder-и; Support/ фикстурите.

**Findings (важни за downstream таскове):**
- Генерираният метод е `AddPartyUpTypes()`, не `AddTypes()` (Hot Chocolate именува по асембли), а генераторът не емитва НИЩО при нула анотирани типа → фундаментът регистрира DomainError през [ObjectType<T>], за да компилира Program.cs.
- Hot Chocolate инжектира `global using GreenDonut;`, чийто Result<T> се сблъсква с нашия → премахнато с MSBuild target, иначе всеки slice щеше да удари CS0104.
- OAuth провайдър с празен секрет чупи ВСЯКА заявка (remote handler-ите са IAuthenticationRequestHandler) → неконфигурираните провайдъри се пропускат, не се регистрират.
- Контрактът на таск 2 беше вече мърднат → SessionFormat/TableRole преименувани на GameFormat/MembershipRole; останалото съвпада поле по поле.

**Verification:**
- `dotnet test backend/PartyUp.slnx` → 29/29 pass (20 unit + 9 integration, вкл. двата заварени smoke теста)
- `npm --prefix frontend run typecheck` → clean · `npm --prefix frontend test` → 1/1 pass (frontend/ непипнат)
- Работно дърво чисто, никакви останали контейнери/слушащи процеси; contracts/ не е докосван; никакви секрети в git (секретите са празни placeholder-и).

**Files modified:**
- backend/src/PartyUp.Api/{Program.cs, PartyUp.Api.csproj, appsettings.json, appsettings.Development.json}
- backend/src/PartyUp.Api/Domain/** (AppUser, UserProfile, PlayerListing, Table, TableMembership, Candidacy, GroupDecision, Vote, Chat, Message, Notification, PushSubscription, Enums)
- backend/src/PartyUp.Api/Data/PartyUpDbContext.cs
- backend/src/PartyUp.Api/Common/** (Results, GraphQL, Notifications, Endpoints, CurrentUser, FrontendOptions, TableRules)
- backend/src/PartyUp.Api/GraphQL/TypeModule.cs
- backend/tests/PartyUp.UnitTests/{Support/TestSchema.cs, Common/*}
- backend/tests/PartyUp.IntegrationTests/{Support/*, Foundation/*, PartyUp.IntegrationTests.csproj}

**Git commit:** `c8072ba` — `feat(be): add domain model, DbContext, Result primitives, Identity external auth, GraphQL module registration and test fixtures`

---


## [2026-08-17 11:52] - Task #27: feat(fe-auth): add login screen with three OAuth providers, session hook and auth gate

**Репо:** partyup (frontend/) · **Бранч:** ralph/task-27 · **Commit:** `b32c0da`

**Status:** ✅ Complete

**TDD Phase:** RECON → RED → GREEN → DONE

### Какво е направено

**`features/auth/oauth.ts`** — списъкът на провайдърите (`google, discord, facebook` — редът тук е редът на бутоните) + `buildLoginUrl` → `<apiBase>/auth/login/{provider}?returnUrl=…` върху `API_BASE_URL` от `lib/config` (фундаментът от таск 3). Входът е HTTP endpoint, не GraphQL мутация — сесията идва като HttpOnly бисквитка от redirect-а, а схемата има само `me`/`logout`. Уеб: `location.assign` (XHR не може да следва redirect-ите на провайдъра и не би получил бисквитката); нативно: `WebBrowser.openAuthSessionAsync` върху `Linking.createURL('/')`.

**`features/auth/use-session.ts`** — `me` заявката → `{ user, loading, resolved }`. Сървърен state, значи живее в Apollo кеша, не в Zustand (§2.4). `resolved` разграничава „сървърът каза: няма сесия" от „още не знаем".

**`features/auth/use-logout.ts`** — `Logout` мутацията + `client.resetStore()`. Кешът не се кърпи на ръка: `me` се презарежда, гейтът вижда празна сесия и праща към входа.

**`features/auth/login-screen.tsx` + `app/login.tsx`** — три бутона и нищо друго (без форма, без пароли). Route файлът е тънък — екранът живее в областта си (§2.1).

**`lib/auth-gate.tsx`** — стъбът от таск 3 е подменен съдържателно: анонимна сесия → `<Redirect href="/login">`, `loading` → splash НАД вече монтираното дърво (без второ сглобяване при готова сесия), сегментът `login` остава публичен.

**`locales/{bg,en}/auth.json`** — всички низове през `auth` namespace-а (§4.6), нула твърдо зашити текстове в компонентите.

### Едно решение, което си заслужава да се спомене

Гейтът препраща САМО при изричен `me: null`, не при грешка на заявката. Мрежова грешка не е анонимен потребител — да я третираме като такава щеше да изхвърля всеки потребител на `/login` при паднал бекенд И щеше да счупи заварения `navigation.test.tsx`, който рендерира истинския рутер срещу истинския Apollo клиент (файл извън обхвата ми).

### TDD

RED първо: 4 спека паднаха, преди да има имплементация. GREEN след това. Тестовете: трите бутона с БЪЛГАРСКИТЕ етикети + превключване на en, `assign` към `buildLoginUrl(provider, origin)`, гейтът (splash при чакане / пуска при `me` мок / препраща при `null` / не препраща на самия `login` сегмент), logout вика мутацията и `resetStore`.

### Верификация

- `npm --prefix frontend test` — зелено, **8 suite-а / 20 теста** (4-те заварени suite-а непроменени и зелени)
- `npm --prefix frontend run typecheck` — зелено (codegen + `tsc --noEmit`, 0 грешки)
- Червени линии: пипнати са САМО файловете от `files` списъка; `contracts/` и `backend/` непипнати; e2e и dev сървъри НЕ са пускани; `src/gql/` и node_modules не са комитнати; `package-lock.json` непроменен; работното дърво е чисто след тестовете

### Бележки за следващите

- `useSession()` е единственият източник за „кой съм" — консумирай го, не дублирай `me` заявката.
- `useLogout()` вече прави `resetStore` — екранът, който го вика, не бута кеша допълнително.
- Ако някой таск има нужда гейтът да реагира и на грешка, това е СЪЗНАТЕЛНО решение да се промени, не пропуск.

**Files modified:**
- frontend/src/features/auth/oauth.ts (+ oauth.test.ts)
- frontend/src/features/auth/use-session.ts
- frontend/src/features/auth/use-logout.ts (+ use-logout.test.tsx)
- frontend/src/features/auth/login-screen.tsx (+ login-screen.test.tsx)
- frontend/src/app/login.tsx
- frontend/src/lib/auth-gate.tsx (+ auth-gate.test.tsx)
- frontend/src/locales/bg/auth.json
- frontend/src/locales/en/auth.json

**Git commit:** `b32c0da` — `feat(fe-auth): add login screen with three OAuth providers, session hook and auth gate`

---


## [2026-08-17 12:20] - Task #28: feat(fe-auth): add settings screen with provider management, theme and language toggles

**Репо:** partyup (frontend/) · **Бранч:** ralph/task-28 · **Commit:** `1769266`

**Status:** ✅ Complete

**TDD Phase:** RECON → RED → GREEN → DONE

**Problem:** `settings.tsx` беше placeholder от таск 3. Трябваше да стане реалният екран: свързани акаунти + тема + UI език. Това е и витрината на Result патърна на FE — `CANNOT_UNLINK_LAST` е ОЧАКВАН провал, не изключение.

### Какво е направено

**Свързани акаунти (`features/auth-linking/`).** `documents.ts` държи трите кодген документа: `linkedProviders`, `linkProviderUrl($provider)` и мутацията `unlinkProvider`. В payload-а НАРОЧНО не се селектира `DomainError.message` — той е за разработчици; UI-ят чете само `code` + `i18nKey` (§4.6, §7б.4). `use-auth-linking.ts` е хукът: сървърният state живее САМО в Apollo кеша, в React state стоят единствено двете UI решения — чакащото потвърждение и готовото съобщение за грешка. `unlinkProvider` връща остатъчния списък, който се пише право в кеша с `overwrite: true` (`LinkedProvider` няма `id`, иначе кешът предупреждава за сливане на два масива) — без refetch. `linkProviderUrl` се тегли с `fetchPolicy: 'network-only'`: URL-ът носи еднократен OAuth state и кеширането му е грешка. Самото пренасочване е изнесено в `redirect.ts` (`expo-linking.openURL`) — единственият страничен ефект на фичата, оставен като мокваем шев.

**Result патърнът на екрана.** `domainErrorText` резолвва `i18nKey` първо в namespace-а на фичата, после пада на общата витрина `domainErrorMessage` → `errors.unknown`. Така `CANNOT_UNLINK_LAST` излиза като „Това е единственият ти начин за влизане…“, а не като код или exception. Премахването минава през вградено потвърждение (необратимо действие).

**Тема и език (Е.9).** `appearance-section.tsx` — чипове light/dark/system и bg/en/system; двете четат и пишат `ui-store` (логиката дойде готова от таск 3, тук е UI-ът). `null` за език = „следвай устройството“.

**i18n.** Празният ns `authLinking` (bg + en) е запълнен: заглавия, имена на провайдъри, действия, потвърждение и `errors.auth.cannotUnlinkLast`.

### TDD

RED първо — 8 спека срещу липсващия модул. GREEN след имплементацията. Покриват: списъкът от мока (свързаните с „Премахни“, останалите със „Свържи“), потвърждението преди премахване, успешното премахване (списъкът се свива през кеша), човешкото съобщение при `CANNOT_UNLINK_LAST` + изрична проверка, че кодът НЕ изтича в UI-я, редиректът към URL-а от контракта, двата тогъла срещу `ui-store`, маркирането на текущия избор и пълният екран на английски.

**Verification:**
- `npm --prefix frontend run typecheck` → exit 0
- `npm --prefix frontend test` → 5 suites / 18 tests pass
- Чист worktree след кодген; `src/gql/` остава генериран и некомитнат; BE и `contracts/` непипнати.

**Files modified:**
- frontend/src/app/settings.tsx
- frontend/src/features/auth-linking/{documents.ts,use-auth-linking.ts,redirect.ts,linked-accounts-section.tsx,appearance-section.tsx,primitives.tsx,index.ts}
- frontend/src/features/auth-linking/__tests__/settings-screen.test.tsx
- frontend/src/locales/{bg,en}/authLinking.json

**Git commit:** `1769266` — `feat(fe-auth): add settings screen with provider management, theme and language toggles`

**Бележка за следващите итерации:** в RNTL v14 `fireEvent` е асинхронен — без `await` се получават застъпващи се `act()` извиквания и полу-рендерирани дървета. Тази итерация беше resume след прекъснат ран: комитът беше налице, липсваше само result файлът; кодът е ре-верифициран без промени.

---


## Task #3 — feat(fe): wire Apollo, codegen, i18n, NativeWind theme shell, tab navigation and test utils

**Репо:** partyup (frontend/) · **Бранч:** ralph/task-3 · **Commit:** `031dc52`

### Какво е направено

**Codegen (contract-first).** `frontend/codegen.ts` с client-preset срещу `../contracts/schema.graphql`; изходът `src/gql/` е **gitignored** и се регенерира от `npm run codegen`, който виси пред `typecheck` и `test`. Така паралелните FE таскове никога не комитват генериран код (§7а.3). Семето на кодгена е `lib/session.ts` с `me` заявката — client-preset иска поне един документ.

**Apollo (`lib/apollo.ts`).** HttpLink към `/graphql` с `credentials: 'include'` (cookie auth), GraphQLWsLink през graphql-ws, `split` по `isSubscriptionOperation`. `createClient` резолвва WebSocket имплементацията ВЕДНАГА и хвърля, ако няма такава — затова ws линкът се създава само при наличен `WebSocket` (статичният web export и jest нямат). API базата е една константа в `lib/config.ts`.

**i18n (`lib/i18n.ts`).** react-i18next + expo-localization; default-ът е локалът на устройството, ръчният override живее в ui-store-а. Създадени са ВСИЧКИ 15 namespace-а × bg/en (`common, auth, authLinking, profile, tables, tableForm, tableSettings, board, showcase, candidacy, contact, chat, lifecycle, lifecycleActions, push`) — празни `{}` освен `common` (бутони, състояния, общи грешки, таб етикети, заглавия на екрани). Индексът ги import-ва статично, значи фича таскът пипа САМО своя json. Смяната на езика създава нова i18next инстанция вместо `changeLanguage` — init-ът с вградени ресурси е синхронен, тестовете стават детерминистични. Добавен е `domainErrorMessage(t, i18nKey)` за конвенцията „DomainError.i18nKey → човешки текст, никога `message`".

**Тема (Е.9).** NativeWind v4 wiring: `babel.config.js` (jsxImportSource + `nativewind/babel`), `metro.config.js` (`withNativeWind`), `tailwind.config.js` (`darkMode: 'class'` + surface/ink/brand токени), `@tailwind` директивите в `src/global.css`. Режимът light/dark/system живее в `lib/ui-store.ts` (Zustand + persist през localStorage адаптер с fallback в паметта — БЕЗ нов пакет) и се пуска в NativeWind през `colorScheme.set()` от `lib/theme.tsx`.

**Навигация.** `app/_layout.tsx` = провайдъри (Apollo + i18n + тема) + `<AuthGate>` + Stack; `app/index.tsx` пренасочва към борда. `(tabs)/` с `board.tsx` („Борд"), `tables.tsx` („Моите маси"), `profile.tsx` („Профил"); `login.tsx` е извън табовете. `lib/auth-gate.tsx` е СТЪБ (пуска всичко) — таск 27 го запълва в същия файл, без да пипа `_layout.tsx`. Създадени са всички placeholder route-ове (table/create, table/[id]/{index,settings,lifecycle}, showcase/{index,[id]}, chat/{index,[chatId]}, candidacy/[id], settings, notifications, refound-invite) през един `<PlaceholderScreen name="..." />` — заглавието е i18n ключ, не низ.

**Test utils.** `src/test-utils/render.tsx` → `renderWithProviders(ui, { mocks, link, language, themeMode })` = Apollo MockedProvider + i18n (bg по подразбиране) + тема; `subscription.ts` → `createSubscriptionMock()` върху `MockSubscriptionLink` за чата/известията. Jest мапва `*.css` към празен модул (metro го компилира, jest — не).

**Чистка.** Изтрити: `explore.tsx`, `animated-icon*`, `hint-row`, `web-badge`, `app-tabs*`, `external-link`, `ui/collapsible`, `themed-text/view`, `constants/theme.ts`, `hooks/use-color-scheme*`, `hooks/use-theme` — темизацията вече е NativeWind. `app.json` се казва Party Up (беше „frontend").

### TDD

RED първо: 4 спека паднаха с „Could not locate module @/lib/ui-store". GREEN след имплементацията. Тестовете: таб барът с bg етикети и превключване на en (`renderRouter` срещу РЕАЛНАТА `src/app` директория — хваща счупен root layout), тогълът light→dark→system в ui-store, три placeholder route-а, и ремонтираният смоук през `renderWithProviders` с Apollo мок на `me`.

### Верификация

- `npm --prefix frontend run typecheck` — зелено (codegen + `tsc --noEmit`, 0 грешки)
- `npm --prefix frontend test` — зелено, 4 suite-а / 9 теста, ~4 сек
- Червени линии: contracts/ и backend/ непипнати; никакви секрети; тестовете не пипат мрежа; dev сървъри не са пускани; `src/gql/` и node_modules не са комитнати; нови пакети НЯМА (`package-lock.json` непроменен)

### Бележки за следващите

- Тестовете рендерират през `renderWithProviders` — инфраструктурен файл, фича таск го КОНСУМИРА, не го преправя (§4.7).
- `lib/auth-gate.tsx` е единственият файл от тази зона, който таск 27 е упълномощен да редактира.
- Всеки фича таск попълва САМО своя locale json — индексът вече знае namespace-а.


## Таск 2 — feat(contracts): design the complete v0.1 GraphQL schema as the frozen BE-FE contract

**Репо:** partyup (`contracts/`) · **Branch:** `ralph/task-2` · **Commit:** `2f6aa31`

### Какво е направено

- **`contracts/schema.graphql`** — ръчно написаната целева схема за целия v0.1 разрез (party-up.md секция Е, точки 1-9 + Web Push):
  - **18 query:** `hello`, `me`, `linkedProviders`, `linkProviderUrl`, `myProfile`, `myListing`, `myTables`, `lfgBoard(filter)`, `tablesShowcase(filter)`, `table(id)`, `myTableCandidacies`, `candidacy(id)`, `groupDecision(id)`, `staleDecisions`, `myChats`, `chat(id)`, `notifications(unreadOnly)`, `vapidPublicKey`.
  - **25 mutation:** `logout`, `unlinkProvider`, `updateProfile`, `createTable`, `updateTableSettings`, `setTableListing`, `publishMyListing`/`unpublishMyListing`, `pullCandidate`, `castVote`, `openContactChat`, `submitVerdict`, `snoozeDecision`, `sendMessage`, `startTrial`/`startDecidingPhase`/`finalizeDeciding`/`stayOrLeave`, `leaveTable`, `proposeKick`, `refoundTable`/`acceptRefoundInvite`, `markNotificationRead`, `pushSubscribe`/`pushUnsubscribe`.
  - **2 subscription:** `onMessage(chatId)`, `onNotification`.
  - **Hot Chocolate конвенции:** camelCase полета, `SCREAMING_SNAKE` enum стойности, скалари `UUID` (Guid) и `DateTime` (DateTimeOffset), `xxx(input: XxxInput!): XxxPayload!` с `errors: [XxxError!]`, където `XxxError` е union (както ги генерира `AddMutationConventions()` дори при един error тип).
  - **Грешки по Result pattern-а (решение 13.08):** `interface Error { message }` + `type DomainError implements Error { message, code, i18nKey }` — FE рендерира `t(error.i18nKey)`, `message` никога не стига до UI.
  - **Домейнът е огледален на таск 1:** `ExperienceLevel`, `GameFormat`, `TableStatus`, `AdmissionMode`, `MembershipRole`, `CandidacyStatus`, `DecisionTopic`, `DecisionStatus`, `ChatType`, `AuthProvider`; типове `User`/`CurrentUser`/`UserProfile`, `PlayerListing`, `Table`, `TableMembership`, `Candidacy`, `GroupDecision` (с **явните** гласове + `pendingVoters` + `excludedUser`), `Vote`, `Chat`, `Message`, `Notification`, `PushSubscription`, `LinkedProvider`.
- **`contracts/DESIGN-NOTES.md`** — карта operation→таск (BE + FE консуматор за всичките 42 таска), конвенциите, продуктовите решения зад схемата и съзнателните опростявания.

### Ключови решения

- **Записана е екзепцията от §3.1** (амендмънт §7а.1): таск 2 е ЕДИНСТВЕНАТА упълномощена ръчна редакция; между 2 и 41 никой не пипа `contracts/`; таск 41 затваря екзепцията с реалния HC експорт.
- **`UUID` вместо `ID`** — `[ID]` в HC би включило base64 relay кодиране, което v0.1 не иска.
- **`[UseMutationConvention(PayloadFieldName = "...")]`** е документирано като задължително там, където data полето на payload-а не съвпада с camelCase на върнатия C# тип (`success`, `linkedProviders`, `pushSubscription`) — иначе таск 41 намира drift.
- **Прагът 4 НЕ е в схемата** — константа в `Common`; `pullCandidate` връща `Candidacy.decision = null` при founder fast-path, FE чете резултата, не преизчислява правилото.
- **Съзнателни опростявания:** без пагинация/Relay connections, без `node(id)`, `String` (не enum) за език и система, място = описание (не гео), без наличностни решетки, без „покани конкретен играч" (моделът е PULL), `Notification.payloadJson` като JSON низ.
- **`hello` остава** в схемата, докато интеграционният smoke на таск 1 го ползва (иначе §7б.11 гърми).

### Верификация

- `graphql.buildSchema` парсва чисто; `validateSchema` → **0 грешки**.
- Скриптова проверка на конвенциите: всичките 25 мутации имат коректна `XxxInput`/`XxxPayload!`/`errors: [XxxError!]` тройка; всичките 25 error union-а сочат `DomainError`. **0 нарушения.**
- `dotnet test backend/tests/PartyUp.UnitTests` → **1/1 passed** (таскът не пипа код).
- Обхват: САМО `contracts/schema.graphql` + `contracts/DESIGN-NOTES.md`. Никакви секрети, никакви runtime артефакти.


## Task #650 — test(bases): add e2e fixture and accordion spec for the Bases tab

**Repo:** inventory (shared-inventory) · **Lane:** bases-e2e · **Commit:** 144d293

**What:** Final task of the Bases feature. Added two new files (both explicitly permitted by §10; existing e2e/fixtures untouched per red line §3.5):
- `test/fixtures/bases-fixture.html` — standalone HTML with inline copy of the base table/button styles + the `.base-location` / `tr.base-expanded` accordion rules (1:1 from styles.css). Inline script renders 2 bases (base 0 short location, base 1 a 3+ line location to give the ellipsis something to clamp) and replicates renderBases' row markup (drag-handle, name `<strong>`, `.base-location` div, `.tbl-actions` with 📖 openBaseDetail + 🗑 deleteBase) and its single-open accordion logic. No detail page / hash routing / Firestore (unit tests cover those).
- `test/e2e/bases-accordion.spec.js` — mirrors maps-accordion.spec.js: FIXTURE `/test/fixtures/bases-fixture.html`, waits for `#baseBody tr[data-idx]`, and the 6 tests: (a) `.base-location` overflow hidden; (b) row starts without `base-expanded`; (c) click expands; (d) re-click collapses; (e) only one expanded (second click collapses first); (f) clicking the 📖 button does not expand.

**Verify:** `npm run test:unit` green (14 files, 177 tests). Did NOT run `npm test` (Playwright on shared port 45279 — left for the post-merge gate). `git status` confirms only the two new files, no existing spec/fixture edited. No 610/620 markup/style gaps needed fixing, so index.html/styles.css/modules/bases.js were not modified.

**Red lines:** respected — no Firestore/persistence touched, no runtime artifacts committed, existing e2e specs/fixtures untouched.


## Task 630 — feat(bases): implement base detail hash routing with editable name, location and history

**Repo:** inventory (shared-inventory) · **Lane:** bases-detail · **Branch:** ralph/task-630 · **Commit:** 003f07b

**What:** Filled the stubs in `modules/base-detail.js` (from the 610 foundation) with the real hash-routing implementation, per §10 + bases-feature-plan.md.

- `renderRoute()` — the single transition point, wired to `hashchange` and called from the bases `onSnapshot`. On `#base/<id>` for a known base: adds `hidden` to `.tab-nav` + every `.tab`, reveals `#baseDetail`, sets `state.currentBaseId`, and (only when the route id actually changes) populates `bdName/bdLocation/bdHistory` and dispatches `document` `CustomEvent('base-route', {detail:{id}})`. On empty/unknown hash: restores the tabs with `tab-bases` active and dispatches `{id:null}` — but only when leaving an open detail, so a plain load never steals the active tab. Unknown id with data present clears the stale hash; with an empty list it waits for the snapshot (deep-link on load).
- `openBaseDetail(i)` → `location.hash = '#base/' + id`. `saveBaseDetail()` requires `bdName` (empty → focus + return), updates the fields and splices+unshifts the edited base to the top (saveQuest pattern) while keeping the detail open (anchor is the id, not the index), then `await saveBases()`.
- Field repopulation is gated on a module-level `lastRenderedId`, so an incoming snapshot while the detail is open does not overwrite what the DM is typing.
- Init wiring: `hashchange` listener, `btnBaseBack` → clear hash + renderRoute, `btnBaseSave` → saveBaseDetail.

**Tests:** Added `test/unit/bases-detail.spec.js` (7 tests: open/route, back button + bases-tab active, unknown id fallback, save moves-to-top + persists, empty-name block + focus, deep link, snapshot does not clobber typed input). TDD: RED against the stubs, then GREEN.

**Verify:** `npm run test:unit` → 13 files, **152 passed** (145 prior + 7 new), no regressions. `git status` — only `modules/base-detail.js` + the new spec touched. No real Firestore, no e2e/fixtures touched, UI Bulgarian.


### Task 620 — feat(bases): implement bases list with accordion, add dialog, delete and drag ordering

**Repo:** inventory (shared-inventory) · **Lane:** bases-list · **Commit:** 08945ee

Filled the no-op stubs from the 610 foundation in `modules/bases.js`, mirroring `modules/quests.js` (the etalon):

- **renderBases()** — empty state `Няма добавени бази.` (colspan 4, `.empty`); rows `data-idx` with ☰ `.drag-handle`, `<strong>${esc(name)}</strong>`, `<div class="base-location">${esc(location)}</div>`, and `.tbl-actions` with 📖 `openBaseDetail(i)` first then 🗑 `deleteBase(i)` (no ✏ — editing lives on the detail page). Accordion is a copy of the quest pattern: class `base-expanded`, exactly one expanded, clicks on a button/handle don't toggle, expanded survives re-render via `state.expandedBaseIdx`. `initSortable('baseBody', state.bases, saveBases)`.
- **openBaseModal(idx=null)** — clears `bName`/`bLocation`, title `Добави база`, opens `#baseModal`, focuses `bName`.
- **saveBase()** — name required (empty → focus + return); new base `{ id: crypto.randomUUID(), name, location, history:'', buildings:[], populace:[], production:[] }`, unshift + close + render + `await saveBases()`.
- **deleteBase(i)** — `confirm("Изтрий база …?")` → splice + render + saveBases.
- `saveBases` left as the real implementation from 610; exports list identical.

**Tests:** added `test/unit/bases.spec.js` (15 tests: render, escaping, action-button order, sortable, accordion behaviour, add modal + validation + unshift, delete confirm/cancel). Note: jsdom does not resolve `window`-expando globals from inline `onclick` content attributes, so the accordion-guard test drops the button's `onclick` before DOM-clicking (it exercises the row guard, not the wired handler) — consistent with the suite calling `window.fn()` directly elsewhere.

**Verify:** `npm run test:unit` → 13 files / 160 tests green (incl. bases-foundation and all pre-existing specs). Scope: only `modules/bases.js` + `test/unit/bases.spec.js` touched.


### Task 640 — feat(bases): implement buildings, populace and production sub-tables with shared dialog

**Repo:** inventory (shared-inventory) · **Lane:** bases-tables · **Branch:** ralph/task-640 · **Commit:** c30fb67

**What:** Implemented the three base sub-tables in `modules/base-tables.js`, replacing the 610 no-op stubs while keeping the export signature identical (`renderSubTables, openSubModal, closeSubModal, editSub, saveSub, deleteSub`).

- **Generic, not ×3:** one `renderSubTable(kind)` + `renderSubTables()`; `kind ∈ buildings|populace|production` maps to `bdBuildingsBody/bdPopulaceBody/bdProductionBody`.
- **Row markup (app pattern):** ☰ `.drag-handle` | `<strong>${esc(name)}</strong>` | `<div class="bs-details">${esc(details)}</div>` | `.tbl-actions` ✏ `editSub` / 🗑 `deleteSub` (confirm). Empty sub-array → `.empty` row „Няма записи.“.
- **Shared modal `#bsModal`:** `state.editingSub = {kind, idx}`; `openSubModal(kind, idx=null)` sets title „Добави/Редактирай сграда|жител|продукция“ and prefills; `saveSub` requires name (empty → focus + return), unshifts new/edited record to the top of the sub-array, closes modal, then `await saveBases()`.
- **Per-table accordion:** class `bs-expanded`, exactly one expanded per table via `state.expandedSub[kind]`; expanding populace does not collapse buildings; clicks on button/handle do not toggle.
- **Contract to detail lane:** current base resolved ALWAYS by `state.currentBaseId` (null → tables cleared), never by index; listens to `document` event `base-route` → `renderSubTables()`. Never calls base-detail.js.
- **Drag&drop:** `initSortable(tbodyId, base[kind], saveBases)` per tbody.

**Tests:** new `test/unit/bases-tables.spec.js` (TDD: 16 RED against stubs → 17 GREEN) covering rendering per kind, empty state, currentBaseId null, `base-route` re-render, sortable init, modal open/empty/title, name-required, new/edit unshift into the right base by id, delete confirm true/false, and the per-table accordion. `npm run test:unit` → 13 files / 162 tests all green.

**Scope:** only `modules/base-tables.js` + `test/unit/bases-tables.spec.js` touched (index.html/styles.css/app.js/bases.js/base-detail.js untouched — parallel lanes). No real Firestore, e2e/fixtures untouched, UI in Bulgarian.


## Task 610 — feat(bases): add bases foundation with 2x2 tab grid, full markup, data layer and module stubs

**Repo:** inventory · **Lane:** bases-core · **Branch:** ralph/task-610 · **Commit:** 0f115fc

**What:** Laid the shared foundation for the Bases feature (§10) so lanes 620/630/640 can proceed in parallel, each editing only its own module.

- **index.html:** 4th nav button `data-tab="bases"` (Бази); `#tab-bases` (controls „+ Добави база" + baseTable/baseBody: ☰|Име|Локация|действия); `#baseDetail.hidden` (btnBaseBack, bdName/bdLocation/bdHistory, btnBaseSave + 3 sections Сгради/Население/Продукция each with „+ Добави" openSubModal(kind) and tbody bdBuildingsBody/bdPopulaceBody/bdProductionBody); `baseModal` (bName/bLocation); `bsModal` (bsName/bsDetails).
- **styles.css:** `.tab-nav{flex-wrap:wrap}` + `.tab-btn{flex:1 1 50%}` → 2×2; `.base-location`/`.bs-details` line-clamp mirroring `.quest-desc`; `tr.base-expanded`/`tr.bs-expanded`; `#baseDetail` page style + `#baseDetail.hidden{display:none}` + base-history min-height 120px.
- **modules/firebase.js:** `BASES_DOC = doc(db,'bases','index')`.
- **modules/state.js:** bases, editingBaseIdx, expandedBaseIdx, savingBases, currentBaseId, editingSub, expandedSub.
- **modules/bases.js:** stubs renderBases/openBaseModal/closeBaseModal/saveBase/deleteBase + REAL saveBases (savingBases flag, setDoc(BASES_DOC,{list}), syncMsg).
- **modules/base-detail.js:** stubs renderRoute/openBaseDetail/saveBaseDetail.
- **modules/base-tables.js:** stubs renderSubTables/openSubModal/closeSubModal/editSub/saveSub/deleteSub.
- **modules/ui.js:** baseModal + bsModal added to initModalBackdrops.
- **app.js:** imports + all window.* base handlers + 5th onSnapshot(BASES_DOC) with savingBases echo guard → renderBases()+renderRoute()+renderSubTables(); facade re-exports; bases in getState/setState.
- **test/helpers/dom.js:** additive `bases = null` param → __emit('bases/index', ...).
- **test/unit/bases-foundation.spec.js:** tab/markup contract, data layer (state.bases populate, saveBases write, echo guard), modal backdrops.

**Verify:** `npm run test:unit` → 12 files, 145 tests, all green. Scope limited to the task's files list (git status clean of anything else). e2e/serve left to the gate (port 45279).


## Task 550 — test(cube): end-to-end integration spec for face themes across the full app

**Repo:** combat (monk_combat_app) · **Lane:** cube · **Branch:** ralph/task-550

**What:** Created `test/e2e/cube-integration.spec.js`, the capstone integration spec for the Cube of Force feature. It drives the real dialog UI and observes the live app's COMPUTED colours (not just the link href), proving the three lanes (tokens/themes/cube) work together end-to-end.

**Coverage (6 points from task notes):**
1. Each of the 5 faces: Activate via dialog → `body` background-color == the palette bg (fog rgb(16,19,21) / stone rgb(21,17,13) / moss rgb(14,19,16) / arcane rgb(18,15,25) / bastion rgb(22,15,17)), `--pill`/`--panel`/`--accent` tokens all move off default, `#cubeThemeLink` href matches the theme file, and the ticker shows `FACE N ACTIVE`. Waits for the standalone stylesheet to load via `expect.poll` on the computed bg.
2. Deactivate (face 6) → body reverts to default #0b0c12, ticker hidden, `#cubeThemeLink` removed.
3. Minute Elapsed → same revert to default.
4. Spell-drain to 0 (face 4, Apply 99 on Disintegrate) → charges 0, default theme, ticker hidden.
5. Reload with active barrier → theme survives (link restored from `st.cube.activeFace`), body still themed, ticker restored.
6. Tab switch (combat→inventory→stats) with active theme → theme unaffected (link lives in `<head>`).

**Verify:** `npx playwright test cube-integration` → 10 passed (12.3s). No other spec/source file touched.

**Notes:** Point 6 uses inventory/stats tabs — the combat section is always-visible and has no `.tab-btn`, so it can't be clicked. Ran `npm ci` once (worktree had no node_modules); the npm `.cache/` artifact was left uncommitted.


## Task 520 — feat(themes): add 5 standalone face theme stylesheets (fog/stone/moss/arcane/bastion)

**Repo:** combat (monk_combat_app) · **Lane:** themes · **Branch:** ralph/task-520 · **Commit:** 9c7ddf2

**Status:** ✅ Complete

**TDD Phase:** RECON → RED → GREEN → DONE

### What
The five Cube of Force face themes as FULLY standalone CSS files: `themes/fog.css`, `themes/stone.css`, `themes/moss.css`, `themes/arcane.css`, `themes/bastion.css`. styles.css is NOT touched (no @import) — themes are applied via a dynamic `<link id="cubeThemeLink">` kept last in `<head>` (later stylesheet wins the `:root` ↔ `:root` cascade); removing it reverts to the styles.css default.

Each file is a single `:root` block overriding the SAME 67 ambient tokens as the post-510 styles.css `:root` (verified 67/67 coverage, zero missing/extra per theme):
- `--bg` and `--accent` pinned EXACTLY to the approved palette (fog #101315/#5e7681, stone #15110d/#8a6f4d, moss #0e1310/#5e7a58, arcane #120f19/#71618f, bastion #160f11/#8a5a62).
- Every other surface/border/text/feat token re-hued to the theme hue (derived from the accent: fog 199°, stone 33°, moss 109°, arcane 261°, bastion 350°) with muted saturations (surf ~0.14–0.20, text ~0.06–0.08) while PRESERVING each token's original lightness → relative light↔dark ordering intact, everything muted (no bright/electric colors).
- Semantic colors (coins, success/danger, cleric purple) are NOT themed — they live as literal values in styles.css, never as `:root` tokens.

### How (TDD)
- RED: created `test/e2e/cube-themes.spec.js` (mirrors styles.spec.js conventions) — for each theme it appends the theme link last in `<head>`, asserts computed `body` background-color equals the palette bg, asserts `--panel`/`--pill`/`--accent` change, then removes the link and asserts revert to default `#0b0c12`. Fails-for-the-right-reason before the files exist (404).
- GREEN: generated the 5 files via a deterministic HSL re-tint of the default token set (script kept outside the worktree, not committed).
- Verify (agent, no shared-port e2e): Node checks — 67/67 token coverage per theme, `--bg`/`--accent` byte-exact vs palette, balanced braces / single `:root` / all declarations terminated. The full Playwright gate (npm ci + npm test incl. cube-themes.spec.js) runs post-merge on the proper checkout — port 45278 is the gate's, so the agent did not spin it (reuseExistingServer would test the wrong checkout).

### Red lines respected
styles.css / index.html / app.js UNTOUCHED. Only `themes/**` + the new spec created (git scope confirmed clean). No @import, no reference to themes/ from styles.css. No real Firestore/JS wiring (that is lane cube, tasks 530/550).

**Files modified:**
- themes/fog.css (new)
- themes/stone.css (new)
- themes/moss.css (new)
- themes/arcane.css (new)
- themes/bastion.css (new)
- test/e2e/cube-themes.spec.js (new)

**Git commit:** `9c7ddf2` — `feat(themes): add 5 standalone face theme stylesheets (fog/stone/moss/arcane/bastion)`


## Task 540 — feat(cube): add barrier news ticker and spell drain accordion

**Repo:** combat (monk_combat_app) · **Lane:** cube · **Commit:** 809a0f6

### What
Two upgrades on top of 530's Cube of Force widget:

1. **News ticker** — static `<div id="cubeTicker" class="hidden"><span></span></div>` inserted in index.html between the `.header` div and `#tab-combat`. Shown only while a barrier is active; text `FACE N ACTIVE — <effect> · N CHARGES` scrolls right→left. Per the accessibility mandate the animation is slow (~32s per cycle) and bold; `@media (prefers-reduced-motion: reduce)` disables the animation and shows static text. Styles live in cube.css. render() drives show/hide + text, so it is restored on reload with an active barrier.
2. **Spell-drain accordion** — row under Minute Elapsed: a `Dmg from special spells` toggle (▶/▼) that expands the 5 RAW drain spells (Disintegrate 1d12, Horn of Blasting 1d10, Passwall 1d6, Prismatic Spray 1d20, Wall of Fire 1d4). Each row has a number input + Apply that subtracts the entered damage (die rolled physically), floors charges at 0, and at 0 drops the barrier (activeFace=null, theme link removed, ticker hidden) + save(). GATE: the toggle is enabled only when activeFace is 4 or 5; switching to a low face (1-3) or dropping the barrier auto-collapses and disables it.

### How (TDD)
- RED: extended test/e2e/cube-widget.spec.js with 8 tests [m]-[t] (ticker hidden/visible/restore/32s+bold, accordion gate/auto-close, Apply subtract, Apply→0 drops barrier). Confirmed 7 failing for the right reason.
- GREEN: ticker div in index.html, ticker+accordion CSS in cube.css, ticker/drain/gate logic in modules/cube.js.
- Verify: `npm test -- cube-widget critical-path` → 44 passed.

### Red lines respected
app.js, styles.css and themes/ untouched; specs extended in cube-widget.spec.js (no new file). Only the 4 `files` entries changed.


## Task 510 — refactor(styles): tokenize ambient hardcoded colors behind :root custom properties (zero visual change)

**Repo:** combat (monk_combat_app) · **Lane:** tokens · **Branch:** ralph/task-510 · **Commit:** 8a3f427

### What
Established the CSS custom-property contract that the Cube of Force face themes (task 520) will override. Moved all AMBIENT hardcoded colors (surfaces, borders, text nuances) in `styles.css` behind `:root` tokens, with **zero visual change** — every hardcoded value was replaced by `var(--token)` whose token holds the exact same value.

### Changes
- **styles.css**: added 52 new ambient tokens to `:root` (grouped: neutral text `--text-white/-bright/-soft/-mute-1..3`, tinted text `--text-lav-1..5`/`--text-slate`, borders `--border-1/-2/-slate/-notes`, `--pill-border`, `--card-border`, tab/subtab border+bg tokens, `--rule-accent`, surfaces `--input-bg`, `--surface-pill/-textarea/-card/-card-hover/-feat-body/-notes/-hover`, `--btn-bg/-alt-bg/-alt-bg-hover`, `--field-bg`, `--modal-bg/-textarea-bg/-btn-hover`, `--flavor-hover-bg`, `--tooltip-bg`, `--alias-th/-even/-odd-bg`, `--collapse-bg`, and `--feat-head-bg-hover/-border-hover`). Replaced every ambient hardcoded usage with `var(--...)`.
- **tabs/stats-basicinfo.html**: inline `background:#101323` → `background:var(--surface-textarea)`.
- **tabs/inventory.html**: intentionally untouched — its sole inline hex `#e05252` is the danger fallback in `var(--danger,#e05252)` (semantic; red line #1).

### Red lines honored
- Semantic colors left hardcoded: coins (#FFD700/#C0C0C0/#B87333/#E5E4E2 + rgba), success greens (#22c55e family, #5ae09f, #2d6245, #224a34, #1f6f3e, #2ab773, #4a7a55, #7ecb7e...), danger reds (#4a2730, #6b1f27, #ff5b73, #8d1f29, #b71c1c, #ff6b6b/#ffaaaa, you-died reds, rgba(255,0,0,...)), cleric/monk purple & orange (#9b8fff, #9b59f6, #c084fc, #dc78ff, #c8c0ff, #f0a030, #7c9ef8, rgba(155,143,255,...), rgba(240,160,48,...)). Also left: box-shadow colors and translucent black/white overlays (theme-neutral).
- Zero visual change: each `var()` resolves to its original literal → computed values byte-identical. Verified programmatically that every mapped ambient value now appears exactly once in styles.css (its `:root` definition) and no raw hex remains in the touched partial.
- Only styles.css + the two partials in scope; no @import, no themes/ references.

### Verification
- No unit infra in combat repo (test:unit absent); did NOT run Playwright/serve (shared port 45278 — the post-merge gate runs e2e incl. styles.spec.js characterization net). Correctness rests on byte-identical construction + script self-check.

### Notes for next lanes
- The `:root` ambient token set is the theming contract for task 520 (fog/stone/moss/arcane/bastion). All ambient surface/border/text tokens are now in one place at the top of styles.css.


## [2026-08-03 00:00] - Task #530: feat(cube): add Cube of Force floating widget with charges, faces dialog and theme switching

**Status:** ✅ Complete

**Repo:** combat · **Lane:** cube · **Branch:** ralph/task-530 · **Commit:** 17e8403

**TDD Phase:** RECON → RED → GREEN → DONE

**Problem:** Core of the Cube of Force feature — a floating widget on the right wall with a charges/faces dialog that themes the whole app by swapping a stylesheet link.

**What was done:**
- RED: wrote test/e2e/cube-widget.spec.js (12 scenarios a–l): peek state, click1->expand/click2->dialog/✕->peek, Activate Face 2 (36->34) creates #cubeThemeLink -> themes/stone.css as last <head> child + persists st.cube, already-active face disabled, switch to Face 5 (->29, bastion.css), Deactivate removes link with charges unchanged, Regain adds+caps at 36, Activate disabled when charges<cost, Minute Elapsed drops barrier with no cost, reload with active barrier restores link+charges (arcane.css), vertical drag moves widget without opening dialog.
- GREEN: modules/cube.js (IIFE, DOMContentLoaded init) builds the widget + dialog in JS, manages the single id=cubeThemeLink element (create/append-last on activate, remove on deactivate/minute/drain-to-0), pointer-event vertical drag with 5px click threshold clamped to viewport, activate/deactivate/minuteElapsed/regain all call window.save(). cube.css holds all widget/dialog styles (z-index 800/900 — above tabs, below .modal=1000 and #youDiedOverlay=9999). index.html gets <link href=cube.css> + <script src=modules/cube.js> before app.js. app.js: one line — cube: { charges: 36, activeFace: null } in defaultState (persistence + Bundle v2 come for free via the existing {...defaultState, ...saved} merge).

**Verification:**
- node --check modules/cube.js → OK; spec parses as ESM → OK.
- e2e (npm test -- cube-widget critical-path) is the post-merge gate's job (port 45278) — not run by the agent per repos.json/structure-reference red line.
- themes/*.css are NOT created here (lane themes / task 520); the spec asserts only the link href/presence, and a 404 on the link doesn't break the page (per spec notes).
- Existing specs unaffected: cube.css only targets .cube-*/#cubeWidget/#cubeDialog; import/export round-trips st.cube symmetrically.

**Files modified:**
- modules/cube.js (new)
- cube.css (new)
- index.html
- app.js
- test/e2e/cube-widget.spec.js (new)

**Git commit:** `17e8403` — `feat(cube): add Cube of Force floating widget with charges, faces dialog and theme switching`

---


## Task 470 — feat(maps): add per-row preview button and viewer zoom buttons

**Repo:** inventory · **Lane:** maps · **Branch:** ralph/task-470 · **Commit:** d930167

### What
Two linked additions so the party can preview a map without entering edit mode and can zoom on a tablet where wheel/pinch aren't obvious:
1. **Per-row preview button** — `renderMaps()` now emits a `🔍` button first in `.tbl-actions` (before ✏/🗑). New `export async function previewMap(i)`: `syncMsg('Зареждане…','saving')`, `getDoc(mapImageDoc(m.id))`; on a doc with `.image` → `openViewer(image)` + `syncMsg('● live','saved')`, otherwise `syncMsg('Няма снимка за тази карта','')`. It never opens the modal or touches `state.editingMapIdx`, and re-fetches fresh every press (no cache). The existing row-click accordion guard `closest('button, .drag-handle')` already stops 🔍 from toggling the row.
2. **Viewer +/- zoom buttons** — `ensureOverlay()` now builds a `.viewer-zoom-bar` with `.viewer-zoom.viewer-zoom-out` (➖) and `.viewer-zoom.viewer-zoom-in` (➕), each `stopPropagation()`-ing (so a click never triggers backdrop-close) and calling a new `zoomButton(factor)` → `zoomAt(view, 1.4 | 1/1.4, centreX, centreY)` + `applyTransform()`. Clamp [1,8] comes from `zoomAt`. In jsdom the rect is 0×0 so the centre is (0,0) and the transform still updates.

`app.js`: `window.previewMap = previewMap` + facade re-export. `styles.css`: `.viewer-zoom-bar` (fixed bottom-centre flex row, gap) and `.viewer-zoom` (44px touch targets, translucent like `.viewer-close`).

### Tests
TDD: wrote 7 RED tests first (confirmed failing for the right reason), then implemented.
- `test/unit/maps.spec.js`: 🔍 is first in `.tbl-actions` before ✏; clicking 🔍 doesn't expand the row; `previewMap(0)` with a seeded image doc opens `#mapViewer` (display flex, correct img src) without opening `#mapModal`; `previewMap` with no image doc leaves the viewer closed and puts 'Няма снимка' in `#sync`.
- `test/unit/viewer.spec.js`: overlay exposes `.viewer-zoom-in`/`.viewer-zoom-out`; + zooms in and − zooms back; − at scale 1 stays clamped at 1; repeated + never exceeds scale 8.

### Verify
`npm run test:unit` → **132/132 passed** (125 prior + 7 new). e2e not run by agent (port 45279 is the gate's); `git diff` confirms `test/e2e/` and `test/fixtures/` are untouched (maps-fixture keeps its edit-by-index accordion spec).


## Task 460 — feat(maps): add static world map link above the add button

**Repo:** inventory · **Lane:** maps · **Status:** ✅ done

Added a static external link to the full Immortal Empires Factions world map, placed ABOVE the `+ Добави карта` button inside `#tab-maps`.

- **RED:** Added `maps — static world map link` describe to `test/unit/maps.spec.js` — asserts `#tab-maps a.map-world-link` exists, `href` is exactly `https://totalwarwarhammer.fandom.com/wiki/Map:Immortal_Empires_Factions`, `target="_blank"`, `rel` contains `noopener`, and the link precedes `.controls` in DOM order (compareDocumentPosition). Failed for the right reason (link absent).
- **GREEN:** `index.html` — inserted `<div class="map-world-row"><a class="map-world-link" href="…" target="_blank" rel="noopener">🗺 Immortal Empires Factions — пълната карта</a></div>` above `.controls`. `styles.css` — `.map-world-row { text-align:right; margin-bottom:6px; }` and a muted `.map-world-link` (0.85rem, no underline, hover underline). Pure static markup, no JS/Firestore.
- **Verify:** `npm run test:unit` → 11 files, 124 tests passed. Only `index.html`, `styles.css`, `test/unit/maps.spec.js` touched.

Commit: `37b3802`


## Task 450 — test(maps): add e2e fixture and accordion spec for the Maps tab

**Repo:** inventory · **Lane:** maps · **Commit:** b59c69a

Final task of the maps lane. Added two new files (both explicitly permitted by §9, existing e2e/fixtures untouched):

- `test/fixtures/maps-fixture.html` — standalone HTML mirroring `quests-fixture.html`: base table/button styles + the `.map-short`/`.map-details`/`tr.map-expanded` rules copied 1:1 from `styles.css`, a `#mapTable`/`#mapBody` table, and an inline script with 2 maps (map 1 has multi-line short + details for the ellipsis clamp) rendered via a `renderMaps`-mirroring accordion (exactly one expanded row, button/.drag-handle clicks don't toggle). No image in the fixture (not shown in the table by design).
- `test/e2e/maps-accordion.spec.js` — mirrors `quests-accordion.spec.js`: FIXTURE `/test/fixtures/maps-fixture.html`, waits for `#mapBody tr[data-idx]`, 6 tests (details overflow hidden, starts collapsed, click expands, re-click collapses, only one expanded at a time, edit button doesn't expand).

Reviewed tasks 410-440 output: `styles.css` map rules and `modules/maps.js` renderMaps were already correct/complete, so no touch-ups required in the shared-ownership files. Agent did not run `npm test` (port 45279 is the gate's); regression `npm run test:unit` green — 122/122 across 11 files. Full Playwright suite incl. the new spec runs at the merge gate.


### Task #440 — feat(maps): add fullscreen map viewer with wheel zoom, drag pan and pinch zoom

**Repo:** inventory · **Lane:** maps · **Branch:** ralph/task-440 · **Commit:** 37c0f69

**What:** Implemented the final interactive piece of the Maps feature — a reusable fullscreen image viewer for the party's tablet/phone.

- `modules/viewer.js` (new): pure geometry `clampScale(s)` → [1,8] and `zoomAt(view, factor, cx, cy)` (keeps the point under the cursor fixed, transform-origin 0 0). Thin DOM/event layer on **Pointer Events** (one path for mouse + fingers): wheel zoom toward the cursor (preventDefault), single-pointer drag pan, two-pointer pinch (zoomAt around the midpoint), dblclick → reset, Esc / backdrop click / ✕ button → close. `#mapViewer` overlay is created once on first `openViewer` and reused via display toggle.
- `modules/maps.js`: import `openViewer`; wire a one-time click listener on the static `#mPreview` → `openViewer(pendingImage || preview.src)`.
- `app.js`: facade re-export `{ zoomAt, clampScale, openViewer, closeViewer }` from viewer.js.
- `styles.css`: `#mapViewer` overlay (fixed, inset 0, z-index 200 above modals, touch-action:none), `#mapViewer img { transform-origin:0 0 }`, and the ✕ close button.
- `test/unit/viewer.spec.js` (new): geometry (zoomAt exact + fixed-point invariant + clamp + reversible round-trip) and overlay lifecycle (create-once, show/hide, Esc, backdrop click, dblclick reset).

**Verify:** `npm run test:unit` → 11 files, 122 tests, all green (new viewer spec + existing 410–430 maps specs + baseline). No e2e/serve run (port 45279 belongs to the gate). Scope limited to the 5 owned files.


## Task 430 — feat(maps): add map dialog with file upload, clipboard paste, required descriptions and Firestore persistence

**Repo:** inventory · **Lane:** maps · **Branch:** ralph/task-430 · **Commit:** 08d9f64

### What
Implemented the Maps modal (task 3 of the maps lane), the DM's upload/paste/persist dialog.

- **index.html:** added `#mapModal` (mirrors questModal) — `#mShort` (Кратко описание *), `#mDetails` (Детайли *), `#mFile` file input (`accept="image/*"`, `onchange=handleMapFile`) + Ctrl+V hint, `#mPreview` image, `#mMapError` (gold-error pattern), Отказ/Запази buttons.
- **styles.css:** `.map-preview` (max 200px, zoom-in cursor, radius), `.map-preview.hidden`, `.field-hint`.
- **modules/ui.js:** `initModalBackdrops` array now `['itemModal','questModal','mapModal']` (only change).
- **modules/maps.js:** module `pendingImage`; `processImageBlob` pipeline (blobToDataUrl → compress only when `needsCompression` → second pass 1200/0.6 → error, save blocked); `handleMapFile`/`handleMapPaste` (paste guarded to open modal only, document-level listener); `openMapModal(idx)` (edit lazy-loads image via `getDoc(mapImageDoc(id))`); `saveMap` (required both descriptions with focus; `crypto.randomUUID()`; `setDoc(mapImageDoc(id), {image})` only when a new image is staged; unshift meta {id,shortDesc,details,createdAt}; `saveMapsIndex`); `deleteMap` (confirm → `deleteDoc` + splice + index rewrite).
- **app.js:** import + `window.` wiring for closeMapModal/saveMap/handleMapFile (open/edit/delete already present).
- **test/unit/maps-modal.spec.js:** 13 characterization tests; partial `vi.mock('../../modules/image.js')` keeping blobToDataUrl/needsCompression/MAX_IMAGE_BYTES real and mocking `compressImage`; `beforeEach` resets the persistent mock.

### Verify
`npm run test:unit` → **109/109 green** (10 files, incl. new 13 + all pre-existing). No e2e/serve run (port 45279 is the gate's). Scope limited to the task's `files` list.

### Notes
- Compression is applied only above the base64 threshold — small images keep original quality (per user requirement).
- The mocked `compressImage` survives `vi.resetModules`, so its call count + resolved value are reset per test to avoid cross-test leakage.
- Firestore `maps` security rules remain a manual owner step (not agent scope).


## Task 420 — feat(maps): add Maps tab with realtime table, ellipsis descriptions and accordion expand

**Repo:** inventory (shared-inventory) · **Lane:** maps · **Branch:** ralph/task-420 · **Commit:** 4305256

**What:** Second task of the maps lane — the read/list UI on top of task 410's data layer.
- `index.html`: added `<button data-tab="maps">Карти</button>` to the nav and a `#tab-maps` section with a `+ Добави карта` control (`onclick="openMapModal()"`) and `#mapTable`/`#mapBody` (columns ☰ | Карта | Детайли | actions). No image column by design — screenshots live in separate `maps/<id>` docs and are not pulled when listing.
- `styles.css`: `.map-short`/`.map-details` ellipsis clamp (mirrors `.quest-desc`/`.quest-note-cell`) and `tr.map-expanded` expansion (details `white-space: pre-wrap`).
- `modules/maps.js` (new): `renderMaps()` (empty state „Няма качени карти.", rows with escaped shortDesc in `<strong>` + `div.map-details`, ✏/🗑 actions, quest-pattern accordion with exactly one expanded row that survives re-render via `state.expandedMapIdx`, `initSortable('mapBody', …, saveMapsIndex)`), `saveMapsIndex()` (`state.savingMaps` flag + `setDoc(MAPS_INDEX_DOC, {list})` + syncMsg), and `openMapModal`/`editMap`/`deleteMap` stubs for task 430.
- `app.js`: `onSnapshot(MAPS_INDEX_DOC, …)` with `savingMaps` echo guard, `window.openMapModal/editMap/deleteMap`, facade re-export `{ renderMaps, saveMapsIndex }`, and `maps` added to `getState`/`setState`.
- `test/helpers/dom.js`: `bootApp` extended additively with `maps = null` → emits `maps/index` (default `null` keeps all existing specs green).
- `test/unit/maps.spec.js` (new): render (2 rows, strong/`.map-details`), empty state, `esc()` (`<img>` escaped), accordion (expand/collapse, single-expanded, button-in-row doesn't toggle, survives re-render), and the `savingMaps` snapshot echo guard.

**Verify:** `npm run test:unit` → 9 files, 96 tests passing, 0 errors (the 6 pre-existing specs stay green; boot now emits `maps/index` null → `renderMaps()` on the static `#mapBody`).

**Notes:** The accordion "button doesn't toggle" test strips the inline `onclick` before clicking — jsdom compiles inline handlers in its own realm so globals like `editMap` don't resolve there (works in a real browser); this is why the repo's other specs never `.click()` inline-`onclick` buttons. No serve/e2e run from the agent (port 45279 belongs to the gate).


## Task 410 — feat(maps): add maps data layer with index and image doc refs, image fit helpers and mock data store

**Repo:** inventory (shared-inventory) · **Lane:** maps · **Branch:** ralph/task-410 · **Commit:** 193703a

**What:** Laid the pure data foundation for the Maps tab (lane maps, tasks 410–450). No UI yet — only the data layer, image helpers and the additive mock store extension.

**Changes (6 files, all in scope):**
- `modules/image.js` (new): `MAX_IMAGE_BYTES = 900000`, `needsCompression(len)` (threshold on data URL length, base64 ~33% inflate vs 1MiB Firestore cap), `blobToDataUrl(blob)` (FileReader Promise, jsdom-safe), pure `fitDimensions(w, h, maxDim=1600)` (aspect-preserving, never upscales, Math.round), and a thin `compressImage(blob, {maxDim, quality})` canvas wrapper (createImageBitmap + Image fallback; body untested per spec — no canvas in jsdom).
- `modules/firebase.js`: added `MAPS_INDEX_DOC = doc(db,'maps','index')` and `mapImageDoc(id)` exports. firebaseConfig untouched, CDN imports intact.
- `modules/state.js`: added `maps: []`, `editingMapIdx`, `expandedMapIdx`, `savingMaps`.
- `test/mocks/firebase-firestore.js`: ADDITIVE store (`Map` token→data); `setDoc` now also writes to it; `getDoc(token)` returns `{ exists: () => store.has(token), data: () => store.get(token) }`; new `__setDocData(token, data)` seeder (no calls entry); `__reset()` also clears the store. Existing exports/behavior toward old specs unchanged — an unseeded token still reads `exists:false`.
- `test/unit/image.spec.js` + `test/unit/firestore-mock.spec.js` (new): written RED first (image.js missing / __setDocData missing), then GREEN.

**TDD:** RED verified for the right reasons (unresolved import + missing export), then implemented to green.

**Verify:** `npm run test:unit` → 88 tests / 8 files, all green (6 pre-existing suites remain green, 2 new). e2e/serve/gitnexus not run (agent scope). Firestore security rules for the `maps` collection remain a manual owner step (per plan).


## Task 90 — docs: add Google Cloud TTS setup guide with voice audition and API key restriction steps

- **Repo:** combat (monk_combat_app) · **Lane:** tts · **Branch:** ralph/task-90 · **Commit:** 88ea67e
- **Files:** `TTS-SETUP.md` (new)
- **Какво:** Създаден е потребителски setup гайд на български, който води от нула до работещ глас за бутона „🔊 Произнеси". Шест секции: (1) създаване на ключ + честна бележка за задължителния billing account; (2) заключване на ключа по HTTP referrers (GitHub Pages + `http://localhost:45278/*`) и restrict само до Cloud Text-to-Speech API; (3) избраните гласове `bg-BG-Chirp3-HD-Sadaltager` / `en-US-Chirp3-HD-Sadaltager` + curl команда със задължителен `Referer` хедър за списъка гласове, плюс проверените Chirp3-HD ограничения (pitch/prompt дават 400); (4) безплатен слой и цена (~7% от квотата за целия корпус); (5) точните `TTS_CONFIG` полета (apiKey/voices/speakingRate/breakMs, изрично БЕЗ pitch); (6) поведение без ключ — fallback към speechSynthesis + бележка под бутона.
- **Червени линии:** истинският API ключ НЕ е в документа (само `API_KEY` плейсхолдър — grep потвърди 0 съвпадения за `AIzaSy`); пипнат е само `TTS-SETUP.md`, никакъв код/тест/runtime боклук.
- **Verify:** docs-only — няма unit инфраструктура за markdown; пълният `npm test` гейт на репото е задната мрежа след merge (без verify override, нарочно).


## Task 80 — fix(tts): harden mobile playback with autoplay priming, request aborts and visible error state

**Repo:** combat (monk_combat_app) · **Branch:** ralph/task-80 · **Commit:** aeba79e

### Какво е направено
1. **Autoplay priming** — `modules/tts.js` вече ползва ЕДИН преизползван `<audio>` елемент (`getAudioEl()`), който се `play()`-ва синхронно още в user-gesture-а преди async fetch-а. При NotAllowedError от play() UI-ът се възстановява (onend се вика, `speaking=false`), вместо да увисне в 'Спри'.
2. **Abort на заявки в полет** — `AbortController` per заявка; `synthesize(text, signal)` подава signal-а на fetch; `stop()` го abort-ва. AbortError се игнорира тихо — без лог, без fallback към speechSynthesis. Добавена и ръчна `signal.aborted` проверка след await (за стъбове, които игнорират signal-а).
3. **Видимо състояние при грешка** — `onend(reason)` с reason `'no-key' | 'network' | null`. `modules/flavor.js` показва `#flavorTtsNote` с различно съобщение при липсващ ключ vs мрежова грешка, и го скрива при успех / при нова реплика.
4. **API ключ seam** — `activeKey()` чете `window.__ttsApiKeyOverride` ако е зададен (само за тест на no-key пътя), иначе комитнатия ключ. Прод поведението непроменено.

### Тестове
- `test/e2e/tts-core.spec.js`: +записване на AbortSignal-ите, +test (и) priming/NotAllowedError, +test (й) втори speak abort-ва първия в полет.
- `test/e2e/flavor-tts.spec.js`: +test (ж) 403 → бележката видима, +test (з) успех → бележката скрита, +test (и) no-key → различно съобщение от network.
- `npm test -- tts-core flavor-tts flavor-ui critical-path` → **66 passed**.

### Червени линии
app.js и test/e2e/flavor-ui.spec.js НЕ са пипани. styles.css и tabs/flavor.html не се наложи да се променят (`.flavor-tts-note` и note елементът вече дойдоха с таск 70). Само добавяне в собствените спекове, без пренаписване на минаващи тестове.


## Task 70 — feat(flavor): add Speak button that voices the current flavor line through MonkTTS

**Repo:** combat (monk_combat_app) · **Lane:** tts · **Commit:** f7d7c34

### What changed
- **tabs/flavor.html**: added `<div class="flavor-actions">` right after `#flavorOutput` with `#btnSpeakFlavor.flavor-speak` (label '🔊 Произнеси') and a hidden `#flavorTtsNote` span (for task 80).
- **modules/flavor.js**: added `attachSpeak()` (toggle click handler — reads trimmed `#flavorOutput`, no-op on empty, syncing button to '⏹ Спри' + `.speaking` while talking, calls `MonkTTS.speak(text, {onend: resetSpeakBtn})` synchronously in the gesture; disables the button with a title when MonkTTS is missing/unsupported), `resetSpeakBtn()`/`stopSpeaking()` helpers, called `attachSpeak()` at the end of `window.attachFlavor`, and prepended `stopSpeaking()` to `showLine()` so a new line resets the button.
- **styles.css**: added `.flavor-actions`, `.flavor-speak` (48px touch target, pill family), `.flavor-speak:hover`, `.flavor-speak.speaking` (var(--accent)), `.flavor-speak:disabled`, `.flavor-tts-note` in the Flavor section — additive only.
- **test/e2e/flavor-tts.spec.js** (new): stubs fetch + inert `Audio` + speechSynthesis via addInitScript. 6 tests: button exists & is not `.flavor-btn`; still exactly 17 `.flavor-btn`; empty output makes no request; flavor+speak makes exactly one TTS request with XML-escaped text in ssml; speaking shows 'Спри' + `.speaking`; clicking another flavor button returns to 'Произнеси'.

### Red lines respected
- app.js NOT touched (attachFlavor already invoked from it).
- test/e2e/flavor-ui.spec.js NOT touched; new button uses `.flavor-speak`, so the '17 .flavor-btn' assertion stays green.
- styles.css changes are additions only, inside the Flavor section.

### Verify
`npm test -- flavor-tts flavor-ui` → **27 passed**.


## Task 60 — feat(tts): add on-demand Google Cloud TTS module with SSML mocking delivery and speechSynthesis fallback

**Repo:** combat (monk_combat_app) · **Lane:** tts · **Commit:** 0ec2400 · **Tests:** `npm test -- tts-core` → 9 passed

### What
- **modules/tts.js** — new `window.MonkTTS = { speak, stop, isSpeaking, isSupported }` IIFE. On-demand only, no cache, no .mp3 in repo.
  - `TTS_CONFIG` at top with the committed (HTTP-referrer-restricted) API key, per the firebase.js precedent. **No `pitch` field** — Chirp3-HD returns HTTP 400 for pitch; a test guards its absence.
  - `detectLang` (Cyrillic → `bg-BG`, else `en-US`), voices locked to `bg-BG-Chirp3-HD-Sadaltager` / `en-US-Chirp3-HD-Sadaltager` (MALE).
  - `escapeXml` + `buildSsml`: splits on strong punctuation (weak only if piece ≥18 chars), inserts `<break time="350ms"/>` drama pauses, wraps the final piece in `<prosody rate="80%">` for the drawl (no pitch attr).
  - `synthesize`: POST to `texttospeech.googleapis.com/v1/text:synthesize` with `input.ssml`, `voice.{languageCode,name,ssmlGender:MALE}`, `audioConfig.{audioEncoding:MP3, speakingRate:0.85}` (no `prompt`). base64 → Blob → objectURL → Audio.play().
  - Always revokes the object URL on ended/error/stop; `onend` always fires. Fallback to `speechSynthesis` on placeholder key, non-2xx, missing audioContent, or network error.
- **index.html** — added `<script src="modules/tts.js"></script>` before `modules/flavor.js` in the module block.
- **test/e2e/tts-core.spec.js** — 9 tests. Stubs `window.fetch` (records TTS calls, returns tiny base64) and `speechSynthesis` (deterministic onend in headless) via `addInitScript`. Asserts request FORMAT only: endpoint/method, bg/en languageCode, MALE, voice.name, SSML `<speak>`+`<break>`, `&apos;`/`&amp;` escaping, MP3 + speakingRate<1, absence of `pitch` and `prompt`, 403→fallback (onend fires, no throw), and empty text → no request.

### Notes
- Only touched the task's `files` (index.html, modules/tts.js, test/e2e/tts-core.spec.js). app.js and other modules/specs untouched. Real key lives only in modules/tts.js.
- **Env fix:** a stray `http-server` from the MAIN checkout (`C:\Users\kaloyan.georgiev\Projects\monk_combat_app`) was listening on 45278; Playwright's `reuseExistingServer` reused it and served an index without tts.js (404), failing all tests against the wrong app. Stopped that stray PID so Playwright booted its own server from the worktree; all 9 tests then passed.


## Task #50 — fix: unify familiar records into st.familiars so export/import round-trips them like aliases and npc names

**Repo:** combat (monk_combat_app) · **Lane:** bugfix · **Commit:** `3e7d9b4`

**Bug (prod, user-reported):** Saving a record in each of the three Names tables → export → delete → import restored alias and npc but NOT familiar. Cause: familiar records lived in a standalone `localStorage['familiars_v1']` key *outside* `st`, and the export/import bundle only packages `st`.

**Fix (4 files, all in scope):**
1. `modules/namegen.js` — familiar store adapter now reads/writes `window.st.familiars` + `window.save()`, identical to the alias/npc adapters. Record schema `{name, cat, note, ts}` unchanged.
2. `modules/namegen.js` — added a defensive one-time `migrateFamiliars()` at the top of `attachNamegen()`: moves any legacy `familiars_v1` records into `st.familiars`, `save()`s *first*, then removes the old key; merges by `ts` if both hold data; leaves invalid JSON untouched. Live characters keep their familiars, which now also cloud-sync.
3. `app.js` — deleted the dead, never-called `stripTransientState` (confirmed zero call sites) that misleadingly implied familiars were transient.
4. Tests — updated the familiar-routing test to assert `st.familiars`, added a migration test (seed `familiars_v1` → reload → row visible, `st.familiars` populated, old key deleted), and added an import-export familiar bundle round-trip test.

**Verification:** Static review of the retained commit; `st.familiars` is wired through defaultState/applyBundle/buildBundle; only remaining `familiars_v1` refs are the read-then-delete migration path. The retry gate's single red — `rest-mechanics.spec.js:240` (multi level-up on Long Rest) — is out of scope and unrelated: a pre-existing timing flake (4 chained modal→observer-click cycles within `waitForTimeout(600)`, `retries:0`, shared server under parallel-mode load). Not caused by this change.


## Task #44 — chore: final sweep after Name Gen consolidation - rename label, navigation spec, bundle check and docs

**Repo:** combat (monk_combat_app) · **Lane:** generators · **Branch:** ralph/task-44 · **Commit:** 606e92b

### What changed
- **index.html:** renamed the `data-tab="namegen"` button label from `Name Gen` to `Names` and moved it to the end of `.tab-nav`; final order is Stats, PC Characteristics, Resurrection, Inventory, Flavor, Skills, Session Notes, Names. `data-tab="namegen"` unchanged (specs depend on it).
- **styles.css:** removed dead rules for the removed tabs — `#tab-shenanigans input[readonly]`, `#tab-shenanigans .one-liner-box(+button)`, `#btnGetName`, `#btnSaveAlias`, and the `#tab-npc-names .one-liner-box` responsive block. `.alias-table` kept (still used by the Names log).
- **test/e2e/import-export.spec.js:** the round-trip fixture no longer clicks the removed Shenanigans/Familiars tabs; it now generates+saves an alias and a familiar through the Names tab (`#genGenerate`, `#genTypeButtons`, `#genFamGroups`, `#genAlias*`/`#genFam*` modals). Bundle round-trip assertions unchanged (st.aliases still in bundle; familiar log stays in `familiars_v1` outside the bundle — existing behavior).
- **test/e2e/tabs-navigation.spec.js:** reordered the `All tabs are clickable` list so `namegen` is last (1:1 with the real nav) and added two tests — the button label reads `Names`, and the Names tab opens with `#genOutput` + the type buttons.
- **BEHAVIOR_DOCUMENTATION.md / TEST_CASES.md:** replaced the separate Shenanigans / Familiar Names / NPC sections with one `Names (Name Gen)` section documenting the 3 generators, save routing (alias→st.aliases, familiar→localStorage['familiars_v1'], npc→st.npcNames), per-type sub-UI and the 3 Save modals; updated the JSON-files list (shenanigans/familiars/npc-names now feed the Names tab) and the TOC/summary counts.

### Verify
- Residue grep (attach*/btn*/data-tab of the 6 removed tabs, fakeNameOutput/famNameOutput/npcNameOutput) → 0 hits in code.
- data-loading.spec.js already covers all five flavor JSONs + familiars + npc-names through the two new tabs (no change needed).
- styles.css brace balance verified (290/290). app.js namegen wiring intact (tabMap + attachNamegen guard).
- Repo is e2e-only (no `test:unit`); Playwright e2e intentionally left to the post-merge verify gate.
- Scope: only the 6 touched files, all within task #44's `files` list.


## Task #43 — refactor: remove legacy NPC Names tab superseded by Name Gen tab

**Repo:** combat (monk_combat_app) · **Branch:** ralph/task-43 · **Commit:** b0c8091

### What
Removed the legacy standalone NPC Names tab now that the consolidated **Name Gen** tab covers NPC name generation writing to the same `st.npcNames` store.

### Changes
- **index.html:** removed `data-tab="npc-names"` button, `#tab-npc-names` div, and `<script src="modules/npc-names.js">`.
- **app.js:** removed `'npc-names'` from `tabMap`, the `attachNpcNames()` boot call, and the now-dead `window.renderNpcNamesUI?.()` hook in `save()`. Kept `st.npcNames` default + normalization (lines ~131/782/1117) — Name Gen persists there.
- **Deleted:** `modules/npc-names.js`, `tabs/npc-names.html`, `test/e2e/npc-names.spec.js` (coverage now via namegen-ui.spec.js).
- **test/e2e/tabs-navigation.spec.js:** removed `'npc-names'` from the clickable-tabs list (now 1:1 with the 8 real tab-nav buttons).
- **test/e2e/data-loading.spec.js:** added a `Data Loading - NPC Names (npc-names.json via Name Gen)` describe block verifying npc-names.json loads and produces varied names through the NPC type of Name Gen.
- **styles.css:** untouched — not in the task `files` scope, and `.npc-options`/`.npc-fieldset` are reused by Name Gen's NPC sub-UI.

### Verify
- `grep` for `attachNpcNames|btnGenerateName|tabs/npc-names|renderNpcNamesUI` → 0 hits in code (only the retained `npc-names.json` fetch in modules/namegen.js remains).
- `node --check` clean on app.js and the edited specs.
- Combat repo has no unit infrastructure; e2e (`npm test`) is left to the post-merge verify gate on port 45278.


## Task #42 — refactor: remove legacy Familiars tab superseded by Name Gen tab

**Repo:** combat (monk_combat_app) · **Lane:** generators · **Commit:** f571298

### What
Removed the legacy Familiars tab now that Name Gen (task 40) covers familiar generation over the same store.

- **index.html:** removed `<button data-tab="familiars">`, `<div id="tab-familiars">`, and `<script src="modules/familiars.js">`.
- **app.js:** removed `'familiars'` from `tabMap`, the `attachFamiliars()` boot call, both `renderFamTable()` call sites (in `save()` and after import), and the entire historical duplicate of the familiars block (`loadFamiliars`, `famPickRandom`, `FAM_LS_KEY`/records helpers, modal, `renderFamTable`, `attachFamiliars`, and the private `escapeHtml` used only by it). The legacy `st.familiars` bundle field (import/export migration) was left untouched — separate live contract, not the tab.
- **modules/familiars.js, tabs/familiars.html:** deleted.
- **styles.css:** untouched — `.fam-btn`/`.fam-groups` are reused by the Name Gen tab.

### Tests
- Deleted `test/e2e/crud-aliases-familiars.spec.js` (only tested the removed tab; namegen-ui.spec.js already covers familiar generate/save/delete via the same FAM_LS_KEY store).
- `tabs-navigation.spec.js`: removed `familiars` from the tab list and the Familiars smoke test.
- `data-loading.spec.js`: routed the familiars.json checks through Name Gen (Familiar type + group buttons → #genOutput); also routed the stale Shenanigans block (task-41 leftover referencing the removed shenanigans tab) through Name Gen's alias generator so the data-loading gate is green.

### Verify
- `node --check` clean on app.js, data-loading.spec.js, tabs-navigation.spec.js.
- e2e not run from agent (shared port 45278 / orchestrator post-merge gate).
- DONE grep: `attachFamiliars`, `tabs/familiars`, `renderFamTable` gone from app code; `btnFamSave` remains only in import-export.spec.js / BEHAVIOR_DOCUMENTATION.md, which are outside task 42's boundary and assigned to task 44's final sweep.


## Task #41 - refactor: remove legacy Shenanigans tab superseded by Name Gen tab

**Repo:** combat (monk_combat_app) · **Lane:** generators · **Status:** done

**What:** Retry of the Shenanigans-tab removal. Predecessor commit `888aa3f` already removed the tab (button, `#tab-shenanigans`, `modules/aliases.js`, `tabs/shenanigans.html`, all alias/shenanigans wiring in `app.js`, `shenanigans-ui.spec.js`, and the Aliases describe in `crud-aliases-familiars.spec.js`) — that work is correct and kept. The verify gate (`namegen-ui tabs-navigation critical-path`) had 1 red: `tabs-navigation.spec.js › Familiars tab shows fam groups and log`.

**Diagnosis:** Task 40's Name Gen tab reuses the `.fam-groups` / `.fam-btn` classes (`<div id="genFamGroups" class="fam-groups hidden">`). `loadTabs()` injects every tab into the DOM at boot, so the Familiars test's unscoped `page.locator('.fam-groups')` matched 2 elements → Playwright strict-mode violation, and `.fam-btn.first()` resolved to Name Gen's hidden button (Name Gen loads before Familiars in tabMap order) → not visible.

**Fix (within #41 files boundary):**
- `test/e2e/tabs-navigation.spec.js` — scoped the Familiars smoke-test class selectors to `#tab-familiars .fam-groups` / `#tab-familiars .fam-btn`.
- `test/e2e/crud-aliases-familiars.spec.js` — defensively scoped the identical `.fam-btn[data-famcat=...]` click selectors to `#tab-familiars` (same latent collision; unique-id locators like `#famNameOutput`/`#famLog`/`.alias-del` are Familiars-only and left untouched — Name Gen uses `.gen-del`).

**Verify:** `node --check` clean on both specs and `app.js`. e2e not run locally (shared ports; post-merge gate owns it). Committed as `e04697f`.

**Out of scope (not touched):** `tabs/namegen.html` / `modules/namegen.js` own the reused classes but are outside #41's `files` list; the fix lives correctly in the test layer.


## Task #40 — feat: add consolidated Name Gen tab with per-type save routing for aliases, familiars and NPC names

**Repo:** combat (monk_combat_app) · **Lane:** generators · **Branch:** ralph/task-40 · **Commit:** 094d691

**What:** New ADDITIVE 'Name Gen' tab consolidating Alias / Familiar / NPC generators into one registry-driven module with a single output zone, Generate/Save buttons and per-type Save modals. Save routes to the CORRECT store based on active type — st.aliases (+window.save), localStorage['familiars_v1'] (FAM_LS_KEY), st.npcNames (+window.save) — reusing the exact record schemas from the old modules so live-character data is visible 1:1. Type switch clears the output, disables Save and swaps the log table; Familiar generates via its 7 group buttons (Generate hidden), NPC via race/gender radios (distinct name attrs to avoid cross-tab radio collision; toblin hides gender).

**Files:** modules/namegen.js (new), tabs/namegen.html (new), test/e2e/namegen-ui.spec.js (new), index.html (tab button + div + script), app.js (tabMap + attachNamegen guard), styles.css (#genOutput sizing, reuses .flavor-btn/.flavor-grid).

**Red lines respected:** old shenanigans/familiars/npc-names tabs & modules NOT touched (removed later in 41-43); no persistence schema/key changes; no runtime artifacts committed.

**Verify:** node --check on namegen.js + app.js green. e2e (npm test -- namegen-ui critical-path) left to the post-merge gate (shared port 45278).


## [2026-07-18 07:35] - Task #34: chore: final sweep after Flavor consolidation - navigation spec, docs and dead code check

**Repo:** combat (monk_combat_app) · **Lane:** flavor · **Branch:** ralph/task-34 · **Commit:** 7ffac26

**Status:** ✅ Complete

**Problem:** Task 34's in-scope work was already done, but the verify gate kept bouncing the task on `attack-bonuses.spec.js:111` ("Attack bonuses update on level up"). Root cause: predecessor agents edited SIX e2e specs OUTSIDE task 34's `files` scope — they removed the `beforeEach` pollers (present on `main`) that auto-click cardMonk to dismiss the multiclass level-up modal, and replaced attack-bonuses' poller with a fragile explicit 4-click loop that went red under full-suite load. The multiclass modal was introduced by a separate task (`ebf0b41`), not the flavor work, so `main`'s pollers are the correct handling.

**What was done:**
- Reverted the six out-of-scope specs to `main` (`git checkout main --`): attack-bonuses, derived-values, import-export, npc-names, proficiency-toggles, skills-features — restoring the working level-up-modal pollers and the data-driven npc name pools. Branch diff vs main is now ONLY the four in-scope files.
- 34.1 RECON: project grep for `attachOneLiners|attachExcuses|attachInsults|btnCritMiss|btnExLifeWisdom|btnGenerateInsult|olCritMiss|exLifeWisdom|tabs/liners|tabs/excuses|tabs/insults` → 0 code matches (only legit Flavor section labels + `*.json` data-source references remain).
- 34.2: `tabs-navigation.spec.js` has 'Can click Flavor tab' and an 'All tabs are clickable' list 1:1 with index.html (stats, pcchar, resurrection, inventory, shenanigans, flavor, familiars, skills, sessionNotes, npc-names — quests commented out at index.html:117). `data-loading.spec.js` covers all 5 Flavor JSONs (one-liners, excuses, insults, dark-jokes, tasha-jokes) via correct `data-flavor` ids verified against modules/flavor.js.
- 34.3: `BEHAVIOR_DOCUMENTATION.md` §5.5 collapsed to a single Flavor tab section (17 types / clear+random+active / 5 JSON sources) with sections renumbered; `TEST_CASES.md` §16 FLAVOR TAB added (main had no separate old-tab sections). No stale One-Liners/Excuses/Insults UI sections remain (§15 headers are data-file references, valid).
- 34.4: `index.html`/`app.js`/`styles.css` byte-identical to main → no in-scope dead code; `.one-liner-box` kept (shared class still used by #tab-npc-names and #tab-shenanigans).

**Verification:**
- Static review of specs only — e2e is forbidden by task step 34.1 ("npm е забранен за e2e — само прегледай спековете статично") and shared-port policy.
- Branch diff vs main = exactly the 4 in-scope files (BEHAVIOR_DOCUMENTATION.md, TEST_CASES.md, test/e2e/data-loading.spec.js, test/e2e/tabs-navigation.spec.js).
- Sole gate blocker `attack-bonuses.spec.js` restored to its green `main` version (poller-based modal dismissal).

**Files modified:**
- BEHAVIOR_DOCUMENTATION.md
- TEST_CASES.md
- test/e2e/data-loading.spec.js
- test/e2e/tabs-navigation.spec.js
- (reverted to main, out-of-scope cleanup) test/e2e/{attack-bonuses,derived-values,import-export,npc-names,proficiency-toggles,skills-features}.spec.js

**Git commit:** `7ffac26` — `chore: final sweep after Flavor consolidation - navigation spec, docs and dead code check`

---


## Task 33 — refactor: remove legacy Insults tab superseded by Flavor tab

**Repo:** combat (monk_combat_app) · **Lane:** flavor · **Branch:** ralph/task-33 · **Commit:** 706ece6

### What
Removed the legacy Insults tab whose three generators (Insult, Dark Joke, Tasha's Joke) are all already provided by the consolidated Flavor tab (task 30).

### Changes
- **index.html:** removed `<button data-tab="insults">`, `<div id="tab-insults">`, and `<script src="modules/insults.js">`.
- **app.js:** removed `'insults': 'tabs/insults.html'` from `tabMap`, the `window.renderInsultsUI?.()` call in `save()`, and the `attachInsults()` guard call in boot.
- **styles.css:** deleted the entire `.insult-*` / `.dark-joke-*` / `.tasha-*` block including the `insultAppear` / `insultSpin` keyframes (lines 1382–1671). Confirmed via grep that the Flavor tab uses its own `.flavor-*` classes and none of these.
- **Deleted files:** `modules/insults.js` (incl. the large commented-out AI/bot block — preserved in git history), `tabs/insults.html`, `test/e2e/insults.spec.js`.
- **Specs:** `tabs-navigation.spec.js` and `data-loading.spec.js` already contained no insults references (removed during tasks 31/32), so no edits were required.

### Kept (live data contract)
`insults.json`, `dark-jokes.json`, `tasha-jokes.json` — still consumed by the Flavor tab.

### Verify
- grep for `attachInsults` / `btnGenerateInsult` / `tabs/insults` / `renderInsultsUI` / `data-tab="insults"` → 0 hits in code (only legitimate Flavor `data-flavor="dark-joke"|"tasha"` and json-url references remain).
- No unit infrastructure in this repo → unit step skipped. e2e (`flavor-ui`, `tabs-navigation`, `data-loading`, `critical-path`) left to the post-merge verify gate.


## Task 32 — refactor: remove legacy Excuses tab superseded by Flavor tab

**Repo:** combat (monk_combat_app) · **Branch:** ralph/task-32 · **Commit:** 845dfc8

### What changed
- **index.html:** removed `<button data-tab="excuses">`, `<div id="tab-excuses">` and `<script src="modules/excuses.js">`.
- **app.js:** removed the `'excuses': 'tabs/excuses.html'` tabMap entry, the historically duplicated `loadExcuses`/`attachExcuses` block (~1220-1258), and the `attachExcuses()` guard call. `pickRandom` helper kept (still used by Shenanigans).
- **Deleted:** `modules/excuses.js`, `tabs/excuses.html`, `test/e2e/excuses-ui.spec.js`.
- **test/e2e/tabs-navigation.spec.js:** dropped `excuses` from the all-tabs list; rewrote the "Excuses tab shows all categories" smoke test to assert the 5 excuses `data-flavor` buttons in the Flavor tab.
- **test/e2e/data-loading.spec.js:** redirected the `Data Loading - Excuses` describe and the `Excuses generate different results` variety test through the Flavor tab (`#flavorOutput` + `[data-flavor]` buttons).
- **Kept:** `excuses.json` (Flavor tab data source).

### Verification
- `grep` for `exLifeWisdom|btnExLifeWisdom|attachExcuses|tabs/excuses|data-tab="excuses"|tab-excuses|modules/excuses` → 0 matches in code.
- Remaining `excuses` mentions are only the JSON data file, the Flavor registry/tab, the redirected specs, and BEHAVIOR_DOCUMENTATION.md (out of scope, task 34).
- `node --check` passes for app.js, modules/flavor.js and both modified specs.
- No unit infrastructure in combat → unit step skipped per repos.json; e2e reserved for the post-merge verify gate.


## Task 31 — refactor: remove legacy One-Liners tab superseded by Flavor tab

**Repo:** combat (monk_combat_app) · **Branch:** ralph/task-31 · **Commit:** 9ca2195

### What changed
- **index.html** — removed the `data-tab="liners"` button, the `#tab-liners` div, and the `modules/one-liners.js` script tag.
- **app.js** — removed the `'liners'` tabMap entry, the `attachOneLiners()` boot call, and the whole legacy One-Liners block (`__ol_cache`/`OL_URL`/`loadOneLiners`/`attachOneLiners`). **Kept `pickRandom`** (still used by Shenanigans).
- **Deleted** `modules/one-liners.js`, `tabs/liners.html`, `test/e2e/one-liners-ui.spec.js`. `one-liners.json` stays (Flavor reads it).
- **test/e2e/tabs-navigation.spec.js** — swapped `liners`→`flavor` in the clickable-tabs list; rewrote the One-Liners smoke check to assert the 9 one-liner buttons in `#tab-flavor`; added multiclass level-up modal clicks (2× Monk for the 1→3 Long Rest) in the Stats-persist test.
- **test/e2e/data-loading.spec.js** — redirected the 9 One-Liners data checks + the variety test through the Flavor tab (`#tab-flavor [data-flavor=...]` → `#flavorOutput`); added 4× Monk modal clicks for the 1→5 Long Rest.

### Root cause of the previous failure (fixed)
The recurring red test `data-loading › skills-and-features.json loads for Level 5` was NOT a level-up problem. Its `text=Extra Attack` locator resolved to **two** elements — the accordion `<summary>[Monk] Lv 5 — Extra Attack</summary>` AND the hidden level-up modal's `#monkFeatureLabel` ("Extra Attack, Stunning Strike") — a Playwright **strict-mode violation**. Since the multiclass modal is created once and kept (hidden) in the DOM, this only bites tests that trigger a level-up. Fix: scope the assertion to `#featuresAccordion details.feat summary` with `hasText`.

### Verify
`npx playwright test flavor-ui tabs-navigation data-loading critical-path` → **88 passed** (server auto-managed by Playwright on 45278, torn down after). Step 31.4 grep (`olCritMiss|btnCritMiss|attachOneLiners|tabs/liners`) returns 0 code matches. `node --check` clean. All edits within task 31's `files` scope.


## Task 30 — feat: add consolidated Flavor tab with registry-driven line generator for all 17 flavor types

**Repo:** combat (monk_combat_app) · **Branch:** ralph/task-30 · **Commit:** 36fad8f

### What was done
- **modules/flavor.js** (new): IIFE + `window.attachFlavor`, following the existing module style. `FLAVOR_TYPES` registry of all 17 types as `{id, label, group, url, key}` — 9 One-Liners (`one-liners.json`, keys incl. `Q&A`/`magic_cocktails`), 5 Excuses (`excuses.json`), 3 Insults & Jokes (`insults.json` / `dark-jokes.json` / `tasha-jokes.json`, flat arrays → `key: null`, read logic lifted from modules/insults.js). Lazy cache is a `Map<url, data>`, so the 9 one-liner types share a single fetch. Click handler clears `#flavorOutput`, picks a random line (trim, `(empty)` fallback, `(failed to load <url>)` on error) and moves `.active` onto the pressed button.
- **tabs/flavor.html** (new): 'Flavor' title, large readonly `#flavorOutput` textarea always visible at the top, then three `section-title` sections (One-Liners / Excuses / Insults & Jokes), each a `.flavor-grid` of `.flavor-btn[data-flavor]` buttons with readable labels. No per-type fields.
- **styles.css**: additive only — `.flavor-btn` (min-height 48px, 1rem/600, hover + accent `.active`), `.flavor-grid` (auto-fill minmax(170px, 1fr)), `#flavorOutput` (min-height 200px, 1.15rem). Per the user's design requirement: big, clearly visible buttons and a large text area.
- **index.html / app.js**: `Flavor` tab-btn placed before One-Liners, `#tab-flavor` div, `modules/flavor.js` script before app.js; `'flavor': 'tabs/flavor.html'` in `tabMap` and a guarded `attachFlavor()` call alongside the other attaches.
- **test/e2e/flavor-ui.spec.js** (new): one click-test per type (22 tests total), looped in the one-liners-ui.spec.js shape, plus tab-opens-empty/readonly, all-17-visible, switching-type-moves-.active, and repeat-click-varies.

### Verification
- `npx playwright test flavor-ui critical-path` → **46/46 passed (1.1m)**.
- Old tabs untouched: `git status --porcelain` clean for tabs/liners.html, tabs/excuses.html, tabs/insults.html, modules/one-liners.js, modules/excuses.js, modules/insults.js (additive task — their specs stay green; removal is tasks 31-33).
- No runtime artifacts committed; no stray http-server left on 45278.

### Note on the previous failed attempt
The earlier attempt failed the verify gate on critical-path → 'Long rest fully restores HP, Ki, and HD', a stale test unrelated to task 30 (it set `xp = 6500` expecting level 5, but the app stores level in `st.level`). Base commit **9dcae14** has since fixed that test by setting `st.level`/`monkLevel`/`clericLevel` directly, so the blocker no longer exists — the gate is green on this branch. The prior attempt's secondary worry (full `npm test` exceeding the gate timeout) did not apply: the gate runs this task's own `verify` (28→46 tests, ~1 min), not the whole suite.


## Task #26 — refactor: finalize app.js as thin orchestrator facade and document module structure in README

**Date:** 2026-07-15
**Status:** ✅ Done

**What was done:**
- Cleaned up dead/unused imports in `app.js` that were only present for direct `export ... from` re-exports:
  - `firebase.js`: dropped `db, doc, collection, updateDoc, deleteDoc, getDoc` (kept `GOLD_DOC, ITEMS_DOC, QUESTS_DOC, onSnapshot, setDoc`).
  - `gold.js`: dropped `spendGold, coinInputs, clearCoinInputs` (kept `renderGold, handleGain, handleSpend`).
  - `ui.js`: dropped `esc, initSortable` (kept `syncMsg, initTabs, initModalBackdrops`).
- Verified the facade is complete — all 15 legacy exports still present (spendGold, renderGold, coinInputs, clearCoinInputs, renderItems, renderQuests, saveItems, saveQuests, initSortable, esc, syncMsg, BADGE, NEXT_STATUS, getState, setState).
- Wrote a `Structure` section in `README.md` documenting each file/module, how to run unit + e2e tests, and the intentional CDN-imports (no-bundler) decision.

**Files modified:** `app.js`, `README.md`

**Verification:** `npm run test:unit` → 6 files / 75 tests passed. No app.js behavior change; unit tests untouched.

**Git commit:** `bb856f7172abd6e6a8174a1cbaa1bf375ecb90f5`


### 2026-07-15 — Task #25: refactor: move gold handlers, tabs and modal backdrop wiring into their modules

**Status:** DONE (passes: true)

**What was done:**
- `modules/gold.js`: added imports for `syncMsg` (./ui.js) and `GOLD_DOC`, `setDoc` (./firebase.js); moved `handleGain` and `handleSpend` verbatim from app.js as exported `async function`s. No import cycle (ui.js does not import gold.js).
- `modules/ui.js`: extracted the `.tab-btn` click wiring into `export function initTabs()` and the modal backdrop-close wiring into `export function initModalBackdrops()`; both moved verbatim.
- `app.js`: imports `handleGain`/`handleSpend` from gold.js and `initTabs`/`initModalBackdrops` from ui.js; replaced the handler function bodies with `window.handleGain = handleGain` / `window.handleSpend = handleSpend` wiring; replaced the tabs and backdrop wiring blocks with `initTabs();` / `initModalBackdrops();` at the same top-level positions (execution order preserved); added `handleGain`/`handleSpend` to the gold.js facade re-export.
- Characterization tests untouched; `npm run test:unit` green (6 files, 75 tests).

**Files modified:** `app.js`, `modules/gold.js`, `modules/ui.js`

**Git commit:** d572efb61d6fa7b1156ed0d18387164e78d1db44


## Task #24 — refactor: extract quests logic into modules/quests.js

**Date:** 2026-07-15
**Status:** ✅ Done

**What was done:**
- Created `modules/quests.js` with verbatim-moved `BADGE`, `NEXT_STATUS`, `renderQuests`, `saveQuests` and the bodies of `openQuestModal`, `closeQuestModal`, `editQuest`, `saveQuest`, `cycleStatus`, `deleteQuest` as exported functions. Imports `state` from `./state.js`, `QUESTS_DOC`/`setDoc` from `./firebase.js`, and `esc`/`syncMsg`/`initSortable` from `./ui.js` (mirrors `modules/items.js`).
- `app.js`: added the `./modules/quests.js` import, replaced the entire QUESTS region with `window.*` wiring (`openQuestModal`/`closeQuestModal`/`editQuest`/`saveQuest`/`cycleStatus`/`deleteQuest`), and re-exports `BADGE`/`NEXT_STATUS`/`renderQuests`/`saveQuests` from the module (facade). The `onSnapshot(QUESTS_DOC)` listener still calls the imported `renderQuests`.
- No behavior change; tests were not edited.

**Verification:** `npm run test:unit` → 6 files, 75 tests passed. `git diff` scoped to `app.js` + new `modules/quests.js` only (index.html, test/**, firebaseConfig untouched).

**Files modified:** `app.js`, `modules/quests.js` (new)

**Git commit:** `1893673b793c67dd9385e531222e36bcfd3cd511`


## Task 23 — refactor: extract leaf ui helpers and inventory items logic into modules/ui.js and modules/items.js

**Date:** 2026-07-15
**Status:** ✅ Done

**What was done:**
- Created `modules/ui.js` with verbatim `esc`, `syncMsg`, `initSortable` (no dependencies on items/quests, so the potential import cycle is broken first).
- Created `modules/items.js` with `renderItems`, `saveItems`, and the bodies of `openItemModal`/`closeItemModal`/`editItem`/`saveItem`/`deleteItem` as named exports; imports from `./state.js`, `./firebase.js`, `./ui.js`.
- `app.js`: imports from both new modules, keeps `window.*` wiring (`openItemModal`, `closeItemModal`, `editItem`, `saveItem`, `deleteItem`) and the `PLAYERS` → `#iCarrier` populate; renderQuests/handlers still use `esc`/`syncMsg`/`initSortable` via the ui.js import. Facade re-exports updated: `esc, syncMsg, initSortable` from ui.js and `renderItems, saveItems` from items.js.
- Behaviour unchanged; characterization tests not edited.

**Verification:** `npm run test:unit` → 6 files, 75 tests passed. Only `app.js` modified; `modules/ui.js` and `modules/items.js` added; no test/index.html/firebaseConfig changes.

**Files modified:** app.js, modules/ui.js (new), modules/items.js (new)

**Git commit:** ffbc5b5


## Task 22 — refactor: extract pure gold logic into modules/gold.js

**Date:** 2026-07-15
**Status:** ✅ Done

**What was done:**
- Created `modules/gold.js` holding the pure gold logic moved verbatim: `spendGold` (borrow-down), `renderGold`, `coinInputs`, `clearCoinInputs`. `renderGold` reads `state.gold` via `import { state } from './state.js'`.
- `app.js`: removed the four inline function definitions, added `import { spendGold, renderGold, coinInputs, clearCoinInputs } from './modules/gold.js'`. `handleGain`/`handleSpend` remain in `app.js` (they still depend on `syncMsg`, moved only in task 23) and now use the imported gold helpers.
- Facade preserved: bottom re-export now does `export { spendGold, renderGold, coinInputs, clearCoinInputs } from './modules/gold.js'` alongside the remaining `export { renderItems, ... }`.
- No import cycle: gold.js depends only on state.js; app.js depends on gold.js.

**Verification:** `npm run test:unit` → 6 files, 75 tests passed. Tests not edited; `index.html` untouched; CDN imports and firebaseConfig unchanged.

**Files modified:** `app.js`, `modules/gold.js` (new)

**Git commit:** 7562863


## [2026-07-15 19:13] - Task #21: refactor: extract mutable app state into modules/state.js

**Status:** ✅ Complete

**TDD Phase:** RECON → REFACTOR → DONE

**Problem:** The mutable app state lived as bare module-level `let` variables in app.js; the refactor lane needs it in a shared `modules/state.js` so later modules (gold/items/quests/ui) can read/write a single state object.

**What was done:**
- Created `modules/state.js` exporting `const state = { gold: {pp:0,gp:0,sp:0,cp:0}, items: [], quests: [], editingItemIdx: null, editingQuestIdx: null, expandedItemIdx: null, expandedQuestIdx: null, saving: false, savingQuests: false }`.
- In app.js: removed the 9 `let` declarations, added `import { state } from './modules/state.js'`, and mechanically redirected EVERY read/write to `state.x` — renderGold, handleGain/handleSpend, renderItems + item modal/save/delete/saveItems (incl. `saving` flag), renderQuests + quest modal/save/cycle/delete/saveQuests (incl. `savingQuests` flag), the accordion `expanded*Idx` logic, the 3 onSnapshot callbacks (incl. the echo-guard `if (state.saving)` / `if (state.savingQuests)`), exportData bundle.
- `getState`/`setState` keep their exact previous signatures, now delegating to the state object: `getState()` returns `{gold: state.gold, items: state.items, quests: state.quests}`; `setState` writes into `state.*`.
- Verbatim move — no logic changed. app.js stays the facade re-exporting everything it exported before.

**Verification:**
- `npm run test:unit` → 6 files / 75 tests passed, no test edits.
- `git diff --stat` → only app.js changed + new modules/state.js; index.html and test/ untouched.

**Files modified:**
- `app.js`
- `modules/state.js` (new)

**Git commit:** `3f4784be26f9846738f85abfbc78ac88b3769b02` — `refactor: extract mutable app state into modules/state.js`

---


## Task 20 — refactor: extract firebase init and doc refs into modules/firebase.js

- **Date:** 2026-07-15
- **Task:** #20 refactor: extract firebase init and doc refs into modules/firebase.js
- **Status:** DONE ✅
- **What was done:**
  - Created `modules/firebase.js` holding the CONFIG (`firebaseConfig` verbatim) and INIT regions (`initializeApp`/`getFirestore` → `db`, and `GOLD_DOC`/`ITEMS_DOC`/`QUESTS_DOC`). It keeps the CDN import URLs byte-for-byte identical and re-exports `db`, the three doc refs, and the firestore functions `doc, collection, onSnapshot, setDoc, updateDoc, deleteDoc, getDoc`.
  - `app.js`: replaced the CONFIG/INIT region + CDN imports with `import { db, GOLD_DOC, ITEMS_DOC, QUESTS_DOC, doc, collection, onSnapshot, setDoc, updateDoc, deleteDoc, getDoc } from './modules/firebase.js';`. `PLAYERS` remains in app.js. No behavior changed; app.js stays the facade re-exporting everything it exported before.
  - Vitest alias continues to intercept the CDN imports through `modules/firebase.js` (URLs unchanged).
- **Verification:** `npm run test:unit` → 6 files / 75 tests passed, no test edits. `git diff` clean outside app.js + new modules/. index.html not touched.
- **Files modified:** `app.js`, `modules/firebase.js` (new)
- **Git commit:** 720be854fd869f31c840a377765d5c9417ac8562


### Task 14 — test: characterization tests for tabs, modals, esc helper and sortable wiring

- **Date:** 2026-07-15
- **Status:** DONE
- **What was done:** Created `test/unit/ui.spec.js` with characterization tests (§2 DND/TABS/MODALS/HELPERS, §6) covering the current, unmodified app.js behaviour:
  - **Tabs:** clicking `data-tab="quests"` marks that button `.active`, deactivates the inventory button, activates `#tab-quests` and deactivates `#tab-inventory`; clicking back restores inventory.
  - **Modals:** `openItemModal()`/`openQuestModal()` add `.open` and reset every field to its §2 default (iCat→Разно, iQty→1, iWeight/iValue→0, iCarrier→Party, qStatus→Активен, text fields empty); clicking the backdrop (`e.target === modal`) closes, clicking inside `.modal-card` does not.
  - **esc():** escapes `&`,`<`,`>`,`"` (with `&` first so no double-escape), leaves other characters and single quotes untouched, and casts non-string input via `String()` (42→'42', null→'null', etc.).
  - **initSortable:** a repeated call destroys the previous Sortable instance (verified with a counting stub swapped in after boot); the stub-retained `opts.onEnd({oldIndex,newIndex})` reorders the backing array and calls `saveFn`, producing a `setDoc('inventory/items', {list})` recorded in `fs.calls`.
- **Verification:** `npm run test:unit` → 63 passed across 5 files; `git diff` shows app.js and all non-test files untouched.
- **Files modified:** `test/unit/ui.spec.js` (new).
- **Git commit:** `825947adbc8f7db32702f77e9116980457f85452`


### 2026-07-15 — Task #13: test: characterization tests for firestore snapshots, export bundle and import flow

**Status:** ✅ Done

**What was done:**
- Created `test/unit/sync.spec.js` with characterization tests for the LISTENERS and EXPORT/IMPORT regions of `app.js` (§2, §4, §5, §6), documenting current behaviour against an unmodified `app.js`.
- Snapshots (driven via mock `__emit`): `inventory/gold` null → all coins show 0; gold data → `renderGold` displays values; `inventory/items`/`quests/items` null → empty-state rows; `quests/items` emit → `#syncStatus` becomes 'Live sync ✓' and `window.__appReady === true`.
- `exportData`: stubbed `URL.createObjectURL`/`revokeObjectURL` and `HTMLAnchorElement.prototype.click`, captured the Blob, asserted bundle `{version:1, exportedAt ISO string, gold, items, quests}` and download filename starts with `shared-inventory-`.
- `importData`: valid bundle + confirm=true → `setDoc` for `inventory/gold`, `inventory/items` ({list}), `quests/items` ({list}); items-only bundle → exactly one setDoc; confirm=false → zero setDoc; invalid JSON → `alert` + zero setDoc; file input `value` cleared after each attempt.

**Verification:** `npm run test:unit` → 3 files, 30 tests, all green. `app.js` untouched (git diff clean outside the new spec). Red lines respected — mocks only, no real Firestore, CDN imports intact, e2e/fixtures untouched.

**Files modified:**
- `test/unit/sync.spec.js` (new)

**Git commit:** `c896c7f0eb7bcda172f6b199cb7449a5023f0ac6`


## Task #10 — test: characterization tests for gold treasury (spendGold borrow-down, gain/spend handlers, input clamping)

**Date:** 2026-07-15
**Status:** DONE

**What was done:**
- Created `test/unit/gold.spec.js` characterizing the GOLD region of `app.js` against the unchanged production code, consuming `bootApp()` (§6) and the firestore mock's `fs.calls`.
- `spendGold` pure-function tests: exact spend without borrow; single borrows cp←sp, sp←gp, gp←pp; chained borrow (1cp paid from 1pp → {pp:0,gp:9,sp:9,cp:9}); shortfall → null; floor affordability guard (10.9→affordable, 11→null); zero cost (unchanged); missing cost fields default to 0.
- DOM tests via `bootApp({gold})`: `renderGold` fills #dispPP/GP/SP/CP; `coinInputs` clamps negatives→0, floors floats, empty→0; `window.handleGain` sums inputs, clears them, writes setDoc('inventory/gold', sum); `window.handleSpend` writes borrow-down result & keeps #goldError hidden on success, adds 'visible' + no setDoc + gold unchanged on shortfall, and clears 'visible' on a later successful spend.

**Files modified:**
- `test/unit/gold.spec.js` (new)

**Verification:** `npm run test:unit` → 2 files, 18 tests passed (3 smoke + 15 gold). `git diff` clean outside the new test file; `app.js` untouched.

**Git commit:** 3091c77


### 2026-07-15 — Task #12: test: characterization tests for quests (render, status badges, cycleStatus, save/edit/delete, accordion)

**Status:** ✅ Done

**What was done:**
- Created `test/unit/quests.spec.js` with 18 characterization tests over the QUESTS region of app.js (§2 QUESTS, §4, §6), consuming the existing `bootApp()` helper and `fs.calls`/`fs.__emit` from the firestore mock.
- Coverage: renderQuests empty-state; name/giver/reward rendering with `—` fallback; description shown only when present; BADGE class per status (active/done/failed/paused); `esc()` escaping of quest name; direct-import assertion of the `NEXT_STATUS` map; `cycleStatus` status advance + unshift-to-top + setDoc `quests/items`; `saveQuest` new/edit/empty-name; `deleteQuest` confirm true/false; `savingQuests` in-flight echo guard (ignored snapshot); accordion single-expand, drag-handle no-toggle, and expanded-state survival across re-render.
- app.js NOT modified — tests pass against unchanged production code.

**Files modified:**
- `test/unit/quests.spec.js` (new)

**Verification:** `npm run test:unit` → 2 files, 21 tests passed (18 new + 3 smoke). git diff clean outside the new test file.

**Git commit:** `4a3705b`


## Task #11 — test: characterization tests for inventory items (render, totals, escaping, save/edit/delete, accordion)

**Date:** 2026-07-15
**Status:** ✅ Done

**What was done:**
- Created `test/unit/items.spec.js` with characterization tests documenting the CURRENT behaviour of the ITEMS region in `app.js` (run against unmodified app code).
- Coverage:
  - **renderItems:** empty list → empty-state row + blank `#invFooter`; populated row shows name/qty/weight/value/carrier; carrier defaults to `Party` when missing; footer = Σ weight*qty `toFixed(1)` lb | Σ value*qty `toFixed(2)` gp; `esc()` escapes `<script>`/quotes so no raw tag is injected.
  - **saveItem (via DOM modal):** new item unshifted to top + `setDoc('inventory/items', {list})`; empty/whitespace name → no write, no change; edit (`openItemModal(idx)` + `saveItem`) removes old entry and moves edited item to top.
  - **deleteItem:** `confirm=true` removes item + writes; `confirm=false` leaves state and calls untouched.
  - **Echo guard (§4):** a `inventory/items` snapshot emitted while `saveItems()` is in-flight (`saving` flag) is ignored — local state keeps `['A']` instead of `HACKED`.
  - **Accordion:** row click toggles `item-expanded`; second click removes it; expanding another row leaves only that one expanded; clicking `.drag-handle` does not toggle; expanded state survives a `renderItems()` re-render.
- Used `bootApp()` from `test/helpers/dom.js` and `fs.calls` for Firestore assertions; `window.confirm` stubbed per-test for delete scenarios.

**Verification:** `npm run test:unit` → 2 files, 18 tests passed (3 smoke + 15 new). app.js and all non-test files untouched (`git status` shows only the new spec).

**Files modified:**
- `test/unit/items.spec.js` (new)

**Git commit:** `7fc74e25b21e6ae8be1748f7d43f770ea519963a`


## Task #3 — chore: add vitest unit test infrastructure with firebase CDN mocks and bootApp helper

**Date:** 2026-07-15
**Status:** DONE ✅
**Commit:** 45c745e

**What was done:**
- `package.json`: added `"test:unit": "vitest run"` (existing scripts untouched) + `vitest`/`jsdom` devDeps.
- `vitest.config.js`: `environment: 'jsdom'`, `include: ['test/unit/**/*.spec.js']`, `resolve.alias` mapping the two Firebase CDN URLs → `./test/mocks/firebase-app.js` and `./test/mocks/firebase-firestore.js` (app.js CDN imports stay byte-identical, intercepted via alias per §5).
- `test/mocks/firebase-app.js`: `initializeApp(cfg) → { cfg }`.
- `test/mocks/firebase-firestore.js` (§5 contract): `doc()` → `${col}/${id}` string token; `calls = {setDoc,updateDoc,deleteDoc}`; `onSnapshot` registers cb + returns unsubscribe; `__emit(token,data)` fires cbs with `{exists,data}`; `__reset()` clears calls+listeners; also exports `collection` (app.js imports it, else the ES named import throws) and `getFirestore/getDoc`.
- `test/helpers/dom.js` (§6 `bootApp`): loads index.html `<body>` sans `<script>` tags into `document.body.innerHTML`, stubs `Sortable`/`confirm`/`alert`, `vi.resetModules()` then imports the firestore mock **before** app.js so both share one module instance (shared listeners), imports app.js (top-level runs), `__emit`s the three docs (`inventory/gold`, `inventory/items`, `quests/items`), returns `{ fs }`.
- `test/unit/smoke.spec.js`: (a) empty boot → `#dispGP` = '0' + both tables show empty-state text; (b) one item → row with 'Меч'; (c) app.js exports `spendGold`/`getState`/`setState`.

**Root cause of prior failures & fix:** The post-merge verify gate's 16 uniform e2e failures were an infrastructure failure, not real assertion failures — `npm ci` rejected the committed lockfile (`Missing: @emnapi/core / @emnapi/runtime from lock file`), a known npm optional-deps lockfile bug (still present in npm 11.6.2). With `npm ci` failing, Playwright + http-server never installed, so every e2e test errored. Reproduced it locally (`npm install` then `npm ci` → EUSAGE), then fixed by deleting node_modules + package-lock.json and running a fresh `npm install` (which records the emnapi packages as proper lockfile entries), and — the step prior attempts skipped or didn't hold — verified with the gate's exact `npm ci --no-audit --no-fund` (exit 0, repeatably, and after a clean install) BEFORE committing.

**Files modified:** package.json, package-lock.json, vitest.config.js, test/mocks/firebase-app.js, test/mocks/firebase-firestore.js, test/helpers/dom.js, test/unit/smoke.spec.js

**Verification:** `npm run test:unit` → 3/3 green (also green after a fresh `npm ci`) · `npm ci --no-audit --no-fund` → exit 0 · app.js/index.html untouched (`git diff` clean) · node_modules/.cache gitignored · firebaseConfig/CDN imports untouched · no real Firestore.

**Git commit hash:** 45c745e


## [2026-07-15] - Task #2: refactor: extract inline module script from index.html into app.js verbatim with named exports

**Status:** ✅ Complete

**Problem:** Целият JS живееше inline в <script type="module"> блок в index.html (редове 166-599). Bootstrap таск за фаза 1 — тестовата инфраструктура (таск 3) import-ва app.js като модул.

**What was done:**
- Създаден app.js с ТОЧНОТО съдържание на module script блока (редове 167-598, без script таговете) — byte-identical извличане, верифицирано с cmp срещу оригиналния блок. firebaseConfig, коментарите и подредбата на регионите са verbatim.
- В края на app.js добавени САМО export статментите по спецификацията: export { spendGold, renderGold, coinInputs, clearCoinInputs, renderItems, renderQuests, saveItems, saveQuests, initSortable, esc, syncMsg, BADGE, NEXT_STATUS }; export const getState; export function setState.
- В index.html module script блокът е заменен с <script type="module" src="./app.js"></script>. Service worker inline classic скриптът и SortableJS <script src> тагът са непокътнати.

**Verification:**
- git diff на index.html: 1 insertion, 434 deletions — само замяната на блока със src reference
- cmp: първите 432 реда на app.js са byte-identical с оригиналния блок; node --check app.js → clean
- 18-те window.* assignments са на място (HTML onclick handler-ите разчитат на тях); CDN imports непроменени
- npm run test:unit не съществува още (преди таск 3) — стъпката се пропуска по правилата; e2e се пуска от verify gate-а

**Files modified:**
- index.html
- app.js (нов)

**Git commit:** `dd7e4f5` — `refactor: extract inline module script from index.html into app.js verbatim with named exports`

---


## [2026-07-15 18:04] - Task #1: refactor: extract inline CSS from index.html into styles.css

**Status:** ✅ Complete

**Problem:** Целият CSS живееше inline в <style> блок в <head> на index.html (редове 11-168). Механичен bootstrap таск, който валидира pipeline-а (worktree -> merge -> verify gate).

**What was done:**
- Създаден styles.css с ТОЧНОТО съдържание на <style> блока (без <style> таговете), без промени/преформатиране — byte-identical извличане, верифицирано програмно срещу git HEAD версията.
- В index.html целият <style>...</style> блок е заменен с `<link rel="stylesheet" href="./styles.css">`. Нищо друго в index.html не е пипано.

**Verification:**
- git diff на index.html: само изваждането на блока + 1 добавен link ред (1 insertion, 158 deletions)
- Няма останали <style> тагове в index.html; styles.css съдържа всички правила verbatim
- npm run test:unit не съществува още (преди таск 3) — стъпката се пропуска по правилата; e2e се пуска от verify gate-а

**Files modified:**
- index.html
- styles.css (нов)

**Git commit:** `806dadb` — `refactor: extract inline CSS from index.html into styles.css`

---















































































