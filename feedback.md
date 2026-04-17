# Feedback from Previous Iteration

<!-- This file will be auto-updated after each iteration -->

## Last Iteration Summary

**Iteration:** Етап 4 завършен
**Task Worked On:** #95 (last task of Етап 4)
**Status:** ✅ ALL COMPLETE (Tasks #1-#95)

---

## Feedback for Next Iteration

<!-- Ralph will read this before next iteration -->

**Continue with:** Task #96 — [FE] Wall data model — extend GridElement with dimension and WallElement type

**🧱 НАЧАЛО НА ЕТАП 5: Walls Feature (Tasks #96-#111)**

### 📜 Задължително преди да започнеш първия wall таск

Прочети **в този ред**:

1. **`C:/Users/kaloyan.georgiev.AMEXIS/Downloads/walls.ini`** — single source of
   truth за визуалния модел, геометрията, UX поведението. Целият документ.
2. **`C:/Projects/BDZ Project/Admin-App/docs/composition/frontend-requirements.md`**,
   секция **§5 Етап 5: Walls** — формалните FR изисквания, acceptance criteria,
   разбивка на таскове, data model, OSDM JSON формат.
3. **`C:/Projects/ralph/user-steps.md`**, секция **🧱 Етап 5** — архитектурни
   правила, TDD рутина, файлова структура, critical rules.
4. **`C:/Projects/admin-app-frontend-structure.md`** — React/TS/MUI patterns
   за проекта.

### 🎯 Архитектурни правила за Етап 5 (кратко)

**Grid инвариант:** Всички клетки в OsdmGrid са 22×22 px — еднакви. Няма
dedicated wall-tracks. Стените се рендерират **вътре** в нормални клетки
(не в dedicated tracks като в open saloon).

**Rendering:** WallCellVisual компонент с до 4 half-line segments
(up/down/left/right). Corner клетки имат 2 половини, срещащи се в центъра.

**Layering:** Walls zIndex 1 (под седалки/зони на 2). Wrapper divs поемат
events; линиите са `pointer-events: none`.

**Classification:** end (resize), middle (move), internal (corner/junction,
без interaction). Зависи от `code` + `orientation` + `dimension`.

**Collision:** стена спира до пречката, не навлиза. Прилага се при resize
И при move. Backward compat — стари wagon-и без `dimension` зареждат с
default от wallShapes.

### 🧪 TDD ритуал за всеки таск

1. **RED** → пиши тестове, пусни npm test, **verify FAIL**
2. **GREEN** → минимална имплементация, verify PASS
3. **DONE** → npm test && npm run type-check && npm run lint — чисто

**За Етап 5, RED phase е КРИТИЧЕН** — тестовете трябва да фейлват по
правилната причина (модулът/функцията липсва, не заради syntax грешка).

### 📋 Последователност на таскове (не пропускай стъпки!)

**5A — Domain & helpers (#96-#101):** pure functions, unit-testable
- #96 WallElement type
- #97 wallShapes registry
- #98 getWallCells
- #99 classifyCell + getCellDirections
- #100 resizeWallArm + moveWall
- #101 canPlaceWall + clampWallToValid

**5B — Rendering (#102-#104):** UI components
- #102 WallCellVisual component
- #103 OsdmGrid integration (замени старите сиви правоъгълничета)
- #104 Cursor + drag handles

**5C — Interaction (#105-#106):**
- #105 Resize session (mousedown end → drag → commit)
- #106 Move session + Esc cancel

**5D — Integration (#107-#109):**
- #107 Palette drop с default dimension
- #108 OSDM serialize (dimension в internals[])
- #109 OSDM deserialize с fallback

**5E — Verification (#110-#111):**
- #110 Integration round-trip тест
- #111 E2E Playwright workflow

---

## Issues from Last Iteration

[None — Етап 4 завършен успешно]

---

## ⚠️ Важно за Етап 5

- **НЕ мигрирай `code` при resize.** WALL_LEFT_3 свит до 2-place си остава
  WALL_LEFT_3. OSDM позволява произволен dimension за всеки code.
- **НЕ пипай Open Saloon Layout's wall rendering.** Там има dedicated
  grid tracks — тази логика остава за съществуващия view. Етап 5 засяга
  ТОЛКОВА OsdmGrid и WagonCreationPage.
- **НЕ добавяй rotate button за v1.** Ориентацията се избира чрез различни
  палитра елементи при drop.
- **backward compat задължителна** — стари JSON без dimension зареждат с
  default от wallShapes (тест в #109).

---

**Next Action:** Find task #96 (first with `"passes": false`) and begin Stage 5.

Прочети walls.ini, frontend-requirements.md §5, и user-steps.md §Етап 5
ПРЕДИ да започнеш. Следвай TDD: RED → GREEN → DONE. Коmmит с точния
`description` от tasks.json. След това изведи XML status и **СПРИ**.
