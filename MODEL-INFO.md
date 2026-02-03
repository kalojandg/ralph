# Claude Model Configuration

## Current Model: Claude Opus 4

**Model ID:** `claude-opus-4-20250514`

### Configuration

Set in `ralph-config.json`:

```json
{
  "claude_args": [
    "--output-format", "text",
    "--model", "claude-opus-4-20250514"
  ]
}
```

### Why Opus 4?

- ✅ **Latest and most capable** Claude model (as of Feb 2026)
- ✅ **Best for complex coding tasks** (TDD, refactoring, architecture)
- ✅ **Superior reasoning** for visual comparison and design matching
- ✅ **Longer context window** (up to 200K tokens)
- ✅ **Better at following multi-step instructions** (TDD phases)

### Model Capabilities for TDD

| Capability | Opus 4 | Why Important |
|------------|--------|---------------|
| **Code Quality** | Exceptional | Writing clean, testable code |
| **Test Design** | Excellent | Designing comprehensive test suites |
| **Refactoring** | Superior | Iterating until design matches |
| **Visual Analysis** | Strong | Comparing screenshots with mockups |
| **Multi-step Planning** | Excellent | Following RED→GREEN→VISUAL→REFACTOR |
| **Context Retention** | 200K tokens | Understanding full project context |

### Alternative Models (if needed)

If Opus 4 is unavailable or you want to test with different models:

#### Option 1: Claude Sonnet 3.7 (Faster, cheaper)

```json
{
  "claude_args": [
    "--output-format", "text",
    "--model", "claude-3-7-sonnet-20250219"
  ]
}
```

**Pros:** Faster iterations, lower cost  
**Cons:** Slightly less capable for complex refactoring

#### Option 2: Claude Sonnet 4 (Balanced)

```json
{
  "claude_args": [
    "--output-format", "text",
    "--model", "claude-sonnet-4-20250514"
  ]
}
```

**Pros:** Good balance of speed and capability  
**Cons:** Not as thorough as Opus 4 for edge cases

### Checking Your Model

To verify which model Ralph is using:

```powershell
# Check config
Get-Content .claude\ralph-config.json | Select-String "model"

# Test Claude CLI
claude --version
claude --model claude-opus-4-20250514 --help
```

### Model Pricing (Reference)

| Model | Input | Output | Best For |
|-------|-------|--------|----------|
| **Opus 4** | $15/1M | $75/1M | Complex TDD, refactoring, visual testing |
| Sonnet 4 | $3/1M | $15/1M | Balanced speed/quality |
| Sonnet 3.7 | $3/1M | $15/1M | Fast iterations, simple tasks |

### For This Project (Compositions Module)

**Recommendation:** **Opus 4** ✅

**Why:**
- Complex TDD workflow (5 phases per task)
- Visual comparison requires strong reasoning
- 30 tasks with multiple steps each
- Design matching needs precision
- Refactoring iterations need quality

**Expected Usage:**
- ~30-40 iterations (one per task + retries)
- ~50K-100K tokens per iteration
- Total: ~1.5M-3M input tokens
- Cost estimate: ~$22-45 for full module

### Switching Models Mid-Project

If you need to switch models:

1. **Edit ralph-config.json:**
   ```json
   "claude_args": [
     "--output-format", "text",
     "--model", "claude-sonnet-4-20250514"
   ]
   ```

2. **Restart Ralph:**
   ```powershell
   .\ralph.ps1 20
   ```

3. **No other changes needed** - all prompts are model-agnostic

### Performance Expectations

**With Opus 4:**
- ⏱️ ~2-5 minutes per task (including tests, implementation, visual testing)
- 🎯 Higher success rate on first try
- 🔄 Fewer refactoring iterations needed
- ✅ Better design match accuracy

**With Sonnet:**
- ⏱️ ~1-3 minutes per task (faster)
- 🎯 Good success rate, may need more iterations
- 🔄 More refactoring iterations
- ✅ Good design match, may need manual review

---

**Current Setup:** Ralph is configured for **Claude Opus 4** for maximum quality! 🚀

**To change model:** Edit `ralph-config.json` → `"claude_args"` → `"--model"` value
