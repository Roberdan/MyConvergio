#!/usr/bin/env bash
# test-peer-heartbeats-migration.sh - Verify peer_heartbeats table + privacy_required column migration
# Plan 296 / T1-05 | F-05, F-16, F-17, F-26
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WORKTREE_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
INIT_SQL="$WORKTREE_ROOT/scripts/init-db.sql"
PLAN_DB_CORE="$WORKTREE_ROOT/scripts/lib/plan-db-core.sh"
DB_PATH="$HOME/.claude/data/dashboard.db"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

failures=0

pass() { echo -e "${GREEN}[PASS]${NC} $1"; }
fail() {
	echo -e "${RED}[FAIL]${NC} $1"
	((failures++))
}
info() { echo -e "${YELLOW}[INFO]${NC} $1"; }

echo "================================================================"
echo "Peer Heartbeats Migration Test (Plan 296 T1-05)"
echo "================================================================"

# F-26: init-db.sql must contain peer_heartbeats table definition
if grep -q 'peer_heartbeats' "$INIT_SQL"; then
	pass "init-db.sql contains peer_heartbeats table"
else
	fail "init-db.sql missing peer_heartbeats table"
fi

# F-16/F-17: init-db.sql must contain privacy_required column definition
if grep -q 'privacy_required' "$INIT_SQL"; then
	pass "init-db.sql contains privacy_required column"
else
	fail "init-db.sql missing privacy_required column"
fi

# plan-db-core.sh must contain ensure_tables function
if grep -q 'ensure_tables' "$PLAN_DB_CORE"; then
	pass "plan-db-core.sh contains ensure_tables() function"
else
	fail "plan-db-core.sh missing ensure_tables() function"
fi

# plan-db-core.sh ensure_tables must create peer_heartbeats
if grep -q 'peer_heartbeats' "$PLAN_DB_CORE"; then
	pass "plan-db-core.sh ensure_tables references peer_heartbeats"
else
	fail "plan-db-core.sh ensure_tables missing peer_heartbeats"
fi

# Verify actual DB: peer_heartbeats table must exist
if [[ -f "$DB_PATH" ]]; then
	if sqlite3 "$DB_PATH" ".tables" | tr ' ' '\n' | grep -q '^peer_heartbeats$'; then
		pass "DB: peer_heartbeats table exists"
	else
		fail "DB: peer_heartbeats table not found"
	fi

	# Verify peer_heartbeats columns
	local_columns=$(sqlite3 "$DB_PATH" "PRAGMA table_info(peer_heartbeats);" | cut -d'|' -f2 | tr '\n' ' ')
	if echo "$local_columns" | grep -q 'peer_name'; then
		pass "DB: peer_heartbeats has peer_name column"
	else
		fail "DB: peer_heartbeats missing peer_name column"
	fi
	if echo "$local_columns" | grep -q 'last_seen'; then
		pass "DB: peer_heartbeats has last_seen column"
	else
		fail "DB: peer_heartbeats missing last_seen column"
	fi
	if echo "$local_columns" | grep -q 'load_json'; then
		pass "DB: peer_heartbeats has load_json column"
	else
		fail "DB: peer_heartbeats missing load_json column"
	fi
	if echo "$local_columns" | grep -q 'capabilities'; then
		pass "DB: peer_heartbeats has capabilities column"
	else
		fail "DB: peer_heartbeats missing capabilities column"
	fi

	# Verify tasks.privacy_required column exists
	if sqlite3 "$DB_PATH" "PRAGMA table_info(tasks);" | cut -d'|' -f2 | grep -q 'privacy_required'; then
		pass "DB: tasks.privacy_required column exists"
	else
		fail "DB: tasks.privacy_required column missing"
	fi
else
	fail "DB not found at $DB_PATH - cannot verify live migration"
fi

# Idempotency: running init-db.sql twice on a fresh DB must not error (IF NOT EXISTS guards)
TEMP_DB=$(mktemp /tmp/test-peer-heartbeats-XXXX.db)
trap 'rm -f "$TEMP_DB"' EXIT
if sqlite3 "$TEMP_DB" <"$INIT_SQL" >/dev/null 2>&1; then
	if sqlite3 "$TEMP_DB" <"$INIT_SQL" >/dev/null 2>&1; then
		pass "Idempotency: running init-db.sql twice on fresh DB completes without error"
	else
		fail "Idempotency: second run of init-db.sql on fresh DB produced errors"
	fi
else
	fail "Idempotency: first run of init-db.sql on fresh DB produced errors"
fi

# Verify peer_heartbeats + privacy_required survive the second run on fresh DB
if sqlite3 "$TEMP_DB" ".tables" | tr ' ' '\n' | grep -q '^peer_heartbeats$'; then
	pass "Idempotency: peer_heartbeats table survives second init-db.sql run"
else
	fail "Idempotency: peer_heartbeats table missing after second init-db.sql run"
fi
if sqlite3 "$TEMP_DB" "PRAGMA table_info(tasks);" | cut -d'|' -f2 | grep -q 'privacy_required'; then
	pass "Idempotency: tasks.privacy_required survives second init-db.sql run"
else
	fail "Idempotency: tasks.privacy_required missing after second init-db.sql run"
fi

echo ""
echo "================================================================"
if [[ $failures -eq 0 ]]; then
	echo -e "${GREEN}ALL TESTS PASSED${NC}"
	exit 0
else
	echo -e "${RED}$failures TESTS FAILED${NC}"
	exit 1
fi
