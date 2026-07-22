---
name: ralph-diagnose
description: Форензика на Ralph swarm run — чете summary/логове/retry контексти, класифицира провала (среда/квота/фосил/агентска грешка/конфликт) и предлага точното действие. Ползвай след неуспешен или странен run, или при „какво стана през нощта".
---

# Ralph Diagnose — форензика на run

RALPH_ROOT = директорията на ralph репото (тук: `D:\Downloads\monk\ralph`; иначе — намери `ralph-swarm.ps1`). Exit таблиците и пълните описания: `RALPH_ROOT/ralph reference/feedback-and-completion-reference.md` и `parallel-swarm-reference.md`.

## Източници на истина (чети в този ред)
1. **SWARM SUMMARY** (конзолата/последния изход): merged / conflicts / skipped / failed / re-queue броячи.
2. **`RALPH_ROOT/retry/task-<id>.md`** — историята на опитите. Първо `## Attempt` + `Reason:` редовете (grep), после детайлите на ПОСЛЕДНИЯ опит. Побира verify изхода и опашката на агентския лог.
3. **`RALPH_ROOT/logs/iteration-<taskId>-*.txt`** — пълният изход на всеки опит (най-новият файл = последният опит). Първите редове хващат環 environment грешки.
4. **`RALPH_ROOT/results/task-<id>.json`** — какво е докладвал агентът.
5. **git**: `git branch --list "ralph/*"`, `git worktree list`, чистота/branch на главния checkout (`git rev-parse --abbrev-ref HEAD` — НЕ `--show-current`, git-ът тук е 2.21!).
6. Жив агент: суровият stream е `%TEMP%\ralph-output-<taskId>.txt` — расте на живо; размер+timestamp казват жив ли е.

## Класификация (дървото)

**Мигновени смърти (<60s, „no result file"):** проблем на СРЕДАТА, не на таска. Виж първите редове на лога:
- `API Error 400 thinking.type` → CLI-ят е стар за модела → `claude update`;
- `Credit balance is too low` → API кредити изчерпани → billing проблем: провери дали ANTHROPIC_API_KEY не е отвлякъл билинга (config `use_api_key: false` кара агентите да го махат → абонамент);
- fastFails guard (3 поредни) сам abort-ва с диагностика.

**Quota:** агентът чака сам в прозореца си (табло = тиха „running" редица) → exit 2 → re-queue без хабене на бюджет. Wording-ът на CLI съобщението ДРЕЙФИ между версии — при нов CLI провери regex-ите в ralph-iteration.ps1 (`hit your(?:\s+\w+)?\s+limit`, resets с опционални :MM).

**Timeout/stale (exit 3):** watchdog kill (180 мин hard / 60 мин без растеж). Стохастично (заклещен процес) → re-queue с бюджет. Ако е гейтът, а не агентът: suite-ът не се събира в `verify_timeout_min` → прицелни verify subset-и + вдигни тавана.

**VERIFY GATE RED:** прочети КОЙ тест и отсъди:
- Тестът в scope-а на таска? → агентска грешка, informed retry я поема;
- Чужд тест? Провери **на чист main в изолация** (`npx playwright test <spec> --grep "<име>"` от репото — ексклузивен порт!): пада и там → ФОСИЛ (заварена руина, напр. отпреди фича; поправя се на main от човек/ескалиран агент), минава → интеграционна регресия на таска;
- ⚠ Baseline само на ексклузивен порт: `reuseExistingServer` + чужд сървър = мериш ГРЕШНОТО приложение (портове: 45279 = inventory/hero/spells, 45278 = combat).

**MERGE SKIPPED:** главният checkout е мръсен или на друг branch → комитни/върни branch-а, нов run. Чест виновник: ръчни редакции по main по време на run.

**MERGE CONFLICT:** новата машина re-queue-ва в conflict режим (агентът merge-ва main в worktree-то си). Изчерпан бюджет → branch-ът чака ръчен resolve.

**Fatal env (exit 4):** целият run спира моментално, тасковете НЕ са failed — оправи средата, пусни пак.

## Retry стълбицата (какво е правил всеки опит)
`continue` (наследено worktree, в scope) → `escalate` (след `escalate_after`=2: scope-ът вдигнат за гейт-доказани провали, out-of-scope файловете са изброени в result summary — ПРЕГЛЕДАЙ ГИ) → `conflict` (merge мандат). Бюджет: `max_fail_retries`=4. Continuation значи: worktree/branch се пазят — работата НЕ е губена, дори при failed.

## Машинни факти (тази машина)
git 2.21 (без `--show-current`); PS 5.1 (ANSI parsing на no-BOM .ps1 — ASCII only в скриптовете; pipeline→ConvertTo-Json капанът); npm ci изисква байт-точен lockfile; playwright version bump иска `npx playwright install`; фосилният патърн на monk: xp+long-rest тестове отпреди multiclass модала.

## Изход на диагнозата
Винаги завършвай с: (а) класификация per провален таск; (б) конкретното действие (командата/фикса); (в) какво ще направи следващият run сам и какво изисква човек.
