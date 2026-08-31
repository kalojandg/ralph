# Monk Combat App — Architecture Reference

> Прочети ПРЕДИ код по repo `combat`. D&D Monk/Cleric character sheet (v3) с автоматизирани тестове. Vanilla JS, без bundler.
> НАЙ-ГОЛЯМОТО и най-старото приложение — очаквай наслоена история. Актуализиран: 2026-08-31 (след Campaign NPCs таба, таскове 810-820 — виж секцията по-долу, вече ГОТОВА, не планирана).

## Файлове

```
monk_combat_app/
├── index.html          ← скелет + tab-nav (9 таба: Stats, PC Characteristics, Resurrection, Inventory,
│                          Flavor, Skills, Session Notes, Names, Campaign NPCs); табовете се зареждат
│                          динамично (loadTabs -> fetch tabs/*.html)
├── app.js              ← ЯДРОТО ~2400+ реда: state (st.*), derived values, tab loading, bundle
│                          (buildBundle/applyBundle), оркестрация. Пипай хирургично, малки таскове.
├── modules/            ← фича модули (IIFE, window.attachX):
│                          flavor.js   — 17-типов registry генератор на реплики (Flavor таба)
│                          namegen.js  — Names таба: alias/familiar/npc с per-type save routing
│                          tts.js      — Google Cloud TTS, гласът на Пийс (виж „TTS" по-долу)
│                          cube.js     — Cube of Force floating widget (виж „Cube of Force" по-долу);
│                                        self-contained IIFE, init на DOMContentLoaded, НЕ е таб
│                          campaign-npc.js — Campaign NPCs таб (виж секцията по-долу); IIFE по
│                                        модела на inventory.js
│                          inventory.js, newchar.js, pcchar.js, quests.js, spells-mark.js
├── tabs/               ← HTML партиали per tab (flavor, namegen, inventory, pcchar, quests,
│                          resurrection, sessionNotes, skills, stats + 3 stats под-партиала,
│                          campaignNpc)
├── themes/             ← 5 самостоятелни face-theme стайла (fog, stone, moss, arcane, bastion),
│                          swap-ват се като <link id="cubeThemeLink"> от cube.js — без @import
├── cube.css            ← стилове за Cube widget-а, дилога, drain accordion-а и news ticker-а
├── styles.css, manifest.json, service-worker.js
├── *.json данни        ← one-liners, excuses, insults, dark-jokes, tasha-jokes (Flavor);
│                          familiars, npc-names (Names); cleric-features, skills-and-features…
│                          Съдържателен таск пипа САМО json, не кода.
├── TTS-SETUP.md        ← как е настроен Google TTS ключът/ограниченията
├── test/README.md      ← четивен guide за пускане/дебъг на тестовете (⚠ BEHAVIOR_DOCUMENTATION.md
│                          и TEST_CASES.md вече ги НЯМА — изтрити; поведението живее в самите e2e спекове;
│                          самият README е с остаряла „Test Coverage" секция отпреди Flavor/TTS/Cube/NPC — не му вярвай)
├── test/e2e/           ← 37 Playwright спек файла (вкл. flavor-ui, namegen-ui, tts-core,
│                          flavor-tts, flavor-text-quality, cube-widget, cube-themes, cube-integration,
│                          campaign-npc)
└── playwright.config.js  ← testDir test/e2e, baseURL localhost:45278, webServer 'npm run serve', workers 1
```

## Модел

- **Персистенция: localStorage, всичко в `st`.** Multiclass: `st.monkLevel`/`st.clericLevel` (Death Domain, interleaved accordion) — поведението на level/class логиката е кодифицирано в `multiclass-levelup.spec.js` / `rest-mechanics.spec.js` (старите BEHAVIOR_DOCUMENTATION.md / TEST_CASES.md са изтрити — спековете са истината). `st.aliases`, `st.npcNames`, `st.familiars` (унифицирани — bundle-ът ги round-trip-ва и трите). `st.campaignNpcs` е ОТДЕЛЕН от `st.npcNames` — виж „Campaign NPCs таб" по-долу; round-trip-ва даром през `{...st}` в buildBundle, без изрично upsert (за разлика от aliases/familiars/npcNames, които buildBundle изрично гарантира като масив — campaignNpcs разчита само на defaultState, работи, но е инконсистентно с прецедента).
- **Long Rest / prepared spells:** `restoreMarkSlots` (spells-mark.js, при Long Rest) нулира използваните mark slots, но НЕ чисти `preparedClericSpells` — подготовката се сменя РЪЧНО на level-up, не автоматично при почивка.
- **Bundle v2** (buildBundle/applyBundle) = export/import контрактът; нов тип запис → влиза в `st`, НЕ в отделен localStorage ключ (урокът от familiars бъга). buildBundle прави `{...st}`, така че всеки нов default в `st` round-trip-ва автоматично — напр. `st.cube` ({charges, activeFace}, default в defaults обекта на app.js).
- **TTS (modules/tts.js):** Google Cloud Text-to-Speech, on-demand (клик = заявка, без кеш, без .mp3 в репото), fallback към браузърния speechSynthesis при липсващ ключ/грешка. Ключът е комитнат НАРОЧНО (прието решение): ограничен по HTTP referrer (localhost dev + GitHub Pages) и само за TTS API, $2 billing аларма + rate limits + капната карта. ⛔ Chirp3-HD гласовете връщат 400 при `pitch` параметър — не го добавяй.
- **Cube of Force (modules/cube.js + cube.css + themes/):** floating widget до дясната стена (drag-ва се; DRAG_THRESHOLD=5px разделя клик от драг), НЕ е таб. Дилог с charges (0..36), faces таблица (5 лица, RAW DMG p.159) и theme switching. Смяната на лице сменя цялата тема на апа чрез swap на `<link id="cubeThemeLink">` към `themes/<theme>.css` (fog/stone/moss/arcane/bastion) — темите са самостоятелни файлове, БЕЗ @import; лице 0/null = маха темата. Charge-drain accordion („Dmg from special spells", 5 spell-а от RAW drain таблицата) е активен САМО при лице 4 (Arcane) или 5 (Bastion) — иначе е disabled и колапснат; заровете се хвърлят физически на масата, играчът въвежда щетата, Apply я вади от charges. News ticker (`#cubeTicker`, статично в index.html между .header и #tab-combat) се показва само докато има вдигнат барьер; render() го възстановява при reload. „Minute Elapsed" бутонът RE-плаща цената на активното лице, за да удържи барьера още минута — пада само при недостатъчни charges (нищо не се харчи) или ако плащането изпразни куба. Widget-ът има „peek" състояние: иконата се ТРАНСЛИРА ~58% извън десния ръб (не само opacity — иначе peek и expanded изглеждат еднакво), клик я връща; специте асертват реалния bounding box, не класа. Целият state е `st.cube` (виж Bundle по-горе); `applyBundle` вика новия `window.renderCube` hook, а render() синхронизира `<link id="cubeThemeLink">` със state — import обновява тема/ticker/charges БЕЗ reload. #510 токенизира ambient цветовете на styles.css зад `:root` custom properties (zero visual change) — темите разчитат на тези токени.
- Repo-то има собствен CLAUDE.md/AGENTS.md — ⛔ НЕ пускай `gitnexus analyze` (виси → watchdog kill).

## Команди / портове

```
npm ci                  # в нов worktree
npm test                # Playwright e2e — САМО verify gate-ът, НЕ агент!
npm run test:critical   # само critical-path спековете (по-бърз, ако таск изрично го иска)
npm run serve           # http-server на 45278 — НЕ пускай от агент
```
- Порт **45278** (собствен — без колизия с другите апове).
- Unit инфраструктура НЯМА — bootstrap по модела на shared-inventory при нужда (localStorage, без Firebase мокове).

## Тестово състояние

- **Baseline 2026-07-27: 452 passed, 0 failed, 13.2 мин** (пълен suite, ексклузивен порт) — събира се комфортно в 45-мин гейт таван. От 2026-08-03 добавени 3 cube спека (cube-widget, cube-themes, cube-integration) → 35 спек файла; гейтът остана зелен (числото 452 е от преди cube-а — не съм пускал suite наново). Peek / Minute-Elapsed / bundle-import поправките (2026-08-10) РАЗШИРИХА cube-widget, cube-integration и rest-mechanics спековете in-place — без нови файлове (пак 35). Таскове 810/820 (2026-08-31) добавиха нов `campaign-npc.spec.js` (CRUD + търсене + details + state-level drag) и РАЗШИРИХА `tabs-navigation.spec.js` in-place → 37 спек файла; verify gate-ът остана зелен (числото 452 не е преброено наново от cube-а насам — не му вярвай буквално, ползвай го само като порядък).
- Legacy спековете (отпреди multiclass модала) носят auto-Monk resolver в beforeEach (interval кликащ cardMonk) — НЕ го махай при редакция; нов тест, който вдига ниво, сетва `st.level` + `st.monkLevel` + `st.clericLevel` директно ИЛИ разчита на resolver-а.
- npc-names.spec.js е DATA-DRIVEN (чете пуловете от npc-names.json) — не връщай hardcoded списъци с имена.

## Campaign NPCs таб (ГОТОВ — таскове 810-820, lane `campaign-npc`, СЕРИЙНА, мърджнати 2026-08-31)

Дневник на срещнатите NPC-та в кампанията: име + фракция, търсене по двете, свободен текст детайли. СЕРИЙНА lane нарочно: една фича = един модул, а паралелни таскове биха се били за порт 45278 при локални filtered runs. #810 докара CRUD таблицата + modal; #820 добави slash-aware търсенето и details accordion-а (реализацията излезе 1:1 с оригиналния план по-долу).

**Данни:** `st.campaignNpcs: []` в defaultState (bundle v2 го round-trip-ва даром — урокът от familiars, виж бележката в „Модел" по-горе за инконсистентността с изричния ensure-array на aliases/familiars/npcNames в buildBundle). Запис: `{ name, faction, description, location }` — всичко стрингове. Име задължително; фракция/описание/локация опционални. ⚠ НЕ се бърка със съществуващия `st.npcNames` (Names таба — генерирани имена; съвсем друга фича, останаха отделни store-ове).

**Слот-имена:** таб `campaignNpc` (nav бутон „Campaign NPCs", div `tab-campaignNpc`, партиал `tabs/campaignNpc.html`, запис в tabMap на loadTabs); модул `modules/campaign-npc.js` (IIFE по модела на inventory.js: `window.attachCampaignNpcs` / `window.renderNpcTable`, плюс `window.npcMatches` изложена за спековете); modal `npcModal` (`npcModalTitle, npcName, npcFaction, npcDescription (textarea), npcLocation (textarea), npcSave, npcCancel`); търсачка `npcSearch`; root `npcTableRoot`; Add бутон `btnNpcAdd`.

**Търсене (ядрото на фичата — ЧИСТА функция `npcMatches(npc, query)`, изложена на window за спековете, по прецедента на spendGold):** и името, и фракцията могат да носят няколко стойности, разделени с `/` ИЛИ `\` („кралицата на Кислев/руснаците", „Кулсталтин/Распутин"). Сплит по `/[\/\\]/`, trim на всяка част, lowercase; query-то (trim + lowercase; празно → всички) match-ва, ако НЯКОЯ част `.includes(q)`. Търси се в частите И на name, И на faction. Живо филтриране на input (`input` event, без debounce). Индексите в render-а остават РЕАЛНИТЕ индекси от `st.campaignNpcs` (не позиция във филтрирания списък) — edit/delete/детайли/drag работят коректно и под филтър.

**Таблица (inventory.js е ЕТАЛОНЪТ):** колони ☰ | Име | Фракция | действия (📖 детайли / ✏️ edit / 🗑️ delete с confirm). Sortable drag по inventory модела (handle `.npc-drag-handle`, `filter: 'button, .icon-btn'`); нов запис се push-ва (конвенцията на апа). 📖 отваря ДЕТАЙЛЕН РЕД под NPC-то (colspan 4, точно един expanded — `__npcExpandedIdx`): Description и Where to find като свободен текст блокове (pre-wrap), НЕ таблица; delete/reorder коригират или колапсват `__npcExpandedIdx`, за да не сочи към грешен ред. Modal-ът показва ВСИЧКИ 4 полета при add и edit; name празно → alert (както inventory). Drag е ИЗКЛЮЧЕН докато филтърът е активен (пренареждане на филтриран изглед би разбъркало скритите редове) и се пресъздава при изчистване на филтъра; `onEnd` чете новия ред по РЕАЛНИТЕ `data-npc-idx` атрибути от DOM-а (не `evt.oldIndex/newIndex`), защото детайлният ред не носи такъв атрибут и би счупил индексите.

**Wiring в app.js (хирургично, 4 региона):** tabMap запис; `campaignNpcs: []` в defaultState; `renderNpcTable()` в render() (при другите render-ове); attach hook в showTab за `campaignNpc` (setTimeout 100, по inventory модела).

**Спекове:** `test/e2e/campaign-npc.spec.js` (crud-inventory.spec.js е еталонът) — CRUD, slash-aware търсене, details accordion, plus state-level drag reorder тестове добавени в review fix-а (реален mouse drag е flaky — Playwright + SortableJS timing, урокът от quest drag теста; вместо това местят `<tr>` в DOM-а и викат `Sortable.get(tbody).options.onEnd()` директно). `tabs-navigation.spec.js` е „1:1 с реалния tab-nav" → таск 810 ДОБАВИ 'campaignNpc' в масива му (поведенческа промяна = спекът се оправи в същия таск — изрично позволено тук).

## Червени линии

1. app.js е голямо споделено ядро — таск, който го пипа = МАЛЪК обхват, един регион, след прочит на BEHAVIOR_DOCUMENTATION.md за областта.
2. `test/e2e/**` не се пипат освен ако таскът е за тях. Спековете са единственият изпълним контракт за поведение (BEHAVIOR_DOCUMENTATION.md / TEST_CASES.md са изтрити) — при съмнение печели съответният спек.
3. localStorage схемата на героя е жив контракт (реални персонажи) — миграция само като изрична стъпка. Нов persistent тип → в `st` (bundle-ът да го носи).
4. **TTS ключът**: не го мести, не го логвай, не разхлабвай referrer restriction-а; no-key fallback пътят е задължителен (апът работи и без ключ). Външни API ключове в ДРУГИ таскове не се комитват без изрично решение като това.
5. Не commit-вай runtime боклук: playwright-report/, test-results/, tmpclaude-*, logs/.
