# Planner + Orchestrator

Plan and execute with parallel Claude instances (max 3).

## Quick Commands
`mostra stato`/`dashboard` → Launch dashboard | `pianifica X` → Create plan | `esegui piano` → Execute

## Workflow (MUST FOLLOW)

### Step 1: Register Project
```bash
~/.claude/scripts/register-project.sh "$(pwd)" --name "Project Name"
```
This creates: project in DB + `~/.claude/plans/{project_id}/` folder

### Step 2: Create Plan in DB
```bash
~/.claude/scripts/plan-db.sh create {project_id} "{PlanName}-Main"
```

### Step 3: Write Plan Files
**Location**: `~/.claude/plans/{project_id}/{PlanName}-Main.md` + Phase files
**NEVER** create plans in `docs/plans/` - always use centralized location

### Step 4: Register Waves & Tasks
```bash
~/.claude/scripts/plan-db.sh add-wave {plan_id} "Phase 1 - Description"
~/.claude/scripts/plan-db.sh add-task {wave_id} "Task description"
```

### Step 5: Execute
Ask "Eseguire?" then orchestrate with max 3 parallel agents

## Plan File Structure
**Max 300 lines** per file. Split: Main tracker + Phase files.

```markdown
# {PlanName} - {Description}
**Created**: DD Mese YYYY, HH:MM CET | **Target**: [Objective]
**Project**: {project_id} | **Plan ID**: {plan_id}

## CHECKPOINT LOG
| Timestamp | Agent | Task | Status | Notes |

## PHASES
| Phase | File | Tasks | Status |
| 1 | Phase1.md | 12 | [ ] |

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
Plans created via this workflow appear automatically in Control Center Kanban.
```bash
open http://127.0.0.1:31415/dashboard/dashboard.html
```

## Status Legend
[ ] Not started | [~] In progress | [x] Done | [!] Blocked
