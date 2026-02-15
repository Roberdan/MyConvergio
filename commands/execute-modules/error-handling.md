---
name: error-handling
version: "1.0.0"
---

# Execution Error Handling

## Task Failure (executor owns retry)

1. Task-executor returns → `verify-task-update.sh` checks DB
2. If task NOT done: retry with error context (max 2 retries)
3. After 2 retries: mark task `blocked`, ASK USER via AskUserQuestion
4. User options: different approach, skip, stop

## Thor Rejection (executor owns dispute loop)

1. Thor returns structured THOR_REJECT (failed_tasks, evidence, fixes)
2. Executor launches targeted task-executor per failed item
3. Re-launches Thor (max 3 rounds total)
4. After round 3 still REJECT: ESCALATE to user with full context

## Build Failure

1. Run `npm run ci:summary` to identify errors
2. Launch task-executor to fix specific build errors
3. Re-run build (max 2 retries)
4. If still fails: ASK USER

## Recovery Strategies

| Failure          | Auto-Action            | Escalation           |
| ---------------- | ---------------------- | -------------------- |
| Task timeout     | Retry with sonnet      | User after 2 retries |
| Test failure     | Fix + re-test          | User after 2 retries |
| Build error      | Fix TS/lint errors     | User after 2 retries |
| Thor rejection   | Fix per THOR_REJECT    | User after 3 rounds  |
| Missing metadata | check-readiness blocks | Immediate (no retry) |

## Anti-Failure Rules

- Never skip approval gate
- Never fake timestamps
- Never mark done without F-xx check
- **NEVER bypass Thor** - learned from Plan 085
- **NEVER trust executor reports** - verify with Thor + file reads
- **Wave completion = Thor PASS** - not just executor reports
