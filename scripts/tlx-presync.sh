#!/usr/bin/env bash
# tlx-presync.sh - Pre-sync local -> remote peer before connecting
# Usage: tlx-presync.sh <peer-name>
# Version: 2.0.0
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/peers.sh
source "${SCRIPT_DIR}/lib/peers.sh"

PEER="${1:?Usage: tlx-presync.sh <peer-name>}"
REMOTE_SYNC_SCRIPT="$SCRIPT_DIR/remote-repo-sync.sh"

# --- Output helpers ---
G='\033[0;32m' Y='\033[1;33m' R='\033[0;31m' C='\033[0;36m' N='\033[0m'
info() { echo -e "${C}[presync]${N} $*"; }
ok() { echo -e "${G}[presync]${N} $*"; }
warn() { echo -e "${Y}[presync]${N} $*"; }
err() { echo -e "${R}[presync]${N} $*" >&2; }

# --- Connectivity check via peers_check ---
peers_load 2>/dev/null || true

info "Checking connectivity to $PEER..."
if ! peers_check "$PEER" 2>/dev/null; then
	err "Peer '$PEER' is unreachable. Aborting pre-sync."
	exit 1
fi
ok "Peer '$PEER' is reachable."

# Resolve SSH destination
HOST="$(peers_best_route "$PEER" 2>/dev/null)" || {
	err "Cannot resolve SSH route for '$PEER'. Check peers.conf."
	exit 1
}
PEER_USER="$(_peers_get_raw "$PEER" "user" 2>/dev/null || true)"
[[ -n "$PEER_USER" ]] && HOST="${PEER_USER}@${HOST}"

START=$(date +%s)

# --- Phase 1: local pushes (parallel) ---
info "Phase 1: Pushing DB + config to $PEER ($HOST)..."

db_log="${TMPDIR:-/tmp}/tlx-dbsync-$$.log"
config_log="${TMPDIR:-/tmp}/tlx-configsync-$$.log"

REMOTE_HOST="$HOST" "$SCRIPT_DIR/sync-dashboard-db.sh" push >"$db_log" 2>&1 &
pid_db=$!

REMOTE_HOST="$HOST" "$SCRIPT_DIR/sync-claude-config.sh" push >"$config_log" 2>&1 &
pid_config=$!

db_ok=0
config_ok=0

wait "$pid_db" && db_ok=1 || true
wait "$pid_config" && config_ok=1 || true

if [[ "$db_ok" -eq 1 ]]; then
	ok "Dashboard DB sync: OK"
else
	warn "Dashboard DB sync: FAILED (see $db_log)"
fi

if [[ "$config_ok" -eq 1 ]]; then
	ok "Claude config sync: OK"
else
	warn "Claude config sync: FAILED (see $config_log)"
fi

# --- Phase 2: remote-side repo sync ---
info "Phase 2: Syncing repos on $PEER..."

if [[ ! -f "$REMOTE_SYNC_SCRIPT" ]]; then
	err "Missing: $REMOTE_SYNC_SCRIPT"
	exit 1
fi

scp -q "$REMOTE_SYNC_SCRIPT" "$HOST:${TMPDIR:-/tmp}/remote-repo-sync.sh"
ssh "$HOST" "chmod +x ${TMPDIR:-/tmp}/remote-repo-sync.sh && ${TMPDIR:-/tmp}/remote-repo-sync.sh"

# --- Summary ---
END=$(date +%s)
ELAPSED=$((END - START))
echo ""
ok "Pre-sync complete in ${ELAPSED}s"
echo -e "  Connectivity: ${G}OK${N}"
echo -e "  DB:     $([ "$db_ok" -eq 1 ] && echo "${G}OK${N}" || echo "${R}FAIL${N}")"
echo -e "  Config: $([ "$config_ok" -eq 1 ] && echo "${G}OK${N}" || echo "${R}FAIL${N}")"
echo -e "  Repos:  ${G}OK${N}"
