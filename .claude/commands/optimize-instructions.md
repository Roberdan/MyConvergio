---
name: optimize-instructions
description: Optimize instruction files for token efficiency using compact markdown format
version: "1.0.0"
---

# Optimize Instructions

You are a **Token Optimizer**, not executor. NO changes without user confirmation.

## Workflow

**0. Scan** → **1. Measure** → **2. Analyze** → **3. Propose** → **4. Convert** → **5. Report** → **6. Test**

## 0. Scan Files

Detect tool, find instruction files:

```bash
# Auto-detect tool
[[ -f "CLAUDE.md" || -d ".claude" ]] && TOOL="claude"
[[ -f ".github/copilot-instructions.md" ]] && TOOL="${TOOL:+$TOOL,}copilot"

# Scan patterns (Claude)
CLAUDE.md .claude/{rules,agents,reference,commands}/**/*.md

# Scan patterns (Copilot)
.github/{copilot-instructions.md,instructions,agents,prompts}/**/*.md
```

## 1. Measure Baseline

Token count via tiktoken (cl100k_base):

```python
import tiktoken, json, sys
enc = tiktoken.get_encoding('cl100k_base')
results = []
for path in sys.argv[1:]:
    content = open(path).read()
    results.append({
        'file': path,
        'tokens': len(enc.encode(content)),
        'lines': content.count('\n') + 1,
        'type': 'auto' if any(x in path for x in ['CLAUDE.md', 'copilot-instructions.md', 'rules/']) else 'demand'
    })
print(json.dumps(results, indent=2))
```

If `--scan-only`, output and EXIT.

## 2. Analyze Issues

Identify:

- Prose-heavy (paragraphs > 2 sentences)
- Inline content (code examples, long lists)
- Repeated patterns
- No tables for mappings
- Missing version (frontmatter/HTML comment)

## 3. Propose Optimizations

Output recommendation table, ask confirmation:

| File                      | Tokens | Issues                              | Priority |
| ------------------------- | ------ | ----------------------------------- | -------- |
| CLAUDE.md                 | 1247   | Prose-heavy (5 sections), no tables | P1       |
| .claude/rules/guardian.md | 823    | Inline examples, no version         | P2       |

**Prompt**: "Proceed with optimization? (y/n)"

## 4. Convert (Per File)

**Steps**:

1. Add version frontmatter if missing
2. Compress prose: paragraphs → bullets, `> **Why**: {reason}` blockquotes
3. Table-ify mappings
4. Extract inline content to separate files (@import for Claude, link for Copilot)
5. Split files > 250 lines (index + detail)

**Rules** (reference: `compact-format-guide.md`):

- Keyword-dense bullets, NO prose
- Tables for mappings
- Remove adjectives/adverbs
- Code blocks only for commands
- Progressive disclosure

## 5. Re-Measure & Report

Token count after optimization:

| File                | Before | After | Reduction | Lines     |
| ------------------- | ------ | ----- | --------- | --------- |
| CLAUDE.md           | 1247   | 687   | -45%      | 197 → 115 |
| Total (auto-loaded) | 3421   | 1834  | -46%      | -         |

**Target**: 40-60% reduction for auto-loaded files.

## 6. Smoke Test

```bash
# Parse check (Claude)
for f in CLAUDE.md .claude/rules/*.md; do cat "$f" > /dev/null || echo "FAIL: $f"; done

# Parse check (Copilot)
[[ -f ".github/copilot-instructions.md" ]] && gh copilot --help > /dev/null
```

## Usage

| Command                                               | Effect                 |
| ----------------------------------------------------- | ---------------------- |
| `/optimize-instructions --scan-only`                  | Baseline only, no edit |
| `/optimize-instructions`                              | Full workflow          |
| `/optimize-instructions CLAUDE.md .claude/rules/*.md` | Target specific files  |

## Manual Process (Copilot CLI)

1. Measure: Python tiktoken (above)
2. Read: `compact-format-guide.md`
3. Apply: prose → bullets, tables
4. Re-measure + test

## Output Required

1. Token counts (JSON)
2. Recommendations (table)
3. Comparison (table)
4. Smoke test (PASS/FAIL)

**Ref**: `~/.claude/reference/operational/compact-format-guide.md`
