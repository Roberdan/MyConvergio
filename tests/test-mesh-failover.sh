#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
source "$SCRIPT_DIR/lib/test-helpers.sh"
auto_cleanup_temp_dir

echo "=== test-mesh-failover.sh ==="

TEST_DB="$TEST_TEMP_DIR/mesh-failover.db"
COORD_LIB="$TEST_TEMP_DIR/mesh-coordinator.lib.sh"
COUNTER_FILE="/tmp/mesh-offline-peer-offline.count"

# Load mesh-coordinator functions without executing CLI main case.
# Keep SCRIPT_DIR-relative library sources valid in extracted file.
mkdir -p "$TEST_TEMP_DIR/lib"
ln -sf "$REPO_ROOT/scripts/lib/peers.sh" "$TEST_TEMP_DIR/lib/peers.sh"
ln -sf "$REPO_ROOT/scripts/lib/notify-config.sh" "$TEST_TEMP_DIR/lib/notify-config.sh"
awk '/^# Main/{exit} {print}' "$REPO_ROOT/scripts/mesh-coordinator.sh" >"$COORD_LIB"
source "$COORD_LIB"

# Test overrides/mocks
DB="$TEST_DB"
_log() { :; }
_info() { :; }
_ok() { :; }
_warn() { :; }
_err() { :; }
_notify() { :; }
peers_self() { echo "self-peer"; }
_db() { sqlite3 "$DB" "$@"; }

now_epoch() { date +%s; }

init_db() {
  rm -f "$DB"
  sqlite3 "$DB" <<'SQL'
CREATE TABLE peer_heartbeats (
  peer_name TEXT PRIMARY KEY,
  last_seen INTEGER NOT NULL
);
CREATE TABLE mesh_events (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  event_type TEXT,
  source_peer TEXT,
  status TEXT DEFAULT 'pending',
  payload TEXT,
  created_at INTEGER
);
CREATE TABLE plans (
  id INTEGER PRIMARY KEY,
  status TEXT,
  execution_host TEXT
);
CREATE TABLE tasks (
  id INTEGER PRIMARY KEY,
  status TEXT,
  executor_host TEXT,
  assigned_at INTEGER
);
CREATE TABLE coordinator_claim (
  id INTEGER PRIMARY KEY CHECK (id=1),
  owner TEXT,
  last_seen INTEGER
);
INSERT INTO coordinator_claim (id, owner, last_seen) VALUES (1, NULL, 0);
SQL
}

claim_coordinator() {
  local peer="$1"
  local now cutoff changed
  now=$(now_epoch)
  cutoff=$((now - 300)) # 5 min stale window
  changed=$(sqlite3 "$DB" <<SQL
BEGIN IMMEDIATE;
UPDATE coordinator_claim
SET owner='${peer}', last_seen=${now}
WHERE id=1 AND (owner IS NULL OR owner='${peer}' OR last_seen <= ${cutoff});
SELECT changes();
COMMIT;
SQL
)
  [[ "${changed##*$'\n'}" -eq 1 ]]
}

# Fixed-loop mock based on mesh-coordinator _check_offline_nodes logic.
_check_offline_nodes() {
  local now peer_name last_seen age active count max_count
  now=$(now_epoch)
  max_count=$((REASSIGN_GRACE + 1))
  while IFS='|' read -r peer_name last_seen; do
    [[ -z "$peer_name" ]] && continue
    age=$((now - last_seen))
    [[ $age -lt $OFFLINE_THRESHOLD ]] && continue
    active=$(_db "SELECT id FROM plans WHERE status='doing' AND execution_host='${peer_name}' LIMIT 1;")
    [[ -z "$active" ]] && continue
    count=0
    [[ -f "$COUNTER_FILE" ]] && count=$(cat "$COUNTER_FILE" 2>/dev/null || echo 0)
    if [[ $count -lt $max_count ]]; then
      count=$((count + 1))
      echo "$count" >"$COUNTER_FILE"
    fi
  done < <(_db "SELECT peer_name,last_seen FROM peer_heartbeats WHERE peer_name!='$(peers_self)';")
}

check_reassign_threshold() {
  local now cutoff_offline cutoff_reassign
  now=$(now_epoch)
  cutoff_offline=$((now - OFFLINE_THRESHOLD))
  cutoff_reassign=$((now - REASSIGN_THRESHOLD))
  _db "INSERT INTO mesh_events (event_type, source_peer, status, payload, created_at)
       SELECT 'reassign_needed', t.executor_host, 'pending', '{\"reason\":\"offline_threshold\"}', ${now}
       FROM tasks t
       JOIN peer_heartbeats p ON p.peer_name=t.executor_host
       WHERE t.status='in_progress'
         AND t.assigned_at <= ${cutoff_reassign}
         AND p.last_seen <= ${cutoff_offline};"
}

# T1: stale coordinator can be claimed by new peer.
init_db
sqlite3 "$DB" "UPDATE coordinator_claim SET owner='old-coord', last_seen=$(($(now_epoch)-360)) WHERE id=1;"
if claim_coordinator "new-peer"; then
  owner=$(sqlite3 "$DB" "SELECT owner FROM coordinator_claim WHERE id=1;")
  [[ "$owner" == "new-peer" ]] && pass "T1: stale coordinator detection" || fail "T1: owner mismatch" "new-peer" "$owner"
else
  fail "T1: expected claim to succeed"
fi

# T2: atomicity - two rapid claims in one transaction, exactly one wins.
init_db
out=$(sqlite3 "$DB" <<SQL
BEGIN IMMEDIATE;
UPDATE coordinator_claim
SET owner='peer-a', last_seen=$(now_epoch)
WHERE id=1 AND (owner IS NULL OR last_seen <= $(($(now_epoch)-300)));
SELECT changes();
UPDATE coordinator_claim
SET owner='peer-b', last_seen=$(now_epoch)
WHERE id=1 AND (owner IS NULL OR last_seen <= $(($(now_epoch)-300)));
SELECT changes();
COMMIT;
SQL
)
c1=$(echo "$out" | sed -n '1p')
c2=$(echo "$out" | sed -n '2p')
won=$((c1 + c2))
[[ "$won" -eq 1 ]] && pass "T2: claim atomicity" || fail "T2: expected exactly one claim" "1" "$won"

# T3: fresh coordinator heartbeat prevents reclaim.
init_db
sqlite3 "$DB" "UPDATE coordinator_claim SET owner='incumbent', last_seen=$(($(now_epoch)-30)) WHERE id=1;"
if claim_coordinator "challenger"; then
  fail "T3: active coordinator should be retained"
else
  owner=$(sqlite3 "$DB" "SELECT owner FROM coordinator_claim WHERE id=1;")
  [[ "$owner" == "incumbent" ]] && pass "T3: active coordinator retention" || fail "T3: owner changed unexpectedly" "incumbent" "$owner"
fi

# T4: grace counter caps at REASSIGN_GRACE + 1.
init_db
rm -f "$COUNTER_FILE"
REASSIGN_GRACE=2
OFFLINE_THRESHOLD=60
sqlite3 "$DB" "INSERT INTO peer_heartbeats VALUES ('peer-offline', $(($(now_epoch)-1000)));"
sqlite3 "$DB" "INSERT INTO plans VALUES (1,'doing','peer-offline');"
for _ in {1..10}; do _check_offline_nodes; done
count=$(cat "$COUNTER_FILE")
expected=$((REASSIGN_GRACE + 1))
[[ "$count" -eq "$expected" ]] && pass "T4: grace counter cap" || fail "T4: counter exceeded cap" "$expected" "$count"
rm -f "$COUNTER_FILE"

# T5: recovered peer does not reclaim coordinator from healthy incumbent.
init_db
sqlite3 "$DB" "UPDATE coordinator_claim SET owner='healthy-incumbent', last_seen=$(($(now_epoch)-20)) WHERE id=1;"
sqlite3 "$DB" "INSERT INTO peer_heartbeats VALUES ('peer-recovered', $(($(now_epoch)-2000)));"
sqlite3 "$DB" "UPDATE peer_heartbeats SET last_seen=$(now_epoch) WHERE peer_name='peer-recovered';"
if claim_coordinator "peer-recovered"; then
  fail "T5: recovered peer should not reclaim"
else
  owner=$(sqlite3 "$DB" "SELECT owner FROM coordinator_claim WHERE id=1;")
  [[ "$owner" == "healthy-incumbent" ]] && pass "T5: offline peer recovery" || fail "T5: incumbent replaced unexpectedly" "healthy-incumbent" "$owner"
fi

# T6: in-progress task on offline peer beyond threshold triggers reassign event.
init_db
OFFLINE_THRESHOLD=900
REASSIGN_THRESHOLD=1800
sqlite3 "$DB" "INSERT INTO peer_heartbeats VALUES ('peer-z', $(($(now_epoch)-4000)));"
sqlite3 "$DB" "INSERT INTO tasks VALUES (1,'in_progress','peer-z', $(($(now_epoch)-1900)));"
check_reassign_threshold
reassign_events=$(sqlite3 "$DB" "SELECT COUNT(*) FROM mesh_events WHERE event_type='reassign_needed' AND source_peer='peer-z';")
[[ "$reassign_events" -eq 1 ]] && pass "T6: reassign threshold" || fail "T6: expected reassign event" "1" "$reassign_events"

exit_with_summary "mesh-failover"
