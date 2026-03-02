# Task Executor - Workflow Reference

> On-demand reference. Not auto-loaded. Consult when detailed workflow needed.

## TDD Workflow Details

### Phase 3: Execute Task (TDD Workflow)

**TDD is MANDATORY for all code tasks:**

1. **RED**: Write failing tests based on `test_criteria` from plan
   - Tests MUST fail initially (proves test is valid)
   - Test covers F-xx acceptance criteria

2. **GREEN**: Implement minimum code to pass tests
   - Only enough code to make tests pass
   - No over-engineering

3. **REFACTOR**: Clean up if needed
   - Keep tests passing
   - Improve code quality

**Examples of execution:**

- If task is "Implement feature X" → RED/GREEN/REFACTOR
- If task is "Fix bug Y" → Write test that reproduces bug, fix, verify
- If task is "Document Z" → write documentation
- If task is "Run tests" → run tests, report results

### Phase 4: Test & Verify (F-xx GATE)

**F-xx verification is MANDATORY before marking task done.**

Before marking done, you MUST:

1. Test the work (run appropriate tests)
2. **Identify which F-xx this task addresses**
3. **Verify task meets ALL F-xx acceptance criteria**
4. **Document F-xx evidence** (test output, screenshots, etc.)
5. Check for side effects/breakage
6. Document any issues found

**F-xx Verification Report (Required)**:

```markdown
## F-xx VERIFICATION

| F-xx | Requirement   | Status   | Evidence       |
| ---- | ------------- | -------- | -------------- |
| F-01 | [requirement] | [x] PASS | [how verified] |

VERDICT: PASS - Ready to mark done
```

**If F-xx NOT verifiable**:

```
❌ CANNOT MARK DONE: F-xx verification failed
- F-xx: [which requirement]
- Issue: [what's missing/failing]
- Required: [what's needed to pass]

ACTION: Fix issue, re-verify, then proceed
```

## Database Operations

### Get numeric task ID (if needed)

```bash
# Use wave_id_fk (numeric FK) instead of wave_id string
DB_TASK_ID=$(sqlite3 ~/.claude/data/dashboard.db \
  "SELECT id FROM tasks WHERE wave_id_fk={db_wave_id} AND task_id='{task_id}';")
```

### Check task status

```bash
sqlite3 ~/.claude/data/dashboard.db \
  "SELECT id, task_id, title, status, started_at, completed_at FROM tasks WHERE id={db_task_id};"
```

### Update task (via plan-db.sh)

```bash
# Mark in progress
~/.claude/scripts/plan-db.sh update-task {db_task_id} in_progress "Work started"

# Mark done (ALWAYS include --tokens!)
~/.claude/scripts/plan-db.sh update-task {db_task_id} done "Work summary" --tokens 15234

# Mark blocked
~/.claude/scripts/plan-db.sh update-task {db_task_id} blocked "Blocker description"

# Mark skipped
~/.claude/scripts/plan-db.sh update-task {db_task_id} skipped "Skip reason"
```

## Error Handling

### Task Status Mismatch

If task is not in "pending" status:

```
❌ CANNOT EXECUTE: Task T1-01 is in status "{status}" (not pending)
Possible reasons:
- Already completed by another executor
- Blocked by another task
- Manually marked as skipped

ACTION: Check database state and ask for clarification
```

### Database Update Failed

If `plan-db.sh update-task` fails:

```
❌ Database update failed
- Verify plan-db.sh is in PATH
- Verify database file exists (~/.claude/data/dashboard.db)
- Check for file permission issues

ACTION: Stop execution, report error to coordinator
```

### Work Cannot Be Completed

If task cannot be completed:

```
❌ BLOCKING ISSUE: [description]
- What tried: [what was attempted]
- Why blocked: [root cause]
- Resolution: [what's needed to unblock]

ACTION: Mark as "blocked" with detailed notes, report to coordinator
```

## Full Execution Example

```bash
# Context provided by coordinator
PROJECT=claude
PLAN_ID=12
WAVE_ID=45
TASK_ID=T1-01
DB_TASK_ID=190
F_REQUIREMENT="Dashboard displays project metrics"

# Phase 1: Verify task exists
TASK=$(sqlite3 ~/.claude/data/dashboard.db \
  "SELECT id, status FROM tasks WHERE id=$DB_TASK_ID;")
# Returns: 190|pending ✓

# Phase 2: Mark started
plan-db.sh update-task $DB_TASK_ID in_progress "Beginning implementation"

# Phase 3: Execute
# [... do actual work ...]
# Implemented metrics display component
# Tested with 3 test cases
# All tests pass ✓

# Phase 4: Verify
npm run test -- metrics.spec.ts  # ✓ PASS
npm run lint                      # ✓ PASS
npm run build                     # ✓ PASS

# Phase 5: Mark complete (with token count!)
plan-db.sh update-task $DB_TASK_ID done "Metrics display implemented and tested. All acceptance criteria met." --tokens 12456

# Report
echo "Task T1-01: DONE
Work: Implemented metrics dashboard component
Tests: 3/3 passing
Tokens: 12,456 (saved to DB)
Status: Ready for next task"
```

## Token Tracking

When task completes, report:

- Tokens used
- Approximate cost
- Context windows used
- Turnaround time

Example:

```
Task Completed: T1-01
==================
Status: DONE
Work: "Implemented authentication module"
Tokens: 15,234 (input: 8,450, output: 6,784)
Time: 18 minutes
Issues: None
```

## Anti-Patterns (DON'T)

1. **Don't mark done without testing**
   - Task marked done = task is DONE
   - No "almost done" or "mostly works"

2. **Don't forget to update database**
   - Mark status changes in DB via plan-db.sh
   - Don't assume changes sync automatically

3. **Don't leave notes empty**
   - Always include summary when marking done
   - Helps coordinator understand what was done

4. **Don't execute if task is already done**
   - Check database status first
   - If already done, report and skip

5. **Don't invent acceptance criteria**
   - Task has F-xx requirements
   - Test against those, not your own standards

## Success Criteria

Task executor execution is successful when:

1. ✓ Task status changed from pending → in_progress → done
2. ✓ Timestamps (started_at, completed_at) set in database
3. ✓ Work is completed per F-xx requirements
4. ✓ Tests pass (or documented skip reason)
5. ✓ Summary notes added to task
6. ✓ No blockers remain
7. ✓ Database state is consistent
