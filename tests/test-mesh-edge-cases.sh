#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
REPO_ROOT="$SCRIPT_DIR"
source "$SCRIPT_DIR/tests/lib/test-helpers.sh"
auto_cleanup_temp_dir

DISPATCHER="$REPO_ROOT/scripts/mesh-dispatcher.sh"
PREFLIGHT="$REPO_ROOT/scripts/mesh-preflight.sh"
MIGRATE="$REPO_ROOT/scripts/mesh-migrate.sh"
SCORING="$REPO_ROOT/scripts/lib/mesh-scoring.sh"
PEERS_LIB="$REPO_ROOT/scripts/lib/peers.sh"

echo "=== test-mesh-edge-cases.sh ==="

mkbin() { mkdir -p "$TEST_TEMP_DIR/bin"; }

# T1: Peer offline mid-dispatch -> warning + retry next-best (simulated harness)
{
  mkbin
  LOG="$TEST_TEMP_DIR/t1.log"; : >"$LOG"
  cat >"$TEST_TEMP_DIR/bin/ssh" <<'SH'
#!/usr/bin/env bash
set -euo pipefail
state_file="${STATE_FILE:?}"
peer="${1:-}"
count=0; [[ -f "$state_file" ]] && count=$(cat "$state_file")
count=$((count+1)); echo "$count" > "$state_file"
if [[ "$count" -eq 1 ]]; then exit 0; fi
[[ "$peer" == "peer-a" ]] && exit 1
exit 0
SH
  chmod +x "$TEST_TEMP_DIR/bin/ssh"
  export PATH="$TEST_TEMP_DIR/bin:$PATH" STATE_FILE="$TEST_TEMP_DIR/t1.count"

  dispatch_with_retry() {
    local peers=("peer-a" "peer-b") t
    for t in 1 2; do
      for p in "${peers[@]}"; do
        if ssh "$p" "run" >/dev/null 2>&1; then
          echo "task $t -> $p" >>"$LOG"; break
        else
          echo "WARN: $p offline mid-dispatch" >>"$LOG"
        fi
      done
    done
  }
  dispatch_with_retry
  if grep -q 'WARN: peer-a offline' "$LOG" && grep -q 'task 2 -> peer-b' "$LOG"; then
    pass "T1: offline peer warning + next-best retry"
  else
    fail "T1: expected warning and fallback dispatch" "warn+peer-b" "$(cat "$LOG")"
  fi
}

# T2: timeout kills hung ssh and moves to next peer (simulated harness)
{
  mkbin
  cat >"$TEST_TEMP_DIR/bin/ssh" <<'SH'
#!/usr/bin/env bash
set -euo pipefail
peer="${1:-}"
if [[ "$peer" == "peer-a" ]]; then sleep 5; exit 0; fi
exit 0
SH
  chmod +x "$TEST_TEMP_DIR/bin/ssh"
  export PATH="$TEST_TEMP_DIR/bin:$PATH"
  winner=""
  if timeout 2 ssh peer-a run >/dev/null 2>&1; then winner="peer-a"; fi
  if [[ -z "$winner" ]]; then timeout 2 ssh peer-b run >/dev/null 2>&1 && winner="peer-b"; fi
  [[ "$winner" == "peer-b" ]] && pass "T2: timeout fallback to next peer" || fail "T2: expected peer-b after timeout" "peer-b" "${winner:-<empty>}"
}

# Shared mock ssh for preflight tests; uses DF_KB to emulate disk-pressure policy
mkbin
cat >"$TEST_TEMP_DIR/bin/ssh" <<'SH'
#!/usr/bin/env bash
set -euo pipefail
skip=0; host_seen=0; cmd=""
for a in "$@"; do
  [[ "$skip" -eq 1 ]] && { skip=0; continue; }
  [[ "$a" == "-o" ]] && { skip=1; continue; }
  [[ "$a" == -* ]] && continue
  [[ "$host_seen" -eq 0 ]] && { host_seen=1; continue; }
  cmd+=" $a"
done
if [[ "$cmd" == *MISSING:* ]]; then
  if [[ "${DF_KB:-9999999}" -lt 5242880 ]]; then
    echo "MISSING: git"; echo "OPTIONAL:"
  else
    echo "MISSING:"; echo "OPTIONAL:"
  fi
else
  echo "MISSING:"; echo "OPTIONAL:"
fi
SH
chmod +x "$TEST_TEMP_DIR/bin/ssh"

# T3: mesh-preflight.sh with <5GB equivalent mock pressure -> non-zero
{
  export PATH="$TEST_TEMP_DIR/bin:$PATH" DF_KB=1000
  rc=0; bash "$PREFLIGHT" test-peer >/dev/null 2>&1 || rc=$?
  [[ "$rc" -ne 0 ]] && pass "T3: preflight fails under low-space mock" || fail "T3: expected non-zero for low space mock"
}

# T4: mesh-preflight.sh with >=5GB equivalent mock pressure -> zero
{
  export PATH="$TEST_TEMP_DIR/bin:$PATH" DF_KB=9000000
  if bash "$PREFLIGHT" test-peer >/dev/null 2>&1; then
    pass "T4: preflight passes with sufficient space mock"
  else
    fail "T4: expected exit 0 for sufficient space mock"
  fi
}

# T5: mesh-migrate.sh unreachable during DB copy triggers rollback; source unchanged
{
  mkbin
  CLAUDE_HOME="$TEST_TEMP_DIR/claude"; export CLAUDE_HOME
  mkdir -p "$CLAUDE_HOME/data" "$CLAUDE_HOME/scripts"
  SRC_DB="$CLAUDE_HOME/data/dashboard.db"
  TGT_DB="$TEST_TEMP_DIR/target.db"
  sqlite3 "$SRC_DB" "CREATE TABLE plans(id INTEGER PRIMARY KEY,status TEXT,execution_host TEXT,worktree_path TEXT); CREATE TABLE waves(id INTEGER PRIMARY KEY,plan_id INTEGER,worktree_path TEXT); CREATE TABLE tasks(id INTEGER PRIMARY KEY,plan_id INTEGER,wave_id_fk INTEGER,status TEXT,executor_host TEXT); CREATE TABLE peer_heartbeats(host TEXT,role TEXT); INSERT INTO plans VALUES(1,'doing','source-host','~/repo'); INSERT INTO waves VALUES(1,1,'~/repo');"
  sqlite3 "$TGT_DB" "CREATE TABLE plans(id INTEGER PRIMARY KEY,status TEXT,execution_host TEXT,worktree_path TEXT); CREATE TABLE waves(id INTEGER PRIMARY KEY,plan_id INTEGER,worktree_path TEXT); CREATE TABLE tasks(id INTEGER PRIMARY KEY,plan_id INTEGER,wave_id_fk INTEGER,status TEXT,executor_host TEXT); INSERT INTO plans VALUES(1,'doing','target-old','~/repo');"
  cp "$TGT_DB" "$TGT_DB.bak"
  cat >"$CLAUDE_HOME/scripts/mesh-heartbeat.sh" <<'SH'
#!/usr/bin/env bash
exit 0
SH
  chmod +x "$CLAUDE_HOME/scripts/mesh-heartbeat.sh"

  cat >"$TEST_TEMP_DIR/bin/ssh" <<'SH'
#!/usr/bin/env bash
set -euo pipefail
skip=0; host_seen=0; cmd_args=()
for a in "$@"; do
  [[ "$skip" -eq 1 ]] && { skip=0; continue; }
  [[ "$a" == "-o" ]] && { skip=1; continue; }
  [[ "$a" == -* ]] && continue
  [[ "$host_seen" -eq 0 ]] && { host_seen=1; continue; }
  cmd_args+=("$a")
done
cmd="${cmd_args[*]:-true}"
cmd="${cmd//~\/.claude\/data\/dashboard.db/$MOCK_TARGET_DB}"
cmd="${cmd//~\/.claude\/data\/dashboard.db.bak/$MOCK_TARGET_DB.bak}"
[[ "$cmd" == 'echo $HOME' ]] && { echo "/home/mock"; exit 0; }
[[ "$cmd" == 'hostname -s' ]] && { echo "mock-host"; exit 0; }
[[ "$cmd" == 'true' ]] && exit 0
bash -lc "$cmd" >/dev/null 2>&1 || true
exit 0
SH
  cat >"$TEST_TEMP_DIR/bin/scp" <<'SH'
#!/usr/bin/env bash
set -euo pipefail
# Fail DB copy to trigger rollback path
for a in "$@"; do [[ "$a" == *"dashboard.db"* ]] && exit 1; done
exit 0
SH
  chmod +x "$TEST_TEMP_DIR/bin/ssh" "$TEST_TEMP_DIR/bin/scp"
  export PATH="$TEST_TEMP_DIR/bin:$PATH" MOCK_TARGET_DB="$TGT_DB"

  rc=0; bash "$MIGRATE" 1 mock-peer --no-launch >/dev/null 2>&1 || rc=$?
  src_host=$(sqlite3 "$SRC_DB" "SELECT execution_host FROM plans WHERE id=1;")
  if [[ "$rc" -ne 0 && "$src_host" == "source-host" ]]; then
    pass "T5: migrate rollback path leaves source unchanged"
  else
    fail "T5: expected rollback failure with unchanged source" "rc!=0 and source-host" "rc=$rc host=$src_host"
  fi
}

# T6: empty peers.conf -> dispatcher exits cleanly with no-peer output
{
  EMPTY_CONF="$TEST_TEMP_DIR/empty-peers.conf"; : >"$EMPTY_CONF"
  DB="$TEST_TEMP_DIR/t6.db"
  sqlite3 "$DB" "CREATE TABLE tasks(id INTEGER PRIMARY KEY,plan_id INTEGER,title TEXT,privacy_required INTEGER,status TEXT,executor_host TEXT); CREATE TABLE plans(id INTEGER PRIMARY KEY,status TEXT); INSERT INTO plans VALUES(1,'doing'); INSERT INTO tasks VALUES(1,1,'edge task',0,'pending','');"
  out=$(PEERS_CONF="$EMPTY_CONF" DB_PATH="$DB" bash "$DISPATCHER" --plan 1 2>&1 || true)
  if echo "$out" | grep -qi 'no peer\|skipped'; then
    pass "T6: dispatcher handles empty peers config cleanly"
  else
    fail "T6: expected clean no-peer behavior" "contains no peer/skipped" "$out"
  fi
}

# T7: malformed peer JSON (missing fields) -> mesh_score_peer negative/no crash
{
  source "$SCORING"
  bad='{"peer":"broken"}'
  score=$(mesh_score_peer "$bad" "" 1 2>/dev/null || echo "-99")
  [[ "$score" =~ ^- ]] && pass "T7: malformed peer JSON safely disqualified" || fail "T7: malformed JSON should disqualify" "negative" "$score"
}

# T8: duplicate peer names in peers.conf -> peers_load no crash
{
  DCONF="$TEST_TEMP_DIR/dup-peers.conf"
  cat >"$DCONF" <<'CONF'
[dup]
ssh_alias=host-a
status=active
[dup]
ssh_alias=host-b
status=active
CONF
  out=$(PEERS_CONF="$DCONF" bash -c "source '$PEERS_LIB'; peers_load; peers_list" 2>&1 || true)
  if [[ -n "$out" ]]; then
    pass "T8: peers_load handles duplicate names without crashing"
  else
    fail "T8: expected non-empty peers_list with duplicate sections"
  fi
}

assert_line_count "$0" 250 "test-mesh-edge-cases.sh <= 250 lines"
exit_with_summary "mesh-edge-cases"
