# Shared Inventory — Architecture Reference

> Прочети този файл ПРЕДИ да пишеш код. Патърните тук са ПРАВИЛА, не препоръки.
> Приложение: DnD party инвентар + куестове. Vanilla JS PWA, **без bundler, без framework**.
> Real-time sync през Firebase/Firestore (CDN imports). Приложението е В ПРОДУКЦИЯ — играе се на живо.

## §1. Файлове

```
shared-inventory/
├── index.html            ← страницата: markup + (до таск 2) целият JS inline; (до таск 1) целият CSS inline
├── styles.css            ← след таск 1: целият CSS (извлечен от <style> блока)
├── app.js                ← след таск 2: целият JS (извлечен verbatim от <script type="module">) + exports
├── modules/              ← след фаза REFACTOR (таскове 20-26): firebase.js, state.js, gold.js, items.js, quests.js, ui.js; след фаза 3 MAPS (410-450): maps.js, image.js, viewer.js; след фаза 4 BASES (610-650): bases.js, base-detail.js, base-tables.js
├── sw.js                 ← service worker (регистрира се от малък inline classic script — ОСТАВА в index.html)
├── manifest.json         ← PWA manifest
├── vitest.config.js      ← след таск 3 (unit test инфраструктура)
├── test/
│   ├── e2e/              ← Playwright specs (items-accordion, quests-accordion, maps-accordion, bases-accordion) — съществуващите НЕ СЕ ПИПАТ (maps-* добавен от таск 450, bases-* от таск 650)
│   ├── fixtures/         ← standalone HTML фикстури за e2e (items-, quests-, maps-, bases-fixture.html) — НЕ СЕ ПИПАТ (те са собственост на e2e)
│   ├── mocks/            ← след таск 3: firebase-app.js, firebase-firestore.js (виж §5)
│   ├── helpers/          ← след таск 3: dom.js (bootApp helper, виж §6)
│   └── unit/             ← unit тестове (фаза 1: 10-14; фаза 3 maps: image/maps/maps-modal/viewer — виж §9; фаза 4 bases: bases-foundation/bases/bases-detail/bases-tables — виж §10)
├── playwright.config.js  ← e2e: testDir test/e2e, baseURL localhost:45279, webServer 'npm run serve' — НЕ СЕ ПИПА
└── package.json          ← scripts: test (playwright), serve (http-server 45279); таск 3 добавя test:unit (vitest run)
```

## §2. Инвентар на кода (какво има в JS блока / app.js)

Региони по ред на появяване (имената са реалните):

| Регион | Символи |
|--------|---------|
| CONFIG | `PLAYERS` (4 имена), `firebaseConfig` — **НЕ СЕ ПИПА НИКОГА** |
| INIT | `initializeApp`, `getFirestore` → `db`; doc refs: `GOLD_DOC` = doc(db,'inventory','gold'), `ITEMS_DOC` = doc(db,'inventory','items'), `QUESTS_DOC` = doc(db,'quests','items') |
| STATE | `let gold {pp,gp,sp,cp}`, `items[]`, `quests[]`, `editingItemIdx`, `editingQuestIdx`, `expandedItemIdx`, `expandedQuestIdx`, `saving`, `savingQuests` |
| SYNC UI | `syncMsg(msg, cls)` — пише в `#sync` |
| GOLD | `spendGold(current, cost)` — **ЧИСТА функция**, borrow-down алгоритъм (cp←sp←gp←pp), връща `null` при недостиг; `renderGold()`, `coinInputs()` (clamp: negative→0, floor), `clearCoinInputs()`, `window.handleGain`, `window.handleSpend` (показва `#goldError` при недостиг) |
| ITEMS | `renderItems()` (empty state, редове, esc() на name/note, footer: Σ weight*qty / Σ value*qty toFixed, акордеон: един expanded, клик на бутон/handle НЕ expand-ва), `window.openItemModal/closeItemModal/editItem/saveItem/deleteItem` (confirm!), `saveItems()` (флаг `saving` — виж §4) |
| QUESTS | `BADGE` map, `NEXT_STATUS` map (Активен→Изпълнен→Паузиран→Активен; Провален→Активен), `renderQuests()`, `window.openQuestModal/.../saveQuest/deleteQuest` (confirm!), `window.cycleStatus` (unshift-ва куеста най-отгоре), `saveQuests()` (флаг `savingQuests`) |
| DND | `initSortable(tbodyId, arr, saveFn)` — destroy на предишния instance, `onEnd` splice-ва и вика saveFn. **`Sortable` е ГЛОБАЛ** (classic script от CDN) |
| TABS/MODALS | tab-btn click listeners, backdrop click затваря модала |
| HELPERS | `esc(s)` — HTML escape (&, <, >, ") |
| LISTENERS | 5× `onSnapshot`: gold (missing→zeros), items (игнорира при `saving`), quests (игнорира при `savingQuests`; сетва `#syncStatus` = 'Live sync ✓' и `window.__appReady = true`), maps (игнорира при `savingMaps`; чете `snap.data().list`, само индекс-докът — снимките са отделни докове, §9), bases (игнорира при `savingBases`; чете `snap.data().list`; вика `renderBases()` + `renderRoute()` + `renderSubTables()` — §10) |
| EXPORT/IMPORT | `window.exportData` (bundle {version:1, exportedAt, gold, items, quests} → download), `window.importData` (confirm → setDoc за наличните ключове; невалиден JSON → alert) |
| PWA | `beforeinstallprompt` → `#btnInstall` |

DOM id-та: `sync, syncStatus, dispPP/GP/SP/CP, inPP/GP/SP/CP, goldError, invBody, invFooter, questBody, itemModal (iName,iCat,iQty,iWeight,iValue,iCarrier,iNote), questModal (qName,qStatus,qGiver,qDesc,qReward,qNote), btnInstall`.
Maps (фаза 3): таб `tab-maps` (tab-btn `data-tab="maps"`), `mapTable/mapBody`, `mapModal` (`mapModalTitle, mShort, mDetails, mFile, mPreview, mMapError`), overlay `#mapViewer` (създава се от viewer.js, не е в index.html).
Bases (фаза 4): таб `tab-bases` (tab-btn `data-tab="bases"`), `baseTable/baseBody`, `baseModal` (`baseModalTitle, bName, bLocation`), детайл `#baseDetail` (`btnBaseBack, bdName, bdLocation, bdHistory, btnBaseSave` + `bdBuildingsBody/bdPopulaceBody/bdProductionBody`), общ под-модал `bsModal` (`bsModalTitle, bsName, bsDetails`) — §10.

## §3. Червени линии (нарушение = failed таск)

1. **`firebaseConfig` НЕ се пипа, мести само verbatim.** Не създавай нови Firestore колекции/документи. Не инсталирай `firebase` npm пакет.
2. **CDN imports ОСТАВАТ** (`https://www.gstatic.com/firebasejs/...`, SortableJS от jsdelivr). Приложението няма bundler и трябва да работи с директно отваряне през http-server. Vitest ги прихваща през alias (§5), НЕ през пренаписване на import-ите.
3. **НИКОГА тест срещу реален Firestore.** Unit тестовете минават САМО през моковете. Приложението е в прод — писане в живата база от тест е инцидент.
4. **НЕ пускай `npm test` (Playwright) и `npm run serve` от агент** — портът 45279 е един; e2e ги пуска verify gate-ът на оркестратора след merge. Агентите пускат само `npm run test:unit`.
5. **`test/e2e/` и `test/fixtures/` не се редактират** от никой таск в тази фаза.
6. **Характеризационните тестове документират КАКВОТО Е**, не каквото „трябва да бъде". Тест, който не минава срещу текущия код = грешно очакване (или реален бъг → опиши го в result summary, НЕ го поправяй, тествай реалното поведение).

## §4. Поведенчески тънкости (снети от кода — важни за тестове)

- `saving`/`savingQuests` флаговете спират echo-то: докато `saveItems()` е in-flight, snapshot listener-ът за items ИГНОРИРА входящи snapshots (иначе собственият write се връща и презаписва по-нов локален state).
- `saveItem`/`saveQuest` при редакция: splice на стария индекс + `unshift` (редактираният отива НАЙ-ОТГОРЕ).
- `cycleStatus` също unshift-ва куеста най-отгоре.
- Акордеонът: точно един expanded ред на таблица; клик върху бутон или `.drag-handle` НЕ toggle-ва; expanded state оцелява re-render (`expandedItemIdx`/`expandedQuestIdx`).
- `coinInputs()` клампва: отрицателни → 0, floats → floor, празно → 0.
- `spendGold` borrow-ва НАДОЛУ по веригата cp→sp→gp→pp (никога обратно, не "оптимизира" рестото).
- `deleteItem`/`deleteQuest`/`importData`/`deleteMap` ползват `confirm()`; `importData` ползва `alert()` при невалиден JSON — в jsdom ги стъбваш.
- Maps (§9): `saveMap` splice+unshift като quests (редактираната отива най-отгоре); индексът се пази с `saveMapsIndex` (флаг `savingMaps`), снимката с ОТДЕЛЕН `setDoc(mapImageDoc(id), {image})` — само когато има staged `pendingImage`. Нова карта без снимка → грешка в диалога (save блокиран). Ред. на карта зарежда снимката лениво през `getDoc` (не е в индекс snapshot-а). `deleteMap` трие и image дока. `crypto.randomUUID()` дава id; `createdAt` = ISO стринг. Компресията е само над прага (`processImageBlob`: оригинал → 1600/0.72 → 1200/0.6 → грешка).

## §5. Unit test инфраструктура (създава се от таск 3; тестовете я КОНСУМИРАТ, не я променят)

`vitest.config.js`: `environment: 'jsdom'`, `resolve.alias`:
```
'https://www.gstatic.com/firebasejs/10.12.2/firebase-app.js'       → ./test/mocks/firebase-app.js
'https://www.gstatic.com/firebasejs/10.12.2/firebase-firestore.js' → ./test/mocks/firebase-firestore.js
```

`test/mocks/firebase-app.js`: `export function initializeApp(cfg) { return { cfg }; }`

`test/mocks/firebase-firestore.js` — контракт (точно тези exports):
```js
getFirestore(app)                       // → {} 
doc(db, col, id)                        // → string token `${col}/${id}`
setDoc(token, data)                     // записва в calls + в вътрешен store, resolve-ва
updateDoc / deleteDoc                   // записват в calls, resolve-ват
getDoc(token)                           // → { exists: () => store.has(token), data: () => store.get(token) }  (след таск 410 чете от store-а)
onSnapshot(token, cb)                   // регистрира cb; връща unsubscribe
export const calls = { setDoc: [], updateDoc: [], deleteDoc: [] };   // [{token, data}]
export function __setDocData(token, data)  // seed на store-а БЕЗ да записва call (test setup)
export function __emit(token, data)     // вика регистрираните cb-та със snap: { exists: () => data !== null, data: () => data }
export function __reset()               // чисти calls + listeners + store
```

## §6. Как се пише unit тест (контракт на helper-а от таск 3)

`test/helpers/dom.js`:
```js
export async function bootApp({ gold = null, items = null, quests = null, maps = null } = {})
// 1. чете index.html, взима <body> markup-а БЕЗ <script> таговете → document.body.innerHTML
// 2. стъбва globalThis.Sortable (class със constructor(el, opts) { el._sortable = this; this.opts = opts; } и destroy(){}),
//    window.confirm = () => true (тестът го override-ва при нужда), window.alert = () => {}
// 3. vi.resetModules(); __reset() на firestore мока
// 4. await import('../../app.js')   ← app.js top-level кодът се изпълнява (populate carrier, listeners)
// 5. __emit за четирите дока: 'inventory/gold' (gold), 'inventory/items' (items===null ? null : {list: items}),
//    'quests/items' (quests===null ? null : {list: quests}), 'maps/index' (maps===null ? null : {list: maps})
// 6. връща { fs }  // fs = импортнатият мок модул (за calls/__emit в теста)
```
Тестът след това: пипа DOM-а (`document.getElementById(...)`), вика `window.handleGain()` / exported функции, assert-ва DOM + `fs.calls`.

## §7. Целева модулна структура (фаза REFACTOR, таскове 20-26)

Модел: monk_combat_app (`app.js` оркестратор + `modules/*.js`). **Инвариант на цялата фаза: тестовете от фаза 1 НЕ се редактират и остават зелени** — `app.js` става фасада, която re-export-ва всичко, което export-ваше преди.

| Модул | Съдържание |
|-------|-----------|
| `modules/firebase.js` | firebaseConfig (verbatim!), init, `db`, `GOLD_DOC/ITEMS_DOC/QUESTS_DOC`; re-export-ва ползваните firestore функции (setDoc, onSnapshot, ...) от CDN import-а |
| `modules/state.js` | `export const state = { gold, items, quests, editingItemIdx, editingQuestIdx, expandedItemIdx, expandedQuestIdx, saving, savingQuests }` — модулите четат/пишат `state.x` (заменя голите `let`-ове) |
| `modules/gold.js` | spendGold, renderGold, coinInputs, clearCoinInputs, handleGain, handleSpend |
| `modules/items.js` | renderItems, item modal функциите, saveItem, deleteItem, saveItems |
| `modules/quests.js` | BADGE, NEXT_STATUS, renderQuests, quest modal функциите, saveQuest, cycleStatus, deleteQuest, saveQuests |
| `modules/ui.js` | syncMsg, esc, initSortable, tabs wiring, modal backdrop wiring |
| `app.js` (остава) | imports, `window.*` assignments, 3-те onSnapshot wiring-а, exportData/importData, PWA install + **фасада: re-export на всичко от модулите** |

## §8. Команди (Windows / PowerShell)

```
npm ci                  # в нов worktree (node_modules не пътуват)
npm run test:unit       # vitest run — ЕДИНСТВЕНОТО, което агент пуска (след таск 3)
npm test                # Playwright e2e — САМО verify gate-ът (не агент!)
```
Playwright browsers са инсталирани глобално на машината — `npm ci` е достатъчен за worktree.

## §9. Maps фича (фаза 3 — РЕАЛИЗИРАНА, таскове 410-470, lane `maps`)

Таб „Карти": ДМ-ът качва карти (скрийншоти) от лаптоп/браузър, партито гледа на Android таблет.
Пълната спека: `maps-feature-plan.md` в корена на репото. **Статус: доставена и merge-ната в main, verify gate зелен.**

**Данни (решено, не се предоговаря):** колекция `maps` — `maps/index` = `{ list: [{id, shortDesc, details, createdAt}] }` (ред = ред на показване; същият патърн като ITEMS_DOC), `maps/<uuid>` = `{ image: '<data URL>' }` (по един док на карта; снимката е ОТДЕЛНО от индекса — 1MB/док лимит + snapshot-ът на индекса да не тегли снимки). Компресия client-side (canvas, ~1600px, JPEG ~0.72) в `modules/image.js` — но САМО при нужда: прагът е `MAX_IMAGE_BYTES = 900000` върху **data URL дължината** (base64 надува ~33%, Firestore лимитът е 1MiB/док); под прага оригиналът се пази непипнат, над него компресия → втори по-агресивен опит → грешка в диалога. БЕЗ Firebase Storage, БЕЗ нови npm пакети. Firestore е schema-less — доковете възникват при първия запис; security rules за колекция `maps` са ръчна стъпка на собственика в конзолата, НЕ на агент.

**Амендмънти на §3 (САМО за тази фаза, всичко останало важи):**
1. §3.1 „не създавай нови колекции" → колекция `maps` е РАЗРЕШЕНА (единствено тя). `firebaseConfig` остава непипнат.
2. §3.5 „test/e2e/ и fixtures не се пипат" → НОВИ `maps-*` файлове там са разрешени; съществуващите — не.
3. §5 мокът се разширява АДИТИВНО: вътрешен store, `setDoc` пише и в store-а, `getDoc` чете от него (незасят token → `exists:false` както днес), нов export `__setDocData(token, data)`. Старите тестове остават зелени.
4. §6 `bootApp` получава адитивен параметър `maps = null` → `__emit('maps/index', maps === null ? null : {list: maps})`.

**Доставени модули (реалност):**

| Модул | Съдържание |
|-------|-----------|
| `modules/maps.js` | `renderMaps` (акордеон като quests, клик на бутон/handle не toggle-ва; на всеки ред 🔍 preview / ✏ edit / 🗑 delete, 🔍 е ПЪРВИ), `saveMapsIndex` (флаг `savingMaps`), модал (`openMapModal/closeMapModal/editMap/saveMap/deleteMap`), `previewMap(i)` (таск 470 — виж по-долу), image pipeline (`handleMapFile` за `<input type=file>` + `handleMapPaste` за Ctrl+V document-level listener), `processImageBlob` (компресия само над прага). `saveMap`: и двете описания задължителни, нова карта иска снимка, id = `crypto.randomUUID()`, image в ОТДЕЛЕН `mapImageDoc(id)`, splice+unshift. Клик на `#mPreview` → `openViewer`. |
| `modules/image.js` | `MAX_IMAGE_BYTES = 900000`, `needsCompression(len)`, `blobToDataUrl(blob)` (FileReader, работи в jsdom), `fitDimensions(w,h,maxDim=1600)` (чиста, не upscale-ва), `compressImage(blob,{maxDim,quality=0.72})` (тънък canvas wrapper, без unit тест — jsdom няма canvas). |
| `modules/viewer.js` | `clampScale(s)` (range [1,8]), `zoomAt(view,factor,cx,cy)` (чиста геометрия, transform-origin 0 0), тънък DOM/event слой на pointer events (pan/pinch) + wheel zoom + Escape/backdrop/dblclick reset + видими ➕/➖ zoom бутони (таск 470 — виж по-долу). Overlay `#mapViewer` се създава ВЕДНЪЖ (`ensureOverlay`) и се преизползва. |

`firebase.js` добавя `MAPS_INDEX_DOC = doc(db,'maps','index')` и `mapImageDoc(id) = doc(db,'maps',id)` + export на `collection`. `state.js` добавя `maps, editingMapIdx, expandedMapIdx, savingMaps`. `app.js` добавя `window.*` за map handler-ите, 4-тия `onSnapshot(MAPS_INDEX_DOC)` и re-export на maps/viewer публичното API; `getState/setState` включват `maps`. DOM (в index.html): таб `tab-maps`, `mapTable/mapBody`, модал `mapModal` (`mapModalTitle, mShort, mDetails, mFile, mPreview, mMapError`); overlay `#mapViewer` НЕ е в markup-а — раждан от viewer.js.

**Добавки след първия run (таскове 460, 470 — доставени, зелени):**
1. **Статичен линк към картата на света (460)** — над бутона „+ Добави карта" в `tab-maps`: `<div class="map-world-row"><a class="map-world-link" target="_blank" rel="noopener" href=".../Map:Immortal_Empires_Factions">…</a></div>`. Чист markup в `index.html` + два стила в `styles.css`, БЕЗ JS. В DOM реда стои ПРЕДИ `.controls`.
2. **Preview бутон 🔍 на всеки ред (470)** — `previewMap(i)` в `modules/maps.js`, export-нат и wired като `window.previewMap` в `app.js`. Отваря САМО снимката във fullscreen viewer-а без да минава през едит диалога: ленив `getDoc(mapImageDoc(m.id))` (без кеш, снимката не е в индекса), при успех `openViewer` + `● live`, при липса → „Няма снимка за тази карта". Не пипа `state.editingMapIdx`; кликът не toggle-ва акордеона. Бутонът е ПЪРВИ в `.tbl-actions`.
3. **Лупички ➕/➖ във viewer-а (470, преработени в хотфикс — виж по-долу)** — `.viewer-zoom-bar` (долу-център) в `modules/viewer.js`, раждани в `ensureOverlay`. Едри touch таргети (44×44) за таблета, който няма wheel и на който pinch не е очевиден. Бутоните са МАГНИФАЙЪР ТОГЛОВЕ (`setZoomMode('in'|'out')`): тап по бутона въоръжава режим (клас `.active`, cursor zoom-in/out), после тап по картата зумва ТОЧНО на това място (`zoomAt` при `ZOOM_STEP = 1.4`); повторен тап по бутона изключва режима, `openViewer` също го нулира (`clearZoomMode`). Клампът [1,8] идва от `zoomAt`/`clampScale`. Стилове `.viewer-zoom-bar`/`.viewer-zoom`/`.viewer-zoom.active` в `styles.css`.

Нови DOM/CSS handle-ове: `.map-world-row`/`.map-world-link` (Maps таб), `.viewer-zoom-bar`/`.viewer-zoom`/`.viewer-zoom.active` (overlay). `maps-feature-plan.md` носи същите допълнения в секция „Допълнения (след първия run)".

**Хотфикси на viewer-а след таск 470 (доставени, зелени — поправят реалното поведение, не са нови таскове):**
1. **Затварянето минава през pointer събития, НЕ през `click` (706269b)** — `setPointerCapture` ПРЕНАСОЧВА производния `click` към overlay-а, така че всеки клик (снимка, лупичка) идваше с `target === overlay` и затваряше viewer-а. Махнат е click listener-ът; вместо него `onPointerDown/Move/Up` пазят `gesture` (target + начална точка + `moved`) и решават: движение > `TAP_SLOP` (8px) или втори пръст = pan/pinch; чист tap върху голия фон = `closeViewer`; tap върху снимката = нищо. Бутоните `return`-ват рано в `onPointerDown` (без capture), за да не си губят собствения click.
2. **Native image drag е потиснат (c840ef3)** — на десктоп HTML5 drag на `<img>` краде pointer-ите (`pointercancel`) и мишката влачи „духче" вместо да панва: `viewerImg.draggable = false` + `dragstart → preventDefault` + `-webkit-user-drag: none` в CSS.
3. **Мобилното скриване на колони вече е скоупнато (f643bf8)** — глобалното `@media (max-width:540px)` правило криеше `nth-child(4)/(5)` във ВСЯКА таблица; в maps таблицата колона 4 е actions (🔍/✏/🗑) и бутоните изчезваха на телефон-портрет. Правилото е стеснено до `#invTable/#questTable`; maps описанията са пристегнати да се събират. Само `styles.css`.
4. **Статичният линк към картата на света е центриран и уголемен (706269b)** — `.map-world-row { text-align: center }`, `.map-world-link` с `--accent2`, 1.15rem, bold (беше дребен muted линк вдясно). Само `styles.css`.

**Test state (фаза 3, всичко зелено):**
- Unit (Vitest): `image.spec.js` (9), `maps.spec.js` (14 — +6 за world link и preview), `maps-modal.spec.js` (13), `viewer.spec.js` (24 — +4 zoom бутони, +7 за магнифайър-режима, pointer-close и drag хотфиксите); мокът разширен → `firestore-mock.spec.js` (4). Общо unit spec-ове: 11 файла.
- E2e (Playwright): `test/e2e/maps-accordion.spec.js` (6) + фикстура `test/fixtures/maps-fixture.html`. Съществуващите items/quests e2e непроменени.

**Извън обхват:** export/import bundle-ът (v1) НЕ включва картите (снимките биха издули JSON-а — `getState/setState` носят `maps` само за тестове/state, не за bundle-а). sw.js не се пипа (network-first покрива новите модули).

## §10. Bases фича (фаза 4 — РЕАЛИЗИРАНА, таскове 610-650, lanes `bases-core` → `bases-list` ∥ `bases-detail` ∥ `bases-tables` → `bases-e2e`)

Таб „Бази" — селищата/базите на партито: списък (име + локация), детайлна „страница" през hash routing с история и 3 под-таблици (сгради, население, продукция). Пълната спека: `bases-feature-plan.md` в корена на репото. **Статус: доставена и merge-ната в main, verify gate зелен.** Реалността потвърждава контракта по-долу — трите модула са доставени точно както е описано (import-ват `saveBases` от bases.js, комуникират detail→tables през `state.currentBaseId` + `base-route` event-а).

**Данни (решено от потребителя — НЕ се предоговаря):** колекция `bases`, **ЕДИН док** `BASES_DOC = doc(db,'bases','index')` = `{ list: [ { id, name, location, history, buildings: [{name, details}], populace: [{name, details}], production: [{name, details}] } ] }`. Всичко е свободен текст. `id = crypto.randomUUID()` (котва за routing-а). Един док нарочно — 1 read на snapshot, пази free tier (изрично изискване; съображението за отделни докове при maps беше снимките — тук снимки НЯМА). Редът в `list` = ред на показване, `{list}` патърнът на ITEMS_DOC.

**Амендмънти на §3 (САМО за тази фаза, всичко останало важи):**
1. §3.1 „не създавай нови колекции" → колекция `bases` е РАЗРЕШЕНА (единствено тя). `firebaseConfig` остава непипнат.
2. §3.5 „test/e2e/ и fixtures не се пипат" → НОВИ `bases-*` файлове там са разрешени; съществуващите — не.
3. §6 `bootApp` получава адитивен параметър `bases = null` → `__emit('bases/index', bases === null ? null : {list: bases})`. Дефолтът null пази старите тестове зелени.

**Tabs 2×2 (решение на потребителя):** `.tab-nav { flex-wrap: wrap }`, `.tab-btn { flex: 1 1 50% }` — 4-те таба стоят 2 реда × 2 на всякакъв екран.

**Routing:** hash — `#base/<id>` = детайлът, празно/друго = табовете. При отворен детайл `.tab-nav` и `.tab` дивовете са скрити, `#baseDetail` видим; „← Назад" → `location.hash = ''` → табовете с активен `tab-bases`. Непознат/изтрит id → връщане към списъка. `renderRoute()` се вика от `hashchange` И от bases snapshot-а (deep link при зареждане — данните идват след DOM-а).

**DOM контракт:** nav бутон `data-tab="bases"` („Бази"); `#tab-bases`: „+ Добави база" (`openBaseModal()`) + таблица `baseTable`/`baseBody` (☰ | Име | Локация | действия: 📖 `openBaseDetail(i)` / 🗑 `deleteBase(i)`); модал `baseModal` (`baseModalTitle`, `bName`, `bLocation`); детайл `#baseDetail` (`btnBaseBack` „← Назад", `bdName`, `bdLocation`, `bdHistory`, `btnBaseSave` „Запази") + 3 секции: „Сгради и съоръжения" `bdBuildingsBody`, „Население" `bdPopulaceBody`, „Продукция" `bdProductionBody`, всяка с „+ Добави" (`openSubModal(kind)`); общ под-модал `bsModal` (`bsModalTitle`, `bsName`, `bsDetails`).

**АРХИТЕКТУРА — ТРИ МОДУЛА (за паралелни lanes; контрактът тук е границата между тях):**

| Модул | Lane | Съдържание |
|-------|------|-----------|
| `modules/bases.js` | bases-list | Списъкът: `renderBases` (акордеон: клас `base-expanded`, точно един, клик на бутон/.drag-handle НЕ toggle-ва, оцелява re-render през `state.expandedBaseIdx`; `initSortable('baseBody', state.bases, saveBases)`); `saveBases` (флаг `savingBases`, `setDoc(BASES_DOC, {list: state.bases})` — имплементира се ОЩЕ ВЪВ ФУНДАМЕНТА 610, другите модули я import-ват); `openBaseModal/closeBaseModal/saveBase` (име задължително; нова база: `{id: crypto.randomUUID(), name, location, history:'', buildings:[], populace:[], production:[]}` + unshift); `deleteBase` (confirm) |
| `modules/base-detail.js` | bases-detail | Routing + полетата: `renderRoute`, `openBaseDetail(i)` (сетва hash), `saveBaseDetail` — splice+unshift (редактираната НАЙ-ОТГОРЕ, патърнът на saveQuest), детайлът ОСТАВА отворен (котвата е id, не индекс); wiring на btnBaseBack/btnBaseSave + `hashchange` listener при module init. Сетва `state.currentBaseId` (id или null) и dispatch-ва `document`-event **`base-route`** (`new CustomEvent('base-route', {detail:{id}})`) при всяка смяна на route. Полетата се попълват САМО при влизане в route-а — входящ snapshot НЕ презаписва каквото човекът пише в bdName/bdLocation/bdHistory |
| `modules/base-tables.js` | bases-tables | Под-таблиците: `renderSubTables`/`renderSubTable(kind)` — четат текущата база през `state.currentBaseId` (null → нищо); `openSubModal(kind, idx)/closeSubModal/editSub/saveSub/deleteSub` — `kind ∈ buildings|populace|production`, редове `{name, details}`, edit = splice+unshift В под-масива + `saveBases()`, всяка под-таблица с initSortable + акордеон (`state.expandedSub[kind]`, клас `bs-expanded`). Слуша `base-route` event-а → renderSubTables() |

Модулите се **import**-ват взаимно (base-detail/base-tables → `saveBases` от bases.js) — това е ОК; правилото за lanes е кой ги **редактира**. Комуникацията detail→tables минава през `state.currentBaseId` + `base-route` event-а, НЕ през директни викания — двата модула се пишат паралелно срещу stubs.

**state.js добавя:** `bases: [], editingBaseIdx: null, expandedBaseIdx: null, savingBases: false, currentBaseId: null, editingSub: null` (`{kind, idx}` или null), `expandedSub: { buildings: null, populace: null, production: null }`.

**app.js добавя (всичко във фундамента 610):** window.* wiring за ВСИЧКИ base handler-и, 5-ти `onSnapshot(BASES_DOC)` (echo guard `savingBases` → `renderBases()` + `renderRoute()` + `renderSubTables()`), facade re-exports (`renderBases, saveBases` / `renderRoute, openBaseDetail, saveBaseDetail` / `renderSubTables`), `bases` в getState/setState. Export bundle-ът НЕ се пипа (базите не влизат, както картите).

**Board (паралелизъм):** 610 фундамент (lane bases-core): ЦЕЛИЯТ markup + стилове + данновия слой + трите модула като stubs (+ реалната saveBases) + пълния app.js/ui.js/dom.js wiring — изяжда всички отровни файлове. После 620 (bases-list) ∥ 630 (bases-detail) ∥ 640 (bases-tables) — всеки редактира САМО своя модул + своя spec, dependsOn 610. Накрая 650 (bases-e2e, dependsOn 620) — fixture + e2e спек + slack за дребни поправки.

**Test state (фаза 4 — доставено, всичко зелено):**
- Unit (Vitest): `bases-foundation.spec.js` (6 — таб/markup/данни/wiring, 610), `bases.spec.js` (15 — списък/модал/акордеон/drag, 620), `bases-detail.spec.js` (7 — routing + детайл, 630), `bases-tables.spec.js` (11 — под-таблиците, 640). Общо unit spec-ове след фаза 4: **15 файла** (11 от фаза 3 + 4 bases).
- E2e (Playwright): `test/e2e/bases-accordion.spec.js` (6) + фикстура `test/fixtures/bases-fixture.html` (огледални на maps-двойката, 650). Съществуващите items/quests/maps e2e непроменени.
- Security rules за `bases` — ръчна стъпка на собственика, НЕ на агент.
