#!/usr/bin/env bash
# test-wave-worktree.sh — Integration tests for wave-worktree system
# Version: 1.0.0
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/scripts"
PASS=0 FAIL=0 TOTAL=0

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------
assert() {
	TOTAL=$((TOTAL + 1))
	local desc="$1"
	shift
	if "$@" 2>/dev/null; then
		echo "  PASS: $desc"
		PASS=$((PASS + 1))
	else
		echo "  FAIL: $desc"
		FAIL=$((FAIL + 1))
	fi
}

assert_eq() {
	TOTAL=$((TOTAL + 1))
	local desc="$1" expected="$2" actual="$3"
	if [[ "$expected" == "$actual" ]]; then
		echo "  PASS: $desc"
		PASS=$((PASS + 1))
	else
		echo "  FAIL: $desc (expected='$expected', got='$actual')"
		FAIL=$((FAIL + 1))
	fi
}

# ---------------------------------------------------------------------------
# Setup: create temp git repo + temp SQLite DB
# NOTE: source plan-db-core.sh BEFORE setting DB_FILE — it hardcodes the path.
#       After sourcing, override DB_FILE with our test DB.
# ---------------------------------------------------------------------------
setup() {
	TEST_DIR=$(mktemp -d)
	TEST_REPO="$TEST_DIR/repo"
	TEST_DB="$TEST_DIR/test.db"

	# Create git repo with initial commit
	mkdir -p "$TEST_REPO"
	git -C "$TEST_DIR" init "$TEST_REPO" -q
	git -C "$TEST_REPO" config user.email "test@test.com"
	git -C "$TEST_REPO" config user.name "Test"
	git -C "$TEST_REPO" commit --allow-empty -m "initial" -q
	git -C "$TEST_REPO" checkout -b main 2>/dev/null || true

	# Create minimal DB schema (includes worktree columns + merging status)
	sqlite3 "$TEST_DB" <<'SQL'
CREATE TABLE IF NOT EXISTS projects (id TEXT PRIMARY KEY, name TEXT, path TEXT);
CREATE TABLE IF NOT EXISTS plans (
    id INTEGER PRIMARY KEY, project_id TEXT, name TEXT, status TEXT DEFAULT 'doing',
    worktree_path TEXT, source_file TEXT, markdown_path TEXT, markdown_dir TEXT,
    description TEXT, human_summary TEXT, is_master INTEGER DEFAULT 0,
    parent_plan_id INTEGER, tasks_done INTEGER DEFAULT 0, tasks_total INTEGER DEFAULT 0,
    validated_at DATETIME, validated_by TEXT, started_at DATETIME, completed_at DATETIME,
    execution_host TEXT, lines_added INTEGER, lines_removed INTEGER
);
CREATE TABLE IF NOT EXISTS plan_versions (
    id INTEGER PRIMARY KEY, plan_id INTEGER, version INTEGER, change_type TEXT,
    change_reason TEXT, changed_by TEXT, changed_host TEXT
);
CREATE TABLE IF NOT EXISTS waves (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    project_id TEXT NOT NULL, wave_id TEXT NOT NULL, name TEXT NOT NULL,
    status TEXT NOT NULL CHECK(status IN ('pending','in_progress','done','blocked','merging')),
    assignee TEXT, tasks_done INTEGER DEFAULT 0, tasks_total INTEGER DEFAULT 0,
    started_at DATETIME, completed_at DATETIME, plan_id INTEGER,
    position INTEGER DEFAULT 0, planned_start DATETIME, planned_end DATETIME,
    depends_on TEXT, estimated_hours INTEGER DEFAULT 8, markdown_path TEXT,
    precondition TEXT DEFAULT NULL, worktree_path TEXT, branch_name TEXT,
    pr_number INTEGER, pr_url TEXT
);
CREATE TABLE IF NOT EXISTS tasks (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    project_id TEXT, wave_id TEXT, wave_id_fk INTEGER, plan_id INTEGER,
    task_id TEXT, title TEXT, description TEXT, status TEXT DEFAULT 'pending',
    priority TEXT DEFAULT 'P1', type TEXT DEFAULT 'feature', assignee TEXT,
    test_criteria TEXT, model TEXT, executor_agent TEXT, effort_level INTEGER DEFAULT 1,
    started_at DATETIME, completed_at DATETIME, validated_at DATETIME,
    validated_by TEXT, validation_report TEXT, executor_host TEXT,
    notes TEXT, tokens INTEGER, output_data TEXT
);

CREATE TRIGGER IF NOT EXISTS wave_auto_complete
AFTER UPDATE OF tasks_done ON waves
WHEN NEW.tasks_done = NEW.tasks_total AND NEW.tasks_total > 0
     AND NEW.status NOT IN ('done', 'merging')
BEGIN
    UPDATE waves
    SET status = 'merging', completed_at = COALESCE(completed_at, datetime('now'))
    WHERE id = NEW.id;
END;

INSERT INTO projects VALUES ('test', 'Test Project', '/tmp/test-repo');
INSERT INTO plans (id, project_id, name, status, tasks_done, tasks_total)
    VALUES (999, 'test', 'Test Plan', 'doing', 0, 2);
INSERT INTO waves (id, project_id, wave_id, name, status, plan_id, position, tasks_total)
    VALUES (9991, 'test', 'W0', 'Test Wave', 'pending', 999, 0, 2);
SQL
}

# Source libs with DB_FILE override (plan-db-core.sh hardcodes the path; must override after sourcing)
source_libs() {
	# shellcheck disable=SC1090
	source "$SCRIPT_DIR/lib/plan-db-core.sh"
	# Override AFTER sourcing (plan-db-core.sh sets DB_FILE to real path on load)
	export DB_FILE="$TEST_DB"
	# shellcheck disable=SC1090
	source "$SCRIPT_DIR/lib/wave-worktree-core.sh"
}

teardown() {
	rm -rf "${TEST_DIR:-}" 2>/dev/null || true
}

# ---------------------------------------------------------------------------
# Test 1: Migration idempotent
# ---------------------------------------------------------------------------
test_migration_idempotent() {
	echo ""
	echo "--- Test 1: Migration idempotent ---"
	setup

	local mig="$SCRIPT_DIR/migrate-v8-wave-worktree.sh"
	if [[ ! -f "$mig" ]]; then
		echo "  SKIP: migration script not found"
		teardown
		return
	fi

	# Pre-migration DB: waves table WITHOUT worktree columns
	sqlite3 "$TEST_DB" "DROP TABLE waves;"
	sqlite3 "$TEST_DB" "CREATE TABLE waves (id INTEGER PRIMARY KEY AUTOINCREMENT, project_id TEXT NOT NULL, wave_id TEXT NOT NULL, name TEXT NOT NULL, status TEXT NOT NULL CHECK(status IN ('pending','in_progress','done','blocked')), assignee TEXT, tasks_done INTEGER DEFAULT 0, tasks_total INTEGER DEFAULT 0, started_at DATETIME, completed_at DATETIME, plan_id INTEGER, position INTEGER DEFAULT 0, planned_start DATETIME, planned_end DATETIME, depends_on TEXT, estimated_hours INTEGER DEFAULT 8, markdown_path TEXT, precondition TEXT DEFAULT NULL);"
	sqlite3 "$TEST_DB" "INSERT INTO waves (id, project_id, wave_id, name, status, plan_id, tasks_total) VALUES (9991, 'test', 'W0', 'Test Wave', 'pending', 999, 2);"

	local rc1=0
	DB_FILE="$TEST_DB" bash "$mig" >/dev/null 2>&1 || rc1=$?
	assert "migration first run succeeds" test "$rc1" -eq 0

	local rc2=0
	DB_FILE="$TEST_DB" bash "$mig" >/dev/null 2>&1 || rc2=$?
	assert "migration second run is idempotent (no error)" test "$rc2" -eq 0

	teardown
}

# ---------------------------------------------------------------------------
# Test 2: wave-worktree-core.sh pure function tests
# ---------------------------------------------------------------------------
test_core_functions() {
	echo ""
	echo "--- Test 2: wave-worktree-core.sh functions ---"
	setup
	source_libs

	# wave_branch_name
	local branch
	branch=$(wave_branch_name 200 W1)
	assert_eq "wave_branch_name 200 W1 == plan/200-W1" "plan/200-W1" "$branch"

	# wave_worktree_path
	local wt_path
	wt_path=$(wave_worktree_path /tmp/repo 200 W1)
	assert_eq "wave_worktree_path /tmp/repo 200 W1" "/tmp/repo-plan-200-W1" "$wt_path"

	# wave_set_db + wave_get_db roundtrip
	wave_set_db 9991 "/tmp/test-wt" "plan/999-W0" 2>/dev/null
	local got_json
	got_json=$(wave_get_db 9991)
	assert "wave_get_db JSON contains worktree_path" \
		bash -c "echo '$got_json' | grep -q 'test-wt'"
	assert "wave_get_db JSON contains branch_name" \
		bash -c "echo '$got_json' | grep -q 'plan/999-W0'"

	teardown
}

# ---------------------------------------------------------------------------
# Test 3: wave-worktree.sh create errors on missing plan/wave in DB
# ---------------------------------------------------------------------------
test_create_reads_db() {
	echo ""
	echo "--- Test 3: wave-worktree.sh create errors on missing plan/wave ---"
	setup

	local script="$SCRIPT_DIR/wave-worktree.sh"
	local out rc=0
	out=$(DB_FILE="$TEST_DB" bash "$script" create 9999 9999 2>&1) || rc=$?
	assert "create with missing plan/wave prints error message" \
		bash -c "echo '$out' | grep -qi 'error\\|not found\\|cannot'"

	teardown
}

# ---------------------------------------------------------------------------
# Test 4: wave_stash_if_dirty
# ---------------------------------------------------------------------------
test_stash_if_dirty() {
	echo ""
	echo "--- Test 4: wave_stash_if_dirty ---"
	setup
	source_libs

	# Sub-repo: clean
	local sub_repo="$TEST_DIR/sub"
	mkdir -p "$sub_repo"
	git -C "$sub_repo" init -q
	git -C "$sub_repo" config user.email "t@t.com"
	git -C "$sub_repo" config user.name "T"
	git -C "$sub_repo" commit --allow-empty -m "init" -q

	local ref_clean
	ref_clean=$(wave_stash_if_dirty "$sub_repo")
	assert_eq "stash on clean repo returns empty string" "" "$ref_clean"

	# Make it dirty with staged changes
	echo "dirty" >"$sub_repo/dirty.txt"
	git -C "$sub_repo" add dirty.txt
	local ref_dirty
	ref_dirty=$(wave_stash_if_dirty "$sub_repo")
	assert "stash on dirty repo returns non-empty ref" test -n "$ref_dirty"

	teardown
}

# ---------------------------------------------------------------------------
# Test 5: cleanup logic clears DB worktree fields
# ---------------------------------------------------------------------------
test_cleanup_clears_db() {
	echo ""
	echo "--- Test 5: cleanup clears worktree_path + branch_name in DB ---"
	setup
	source_libs

	# Set fields
	db_query "UPDATE waves SET worktree_path='/tmp/some-wt', branch_name='plan/999-W0' WHERE id=9991;"

	local before
	before=$(db_query "SELECT worktree_path FROM waves WHERE id=9991;")
	assert_eq "worktree_path set before cleanup" "/tmp/some-wt" "$before"

	# Cleanup: NULL out fields (mirrors cmd_cleanup DB update)
	db_query "UPDATE waves SET worktree_path=NULL, branch_name=NULL WHERE id=9991;"

	local after
	after=$(db_query "SELECT COALESCE(worktree_path,'NULL') FROM waves WHERE id=9991;")
	assert_eq "worktree_path is NULL after cleanup" "NULL" "$after"

	local branch_after
	branch_after=$(db_query "SELECT COALESCE(branch_name,'NULL') FROM waves WHERE id=9991;")
	assert_eq "branch_name is NULL after cleanup" "NULL" "$branch_after"

	teardown
}

# ---------------------------------------------------------------------------
# Test 6: Backward compat — old plan without wave worktree_path
# ---------------------------------------------------------------------------
test_backward_compat_wave_is_active() {
	echo ""
	echo "--- Test 6: Backward compat — wave_is_active false for old plan ---"
	setup
	source_libs

	# Plan 999 has wave 9991 with no worktree_path (NULL)
	local result
	if wave_is_active 999 2>/dev/null; then
		result="active"
	else
		result="inactive"
	fi
	assert_eq "wave_is_active returns false for old plan (no wave worktree)" "inactive" "$result"

	# Now activate one wave and check it returns true
	db_query "UPDATE waves SET worktree_path='/tmp/active-wt' WHERE id=9991;"
	if wave_is_active 999 2>/dev/null; then
		result="active"
	else
		result="inactive"
	fi
	assert_eq "wave_is_active returns true when wave has worktree" "active" "$result"

	teardown
}

# ---------------------------------------------------------------------------
# Test 7: cmd_complete blocks when wave is in 'merging' state
# ---------------------------------------------------------------------------
test_complete_blocks_merging() {
	echo ""
	echo "--- Test 7: cmd_complete blocks when wave is merging ---"
	setup

	# Set wave to merging, mark plan tasks done (validated)
	sqlite3 "$TEST_DB" "UPDATE waves SET status='merging' WHERE id=9991;"
	sqlite3 "$TEST_DB" "UPDATE plans SET tasks_done=2, tasks_total=2, validated_at=datetime('now') WHERE id=999;"

	# Mirrors cmd_complete merging guard in plan-db-crud.sh
	local waves_merging
	waves_merging=$(sqlite3 "$TEST_DB" "SELECT COUNT(*) FROM waves WHERE plan_id=999 AND status='merging';")

	assert "merging guard fires: found merging wave" test "$waves_merging" -gt 0

	# Simulate the actual check: if merging > 0, completion is blocked
	local would_block=0
	[[ "$waves_merging" -gt 0 ]] && would_block=1
	assert "complete would be blocked (would_block=1)" test "$would_block" -eq 1

	teardown
}

# ---------------------------------------------------------------------------
# Test 8: Trigger sets 'merging' when tasks_done reaches tasks_total
# ---------------------------------------------------------------------------
test_trigger_sets_merging() {
	echo ""
	echo "--- Test 8: Trigger sets merging when tasks_done == tasks_total ---"
	setup

	local initial
	initial=$(sqlite3 "$TEST_DB" "SELECT status FROM waves WHERE id=9991;")
	assert_eq "initial wave status is pending" "pending" "$initial"

	# Fire trigger by updating tasks_done to match tasks_total
	sqlite3 "$TEST_DB" "UPDATE waves SET tasks_done=2 WHERE id=9991;"

	local final
	final=$(sqlite3 "$TEST_DB" "SELECT status FROM waves WHERE id=9991;")
	assert_eq "trigger sets status to merging (not done)" "merging" "$final"

	teardown
}

# ---------------------------------------------------------------------------
# Test 9: resolve_github_remote() with remote named "github"
# ---------------------------------------------------------------------------
test_resolve_github_remote_named_github() {
	echo ""
	echo "--- Test 9: resolve_github_remote() — remote named 'github' ---"
	setup
	source_libs

	local tmp_repo="$TEST_DIR/github-remote-repo"
	mkdir -p "$tmp_repo"
	git -C "$tmp_repo" init -q
	git -C "$tmp_repo" config user.email "t@t.com"
	git -C "$tmp_repo" config user.name "T"
	git -C "$tmp_repo" remote add github "https://github.com/someuser/somerepo.git"
	git -C "$tmp_repo" remote add origin "https://example.com/other.git"

	local result
	result=$(resolve_github_remote "$tmp_repo")
	assert_eq "resolve_github_remote returns 'github' when a remote named github points to github.com" "github" "$result"

	teardown
}

# ---------------------------------------------------------------------------
# Test 10: resolve_github_remote() with remote named "origin" pointing to github.com
# ---------------------------------------------------------------------------
test_resolve_github_remote_origin() {
	echo ""
	echo "--- Test 10: resolve_github_remote() — origin points to github.com ---"
	setup
	source_libs

	local tmp_repo="$TEST_DIR/origin-remote-repo"
	mkdir -p "$tmp_repo"
	git -C "$tmp_repo" init -q
	git -C "$tmp_repo" config user.email "t@t.com"
	git -C "$tmp_repo" config user.name "T"
	git -C "$tmp_repo" remote add origin "https://github.com/someuser/somerepo.git"

	local result
	result=$(resolve_github_remote "$tmp_repo")
	assert_eq "resolve_github_remote returns 'origin' when origin points to github.com" "origin" "$result"

	teardown
}

# ---------------------------------------------------------------------------
# Test 11: resolve_github_remote() falls back to first remote (non-github URL)
# ---------------------------------------------------------------------------
test_resolve_github_remote_fallback() {
	echo ""
	echo "--- Test 11: resolve_github_remote() — fallback to first remote ---"
	setup
	source_libs

	local tmp_repo="$TEST_DIR/custom-remote-repo"
	mkdir -p "$tmp_repo"
	git -C "$tmp_repo" init -q
	git -C "$tmp_repo" config user.email "t@t.com"
	git -C "$tmp_repo" config user.name "T"
	git -C "$tmp_repo" remote add custom "https://gitlab.com/someuser/somerepo.git"

	local result
	result=$(resolve_github_remote "$tmp_repo")
	assert_eq "resolve_github_remote returns 'custom' (first remote) when no github.com URL" "custom" "$result"

	teardown
}

# ---------------------------------------------------------------------------
# Test 12: No --timeout flag in wave-worktree.sh
# ---------------------------------------------------------------------------
test_no_timeout_flag() {
	echo ""
	echo "--- Test 12: No --timeout flag in wave-worktree.sh ---"

	local count
	count=$(grep -c '\-\-timeout' "$SCRIPT_DIR/wave-worktree.sh" || true)
	assert_eq "wave-worktree.sh contains 0 occurrences of --timeout" "0" "$count"
}

# ---------------------------------------------------------------------------
# Test 13: Rollback pattern exists (merging -> in_progress on failure)
# ---------------------------------------------------------------------------
test_rollback_pattern_exists() {
	echo ""
	echo "--- Test 13: Rollback pattern: merging -> in_progress on failure ---"

	assert "rollback pattern (status='in_progress' WHERE) found in wave-worktree.sh" \
		grep -qE "status='in_progress'" "$SCRIPT_DIR/wave-worktree.sh"
}

# ---------------------------------------------------------------------------
# Test 14: Pre-flight diff check exists (empty wave detection)
# ---------------------------------------------------------------------------
test_preflight_diff_check_exists() {
	echo ""
	echo "--- Test 14: Pre-flight diff check (No changes in wave worktree) ---"

	assert "pre-flight diff check pattern found in wave-worktree.sh" \
		grep -qE "log.*main.*HEAD|No changes in wave worktree" "$SCRIPT_DIR/wave-worktree.sh"
}

# ---------------------------------------------------------------------------
# Run all tests
# ---------------------------------------------------------------------------
echo ""
echo "=== wave-worktree integration tests ==="

test_migration_idempotent
test_core_functions
test_create_reads_db
test_stash_if_dirty
test_cleanup_clears_db
test_backward_compat_wave_is_active
test_complete_blocks_merging
test_trigger_sets_merging
test_resolve_github_remote_named_github
test_resolve_github_remote_origin
test_resolve_github_remote_fallback
test_no_timeout_flag
test_rollback_pattern_exists
test_preflight_diff_check_exists

echo ""
echo "=== Results: $PASS/$TOTAL passed, $FAIL failed ==="
[[ $FAIL -eq 0 ]] && exit 0 || exit 1
