#!/usr/bin/env bash
# test-mesh-migrate.sh — mesh-migrate test suite (no real SSH/network)
# v1.0.0 | C-06: ≤250 lines

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
source "$SCRIPT_DIR/lib/test-helpers.sh"
auto_cleanup_temp_dir

SYNC_LIB="$REPO_ROOT/scripts/lib/mesh-migrate-sync.sh"
DB_LIB="$REPO_ROOT/scripts/lib/mesh-migrate-db.sh"
ORCH="$REPO_ROOT/scripts/mesh-migrate.sh"
EXCL="$REPO_ROOT/config/mesh-rsync-exclude.txt"

echo "=== test-mesh-migrate.sh ==="

# ── Mock SSH/SCP in temp bin (no real SSH calls) ────────────────────────────
mkdir -p "$TEST_TEMP_DIR/bin"
cat >"$TEST_TEMP_DIR/bin/ssh" <<'SEOF'
#!/usr/bin/env bash
# Mock SSH: skip opts and host, run command locally with DB substitution
skip=0; host_found=0; cmd_args=()
for a in "$@"; do
  [[ $skip -eq 1 ]] && skip=0 && continue
  [[ "$a" == "-o" ]] && skip=1 && continue
  [[ "$a" == -* ]] && continue
  if [[ $host_found -eq 0 ]]; then host_found=1; continue; fi
  cmd_args+=("$a")
done
cmd="${cmd_args[*]:-}"
[[ -n "${MOCK_TARGET_DB:-}" ]] && cmd="${cmd//~\/.claude\/data\/dashboard.db/$MOCK_TARGET_DB}"
eval "$cmd"
SEOF
chmod +x "$TEST_TEMP_DIR/bin/ssh"

cat >"$TEST_TEMP_DIR/bin/scp" <<'SEOF'
#!/usr/bin/env bash
# Mock SCP: local-to-local copy, strip host: from destination
skip=0; src=""; dst=""
for a in "$@"; do
  [[ $skip -eq 1 ]] && skip=0 && continue
  [[ "$a" == "-o" ]] && skip=1 && continue
  [[ "$a" == -* ]] && continue
  [[ -z "$src" ]] && { src="$a"; continue; }
  dst="${a#*:}"
done
[[ -n "$src" && -n "$dst" ]] && cp "$src" "$dst" || true
SEOF
chmod +x "$TEST_TEMP_DIR/bin/scp"
export PATH="$TEST_TEMP_DIR/bin:$PATH"

# Helper: create minimal test DB schema
make_db() {
	local db="$1"
	rm -f "$db"
	sqlite3 "$db" "
    CREATE TABLE plans (id INTEGER PRIMARY KEY, worktree_path TEXT DEFAULT '',
                        status TEXT DEFAULT 'doing', execution_host TEXT DEFAULT '');
    CREATE TABLE waves (id INTEGER PRIMARY KEY, plan_id INTEGER, worktree_path TEXT DEFAULT '');
    CREATE TABLE tasks (id INTEGER PRIMARY KEY, task_id TEXT, plan_id INTEGER,
                        wave_id_fk INTEGER, status TEXT DEFAULT 'pending',
                        executor_host TEXT DEFAULT '');
    CREATE TABLE peer_heartbeats (host TEXT, role TEXT);
  "
}

# ── T1: Exclude file patterns ───────────────────────────────────────────────
assert_file_exists "$EXCL" "T1: exclude file exists"
assert_grep '\.git/objects' "$EXCL" "T1: excludes .git/objects"
assert_grep 'node_modules' "$EXCL" "T1: excludes node_modules"
assert_grep '\.db-wal' "$EXCL" "T1: excludes .db-wal"

# ── T2: Bash syntax checks ──────────────────────────────────────────────────
assert_bash_syntax "$SYNC_LIB" "T2: mesh-migrate-sync.sh syntax valid"
assert_bash_syntax "$DB_LIB" "T2: mesh-migrate-db.sh syntax valid"
assert_bash_syntax "$ORCH" "T2: mesh-migrate.sh syntax valid"

# ── T3: File size gate (≤250 lines each) ───────────────────────────────────
assert_line_count "$EXCL" 250 "T3: exclude file ≤250 lines"
assert_line_count "$SYNC_LIB" 250 "T3: mesh-migrate-sync.sh ≤250 lines"
assert_line_count "$DB_LIB" 250 "T3: mesh-migrate-db.sh ≤250 lines"
assert_line_count "$ORCH" 250 "T3: mesh-migrate.sh ≤250 lines"
assert_line_count "$0" 250 "T3: test file itself ≤250 lines"

# ── T4: DB checkpoint (local sqlite3, no SSH needed) ───────────────────────
LOCAL_DB="$TEST_TEMP_DIR/checkpoint.db"
make_db "$LOCAL_DB"
sqlite3 "$LOCAL_DB" "PRAGMA journal_mode=WAL; INSERT INTO plans VALUES (99,'~/test','doing','');"

result=0
bash -c "
  source '$DB_LIB'
  DB='$LOCAL_DB'
  _migrate_db_checkpoint
" 2>/dev/null && pass "T4: DB checkpoint completes" || {
	fail "T4: DB checkpoint failed"
	result=1
}

# ── T5: Path remapping via mock SSH ────────────────────────────────────────
SRC_DB="$TEST_TEMP_DIR/src.db"
TGT_DB="$TEST_TEMP_DIR/tgt.db"
make_db "$SRC_DB"
make_db "$TGT_DB"
sqlite3 "$TGT_DB" "
  INSERT INTO plans VALUES (1, '/Users/old/GitHub/repo', 'doing', '');
  INSERT INTO waves VALUES (1, 1, '/Users/old/.claude/worktrees/w1');
"
export MOCK_TARGET_DB="$TGT_DB"
bash -c "
  source '$DB_LIB'
  SSH_OPTS='-o ConnectTimeout=10'
  _migrate_db_remap_paths 'mock-host' '/Users/old' '/home/new'
" 2>/dev/null

cnt=$(sqlite3 "$TGT_DB" "SELECT COUNT(*) FROM plans WHERE worktree_path LIKE '/home/new%';")
[[ "$cnt" -ge 1 ]] && pass "T5: plans.worktree_path remapped" ||
	fail "T5: plans.worktree_path NOT remapped (got $cnt)"

cnt=$(sqlite3 "$TGT_DB" "SELECT COUNT(*) FROM waves WHERE worktree_path LIKE '/home/new%';")
[[ "$cnt" -ge 1 ]] && pass "T5: waves.worktree_path remapped" ||
	fail "T5: waves.worktree_path NOT remapped (got $cnt)"

# ── T6: Task status reset + plan claim transfer ────────────────────────────
make_db "$SRC_DB"
make_db "$TGT_DB"
sqlite3 "$SRC_DB" "INSERT INTO plans VALUES (42,'~/repo','doing','source-host');"
sqlite3 "$TGT_DB" "
  INSERT INTO plans VALUES (42,'~/repo','doing','source-host');
  INSERT INTO waves VALUES (10, 42, '');
  INSERT INTO tasks VALUES (1,'T1',42,10,'in_progress','source-host');
  INSERT INTO tasks VALUES (2,'T2',42,10,'in_progress','source-host');
"
export MOCK_TARGET_DB="$TGT_DB"
bash -c "
  source '$DB_LIB'
  DB='$SRC_DB'
  SSH_OPTS='-o ConnectTimeout=10'
  _migrate_transfer_plan 42 'mock-host' 'target-host'
" 2>/dev/null

pending=$(sqlite3 "$TGT_DB" "SELECT COUNT(*) FROM tasks WHERE status='pending' AND plan_id=42;")
[[ "$pending" -eq 2 ]] && pass "T6: in_progress tasks reset to pending ($pending/2)" ||
	fail "T6: task reset failed (got $pending pending, expected 2)"

tgt_host=$(sqlite3 "$TGT_DB" "SELECT execution_host FROM plans WHERE id=42;")
[[ "$tgt_host" == "target-host" ]] && pass "T6: execution_host updated on target" ||
	fail "T6: execution_host='$tgt_host' (expected target-host)"

src_host=$(sqlite3 "$SRC_DB" "SELECT execution_host FROM plans WHERE id=42;")
[[ -z "$src_host" ]] && pass "T6: source plan released (execution_host cleared)" ||
	fail "T6: source execution_host='$src_host' (expected empty)"

# ── T7: Rollback — source unchanged on failure ─────────────────────────────
make_db "$SRC_DB"
make_db "$TGT_DB"
sqlite3 "$SRC_DB" "INSERT INTO plans VALUES (99,'~/repo','doing','source-host');"
sqlite3 "$TGT_DB" "INSERT INTO plans VALUES (99,'~/repo','doing','source-host');"
cp "$TGT_DB" "${TGT_DB}.bak"
sqlite3 "$TGT_DB" "UPDATE plans SET execution_host='partial-state' WHERE id=99;"

export MOCK_TARGET_DB="$TGT_DB"
bash -c "
  source '$DB_LIB'
  DB='$SRC_DB'
  SSH_OPTS='-o ConnectTimeout=10'
  _migrate_db_rollback 'mock-host' '${TGT_DB}.bak'
" 2>/dev/null

after=$(sqlite3 "$TGT_DB" "SELECT execution_host FROM plans WHERE id=99;")
[[ "$after" == "source-host" ]] && pass "T7: rollback restored target DB" ||
	fail "T7: rollback: execution_host='$after' (expected source-host)"

src_st=$(sqlite3 "$SRC_DB" "SELECT status FROM plans WHERE id=99;")
[[ "$src_st" == "doing" ]] && pass "T7: source plan unchanged after rollback" ||
	fail "T7: source plan status='$src_st'"

# ── T8: Coordinator-only check blocks worker role ─────────────────────────
mkdir -p "$TEST_TEMP_DIR/coord/data"
COORD_DB="$TEST_TEMP_DIR/coord/data/dashboard.db"
make_db "$COORD_DB"
MYHOSTNAME=$(hostname -s 2>/dev/null | tr '[:upper:]' '[:lower:]' || echo "testhost")
sqlite3 "$COORD_DB" "
  INSERT INTO peer_heartbeats VALUES ('${MYHOSTNAME}', 'worker');
  INSERT INTO plans VALUES (1,'','doing','');
"
result=0
bash -c "
  source '$SYNC_LIB'
  CLAUDE_HOME='$TEST_TEMP_DIR/coord'
  peers_best_route() { echo 'mock-host'; }
  export -f peers_best_route 2>/dev/null || true
  _migrate_preflight 1 'mock-peer'
" 2>/dev/null || result=$?
[[ "$result" -ne 0 ]] && pass "T8: worker role blocks migration (C-01)" ||
	fail "T8: worker role should return exit 1"

# ── T9: Orchestrator contains required patterns ────────────────────────────
assert_grep 'mesh-migrate-sync' "$ORCH" "T9: orchestrator sources sync lib"
assert_grep 'mesh-migrate-db' "$ORCH" "T9: orchestrator sources db lib"
assert_grep 'tmux' "$ORCH" "T9: orchestrator has tmux auto-launch"
assert_grep '\-\-dry-run' "$ORCH" "T9: orchestrator supports --dry-run"
assert_grep 'rollback' "$ORCH" "T9: orchestrator has rollback logic"

# ── Summary ────────────────────────────────────────────────────────────────
unset MOCK_TARGET_DB 2>/dev/null || true
exit_with_summary "mesh-migrate"
