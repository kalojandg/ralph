---
name: ralph-config
description: Настройките на Ralph swarm (ralph-config.json) — какво прави всяка, коя е дефолтната, кога се променя; плюс готови рецепти (квотна криза, демо, бавна машина, строго ревю). Ползвай при въпрос „как се конфигурира X", при смяна на модели/бюджети и ЗАДЪЛЖИТЕЛНО при добавяне на нова настройка в харнеса.
---

# Ralph Config — настройките на харнеса

RALPH_ROOT = директорията с `ralph-swarm.ps1` (на тази машина: `D:\Downloads\monk\ralph`).
Файлът е `RALPH_ROOT/ralph-config.json`. Този скил описва **настройките**; механиката зад тях
живее в `RALPH_ROOT/ralph reference/parallel-swarm-reference.md`, а per-repo настройките
(пътища, verify команди, mainBranch) са в `repos.json` → виж `/ralph-setup`.

## ⚠ ПРАВИЛО ЗА ПОДДРЪЖКА (причината този скил да съществува)

**Всяка нова кастъмизация на харнеса се документира ТУК, в същата промяна, която я въвежда.**
Ново поле в `ralph-config.json`, преименувано, изтрито или сменена дефолтна стойност →
редактираш таблиците по-долу веднага, не „после". Същото важи и за настройка, която
спира да се чете от кода (маркирай я като декоративна, не я триеш мълчаливо).

Двете копия на скиловете се обновяват ЗАЕДНО:
- канонично: `RALPH_ROOT/.claude/skills/` (пътува с git репото),
- активно: `~/.claude/skills/` (извикваемо отвсякъде) — `cp -r` след промяна.

Причината: чатът е смъртен, паметта на асистента е локална за машината. На нова (служебна)
машина оцеляват САМО репото и скиловете — ако настройка не е тук, тя не съществува.

## Как се четат настройките (капани)

- **Конфигът се чете ПРИ СТАРТ** на оркестратора/итерацията. Промяна по време на run не
  важи — спираш и пускаш наново.
- **Соло срещу swarm:** `ralph.ps1` (соло) не чете `swarm` блока изобщо; `ralph-swarm.ps1`
  не чете prompt-сглобяващите блокове (те са в `ralph-iteration.ps1`).
- **`claude_args --model` срещу `models` tier-овете:** в swarm режим tier-ът печели
  (оркестраторът подава `-modelOverride`); `claude_args` остава за соло режима и като
  fallback, ако `models` блокът липсва.
- **Декоративни блокове (НЕ се четат от кода, към 19.09.2026):** `logging` (логовете се
  пишат безусловно) и `tdd` (информативен). Оставени са нарочно като документация.
- **`enabled` флагът се уважава само на част от блоковете:** `prerequisite_steps.enabled` и
  `feedback.enabled` се проверяват; `user_defined_steps` и `task_steps` се четат САМО по
  `steps_file` — `enabled:false` там НЕ изключва нищо (изключваш ги с празен файл или
  като махнеш пътя).

## Top-level настройки

| Ключ | Дефолт | Какво прави |
|---|---|---|
| `prompt_file` | `PROMPT.md` | Базовият prompt, с който тръгва всеки агент. |
| `use_api_key` | `false` | `false` = агентът МАХА `ANTHROPIC_API_KEY` от env-а си → CLI пада на абонамента (OAuth). `true` = API кредити. Сет-нат глобален ключ иначе тихо отвлича билинга и игнорира Max плана. |
| `claude_args` | `--output-format text --model claude-opus-5 --dangerously-skip-permissions` | Аргументите на CLI. Моделът тук важи за соло режима и е fallback за swarm. |
| `models` | виж долу | Tier → модел мапинг (swarm). |
| `prerequisite_steps` | `{enabled:true, steps_file:"prerequisite-steps.md"}` | Стъпки, добавяни след PROMPT.md. `enabled` се уважава. |
| `user_defined_steps` | `{steps_file:"user-steps.md"}` | Червените линии на проекта. ⚠ `enabled` НЕ се чете. |
| `task_steps` | `{steps_file:"task-steps.json"}` | Per-task/per-step hooks. ⚠ `enabled` НЕ се чете. |
| `feedback` | `{enabled:true, feedback_file:"feedback.md"}` | Инжектира се ПОСЛЕДНО в prompt-а („final word"). Празен файл = нищо. |
| `logging`, `tdd` | — | Декоративни (виж капаните). |

## `models` — моделни нива (tier-ове)

| Tier | Кой го ползва | Текуща стойност |
|---|---|---|
| `easy` | таскове с `"model": "easy"` | `claude-sonnet-5` |
| `heavy` | таскове с `"model": "heavy"` и таскове БЕЗ `model` поле | `claude-opus-5` |
| `review` | finishing review + fix агентите | `claude-opus-5` |
| `docs` | finishing docs агентът (липсва → пада към `easy`) | `claude-sonnet-5` |

Таскът в `tasks.json` сочи **tier име**, не модел — затова при квотна криза се сменят
стойностите тук, а board-ът не се пипа. Кой таск какъв tier получава: `/ralph-plan` §2в.
Харнесът сам вдига tier-а при ескалация (`easy → heavy → review`) на прага `escalate_after`.

**История:** 19.08 tier-овете влизат (review/docs бяха `claude-fable-5` — той гори ОТДЕЛНИЯ
Fable седмичен джоб на Max плана); 19.09 Fable джобът свършва → review и docs минават на
opus/sonnet. При нулиране на джоба връщането е смяна на две стойности.

## `swarm` блок

### Паралелизъм и прозорци
| Ключ | Дефолт | Какво прави |
|---|---|---|
| `agents` | `3` | Паралелни слота (2-3 старт, 5-6 практичен таван). Аргументът на `START-RALPH-SWARM.bat` го надделява; подай `0`/нищо, за да важи конфигът. |
| `worktree_root` | `""` → `<parent>\.ralph-worktrees` | Къде живеят агентските worktree-та. |
| `keep_windows` | `false` | Агентските конзоли да остават отворени след края (за оглед/демо). |
| `window_style` | `"Normal"` | `Normal`/`Minimized`/`Hidden` за агентските прозорци. |
| `window_positions` | `"auto"` | `"auto"` = грид по броя агенти + оркестратора, мониторите се пълнят от основния (до 4 прозореца/монитор). Или масив `"x,y,w,h"` per слот (индекс 0 = SLOT 1; `""` = не местѝ). Само при `window_style: Normal`. |

### Retry бюджети
| Ключ | Дефолт | Какво прави |
|---|---|---|
| `max_timeout_requeues` | `4` | Колко пъти watchdog-убит таск (timeout/stale) се пуска наново. Същият бюджет поема и преходните API смърти (529 / connection drop). |
| `max_fail_retries` | `4` | Колко пъти реално провалил се таск се retry-ва с инжектиран failure контекст (`retry/task-<id>.md`). Verify revert-ите споделят този бюджет. |
| `escalate_after` | `2` | След толкова изгорени fail retry-та: `files` границата се вдига (scope ескалация) И моделът скача едно стъпало (`easy→heavy→review`). |

### Verify гейт (след всеки merge)
| Ключ | Дефолт | Какво прави |
|---|---|---|
| `verify_enabled` | `true` | Пуска `verify` командите на репото (от `repos.json`) върху integration клона след merge; червено → merge-ът се връща + информиран retry. |
| `verify_timeout_min` | `45` | Таван per команда. Мери се спрямо baseline на пълния suite — твърде нисък = фалшиво червено на перфектен таск. |

### Finishing (само при ALL TASKS COMPLETE)
| Ключ | Дефолт | Какво прави |
|---|---|---|
| `finish_review` | `true` | Review агент per репо върху diff-а на целия run (`startSha..HEAD`), после fix цикли. |
| `finish_review_cycles` | `2` | Колко fix цикъла се допускат, преди финалната присъда. |
| `review_acceptance` | `"blockers"` | `blockers` = на финалния цикъл блокерите спират, important-ите са advisory (влизат в доклада като вход за следващ board). `strict` = старото 0 blockers + 0 important. |
| `review_dir` | `C:\CodeReview` | Къде отиват `CODE-REVIEW-*.md` + `verdict.json`. |
| `finish_docs` | `true` | Docs агент per докоснато репо: обновява structure reference/README по board-а. |
| `finish_push` | `true` | Auto-commit на ralph репото + push на докоснатите репота. |
| `finish_index` | `true` | GitNexus re-index като последно действие (detached, не блокира). ⚠ Преди първото индексиране артефактите да са в `.gitignore`/`.git/info/exclude`. |

## Готови рецепти

- **Квотна криза (изгаря твърде бързо):** `models.heavy` → `claude-sonnet-5` и/или `agents` → 2-3;
  board-ът не се пипа. Ескалацията пак ще вдигне закъсалите таскове.
- **Демо пред публика:** `agents` 5-7 + `window_positions: "auto"` + `keep_windows: true`
  (конзолите остават за разглеждане). Стартирай на свеж 5-часов quota прозорец — 5 Opus
  агента изяждат прозореца за ~1-1.5 ч активна работа.
- **Бавна машина / тежък suite:** `verify_timeout_min` нагоре (мери baseline!), `agents` надолу
  (паралелни Testcontainers контейнери се бият за RAM — при масов integration провал в
  несвързани зони подозирай средата, не таска).
- **Строг release:** `review_acceptance: "strict"` за board, след който се пуска в прод.
- **Тиха нощна работа:** `window_style: "Minimized"`, `keep_windows: false`.
- **Соло режим (без swarm):** `.\ralph.ps1 <iterations>` — чете само top-level блоковете;
  моделът идва от `claude_args`.
