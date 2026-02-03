# User Defined Steps - TDD Visual Feedback

Това са допълнителни специфични инструкции за TDD workflow с visual testing.

---

## 🎯 Visual Feedback Loop (КРИТИЧНО!)

### Playwright MCP Setup

**Server:** `cursor-ide-browser` (вече инсталиран)

### Visual Testing Workflow

След имплементация на UI компонент (VISUAL phase):

#### 1. Start Dev Server

```bash
npm run dev
# Server ще стартира на http://localhost:5173
```

#### 2. Navigate to Component/Page

```javascript
CallMcpTool({
  server: "cursor-ide-browser",
  toolName: "browser_navigate",
  arguments: {
    url: "http://localhost:5173/compositions"  // Adjust based on task
  }
})
```

#### 3. Take Screenshot

```javascript
CallMcpTool({
  server: "cursor-ide-browser",
  toolName: "browser_screenshot",
  arguments: {
    fullPage: true
  }
})
// Screenshot автоматично се запазва
```

#### 4. Compare with Design Mockup

**Референтен дизайн:** `@docs/composition/designs/{task_id}.png`

**Comparison Checklist:**

```markdown
### Layout Structure
- [ ] Header position и alignment правилни
- [ ] Sidebar width (25% за editor) правилна
- [ ] Main content width (75% за editor) правилна
- [ ] Grid/Flex layout съвпада с mockup

### Colors (виж design-mapping.json)
- [ ] Status badges: gray (#757575) за Draft, green (#4caf50) за Active
- [ ] Wagon backgrounds: blue (#e3f2fd) за Compartment, purple (#f3e5f5) за Sleeper, yellow (#fff9c4) за Bistro
- [ ] Wagon borders: green (#4caf50) за active, gray (#bdbdbd) за inactive
- [ ] Locomotive: red (#c62828)
- [ ] Primary button: blue (#1976d2)

### Typography (виж design-mapping.json)
- [ ] Page title: Typography variant="h4"
- [ ] Wagon placard: Typography variant="h6" (#1, #2, #3)
- [ ] Wagon type: Typography variant="body1" (Купе, Спален)
- [ ] Capacity: Typography variant="caption" color="textSecondary" (54 места)

### Spacing (виж design-mapping.json)
- [ ] Filter gap: 16px
- [ ] Wagon gap: 16px
- [ ] Card padding: 16px
- [ ] Drawer width: 400px (properties panel)
- [ ] Sidebar width: 25% (wagon palette)
```

#### 5. If Design Doesn't Match → REFACTOR

**Common fixes:**

| Issue | Fix |
|-------|-----|
| Wrong status badge color | `<Chip color="success" />` за Active, `color="default"` за Draft |
| Wrong spacing | Use MUI `spacing()`: `gap: theme.spacing(2)` за 16px |
| Wrong typography | Check Typography `variant`: `<Typography variant="h6">` |
| Wrong wagon border | Use `sx`: `sx={{ borderLeft: '4px solid #4caf50' }}` |
| Wrong layout | Check Grid `xs` values: `<Grid xs={3}>` sidebar, `<Grid xs={9}>` canvas |

#### 6. Re-Screenshot and Compare

```javascript
// After fixes, take new screenshot
CallMcpTool({
  server: "cursor-ide-browser",
  toolName: "browser_screenshot",
  arguments: { fullPage: true }
})

// Compare again with mockup
// Iterate until matches ✅
```

---

## 🧪 Testing Loop (КРИТИЧНО!)

### Test Execution Order

```bash
# 1. Unit/Component tests
npm test

# 2. E2E Playwright tests
npx playwright test

# 3. Linter
npm run lint

# 4. TypeScript check
npm run type-check
```

### If ANY Test Fails

**DO NOT proceed!**

1. **Read error message carefully**
2. **Fix the issue**
3. **Re-run the failed test**
4. **Repeat until ALL tests pass**

### Test-Specific Actions

#### Unit Test Fails
- Fix component logic
- Fix props handling
- Fix state management
- Re-run: `npm test`

#### E2E Test Fails
- Fix user interaction flow
- Fix localStorage mock data
- Fix navigation/routing
- Re-run: `npx playwright test`

#### Linter Fails
- Fix code style issues
- Remove unused imports
- Fix formatting
- Re-run: `npm run lint`

#### TypeScript Fails
- Fix type errors
- Add missing types
- Fix interface mismatches
- Re-run: `npm run type-check`

---

## 📋 Step-by-Step Execution (КРИТИЧНО!)

### ONE Step at a Time

**Example from Task #11 (Dashboard List Page):**

```markdown
Step 11.1 (RED): Write failing E2E test
  ↓
Run: npx playwright test
  ↓
Verify: TEST FAILS ✅
  ↓
Step 11.2 (RED): Continue...

Step 11.3 (GREEN): Create CompositionsListPage.tsx
  ↓
Step 11.4 (GREEN): Import hooks
  ↓
Step 11.5 (GREEN): Create layout
  ↓
...
  ↓
Step 11.10 (GREEN): Run test
  ↓
Verify: TEST PASSES ✅
  ↓
Step 11.11 (VISUAL): Start dev server
  ↓
Step 11.12 (VISUAL): Navigate with Playwright MCP
  ↓
Step 11.13 (VISUAL): Screenshot
  ↓
Step 11.14 (VISUAL): Compare with design 9.png
  ↓
IF NOT MATCH:
  ↓
Step 11.15 (REFACTOR): Adjust styles
  ↓
Step 11.16 (REFACTOR): Re-screenshot
  ↓
LOOP until MATCH ✅
  ↓
Step 11.17 (DONE): Final verification
```

### Verification After Each Phase

**After RED:**
- ✅ Test written?
- ✅ Test FAILS? (expected)

**After GREEN:**
- ✅ Code implemented?
- ✅ Test PASSES?

**After VISUAL:**
- ✅ Screenshot taken?
- ✅ Design matches mockup?

**After REFACTOR:**
- ✅ All adjustments made?
- ✅ Design now matches?

**After DONE:**
- ✅ ALL tests pass?
- ✅ ALL verifications pass?
- ✅ Ready to commit?

---

## 🚨 Critical Checkpoints

### Before Marking Task Complete

**ASK YOURSELF:**

1. Did I write the test FIRST (for TDD tasks)?
2. Did ALL tests pass?
3. Did I take a screenshot (for designReference tasks)?
4. Does the screenshot MATCH the mockup?
5. Did I check layout, colors, typography, spacing?
6. Did npm run lint pass?
7. Did npm run type-check pass?
8. Did I update tasks.json ("passes": true)?
9. Did I log in activity.md?
10. Did I git commit?

**IF ANY ANSWER IS NO → DO NOT MARK COMPLETE!**

---

## 📊 Progress Tracking

### Check Remaining Tasks

```powershell
# Count tasks with passes: false
(Get-Content "docs/composition/tasks.json" | ConvertFrom-Json | Where-Object { $_.passes -eq $false }).Count
```

### Check Completed Tasks

```powershell
# Count tasks with passes: true
(Get-Content "docs/composition/tasks.json" | ConvertFrom-Json | Where-Object { $_.passes -eq $true }).Count
```

---

## 💡 Debugging Tips

### If Screenshot Doesn't Match Mockup

1. **Open design-mapping.json** → check color palette, typography, spacing
2. **Compare side-by-side** → screenshot vs mockup
3. **Identify specific differences** → layout? colors? spacing?
4. **Make targeted fixes** → adjust specific properties
5. **Re-screenshot** → verify fix worked
6. **Iterate** → repeat until matches

### If Tests Keep Failing

1. **Read error message** → what exactly failed?
2. **Check test expectations** → are they correct?
3. **Check implementation** → does it match test?
4. **Check imports** → everything imported correctly?
5. **Check data** → localStorage mock data correct?
6. **Run test in isolation** → `npm test -- ComponentName.test.tsx`

### If Linter Fails

1. **Read linter errors** → specific line/column
2. **Fix formatting** → run auto-fix if available
3. **Remove unused code** → imports, variables
4. **Check ESLint rules** → understand what's required

---

## 🎯 Success Criteria Reminder

**Task is complete ONLY when:**

1. ✅ Tests written (for TDD tasks)
2. ✅ Tests pass (npm test && npx playwright test)
3. ✅ Screenshot taken (for designReference tasks)
4. ✅ Design matches mockup (visual comparison ✅)
5. ✅ Linter passes (npm run lint)
6. ✅ TypeScript compiles (npm run type-check)
7. ✅ tasks.json updated ("passes": true)
8. ✅ activity.md logged
9. ✅ Git committed
10. ✅ Status output (XML tags)

**NO SHORTCUTS! Follow TDD workflow completely!**

---

## 📝 Output Format

**At end of iteration:**

```xml
<task-complete>
  <task-id>11</task-id>
  <tests>PASSED</tests>
  <visual>MATCHED</visual>
  <committed>YES</committed>
</task-complete>

<status>CONTINUE</status>
<next-task>12</next-task>
```

**Or if all complete:**

```xml
<promise>COMPLETE</promise>
<total-tasks>30</total-tasks>
<all-passed>true</all-passed>
```

---

**These user-defined steps ensure quality through TDD and visual verification!** ✅
