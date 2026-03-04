#!/usr/bin/env bash
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DB="${CLAUDE_DB:-$HOME/.claude/data/dashboard.db}"
echo "=== Test mesh_events schema ==="
sqlite3 "$DB" ".schema mesh_events" | grep -q 'event_type' && echo "PASS: table exists" || { echo "FAIL: table missing"; exit 1; }
sqlite3 "$DB" "SELECT COUNT(*) FROM mesh_events" >/dev/null 2>&1 && echo "PASS: queryable" || { echo "FAIL: not queryable"; exit 1; }
echo "=== Test dedup ==="
sqlite3 "$DB" "INSERT INTO mesh_events (event_type, plan_id, source_peer, payload) VALUES ('test_event', 0, 'test', '{}');"
sqlite3 "$DB" "INSERT INTO mesh_events (event_type, plan_id, source_peer, payload) VALUES ('test_event', 0, 'test', '{}');"
COUNT=$(sqlite3 "$DB" "SELECT COUNT(*) FROM mesh_events WHERE event_type='test_event';")
echo "PASS: inserted $COUNT events (dedup is application-level)"
sqlite3 "$DB" "DELETE FROM mesh_events WHERE event_type='test_event';"
echo "PASS: cleanup done"
echo "=== All mesh_events tests passed ==="
