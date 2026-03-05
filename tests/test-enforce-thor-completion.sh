#!/usr/bin/env bash
# test-enforce-thor-completion.sh — Tests for enforce-thor-completion.sh hook
# Version: 1.0.0
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
HOOK="$SCRIPT_DIR/hooks/enforce-thor-completion.sh"

PASS=0
FAIL=0
TOTAL=0

# ── Test framework ─────────────────────────────────────────────────────────────

pass() {
	PASS=$((PASS + 1))
	TOTAL=$((TOTAL + 1))
	echo "[PASS] $1"
}
fail() {
	FAIL=$((FAIL + 1))
	TOTAL=$((TOTAL + 1))
	echo "[FAIL] $1"
	[ -n "${2:-}" ] && echo "       Expected: $2"
	[ -n "${3:-}" ] && echo "       Got:      $3"
}

assert_exit() {
	local desc="$1" expected="$2" actual="$3"
	[ "$actual" -eq "$expected" ] && pass "$desc" || fail "$desc" "exit $expected" "exit $actual"
}

assert_contains() {
	local desc="$1" pattern="$2" output="$3"
	if echo "$output" | grep -q "$pattern"; then
		pass "$desc"
	else
		fail "$desc" "output contains '$pattern'" "$(echo "$output" | head -1)"
	fi
}

assert_not_contains() {
	local desc="$1" pattern="$2" output="$3"
	if echo "$output" | grep -q "$pattern"; then
		fail "$desc" "output NOT containing '$pattern'" "$output"
	else
		pass "$desc"
	fi
}

# ── Temp DB setup ──────────────────────────────────────────────────────────────

TMPDIR_TEST=$(mktemp -d)
TEST_DB="$TMPDIR_TEST/dashboard.db"

cleanup() { rm -rf "$TMPDIR_TEST"; }
trap cleanup EXIT

sqlite3 "$TEST_DB" <<'SQL'
CREATE TABLE tasks (
  id INTEGER PRIMARY KEY,
  task_id TEXT,
  plan_id INTEGER,
  title TEXT,
  status TEXT DEFAULT 'pending',
  validated_at TEXT
);
SQL

# Plan 100: all tasks validated (allow)
sqlite3 "$TEST_DB" "INSERT INTO tasks (task_id, plan_id, title, status, validated_at) VALUES
  ('T1-01', 100, 'Task A', 'done',    '2026-01-01T10:00:00'),
  ('T1-02', 100, 'Task B', 'done',    '2026-01-01T11:00:00');"

# Plan 200: one task not validated (deny)
sqlite3 "$TEST_DB" "INSERT INTO tasks (task_id, plan_id, title, status, validated_at) VALUES
  ('T2-01', 200, 'Task A', 'done',    '2026-01-01T10:00:00'),
  ('T2-02', 200, 'Task B', 'submitted', NULL);"

# Plan 300: skipped + cancelled tasks only, no validated_at needed (allow)
sqlite3 "$TEST_DB" "INSERT INTO tasks (task_id, plan_id, title, status, validated_at) VALUES
  ('T3-01', 300, 'Task A', 'done',      '2026-01-01T10:00:00'),
  ('T3-02', 300, 'Task B', 'skipped',   NULL),
  ('T3-03', 300, 'Task C', 'cancelled', NULL);"

# ── Helper: run hook with overridden DB path ───────────────────────────────────

run_hook() {
	local json="$1"
	HOME="$TMPDIR_TEST" DB_OVERRIDE="$TEST_DB" \
		bash -c "
      export HOME='$TMPDIR_TEST'
      # Patch DB path: hook uses \$HOME/.claude/data/dashboard.db
      mkdir -p '$TMPDIR_TEST/.claude/data'
      cp '$TEST_DB' '$TMPDIR_TEST/.claude/data/dashboard.db'
      echo '$json' | bash '$HOOK'
    " 2>&1
}

run_hook_exit() {
	local json="$1"
	HOME="$TMPDIR_TEST" \
		bash -c "
      mkdir -p '$TMPDIR_TEST/.claude/data'
      cp '$TEST_DB' '$TMPDIR_TEST/.claude/data/dashboard.db'
      echo '$json' | bash '$HOOK' >/dev/null 2>&1
    "
	echo $?
}

# ── Test 1: non-complete command → exit 0, no output ──────────────────────────

echo ""
echo "=== Test 1: non-complete command ==="

JSON1='{"toolName":"bash","toolArgs":{"command":"plan-db.sh start 42"}}'
OUT1=$(run_hook "$JSON1")
EXIT1=$(run_hook_exit "$JSON1")
assert_exit "exit 0 for non-complete command" 0 "$EXIT1"
assert_not_contains "no deny JSON for non-complete command" "permissionDecision" "$OUT1"

# ── Test 2: non-bash tool → exit 0 ────────────────────────────────────────────

echo ""
echo "=== Test 2: non-bash tool ==="

JSON2='{"toolName":"read","toolArgs":{"command":"plan-db.sh complete 100"}}'
OUT2=$(run_hook "$JSON2")
EXIT2=$(run_hook_exit "$JSON2")
assert_exit "exit 0 for non-bash tool" 0 "$EXIT2"
assert_not_contains "no deny JSON for non-bash tool" "permissionDecision" "$OUT2"

# ── Test 3: plan 100 all validated → exit 0, no deny ──────────────────────────

echo ""
echo "=== Test 3: plan with all tasks validated (allow) ==="

JSON3='{"toolName":"bash","toolArgs":{"command":"plan-db.sh complete 100"}}'
OUT3=$(run_hook "$JSON3")
EXIT3=$(run_hook_exit "$JSON3")
assert_exit "exit 0 when all tasks validated" 0 "$EXIT3"
assert_not_contains "no deny JSON when all validated" "deny" "$OUT3"

# ── Test 4: plan 200 unvalidated task → deny JSON ─────────────────────────────

echo ""
echo "=== Test 4: plan with unvalidated tasks (deny) ==="

JSON4='{"toolName":"bash","toolArgs":{"command":"plan-db.sh complete 200"}}'
OUT4=$(run_hook "$JSON4")
EXIT4=$(run_hook_exit "$JSON4")
assert_exit "exit 0 even on deny (hook uses JSON not exit code)" 0 "$EXIT4"
assert_contains "deny permissionDecision for unvalidated tasks" '"deny"' "$OUT4"
assert_contains "deny message mentions plan id 200" "200" "$OUT4"
assert_contains "deny message mentions unvalidated task_id" "T2-02" "$OUT4"

# ── Test 5: plan 300 skipped/cancelled tasks → exit 0, no deny ────────────────

echo ""
echo "=== Test 5: plan with skipped/cancelled tasks (allow) ==="

JSON5='{"toolName":"bash","toolArgs":{"command":"plan-db.sh complete 300"}}'
OUT5=$(run_hook "$JSON5")
EXIT5=$(run_hook_exit "$JSON5")
assert_exit "exit 0 when only skipped/cancelled non-validated" 0 "$EXIT5"
assert_not_contains "no deny JSON for skipped/cancelled" "deny" "$OUT5"

# ── Test 6: complete without plan_id → deny (cannot resolve plan) ─────────────

echo ""
echo "=== Test 6: complete with no plan_id and no active-plan-id.txt ==="

# Ensure no active-plan-id.txt in temp home
rm -f "$TMPDIR_TEST/.claude/data/active-plan-id.txt"

JSON6='{"toolName":"bash","toolArgs":{"command":"plan-db.sh complete"}}'
OUT6=$(run_hook "$JSON6")
EXIT6=$(run_hook_exit "$JSON6")
assert_exit "exit 0 even when plan_id unresolvable" 0 "$EXIT6"
assert_contains "deny when plan_id cannot be resolved" "deny" "$OUT6"
assert_contains "deny message mentions Cannot resolve" "Cannot resolve" "$OUT6"

# ── Summary ───────────────────────────────────────────────────────────────────

echo ""
echo "─────────────────────────────────────────"
echo "Results: $PASS passed, $FAIL failed / $TOTAL total"
echo "─────────────────────────────────────────"
[ "$FAIL" -eq 0 ] && exit 0 || exit 1
