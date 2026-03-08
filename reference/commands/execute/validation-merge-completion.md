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

## Post-Plan Learning Loop (Thor 10)

After plan closure (PR merged, deploy verified), before marking complete:

1. **Analyze**: What broke, what was manually fixed, what CI caught that agents missed, what took multiple attempts
2. **Propose**: For each finding → concrete fix (new rule in `rules/*.md`, KB entry, script fix, planner constraint)
3. **Apply**: Two-level update:
   - **Generic (`.claude/`)**: Rules valid for any repo/platform/language. Max 3 new rules per plan.
   - **Project-specific**: Update repo `CLAUDE.md` (conventions, gotchas) and/or `AGENTS.md` (domain context)
4. **Verify**: Confirm the new rule would have caught the original issue

Constraints: `.claude/` rules MUST be generic. Project-specific learnings go in repo `CLAUDE.md`, `AGENTS.md`, or `MEMORY.md`. Every new rule MUST include `_Why: Plan NNN — description_`.
