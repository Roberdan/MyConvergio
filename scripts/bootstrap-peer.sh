#!/usr/bin/env bash
# bootstrap-peer.sh — Initialize a remote peer for the Claude mesh
# Version: 1.0.0
# Usage: bootstrap-peer.sh <peer-name> [--skip-tools]
# Steps (all idempotent):
#   1) Read peer from peers.conf via peers_get()
#   2) Check/copy local SSH pubkey to remote authorized_keys
#   3) Bidirectional: read remote pubkey, add to local authorized_keys
#   4) Create remote ~/.claude dirs
#   5) Initialize remote dashboard.db from init-db.sql if not exists
#   6) Verify PATH includes ~/.claude/scripts on remote
#   7) Run mesh-env-setup.sh --tools-only on remote (unless --skip-tools)
#   8) Write heartbeat row to remote peer_heartbeats table
#   9) Print JSON summary
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CLAUDE_HOME="${CLAUDE_HOME:-$HOME/.claude}"
INIT_DB_SQL="$SCRIPT_DIR/init-db.sql"

source "$SCRIPT_DIR/lib/peers.sh"

# ---- logging ----------------------------------------------------------------
_log() { echo "[bootstrap-peer] $*" >&2; }
_warn() { echo "[bootstrap-peer] WARN: $*" >&2; }
_err() { echo "[bootstrap-peer] ERROR: $*" >&2; }

# ---- usage ------------------------------------------------------------------
usage() {
	echo "Usage: $(basename "$0") <peer-name> [--skip-tools]" >&2
	echo "  Initializes a remote peer for the Claude mesh (all steps idempotent)." >&2
	exit 1
}

# ---- argument parsing -------------------------------------------------------
PEER_NAME=""
SKIP_TOOLS=false

for arg in "$@"; do
	case "$arg" in
	--skip-tools) SKIP_TOOLS=true ;;
	--help | -h) usage ;;
	-*)
		_err "Unknown option: $arg"
		usage
		;;
	*) PEER_NAME="$arg" ;;
	esac
done

[[ -z "$PEER_NAME" ]] && usage

# ---- state tracking ---------------------------------------------------------
SSH_OK=false
DB_OK=false
PATH_OK=false
TOOLS_OK=false
BIDIRECTIONAL_OK=false

# ---- load peers -------------------------------------------------------------
peers_load || {
	_err "Failed to load peers.conf"
	exit 1
}

# ---- resolve peer connection ------------------------------------------------
PEER_HOST="$(peers_best_route "$PEER_NAME" 2>/dev/null)" || {
	_err "No route found for peer: $PEER_NAME"
	exit 1
}
PEER_USER="$(peers_get "$PEER_NAME" "user" 2>/dev/null || true)"
PEER_DEST="${PEER_USER:+${PEER_USER}@}${PEER_HOST}"

_ssh() { ssh -o BatchMode=yes -o ConnectTimeout=10 -o StrictHostKeyChecking=no "$PEER_DEST" "$@"; }

# ---- step 1: verify SSH reachability ----------------------------------------
_log "Step 1: Checking SSH connectivity to $PEER_DEST..."
if _ssh true &>/dev/null; then
	SSH_OK=true
	_log "SSH OK"
else
	_log "SSH not yet working — attempting ssh-copy-id..."
	# Step 2: push local pubkey
	LOCAL_PUBKEY="${HOME}/.ssh/id_rsa.pub"
	[[ ! -f "$LOCAL_PUBKEY" ]] && LOCAL_PUBKEY="${HOME}/.ssh/id_ed25519.pub"
	if [[ -f "$LOCAL_PUBKEY" ]]; then
		ssh-copy-id -i "$LOCAL_PUBKEY" "${PEER_DEST}" 2>/dev/null || {
			_err "ssh-copy-id failed — cannot proceed without SSH access"
			exit 1
		}
		SSH_OK=true
		_log "SSH pubkey installed via ssh-copy-id"
	else
		_err "No local SSH pubkey found (~/.ssh/id_rsa.pub or id_ed25519.pub)"
		exit 1
	fi
fi

# ---- step 3: bidirectional — fetch remote pubkey, add to local authorized_keys
_log "Step 3: Bidirectional SSH key exchange..."
REMOTE_PUBKEY="$(_ssh "cat ~/.ssh/id_rsa.pub 2>/dev/null || cat ~/.ssh/id_ed25519.pub 2>/dev/null || true")"
if [[ -n "$REMOTE_PUBKEY" ]]; then
	LOCAL_AUTH="$HOME/.ssh/authorized_keys"
	mkdir -p "$HOME/.ssh"
	chmod 700 "$HOME/.ssh"
	if ! grep -qF "$REMOTE_PUBKEY" "$LOCAL_AUTH" 2>/dev/null; then
		echo "$REMOTE_PUBKEY" >>"$LOCAL_AUTH"
		chmod 600 "$LOCAL_AUTH"
		_log "Remote pubkey added to local authorized_keys"
	else
		_log "Remote pubkey already in local authorized_keys"
	fi
	BIDIRECTIONAL_OK=true
else
	_warn "No remote pubkey found — bidirectional auth not configured"
fi

# ---- step 4: create remote directories --------------------------------------
_log "Step 4: Creating remote ~/.claude directories..."
_ssh "mkdir -p ~/.claude/data ~/.claude/config ~/.claude/scripts" && {
	_log "Remote directories ready"
}

# ---- step 5: initialize remote dashboard.db ---------------------------------
_log "Step 5: Initializing remote dashboard.db..."
if [[ ! -f "$INIT_DB_SQL" ]]; then
	_warn "init-db.sql not found at $INIT_DB_SQL — skipping DB init"
else
	REMOTE_DB_EXISTS="$(_ssh '[ -f ~/.claude/data/dashboard.db ] && echo yes || echo no')"
	if [[ "$REMOTE_DB_EXISTS" == "no" ]]; then
		scp -q "$INIT_DB_SQL" "${PEER_DEST}:~/.claude/data/init-db.sql"
		_ssh "sqlite3 ~/.claude/data/dashboard.db < ~/.claude/data/init-db.sql && rm ~/.claude/data/init-db.sql"
		_log "Remote dashboard.db initialized"
		DB_OK=true
	else
		_log "Remote dashboard.db already exists — skipping init"
		DB_OK=true
	fi
fi

# ---- step 6: verify PATH includes ~/.claude/scripts -------------------------
_log "Step 6: Verifying remote PATH includes ~/.claude/scripts..."
PATH_CHECK="$(_ssh '
for f in ~/.zshrc ~/.bashrc; do
  [ -f "$f" ] && grep -q "\.claude/scripts" "$f" 2>/dev/null && echo found && exit 0
done
echo missing
')"
if [[ "$PATH_CHECK" == "found" ]]; then
	_log "PATH entry already present"
	PATH_OK=true
else
	_log "Appending ~/.claude/scripts to remote PATH in .zshrc and .bashrc..."
	_ssh '
PATH_ENTRY='\''export PATH="$HOME/.claude/scripts:$PATH"'\''
for f in ~/.zshrc ~/.bashrc; do
  [ -f "$f" ] && echo "$PATH_ENTRY" >> "$f"
done
'
	PATH_OK=true
fi

# ---- step 7: run mesh-env-setup.sh --tools-only (unless --skip-tools) -------
if [[ "$SKIP_TOOLS" == true ]]; then
	_log "Step 7: --skip-tools set — skipping tools setup"
	TOOLS_OK=true
else
	_log "Step 7: Running mesh-env-setup.sh --tools-only on remote..."
	MESH_EXISTS="$(_ssh 'command -v mesh-env-setup.sh &>/dev/null && echo yes || [ -f ~/.claude/scripts/mesh-env-setup.sh ] && echo yes || echo no')"
	if [[ "$MESH_EXISTS" == "yes" ]]; then
		_ssh "mesh-env-setup.sh --tools-only" && {
			TOOLS_OK=true
			_log "Remote tools setup complete"
		} || {
			_warn "mesh-env-setup.sh --tools-only failed on remote"
		}
	else
		_warn "mesh-env-setup.sh not installed yet, skip tools"
		TOOLS_OK=false
	fi
fi

# ---- step 8: write heartbeat row to remote peer_heartbeats ------------------
_log "Step 8: Writing heartbeat to remote peer_heartbeats..."
LOCAL_PEER="$(peers_self 2>/dev/null || hostname -s)"
EPOCH="$(date +%s)"
CAPS="$(peers_get "$PEER_NAME" "capabilities" 2>/dev/null || true)"

_ssh "sqlite3 ~/.claude/data/dashboard.db \"
  INSERT OR REPLACE INTO peer_heartbeats (peer_name, last_seen, capabilities, updated_at)
  VALUES ('${LOCAL_PEER}', ${EPOCH}, '${CAPS}', datetime('now'));
\"" 2>/dev/null && {
	_log "Heartbeat written to remote peer_heartbeats"
} || {
	_warn "Failed to write heartbeat (peer_heartbeats table may not exist yet)"
}

# ---- step 9: JSON summary ---------------------------------------------------
_bool() { [[ "$1" == "true" ]] && echo "true" || echo "false"; }

printf '{
  "peer": "%s",
  "ssh_ok": %s,
  "db_ok": %s,
  "path_ok": %s,
  "tools_ok": %s,
  "bidirectional_ok": %s
}\n' \
	"$PEER_NAME" \
	"$(_bool "$SSH_OK")" \
	"$(_bool "$DB_OK")" \
	"$(_bool "$PATH_OK")" \
	"$(_bool "$TOOLS_OK")" \
	"$(_bool "$BIDIRECTIONAL_OK")"

# Exit 1 if critical steps failed
if [[ "$SSH_OK" == false || "$DB_OK" == false ]]; then
	exit 1
fi
exit 0
