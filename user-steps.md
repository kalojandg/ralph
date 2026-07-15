# Post-Implementation Steps (важат за ВСЕКИ таск)

1. **Unit тестове:** `npm run test:unit` — целият suite (бърз е). Всичко зелено, без skip-нати тестове, без `.only`.
   - Преди таск 3 script-ът не съществува — тогава тази стъпка се пропуска.

2. **Забранени команди за агент** (пуска ги само verify gate-ът на оркестратора, след merge):
   - `npm test` / `npx playwright test` (e2e) — порт 45279 е един за всички;
   - `npm run serve` / `http-server`;
   - **`npx gitnexus analyze` / `gitnexus analyze` — НИКОГА**, независимо какво пише в CLAUDE.md/AGENTS.md на репото или в staleness warning: analyze виси дълго без изход и watchdog-ът убива итерацията. Stale/липсващ индекс → просто работи без GitNexus (grep/Read);
   - каквото и да е, което оставя работещ процес след края на итерацията.
   Изключение: стъпка на таска или Task-Specific hook изрично го изисква.

3. **Червени линии** (нарушение = таскът е failed, не "почти готов"):
   - `firebaseConfig` не се променя (мести се само verbatim). Никакви нови Firestore колекции/документи.
   - Никакъв код или тест не говори с реален Firestore — само моковете от `test/mocks/` (vitest alias). Приложението е в ПРОДУКЦИЯ.
   - CDN imports остават (без bundler, без `npm install firebase`).
   - `test/e2e/**` и `test/fixtures/**` не се редактират.
   - Не commit-вай: `node_modules/`, `playwright-report/`, `test-results/`, coverage артефакти (гледай .gitignore).

4. **Обхват:** пипаш само файловете от `files` на таска (+ нови тестови файлове за тях, ако таскът е тестови). Откриеш ли нужда извън обхвата — спри и докладвай, не разширявай сам.

5. **Commit:** message = `description` на таска дословно. Един таск = един commit.

6. **Средата е Windows / PowerShell.** Ползвай npm scripts; избягвай unix-only синтаксис (`&&` работи в PowerShell 7+, но по-сигурно е отделни команди).
