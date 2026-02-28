#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DB_FILE="$HOME/.claude/data/dashboard.db"
VALIDATE_FILE="$SCRIPT_DIR/lib/plan-db-validate.sh"

PASS=0
FAIL=0

sq() { sqlite3 -cmd ".timeout 5000" "$DB_FILE" "$@"; }
pass() { PASS=$((PASS + 1)); echo "PASS $1"; }
fail() { FAIL=$((FAIL + 1)); echo "FAIL $1"; }

cleanup_task() {
	local task_id="$1"
	local wave_db_id="$2"
	local plan_db_id="$3"
	sq "DELETE FROM tasks WHERE id = $task_id;" >/dev/null 2>&1 || true
	sq "
		UPDATE waves SET tasks_done = (SELECT COUNT(*) FROM tasks WHERE wave_id_fk = $wave_db_id AND status = 'done'),
		                 tasks_total = (SELECT COUNT(*) FROM tasks WHERE wave_id_fk = $wave_db_id)
		WHERE id = $wave_db_id;
		UPDATE plans SET tasks_done = (SELECT COALESCE(SUM(tasks_done),0) FROM waves WHERE plan_id = $plan_db_id),
		                 tasks_total = (SELECT COALESCE(SUM(tasks_total),0) FROM waves WHERE plan_id = $plan_db_id)
		WHERE id = $plan_db_id;
	" >/dev/null 2>&1 || true
}

echo "=== test-plan-db-validate-refactor ==="

# Test 1: main dispatcher file must stay under 200 lines
line_count=$(wc -l <"$VALIDATE_FILE" | tr -d ' ')
if [[ "$line_count" -lt 200 ]]; then
	pass "plan-db-validate.sh line count < 200 ($line_count)"
else
	fail "plan-db-validate.sh line count < 200 (actual: $line_count)"
fi

# Test 2: integration validate-task keeps submitted -> done flow working
wave_db_id=$(sq "SELECT id FROM waves LIMIT 1;")
if [[ -z "$wave_db_id" ]]; then
	fail "validate-task integration (no wave rows found)"
else
	plan_db_id=$(sq "SELECT plan_id FROM waves WHERE id = $wave_db_id;")
	task_db_id=$(sq "
		INSERT INTO tasks (project_id, wave_id, task_id, title, status, plan_id, wave_id_fk)
		VALUES ('test-project', 'W-test', 'T-validate-refactor-$(date +%s)', 'Validate refactor integration', 'submitted', $plan_db_id, $wave_db_id);
		SELECT last_insert_rowid();
	")
	output="$("$SCRIPT_DIR/plan-db.sh" validate-task "$task_db_id" "" "thor" 2>&1 || true)"
	status_now=$(sq "SELECT status FROM tasks WHERE id = $task_db_id;")
	validated_by_now=$(sq "SELECT validated_by FROM tasks WHERE id = $task_db_id;")
	if [[ "$status_now" == "done" && "$validated_by_now" == "thor" ]] && echo "$output" | grep -Eqi "submitted.*done"; then
		pass "plan-db.sh validate-task integration"
	else
		fail "plan-db.sh validate-task integration (status=$status_now validated_by=$validated_by_now)"
	fi
	cleanup_task "$task_db_id" "$wave_db_id" "$plan_db_id"
fi

echo "=== summary: pass=$PASS fail=$FAIL ==="
[[ "$FAIL" -eq 0 ]]
