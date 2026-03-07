#!/bin/bash
# Safe DB pull from remote peer — copies to temp, then VACUUM INTO to replace
# Usage: db-pull.sh [peer_ssh]
set -euo pipefail
PEER="${1:-mac-dev-ts}"
DB="$HOME/.claude/data/dashboard.db"
TMP="/tmp/dashboard-pull-$$.db"
trap 'rm -f "$TMP"' EXIT

# Checkpoint remote WAL
ssh -n -o ConnectTimeout=5 -o BatchMode=yes "$PEER" \
  "sqlite3 ~/.claude/data/dashboard.db 'PRAGMA wal_checkpoint(TRUNCATE);'" 2>/dev/null || true

# Copy to temp
scp -o ConnectTimeout=10 -o BatchMode=yes "$PEER:~/.claude/data/dashboard.db" "$TMP" 2>/dev/null

# Verify integrity
if ! sqlite3 "$TMP" "PRAGMA integrity_check;" 2>/dev/null | grep -q ok; then
  echo "[ERROR] Remote DB failed integrity check" >&2; exit 1
fi

# Normalize host aliases on the pulled temp DB before the atomic swap.
NORMALIZE_SCRIPT="$HOME/.claude/scripts/mesh-normalize-hosts.sh"
if [[ -x "$NORMALIZE_SCRIPT" ]]; then
  if NORMALIZE_OUT="$(CLAUDE_DB="$TMP" "$NORMALIZE_SCRIPT" 2>&1)"; then
    echo "[OK] $NORMALIZE_OUT"
  else
    echo "[WARN] Host normalization failed on pulled DB: $NORMALIZE_OUT" >&2
  fi
fi

# Atomic replace: backup then move
cp "$DB" "${DB}.bak" 2>/dev/null || true
mv "$TMP" "$DB"
rm -f "${DB}-wal" "${DB}-shm"
trap - EXIT

REMOTE_DONE=$(sqlite3 "$DB" "SELECT tasks_done||'/'||tasks_total FROM plans WHERE status='doing' ORDER BY id DESC LIMIT 1;" 2>/dev/null)
echo "[OK] DB pulled from $PEER ($REMOTE_DONE)"
