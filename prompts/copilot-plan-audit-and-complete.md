# CRITICAL: Plan Audit + Completion — Last 48 Hours

The Linux machine (omarchy-ts) is unreliable. All active plans must be audited and completed HERE.
Trust NOTHING that was "done" without `validated_at` timestamp + `validated_by` = thor\*.

## Phase 0: Setup

```bash
export PATH="$HOME/.claude/scripts:$PATH"
DB=~/.claude/data/dashboard.db
```

## Phase 1: Audit ALL plans from last 48 hours

### 1.1 List all active/done plans

```bash
sqlite3 -cmd ".timeout 5000" "$DB" "
SELECT p.id, p.name, p.status, pr.name as project,
  p.tasks_total, p.tasks_done,
  (SELECT COUNT(*) FROM tasks t WHERE t.plan_id=p.id AND t.status='done' AND t.validated_at IS NULL) as unvalidated,
  (SELECT COUNT(*) FROM tasks t WHERE t.plan_id=p.id AND t.status NOT IN ('done','skipped','cancelled')) as remaining
FROM plans p JOIN projects pr ON p.project_id=pr.id
WHERE p.created_at >= datetime('now', '-3 days')
ORDER BY p.id;
"
```

### 1.2 For each plan marked 'done', verify ACTUAL completion

For every plan with `unvalidated > 0` or `remaining > 0`:

```bash
# List suspicious tasks (done but never validated by Thor)
sqlite3 "$DB" "
SELECT t.id, t.task_id, t.title, t.status, t.validated_at, t.validated_by, t.completed_at
FROM tasks t WHERE t.plan_id = {PLAN_ID}
  AND t.status = 'done' AND t.validated_at IS NULL
ORDER BY t.id;
"
```

**For each unvalidated task**: Check if the actual work was done:

1. Read the task description: `sqlite3 "$DB" "SELECT description FROM tasks WHERE id={TASK_DB_ID};"`
2. Check if files exist and contain expected changes (grep for key patterns)
3. If work EXISTS: run `plan-db.sh validate-task {TASK_DB_ID} {PLAN_ID} thor` to mark validated
4. If work DOES NOT EXIST: report as FAKE and mark `plan-db.sh update-task {TASK_DB_ID} in_progress "Audit: work not found"`

## Phase 2: Plan 265 (MirrorBuddy — 18 done/unvalidated + 17 pending)

**CRITICAL**: All 18 "done" tasks have `validated_by='plan-db-safe-auto'` (the OLD bypass, pre-trigger).
They were done on Linux. The worktree is `~/GitHub/MirrorBuddy` (main repo).

### 2a. Verify the 18 "done" tasks

For each done task, verify the actual code changes exist in main:

```bash
# Get task details
sqlite3 "$DB" "SELECT task_id, title, notes FROM tasks WHERE plan_id=265 AND status='done' ORDER BY task_id;"
```

For each task, grep/read the files mentioned in the `notes` column to verify the work exists.

- If work EXISTS in main: retroactively validate: `plan-db.sh validate-task {DB_ID} 265 thor`
- If work DOES NOT EXIST: `plan-db.sh update-task {DB_ID} in_progress "Audit: work not found in main"`

### 2b. Complete the 17 pending tasks

````bash
plan-db.sh get-context 265

### For each pending task:

```bash
# Get next task
NEXT=$(sqlite3 "$DB" "SELECT id, task_id, title, description, test_criteria FROM tasks WHERE plan_id=265 AND status='pending' ORDER BY wave_id_fk, task_id LIMIT 1;")
echo "$NEXT"
````

Execute using the standard workflow:

1. `plan-db.sh update-task {DB_ID} in_progress "Started"`
2. cd to worktree, write tests (TDD RED)
3. Implement (TDD GREEN)
4. `plan-db-safe.sh update-task {DB_ID} done "Summary"` (sets SUBMITTED)
5. `plan-db.sh validate-task {DB_ID} 265 thor` (sets DONE)
6. Move to next task

### Wave completion after all tasks in wave:

```bash
WAVE_DB_ID=$(sqlite3 "$DB" "SELECT id FROM waves WHERE plan_id=265 AND wave_id='{WAVE}';")
plan-db.sh validate-wave $WAVE_DB_ID
```

## Phase 3: Complete Plan 266 (VirtualBPM — 3 tasks remaining)

```bash
# Check what's left
sqlite3 "$DB" "SELECT id, task_id, title, status, description FROM tasks WHERE plan_id=266 AND status NOT IN ('done','skipped','cancelled');"
```

Same workflow as Phase 2. Handle the blocked task first (check why it's blocked).

## Phase 4: Verify Plan 267 (MyConvergio — marked done)

```bash
# Quick check: any unvalidated tasks?
sqlite3 "$DB" "SELECT COUNT(*) FROM tasks WHERE plan_id=267 AND status='done' AND validated_at IS NULL;"
```

If > 0: audit each task like Phase 1.2.
If 0: plan is clean.

## Phase 5: Final verification

```bash
# All active plans should be done or have clear status
sqlite3 "$DB" "
SELECT p.id, p.name, p.status, pr.name,
  (SELECT COUNT(*) FROM tasks t WHERE t.plan_id=p.id AND t.status NOT IN ('done','skipped','cancelled')) as remaining
FROM plans p JOIN projects pr ON p.project_id=pr.id
WHERE p.status = 'doing';
"
# Expected: 0 rows (all plans completed)

# Run full test suite to verify enforcement still works
bash ~/.claude/scripts/tests/test-thor-enforcement.sh
# Expected: 53/53 PASS
```

## Rules

- NEVER skip Thor validation. Every task MUST go through submitted → done via validate-task.
- If a task was "done" without evidence: mark it in_progress and REDO it.
- TDD mandatory: tests FIRST, then implementation.
- Work in the correct worktree (NOT main).
- Max 250 lines per file. Conventional commits. English code.
- After EVERY wave: `plan-db.sh validate-wave {wave_db_id}`
- After ALL tasks done: `plan-db.sh complete {plan_id}`

## Priority order

1. Plan 266 (VirtualBPM) — only 3 tasks, quick win
2. Plan 265 (MirrorBuddy) — 17 tasks, biggest effort
3. Plan 267 audit — verify only
4. Legacy plans audit — flag but don't fix (pre-trigger era)
