# ADR 0009: Compact Markdown Format for LLM Instructions

**Status**: Accepted
**Date**: 15 Feb 2026
**Deciders**: Roberto
**Plan**: 149

## Context

LLM instruction files (CLAUDE.md, rules/, agents/, skills/) are consumed by multiple AI coding tools: Claude Code, Copilot CLI, Codex, Gemini. Token usage directly impacts cost, latency, and context window availability. Research findings:

- **LLMLingua** (Microsoft): 20x compression with minimal performance loss
- **CompactPrompt**: 60% token reduction via self-information scoring
- **Symbol compression anti-pattern**: Symbols themselves consume tokens; replacing words with symbols INCREASES usage
- **Claude Code best practices (2026)**: ~150-200 instructions max for frontier LLMs; use `@imports` for lazy-loading
- **Copilot CLI (2026)**: AGENTS.md recognized; skills use progressive disclosure; `.github/instructions/*.instructions.md`

The key insight: **information density per line matters more than line count.** Every line must carry actionable information that prevents agent mistakes.

## Decision

### The 12 Rules of Compact Markdown

All instruction files consumed by LLMs MUST follow these rules:

| #   | Rule                                                               | Rationale                                                                    |
| --- | ------------------------------------------------------------------ | ---------------------------------------------------------------------------- |
| 1   | **Keyword-dense bullets only** — no prose sentences                | Prose wastes tokens without adding information                               |
| 2   | **Tables for mappings** — `\| Key \| Value \|` for correspondences | Tables are 40-60% more token-efficient than bullet lists for structured data |
| 3   | **Max 3 heading levels** — `##`, `###`, `####` only                | `#` reserved for title; deeper nesting signals over-structuring              |
| 4   | **Code blocks only for commands** — not for emphasis               | Backtick fences add 2 tokens minimum; inline `code` for names                |
| 5   | **References as `@path/to/file`** — not inline content             | Claude Code `@imports` enable lazy-loading; content loaded on demand         |
| 6   | **Frontmatter YAML** — version, name, description                  | Machine-parseable metadata for tooling and version tracking                  |
| 7   | **Max 250 lines/file** — split if exceeds                          | Agents lose context in long files; merge conflicts multiply                  |
| 8   | **Max 150 instructions total** — across CLAUDE.md + rules/         | Frontier LLMs degrade beyond ~200 instructions; budget for headroom          |
| 9   | **Progressive disclosure** — CLAUDE.md = index + @imports          | Load full content only when relevant to current task                         |
| 10  | **No redundancy** — if linter/hook enforces, don't instruct        | Duplicate enforcement wastes tokens and creates drift                        |
| 11  | **Model-agnostic** — no model-specific syntax or symbols           | Files must work across Claude, Copilot, Codex, Gemini                        |
| 12  | **Versioning** — frontmatter or `<!-- v2.0.0 -->` comment          | Track changes, enable staleness detection                                    |

### Before/After Example

**Before (verbose, 7 lines, ~85 tokens):**

```markdown
## Thor Gate (NON-NEGOTIABLE)

_Why: agents self-report "all tests pass" when they don't. Thor reads files directly, trusts nothing._

1. Execute all tasks in wave
2. `thor-quality-assurance-guardian` validates F-xx + code quality
3. Fix ALL Thor rejections (max 3 rounds)
4. Thor PASS -> commit -> next wave

**Committing before Thor = VIOLATION.** Wave cannot be `done` without `plan-db.sh validate`.
```

**After (compact, 4 lines, ~45 tokens):**

```markdown
## Thor Gate

- Per-task: Gate 1-4, 8, 9 after each task. Per-wave: all 9 gates + build
- Max 3 rejection rounds, then escalate
- `plan-db.sh validate-task {id} {plan}` / `validate-wave {wave_db_id}`
- Commit before Thor = VIOLATION
```

**Compression**: 47% token reduction, zero information loss.

### What NOT to Compress

- **ADRs**: Stay human-readable (standard Context/Decision/Consequences format)
- **README files**: User-facing documentation, not LLM instructions
- **Code comments**: Follow language conventions, not compact format
- **Error messages**: Must be clear to developers, not token-optimized

### Skills Conversion Pattern

Domain-specific workflows should be converted to Skills for progressive loading:

- **Claude Code**: Skills in `.claude/commands/` with YAML frontmatter (name, description, model)
- **Copilot CLI**: Skills in `.github/prompts/` with YAML frontmatter (name, description, applyTo)
- **Loading behavior**: Metadata always in context; full content loaded only on invocation
- **Migration**: Move workflows from CLAUDE.md/rules/ to skills when workflow > 50 lines or rarely used

### Cross-Tool Compatibility Matrix

| Feature             | Claude Code                           | Copilot CLI                              | Universal Approach                         |
| ------------------- | ------------------------------------- | ---------------------------------------- | ------------------------------------------ |
| @imports            | `@path/to/file` in CLAUDE.md          | N/A                                      | Use for Claude; separate files for Copilot |
| Progressive load    | Skills metadata -> full on invoke     | Skills metadata -> full on invoke        | Both support progressive disclosure        |
| Auto-load rules     | `.claude/rules/*.md`                  | `.github/instructions/*.instructions.md` | Different paths, same pattern              |
| Agent config        | `.claude/agents/*.md`                 | `.github/agents/*.md`                    | YAML frontmatter in both                   |
| Global instructions | `CLAUDE.md`                           | `copilot-instructions.md` + `AGENTS.md`  | Keep both in sync                          |
| Frontmatter         | YAML `---` block                      | YAML `---` block with `applyTo`          | YAML is universal                          |
| Hooks               | `hooks.json` (preToolUse/postToolUse) | `hooks.json` (same events)               | Same format                                |
| Memory              | Automatic memories                    | Copilot Memory                           | Both persist context                       |

### Line-Level Decision Test

For each line in an instruction file, ask:

1. **Would removing this cause the agent to make a mistake?** If no, cut it.
2. **Is this enforced by a tool (linter, hook, CI)?** If yes, cut it.
3. **Can this be a table row instead of a bullet?** If yes, use table.
4. **Does this belong in a separate file behind @import?** If rarely needed, split it.

## @import Optimization Strategy

**Update**: February 2026, T0-01 testing (Plan 189)

**Key Finding**: `@import` directives in Claude Code are **NOT lazy-loaded**. T0-01 tested 9 import scenarios; all imports fully loaded into context at session start, regardless of relevance to current task.

**Implications**:

- `@import` is syntactic organization, not progressive disclosure
- Token cost is same whether content is inline or imported
- Strategy: Keep imports compact and consolidated; minimize total imported content
- v2.0.0 format achieves 35% token reduction per-turn via compact markdown rules
- Cross-reference: ADR-0001 digest script optimization (lazy file reads via user request)

**Recommendation**: Use `@import` for logical separation (e.g., rules by domain), NOT for reducing token cost. Total instruction budget still limited to ~150-200 actionable items across all imported files.

## Consequences

### Positive

- 40-60% token reduction across instruction files
- Faster agent response (less context to process)
- Lower cost per session
- Cross-tool compatibility documented and enforced
- Progressive disclosure prevents context overload (Skills only, not @imports)
- v2.0.0 format tested in production (Plans 149, 173, 189) with measurable savings

### Negative

- Learning curve for contributors writing instructions
- Some nuance lost in compression (mitigated by "what NOT to compress" exceptions)
- Requires periodic audit to stay within 150-instruction budget
- @import provides no token savings, only organizational benefits

## Enforcement

- Rule: `wc -l < file` must be <= 250 for any instruction file
- Check: `find .claude/ -name '*.md' -exec sh -c 'test $(wc -l < "$1") -le 250' _ {} \; -print`
- Audit: Monthly review of total instruction count across CLAUDE.md + rules/
- Ref: ADR-0007 (CLAUDE.md restructuring), ADR-0001 (digest scripts)
