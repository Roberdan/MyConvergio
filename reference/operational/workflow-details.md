<!-- v2.0.0 | 15 Feb 2026 | Token-optimized per ADR 0009 -->

# Workflow Details

## Phase Isolation

Each phase uses fresh context, data via files/DB only.

## Workflow Steps

1. `/prompt` -> Extract F-xx requirements, user confirms
2. `/research` (optional) -> Research doc at `.copilot-tracking/research/`
3. `/planner` -> Waves/tasks in DB, user approves
4. `plan-db.sh start {id}` -> `/execute {id}` (TDD: RED->GREEN->REFACTOR)
5. Thor validation per-task + per-wave -> `plan-db.sh validate-task` / `validate-wave` + build + tests
6. Closure -> All F-xx with [x]/[ ], user approves ("finito")

## Constraints

- **Skip any step = BLOCKED**
- **Self-declare done = REJECTED**
- User approves closure ("finito")

## Detail References

@reference/operational/plan-scripts.md
@reference/operational/digest-scripts.md
@reference/operational/worktree-discipline.md
@reference/operational/concurrency-control.md
@reference/operational/execution-optimization.md
