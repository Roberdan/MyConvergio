#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
source "$SCRIPT_DIR/lib/test-helpers.sh"
auto_cleanup_temp_dir

CORE_LIB="$REPO_ROOT/scripts/lib/plan-db-core.sh"
PEERS_LIB="$REPO_ROOT/scripts/lib/peers.sh"
NORMALIZE_SCRIPT="$REPO_ROOT/scripts/mesh-normalize-hosts.sh"

plan_db_host() {
	local peers_conf="${1:-}"
	if [[ -n "$peers_conf" ]]; then
		PEERS_CONF="$peers_conf" bash -c "set -euo pipefail; source '$CORE_LIB'; printf '%s' \"\$PLAN_DB_HOST\""
	else
		bash -c "set -euo pipefail; source '$CORE_LIB'; printf '%s' \"\$PLAN_DB_HOST\""
	fi
}

echo "=== mesh node identity tests ==="

# T1: PLAN_DB_HOST should not be legacy hostname variants.
HOST_VALUE="$(plan_db_host)"
if [[ -n "$HOST_VALUE" && ! "$HOST_VALUE" =~ ^(Mac|Mac\.lan|RobertoM3Max957|RobertoM3Max957\.lan)$ ]]; then
	pass "T1: PLAN_DB_HOST is canonical (got '$HOST_VALUE')"
else
	fail "T1: PLAN_DB_HOST should not be legacy hostname variant" \
		"not Mac/Mac.lan/RobertoM3Max957(.lan)" "${HOST_VALUE:-<empty>}"
fi

# T2: PLAN_DB_HOST should match peers_self (section name from peers.conf).
SELF_PEER="$(bash -c "set -euo pipefail; source '$PEERS_LIB'; peers_load >/dev/null 2>&1 || true; peers_self")"
if [[ -n "$SELF_PEER" && "$HOST_VALUE" == "$SELF_PEER" ]]; then
	pass "T2: PLAN_DB_HOST matches peers_self ('$SELF_PEER')"
else
	fail "T2: PLAN_DB_HOST should match peers_self" \
		"non-empty peers_self and equal values" \
		"PLAN_DB_HOST='${HOST_VALUE:-<empty>}' peers_self='${SELF_PEER:-<empty>}'"
fi

# T3: Fallback without peers.conf should use hostname -s.
TEMP_EMPTY="$TEST_TEMP_DIR/peers-empty.conf"
: >"$TEMP_EMPTY"
FALLBACK_HOST="$(
	PEERS_CONF="$TEMP_EMPTY" bash -c "
		set -euo pipefail
		peers_self() { return 1; }
		source '$CORE_LIB'
		printf '%s' \"\$PLAN_DB_HOST\"
	"
)"
EXPECTED_SHORT="$(hostname -s 2>/dev/null || hostname)"
if [[ "$FALLBACK_HOST" == "$EXPECTED_SHORT" ]]; then
	pass "T3: fallback host uses hostname -s ('$FALLBACK_HOST')"
else
	fail "T3: fallback should use hostname -s" "$EXPECTED_SHORT" "${FALLBACK_HOST:-<empty>}"
fi

# Shared fixtures for normalization tests (T4-T5).
MOCK_BIN="$TEST_TEMP_DIR/mock-bin"
mkdir -p "$MOCK_BIN"
cat >"$MOCK_BIN/hostname" <<'EOM'
#!/usr/bin/env bash
if [[ "${1:-}" == "-s" ]]; then
	echo "Mac"
else
	echo "Mac.lan"
fi
EOM
cat >"$MOCK_BIN/scutil" <<'EOM'
#!/usr/bin/env bash
if [[ "${1:-}" == "--get" && "${2:-}" == "LocalHostName" ]]; then
	echo "RobertoM3Max957"
elif [[ "${1:-}" == "--get" && "${2:-}" == "ComputerName" ]]; then
	echo "Roberto M3 Max 957"
fi
EOM
chmod +x "$MOCK_BIN/hostname" "$MOCK_BIN/scutil"

PEERS_FIXTURE="$TEST_TEMP_DIR/peers.conf"
cat >"$PEERS_FIXTURE" <<'EOF_CONF'
[m3max]
ssh_alias=Mac
dns_name=RobertoM3Max957.lan
status=active
tailscale_ip=100.64.0.10
EOF_CONF

DB_FILE="$TEST_TEMP_DIR/mesh-normalize.db"
sqlite3 "$DB_FILE" <<'SQL'
CREATE TABLE plans (id INTEGER PRIMARY KEY, execution_host TEXT);
CREATE TABLE tasks (id INTEGER PRIMARY KEY, executor_host TEXT);
CREATE TABLE peer_heartbeats (peer_name TEXT);
INSERT INTO plans(id, execution_host) VALUES
  (1, 'Mac.lan'),
  (2, 'Mac'),
  (3, 'RobertoM3Max957.lan');
INSERT INTO tasks(id, executor_host) VALUES
  (1, 'Mac.lan'),
  (2, 'Mac'),
  (3, 'RobertoM3Max957.lan');
INSERT INTO peer_heartbeats(peer_name) VALUES ('test-junk');
SQL

# T4: dry-run should emit normalization UPDATE SQL.
DRY_OUT="$TEST_TEMP_DIR/dry-run.sql"
PATH="$MOCK_BIN:$PATH" PEERS_CONF="$PEERS_FIXTURE" CLAUDE_DB="$DB_FILE" DASHBOARD_DB="$DB_FILE" \
	bash "$NORMALIZE_SCRIPT" --dry-run >"$DRY_OUT"
if grep -q "UPDATE plans" "$DRY_OUT" && grep -q "UPDATE tasks" "$DRY_OUT" && grep -q "Mac.lan" "$DRY_OUT"; then
	pass "T4: dry-run emits UPDATE statements and host variants"
else
	fail "T4: dry-run should emit UPDATE statements" \
		"UPDATE plans + UPDATE tasks + Mac.lan" "$(cat "$DRY_OUT")"
fi

# T5: execution should normalize all hosts to canonical peer name.
PATH="$MOCK_BIN:$PATH" PEERS_CONF="$PEERS_FIXTURE" CLAUDE_DB="$DB_FILE" DASHBOARD_DB="$DB_FILE" \
	bash "$NORMALIZE_SCRIPT" >/dev/null
BAD_PLANS="$(sqlite3 "$DB_FILE" "SELECT COUNT(*) FROM plans WHERE execution_host <> 'm3max';")"
BAD_TASKS="$(sqlite3 "$DB_FILE" "SELECT COUNT(*) FROM tasks WHERE executor_host <> 'm3max';")"
if [[ "$BAD_PLANS" == "0" && "$BAD_TASKS" == "0" ]]; then
	pass "T5: normalize execution rewrites all hosts to m3max"
else
	fail "T5: normalize execution should canonicalize all hosts" "0 mismatches" \
		"plans=$BAD_PLANS tasks=$BAD_TASKS"
fi

# T6: Python API host matching for variants -> m3max.
PY_HOME="$TEST_TEMP_DIR/pyhome"
mkdir -p "$PY_HOME/.claude/config"
cp "$PEERS_FIXTURE" "$PY_HOME/.claude/config/peers.conf"

if HOME="$PY_HOME" PYTHONPATH="$REPO_ROOT" python3 - <<'PY'
from scripts.dashboard_web.api_mesh import peer_host_match, resolve_host_to_peer

cases = ["Mac.lan", "RobertoM3Max957.lan"]
for host in cases:
    canonical = resolve_host_to_peer(host)
    assert canonical == "m3max", f"resolve_host_to_peer({host})={canonical!r}"
    assert peer_host_match("m3max", canonical), f"peer_host_match failed for canonical={canonical!r}"
PY
then
	pass "T6: Python variant hosts resolve/match to m3max"
else
	fail "T6: Python host matching should resolve variants to m3max"
fi

exit_with_summary "mesh-node-identity"
