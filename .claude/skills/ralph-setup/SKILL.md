---
name: ralph-setup
description: Bootstrap на нов проект/репо за Ralph swarm — repos.json запис, structure reference, отровен списък, verify команди и предстартовия чеклист (зелен baseline!). Ползвай при закачане на ralph към ново репо или нова машина.
---

# Ralph Setup — закачане на нов проект

RALPH_ROOT = директорията на ralph репото (тук: `D:\Downloads\monk\ralph`; иначе — намери `ralph-swarm.ps1`). Шаблоните за подражание: съществуващите записи в `project reference/repos.json` и `*-structure.md` файловете там.

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
3. `.gitignore` покрива runtime артефактите (node_modules, playwright-report, test-results, coverage) — verify команди, оставящи untracked файлове, правят следващите merges "dirty-skipped".
4. Env файлове: untracked `.env*` се копират в worktrees от оркестратора — провери, че са в location root-а.
5. Среда: `claude --version` (моделите в config-а се поддържат?), git версия (worktree-ите искат ≥2.5; `--show-current` иска ≥2.22 — оркестраторът ползва rev-parse), диск за worktrees (~размер на репото × агенти).
6. `ralph-config.json`: модел (`use_api_key:false` = абонамент), `swarm` бюджети (retries 4/4, escalate_after 2), `verify_timeout_min` спрямо baseline мярката.

## 4. Пренос на нова машина
1. Клонирай ralph репото (скиловете и референциите пътуват с него — `.claude/skills/` важат автоматично при работа В репото);
2. За извикване отвсякъде: копирай скиловете на потребителско ниво: `cp -r <RALPH_ROOT>/.claude/skills/* ~/.claude/skills/`;
3. Пренапиши `repos.json` пътищата за новата машина (location/gitRoot са абсолютни!);
4. Мини чеклиста от т.3 (нова машина = нова среда = нови изненади: CLI версия, git версия, портове).

## 5. Финал
Board-ът се пише с `/ralph-plan`. Диагностиката след run — `/ralph-diagnose`.
