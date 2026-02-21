# agents.md

Cross-tool agent configuration for ~/.claude. Compatible with Claude Code, GitHub Copilot CLI, and Codex CLI.

## Repository Overview

Personal Claude Code configuration: dashboard, scripts, rules for AI-powered development workflows. Plan execution system with SQLite DB, worktree management, quality validation (Thor gates).

## Coding Standards

### TypeScript/JavaScript
ESLint+Prettier | Semicolons, single quotes, max 100 chars | `const`>`let` | `async`/`await` | Named imports (no default exports unless framework) | `interface`>`type` | Props interface above component | Colocated `.test.ts`, AAA pattern

### Bash
`set -euo pipefail` | Quote vars: `"$VAR"` | `local` in functions | `trap cleanup EXIT` | Exit: 0=success, 1=error, 2=usage

### Python
Black (88 chars) | Google docstrings | Type hints (public APIs) | pytest+fixtures

### CSS
CSS Modules or BEM | `rem` (type), `px` (borders) | Mobile-first | Max 3 nesting

### General
2-space indent | English only | Max 250 lines/file (Thor enforced) | Conventional commits (`feat:`, `fix:`, `chore:`, `docs:`)

## Anti-Hallucination Rules

1. **NEVER guess DB schema, file paths, or API signatures** — read the source first (`plan-db-schema.md`, `script --help`, `PRAGMA table_info`)
2. **NEVER invent URLs, emails, or domains** — ASK user if unknown
3. **NEVER hardcode secrets/URLs/endpoints in code** — use `${VAR:-default}` pattern (see `.env.example`)
4. **Guessing = hallucination = VIOLATION**

## Quality Gates - Thor Validation

**Per-task** (gates 1-4, 8, 9): DB integrity, F-xx coverage, file size <250, test criteria, no debt (TODO/FIXME/@ts-ignore), git clean

**Per-wave**: All 9 gates + build

**Commands**:
```bash
plan-db.sh validate-task {task_id}     # Single task
plan-db.sh validate-wave {wave_db_id}  # Wave
plan-db.sh validate {plan_id}          # Full plan
thor-validate.sh {plan_id} [--full]    # Quick/full validation
```

**Rules**: NEVER commit before Thor | Use `plan-db-safe.sh update-task` (auto-validates) | Max 3 rejection rounds

### Testing
80% coverage (business logic), 100% (critical paths) | Isolated, one behavior/test | TDD: Red-Green-Refactor

### Security
Parameterized queries (`:param`), never string interpolation | Env vars for secrets | CSP headers | TLS 1.2+ | RBAC | IaC: no secrets in outputs

### Accessibility
4.5:1 contrast | Keyboard nav | Screen readers | Text alternatives | 200% zoom support

## Test Commands

### Dashboard (Node.js/TypeScript)
```bash
npm install               # Dependencies
npm run lint              # Linting
npm run typecheck         # Type checking
npm run build             # Build
npm run ci:summary        # All checks
```

### Bash Scripts
```bash
./scripts/collect-tests.sh          # All tests
./tests/test-{name}.sh              # Specific test
./scripts/thor-validate.sh {plan}   # Thor validation
```

### Database
```bash
plan-db.sh validate {plan_id}           # Plan integrity
plan-db.sh conflict-check {plan_id}     # Conflict detection
plan-db.sh validate-wave {wave_db_id}   # Wave validation
```

## Database Architecture

**Location**: `$HOME/.claude/data/dashboard.db` (SQLite, WAL mode)

**Access**: Use `plan-db.sh` CLI for ALL database operations. NEVER use raw sqlite3 unless you have read `reference/operational/plan-db-schema.md` first.

**Why CLI-only**: Complex FK relationships (`wave_id_fk` numeric FK, not `wave_id` string). Direct SQL = schema violations.

**Valid Statuses**:
- Task: `pending` | `in_progress` | `done` | `blocked` | `skipped`
- Plan: `todo` | `doing` | `done` | `archived`
- Wave: `pending` | `in_progress` | `done` | `blocked`

**Common Operations**:
```bash
plan-db.sh create {proj} "Name" --source-file {file} --auto-worktree  # Create plan
plan-db-safe.sh update-task {id} done "Summary"                       # Update task (auto-validates)
plan-db.sh json {plan_id} {task_id}                                   # Get task info
plan-db.sh list {project_id}                                          # List plans
plan-db.sh complete {plan_id}                                         # Complete plan
plan-db.sh get-worktree {plan_id}                                     # Get worktree path
```

## Worktree Discipline

**Principle**: Every plan = dedicated worktree. Auto-created: `plan/{plan_id}-{slug}` branch, path in DB.

**Protection**: `worktree-guard.sh` BLOCKS git writes on `main`/`master` (exit 2)

**Rules**:
1. Create via `worktree-create.sh`, NEVER `git worktree add`
2. One plan = one worktree (path in DB)
3. `.env` auto-symlinked from main repo
4. Check `pwd` + branch before git ops
5. Commit/stash before switch
6. DB = source of truth: `plan-db.sh get-worktree {plan_id}`
7. `plan-db.sh check-readiness {plan_id}` validates worktree_path

**Commands**:
```bash
worktree-create.sh {branch} [path]    # Create worktree
worktree-check.sh [expected]          # Check context
plan-db.sh set-worktree {plan} {path} # Set in DB
```

## PR Conventions

**Branches**: `feature/`, `fix/`, `chore/`, `plan/{plan_id}-{slug}` (auto)

**Commits**: Conventional Commits format
```
<type>(<scope>): <description>
```
Types: `feat`, `fix`, `chore`, `docs`, `style`, `refactor`, `test`, `perf`

**PR Checklist**: Lint pass | Type check pass | Tests pass | Build success | Threads resolved | Thor validated | ZERO debt (no TODO/FIXME/@ts-ignore in new code)

## Architectural Invariants

### File Size Limit
Max 250 lines/file (Thor Gate 3). Why: agents lose context, merge conflicts multiply, review unreliable.

### Workflow Enforcement
Mandatory: `/prompt` → F-xx extract → `/planner` → DB approval → `/execute {id}` (TDD) → Thor per-task → Thor per-wave → closure

**Anti-bypass**: NEVER execute plan tasks via direct file edits. Active plan = tasks through `Task(subagent_type='task-executor')`. Why: Plan 182.

### Compaction Preservation
When rewriting/compacting files, NEVER remove workflow-critical content. See `rules/compaction-preservation.md`.

### Concurrency Control
File locking via `file-lock.sh`:
```bash
file-lock.sh acquire {file} {task_id}
file-lock.sh release {file} [task_id]
file-lock.sh check {file}
```

Stale detection:
```bash
plan-db.sh stale-check snapshot|check|diff
plan-db.sh merge-queue enqueue|process|status
```

## Cross-Tool Compatibility

**Tools**: Claude Code (primary), GitHub Copilot CLI, Codex CLI

**Tool-specific config**: See `CLAUDE.md` (not here)

**Shell**: zsh | NEVER pipe to `tail`/`head`/`grep`/`cat` (hooks block) | Use Read tool over Bash | Prefer `bat`/`catp` for highlighting

**Path references**: Always use absolute paths or verify `pwd` (worktree context matters)

## Pre-Closure Checklist

```bash
git-digest.sh                   # clean:true required
ls -la {files} && wc -l {files} # Verify existence + line counts
plan-db.sh validate {plan_id}   # Thor validation
plan-db.sh validate-fxx {plan_id} # F-xx requirements
```

## Process Guardian

**Done criteria**:
- "works" = tested, no errors, output shown
- "done" = written, tests pass, committed, Thor validated
- "fixed" = reproduced, fixed, test proves it

**Verification**: List ALL items `[x]`/`[ ]` + method | Each F-xx: `[x]` with evidence | Disclose additions | User approves closure

**Reject if**: Errors suppressed | Steps skipped | Verification promised but not done | Same approach fails twice without different strategy

## References

- `CLAUDE.md` - Claude-specific config, agent routing
- `rules/coding-standards.md` - Detailed standards
- `rules/guardian.md` - Process guardian rules
- `rules/compaction-preservation.md` - File compaction safety
- `reference/operational/plan-scripts.md` - Plan DB script reference
- `reference/operational/worktree-discipline.md` - Worktree details
- `reference/operational/tool-preferences.md` - Tool selection
- `PLANNER-ARCHITECTURE.md` - DB schema, architecture

---

**Version**: 1.0.0 | **Updated**: 21 Feb 2026 | **Spec**: Linux Foundation agents.md
