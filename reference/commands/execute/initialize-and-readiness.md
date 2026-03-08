# Execute: Initialize and Readiness

## Startup sequence
1. Load plan context (`plan-db.sh get-context`).
2. Auto-heal approval/worktree metadata when missing.
3. Ensure worktree path exists and `cd` into it.
4. Start plan if not already in `doing`.
5. Run readiness checks before dispatch.

## Mandatory readiness bundle
- Run execution preflight and inspect warnings.
- Stop for critical readiness warnings (dirty worktree, missing docs, auth readiness for PR/CI tasks).
- Load CI knowledge from repo first, then global fallback.
- Extract and pass constraints block into every task prompt.
