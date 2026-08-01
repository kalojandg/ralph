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
├── modules/              ← след фаза REFACTOR (таскове 20-26): firebase.js, state.js, gold.js, items.js, quests.js, ui.js
├── sw.js                 ← service worker (регистрира се от малък inline classic script — ОСТАВА в index.html)
├── manifest.json         ← PWA manifest
├── vitest.config.js      ← след таск 3 (unit test инфраструктура)
├── test/
│   ├── e2e/              ← Playwright specs (items-accordion, quests-accordion) — НЕ СЕ ПИПАТ
│   ├── fixtures/         ← standalone HTML фикстури за e2e — НЕ СЕ ПИПАТ (те са собственост на e2e)
│   ├── mocks/            ← след таск 3: firebase-app.js, firebase-firestore.js (виж §5)
│   ├── helpers/          ← след таск 3: dom.js (bootApp helper, виж §6)
│   └── unit/             ← unit тестове (фаза 1, таскове 10-14)
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
| LISTENERS | 3× `onSnapshot`: gold (missing→zeros), items (игнорира при `saving`), quests (игнорира при `savingQuests`; сетва `#syncStatus` = 'Live sync ✓' и `window.__appReady = true`) |
| EXPORT/IMPORT | `window.exportData` (bundle {version:1, exportedAt, gold, items, quests} → download), `window.importData` (confirm → setDoc за наличните ключове; невалиден JSON → alert) |
| PWA | `beforeinstallprompt` → `#btnInstall` |

DOM id-та: `sync, syncStatus, dispPP/GP/SP/CP, inPP/GP/SP/CP, goldError, invBody, invFooter, questBody, itemModal (iName,iCat,iQty,iWeight,iValue,iCarrier,iNote), questModal (qName,qStatus,qGiver,qDesc,qReward,qNote), btnInstall`.

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
- `deleteItem`/`deleteQuest`/`importData` ползват `confirm()`; `importData` ползва `alert()` при невалиден JSON — в jsdom ги стъбваш.

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
setDoc(token, data) / updateDoc / deleteDoc / getDoc   // записват в calls + resolve-ват
onSnapshot(token, cb)                   // регистрира cb; връща unsubscribe
export const calls = { setDoc: [], updateDoc: [], deleteDoc: [] };   // [{token, data}]
export function __emit(token, data)     // вика регистрираните cb-та със snap: { exists: () => data !== null, data: () => data }
export function __reset()               // чисти calls + listeners
```

## §6. Как се пише unit тест (контракт на helper-а от таск 3)

`test/helpers/dom.js`:
```js
export async function bootApp({ gold = null, items = null, quests = null } = {})
// 1. чете index.html, взима <body> markup-а БЕЗ <script> таговете → document.body.innerHTML
// 2. стъбва globalThis.Sortable (class със constructor(el, opts) { el._sortable = this; this.opts = opts; } и destroy(){}),
//    window.confirm = () => true (тестът го override-ва при нужда), window.alert = () => {}
// 3. vi.resetModules(); __reset() на firestore мока
// 4. await import('../../app.js')   ← app.js top-level кодът се изпълнява (populate carrier, listeners)
// 5. __emit за трите дока: 'inventory/gold' (gold), 'inventory/items' (items===null ? null : {list: items}),
//    'quests/items' (quests===null ? null : {list: quests})
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

## §9. Maps фича (фаза 3 — одобрена от собственика, lane `maps`)

Таб „Карти": ДМ-ът качва карти (скрийншоти) от лаптоп/браузър, партито гледа на Android таблет.
Пълната спека: `maps-feature-plan.md` в корена на репото.

**Данни (решено, не се предоговаря):** колекция `maps` — `maps/index` = `{ list: [{id, shortDesc, details, createdAt}] }` (ред = ред на показване; същият патърн като ITEMS_DOC), `maps/<uuid>` = `{ image: '<data URL>' }` (по един док на карта; снимката е ОТДЕЛНО от индекса — 1MB/док лимит + snapshot-ът на индекса да не тегли снимки). Компресия client-side (canvas, ~1600px, JPEG ~0.72) в `modules/image.js` — но САМО при нужда: прагът е `MAX_IMAGE_BYTES = 900000` върху **data URL дължината** (base64 надува ~33%, Firestore лимитът е 1MiB/док); под прага оригиналът се пази непипнат, над него компресия → втори по-агресивен опит → грешка в диалога. БЕЗ Firebase Storage, БЕЗ нови npm пакети. Firestore е schema-less — доковете възникват при първия запис; security rules за колекция `maps` са ръчна стъпка на собственика в конзолата, НЕ на агент.

**Амендмънти на §3 (САМО за тази фаза, всичко останало важи):**
1. §3.1 „не създавай нови колекции" → колекция `maps` е РАЗРЕШЕНА (единствено тя). `firebaseConfig` остава непипнат.
2. §3.5 „test/e2e/ и fixtures не се пипат" → НОВИ `maps-*` файлове там са разрешени; съществуващите — не.
3. §5 мокът се разширява АДИТИВНО: вътрешен store, `setDoc` пише и в store-а, `getDoc` чете от него (незасят token → `exists:false` както днес), нов export `__setDocData(token, data)`. Старите тестове остават зелени.
4. §6 `bootApp` получава адитивен параметър `maps = null` → `__emit('maps/index', maps === null ? null : {list: maps})`.

**Нови модули/id-та:** `modules/maps.js` (render/modal/save по образеца на quests.js), `modules/image.js` (fitDimensions чиста + compressImage тънка), `modules/viewer.js` (fullscreen zoom/pan; чиста геометрия `zoomAt`/`clampScale`). DOM: таб `tab-maps`, `mapTable/mapBody`, модал `mapModal` (`mShort`, `mDetails`, `mFile`, `mPreview`, `mMapError`), overlay `#mapViewer`. State: `maps, editingMapIdx, expandedMapIdx, savingMaps`.

**Извън обхват:** export/import bundle-ът (v1) НЕ включва картите (снимките биха издули JSON-а). sw.js не се пипа (network-first покрива новите модули).
