# Thor Validation Protocol

> **Version**: 2.0.0 | Merged from worker-instructions + validation-protocol

**Golden Rule**: No agent may declare "done" without Thor's approval.

## Validation Flow

1. **Complete work**: run tests, lint, build
2. **Gather evidence**: actual output, not assurances
3. **Submit**: `plan-db-safe.sh update-task {id} done "summary"` (auto-validates)
4. **Handle response**: APPROVED / REJECTED / CHALLENGED / ESCALATED

## 9 Validation Gates

| Gate | Check                    | Pass Criteria                                         |
| ---- | ------------------------ | ----------------------------------------------------- |
| 1    | Task Compliance          | All requirements addressed, no scope creep            |
| 2    | Code Quality             | Tests pass, lint clean, build succeeds, 80%+ coverage |
| 3    | Engineering Fundamentals | No secrets, proper error handling, input validation   |
| 4    | Repository Compliance    | CLAUDE.md guidelines, existing patterns respected     |
| 5    | Documentation            | README, API docs, JSDoc/docstrings updated            |
| 6    | Git Hygiene              | Correct branch, conventional commits, no secrets      |
| 7    | Performance              | No N+1 queries, lazy loading, perf-check passes       |
| 8    | TDD Verification         | Tests written BEFORE implementation                   |
| 9    | Acceptance               | Stakeholder approval, user-facing validation          |

## Status Types

| Status     | Meaning                 | Action                            |
| ---------- | ----------------------- | --------------------------------- |
| APPROVED   | All gates passed        | Proceed to next task              |
| REJECTED   | Gate(s) failed          | Fix ALL issues, resubmit          |
| CHALLENGED | Evidence insufficient   | Provide proof, not assurances     |
| ESCALATED  | 3 failures on same task | STOP, wait for human intervention |

## Request Format (JSON)

```json
{
  "request_id": "uuid",
  "worker_id": "agent-name",
  "request_type": "task_validation",
  "task": {
    "reference": "W1-T03",
    "original_instructions": "exact task description",
    "plan_file": "/path/to/plan"
  },
  "claim": {
    "summary": "what was done",
    "files_created": [],
    "files_modified": [],
    "tests_added": []
  },
  "evidence": {
    "test_output": "actual output",
    "lint_output": "actual output",
    "build_output": "actual output",
    "git_branch": "actual branch",
    "git_status": "actual status"
  }
}
```

## Response Format (JSON)

```json
{
  "request_id": "uuid",
  "status": "APPROVED|REJECTED|CHALLENGED|ESCALATED",
  "validation_results": { "gate_name": { "passed": true, "notes": "" } },
  "issues": ["list of failures"],
  "required_fixes": ["what to do"],
  "retry_count": 1,
  "max_retries": 3
}
```

## Specialist Integration

Thor invokes domain specialists when relevant:

| Domain       | Specialist                 |
| ------------ | -------------------------- |
| Security     | luca-security-expert       |
| Architecture | baccio-tech-architect      |
| Performance  | otto-performance-optimizer |

## Retry Management

- Max 3 retries per agent per task
- After 3 failures: ESCALATED (human must intervene)
- Retry count resets after APPROVED

## Audit Log

All validations logged to `thor-audit-log.sh` (append-only):

```jsonl
{
  "ts": "...",
  "id": "uuid",
  "worker": "agent",
  "task": "ref",
  "status": "APPROVED",
  "retry": 0
}
```

## Worker Integration

Every agent MUST:

1. Submit work to Thor before claiming completion
2. Wait for response (do not proceed without validation)
3. If REJECTED: fix ALL issues, resubmit
4. If CHALLENGED: provide requested evidence
5. If ESCALATED: STOP and wait
6. Only after APPROVED: declare task complete

**Preferred method**: Use `plan-db-safe.sh update-task {id} done` which auto-triggers Thor validation.
