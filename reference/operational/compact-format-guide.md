<!-- v2.0.0 | 15 Feb 2026 | Token-optimized per ADR 0009 -->

# Compact Markdown Format Guide

> **Purpose**: Reduce token consumption 40-60% for LLM instruction files.
> Applies to ANY repo using Claude Code, GitHub Copilot, or any LLM-powered tool.

## Format Rules Summary

**Core principles** (full spec in ADR 0007):

- No prose — keyword-dense bullets
- Tables for mappings/comparisons
- @imports for lazy-load (Claude Code)
- Max 150 instructions in auto-loaded files
- Progressive disclosure: index + on-demand detail
- Version every file (frontmatter or HTML comment)

**Anti-patterns**:

- Explanatory paragraphs → compress to bullets with `Why:`
- Inline examples → extract to separate files
- Repeated concepts → reference once, link elsewhere

## Step-by-Step Conversion

### 1. Measure Baseline & Re-Measure

```bash
# Baseline
/optimize-instructions --scan-only

# Manual (requires tiktoken)
python3 -c "import tiktoken; enc=tiktoken.get_encoding('cl100k_base'); print(len(enc.encode(open('.github/copilot-instructions.md').read())))"

# Re-measure after conversion
/optimize-instructions --report
```

Target: 40-60% token reduction for auto-loaded files.

### 2. Auto-Loaded vs On-Demand

| Auto-loaded (optimize FIRST)         | On-demand (lower priority)       |
| ------------------------------------ | -------------------------------- |
| CLAUDE.md                            | reference/\*\*/\*.md             |
| .github/copilot-instructions.md      | docs/\*\*/\*.md                  |
| rules/\*.md                          | agents/\*\*/\*.md (body only)    |
| .claude/agents/\*.md (frontmatter)   | commands/planner-modules/\*.md   |
| .github/instructions/\*.md (Copilot) | .github/agents/\*\*/\*.md (body) |

**Before** (prose-heavy):

```markdown
When you want to check the status of GitHub Actions, you should avoid using the raw `gh run view --log-failed` command because it produces thousands of lines of output that consume tokens unnecessarily. Instead, use the digest script which provides a compact JSON summary.
```

**After** (compact):

```markdown
> **Why**: `gh run view --log-failed` produces 500-5000 lines. Digest scripts produce compact JSON (~10x less tokens).

| Instead of                 | Use                    |
| -------------------------- | ---------------------- |
| `gh run view --log-failed` | `service-digest.sh ci` |
| `gh pr view --comments`    | `service-digest.sh pr` |
```

### 3. Apply Compact Rules

- [ ] Convert "why" prose to `> **Why**: {reason}` blockquotes
- [ ] Table-ify all mappings/comparisons
- [ ] Extract code examples to separate files, reference via @import
- [ ] Remove adjectives/adverbs ("complex", "important", "very")
- [ ] Use `|` for inline options: `git status|log|diff`
- [ ] Bullets for lists, never full sentences

## Conversion Checklist

- [ ] Prose removed, keyword-dense
- [ ] Tables used for mappings
- [ ] Code blocks only for commands
- [ ] References not inline content
- [ ] Frontmatter version present
- [ ] Max 250 lines/file
- [ ] Total instructions < 150 (count NON-NEGOTIABLE + MANDATORY + commands)
- [ ] Before/after token count documented

## Cross-Tool Feature Matrix

| Feature          | Claude Code                         | Copilot CLI                         | Both                                          |
| ---------------- | ----------------------------------- | ----------------------------------- | --------------------------------------------- |
| @imports         | `@path/to/file` in CLAUDE.md        | N/A                                 | Use @imports for Claude, separate for Copilot |
| Progressive load | Skills in commands/                 | Skills in .github/prompts/          | Both support skills                           |
| Auto-load rules  | `.claude/rules/`                    | `.github/instructions/`             | Different paths, same pattern                 |
| Agent profiles   | `.claude/agents/`                   | `.github/agents/`                   | YAML frontmatter in both                      |
| Global config    | CLAUDE.md                           | copilot-instructions.md + AGENTS.md | Keep synced                                   |
| Hooks            | hooks.json (preToolUse/postToolUse) | hooks.json (same events!)           | Same format                                   |
| Memory           | Automatic memories                  | Copilot Memory                      | Both persist context                          |
