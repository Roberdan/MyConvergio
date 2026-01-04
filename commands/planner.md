# Planner + Orchestrator

Plan and execute with parallel Claude instances (max 3).

## Quick Commands
`mostra stato`/`dashboard` → Launch dashboard | `pianifica X` → Create plan | `esegui piano` → Execute

## Workflow
1. Read project context (./CLAUDE.md) → 2. Gather requirements → 3. Create plan file → 4. Ask "Eseguire?" → 5. Orchestrate

## Plan File
**Location**: `docs/plans/[Name]Plan[Date].md` or `~/.claude/plans/{project_id}/`
**Max 300 lines** per file-size-limits.md. Split: Main tracker + Phase files.

### Required Structure
```markdown
# [Name]Plan - [Description]
**Created**: DD Mese YYYY, HH:MM CET | **Target**: [Objective]

## CHECKPOINT LOG
| Timestamp | Agent | Task | Status | Notes |
**Last Good State**: [description] | **Resume**: [instructions]

## RUOLI
| Claude | Ruolo | Model |
| CLAUDE 1 | PLANNER | opus |
| CLAUDE 2-3 | EXECUTOR | haiku (simple) / sonnet (complex) |

## FUNCTIONAL REQUIREMENTS
| ID | Requirement | Acceptance Criteria | Verified |
| F-01 | [What must WORK] | [How to test] | [ ] |

## EXECUTION TRACKER
| Status | ID | Task | Assignee | Files |
| [ ] | T-01 | [Specific action] | CLAUDE 2 | `exact/path.ts` |
| [ ] | T-FINAL | THOR VALIDATION | thor | All |
```

## Anti-Crash Rules
1. Write plan BEFORE launching agents
2. Max 3 parallel agents (4 = crash)
3. Tasks MUST be atomic: specify exact file + action
4. BAD: "Refactor auth" | GOOD: "Add logout() to src/auth.ts:45"
5. Executors read ONLY files in task, no exploration

## Models
**opus**: Planning, architecture | **sonnet**: Complex execution | **haiku**: Simple tasks (<10 files)

## Token Safety
Read(limit), Grep for searches, Task tool for exploration

## Git/PR
Branch: `{type}/{ticket}-{desc}` | Worktree: `git worktree add ../{proj}-{branch} {branch}`
PR: `gh pr create --title "..." --body "Fixes #123..."`

## Thor Validation
Before closure: All F-xx verified, build/lint/typecheck pass, docs complete.

## Dashboard
```bash
npx live-server ~/.claude --port=31415 --no-browser &
open http://127.0.0.1:31415/dashboard/dashboard.html
```

## Status Legend
[ ] Not started | [~] In progress | [x] Done | [!] Blocked
