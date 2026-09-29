---
name: ralph-setup
description: Bootstrap на нов проект/репо за Ralph swarm — GitNexus индекс (разкачен, пуска се пръв), repos.json запис, per-machine repos.local.json, structure reference, отровен списък, verify команди и предстартовия чеклист (зелен baseline!). Ползвай при закачане на ralph към ново репо или нова машина.
---

# Ralph Setup — закачане на нов проект

RALPH_ROOT = директорията на ralph репото (тук: `D:\Downloads\monk\ralph`; иначе — намери `ralph-swarm.ps1`). Шаблоните за подражание: съществуващите записи в `project reference/repos.json` и `*-structure.md` файловете там.

## 0. GitNexus индекс — ПУСНИ ГО ПЪРВО, разкачен (върви, докато правиш останалото)
`analyze` може да отнеме **30+ минути** на голямо репо, а нищо в стъпки 1–3 не го чака. Затова
е стъпка нула и е РАЗКАЧЕН процес — същият патърн като `finish_index` в оркестратора
(`ralph-swarm.ps1`, „ONCE, at the very end, FIRE-AND-FORGET"): пускаш го, връщаш се на setup-а,
готов е някъде докато пишеш structure reference-а.

Редът има значение — **първо изключването, после анализът**, иначе `.gitnexus/` излиза untracked
и прави следващите merge-ове „dirty-skipped":

```powershell
# 0.1 веднъж на МАШИНА (не на репо): закача MCP-то към Claude Code
npx gitnexus setup

# 0.2 ПРЕДИ анализа: артефактът вън от погледа на git
#     свое репо -> .gitignore;  чуждо/екипно -> .git/info/exclude (per-clone, невидим за колегите)
Add-Content "<gitRoot>\.git\info\exclude" ".gitnexus/"

# 0.3 разкачено, минимизирано, с лог — и продължаваш напред веднага
$log = "RALPH_ROOT\logs\gitnexus-setup-<key>-$(Get-Date -Format yyyyMMdd-HHmmss).txt"
Start-Process powershell.exe -ArgumentList "-NoProfile","-Command", `
  "`$host.UI.RawUI.WindowTitle = 'GitNexus analyze: <key>'; Set-Location '<location>'; npx gitnexus analyze *> '$log'" `
  -WindowStyle Minimized
```

Прозорецът в лентата = още върви; изчезнал = готово (както при finish_index). Проверка: `gitnexus status`.
Резултат: `.gitnexus/` + `AGENTS.md`/`CLAUDE.md` в корена — **тях ги комитваш** (ралф ги
преподновява сам след всеки run).
⚠ Без тази стъпка `finish_index` на ПЪРВИЯ run пада тихо в лога: оркестраторът вика
`npx --no-install gitnexus analyze` нарочно, за да не инсталира нищо зад гърба ти — но на
неиндексирано репо това значи „нищо не се случи", без вик.

## 1. repos.json запис
Във `RALPH_ROOT/ralph reference/project reference/repos.json` → `repos.<key>`:
- `location` / `gitRoot` / `workSubdir` — при солюшън с много сървиси: ЕДИН gitRoot, зоните се управляват от lanes/files, не от отделни записи;
- `mainBranch` — ПРОВЕРИ реално: `git -C <gitRoot> rev-parse --abbrev-ref HEAD` (репотата се различават: main/master/dev!);
- `reference` — името на structure файла (стъпка 2);
- `verify` — гейт командите, бързите първи (напр. `["npm ci --no-audit --no-fund", "npm run --if-present test:unit", "npm test"]`). Репо без работещи тестове → БЕЗ e2e във verify + бележка в reference-а, че първият таск е тестовият bootstrap;
- `commands` — как се пускат unit/e2e/dev, с бележка кое е ЗАБРАНЕНО за агенти (e2e/сървъри = само гейтът).
⚠ `repo` полето в тасковете е задължително — дефолт няма.

## 1а. rules/ папка в репото (по избор, с ПРИОРИТЕТ при код ревю)
Finishing review stage-ът търси `<repo>/rules/` папка: ако съществува и има файлове — ТЕ са
обвързващият правилник за ревюто (structure reference-ът остава за червените линии); ако я
няма — ревюто се движи само по structure reference-а. Употреба: на служебно/чуждо репо
просто сложи правилата на екипа в `rules/` и ревюто ги прилага out-of-the-box, без ralph
конфигурация. За нов проект: попитай потребителя дали иска rules/ (за Party Up-мащаб — да:
architecture-rules.md + i18n-rules.md; за малък ап — стига кратък code-rules.md или нищо).

## 1б. `repos.local.json` — per-machine застъпване (лекът за преноса)
`repos.json` носи **абсолютни** пътища и пътува през git, затова на всяка нова машина
`location`/`gitRoot` се разминават — и рецидивът беше ръчно пренаписване при всеки пренос
(а после конфликт при следващия pull). Затова до него живее **`repos.local.json`**,
**gitignore-нат**, който застъпва само подадените полета:

```json
{ "repos": { "partyup": { "location": "C:\\work\\party-up", "gitRoot": "C:\\work\\party-up" } } }
```

Правила: чете се от `ralph-swarm.ps1` веднага след `repos.json`; **merge е per поле** (каквото не си подал, остава от `repos.json`); липсващият файл значи „нищо не се променя"; ключ, който няма запис в `repos.json`, се ПРОПУСКА с жълто `[!]`, а всяко застъпване се обявява с циан `[i]` при старта — тоест виждаш в конзолата какво е било застъпено, без да гадаеш. Обхватът е ЦЕЛИЯТ запис на репото, не само пътищата: `mainBranch`, `verify`, `commands` също се застъпват, ако машината го иска.
⚠ Ключът трябва да е ТОЧНО като в `repos.json` (там е `partyup`, не `party-up`) — печатка не гърми, а се пропуска с жълто предупреждение.
⚠ Соло `ralph.ps1` НЕ чете застъпването — само swarm оркестраторът.

## 2. Structure reference (`<key>-structure.md`)
Задължителни секции (виж shared-inventory-structure.md като образец):
- файлова карта + инвентар на кода (региони/модули, с реални имена);
- модел на персистенция (localStorage ключове/схеми, DB, външни API-та) — кое е ЖИВ КОНТРАКТ;
- **ЧЕРВЕНИ ЛИНИИ** (нарушение = failed таск): конфиг/секрети не се пипат, прод хранилища не се докосват от тестове, кое не се редактира;
- **ОТРОВЕН СПИСЪК**: споделените/cross-cutting файлове (DI, router, locales, package.json, contracts, солюшън файлове) → те диктуват соло lanes;
- команди и ПОРТОВЕ (провери за колизии с другите репота във флота! заети: 45279 inventory/hero/spells, 45278 combat);
- тестово състояние: какво има, какво липсва, колко трае пълният suite.

## 3. Предстартов чеклист (платен с кръв — не прескачай)
1. **ЗЕЛЕН BASELINE**: пълният suite на ЕКСКЛУЗИВЕН порт — нула работещи агенти, нула чужди сървъри (`reuseExistingServer` иначе мери грешно приложение). Червените се оправят ПРЕДИ board (фосилите иначе горят retry бюджети). Запиши колко трае → сверка с `swarm.verify_timeout_min` (config, сега 45 мин).
2. Integration branch: checked out + ЧИСТ (`git status --porcelain` празен) — мръсен checkout = MERGE SKIPPED на всичко. **И ЗАДЪЛЖИТЕЛНО ПОПИТАЙ ПОТРЕБИТЕЛЯ**: „В момента сте на клон '<current>' и агентите ще merge-ват в '<mainBranch>' — да?"; при „не" → създай/checkout-ни посочения от него клон И обнови `repos.json → mainBranch`. Board към прод клон (main/master/develop) само след изрично „да" — никога по подразбиране.
3. `.gitignore` покрива runtime артефактите (node_modules, playwright-report, test-results, coverage) — verify команди, оставящи untracked файлове, правят следващите merges "dirty-skipped". За артефакти на ЛИЧНИ инструменти в чуждо/екипно репо (gitnexus индекси и подобни): **`.git/info/exclude`** (per-clone, не се комитва, невидим за колегите) или `core.excludesFile` глобално — иначе untracked боклукът им спира merge-овете на ралф.
4. Env файлове: untracked `.env*` се копират в worktrees от оркестратора — провери, че са в location root-а.
5. Среда: `claude --version` (моделите в config-а се поддържат?), git версия (worktree-ите искат ≥2.5; `--show-current` иска ≥2.22 — оркестраторът ползва rev-parse), диск за worktrees (~размер на репото × агенти).
6. `ralph-config.json`: модел (`use_api_key:false` = абонамент), `swarm` бюджети (retries 4/4, escalate_after 2), `verify_timeout_min` спрямо baseline мярката. **Пълният справочник на настройките (всяко поле, дефолт, рецепти за квотна криза/демо/бавна машина): скилът `/ralph-config`** — там се и ДОКУМЕНТИРА всяка нова настройка, в същата промяна.

## 4. Пренос на нова машина
1. Клонирай ralph репото (скиловете и референциите пътуват с него — `.claude/skills/` важат автоматично при работа В репото);
2. За извикване отвсякъде: копирай скиловете на потребителско ниво: `cp -r <RALPH_ROOT>/.claude/skills/* ~/.claude/skills/`;
3. **НЕ пипай `repos.json`** — направи `repos.local.json` до него с новите `location`/`gitRoot` (т.1б). Файлът е gitignore-нат, тоест машините не си стъпват по пътищата и следващият pull минава без конфликт;
4. **GitNexus е per-clone, не пътува** — `.gitnexus/` е изключен от git, значи на новата машина репото е НЕиндексирано, колкото и да е индексирано на старата. Мини т.0 за всяко репо (пусни ги разкачени едно след друго, вървят си паралелно, докато ти правиш т.2/т.3);
5. Мини чеклиста от т.3 (нова машина = нова среда = нови изненади: CLI версия, git версия, портове).

## 5. Финал
Board-ът се пише с `/ralph-plan`. Диагностиката след run — `/ralph-diagnose`.
