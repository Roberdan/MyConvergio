---
name: optimize-project
description: Optimize project instructions and agent setup for lower token usage and higher signal
allowed-tools:
  - Read
  - Glob
  - Grep
  - Bash
  - Edit
context: fork
user-invocable: true
version: "1.0.0"
---

# Optimize Project Skill

> User-invocable workflow to audit, fix, and bootstrap token-efficient project instructions.

## Modes

- `--audit`: analysis only, no file changes
- `--fix`: apply safe auto-fixes after audit
- `--setup`: bootstrap optimize-project baseline for new repositories

## When to Use

- Existing repository has verbose instruction/docs churn
- CLAUDE.md and agent files have drift or redundancy
- Comments are consuming too many tokens
- New repository needs compact defaults from day one

## Workflow

### Step 1: Detect project type and language

Collect project signals from root:

- Node/TS: `package.json`, `tsconfig.json`
- Python: `pyproject.toml`, `requirements.txt`
- Go: `go.mod`
- Rust: `Cargo.toml`
- Bash-heavy: `scripts/*.sh`, hooks, no language manifest

Report detected stack, dominant language, test command, and docs/instruction locations.

### Step 2: Run project audit script

Run the standard audit first (machine-first, JSON output):

```bash
~/.claude/scripts/project-audit.sh --project-root . --json
```

Use this output as baseline counts for debt, risk, and comment-density flags.

### Step 3: AI analysis (token efficiency + quality)

Analyze audit output plus repository files for:

1. **CLAUDE.md quality**
   - conflicting rules
   - duplicated sections
   - verbose prose where compact tables/checklists are better
2. **Agent file redundancy**
   - duplicated guidance across `AGENTS.md`, `CLAUDE.md`, skill files
   - repeated workflow text better centralized in one reference file
3. **Comment token waste**
   - comments that restate obvious code behavior
   - long explanatory blocks with no decision context
   - stale comments that no longer match code

Comment-density severity:

- **P2** if comment density is `> 10%`
- **P1** if comment density is `> 20%`

### Step 4: Generate optimization report

Return a structured report:

```markdown
## Optimize Project Report: {project}

### Mode
{--audit|--fix|--setup}

### Detection
- Type: {type}
- Language: {language}
- Framework: {framework}

### Audit Summary
| Severity | Count |
|----------|-------|
| P1       | {n}   |
| P2       | {n}   |
| P3       | {n}   |

### AI Findings
| # | Severity | Area | File | Issue | Suggested Action |
|---|----------|------|------|-------|------------------|

### Token Savings Estimate
- Estimated current instruction/comment tokens: {current}
- Estimated optimized tokens: {optimized}
- Estimated savings: {saved} ({percent}%)
```

Savings estimate should separate:

- instruction/documentation compaction
- redundant agent content removal
- comment cleanup impact

### Step 5: Apply safe auto-fixes (`--fix` mode)

Only safe, low-risk fixes are allowed automatically:

1. `.gitignore` hygiene:
   - add missing common local/runtime artifacts
   - avoid removing existing ignore patterns without evidence
2. Comment cleanup:
   - remove trivial comments that restate obvious code
   - keep comments that explain **why**, invariants, or non-obvious constraints
   - never change executable logic during cleanup

After fixes, rerun:

```bash
~/.claude/scripts/project-audit.sh --project-root . --json
```

Report before/after deltas and updated token-savings estimate.

### Step 6: Setup mode for new projects (`--setup`)

Bootstrap optimize-project baseline:

1. Detect stack and choose matching minimal templates
2. Create compact `CLAUDE.md` baseline with no duplicated policy blocks
3. Add starter `AGENTS.md` + skill references with clear ownership boundaries
4. Add/update `.gitignore` with language-appropriate defaults
5. Run `project-audit.sh --json` and return initial health report

`--setup` must prefer concise templates and avoid adding verbose boilerplate.

## Guardrails

- `--audit` never writes files
- `--fix` writes only safe auto-fixes listed above
- `--setup` creates baseline files but does not overwrite user-authored docs without explicit diff review
- All outputs must be deterministic and machine-readable where possible

## References

- Pattern baseline: `~/.claude/skills/review-pr/SKILL.md`
- Audit script: `~/.claude/scripts/project-audit.sh`
- Hardening context: `~/.claude/skills/hardening/SKILL.md`
