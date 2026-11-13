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

## CLI обновяване → проверявай разпознаването на съобщения (добавено 03.10.2026)

Харнесът класифицира изхода на агента по **текстови шаблони**, а Claude Code мени
формулировките между версии. Затова всяко `npm install -g @anthropic-ai/claude-code@latest`
е и риск от тих регрес: съобщението се сменя, шаблонът спира да хваща, и квотната пауза се
превръща в „обикновен провал", който гори fail бюджет.

**Шаблоните, които трябва да се сверят след обновяване** (всички са в `ralph-iteration.ps1`
и `ralph-swarm.ps1`):

| Какво | Шаблон | Какво става при разминаване |
|---|---|---|
| Квота | `hit your(?:\s+[\w'-]+){0,4}\s+limit` | НЕ се разпознава квота → гори fail бюджет вместо да чака reset |
| Час на reset | `resets\s+(\d{1,2})(?::(\d{2}))?\s*(am\|pm)\s*\(([^)]+)\)` | Пада на 60 мин по подразбиране — безопасно, само неточно |
| Преходни | `API Error:\s*(529\|5\d\d\s+Overloaded\|Connection closed\|Overloaded)` | Преходен срив минава за агентски провал |
| Стар CLI | `Claude Code \S+ does not support this model` | (нов) FATAL с точния лек, вместо 3 изгорени таска |

**Как се сверява, без да чакаш да ти свърши квотата:** имената на лимитите живеят в самия
CLI бинар, не в API-то. Извлечи ги:

```bash
# КОЙ бинар: провери вида инсталация, преди да търсиш пътя (13.11.2026)
npm ls -g @anthropic-ai/claude-code --depth=0     # празно => NATIVE инсталация
B="$APPDATA/npm/node_modules/@anthropic-ai/claude-code/bin/claude.exe"   # npm инсталация
B="$HOME/.local/bin/claude.exe"                                          # native инсталация
grep -ao "hit your[^\"]\{0,60\}" "$B" | sort -u          # шаблоните на съобщението
grep -ao "five_hour[^\"]\{0,220\}" "$B" | head -2        # таблицата име-на-лимит
grep -ao "out of usage credits[^\"]\{0,120\}" "$B" | sort -u
```

⚠ **Лекът зависи от вида инсталация.** При native (`~/.local/bin/claude.exe`, npm global празен)
обновяването е **`claude update`**; `npm install -g` там слага ВТОРИ екземпляр до първия и PATH-ът
решава кой върви. FATAL съобщението в `ralph-swarm.ps1` вече разпознава двата случая.

Към 2.1.288 таблицата е: `five_hour`→„session limit", `seven_day`→„weekly limit",
`seven_day_opus`→„Opus limit", `seven_day_sonnet`→„Sonnet limit",
`seven_day_overage_included`→„Fable limit", `overage`→„usage credit limit"
(+ билинг вариантите „monthly spend limit" и „channel's monthly spend limit").

⚠ Точно тук се счупи предния път: старият шаблон позволяваше най-много ЕДНА дума пред
„limit", а „usage credit limit" са две.

### 2.1.323 (сверено 13.11.2026) — и защо сверяването не е формалност

Обновяване 2.1.123 → 2.1.323 завари **нов клас квотни съобщения БЕЗ „hit your … limit"**:
```
You're out of usage credits. /model to switch models.
Your org is out of usage credits. Contact your admin to add more.
out of usage credits · resets <час>
```
Старият шаблон не ги хващаше — тоест опреш ли до кредити посред нощ, пауза нямаше да има и
бюджетът щеше да изгори. **Закърпено в двата файла** (`ralph-iteration.ps1` QUOTA DETECTION и
`ralph-swarm.ps1` ревюерът) с нарочно разграничение:
- „out of usage credits" **+ „resets"** → квота, чака се (прозорецът се подновява);
- без reset → билинг състояние (org без средства), което чакане НЕ лекува → пада по нормалния
  път, за да гръмне бързият FATAL вместо безкраен requeue на всеки час.

Другите промени в 2.1.323: таблицата се размести (`seven_day_overage_included` вече го няма;
появиха се `extra_usage`, `tengu_usage_overage_included_models`, `seven_day_oauth_apps`,
`blocked_seven_day`), и има ново „hit your **fast** limit" (fast mode) — него старият шаблон
си го хваща. Форматът `resets 4pm` оцелява, но вече има и дата-базирани форми
(„resets next month", „resets Dec 5"), които падат на 60-минутния дефолт.

**Проверявай с таблица на истинност, не на око.** Скрипт, който пуска новото условие срещу
реалните низове (включително отрицателните случаи: „API Error: 529", обикновен провал), струва
две минути и показва веднага дали си разширил шаблона твърде много.
