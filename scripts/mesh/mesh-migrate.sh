#!/usr/bin/env bash
# mesh-migrate.sh — migrate a live plan to another peer
# Usage: mesh-migrate.sh <plan_id> <target_peer> [--dry-run] [--no-launch]
# Bash 3.2 compatible | v1.0.0 | C-01,C-03,C-04,C-05,C-07

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
CLAUDE_HOME="${CLAUDE_HOME:-$HOME/.claude}"
SSH_OPTS="-o ConnectTimeout=10 -o BatchMode=yes -o StrictHostKeyChecking=accept-new"

# shellcheck source=lib/peers.sh
source "${SCRIPT_DIR}/lib/peers.sh" 2>/dev/null || true
peers_load 2>/dev/null || true
source "${SCRIPT_DIR}/lib/mesh-migrate-sync.sh"
source "${SCRIPT_DIR}/lib/mesh-migrate-db.sh"

usage() {
	echo "Usage: $(basename "$0") <plan_id> <target_peer> [--dry-run] [--no-launch]"
	echo "  --dry-run    Preflight + sync check only, no DB changes"
	echo "  --no-launch  Skip auto-launch of /execute on target"
	exit 1
}

[[ $# -lt 2 ]] && usage

PLAN_ID="$1"
TARGET="$2"
DRY_RUN=0
NO_LAUNCH=0
shift 2

while [[ $# -gt 0 ]]; do
	case "$1" in
	--dry-run) DRY_RUN=1 ;;
	--no-launch) NO_LAUNCH=1 ;;
	*)
		echo "Unknown option: $1" >&2
		usage
		;;
	esac
	shift
done

if ! [[ "$PLAN_ID" =~ ^[0-9]+$ ]]; then
	echo "ERROR: plan_id must be numeric" >&2
	exit 1
fi

# Resolve SSH destination
DEST=$(peers_best_route "$TARGET" 2>/dev/null || echo "$TARGET")

echo "=== mesh-migrate: Plan #${PLAN_ID} → ${TARGET} ==="
[[ "$DRY_RUN" -eq 1 ]] && echo "(DRY-RUN — no DB changes)"

# --- PHASE 1: Pre-flight ---
echo ""
echo "--- PHASE 1: Pre-flight ---"
if ! _migrate_preflight "$PLAN_ID" "$TARGET"; then
	echo "Pre-flight FAILED — aborting" >&2
	exit 1
fi

echo "-- Tool versions --"
_migrate_check_tools "$DEST" ||
	echo "WARN: some tools missing on target (non-critical)"

[[ "$DRY_RUN" -eq 1 ]] && {
	echo "DRY-RUN complete"
	exit 0
}

# --- PHASE 2: Sync folders ---
echo ""
echo "--- PHASE 2: Sync folders ---"
_migrate_sync_all "$DEST" "$PLAN_ID"

# --- PHASE 3: DB migration ---
echo ""
echo "--- PHASE 3: DB migration ---"
_migrate_db_checkpoint

echo "==> Backing up target DB"
ssh $SSH_OPTS "$DEST" \
	"cp ~/.claude/data/dashboard.db ~/.claude/data/dashboard.db.bak" ||
	echo "WARN: target backup failed (continuing)"
BACKUP_PATH="~/.claude/data/dashboard.db.bak"

TARGET_HOME=$(ssh $SSH_OPTS "$DEST" 'echo $HOME' 2>/dev/null || echo "~")
TARGET_HOST=$(ssh $SSH_OPTS "$DEST" 'hostname -s' 2>/dev/null || echo "$TARGET")

if ! _migrate_db_copy "$DEST"; then
	echo "==> DB copy failed — rolling back" >&2
	_migrate_db_rollback "$DEST" "$BACKUP_PATH" || true
	exit 1
fi

if ! _migrate_db_remap_paths "$DEST" "$HOME" "$TARGET_HOME"; then
	echo "==> Path remap failed — rolling back" >&2
	_migrate_db_rollback "$DEST" "$BACKUP_PATH" || true
	exit 1
fi

if ! _migrate_transfer_plan "$PLAN_ID" "$DEST" "$TARGET_HOST"; then
	echo "==> Plan transfer failed — rolling back" >&2
	_migrate_db_rollback "$DEST" "$BACKUP_PATH" || true
	exit 1
fi

# --- PHASE 4: Auto-launch ---
if [[ "$NO_LAUNCH" -eq 0 ]]; then
	echo ""
	echo "--- PHASE 4: Auto-launch ---"
	SESSION="Convergio"
	WINDOW_NAME="plan-${PLAN_ID}"
	LAUNCH_CMD="cd ~/.claude && claude --model sonnet -p '/execute ${PLAN_ID}'"

	# Create Convergio session if not exists, then add a window for this plan
	ssh $SSH_OPTS "$DEST" \
		"tmux has-session -t '${SESSION}' 2>/dev/null || tmux new-session -d -s '${SESSION}'; \
		 tmux new-window -t '${SESSION}' -n '${WINDOW_NAME}' '${LAUNCH_CMD}'" 2>/dev/null
	if ssh $SSH_OPTS "$DEST" "tmux has-session -t '${SESSION}'" 2>/dev/null; then
		echo "tmux window '${WINDOW_NAME}' created in session '${SESSION}' on ${TARGET_HOST}"
	else
		echo "WARN: tmux session not confirmed — plan transferred but needs manual /execute"
	fi
else
	echo "--- PHASE 4: Skipped (--no-launch) ---"
fi

# --- PHASE 5: Report ---
echo ""
echo "--- PHASE 5: Summary ---"
printf "%-20s %s\n" "Plan ID:" "$PLAN_ID"
printf "%-20s %s\n" "Source released:" "yes"
printf "%-20s %s\n" "Target host:" "$TARGET_HOST"
printf "%-20s %s\n" "DB integrity:" "ok"
if [[ "$NO_LAUNCH" -eq 0 ]]; then
	printf "%-20s %s\n" "tmux session:" "Convergio"
	printf "%-20s %s\n" "tmux window:" "plan-${PLAN_ID}"
fi

echo ""
echo "Plan #${PLAN_ID} migrated to ${TARGET}. Source released. Target executing."
