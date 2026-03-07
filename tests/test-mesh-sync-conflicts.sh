#!/usr/bin/env bash
# test-mesh-sync-conflicts.sh — DB conflict + mesh sync error handling tests
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
source "$SCRIPT_DIR/lib/test-helpers.sh"
auto_cleanup_temp_dir

DB_SYNC="$REPO_ROOT/scripts/mesh-db-sync-tasks.sh"
SYNC_ALL="$REPO_ROOT/scripts/mesh-sync-all.sh"

echo "=== test-mesh-sync-conflicts.sh ==="

mkdir -p "$TEST_TEMP_DIR/bin" "$TEST_TEMP_DIR/local/data" "$TEST_TEMP_DIR/local/config" "$TEST_TEMP_DIR/remote"

# Mock SSH: run sqlite3 queries against remote temp DB; simulate online/offline peers for mesh-sync-all.
cat >"$TEST_TEMP_DIR/bin/ssh" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
REMOTE_DB="${MOCK_REMOTE_DB:-/tmp/test-remote.db}"
skip=0; host=""; cmd_args=()
for a in "$@"; do
  [[ $skip -eq 1 ]] && { skip=0; continue; }
  [[ "$a" == "-o" ]] && { skip=1; continue; }
  [[ "$a" == -* ]] && continue
  [[ -z "$host" ]] && { host="$a"; continue; }
  cmd_args+=("$a")
done
cmd="${cmd_args[*]:-}"
[[ "${host#*@}" == "${MOCK_OFFLINE_HOST:-}" ]] && exit 124
[[ "$cmd" == "true" ]] && exit 0
if [[ "$cmd" == *"sqlite3"* ]]; then
  cmd="${cmd//~\/.claude\/data\/dashboard.db/$REMOTE_DB}"
  eval "$cmd"
  exit $?
fi
if [[ "$cmd" == *"log -1 --format='%ct'"* ]]; then echo "${MOCK_REMOTE_TS:-0}"; exit 0; fi
if [[ "$cmd" == *"log --oneline -1"* ]]; then echo "${MOCK_REMOTE_SHA:-deadbee}"; exit 0; fi
if [[ "$cmd" == *"git pull --ff-only"* || "$cmd" == *"git reset --hard"* ]]; then
  echo "SYNC_OK:${MOCK_SYNC_SHA:-deadbee} mock"
  exit 0
fi
exit 0
EOF
chmod +x "$TEST_TEMP_DIR/bin/ssh"

cat >"$TEST_TEMP_DIR/bin/scp" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
[[ "${MOCK_SCP_FAIL:-0}" == "1" ]] && { echo "mock scp failure" >&2; exit 1; }
exit 0
EOF
chmod +x "$TEST_TEMP_DIR/bin/scp"

cat >"$TEST_TEMP_DIR/bin/rsync" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
[[ "${MOCK_RSYNC_FAIL:-0}" == "1" ]] && { echo "mock rsync failure" >&2; exit 1; }
exit 0
EOF
chmod +x "$TEST_TEMP_DIR/bin/rsync"
export PATH="$TEST_TEMP_DIR/bin:$PATH"

make_db() {
  local db="$1"
  rm -f "$db"
  sqlite3 "$db" "
    CREATE TABLE plans (id INTEGER PRIMARY KEY, status TEXT, tasks_done INTEGER DEFAULT 0, tasks_total INTEGER DEFAULT 0);
    CREATE TABLE waves (id INTEGER PRIMARY KEY, wave_id TEXT, status TEXT, tasks_done INTEGER DEFAULT 0, tasks_total INTEGER DEFAULT 0, plan_id INTEGER);
    CREATE TABLE tasks (
      id INTEGER PRIMARY KEY, task_id TEXT, plan_id INTEGER, wave_id_fk INTEGER,
      status TEXT, validated_by TEXT, validated_at TEXT, completed_at TEXT, started_at TEXT,
      tokens INTEGER DEFAULT 0, executor_agent TEXT, executor_status TEXT, output_data TEXT
    );
    CREATE TABLE peer_heartbeats (peer_name TEXT PRIMARY KEY, last_seen INTEGER, load_json TEXT, capabilities TEXT);
  "
}

write_peers_conf() {
  local file="$1"; shift
  : >"$file"
  for p in "$@"; do
    cat >>"$file" <<EOF
[$p]
ssh_alias=$p
status=active
EOF
  done
}

run_db_sync() {
  local local_home="$1" peer="$2"
  CLAUDE_HOME="$local_home" PEERS_CONF="$local_home/config/peers.conf" bash "$DB_SYNC" --peer "$peer" >/dev/null 2>&1
}

# T1: Remote done wins over local in_progress
LOCAL_DB="$TEST_TEMP_DIR/local/data/dashboard.db"
REMOTE_DB="$TEST_TEMP_DIR/remote/dashboard.db"
make_db "$LOCAL_DB"; make_db "$REMOTE_DB"
write_peers_conf "$TEST_TEMP_DIR/local/config/peers.conf" "peer-a"
sqlite3 "$LOCAL_DB" "INSERT INTO plans VALUES (1,'doing',0,1); INSERT INTO waves VALUES (1,'W1','doing',0,1,1);
  INSERT INTO tasks (id,task_id,plan_id,wave_id_fk,status,validated_at) VALUES (101,'T1',1,1,'in_progress','');"
sqlite3 "$REMOTE_DB" "INSERT INTO plans VALUES (1,'doing',1,1); INSERT INTO waves VALUES (1,'W1','done',1,1,1);
  INSERT INTO tasks (id,task_id,plan_id,wave_id_fk,status,validated_by,validated_at,completed_at) VALUES
  (101,'T1',1,1,'done','thor','2026-01-01T10:00:00Z','2026-01-01T10:00:00Z');"
export MOCK_REMOTE_DB="$REMOTE_DB"
run_db_sync "$TEST_TEMP_DIR/local" "peer-a"
s1=$(sqlite3 "$LOCAL_DB" "SELECT status FROM tasks WHERE id=101;")
v1=$(sqlite3 "$LOCAL_DB" "SELECT validated_at FROM tasks WHERE id=101;")
[[ "$s1" == "done" && "$v1" == "2026-01-01T10:00:00Z" ]] && pass "T1: remote done overrides local in_progress" || fail "T1: remote done override failed" "done + validated_at" "$s1 / $v1"

# T2: Most recent validated_at wins (local newer than remote should remain)
make_db "$LOCAL_DB"; make_db "$REMOTE_DB"
write_peers_conf "$TEST_TEMP_DIR/local/config/peers.conf" "peer-a"
sqlite3 "$LOCAL_DB" "INSERT INTO plans VALUES (1,'doing',1,1); INSERT INTO waves VALUES (1,'W1','done',1,1,1);
  INSERT INTO tasks (id,task_id,plan_id,wave_id_fk,status,validated_by,validated_at) VALUES
  (102,'T2',1,1,'done','local','2026-02-01T12:00:00Z');"
sqlite3 "$REMOTE_DB" "INSERT INTO plans VALUES (1,'doing',1,1); INSERT INTO waves VALUES (1,'W1','done',1,1,1);
  INSERT INTO tasks (id,task_id,plan_id,wave_id_fk,status,validated_by,validated_at) VALUES
  (102,'T2',1,1,'done','remote','2026-01-01T12:00:00Z');"
export MOCK_REMOTE_DB="$REMOTE_DB"
run_db_sync "$TEST_TEMP_DIR/local" "peer-a"
v2=$(sqlite3 "$LOCAL_DB" "SELECT validated_at FROM tasks WHERE id=102;")
[[ "$v2" == "2026-02-01T12:00:00Z" ]] && pass "T2: most recent validated_at kept" || fail "T2: validated_at recency failed" "2026-02-01T12:00:00Z" "$v2"

# T3: Cancelled is irreversible
make_db "$LOCAL_DB"; make_db "$REMOTE_DB"
write_peers_conf "$TEST_TEMP_DIR/local/config/peers.conf" "peer-a"
sqlite3 "$LOCAL_DB" "INSERT INTO plans VALUES (1,'doing',0,1); INSERT INTO waves VALUES (1,'W1','doing',0,1,1);
  INSERT INTO tasks (id,task_id,plan_id,wave_id_fk,status) VALUES (103,'T3',1,1,'in_progress');"
sqlite3 "$REMOTE_DB" "INSERT INTO plans VALUES (1,'doing',1,1); INSERT INTO waves VALUES (1,'W1','done',1,1,1);
  INSERT INTO tasks (id,task_id,plan_id,wave_id_fk,status,validated_at) VALUES (103,'T3',1,1,'cancelled','2026-03-01T00:00:00Z');"
export MOCK_REMOTE_DB="$REMOTE_DB"
run_db_sync "$TEST_TEMP_DIR/local" "peer-a"
s3=$(sqlite3 "$LOCAL_DB" "SELECT status FROM tasks WHERE id=103;")
[[ "$s3" == "cancelled" ]] && pass "T3: cancelled from remote wins" || fail "T3: cancelled irreversibility failed" "cancelled" "$s3"

# Prepare a local git repo for mesh-sync-all phase repos
mkdir -p "$TEST_TEMP_DIR/repo"
git -C "$TEST_TEMP_DIR/repo" init >/dev/null 2>&1
git -C "$TEST_TEMP_DIR/repo" config user.email test@example.com
git -C "$TEST_TEMP_DIR/repo" config user.name tester
echo "hello" >"$TEST_TEMP_DIR/repo/a.txt"
git -C "$TEST_TEMP_DIR/repo" add a.txt && git -C "$TEST_TEMP_DIR/repo" commit -m init >/dev/null 2>&1

cat >"$TEST_TEMP_DIR/local/config/repos.conf" <<EOF
[sample]
path=$TEST_TEMP_DIR/repo
branch=master
sync_files=a.txt
EOF

# T4: Phase 2 failure isolation (SCP failure reported, not fatal; pre-existing phase1 state preserved)
write_peers_conf "$TEST_TEMP_DIR/local/config/peers.conf" "peer-online"
echo "phase1-ok" >"$TEST_TEMP_DIR/local/config-state.txt"
export MOCK_REMOTE_TS=0 MOCK_REMOTE_SHA=aaa1111 MOCK_SYNC_SHA=bbb2222 MOCK_SCP_FAIL=1 MOCK_OFFLINE_HOST=""
out4=$(CLAUDE_HOME="$TEST_TEMP_DIR/local" PEERS_CONF="$TEST_TEMP_DIR/local/config/peers.conf" bash "$SYNC_ALL" --phase repos 2>&1); ec4=$?
state4=$(cat "$TEST_TEMP_DIR/local/config-state.txt")
[[ "$ec4" -eq 0 && "$state4" == "phase1-ok" && "$out4" == *"SCP FAIL"* ]] && pass "T4: phase2 failure isolated and non-fatal" || fail "T4: phase2 failure isolation failed" "exit=0,state preserved,SCP FAIL log" "exit=$ec4 state=$state4"

# T5: Offline peer skipped while online peer syncs
write_peers_conf "$TEST_TEMP_DIR/local/config/peers.conf" "peer-online" "peer-offline"
export MOCK_SCP_FAIL=0 MOCK_OFFLINE_HOST="peer-offline" MOCK_SYNC_SHA="ccc3333"
out5=$(CLAUDE_HOME="$TEST_TEMP_DIR/local" PEERS_CONF="$TEST_TEMP_DIR/local/config/peers.conf" bash "$SYNC_ALL" --phase repos 2>&1); ec5=$?
[[ "$ec5" -eq 0 && "$out5" == *"peer-offline"*OFFLINE* && "$out5" == *"→ peer-online"* ]] && pass "T5: offline peer warned; online peer synced" || fail "T5: offline-peer handling failed" "offline warning + online sync + exit0" "exit=$ec5"

# T6: DB integrity post-sync (no orphan tasks or waves)
make_db "$LOCAL_DB"; make_db "$REMOTE_DB"
write_peers_conf "$TEST_TEMP_DIR/local/config/peers.conf" "peer-a"
sqlite3 "$LOCAL_DB" "INSERT INTO plans VALUES (7,'doing',0,2); INSERT INTO waves VALUES (70,'W7','doing',0,2,7);
  INSERT INTO tasks (id,task_id,plan_id,wave_id_fk,status) VALUES (701,'T6a',7,70,'in_progress'),(702,'T6b',7,70,'pending');"
sqlite3 "$REMOTE_DB" "INSERT INTO plans VALUES (7,'doing',1,2); INSERT INTO waves VALUES (70,'W7','doing',1,2,7);
  INSERT INTO tasks (id,task_id,plan_id,wave_id_fk,status,validated_at) VALUES (701,'T6a',7,70,'done','2026-04-01T00:00:00Z');"
export MOCK_REMOTE_DB="$REMOTE_DB"
run_db_sync "$TEST_TEMP_DIR/local" "peer-a"
orph_tasks=$(sqlite3 "$LOCAL_DB" "SELECT COUNT(*) FROM tasks t LEFT JOIN waves w ON t.wave_id_fk=w.id WHERE w.id IS NULL;")
orph_waves=$(sqlite3 "$LOCAL_DB" "SELECT COUNT(*) FROM waves w LEFT JOIN plans p ON w.plan_id=p.id WHERE p.id IS NULL;")
[[ "$orph_tasks" -eq 0 && "$orph_waves" -eq 0 ]] && pass "T6: no orphan tasks/waves after sync" || fail "T6: referential integrity check failed" "0 orphan tasks/waves" "tasks=$orph_tasks waves=$orph_waves"

unset MOCK_REMOTE_DB MOCK_REMOTE_TS MOCK_REMOTE_SHA MOCK_SYNC_SHA MOCK_SCP_FAIL MOCK_RSYNC_FAIL MOCK_OFFLINE_HOST 2>/dev/null || true
exit_with_summary "mesh-sync-conflicts"
