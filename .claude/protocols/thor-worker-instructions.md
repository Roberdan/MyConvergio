# Thor Validation: Worker Instructions

> **Version**: 1.0.0
> **Status**: MANDATORY for ALL Claude workers
> **Last Updated**: 2025-12-30

## The Golden Rule

**You are NOT done until Thor says you are done.**

This is not optional. This is not a suggestion. If you claim a task is complete without Thor's approval, you are lying.

## Why This Exists

Because you (and all other Claudes) have a tendency to:
- Say "done" when you're not done
- Forget things and not mention it
- Skip tests "because they're obvious"
- Not read documentation
- Not update documentation
- Commit to wrong branches
- Leave debug code everywhere
- Make excuses instead of fixing

Thor exists to catch all of this before Roberto has to.

## The Validation Flow

### Step 1: Complete Your Work
Do the actual task. Run the tests. Check the linting. Make sure the build passes.

### Step 2: Gather Evidence
Before submitting to Thor, gather actual evidence:

```bash
# Get current branch
git branch --show-current

# Get git status
git status --short

# Run tests and capture output
npm test 2>&1 | tee /tmp/test-output.txt

# Run linting
npm run lint 2>&1 | tee /tmp/lint-output.txt

# Run build
npm run build 2>&1 | tee /tmp/build-output.txt
```

### Step 3: Create Validation Request

```bash
REQUEST_ID=$(uuidgen | tr '[:upper:]' '[:lower:]')
TIMESTAMP=$(date -u +%Y-%m-%dT%H:%M:%SZ)

cat > /tmp/thor-queue/requests/${REQUEST_ID}.json << EOF
{
  "request_id": "${REQUEST_ID}",
  "timestamp": "${TIMESTAMP}",
  "worker_id": "[YOUR CLAUDE ID, e.g., Claude-2]",
  "worker_title": "[YOUR CLAUDE ID]",
  "request_type": "task_validation",

  "task": {
    "reference": "[TASK ID from plan, e.g., W1-T03]",
    "original_instructions": "[COPY the exact task description from the plan]",
    "plan_file": "[PATH to the execution plan]"
  },

  "claim": {
    "summary": "[What you claim to have done]",
    "files_created": ["list", "of", "new", "files"],
    "files_modified": ["list", "of", "modified", "files"],
    "tests_added": ["list", "of", "test", "files"]
  },

  "evidence": {
    "test_command": "npm test",
    "test_output": "[ACTUAL test output - not 'tests pass']",
    "test_coverage": "[ACTUAL coverage percentage]",
    "lint_command": "npm run lint",
    "lint_output": "[ACTUAL lint output]",
    "build_command": "npm run build",
    "build_output": "[ACTUAL build output]",
    "git_branch": "[ACTUAL current branch]",
    "git_status": "[ACTUAL git status output]",
    "git_log_last": "[ACTUAL last commit message]"
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
EOF
```

### Step 4: Submit to Thor

```bash
# Notify Thor (if using Kitty)
kitty @ send-text --match title:Thor-QA "[VALIDATION REQUEST] Request ${REQUEST_ID} from [YOUR ID]" && kitty @ send-key --match title:Thor-QA Return
```

### Step 5: Wait for Response

```bash
# Poll for response
RESPONSE_FILE="/tmp/thor-queue/responses/${REQUEST_ID}.json"

while [ ! -f "${RESPONSE_FILE}" ]; do
  echo "Waiting for Thor's response..."
  sleep 10
done

# Read response
cat "${RESPONSE_FILE}"
```

### Step 6: Handle Response

#### If APPROVED ✅
```
You may now:
1. Mark the task as ✅ in the plan
2. Fill in the completion timestamp
3. Proceed to your next task
```

#### If REJECTED ❌
```
You MUST:
1. Read ALL issues listed
2. Fix EVERY issue (not just some)
3. Re-run tests, lint, build
4. Submit a NEW validation request
5. DO NOT mark task complete
6. DO NOT proceed to next task
```

#### If CHALLENGED 🔥
```
Thor doesn't trust your claim. You MUST:
1. Provide the specific evidence requested
2. Show actual output, not assurances
3. Demonstrate the claim is true
```

#### If ESCALATED 🚨
```
You have failed 3 times. You MUST:
1. STOP immediately
2. DO NOT try again
3. Wait for Roberto to intervene
4. Do not start other tasks
```

## What Thor Checks

Thor will verify:

### Task Compliance
- Did you do EXACTLY what was asked?
- Every requirement addressed?
- No creative interpretation?
- No scope creep or reduction?

### Code Quality
- Tests exist for new code?
- Tests actually pass?
- Coverage ≥80%?
- Lint clean (0 warnings)?
- Build succeeds?
- No debug code left?

### Engineering Fundamentals
- No secrets in code?
- Proper error handling?
- Input validation?
- No security vulnerabilities?
- Type safety respected?

### Repository Compliance
- CONSTITUTION.md followed?
- CLAUDE.md guidelines followed?
- Existing patterns respected?

### Documentation
- README updated if needed?
- API docs updated if needed?
- JSDoc/docstrings added?
- CHANGELOG updated?

### Git Hygiene
- On correct branch?
- Changes committed?
- Commit message follows convention?
- No secrets committed?

## Thor's Brutal Questions

Thor will ask you these questions. Have answers ready:

1. "Are you BRUTALLY sure you've done EVERYTHING?"
2. "Did you FORGET anything? Think carefully."
3. "Did you INTENTIONALLY OMIT something without mentioning it?"
4. "Did you READ all the relevant documentation?"
5. "Did you UPDATE all the documentation that needed updating?"
6. "Is the commit DONE or are you just saying you'll do it?"
7. "Are you on the RIGHT branch/worktree?"
8. "Did you actually RUN the tests or just assume they pass?"
9. "Is there ANY technical debt you're hiding?"
10. "What's the ONE thing you're hoping I won't check?"

If you hesitate or give vague answers: **REJECTED**

## Quick Reference

```
┌─────────────────────────────────────────────────────────────┐
│                    VALIDATION FLOW                          │
├─────────────────────────────────────────────────────────────┤
│                                                             │
│   1. Complete task                                          │
│   2. Run tests/lint/build                                   │
│   3. Create request JSON with ACTUAL evidence               │
│   4. Submit to /tmp/thor-queue/requests/                    │
│   5. Wait for response in /tmp/thor-queue/responses/        │
│   6. Handle response:                                       │
│      ├── APPROVED → Mark ✅, proceed                        │
│      ├── REJECTED → Fix ALL issues, resubmit               │
│      ├── CHALLENGED → Provide evidence                      │
│      └── ESCALATED → STOP, wait for Roberto                │
│                                                             │
│   ⚠️  YOU ARE NOT DONE UNTIL THOR SAYS YOU ARE DONE         │
│                                                             │
└─────────────────────────────────────────────────────────────┘
```

## Common Mistakes That Get You Rejected

1. **"Tests pass" without showing output** → REJECTED
2. **Forgetting to update documentation** → REJECTED
3. **On wrong branch** → REJECTED
4. **Changes not committed** → REJECTED
5. **Lint warnings ignored** → REJECTED
6. **Coverage below 80%** → REJECTED
7. **Not addressing all requirements** → REJECTED
8. **Debug code left in** → REJECTED
9. **Vague answers to challenge questions** → REJECTED
10. **Assuming Thor won't check something** → REJECTED (Thor checks EVERYTHING)

## Remember

Thor is not your enemy. Thor is the last line of defense before Roberto has to deal with your mistakes.

If Thor rejects you, Thor is right. Fix it.

If you think Thor is wrong, you're wrong. Fix it anyway.

**Your job is not to argue with Thor. Your job is to deliver work that passes Thor's validation.**
