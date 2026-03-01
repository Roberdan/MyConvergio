# ADR-0026: Anti-Self-Validation Protocol

**Status**: Accepted
**Date**: 01 March 2026
**Context**: Copilot CLI executor calling `validate-task ... thor` directly = self-validation = confirmation bias from implementation context.

## Problem

An executor that validates its own work has inherent confirmation bias. Even with fresh context (context_isolation: true), the same LLM instance processing the same prompt framing will tend to validate what it implemented. This is the "fox guarding the henhouse" problem.

## Decision

3-layer protection (all layers required, in order):

| Layer | Mechanism                                                                                            | Bypassable?                              |
| ----- | ---------------------------------------------------------------------------------------------------- | ---------------------------------------- |
| 1     | `plan-db-safe.sh` guards: time elapsed, git-diff, verify commands                                    | NO — deterministic                       |
| 2     | Independent validator in fresh context window (`@validate` handoff or `task(agent_type="validate")`) | Partially — same model, no prior context |
| 3     | SQLite trigger `enforce_thor_done`: submitted→done ONLY via `validated_by` whitelist                 | NO — DB enforced                         |

## Correct Copilot CLI Flow

```bash
# 1. Execute task inline
# 2. Submit (Layer 1 guards run)
plan-db-safe.sh update-task {id} done "summary"   # → status: submitted

# 3. Independent validation in FRESH context (Layer 2)
@validate Validate task {task_id} in plan {plan_id}. Read files, run verify.
  If PASS: plan-db.sh validate-task {db_id} {plan_id} thor
  If FAIL: reject with reasons.
# Layer 3: SQLite trigger enforces validated_by whitelist
```

## VIOLATIONS

- `plan-db.sh validate-task` called directly by the executor (no `@validate` intermediate) = VIOLATION
- Executor calling `validate-task` in same context as implementation = VIOLATION
- Skipping `plan-db-safe.sh` and calling `validate-task` directly = blocked by Layer 3 (submitted status required)

## Why Layer 2 Still Matters

Layer 1 and 3 are deterministic and non-bypassable. Layer 2 (fresh context) reduces but does not eliminate bias. The combination of all 3 is what provides meaningful quality assurance.

## Consequences

- `execute.agent.md`, `.github/skills/execute.md`, `copilot-instructions.md` updated to remove "self-validate" language
- `execution-optimization.md` v2.5.0 documents 3-layer protection table
- Any new Copilot CLI executor doc must reference `@validate` handoff, never direct `validate-task`
