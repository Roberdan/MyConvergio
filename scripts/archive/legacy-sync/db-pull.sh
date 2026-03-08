#!/bin/bash
# DEPRECATED: Full DB pull is destructive — overwrites local DB with remote copy,
# losing tables/data that only exist locally. Use Rust mesh daemon (port 9420) instead.
# Kept for emergency manual use only.
set -euo pipefail

# LOUD ERROR if called from automated sync
if [[ "${AUTOSYNC_CALLER:-}" == "1" ]] || [[ -f "$HOME/.claude/data/autosync-disabled.flag" ]]; then
  echo -e "\033[0;31m[BLOCKED] db-pull.sh is DISABLED. Rust daemon handles sync (port 9420).\033[0m" >&2
  echo -e "\033[0;31m  Remove ~/.claude/data/autosync-disabled.flag to force.\033[0m" >&2
  exit 1
fi
echo -e "\033[1;33m[WARNING] db-pull.sh does FULL DB REPLACE — this DESTROYS local-only tables!\033[0m" >&2
echo -e "\033[1;33m  Use Rust mesh daemon instead. Ctrl+C to abort, Enter to continue...\033[0m" >&2
read -r
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

# Re-apply migrations: pulled DB may be missing tables/indexes added by this node
INIT_SQL="$HOME/.claude/scripts/init-db-migrate.sql"
if [[ -f "$INIT_SQL" ]]; then
  if ! sqlite3 "$DB" < "$INIT_SQL" 2>/dev/null; then
    echo "[WARN] Post-pull migration had errors (non-fatal)" >&2
  fi
fi
