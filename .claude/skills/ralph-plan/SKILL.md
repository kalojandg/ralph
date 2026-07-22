---
name: ralph-plan
description: Авторство на tasks.json board за Ralph swarm — разузнаване, декомпозиция по lanes/files/dependsOn, per-task verify, валидация. Ползвай при създаване или разширяване на board за ralph run.
---

# Ralph Plan — авторство на task board

RALPH_ROOT = директорията на ralph репото (на тази машина: `D:\Downloads\monk\ralph`; на непозната — намери директорията, съдържаща `ralph-swarm.ps1`, или питай). Пълните референции живеят в `RALPH_ROOT/ralph reference/` — при съмнение чети `parallel-swarm-reference.md` Част 2 и `tasks-and-progress-reference.md`.

## Процедура

### 1. Разузнаване (ЗАДЪЛЖИТЕЛНО преди писане)
- Прочети `RALPH_ROOT/ralph reference/project reference/repos.json` → кое репо, mainBranch, verify команди, structure reference.
- Прочети structure reference документа на целевото репо (ако липсва → първо `/ralph-setup`).
- Прочети реалния код, който тасковете ще пипат: точни имена на функции/файлове/DOM id-та правят стъпките изпълними. При голям проект (много сървиси/зони) — fan-out: по един Explore агент на зона, събери картите, чак тогава декомпозирай.
- Идентифицирай ОТРОВНИЯ СПИСЪК на репото: споделени файлове (DI/bootstrap, router, locales, package.json, shared types, contracts, солюшън файлове). Те определят соло lane-овете.

### 2. Правила за декомпозиция
1. **Разбивай по фичи, не по слоеве.** Един таск = един commit = един merge. Къси таскове — дълголетен branch = конфликт.
2. **Нула файлово застъпване между lanes.** Два таска на един файл → същата lane (ред = редът в масива) или dependsOn. Lane-овете вървят паралелно; вътре в lane — последователно.
3. **`repo` полето е ЗАДЪЛЖИТЕЛНО** на всеки таск (multi-repo fleet — няма безопасен дефолт; липсва → шумен skip).
4. **`files` = glob-ове = зони на собственост**, не списък файлове. Гранулярност по избор: цял сървис = 1 ред (`Services/OrderService/**`). Отровен файл в files → соло lane + dependsOn.
5. **`dependsOn` гейтва на MERGED** (worktree на зависимия се клонира от integration при старта му). Cross-repo dependsOn работи. Цикъл = deadlock.
6. **Поведенческа промяна = спековете се оправят В СЪЩИЯ таск/commit** — иначе гейтът на merge-а е червен по конструкция. Патърн за консолидации: първо АДИТИВЕН таск (новото + негов spec, старото непипнато), после премахващи таскове един по един (всеки чисти своите спекове).
7. **TDD**: RED+GREEN в ЕДИН таск (`tddWorkflow: true`). Характеризационни тестове = документират каквото Е, върху замразен код.
8. **Id-та не се преизползват** (логовете/retry файловете са per id) — номерирай с луфтове по lane (10-те, 20-те…).
9. `description` = git commit message дословно (conventional style). `specRef` сочи секции от structure reference. `notes` носи червените линии и контекста, който агентът иначе няма как да знае.

### 3. Verify стратегия (гейтът)
- **Per-task `verify` масив** за междинните таскове: прицелен subset `["npm test -- <spec-filter> critical-path"]` (playwright филтрира по подниз). БЕЗ `npm ci`, ако таскът не пипа package.json.
- **Финалният таск на всяка lane — БЕЗ verify override** → пълният repo гейт е задната мрежа.
- Във филтъра само спекове, които СЪЩЕСТВУВАТ след таска (изтрит спек във филтъра = playwright error = фалшиво червено).
- Провери, че пълният suite се събира в `swarm.verify_timeout_min` (мери с baseline; виж /ralph-setup).

### 4. Механика на board-а
- `tasks.json` = чист JSON масив, редът в масива = ред на изпълнение в lane.
- ⚠ PowerShell капан при програмно append: пиши с `ConvertTo-Json -InputObject $array -Depth 16` (pipeline-ът `$arr | ConvertTo-Json` увива в `{value, Count}` и чупи board-а).
- Валидация преди пускане: уникални id-та; всички dependsOn таргети съществуват; всеки таск има repo; files на различни lanes не се пресичат; описанията са commit-готови.

### 5. Преди старт
Чеклистът е в `/ralph-setup` (зелен baseline на ексклузивен порт, чист integration branch и т.н.). Не пускай board върху непроверена база — фосилите се плащат с retry бюджети.

## Изпълнение
`START-RALPH-SWARM.bat [agents] [maxTasks]` от RALPH_ROOT. Броят агенти има смисъл само при паралелни lanes; серийна фича = 1.
