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

## Rule highlights
- Never skip F-xx coverage checks.
- Never mark work done without Thor validation.
- Every task must include model, effort, and executor agent.
- No silent exclusions/defer of requirements.
