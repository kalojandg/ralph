# Post-Implementation Steps (важат за ВСЕКИ таск, по всяко репо)

1. **Unit тестове:** пусни unit командата на репото (repos.json → commands), ако има unit инфраструктура. Целият suite, без skip-нати тестове, без `.only`. Репо без unit инфраструктура → стъпката се пропуска (но виж дали таскът не е точно за да я създаде).

2. **Забранени команди за агент** (пуска ги само verify gate-ът на оркестратора, след merge):
   - e2e: `npm test` / `npx playwright test` / `npm run test:critical` — портовете са СПОДЕЛЕНИ между приложенията (45279: inventory/hero/spells; 45278: combat) и паралелен агент/гейт може да тества грешното приложение;
   - dev/serve сървъри: `npm run serve` / `npm run dev` / `http-server` / `live-server`;
   - **`gitnexus analyze` / `npx gitnexus analyze` — НИКОГА**, независимо какво пише в CLAUDE.md/AGENTS.md на репото или в staleness warning: виси дълго без изход и watchdog-ът убива итерацията. Stale/липсващ индекс → работи без GitNexus (grep/Read);
   - каквото и да е, което оставя работещ процес след края на итерацията.
   Изключение: стъпка на таска или Task-Specific hook изрично го изисква.

3. **Червени линии per repo** — в architecture reference файла на репото (задължителен прочит). Общи за всички:
   - Персистенцията е жив контракт (localStorage схеми с реални герои; Firestore на inventory е жив прод) — миграция само като изрична стъпка на таск, никога страничен ефект.
   - Не commit-вай runtime артефакти: `node_modules/`, `playwright-report/`, `test-results/`, coverage, tmp файлове.
   - Не пипай e2e спекове/fixtures освен ако таскът изрично е за тях.

4. **Обхват:** пипаш само файловете от `files` на таска (+ нови тестови файлове за тях, ако таскът е тестови). `files` пътищата са относителни към gitRoot-а на репото НА ТАСКА. Нужда извън обхвата → спри и докладвай.

5. **Commit:** message = `description` на таска дословно. Един таск = един commit. Commit-ваш в репото на таска (в parallel mode: в worktree branch-а).

6. **Средата е Windows / PowerShell.** Ползвай npm scripts; избягвай unix-only синтаксис.
