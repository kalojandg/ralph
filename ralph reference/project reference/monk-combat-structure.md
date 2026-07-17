# Monk Combat App — Architecture Reference

> Прочети ПРЕДИ код по repo `combat`. D&D Monk/Cleric character sheet (v3) с автоматизирани тестове. Vanilla JS, без bundler.
> Това е НАЙ-ГОЛЯМОТО и най-старото приложение — очаквай наслоена история.

## Файлове

```
monk_combat_app/
├── index.html          ← скелет + tab-nav; табовете се зареждат динамично (loadTabs -> fetch tabs/*.html)
├── app.js              ← ЯДРОТО ~2468 реда: state (st.*), derived values, tab loading, оркестрация.
│                          Приложението Е модулно (разделено под характеризационни тестове от 1 app.js
│                          + 1 html по ~3000 реда) — но ядрото остава голямо: пипай хирургично, малки таскове.
│                          ⚠ ЧАСТ от модулната логика има ИСТОРИЧЕСКИ ДУБЛИКАТИ в app.js (напр.
│                          attachOneLiners/attachExcuses са и в modules/, и копирани в app.js ~ред 1219+) —
│                          при премахване/промяна удряй ДВЕТЕ места.
├── modules/            ← фича модули (IIFE, window.attachX): aliases, excuses, familiars, insults,
│                          inventory, newchar, npc-names, one-liners, pcchar, quests, spells-mark
├── tabs/               ← HTML партиали per tab (fetch-ват се от loadTabs)
├── styles.css, manifest.json, service-worker.js
├── *.json данни        ← cleric-features, familiars, excuses, insults, npc-names, one-liners, shenanigans,
│                          skills-and-features, dark-jokes, tasha-jokes — данните са в JSON файлове, не в кода
├── docs/, BEHAVIOR_DOCUMENTATION.md, TEST_CASES.md, QUESTS_FEATURE_PRD.md ← четивна документация за поведение
├── test/e2e/           ← Playwright спекове (+ test/README.md)
└── playwright.config.js  ← testDir test/e2e, baseURL localhost:45278, webServer 'npm run serve', workers 1
```

## Модел

- **Персистенция: localStorage.** Multiclass: `st.monkLevel` / `st.clericLevel` split (Death Domain, interleaved accordion) — виж BEHAVIOR_DOCUMENTATION.md преди да пипаш level/class логика.
- Данните (шеги, фамилиари, features) са в JSON файлове — таск за съдържание пипа САМО json, не кода.
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

## Червени линии

1. app.js е голямо споделено ядро — таск, който го пипа = МАЛЪК обхват, един регион, след прочит на BEHAVIOR_DOCUMENTATION.md за областта. Внимавай за историческите дубликати (modules/ vs копия в app.js).
2. `test/e2e/**` не се пипат освен ако таскът е за тях. TEST_CASES.md описва очакваното поведение — при съмнение той печели.
3. localStorage схемата на героя е жив контракт (реални персонажи) — миграция само като изрична стъпка.
4. Не commit-вай runtime боклук: playwright-report/, test-results/, tmpclaude-*, logs/ (има заварени такива в репото — не ги умножавай).
