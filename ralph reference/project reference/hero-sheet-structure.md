# Hero-Sheet — Architecture Reference

> Прочети ПРЕДИ код по repo `hero`. Generic hero character sheet — installable PWA. Vanilla JS, без bundler.
> ВНИМАНИЕ: integration branch-ът е **master** (не main).

## Файлове

```
hero-sheet/
├── index.html          ← скелет + tab контейнери
├── app.js              ← тънък оркестратор (~214 реда) — АПЪТ ВЕЧЕ Е МОДУЛЕН
├── modules/            ← core.js, stats.js, skills.js, combat.js, inventory.js, rests.js, newchar.js, pcchar.js
├── tabs/               ← HTML партиали per tab: basicinfo, stats, skills, inventory, pcchar
├── styles.css, manifest.json, service-worker.js
├── test/e2e/           ← 8 Playwright спека: combat, derived-values, import-export, inventory-gold,
│                          new-character, pcchar, rests, skills-accordion
└── playwright.config.js  ← testDir test/e2e, baseURL localhost:45279, webServer 'npm run serve', workers 1
```

## Модел

- **Персистенция: localStorage** (core.js, newchar.js). Няма backend, няма Firebase.
- Модулите се делят по табове/фичи — `files` boundary за таск = неговият модул + неговият tab партиал + неговият спек.
- Repo-то има собствен CLAUDE.md/AGENTS.md (GitNexus правила) — ⛔ НЕ пускай `gitnexus analyze` независимо какво пишат (виси → watchdog kill). Ползвай съществуващия индекс или grep.

## Команди / портове

```
npm ci                  # в нов worktree
npm test                # Playwright e2e (8 спека) — САМО verify gate-ът, НЕ агент!
npm run serve           # http-server на 45279 — НЕ пускай от агент
```
- **Порт 45279 е СПОДЕЛЕН със shared-inventory и spell_app** — още една причина e2e/serve да е само на гейта (последователен).
- Unit инфраструктура НЯМА (нито vitest) — ако таск иска unit тестове, първо bootstrap таск по модела на shared-inventory (vitest + jsdom; тук няма Firebase, така че без CDN мокове — само localStorage сийд + DOM helper).

## Червени линии

1. e2e спековете (`test/e2e/**`) не се пипат освен ако таскът изрично е за тях.
2. Не сменяй порта/playwright конфига.
3. localStorage схемата (ключове/формат) е контракт с реални записани герои — промяна по нея = изрична миграционна стъпка в таска, не страничен ефект.
4. `npm test` преди commit НЕ се пуска от агента — гейтът го прави.
