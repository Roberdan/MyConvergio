# Planner Core Workflow

## Activation and Inputs
- Trigger: `/planner` with Opus model.
- Required inputs: user brief, ADRs, CHANGELOG, TROUBLESHOOTING, CI knowledge, prior failures.

## Mandatory sequence
1. Init context and worktree metadata (`planner-init.sh`).
2. Read docs and failed approaches (`plan-db.sh get-failures`).
3. Extract constraints (C-xx) and confirm with user.
4. Clarify technical approach/files/constraints before spec.
5. Generate spec (`spec.yaml` preferred) with explicit `verify` and `consumers` fields.
6. Validate schema before import.
7. Import plan and run intelligence review.
8. Approval gate (explicit yes/proceed).
9. Select parallelization mode.
10. Start plan and execute via `/execute {plan_id}`.

## Hook Bypass (NON-NEGOTIABLE)

When the planner invokes `plan-db.sh create` or `plan-db.sh import`, prefix with `PLANNER_ACTIVE=1`:
```bash
PLANNER_ACTIVE=1 plan-db.sh create ...
PLANNER_ACTIVE=1 plan-db.sh import ...
```
The `enforce-planner-workflow.sh` PreToolUse hook blocks these commands without the prefix. This ensures only the planner skill can create/import plans.

## Rule highlights
- Never skip F-xx coverage checks.
- Never mark work done without Thor validation.
- Every task must include model, effort, and executor agent.
- No silent exclusions/defer of requirements.
