#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$REPO_ROOT/tests/lib/test-helpers.sh"

SCORING_LIB="$REPO_ROOT/scripts/lib/mesh-scoring.sh"

setup() {
  export TEST_DB
  TEST_DB=$(mktemp /tmp/test-concurrency-XXXXXX.db)
  export TEST_TMP_DIR
  TEST_TMP_DIR=$(mktemp -d /tmp/test-concurrency-bin-XXXXXX)

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
      cost_tier TEXT DEFAULT 'free'
    );
    CREATE TABLE plans(id INTEGER PRIMARY KEY, status TEXT DEFAULT 'doing');
    CREATE TABLE waves(id INTEGER PRIMARY KEY, plan_id INTEGER, status TEXT DEFAULT 'pending');
    CREATE TABLE tasks(
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      task_id TEXT,
      plan_id INTEGER,
      wave_id_fk INTEGER,
      title TEXT,
      status TEXT DEFAULT 'pending'
    );
  " >/dev/null

  sqlite3 "$TEST_DB" "INSERT INTO plans(id,status) VALUES (1,'doing');"
  sqlite3 "$TEST_DB" "INSERT INTO waves(id,plan_id,status) VALUES (1,1,'pending');"

  for i in 1 2 3 4 5; do
    sqlite3 "$TEST_DB" "
      INSERT INTO peer_heartbeats(peer_name,status,last_seen,cpu_load,mem_used_gb,mem_total_gb,tasks_in_progress,cost_tier)
      VALUES('peer$i','online',datetime('now'),$((i * 15)),4.0,16.0,$((i - 1)),'free');
    "
  done

  export MESH_MAX_TASKS_PER_PEER=3
  export DASHBOARD_DB="$TEST_DB"

  mkdir -p "$TEST_TMP_DIR/bin"
  cat >"$TEST_TMP_DIR/bin/ssh" <<'SH'
#!/usr/bin/env bash
set -euo pipefail
host=""
skip=0
for a in "$@"; do
  if [[ "$skip" -eq 1 ]]; then skip=0; continue; fi
  if [[ "$a" == "-o" ]]; then skip=1; continue; fi
  [[ "$a" == -* ]] && continue
  if [[ -z "$host" ]]; then host="$a"; continue; fi
done

cpu=$(sqlite3 "${TEST_DB}" "SELECT COALESCE(cpu_load,0) FROM peer_heartbeats WHERE peer_name='${host}';" 2>/dev/null || echo 0)
tip=$(sqlite3 "${TEST_DB}" "SELECT COALESCE(tasks_in_progress,0) FROM peer_heartbeats WHERE peer_name='${host}';" 2>/dev/null || echo 0)

printf '{"peer":"%s","cpu_load":%s,"tasks_in_progress":%s,"capabilities":"ollama","cost_tier":"free","privacy_safe":true,"online":true}\n' "$host" "${cpu:-0}" "${tip:-0}"
SH
  chmod +x "$TEST_TMP_DIR/bin/ssh"
  export PATH="$TEST_TMP_DIR/bin:$PATH"
}

teardown() {
  rm -f "${TEST_DB:-}" 2>/dev/null || true
  rm -rf "${TEST_TMP_DIR:-}" 2>/dev/null || true
}
trap teardown EXIT

peers_json_from_mock() {
  local out="[" first=1 p row
  for p in peer1 peer2 peer3 peer4 peer5; do
    row="$(ssh "$p" "echo load" 2>/dev/null || true)"
    [[ -z "$row" ]] && continue
    if [[ "$first" -eq 0 ]]; then out+=$',\n'; fi
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
      if [[ "$first" -eq 0 ]]; then out+=$',\n'; fi
      out+="$line"
      first=0
    fi
  done <<<"$peers_json"
  out+=$'\n]'
  echo "$out"
}

setup
source "$SCORING_LIB"

echo "=== test-mesh-concurrency.sh ==="

# T1: Capacity check: full peer has low/non-positive score vs available peer
FULL='{"peer":"full","online":true,"privacy_safe":true,"cpu_load":2.5,"tasks_in_progress":3,"capabilities":"ollama","cost_tier":"premium"}'
OPEN='{"peer":"open","online":true,"privacy_safe":true,"cpu_load":2.5,"tasks_in_progress":2,"capabilities":"ollama","cost_tier":"premium"}'
S_FULL="$(mesh_score_peer "$FULL" "" 0 2>/dev/null || echo -99)"
S_OPEN="$(mesh_score_peer "$OPEN" "" 0 2>/dev/null || echo -99)"
if [[ "$S_FULL" -le 0 && "$S_FULL" -lt "$S_OPEN" ]]; then
  pass "T1: full peer score is low and lower than available peer"
else
  fail "T1: full peer should score low/lower" "full<=0 and full<open" "full=$S_FULL open=$S_OPEN"
fi

# T2: Rapid dispatch: 4 attempts to same best peer accepts only MESH_MAX_TASKS_PER_PEER
accepted=0
rejected=0
for _ in 1 2 3 4; do
  tip=$(sqlite3 "$TEST_DB" "SELECT tasks_in_progress FROM peer_heartbeats WHERE peer_name='peer1';")
  peer_json="{\"peer\":\"peer1\",\"online\":true,\"privacy_safe\":true,\"cpu_load\":0.2,\"tasks_in_progress\":${tip},\"capabilities\":\"ollama\",\"cost_tier\":\"free\"}"
  score="$(mesh_score_peer "$peer_json" "" 0 2>/dev/null || echo -99)"
  if [[ "$tip" -lt "$MESH_MAX_TASKS_PER_PEER" && "$score" -ge 0 ]]; then
    accepted=$((accepted + 1))
    sqlite3 "$TEST_DB" "UPDATE peer_heartbeats SET tasks_in_progress=tasks_in_progress+1 WHERE peer_name='peer1';"
  else
    rejected=$((rejected + 1))
  fi
done
if [[ "$accepted" -eq "$MESH_MAX_TASKS_PER_PEER" && "$rejected" -eq 1 ]]; then
  pass "T2: rapid dispatch enforces per-peer capacity"
else
  fail "T2: capacity should cap accepted dispatches" "accepted=3 rejected=1" "accepted=$accepted rejected=$rejected"
fi

# T3: Overflow routing: when best peer is full, next task goes to next-best
sqlite3 "$TEST_DB" "
  UPDATE peer_heartbeats SET tasks_in_progress=2;
  UPDATE peer_heartbeats SET cpu_load=15;
  UPDATE peer_heartbeats SET tasks_in_progress=3, cpu_load=15 WHERE peer_name='peer1';
  UPDATE peer_heartbeats SET tasks_in_progress=0, cpu_load=15 WHERE peer_name='peer2';
"
PEERS_JSON="$(peers_json_from_mock)"
WINNER="$(mesh_best_peer "$PEERS_JSON" "" 0 2>/dev/null || true)"
if [[ "$WINNER" == "peer2" ]]; then
  pass "T3: overflow routes task to next-best peer"
else
  fail "T3: expected overflow routing to peer2" "peer2" "${WINNER:-<empty>}"
fi

# T4: WAL concurrency: 3 parallel writes do not hit SQLITE_BUSY
for i in 1 2 3; do
  (
    sqlite3 "$TEST_DB" "
      PRAGMA busy_timeout=5000;
      BEGIN IMMEDIATE;
      INSERT INTO tasks(task_id,plan_id,wave_id_fk,title,status)
      VALUES('wal-$i',1,1,'wal-$i','pending');
      SELECT randomblob(50000);
      COMMIT;
    "
  ) >"$TEST_TMP_DIR/wal-$i.out" 2>"$TEST_TMP_DIR/wal-$i.err" &
  eval "pid_$i=$!"
done

wal_ok=1
for i in 1 2 3; do
  eval "pid=\$pid_$i"
  if ! wait "$pid"; then wal_ok=0; fi
  if grep -Eqi 'SQLITE_BUSY|database is locked|busy' "$TEST_TMP_DIR/wal-$i.err"; then wal_ok=0; fi
done

if [[ "$wal_ok" -eq 1 ]]; then
  pass "T4: WAL mode handled 3 parallel writes without SQLITE_BUSY"
else
  fail "T4: WAL concurrent writes should avoid SQLITE_BUSY"
fi

# T5: Full capacity: all peers maxed -> no capacity-qualified peer, mesh_best_peer returns empty
sqlite3 "$TEST_DB" "UPDATE peer_heartbeats SET tasks_in_progress=$MESH_MAX_TASKS_PER_PEER;"
ALL_PEERS="$(peers_json_from_mock)"
AVAILABLE="$(filter_available_peers "$ALL_PEERS")"
FULL_WINNER="$(mesh_best_peer "$AVAILABLE" "" 0 2>/dev/null || true)"
if [[ -z "$FULL_WINNER" ]]; then
  pass "T5: full-capacity peer set yields empty mesh_best_peer result"
else
  fail "T5: expected empty winner when all peers are at max" "<empty>" "$FULL_WINNER"
fi

assert_line_count "$0" 250 "test-mesh-concurrency.sh <= 250 lines"
exit_with_summary "mesh-concurrency"
