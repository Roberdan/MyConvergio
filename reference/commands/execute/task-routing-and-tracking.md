# Execute: Task Routing and Tracking

## Per-task routing
- Source tasks from `CTX.pending_tasks`.
- Route by `executor_agent` (default `copilot`).
- Copilot path: `copilot-worker.sh` with model from DB.
- Claude path: launch task-executor with explicit model mapping.

## Mandatory tracking
- Register agent start/completion.
- Update substatus transitions (`agent_running`, `waiting_thor`, `waiting_ci`, `waiting_review`, `waiting_merge`, clear when done).
- After execution, verify task status update in DB.

## Failure handling
- Retry bounded attempts.
- Log failed approaches before marking blocked.
- Do not repeat previously failed strategy without changes.

Reference module: `@commands/execute-modules/error-handling.md`.
