# Prerequisite: Read Before Implementation

Изпълняват се СЛЕД избора на таск, ПРЕДИ да напишеш и ред код.

1. **Repo routing:** отвори `ralph reference/project reference/repos.json` (спрямо ralph/ директорията). Намери `repo`-то на таска (в този проект всичко е `frontend` → shared-inventory). Оттам взимаш:
   - `location` — работната директория (в PARALLEL MODE работната директория ти е подадена — worktree; `location` е само за справка);
   - `reference` — architecture файла в `ralph reference/project reference/`.

2. **Прочети `shared-inventory-structure.md`** — задължително:
   - §2 (инвентар на кода) и §4 (поведенчески тънкости) — за всеки таск;
   - §5 + §6 (test инфраструктура и bootApp контракт) — за тестови таскове (10-14) и за таск 3;
   - §7 (целева модулна структура) — за refactor таскове (20-26);
   - §3 (червени линии) — ВИНАГИ.

3. **Прочети `specRef` секцията** на таска, ако е посочена.

4. **Разгледай реалния код** в границите на `files` списъка на таска, преди да пишеш.

5. **Setup на worktree:** ако липсва `node_modules` → `npm ci` (веднъж). Нищо друго не се инсталира глобално.
