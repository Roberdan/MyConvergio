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

## Gated Plan Creation (NON-NEGOTIABLE)

`plan-db.sh create` and `plan-db.sh import` are **blocked by PreToolUse hook**. The ONLY way to create/import plans is through `planner-create.sh`, which enforces all 3 reviews exist before allowing creation.

### Mandatory sequence inside planner skill:

```bash
# 1. Launch 3 review agents (parallel)
Agent(subagent_type="plan-reviewer")           # standard review
Agent(subagent_type="plan-reviewer", name="plan-challenger")  # challenger mode
Agent(subagent_type="plan-business-advisor")    # business impact

# 2. Save review outputs to files
Write review outputs to /tmp/review-standard.md, /tmp/review-challenger.md, /tmp/review-business.md

# 3. Register reviews (gate validation)
planner-create.sh register-review standard /tmp/review-standard.md
planner-create.sh register-review challenger /tmp/review-challenger.md
planner-create.sh register-review business /tmp/review-business.md

# 4. Create plan (blocked without all 3 reviews)
planner-create.sh create <project> "<name>" --auto-worktree --human-summary "<summary>"

# 5. Import spec (also blocked without reviews)
planner-create.sh import <plan_id> spec.yaml

# 6. Reset for next plan
planner-create.sh reset
```

Skipping any review = `planner-create.sh` exits with error. No bypass possible.

## Rule highlights
- Never skip F-xx coverage checks.
- Never mark work done without Thor validation.
- Every task must include model, effort, and executor agent.
- No silent exclusions/defer of requirements.
