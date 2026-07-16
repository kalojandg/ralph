# Spell App — Architecture Reference

> Прочети ПРЕДИ код по repo `spells`. D&D Spellbook PoC. Vanilla JS (type: module), без bundler.

## Файлове

```
spell_app/
├── index.html
├── js/                 ← МОДУЛЕН: api.js (външен spells API), app.js, caster.js, details.js,
│                          slots.js, spells.js, state.js
├── requirements/       ← спецификации
├── scripts/read-test-results.js
└── playwright.config.js  ← ⚠ СЧУПЕН КОНТРАКТ: сочи testDir './test/e2e' (НЕ съществува) и
                             webServer 'npm run serve' (НЯМА такъв script; dev е live-server на 3000)
```

## Модел

- **Персистенция: localStorage** (state.js); api.js говори с външен D&D spells API.
- Вече модулен — `files` boundary за таск = неговият js/ модул.
- Repo-то има собствен CLAUDE.md/AGENTS.md — ⛔ НЕ пускай `gitnexus analyze`.

## ⚠ Тестово състояние (важно за verify gate-а и за първите таскове)

- **`npm test` В МОМЕНТА Е СЧУПЕН**: playwright конфигът очаква test/e2e/ и `npm run serve`, а няма нито едното.
- Затова repo-то в repos.json НЯМА e2e във verify масива — гейтът пуска само unit (--if-present, т.е. нищо, докато няма).
- **Кандидат за първи таск по това репо:** bootstrap на тестовете — добави `serve` script (http-server, порт 45279 като другите или собствен), създай test/e2e/ с basic smoke спек, и ЧАК ТОГАВА добави "npm test" във verify масива на repos.json (това е ralph config промяна — отбележи я в result summary, не я прави сам).

## Команди / портове

```
npm ci                  # в нов worktree
npm run dev             # live-server на порт 3000 — НЕ пускай от агент
```
- Playwright baseURL сочи 45279 (споделен с inventory/hero) — при оправяне на тестовете съобрази.

## Червени линии

1. api.js контрактът с външния API не се сменя без изричен таск.
2. localStorage схемата = контракт; миграция само като изрична стъпка.
3. Не пипай playwright.config.js освен в таск, който изрично оправя тестовата инфраструктура.
