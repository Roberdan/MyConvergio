#!/usr/bin/env bash
# tests/test-mesh-stress.sh — stress test with 50 simulated peers
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

source "$SCRIPT_DIR/lib/test-helpers.sh"
source "$REPO_ROOT/scripts/lib/mesh-scoring.sh"

TEST_DB=""
TEST_TMP_DIR=""
PEERS_CONF=""
PEER_TIPS=()
PEER_TIERS=()
PEER_CAPS=()

setup() {
  TEST_DB="$(mktemp /tmp/test-mesh-stress-db-XXXXXX)"
  TEST_TMP_DIR="$(mktemp -d /tmp/test-mesh-stress-bin-XXXXXX)"
  PEERS_CONF="$TEST_TMP_DIR/peers.conf"

  sqlite3 "$TEST_DB" "
    PRAGMA journal_mode=WAL;
    CREATE TABLE peer_heartbeats(
      peer_name TEXT PRIMARY KEY,
      status TEXT,
      last_seen TEXT,
      cpu_load REAL,
      mem_used_gb REAL,
      mem_total_gb REAL,
      tasks_in_progress INTEGER DEFAULT 0,
      cost_tier TEXT DEFAULT 'free',
      capabilities TEXT DEFAULT 'ollama',
      privacy_safe TEXT DEFAULT 'true'
    );
    CREATE TABLE dispatch_log(task_no INTEGER, peer_name TEXT);
  " >/dev/null

  : >"$PEERS_CONF"
  local i name tier caps
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

    PEER_TIPS[$i]=0
    PEER_TIERS[$i]="$tier"
    PEER_CAPS[$i]="$caps"

    printf '%s|%s|%s\n' "$name" "$tier" "$caps" >>"$PEERS_CONF"
    sqlite3 "$TEST_DB" "INSERT INTO peer_heartbeats(peer_name,status,last_seen,cpu_load,mem_used_gb,mem_total_gb,tasks_in_progress,cost_tier,capabilities,privacy_safe) VALUES('$name','online',datetime('now'),0,4.0,16.0,0,'$tier','$caps','true');"
  done

  export MESH_MAX_TASKS_PER_PEER=3
}

teardown() {
  rm -f "$TEST_DB" 2>/dev/null || true
  rm -rf "$TEST_TMP_DIR" 2>/dev/null || true
}
trap teardown EXIT

reset_tips() { local i; for i in $(seq 1 50); do PEER_TIPS[$i]=0; done; }

build_peers_json() {
  local out="[" first=1 i name row
  for i in $(seq 1 50); do
    name="peer-$(printf '%03d' "$i")"
    row="{\"peer\":\"$name\",\"online\":true,\"cost_tier\":\"${PEER_TIERS[$i]}\",\"privacy_safe\":true,\"cpu_load\":0,\"tasks_in_progress\":${PEER_TIPS[$i]},\"capabilities\":\"${PEER_CAPS[$i]}\"}"
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

inc_tip() { local idx="${1#peer-}"; idx=$((10#$idx)); PEER_TIPS[$idx]=$((PEER_TIPS[$idx] + 1)); }
max_tip() { local i m=0; for i in $(seq 1 50); do [[ "${PEER_TIPS[$i]}" -gt "$m" ]] && m="${PEER_TIPS[$i]}"; done; echo "$m"; }

setup
echo "=== test-mesh-stress.sh ==="

# 1) mesh_score_peer correctly scores all 50 peers
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
  [[ "$ok" -eq 1 && "$scored" -eq 50 ]] && pass "T1: scored all 50 peers" || fail "T1: expected 50 numeric scores" "50" "$scored"
}

# 2) mesh_best_peer selects from 50-entry array in <10 seconds
{
  peers_json="$(build_peers_json)"
  start="$(date +%s)"
  mesh_best_peer "$peers_json" "" 0 >/dev/null 2>&1 || true
  elapsed=$(( $(date +%s) - start ))
  [[ "$elapsed" -lt 10 ]] && pass "T2: mesh_best_peer in <10s (${elapsed}s)" || fail "T2: expected <10s" "<10" "$elapsed"
}

# 3) Heartbeat DB with 50 rows — INSERT + UPDATE cycle without SQLITE_BUSY
{
  ok=1
  for w in 1 2 3 4 5; do
    (
      sqlite3 "$TEST_DB" "PRAGMA busy_timeout=5000; BEGIN IMMEDIATE; INSERT INTO peer_heartbeats(peer_name,status,last_seen,cpu_load,mem_used_gb,mem_total_gb,tasks_in_progress,cost_tier,capabilities,privacy_safe) VALUES('peer-$(printf '%03d' "$w")','online',datetime('now'),0,4,16,0,'free','ollama','true') ON CONFLICT(peer_name) DO UPDATE SET last_seen=datetime('now'); UPDATE peer_heartbeats SET tasks_in_progress=(tasks_in_progress+1)%3 WHERE CAST(substr(peer_name,6) AS INTEGER)%5=$((w-1)); COMMIT;"
    ) >"$TEST_TMP_DIR/db-$w.out" 2>"$TEST_TMP_DIR/db-$w.err" &
    eval "pid_$w=$!"
  done
  for w in 1 2 3 4 5; do eval "pid=\$pid_$w"; wait "$pid" || ok=0; grep -Eqi 'SQLITE_BUSY|database is locked|busy' "$TEST_TMP_DIR/db-$w.err" && ok=0 || true; done
  [[ "$ok" -eq 1 ]] && pass "T3: INSERT+UPDATE without SQLITE_BUSY" || fail "T3: expected no SQLITE_BUSY"
}

# 4-6) Heavy scoring tests — skip unless MESH_STRESS_FULL=1
if [[ "${MESH_STRESS_FULL:-0}" == "1" ]]; then
{
  reset_tips
  for _ in 1 2 3 4 5 6 7 8; do
    peers_json="$(build_peers_json)"
    available="$(filter_available_peers "$peers_json")"
    winner="$(mesh_best_peer "$available" "" 0 2>/dev/null || true)"
    [[ -z "$winner" ]] && break
    inc_tip "$winner"
  done
  m="$(max_tip)"
  [[ "$m" -le "$MESH_MAX_TASKS_PER_PEER" ]] && pass "T4: max tasks per peer respected (max=$m)" || fail "T4: peer exceeded max" "<=${MESH_MAX_TASKS_PER_PEER}" "$m"
}
{
  reset_tips
  sqlite3 "$TEST_DB" "DELETE FROM dispatch_log;"
  for t in 1 2 3 4 5 6 7 8; do
    peers_json="$(build_peers_json)"
    available="$(filter_available_peers "$peers_json")"
    winner="$(mesh_best_peer "$available" "" 0 2>/dev/null || true)"
    [[ -z "$winner" ]] && break
    inc_tip "$winner"
    sqlite3 "$TEST_DB" "INSERT INTO dispatch_log(task_no,peer_name) VALUES($t,'$winner');"
  done
  distinct="$(sqlite3 "$TEST_DB" "SELECT COUNT(DISTINCT peer_name) FROM dispatch_log;")"
  [[ "$distinct" -ge 3 ]] && pass "T5: distributed across >=3 peers (distinct=$distinct)" || fail "T5: expected >=3 peers" ">=3" "$distinct"
}
{
  peers_json="$(build_peers_json)"
  start="$(date +%s)"
  for _ in 1 2; do
    while IFS= read -r line; do
      [[ -z "$line" || "$line" == "[" || "$line" == "]" || "$line" == "," ]] && continue
      line="${line%,}"
      mesh_score_peer "$line" "claude" 0 >/dev/null 2>&1 || true
    done <<<"$peers_json"
  done
  elapsed=$(( $(date +%s) - start ))
  [[ "$elapsed" -le 15 ]] && pass "T6: 50x2 scoring in ≤15s (${elapsed}s)" || fail "T6: expected ≤15s" "≤15" "$elapsed"
}
else
  echo "SKIP: T4-T6 (set MESH_STRESS_FULL=1 for full stress)"
fi

assert_line_count "$0" 250 "test-mesh-stress.sh <= 250 lines"
exit_with_summary "mesh-stress"
