# Execute: Validation, Merge, Completion

## Thor flow
1. Per-task Thor validation.
2. Per-wave Thor validation when wave tasks are done and validated.
3. Rework loop on rejection (bounded retries).

## Merge decision
After per-wave Thor PASS, dispatch by `merge_mode`:
- `sync`: merge wave worktree, PR, CI path
- `batch`: commit to shared theme branch
- `none`: validate-only path (no immediate merge)

Maintain substatus updates through CI/review/merge lifecycle.

## Completion criteria
- All tasks validated.
- Wave validations complete.
- Plan validates and completes in DB.
- Check checkpoint/memory consistency and smoke-test evidence for sensitive changes.
