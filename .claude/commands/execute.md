## <!-- v2.3.0 -->

name: execute
version: "2.3.0"

---

# Plan Executor (Compact)

Automated task execution with per-task routing (`copilot` default, `claude` by escalation).

## Activation
`/execute {plan_id}` or `/execute` (current) | Override: `--force-engine claude|copilot`

## Routing Rules
- Read `executor_agent` from DB per task.
- Default route is `copilot`.
- Use `claude` only when explicitly assigned.
- Always pass worktree path, constraints, readiness bundle, and CI knowledge.

## Required Flow
1. Initialize + auto-heal plan/worktree metadata.
2. Run readiness checks and stop on critical warnings.
3. Dispatch pending tasks via selected executor.
4. Track agent lifecycle + task substatus transitions.
5. Run per-task Thor, then per-wave Thor.
6. Apply wave merge mode (`sync`/`batch`/`none`).
7. Validate and complete plan in DB.

## Module References
- Init + readiness: `@reference/commands/execute/initialize-and-readiness.md`
- Task routing + tracking: `@reference/commands/execute/task-routing-and-tracking.md`
- Validation + merge + completion: `@reference/commands/execute/validation-merge-completion.md`
- Error handling: `@commands/execute-modules/error-handling.md`

## Output Format
`[N/total] task_id: title -> DONE` | `--- Wave WX --- Thor: PASS` | `=== COMPLETE ===`
