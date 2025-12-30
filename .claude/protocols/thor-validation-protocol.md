# Thor Validation Protocol

> **Version**: 1.0.1
> **Status**: Active
> **Last Updated**: 2025-12-30

## Overview

This protocol defines how ALL Claude instances (workers AND orchestrators) must interact with Thor for validation before claiming task completion.

**Golden Rule**: No Claude may declare "done" without Thor's approval.

## Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                        KITTY TERMINAL                           │
├─────────┬─────────┬─────────┬─────────┬─────────────────────────┤
│Claude-1 │Claude-2 │Claude-3 │Claude-4 │     Thor-QA             │
│(Planner)│(Worker) │(Worker) │(Worker) │   (Validator)           │
├─────────┴─────────┴─────────┴─────────┴─────────────────────────┤
│                                                                 │
│  ┌─────────────────────────────────────────────────────────┐   │
│  │              /tmp/thor-queue/                            │   │
│  │  ├── requests/     ← Workers submit validation requests │   │
│  │  ├── responses/    ← Thor writes validation responses   │   │
│  │  └── audit.jsonl   ← All validations logged            │   │
│  └─────────────────────────────────────────────────────────┘   │
│                                                                 │
│  Dual-Channel Communication:                                    │
│  1. File-based (persistent, complete data)                     │
│  2. Kitty text (real-time notification, cross-check)           │
└─────────────────────────────────────────────────────────────────┘
```

## Queue Setup

### Directory Structure
```bash
/tmp/thor-queue/
├── requests/           # Validation request files
│   └── {uuid}.json     # One file per request
├── responses/          # Thor's validation responses
│   └── {uuid}.json     # One file per response
├── audit.jsonl         # Append-only audit log
└── state/              # Thor's state tracking
    └── retry-counts.json
```

### Initialization Script
```bash
#!/bin/bash
# Run this before starting Thor

mkdir -p /tmp/thor-queue/{requests,responses,state}
touch /tmp/thor-queue/audit.jsonl
echo '{}' > /tmp/thor-queue/state/retry-counts.json
echo "Thor queue initialized at $(date)"
```

## Request Format

Workers MUST submit validation requests in this format:

```json
{
  "request_id": "550e8400-e29b-41d4-a716-446655440000",
  "timestamp": "2025-12-30T14:30:00Z",
  "worker_id": "Claude-2",
  "worker_title": "Claude-2",
  "request_type": "task_validation",

  "task": {
    "reference": "Plan Phase 2, Task 2.3",
    "original_instructions": "Implement JWT authentication with refresh tokens. Must include: 1) Token generation endpoint 2) Token refresh endpoint 3) Token validation middleware 4) Unit tests with >80% coverage",
    "plan_file": "/path/to/execution-plan.md"
  },

  "claim": {
    "summary": "JWT authentication implemented with all required endpoints and tests",
    "files_created": ["src/auth/jwt.ts", "src/auth/middleware.ts"],
    "files_modified": ["src/routes/index.ts"],
    "tests_added": ["tests/auth/jwt.test.ts"]
  },

  "evidence": {
    "test_command": "npm test -- --coverage",
    "test_output": "Tests: 15 passed, 0 failed\nCoverage: 87%",
    "lint_command": "npm run lint",
    "lint_output": "No errors or warnings",
    "build_command": "npm run build",
    "build_output": "Build successful",
    "git_branch": "feature/jwt-auth",
    "git_status": "On branch feature/jwt-auth\nnothing to commit, working tree clean",
    "git_log_last": "feat(auth): implement JWT authentication\n\n- Add token generation endpoint\n- Add refresh token endpoint\n- Add validation middleware\n- Add tests (87% coverage)"
  },

  "self_check": {
    "tests_run": true,
    "tests_pass": true,
    "lint_clean": true,
    "build_passes": true,
    "documentation_updated": true,
    "on_correct_branch": true,
    "changes_committed": true
  }
}
```

## Response Format

Thor responds with:

```json
{
  "request_id": "550e8400-e29b-41d4-a716-446655440000",
  "timestamp": "2025-12-30T14:35:00Z",
  "worker_id": "Claude-2",
  "status": "REJECTED",

  "validation_results": {
    "task_compliance": {
      "passed": false,
      "score": "3/4",
      "notes": "Token validation middleware not properly handling expired tokens",
      "missing": ["Expired token handling returns 500 instead of 401"]
    },
    "code_quality": {
      "passed": true,
      "notes": "Tests comprehensive, good coverage"
    },
    "engineering_fundamentals": {
      "passed": true,
      "notes": "No security issues found"
    },
    "repository_compliance": {
      "passed": true,
      "notes": "Follows existing patterns"
    },
    "documentation": {
      "passed": false,
      "issues": ["README not updated with new endpoints", "No JSDoc on public functions"]
    },
    "git_hygiene": {
      "passed": true,
      "notes": "Clean commit on correct branch"
    }
  },

  "specialist_reviews": {
    "luca-security-expert": {
      "invoked": true,
      "assessment": "PASS - No OWASP violations detected"
    }
  },

  "brutal_challenge": {
    "questions_asked": [
      "Are you BRUTALLY sure you've done EVERYTHING?",
      "Did you handle ALL error cases for token validation?"
    ],
    "concerns": ["Worker claimed expired token handling but code returns 500"]
  },

  "issues": [
    "Token validation middleware returns 500 for expired tokens instead of 401",
    "README not updated with new authentication endpoints",
    "Missing JSDoc comments on exported functions"
  ],

  "required_fixes": [
    "Fix expired token handling to return 401 Unauthorized",
    "Add authentication section to README with endpoint documentation",
    "Add JSDoc to all public functions in jwt.ts and middleware.ts"
  ],

  "retry_count": 1,
  "max_retries": 3,
  "next_action": "Fix listed issues and resubmit. Do not resubmit until ALL issues are resolved."
}
```

## Communication Flow

### Worker → Thor (Request Submission)

```bash
# 1. Worker generates request file
REQUEST_ID=$(uuidgen | tr '[:upper:]' '[:lower:]')
# Note: Use unquoted EOF for variable expansion
cat > /tmp/thor-queue/requests/${REQUEST_ID}.json << EOF
{
  "request_id": "${REQUEST_ID}",
  ...
}
EOF

# 2. Worker notifies Thor via Kitty (optional but recommended)
kitty @ send-text --match title:Thor-QA "[VALIDATION REQUEST] ${REQUEST_ID} from Claude-2 - Task: JWT Authentication"
kitty @ send-key --match title:Thor-QA Return

# 3. Worker waits for response
while [ ! -f /tmp/thor-queue/responses/${REQUEST_ID}.json ]; do
  sleep 5
done

# 4. Worker reads response
cat /tmp/thor-queue/responses/${REQUEST_ID}.json
```

### Thor → Worker (Response)

```bash
# 1. Thor writes response file (unquoted EOF for variable expansion)
cat > /tmp/thor-queue/responses/${REQUEST_ID}.json << EOF
{
  "request_id": "${REQUEST_ID}",
  "status": "APPROVED",
  ...
}
EOF

# 2. Thor notifies worker via Kitty
kitty @ send-text --match title:Claude-2 "[THOR RESPONSE] ${REQUEST_ID} - APPROVED - You may proceed"
kitty @ send-key --match title:Claude-2 Return

# 3. Thor logs to audit file
echo '{"timestamp":"...","request_id":"...","status":"APPROVED"}' >> /tmp/thor-queue/audit.jsonl
```

## Status Types

### APPROVED
- All validation gates passed
- Worker may proceed to next task
- Logged as success in audit

### REJECTED
- One or more validation gates failed
- Worker MUST fix all issues before resubmitting
- Retry count incremented
- Specific issues and fixes provided

### CHALLENGED
- Thor needs more evidence
- Worker must provide proof, not assurances
- Does not count against retry limit

### ESCALATED
- Worker has failed 3 times for same task
- Roberto must intervene
- Worker should STOP and wait
- High priority notification to Roberto

## Retry Management

```json
// /tmp/thor-queue/state/retry-counts.json
{
  "Claude-2:task-2.3": 2,
  "Claude-1:task-1.1": 0,
  "Claude-3:task-3.2": 1
}
```

- Max 3 retries per worker per task
- After 3 failures → ESCALATED
- Retry count resets after APPROVED

## Orchestrator Validation

Orchestrators (Planner, Ali) are also subject to validation:

### Plan Validation Request
```json
{
  "request_id": "...",
  "worker_id": "Planner",
  "request_type": "plan_validation",
  "task": {
    "reference": "User Request",
    "original_instructions": "Original user request text",
    "plan_file": "/path/to/generated-plan.md"
  },
  "claim": {
    "summary": "Execution plan created covering all requirements",
    "phases": 4,
    "tasks": 12,
    "parallel_lanes": 3
  },
  "evidence": {
    "requirements_coverage": {
      "req1": "Task 1.1",
      "req2": "Task 2.3",
      "req3": "Task 3.1"
    }
  }
}
```

### Thor validates plans for:
- Complete requirement coverage
- Proper task decomposition
- Correct dependency mapping
- Valid parallel lane independence
- Included verification steps
- Correct git workflow

## Specialist Integration

Thor invokes specialists for domain-specific validation:

```
Thor Processing Request
├── Parse request, identify domains touched
├── For security-related changes:
│   └── Task → luca-security-expert
├── For architecture changes:
│   └── Task → baccio-tech-architect
├── For performance-critical code:
│   └── Task → otto-performance-optimizer
├── Collect specialist assessments
└── Incorporate into final validation
```

## Audit Log Format

```jsonl
{"ts":"2025-12-30T14:35:00Z","id":"uuid1","worker":"Claude-2","task":"jwt-auth","status":"REJECTED","retry":1,"issues":["expired token handling"]}
{"ts":"2025-12-30T15:10:00Z","id":"uuid2","worker":"Claude-2","task":"jwt-auth","status":"APPROVED","retry":2,"specialists":["luca"]}
{"ts":"2025-12-30T15:15:00Z","id":"uuid3","worker":"Planner","task":"plan-v1","status":"APPROVED","type":"plan_validation"}
```

## Worker Integration Requirements

Every Claude worker MUST:

1. **Before claiming completion**: Submit validation request to Thor
2. **Wait for response**: Do not proceed until Thor responds
3. **If REJECTED**: Fix ALL issues, then resubmit
4. **If CHALLENGED**: Provide requested evidence
5. **If ESCALATED**: STOP and wait for Roberto
6. **Only after APPROVED**: Declare task complete

### Worker Prompt Addition
All workers should have this in their instructions:

```markdown
## Thor Validation Requirement

You MUST submit your work to Thor for validation before claiming any task is complete.

1. When you finish a task, create a validation request file
2. Submit to /tmp/thor-queue/requests/
3. Wait for Thor's response in /tmp/thor-queue/responses/
4. If REJECTED: Fix everything, resubmit
5. If APPROVED: You may proceed

You are NOT done until Thor says you are done.
```

## Error Handling

### Queue Directory Missing
```bash
if [ ! -d /tmp/thor-queue ]; then
  echo "ERROR: Thor queue not initialized. Run setup script."
  exit 1
fi
```

### Thor Not Responding (>5 min)
- Worker should notify via Kitty
- If still no response, escalate to Roberto
- Do NOT proceed without validation

### Malformed Request
- Thor rejects with CHALLENGED status
- Specifies what's wrong with request format
- Worker must fix and resubmit

## Security Considerations

- Queue directories should be readable/writable by Claude processes
- Audit log is append-only
- No sensitive data (passwords, tokens) in requests
- Request/response files cleaned up after 24h

## Changelog

- **1.0.1** (2025-12-30): Fixed heredoc quoting bugs, architecture diagram role labels, and Kitty command formatting
- **1.0.0** (2025-12-30): Initial protocol specification
