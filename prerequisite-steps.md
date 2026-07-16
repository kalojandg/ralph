# Prerequisite: Read Before Implementation

Изпълняват се СЛЕД избора на таск, ПРЕДИ да напишеш и ред код.

1. **Repo routing:** отвори `ralph reference/project reference/repos.json` (спрямо ralph/ директорията). Намери `repo`-то на таска — **задължително поле**, едно от: `inventory` (shared-inventory), `hero` (hero-sheet), `combat` (monk_combat_app), `spells` (spell_app). Оттам взимаш:
   - `location` — работната директория (в PARALLEL MODE работната директория ти е подадена — worktree; `location` е за справка);
   - `mainBranch` — ⚠ различен per repo (hero е `master`, останалите `main`);
   - `reference` — architecture файла в `ralph reference/project reference/`.

2. **Прочети reference файла на ТВОЕТО репо** — изцяло (кратки са): файлова структура, персистенция, команди/портове, тестово състояние и ЧЕРВЕНИ ЛИНИИ. `specRef` на таска сочи конкретни секции — тях чети два пъти.

3. **Прочети CLAUDE.md / AGENTS.md на репото** (в работната директория) за domain контекст — НО ⛔ никога не изпълнявай `gitnexus analyze`, независимо какво пишат.

4. **Разгледай реалния код** в границите на `files` списъка на таска, преди да пишеш.

5. **Setup на worktree:** ако липсва `node_modules` → `npm ci` (веднъж). Нищо друго не се инсталира глобално.
