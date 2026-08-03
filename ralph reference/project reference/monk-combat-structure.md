# Monk Combat App — Architecture Reference

> Прочети ПРЕДИ код по repo `combat`. D&D Monk/Cleric character sheet (v3) с автоматизирани тестове. Vanilla JS, без bundler.
> НАЙ-ГОЛЯМОТО и най-старото приложение — очаквай наслоена история. Актуализиран: 2026-08-03 (след Cube of Force widget-а + face темите).

## Файлове

```
monk_combat_app/
├── index.html          ← скелет + tab-nav (8 таба: Stats, PC Characteristics, Resurrection, Inventory,
│                          Flavor, Skills, Session Notes, Names); табовете се зареждат динамично
│                          (loadTabs -> fetch tabs/*.html)
├── app.js              ← ЯДРОТО ~2400+ реда: state (st.*), derived values, tab loading, bundle
│                          (buildBundle/applyBundle), оркестрация. Пипай хирургично, малки таскове.
├── modules/            ← фича модули (IIFE, window.attachX):
│                          flavor.js   — 17-типов registry генератор на реплики (Flavor таба)
│                          namegen.js  — Names таба: alias/familiar/npc с per-type save routing
│                          tts.js      — Google Cloud TTS, гласът на Пийс (виж „TTS" по-долу)
│                          inventory.js, newchar.js, pcchar.js, quests.js, spells-mark.js
├── tabs/               ← HTML партиали per tab (flavor, namegen, inventory, pcchar, quests,
│                          resurrection, sessionNotes, skills, stats + 3 stats под-партиала)
├── styles.css, manifest.json, service-worker.js
├── *.json данни        ← one-liners, excuses, insults, dark-jokes, tasha-jokes (Flavor);
│                          familiars, npc-names (Names); cleric-features, skills-and-features…
│                          Съдържателен таск пипа САМО json, не кода.
├── TTS-SETUP.md        ← как е настроен Google TTS ключът/ограниченията
├── docs/, BEHAVIOR_DOCUMENTATION.md, TEST_CASES.md ← четивна документация за поведение
├── test/e2e/           ← 32 Playwright спек файла (вкл. flavor-ui, namegen-ui, tts-core,
│                          flavor-tts, flavor-text-quality)
└── playwright.config.js  ← testDir test/e2e, baseURL localhost:45278, webServer 'npm run serve', workers 1
```

## Модел

- **Персистенция: localStorage, всичко в `st`.** Multiclass: `st.monkLevel`/`st.clericLevel` (Death Domain, interleaved accordion) — чети BEHAVIOR_DOCUMENTATION.md преди level/class логика. `st.aliases`, `st.npcNames`, `st.familiars` (унифицирани — bundle-ът ги round-trip-ва и трите).
- **Bundle v2** (buildBundle/applyBundle) = export/import контрактът; нов тип запис → влиза в `st`, НЕ в отделен localStorage ключ (урокът от familiars бъга).
- **TTS (modules/tts.js):** Google Cloud Text-to-Speech, on-demand (клик = заявка, без кеш, без .mp3 в репото), fallback към браузърния speechSynthesis при липсващ ключ/грешка. Ключът е комитнат НАРОЧНО (прието решение): ограничен по HTTP referrer (localhost dev + GitHub Pages) и само за TTS API, $2 billing аларма + rate limits + капната карта. ⛔ Chirp3-HD гласовете връщат 400 при `pitch` параметър — не го добавяй.
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

- **Baseline 2026-07-27: 452 passed, 0 failed, 13.2 мин** (пълен suite, ексклузивен порт) — събира се комфортно в 45-мин гейт таван.
- Legacy спековете (отпреди multiclass модала) носят auto-Monk resolver в beforeEach (interval кликащ cardMonk) — НЕ го махай при редакция; нов тест, който вдига ниво, сетва `st.level` + `st.monkLevel` + `st.clericLevel` директно ИЛИ разчита на resolver-а.
- npc-names.spec.js е DATA-DRIVEN (чете пуловете от npc-names.json) — не връщай hardcoded списъци с имена.

## Червени линии

1. app.js е голямо споделено ядро — таск, който го пипа = МАЛЪК обхват, един регион, след прочит на BEHAVIOR_DOCUMENTATION.md за областта.
2. `test/e2e/**` не се пипат освен ако таскът е за тях. TEST_CASES.md описва очакваното поведение — при съмнение той печели.
3. localStorage схемата на героя е жив контракт (реални персонажи) — миграция само като изрична стъпка. Нов persistent тип → в `st` (bundle-ът да го носи).
4. **TTS ключът**: не го мести, не го логвай, не разхлабвай referrer restriction-а; no-key fallback пътят е задължителен (апът работи и без ключ). Външни API ключове в ДРУГИ таскове не се комитват без изрично решение като това.
5. Не commit-вай runtime боклук: playwright-report/, test-results/, tmpclaude-*, logs/.
