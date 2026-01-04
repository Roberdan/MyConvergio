# Planner + Orchestrator

Plan and execute with parallel Claude instances (max 3).

## Quick Commands
`mostra stato`/`dashboard` → Launch dashboard | `pianifica X` → Create plan | `esegui piano` → Execute

## Workflow (MUST FOLLOW)

### Step 1: Register Project (if new)
```bash
~/.claude/scripts/register-project.sh "$(pwd)" --name "Project Name"
# Returns: project_id (e.g., "myproject")
```

### Step 2: Create Plan in DB
```bash
~/.claude/scripts/plan-db.sh create {project_id} "{PlanName}"
# Returns: plan_id (e.g., 5)
```

### Step 3: Write Plan Files
**Location**: `~/.claude/plans/{project_id}/{PlanName}-Main.md` + Phase files
**NEVER** create plans in `docs/plans/` - always use centralized location

### Step 4: Register Waves with Gantt Data
```bash
# Add wave with planned dates, estimated hours, dependencies
~/.claude/scripts/plan-db.sh add-wave {plan_id} "W1: Phase Name" \
  --planned-start "2026-01-06 09:00" \
  --planned-end "2026-01-06 17:00" \
  --estimated-hours 8

# Second wave depends on first
~/.claude/scripts/plan-db.sh add-wave {plan_id} "W2: Phase Name" \
  --planned-start "2026-01-07 09:00" \
  --planned-end "2026-01-07 17:00" \
  --estimated-hours 8 \
  --depends-on {wave_id_of_W1}
```

### Step 5: Add Tasks to Waves
```bash
# Task types: feature, bug, chore, doc, test
# Priorities: P0 (critical), P1 (high), P2 (medium), P3 (low)
~/.claude/scripts/plan-db.sh add-task {wave_id} "Task description" \
  --type feature --priority P1 --assignee "executor"
```

### Step 6: Execute
Ask "Eseguire?" then orchestrate with max 3 parallel agents

## Plan File Structure
**Max 300 lines** per file. Split: Main tracker + Phase files.

```markdown
# {PlanName} - {Description}
**Created**: DD Mese YYYY, HH:MM CET | **Target**: [Objective]
**Project**: {project_id} | **Plan ID**: {plan_id}

## PHASES
| Phase | File | Tasks | Est. Hours | Depends On | Status |
| W1 | Phase1.md | 12 | 8h | - | [ ] |
| W2 | Phase2.md | 14 | 8h | W1 | [ ] |

## FUNCTIONAL REQUIREMENTS
| ID | Requirement | Acceptance Criteria | Verified |
| F-01 | [What must WORK] | [How to test] | [ ] |
```

## Anti-Crash Rules
1. Write plan BEFORE launching agents
2. Max 3 parallel agents (4 = crash)
3. Tasks MUST be atomic: exact file + action
4. BAD: "Refactor auth" | GOOD: "Add logout() to src/auth.ts:45"

## Models
**opus**: Planning, architecture | **sonnet**: Complex execution | **haiku**: Simple tasks

## Dashboard Integration
Plans appear in Control Center Kanban with Gantt visualization.
```bash
~/.claude/scripts/start-dashboard.sh
# Opens http://127.0.0.1:31415/dashboard/dashboard.html
```

## Status Legend
[ ] Not started | [~] In progress | [x] Done | [!] Blocked
