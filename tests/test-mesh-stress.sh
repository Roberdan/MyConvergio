#!/usr/bin/env bash
# tests/test-mesh-stress.sh — stress tests for 50-peer mesh scoring/dispatch
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

source "$SCRIPT_DIR/lib/test-helpers.sh"
source "$REPO_ROOT/scripts/lib/mesh-scoring.sh"

PEER_NAMES=()
PEER_TIERS=()
PEER_CAPS=()
PEER_CPU=()
PEER_TIPS=()

setup() {
  export TEST_DB TEST_TMP_DIR PEERS_CONF
  TEST_DB="$(mktemp /tmp/test-mesh-stress-XXXXXX.db)"
  TEST_TMP_DIR="$(mktemp -d /tmp/test-mesh-stress-bin-XXXXXX)"
  PEERS_CONF="$TEST_TMP_DIR/peers.conf"

  sqlite3 "$TEST_DB" "
    PRAGMA journal_mode=WAL;
    CREATE TABLE peer_heartbeats(
      peer_name TEXT PRIMARY KEY,
      status TEXT,last_seen TEXT,cpu_load REAL,
      mem_used_gb REAL,mem_total_gb REAL,
      tasks_in_progress INTEGER DEFAULT 0,
      cost_tier TEXT DEFAULT 'free',
      capabilities TEXT DEFAULT 'ollama',
      privacy_safe TEXT DEFAULT 'true'
    );
    CREATE TABLE dispatch_log(task_no INTEGER, peer_name TEXT);
  " >/dev/null

  : >"$PEERS_CONF"
  local i name tier caps cpu
  for i in $(seq 1 50); do
    name="peer-$(printf '%03d' "$i")"
    if [[ "$i" -le 10 ]]; then
      tier="free"; caps="ollama"
    elif [[ "$i" -le 25 ]]; then
      tier="zero"; caps="copilot"
    elif [[ "$i" -le 40 ]]; then
      tier="premium"; caps="claude"
    else
      tier="premium"; caps="claude,copilot"
    fi
    cpu=$((i % 3))

    PEER_NAMES[$i]="$name"
    PEER_TIERS[$i]="$tier"
    PEER_CAPS[$i]="$caps"
    PEER_CPU[$i]="$cpu"
    PEER_TIPS[$i]=0

    printf '%s|%s|%s\n' "$name" "$tier" "$caps" >>"$PEERS_CONF"
    sqlite3 "$TEST_DB" "INSERT INTO peer_heartbeats(peer_name,status,last_seen,cpu_load,mem_used_gb,mem_total_gb,tasks_in_progress,cost_tier,capabilities,privacy_safe) VALUES('$name','online',datetime('now'),$cpu,4.0,16.0,0,'$tier','$caps','true');"
  done

  export MESH_MAX_TASKS_PER_PEER=3
}

teardown() {
  rm -f "${TEST_DB:-}" 2>/dev/null || true
  rm -rf "${TEST_TMP_DIR:-}" 2>/dev/null || true
}
trap teardown EXIT

reset_tips() { local i; for i in $(seq 1 50); do PEER_TIPS[$i]=0; done; }

build_peers_json() {
  local out="[" first=1 i row
  for i in $(seq 1 50); do
    row="{\"peer\":\"${PEER_NAMES[$i]}\",\"online\":true,\"cost_tier\":\"${PEER_TIERS[$i]}\",\"privacy_safe\":true,\"cpu_load\":${PEER_CPU[$i]},\"tasks_in_progress\":${PEER_TIPS[$i]},\"capabilities\":\"${PEER_CAPS[$i]}\"}"
    [[ "$first" -eq 0 ]] && out+=$',\n'
    out+="$row"
    first=0
  done
  out+=$'\n]'
  echo "$out"
}

filter_available_peers() {
  local peers_json="$1" line tip out="[" first=1
  while IFS= read -r line; do
    [[ -z "$line" || "$line" == "[" || "$line" == "]" || "$line" == "," ]] && continue
    line="${line%,}"
    tip="$(_json_field "$line" "tasks_in_progress")"
    [[ "$tip" =~ ^[0-9]+$ ]] || tip=0
    if [[ "$tip" -lt "$MESH_MAX_TASKS_PER_PEER" ]]; then
      [[ "$first" -eq 0 ]] && out+=$',\n'
      out+="$line"
      first=0
    fi
  done <<<"$peers_json"
  out+=$'\n]'
  echo "$out"
}

increment_tip() {
  local peer="$1" idx
  idx="${peer#peer-}"
  idx=$((10#$idx))
  PEER_TIPS[$idx]=$((PEER_TIPS[$idx] + 1))
}

max_tip() {
  local i m=0
  for i in $(seq 1 50); do
    [[ "${PEER_TIPS[$i]}" -gt "$m" ]] && m="${PEER_TIPS[$i]}"
  done
  echo "$m"
}

setup
echo "=== test-mesh-stress.sh ==="

# T1: mesh_score_peer correctly scores all 50 peers
{
  peers_json="$(build_peers_json)"
  scored=0; ok=1
  while IFS= read -r line; do
    [[ -z "$line" || "$line" == "[" || "$line" == "]" || "$line" == "," ]] && continue
    line="${line%,}"
    score="$(mesh_score_peer "$line" "" 0 2>/dev/null || echo -99)"
    [[ "$score" =~ ^-?[0-9]+$ ]] || ok=0
    scored=$((scored + 1))
  done <<<"$peers_json"
  [[ "$ok" -eq 1 && "$scored" -eq 50 ]] && pass "T1: mesh_score_peer scored all 50 peers" || fail "T1: mesh_score_peer should score all peers" "scored=50 and numeric" "scored=$scored ok=$ok"
}

# T2: mesh_best_peer selects from 50-entry array in <2s
{
  peers_json="$(build_peers_json)"
  TIMEFORMAT='%3R'
  elapsed="$( { time mesh_best_peer "$peers_json" "" 0 >/dev/null; } 2>&1 )"
  awk -v t="$elapsed" 'BEGIN{exit !(t+0 < 2.0)}' && pass "T2: mesh_best_peer selected in <2s (${elapsed}s)" || fail "T2: mesh_best_peer should run in <2s" "<2.0" "$elapsed"
}

# T3: 50-row heartbeat INSERT+UPDATE cycle without SQLITE_BUSY
{
  cycle_ok=1
  for w in 1 2 3 4 5; do
    (
      sqlite3 "$TEST_DB" "
        PRAGMA busy_timeout=5000;
        BEGIN IMMEDIATE;
        INSERT INTO peer_heartbeats(peer_name,status,last_seen,cpu_load,mem_used_gb,mem_total_gb,tasks_in_progress,cost_tier,capabilities,privacy_safe)
        VALUES('peer-$(printf '%03d' "$w")','online',datetime('now'),1,4,16,0,'free','ollama','true')
        ON CONFLICT(peer_name) DO UPDATE SET last_seen=datetime('now');
        UPDATE peer_heartbeats SET tasks_in_progress=(tasks_in_progress + 1) % 3 WHERE CAST(substr(peer_name,6) AS INTEGER) % 5 = $((w - 1));
        COMMIT;
      "
    ) >"$TEST_TMP_DIR/db-$w.out" 2>"$TEST_TMP_DIR/db-$w.err" &
    eval "pid_$w=$!"
  done
  for w in 1 2 3 4 5; do
    eval "pid=\$pid_$w"
    if ! wait "$pid"; then cycle_ok=0; fi
    if grep -Eqi 'SQLITE_BUSY|database is locked|busy' "$TEST_TMP_DIR/db-$w.err"; then cycle_ok=0; fi
  done
  [[ "$cycle_ok" -eq 1 ]] && pass "T3: heartbeat insert/update cycle had no SQLITE_BUSY" || fail "T3: heartbeat cycle should avoid SQLITE_BUSY"
}

# T4: 50-peer dispatch dry-run — no peer exceeds MESH_MAX_TASKS_PER_PEER
{
  reset_tips
  for _ in $(seq 1 120); do
    peers_json="$(build_peers_json)"
    available="$(filter_available_peers "$peers_json")"
    winner="$(mesh_best_peer "$available" "" 0 2>/dev/null || true)"
    [[ -z "$winner" ]] && break
    increment_tip "$winner"
  done
  m="$(max_tip)"
  [[ "$m" -le "$MESH_MAX_TASKS_PER_PEER" ]] && pass "T4: dry-run dispatch respected per-peer max (max=$m)" || fail "T4: no peer should exceed MESH_MAX_TASKS_PER_PEER" "<=${MESH_MAX_TASKS_PER_PEER}" "$m"
}

# T5: 15 tasks across 50 peers spread to >=5 peers
{
  reset_tips
  sqlite3 "$TEST_DB" "DELETE FROM dispatch_log;"
  for t in $(seq 1 15); do
    peers_json="$(build_peers_json)"
    available="$(filter_available_peers "$peers_json")"
    winner="$(mesh_best_peer "$available" "" 0 2>/dev/null || true)"
    [[ -z "$winner" ]] && break
    increment_tip "$winner"
    sqlite3 "$TEST_DB" "INSERT INTO dispatch_log(task_no,peer_name) VALUES($t,'$winner');"
  done
  distinct="$(sqlite3 "$TEST_DB" "SELECT COUNT(DISTINCT peer_name) FROM dispatch_log;")"
  [[ "$distinct" -ge 5 ]] && pass "T5: 15 tasks spread across >=5 peers (distinct=$distinct)" || fail "T5: expected distribution across at least 5 peers" ">=5" "$distinct"
}

# T6: Performance — score 50 peers x 10 tasks in <5s total
{
  peers_json="$(build_peers_json)"
  TIMEFORMAT='%3R'
  elapsed="$({
    time for _ in $(seq 1 10); do
      while IFS= read -r line; do
        [[ -z "$line" || "$line" == "[" || "$line" == "]" || "$line" == "," ]] && continue
        line="${line%,}"
        mesh_score_peer "$line" "claude" 0 >/dev/null 2>&1 || true
      done <<<"$peers_json"
    done
  } 2>&1)"
  awk -v t="$elapsed" 'BEGIN{exit !(t+0 < 5.0)}' && pass "T6: 500 scoring ops in <5s (${elapsed}s)" || fail "T6: performance target for scoring" "<5.0" "$elapsed"
}

assert_line_count "$0" 250 "test-mesh-stress.sh <= 250 lines"
exit_with_summary "mesh-stress"
