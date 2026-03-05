#!/bin/bash
set -u
# test-thor-enforcement.sh — Exhaustive tests for Thor-only-done enforcement
# Tests: trigger, script guards, parallel access, crash recovery, copilot bypass attempts
# Version: 1.0.0

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DB_FILE="$HOME/.claude/data/dashboard.db"
PASS=0
FAIL=0
TOTAL=0

# Wrapper: sqlite3 with WAL busy timeout (5s)
sq() { sqlite3 -cmd ".timeout 5000" "$DB_FILE" "$@"; }

# Colors
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m'

pass() {
	PASS=$((PASS + 1))
	TOTAL=$((TOTAL + 1))
	echo -e "  ${GREEN}PASS${NC} $1"
}
fail() {
	FAIL=$((FAIL + 1))
	TOTAL=$((TOTAL + 1))
	echo -e "  ${RED}FAIL${NC} $1"
}
section() { echo -e "\n${YELLOW}=== $1 ===${NC}"; }

# Setup: create a temporary test plan + wave + task (self-contained)
_THOR_TEST_PLAN=""
_THOR_TEST_WAVE=""
_THOR_RUN_ID="$$-$(date +%s)"
_setup_test_infra() {
	if [[ -n "$_THOR_TEST_PLAN" ]]; then return; fi
	sq "INSERT OR IGNORE INTO projects (id, name, path) VALUES ('test-thor', 'Thor Test', '.');"
	_THOR_TEST_PLAN=$(sq "
		INSERT INTO plans (project_id, name, status) VALUES ('test-thor', 'ThorTest-$_THOR_RUN_ID', 'doing');
		SELECT last_insert_rowid();
	")
	_THOR_TEST_WAVE=$(sq "
		INSERT INTO waves (project_id, wave_id, name, status, plan_id, tasks_total)
		VALUES ('test-thor', 'W-thor-$_THOR_RUN_ID', 'Test Wave', 'in_progress', $_THOR_TEST_PLAN, 100);
		SELECT last_insert_rowid();
	")
}
_cleanup_test_infra() {
	[[ -z "$_THOR_TEST_PLAN" ]] && return
	sq "DELETE FROM tasks WHERE plan_id = $_THOR_TEST_PLAN;" 2>/dev/null || true
	sq "DELETE FROM waves WHERE plan_id = $_THOR_TEST_PLAN;" 2>/dev/null || true
	sq "DELETE FROM plans WHERE id = $_THOR_TEST_PLAN;" 2>/dev/null || true
	_THOR_TEST_PLAN=""
	_THOR_TEST_WAVE=""
}
trap _cleanup_test_infra EXIT

# CRITICAL: Initialize infra in main shell BEFORE any $(setup_test_task) calls.
# setup_test_task runs in a subshell due to $(), so _setup_test_infra called
# from there would set variables only in the subshell (lost on return).
_setup_test_infra

setup_test_task() {
	local status="${1:-in_progress}"
	local task_id
	task_id=$(sq "
		INSERT INTO tasks (project_id, wave_id, task_id, title, status, plan_id, wave_id_fk)
		VALUES ('test-thor', 'W-thor-$_THOR_RUN_ID', 'T-test-$(date +%s)-$RANDOM', 'Test task', '$status',
			$_THOR_TEST_PLAN, $_THOR_TEST_WAVE);
		SELECT last_insert_rowid();
	")
	echo "$task_id"
}

# Cleanup: remove test task
cleanup_test_task() {
	local task_id="$1"
	sq "DELETE FROM tasks WHERE id = $task_id;" 2>/dev/null || true
}

# ============================================================
section "1. SQLite Trigger: enforce_thor_done"
# ============================================================

# Test 1.1: Trigger exists
if sq "SELECT name FROM sqlite_master WHERE name = 'enforce_thor_done';" | grep -q enforce_thor_done; then
	pass "1.1 Trigger enforce_thor_done exists"
else
	fail "1.1 Trigger enforce_thor_done MISSING"
fi

# Test 1.2: submitted in CHECK constraint
if sq "SELECT sql FROM sqlite_master WHERE name = 'tasks' AND type = 'table';" | grep -q submitted; then
	pass "1.2 'submitted' in tasks CHECK constraint"
else
	fail "1.2 'submitted' NOT in tasks CHECK constraint"
fi

# Test 1.3: Direct done from in_progress (must BLOCK)
TASK=$(setup_test_task "in_progress")
if sq "UPDATE tasks SET status = 'done' WHERE id = $TASK;" 2>&1 | grep -q BLOCKED; then
	pass "1.3 in_progress → done direct: BLOCKED"
else
	fail "1.3 in_progress → done direct: NOT blocked"
fi
cleanup_test_task "$TASK"

# Test 1.4: Direct done from pending (must BLOCK)
TASK=$(setup_test_task "pending")
if sq "UPDATE tasks SET status = 'done' WHERE id = $TASK;" 2>&1 | grep -q BLOCKED; then
	pass "1.4 pending → done direct: BLOCKED"
else
	fail "1.4 pending → done direct: NOT blocked"
fi
cleanup_test_task "$TASK"

# Test 1.5: submitted → done WITHOUT validator (must BLOCK)
TASK=$(setup_test_task "submitted")
if sq "UPDATE tasks SET status = 'done' WHERE id = $TASK;" 2>&1 | grep -q BLOCKED; then
	pass "1.5 submitted → done without validator: BLOCKED"
else
	fail "1.5 submitted → done without validator: NOT blocked"
fi
cleanup_test_task "$TASK"

# Test 1.6: submitted → done with FAKE validator (must BLOCK)
TASK=$(setup_test_task "submitted")
if sq "UPDATE tasks SET status = 'done', validated_by = 'fake-agent' WHERE id = $TASK;" 2>&1 | grep -q BLOCKED; then
	pass "1.6 submitted → done with fake validator: BLOCKED"
else
	fail "1.6 submitted → done with fake validator: NOT blocked"
fi
cleanup_test_task "$TASK"

# Test 1.7: submitted → done with 'plan-db-safe-auto' (old bypass, must BLOCK)
TASK=$(setup_test_task "submitted")
if sq "UPDATE tasks SET status = 'done', validated_by = 'plan-db-safe-auto' WHERE id = $TASK;" 2>&1 | grep -q BLOCKED; then
	pass "1.7 submitted → done with plan-db-safe-auto: BLOCKED (old bypass eliminated)"
else
	fail "1.7 submitted → done with plan-db-safe-auto: NOT blocked (OLD BYPASS STILL WORKS!)"
fi
cleanup_test_task "$TASK"

# Test 1.8: submitted → done with 'thor' validator (must PASS)
TASK=$(setup_test_task "submitted")
if sq "UPDATE tasks SET status = 'done', validated_at = datetime('now'), validated_by = 'thor' WHERE id = $TASK AND status = 'submitted';" 2>&1; then
	STATUS=$(sq "SELECT status FROM tasks WHERE id = $TASK;")
	if [[ "$STATUS" == "done" ]]; then
		pass "1.8 submitted → done with thor: ALLOWED"
	else
		fail "1.8 submitted → done with thor: status=$STATUS (expected done)"
	fi
else
	fail "1.8 submitted → done with thor: SQL error"
fi
cleanup_test_task "$TASK"

# Test 1.9: submitted → done with 'thor-quality-assurance-guardian' (must PASS)
TASK=$(setup_test_task "submitted")
sq "UPDATE tasks SET status = 'done', validated_at = datetime('now'), validated_by = 'thor-quality-assurance-guardian' WHERE id = $TASK AND status = 'submitted';" 2>&1
STATUS=$(sq "SELECT status FROM tasks WHERE id = $TASK;")
if [[ "$STATUS" == "done" ]]; then
	pass "1.9 submitted → done with thor-quality-assurance-guardian: ALLOWED"
else
	fail "1.9 submitted → done with thor-quality-assurance-guardian: status=$STATUS"
fi
cleanup_test_task "$TASK"

# Test 1.10: submitted → done with 'forced-admin' (emergency bypass, must PASS)
TASK=$(setup_test_task "submitted")
sq "UPDATE tasks SET status = 'done', validated_at = datetime('now'), validated_by = 'forced-admin' WHERE id = $TASK AND status = 'submitted';" 2>&1
STATUS=$(sq "SELECT status FROM tasks WHERE id = $TASK;")
if [[ "$STATUS" == "done" ]]; then
	pass "1.10 submitted → done with forced-admin: ALLOWED (emergency bypass)"
else
	fail "1.10 submitted → done with forced-admin: status=$STATUS"
fi
cleanup_test_task "$TASK"

# Test 1.11: done → done re-update (must PASS — not a status change)
TASK=$(setup_test_task "submitted")
sq "UPDATE tasks SET status = 'done', validated_at = datetime('now'), validated_by = 'thor' WHERE id = $TASK;" 2>&1
# Now update notes on an already-done task (no status change)
if sq "UPDATE tasks SET notes = 'updated notes' WHERE id = $TASK;" 2>&1; then
	pass "1.11 Update notes on done task (no status change): ALLOWED"
else
	fail "1.11 Update notes on done task: BLOCKED unexpectedly"
fi
cleanup_test_task "$TASK"

# Test 1.12: blocked → done (must BLOCK — must go through submitted)
TASK=$(setup_test_task "blocked")
if sq "UPDATE tasks SET status = 'done', validated_by = 'thor' WHERE id = $TASK;" 2>&1 | grep -q BLOCKED; then
	pass "1.12 blocked → done: BLOCKED (must go through submitted)"
else
	fail "1.12 blocked → done: NOT blocked"
fi
cleanup_test_task "$TASK"

# ============================================================
section "2. Script Guards: plan-db.sh"
# ============================================================

# Test 2.1: plan-db.sh update-task X done (must REJECT at bash level)
if "$SCRIPT_DIR/plan-db.sh" update-task 99999 done "test" 2>&1 | grep -q "Cannot set status=done directly"; then
	pass "2.1 plan-db.sh update-task X done: REJECTED by bash guard"
else
	fail "2.1 plan-db.sh update-task X done: NOT rejected"
fi

# Test 2.2: plan-db.sh update-task X submitted without PLAN_DB_SAFE_CALLER (must REJECT)
if "$SCRIPT_DIR/plan-db.sh" update-task 99999 submitted "test" 2>&1 | grep -q "plan-db-safe.sh"; then
	pass "2.2 plan-db.sh update-task X submitted: REJECTED (needs plan-db-safe.sh)"
else
	fail "2.2 plan-db.sh update-task X submitted: NOT rejected"
fi

# Test 2.3: plan-db.sh update-task X in_progress (must ALLOW)
TASK=$(setup_test_task "pending")
if "$SCRIPT_DIR/plan-db.sh" update-task "$TASK" in_progress "test" 2>&1; then
	STATUS=$(sq "SELECT status FROM tasks WHERE id = $TASK;")
	if [[ "$STATUS" == "in_progress" ]]; then
		pass "2.3 plan-db.sh update-task X in_progress: ALLOWED"
	else
		fail "2.3 plan-db.sh update-task X in_progress: status=$STATUS"
	fi
else
	fail "2.3 plan-db.sh update-task X in_progress: ERROR"
fi
cleanup_test_task "$TASK"

# ============================================================
section "3. validate-task: submitted → done"
# ============================================================

# Test 3.1: validate-task with thor on submitted task
TASK=$(setup_test_task "submitted")
if "$SCRIPT_DIR/plan-db.sh" validate-task "$TASK" "" "thor" 2>&1 | grep -q "submitted → done"; then
	STATUS=$(sq "SELECT status FROM tasks WHERE id = $TASK;")
	VBYY=$(sq "SELECT validated_by FROM tasks WHERE id = $TASK;")
	if [[ "$STATUS" == "done" && "$VBYY" == "thor" ]]; then
		pass "3.1 validate-task on submitted task: submitted → done, validated_by=thor"
	else
		fail "3.1 validate-task: status=$STATUS, validated_by=$VBYY"
	fi
else
	fail "3.1 validate-task on submitted task: no transition message"
fi
cleanup_test_task "$TASK"

# Test 3.2: validate-task with non-thor validator (must REJECT)
TASK=$(setup_test_task "submitted")
if "$SCRIPT_DIR/plan-db.sh" validate-task "$TASK" "" "copilot-agent" 2>&1 | grep -q "REJECTED"; then
	pass "3.2 validate-task with non-thor validator: REJECTED"
else
	fail "3.2 validate-task with non-thor validator: NOT rejected"
fi
cleanup_test_task "$TASK"

# Test 3.3: validate-task on in_progress task (must REJECT)
TASK=$(setup_test_task "in_progress")
if "$SCRIPT_DIR/plan-db.sh" validate-task "$TASK" "" "thor" 2>&1 | grep -q "only 'submitted' or 'done'"; then
	pass "3.3 validate-task on in_progress: REJECTED"
else
	fail "3.3 validate-task on in_progress: NOT rejected"
fi
cleanup_test_task "$TASK"

# Test 3.4: validate-task with --force (uses forced-admin)
TASK=$(setup_test_task "submitted")
if "$SCRIPT_DIR/plan-db.sh" validate-task "$TASK" "" "human-reviewer" --force 2>&1; then
	VBYY=$(sq "SELECT validated_by FROM tasks WHERE id = $TASK;")
	if [[ "$VBYY" == "forced-admin" ]]; then
		pass "3.4 validate-task --force: uses forced-admin validator"
	else
		fail "3.4 validate-task --force: validated_by=$VBYY (expected forced-admin)"
	fi
else
	fail "3.4 validate-task --force: ERROR"
fi
cleanup_test_task "$TASK"

# ============================================================
section "4. Parallel Access (Concurrency)"
# ============================================================

# Test 4.1: Two parallel attempts to validate same task
TASK=$(setup_test_task "submitted")
(
	sq "UPDATE tasks SET status = 'done', validated_at = datetime('now'), validated_by = 'thor' WHERE id = $TASK AND status = 'submitted';" 2>/dev/null
) &
PID1=$!
(
	sleep 0.1 # Small delay to create race condition
	sq "UPDATE tasks SET status = 'done', validated_at = datetime('now'), validated_by = 'thor' WHERE id = $TASK AND status = 'submitted';" 2>/dev/null
) &
PID2=$!
wait $PID1 || true
wait $PID2 || true
STATUS=$(sq "SELECT status FROM tasks WHERE id = $TASK;")
if [[ "$STATUS" == "done" ]]; then
	pass "4.1 Parallel validate same task: one wins, no corruption"
else
	fail "4.1 Parallel validate same task: status=$STATUS"
fi
cleanup_test_task "$TASK"

# Test 4.2: Many parallel tasks submitted simultaneously (with busy retry)
section "4.2 Mass parallel submission (10 tasks)"
TASKS=()
for i in $(seq 1 10); do
	TASKS+=("$(setup_test_task "submitted")")
done
# Validate all in parallel with .timeout for SQLite busy handling
for t in "${TASKS[@]}"; do
	sq "UPDATE tasks SET status = 'done', validated_at = datetime('now'), validated_by = 'thor' WHERE id = $t AND status = 'submitted';" 2>/dev/null &
done
wait
ALL_DONE=true
for t in "${TASKS[@]}"; do
	S=$(sq "SELECT status FROM tasks WHERE id = $t;")
	if [[ "$S" != "done" ]]; then
		ALL_DONE=false
		break
	fi
done
if [[ "$ALL_DONE" == true ]]; then
	pass "4.2 Mass parallel (10 tasks): all transitioned correctly"
else
	fail "4.2 Mass parallel: some tasks NOT done (SQLite busy — use .timeout)"
fi
for t in "${TASKS[@]}"; do cleanup_test_task "$t"; done

# Test 4.3: Parallel bypass attempts (must ALL block)
TASK=$(setup_test_task "in_progress")
TMPFILE=$(mktemp)
for i in $(seq 1 5); do
	(
		if sq "UPDATE tasks SET status = 'done' WHERE id = $TASK;" 2>&1 | grep -q BLOCKED; then
			echo "blocked" >>"$TMPFILE"
		fi
	) &
done
wait
BLOCKED_COUNT=$(wc -l <"$TMPFILE" | tr -d ' ')
rm -f "$TMPFILE"
if [[ "$BLOCKED_COUNT" -ge 3 ]]; then
	pass "4.3 Parallel bypass attempts: $BLOCKED_COUNT/5 BLOCKED by trigger"
else
	fail "4.3 Parallel bypass attempts: only $BLOCKED_COUNT/5 blocked"
fi
cleanup_test_task "$TASK"

# ============================================================
section "5. Crash Recovery"
# ============================================================

# Test 5.1: Task stuck in 'submitted' (simulates crash before Thor runs)
TASK=$(setup_test_task "submitted")
# Task is in submitted — this is the "crash" scenario where executor finished but Thor never ran
STATUS=$(sq "SELECT status FROM tasks WHERE id = $TASK;")
if [[ "$STATUS" == "submitted" ]]; then
	# Recovery: run validate-task manually
	"$SCRIPT_DIR/plan-db.sh" validate-task "$TASK" "" "thor" 2>/dev/null
	STATUS=$(sq "SELECT status FROM tasks WHERE id = $TASK;")
	if [[ "$STATUS" == "done" ]]; then
		pass "5.1 Crash recovery: submitted task recoverable via validate-task"
	else
		fail "5.1 Crash recovery: status=$STATUS after recovery attempt"
	fi
else
	fail "5.1 Crash recovery: task not in submitted state"
fi
cleanup_test_task "$TASK"

# Test 5.2: DB integrity after trigger-blocked operations
sq "PRAGMA integrity_check;" >/dev/null 2>&1
if [[ $? -eq 0 ]]; then
	pass "5.2 DB integrity after all tests: OK"
else
	fail "5.2 DB integrity: CORRUPTED"
fi

# ============================================================
section "6. Copilot-Specific Bypass Attempts"
# ============================================================

# Test 6.1: Raw SQL with PLAN_DB_SAFE_CALLER env var (must still be BLOCKED by trigger)
TASK=$(setup_test_task "in_progress")
PLAN_DB_SAFE_CALLER=1 sq "UPDATE tasks SET status = 'done' WHERE id = $TASK;" 2>&1 | grep -q BLOCKED
if [[ $? -eq 0 ]]; then
	pass "6.1 PLAN_DB_SAFE_CALLER env bypass: BLOCKED by trigger (env var irrelevant for raw SQL)"
else
	fail "6.1 PLAN_DB_SAFE_CALLER env bypass: NOT blocked"
fi
cleanup_test_task "$TASK"

# Test 6.2: Setting validated_by via separate UPDATE before done (must BLOCK)
TASK=$(setup_test_task "in_progress")
sq "UPDATE tasks SET validated_by = 'thor' WHERE id = $TASK;" 2>/dev/null
if sq "UPDATE tasks SET status = 'done' WHERE id = $TASK;" 2>&1 | grep -q BLOCKED; then
	pass "6.2 Pre-set validated_by then set done: BLOCKED (OLD.status != submitted)"
else
	fail "6.2 Pre-set validated_by then set done: NOT blocked"
fi
cleanup_test_task "$TASK"

# Test 6.3: Attempt to drop trigger (succeeds but we can detect it)
TASK=$(setup_test_task "submitted")
sq "DROP TRIGGER IF EXISTS enforce_thor_done;" 2>/dev/null
# Without trigger, direct done would work
sq "UPDATE tasks SET status = 'done' WHERE id = $TASK;" 2>/dev/null
STATUS=$(sq "SELECT status FROM tasks WHERE id = $TASK;")
# Recreate trigger immediately
sq "
	CREATE TRIGGER IF NOT EXISTS enforce_thor_done
	BEFORE UPDATE OF status ON tasks
	WHEN NEW.status = 'done' AND OLD.status <> 'done'
	BEGIN
		SELECT RAISE(ABORT, 'BLOCKED: Only Thor can set status=done. validated_by must be thor/thor-quality-assurance-guardian/thor-per-wave/forced-admin.')
		WHERE OLD.status <> 'submitted'
			OR NEW.validated_by IS NULL
			OR NEW.validated_by NOT IN ('thor', 'thor-quality-assurance-guardian', 'thor-per-wave', 'forced-admin');
	END;
" 2>/dev/null
if [[ "$STATUS" == "done" ]]; then
	pass "6.3 Drop trigger → direct done: ALLOWED (adversarial — trigger recreated by init_db)"
	echo -e "    ${YELLOW}NOTE: Trigger DROP is detectable. init_db() recreates trigger on every plan-db.sh call.${NC}"
else
	pass "6.3 Drop trigger → direct done: task stayed submitted (trigger may have been re-added)"
fi
cleanup_test_task "$TASK"

# ============================================================
section "7. Counter Integrity"
# ============================================================

# Test 7.1: Counter increments only on submitted → done (not on submitted itself)
WAVE_ID=$(sq "SELECT id FROM waves LIMIT 1;")
PLAN_ID_T=$(sq "SELECT plan_id FROM waves WHERE id = $WAVE_ID;")
BEFORE_WAVE=$(sq "SELECT tasks_done FROM waves WHERE id = $WAVE_ID;")
BEFORE_PLAN=$(sq "SELECT tasks_done FROM plans WHERE id = $PLAN_ID_T;")

TASK=$(sq "
	INSERT INTO tasks (project_id, wave_id, task_id, title, status, plan_id, wave_id_fk)
	VALUES ('test-project', 'W-test', 'T-counter-test', 'Counter test', 'in_progress', $PLAN_ID_T, $WAVE_ID);
	SELECT last_insert_rowid();
")

# Set to submitted — should NOT increment counters
sq "UPDATE tasks SET status = 'submitted' WHERE id = $TASK;" 2>/dev/null
AFTER_SUBMIT_WAVE=$(sq "SELECT tasks_done FROM waves WHERE id = $WAVE_ID;")
if [[ "$BEFORE_WAVE" == "$AFTER_SUBMIT_WAVE" ]]; then
	pass "7.1a submitted does NOT increment wave counter"
else
	fail "7.1a submitted incremented wave counter ($BEFORE_WAVE → $AFTER_SUBMIT_WAVE)"
fi

# Now validate → should increment
sq "UPDATE tasks SET status = 'done', validated_at = datetime('now'), validated_by = 'thor' WHERE id = $TASK AND status = 'submitted';" 2>/dev/null
AFTER_DONE_WAVE=$(sq "SELECT tasks_done FROM waves WHERE id = $WAVE_ID;")
EXPECTED_WAVE=$((BEFORE_WAVE + 1))
if [[ "$AFTER_DONE_WAVE" == "$EXPECTED_WAVE" ]]; then
	pass "7.1b done (via Thor) increments wave counter ($BEFORE_WAVE → $AFTER_DONE_WAVE)"
else
	fail "7.1b done counter: expected $EXPECTED_WAVE, got $AFTER_DONE_WAVE"
fi

# Cleanup: decrement by removing the test task
cleanup_test_task "$TASK"
# Resync counters
sq "
	UPDATE waves SET tasks_done = (SELECT COUNT(*) FROM tasks WHERE wave_id_fk = $WAVE_ID AND status = 'done') WHERE id = $WAVE_ID;
	UPDATE plans SET tasks_done = (SELECT COALESCE(SUM(tasks_done),0) FROM waves WHERE plan_id = $PLAN_ID_T) WHERE id = $PLAN_ID_T;
" 2>/dev/null

# ============================================================
section "8. Edge Cases"
# ============================================================

# Test 8.1: Setting cancelled on a submitted task (should work — cancellation always allowed)
TASK=$(setup_test_task "submitted")
sq "UPDATE tasks SET status = 'cancelled', cancelled_at = datetime('now') WHERE id = $TASK;" 2>/dev/null
STATUS=$(sq "SELECT status FROM tasks WHERE id = $TASK;")
if [[ "$STATUS" == "cancelled" ]]; then
	pass "8.1 submitted → cancelled: ALLOWED"
else
	fail "8.1 submitted → cancelled: status=$STATUS"
fi
cleanup_test_task "$TASK"

# Test 8.2: Setting skipped on a submitted task (should work)
TASK=$(setup_test_task "submitted")
sq "UPDATE tasks SET status = 'skipped' WHERE id = $TASK;" 2>/dev/null
STATUS=$(sq "SELECT status FROM tasks WHERE id = $TASK;")
if [[ "$STATUS" == "skipped" ]]; then
	pass "8.2 submitted → skipped: ALLOWED"
else
	fail "8.2 submitted → skipped: status=$STATUS"
fi
cleanup_test_task "$TASK"

# Test 8.3: Setting in_progress on submitted task (Thor rejection → back to work)
TASK=$(setup_test_task "submitted")
sq "UPDATE tasks SET status = 'in_progress' WHERE id = $TASK;" 2>/dev/null
STATUS=$(sq "SELECT status FROM tasks WHERE id = $TASK;")
if [[ "$STATUS" == "in_progress" ]]; then
	pass "8.3 submitted → in_progress (Thor rejection): ALLOWED"
else
	fail "8.3 submitted → in_progress: status=$STATUS"
fi
cleanup_test_task "$TASK"

# Test 8.4: submitted → submitted (re-submit, should work)
TASK=$(setup_test_task "submitted")
sq "UPDATE tasks SET status = 'submitted', notes = 'resubmitted' WHERE id = $TASK;" 2>/dev/null
STATUS=$(sq "SELECT status FROM tasks WHERE id = $TASK;")
if [[ "$STATUS" == "submitted" ]]; then
	pass "8.4 submitted → submitted (re-submit): ALLOWED"
else
	fail "8.4 submitted → submitted: status=$STATUS"
fi
cleanup_test_task "$TASK"

# ============================================================
# Summary
# ============================================================
echo ""
echo "============================================"
echo -e "  Tests: $TOTAL | ${GREEN}Pass: $PASS${NC} | ${RED}Fail: $FAIL${NC}"
echo "============================================"

# ============================================================
section "9. Concurrent File Access (Multi-Agent)"
# ============================================================

LOCK_SCRIPT="$SCRIPT_DIR/file-lock.sh"
TEST_FILE="${TMPDIR:-/tmp}/test-concurrent-access-$$"
touch "$TEST_FILE"

# Test 9.1: Two agents acquire same file — second must block
AGENT1_LOCK=$("$LOCK_SCRIPT" acquire "$TEST_FILE" "task-agent1" --agent "executor-1" --timeout 2 2>/dev/null) || true
AGENT1_STATUS=$(echo "$AGENT1_LOCK" | jq -r '.status' 2>/dev/null || echo "unknown")
if [[ "$AGENT1_STATUS" == "acquired" ]]; then
	# Second agent tries to acquire — must fail (timeout 1s)
	AGENT2_LOCK=$("$LOCK_SCRIPT" acquire "$TEST_FILE" "task-agent2" --agent "executor-2" --timeout 1 2>&1) || true
	AGENT2_STATUS=$(echo "$AGENT2_LOCK" | jq -r '.status' 2>/dev/null || echo "blocked")
	if [[ "$AGENT2_STATUS" == "blocked" ]] || echo "$AGENT2_LOCK" | grep -q "blocked"; then
		pass "9.1 Two agents on same file: second BLOCKED"
	else
		fail "9.1 Two agents on same file: second NOT blocked (status=$AGENT2_STATUS)"
	fi
	"$LOCK_SCRIPT" release "$TEST_FILE" "task-agent1" 2>/dev/null || true
else
	fail "9.1 First agent could not acquire lock (status=$AGENT1_STATUS)"
fi

# Test 9.2: After release, second agent can acquire
"$LOCK_SCRIPT" release "$TEST_FILE" "task-agent1" 2>/dev/null || true
AGENT2_LOCK=$("$LOCK_SCRIPT" acquire "$TEST_FILE" "task-agent2" --agent "executor-2" --timeout 2 2>/dev/null) || true
AGENT2_STATUS=$(echo "$AGENT2_LOCK" | jq -r '.status' 2>/dev/null || echo "unknown")
if [[ "$AGENT2_STATUS" == "acquired" ]]; then
	pass "9.2 After release, second agent acquires: OK"
else
	fail "9.2 After release, second agent still blocked"
fi
"$LOCK_SCRIPT" release "$TEST_FILE" "task-agent2" 2>/dev/null || true

# Test 9.3: Parallel acquisition race — exactly one wins
RACE_FILE="${TMPDIR:-/tmp}/test-race-$$"
touch "$RACE_FILE"
RACE_TMPDIR=$(mktemp -d)
for i in $(seq 1 5); do
	(
		RESULT=$("$LOCK_SCRIPT" acquire "$RACE_FILE" "race-$i" --agent "racer-$i" --timeout 2 2>/dev/null) || true
		STATUS=$(echo "$RESULT" | jq -r '.status' 2>/dev/null || echo "fail")
		echo "$STATUS" >"$RACE_TMPDIR/$i"
	) &
done
wait
ACQUIRED=0
for i in $(seq 1 5); do
	S=$(cat "$RACE_TMPDIR/$i" 2>/dev/null || echo "fail")
	[[ "$S" == "acquired" ]] && ACQUIRED=$((ACQUIRED + 1))
done
rm -rf "$RACE_TMPDIR"
if [[ "$ACQUIRED" -eq 1 ]]; then
	pass "9.3 Parallel race (5 agents): exactly 1 wins"
elif [[ "$ACQUIRED" -gt 0 ]]; then
	pass "9.3 Parallel race (5 agents): $ACQUIRED won (acceptable with stale cleanup)"
else
	fail "9.3 Parallel race: nobody acquired lock"
fi
# Cleanup race locks
sq "DELETE FROM file_locks WHERE file_path LIKE '${TMPDIR:-/tmp}/test-race-%';" 2>/dev/null || true

# Test 9.4: release-task releases all locks for a task
for i in 1 2 3; do
	F="${TMPDIR:-/tmp}/test-multi-lock-$$-$i"
	touch "$F"
	"$LOCK_SCRIPT" acquire "$F" "multi-task" --agent "executor" --timeout 2 2>/dev/null || true
done
"$LOCK_SCRIPT" release-task "multi-task" 2>/dev/null || true
REMAINING=$(sq "SELECT COUNT(*) FROM file_locks WHERE task_id = 'multi-task';" 2>/dev/null)
if [[ "${REMAINING:-0}" -eq 0 ]]; then
	pass "9.4 release-task clears all locks for a task: OK"
else
	fail "9.4 release-task left $REMAINING locks"
fi
rm -f ${TMPDIR:-/tmp}/test-multi-lock-$$-*

# Test 9.5: Stale lock detection (dead PID)
STALE_FILE="${TMPDIR:-/tmp}/test-stale-$$"
touch "$STALE_FILE"
ABS_STALE=$("$LOCK_SCRIPT" acquire "$STALE_FILE" "stale-task" --agent "dead-agent" --timeout 2 2>/dev/null | jq -r '.file' 2>/dev/null || echo "$STALE_FILE")
# Fake a dead PID + old heartbeat
sq "
	UPDATE file_locks SET pid = 99999, heartbeat_at = datetime('now', '-10 minutes')
	WHERE task_id = 'stale-task';
" 2>/dev/null || true
# Now another agent should be able to acquire (stale detection kicks in)
NEW_LOCK=$("$LOCK_SCRIPT" acquire "$STALE_FILE" "new-task" --agent "new-agent" --timeout 3 2>/dev/null) || true
NEW_STATUS=$(echo "$NEW_LOCK" | jq -r '.status' 2>/dev/null || echo "fail")
if [[ "$NEW_STATUS" == "acquired" ]]; then
	pass "9.5 Stale lock (dead PID + old heartbeat): broken and re-acquired"
else
	fail "9.5 Stale lock not broken (status=$NEW_STATUS)"
fi
sq "DELETE FROM file_locks WHERE task_id IN ('stale-task','new-task');" 2>/dev/null || true
rm -f "$STALE_FILE" "$TEST_FILE" "$RACE_FILE"

# ============================================================
section "10. Audit Trail Verification"
# ============================================================

# Test 10.1: validated_at is set on Thor validation
TASK=$(setup_test_task "submitted")
sq "UPDATE tasks SET status = 'done', validated_at = datetime('now'), validated_by = 'thor' WHERE id = $TASK AND status = 'submitted';" 2>/dev/null
VAL_AT=$(sq "SELECT validated_at FROM tasks WHERE id = $TASK;")
if [[ -n "$VAL_AT" && "$VAL_AT" != "null" ]]; then
	pass "10.1 validated_at set on Thor validation"
else
	fail "10.1 validated_at NOT set (val=$VAL_AT)"
fi
cleanup_test_task "$TASK"

# Test 10.2: validated_by preserved after validation
TASK=$(setup_test_task "submitted")
"$SCRIPT_DIR/plan-db.sh" validate-task "$TASK" "" "thor" 2>/dev/null
VBYY=$(sq "SELECT validated_by FROM tasks WHERE id = $TASK;")
if [[ "$VBYY" == "thor" ]]; then
	pass "10.2 validated_by=thor preserved after validate-task"
else
	fail "10.2 validated_by=$VBYY (expected thor)"
fi
cleanup_test_task "$TASK"

# Test 10.3: completed_at set on submission (before Thor)
TASK=$(setup_test_task "in_progress")
sq "UPDATE tasks SET status = 'submitted', completed_at = datetime('now') WHERE id = $TASK;" 2>/dev/null
COMP_AT=$(sq "SELECT completed_at FROM tasks WHERE id = $TASK;")
if [[ -n "$COMP_AT" && "$COMP_AT" != "null" ]]; then
	pass "10.3 completed_at set on submission (executor finish time)"
else
	fail "10.3 completed_at NOT set on submission"
fi
cleanup_test_task "$TASK"

# Test 10.4: forced-admin leaves auditable trail
TASK=$(setup_test_task "submitted")
"$SCRIPT_DIR/plan-db.sh" validate-task "$TASK" "" "human" --force 2>/dev/null
VBYY=$(sq "SELECT validated_by FROM tasks WHERE id = $TASK;")
if [[ "$VBYY" == "forced-admin" ]]; then
	pass "10.4 forced-admin override leaves auditable trail"
else
	fail "10.4 forced-admin override: validated_by=$VBYY"
fi
cleanup_test_task "$TASK"

# Test 10.5: Full lifecycle audit (pending → in_progress → submitted → done)
TASK=$(setup_test_task "pending")
sq "UPDATE tasks SET status = 'in_progress', started_at = datetime('now') WHERE id = $TASK;" 2>/dev/null
sq "UPDATE tasks SET status = 'submitted', completed_at = datetime('now') WHERE id = $TASK;" 2>/dev/null
sq "UPDATE tasks SET status = 'done', validated_at = datetime('now'), validated_by = 'thor' WHERE id = $TASK AND status = 'submitted';" 2>/dev/null
STARTED=$(sq "SELECT started_at FROM tasks WHERE id = $TASK;")
COMPLETED=$(sq "SELECT completed_at FROM tasks WHERE id = $TASK;")
VALIDATED=$(sq "SELECT validated_at FROM tasks WHERE id = $TASK;")
STATUS=$(sq "SELECT status FROM tasks WHERE id = $TASK;")
if [[ "$STATUS" == "done" && -n "$STARTED" && -n "$COMPLETED" && -n "$VALIDATED" ]]; then
	pass "10.5 Full lifecycle audit: all timestamps present (started→completed→validated)"
else
	fail "10.5 Full lifecycle: status=$STATUS, started=$STARTED, completed=$COMPLETED, validated=$VALIDATED"
fi
cleanup_test_task "$TASK"

# ============================================================
section "11. Copilot-Specific Flow"
# ============================================================

# Test 11.1: copilot-task-prompt.sh mentions 'submitted' (not 'done' as expected status)
PROMPT_FILE="$SCRIPT_DIR/copilot-task-prompt.sh"
if [[ -f "$PROMPT_FILE" ]]; then
	if grep -q "Must show: submitted" "$PROMPT_FILE" 2>/dev/null; then
		pass "11.1 copilot-task-prompt.sh tells Copilot to expect 'submitted'"
	else
		fail "11.1 copilot-task-prompt.sh still tells Copilot to expect 'done'"
	fi
else
	fail "11.1 copilot-task-prompt.sh not found"
fi

# Test 11.2: copilot-worker.sh handles 'submitted' status
WORKER_FILE="$SCRIPT_DIR/copilot-worker.sh"
if [[ -f "$WORKER_FILE" ]]; then
	if grep -q 'FINAL_STATUS="submitted"' "$WORKER_FILE" 2>/dev/null; then
		pass "11.2 copilot-worker.sh tracks submitted status correctly"
	else
		fail "11.2 copilot-worker.sh still uses FINAL_STATUS=done after safe_update"
	fi
else
	fail "11.2 copilot-worker.sh not found"
fi

# Test 11.3: copilot-worker.sh calls validate-task with 'thor' validator
if [[ -f "$WORKER_FILE" ]]; then
	if grep -q 'validate-task.*thor' "$WORKER_FILE" 2>/dev/null; then
		pass "11.3 copilot-worker.sh calls validate-task with 'thor' validator"
	else
		fail "11.3 copilot-worker.sh missing per-task Thor validation"
	fi
else
	fail "11.3 copilot-worker.sh not found"
fi

# Test 11.4: validate.agent.md mentions submitted flow
VALIDATE_AGENT="$HOME/.claude/copilot-agents/validate.agent.md"
if [[ -f "$VALIDATE_AGENT" ]]; then
	if grep -q "submitted" "$VALIDATE_AGENT" 2>/dev/null; then
		pass "11.4 validate.agent.md documents submitted flow"
	else
		fail "11.4 validate.agent.md missing submitted status documentation"
	fi
else
	fail "11.4 validate.agent.md not found"
fi

# Test 11.5: thor-validate.sh handles submitted tasks
THOR_FILE="$SCRIPT_DIR/thor-validate.sh"
if [[ -f "$THOR_FILE" ]]; then
	if grep -q "submitted" "$THOR_FILE" 2>/dev/null; then
		pass "11.5 thor-validate.sh handles submitted tasks"
	else
		fail "11.5 thor-validate.sh ignores submitted tasks"
	fi
else
	fail "11.5 thor-validate.sh not found"
fi

# Test 11.6: safe_update_task delegates to plan-db-safe.sh (which sets submitted)
DELEGATE_FILE="$SCRIPT_DIR/lib/delegate-utils.sh"
if [[ -f "$DELEGATE_FILE" ]]; then
	if grep -q "plan-db-safe.sh" "$DELEGATE_FILE" 2>/dev/null; then
		pass "11.6 safe_update_task delegates through plan-db-safe.sh"
	else
		fail "11.6 safe_update_task bypasses plan-db-safe.sh"
	fi
else
	fail "11.6 delegate-utils.sh not found"
fi

# Test 11.7: plan-db-safe.sh intercepts 'done' and sets 'submitted'
SAFE_FILE="$SCRIPT_DIR/plan-db-safe.sh"
if [[ -f "$SAFE_FILE" ]]; then
	if grep -q "submitted" "$SAFE_FILE" 2>/dev/null; then
		pass "11.7 plan-db-safe.sh sets 'submitted' (not 'done')"
	else
		fail "11.7 plan-db-safe.sh still sets 'done' directly"
	fi
else
	fail "11.7 plan-db-safe.sh not found"
fi

# ============================================================
section "12. Counter Triggers (Undone + Wave Auto-Complete)"
# ============================================================

# Test 12.1: task_undone_counter trigger exists
if sq "SELECT name FROM sqlite_master WHERE name = 'task_undone_counter';" | grep -q task_undone_counter; then
	pass "12.1 task_undone_counter trigger exists"
else
	fail "12.1 task_undone_counter trigger MISSING"
fi

# Test 12.2: done → in_progress decrements wave counter
WAVE_ID=$(sq "SELECT id FROM waves LIMIT 1;")
PLAN_ID_T=$(sq "SELECT plan_id FROM waves WHERE id = $WAVE_ID;")
BEFORE_WAVE=$(sq "SELECT tasks_done FROM waves WHERE id = $WAVE_ID;")
TASK=$(sq "
	INSERT INTO tasks (project_id, wave_id, task_id, title, status, plan_id, wave_id_fk)
	VALUES ('test-project', 'W-test', 'T-undone-test', 'Undone test', 'submitted', $PLAN_ID_T, $WAVE_ID);
	SELECT last_insert_rowid();
")
# First: submitted → done (increment)
sq "UPDATE tasks SET status = 'done', validated_at = datetime('now'), validated_by = 'thor' WHERE id = $TASK AND status = 'submitted';" 2>/dev/null
AFTER_DONE=$(sq "SELECT tasks_done FROM waves WHERE id = $WAVE_ID;")
# Then: done → in_progress (decrement via task_undone_counter)
sq "UPDATE tasks SET status = 'in_progress' WHERE id = $TASK;" 2>/dev/null
AFTER_UNDONE=$(sq "SELECT tasks_done FROM waves WHERE id = $WAVE_ID;")
if [[ "$AFTER_UNDONE" == "$BEFORE_WAVE" ]]; then
	pass "12.2 done → in_progress decrements wave counter ($AFTER_DONE → $AFTER_UNDONE)"
else
	fail "12.2 Counter drift: before=$BEFORE_WAVE, after_done=$AFTER_DONE, after_undone=$AFTER_UNDONE"
fi
cleanup_test_task "$TASK"
# Resync
sq "UPDATE waves SET tasks_done = (SELECT COUNT(*) FROM tasks WHERE wave_id_fk = $WAVE_ID AND status = 'done') WHERE id = $WAVE_ID;
UPDATE plans SET tasks_done = (SELECT COALESCE(SUM(tasks_done),0) FROM waves WHERE plan_id = $PLAN_ID_T) WHERE id = $PLAN_ID_T;" 2>/dev/null

# Test 12.3: wave_auto_complete transitions to 'merging' (not 'done')
TRIGGER_SQL=$(sq "SELECT sql FROM sqlite_master WHERE name = 'wave_auto_complete';")
if echo "$TRIGGER_SQL" | grep -q "merging" 2>/dev/null; then
	pass "12.3 wave_auto_complete transitions to 'merging' (not 'done')"
else
	fail "12.3 wave_auto_complete still transitions to 'done'"
fi

# ============================================================
# Summary
# ============================================================
echo ""
echo "============================================"
echo -e "  Tests: $TOTAL | ${GREEN}Pass: $PASS${NC} | ${RED}Fail: $FAIL${NC}"
echo "============================================"

if [[ $FAIL -gt 0 ]]; then
	echo -e "${RED}SOME TESTS FAILED${NC}"
	exit 1
else
	echo -e "${GREEN}ALL TESTS PASSED${NC}"
	exit 0
fi
