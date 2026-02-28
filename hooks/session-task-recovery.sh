#!/usr/bin/env bash
set -euo pipefail

# session-task-recovery.sh — Copilot CLI sessionEnd hook
# Recovers tasks left in_progress when session ends without proper completion.
# Prevents the "0% progress" bug when Copilot executor doesn't call plan-db-safe.sh.
# Version: 1.0.0

DB_FILE="$HOME/.claude/data/dashboard.db"
SCRIPTS_DIR="$HOME/.claude/scripts"
LOG_FILE="$HOME/.claude/logs/copilot-task-recovery.log"

mkdir -p "$(dirname "$LOG_FILE")" 2>/dev/null

log() { echo "$(date '+%Y-%m-%d %H:%M:%S') $1" >>"$LOG_FILE" 2>/dev/null; }

# Check dependencies
for cmd in jq sqlite3; do
	command -v "$cmd" >/dev/null 2>&1 || exit 0
done
[ ! -f "$DB_FILE" ] && exit 0

# Read hook input (Copilot hook protocol)
INPUT=$(cat)
SESSION_ID=$(echo "$INPUT" | jq -r '.session_id // empty' 2>/dev/null)

log "Session $SESSION_ID ending — checking for orphaned in_progress tasks"

# Find tasks stuck in in_progress (from active plans only)
STUCK_TASKS=$(sqlite3 "$DB_FILE" "
	SELECT t.id, t.task_id, t.plan_id, COALESCE(p.worktree_path, '')
	FROM tasks t
	JOIN plans p ON t.plan_id = p.id
	WHERE t.status = 'in_progress'
	  AND p.status = 'doing'
	ORDER BY t.id;
" 2>/dev/null || echo "")

if [[ -z "$STUCK_TASKS" ]]; then
	log "No orphaned tasks found"
	exit 0
fi

RECOVERED=0
SYNCED_PLANS=""

while IFS='|' read -r DB_ID TASK_CODE PLAN_ID WT_PATH; do
	[[ -z "$DB_ID" ]] && continue
	WT_PATH="${WT_PATH/#\~/$HOME}"

	# Check if worktree has uncommitted changes (evidence of work done)
	HAS_CHANGES=false
	if [[ -n "$WT_PATH" && -d "$WT_PATH" ]]; then
		DIRTY=$(git -C "$WT_PATH" status --porcelain 2>/dev/null | wc -l | tr -d ' ')
		[[ "$DIRTY" -gt 0 ]] && HAS_CHANGES=true
	fi

	if $HAS_CHANGES; then
		# Work was done but task not marked complete — recover it
		log "RECOVERING task $TASK_CODE (db_id=$DB_ID): $DIRTY uncommitted files in $WT_PATH"
		if "$SCRIPTS_DIR/plan-db-safe.sh" update-task "$DB_ID" done \
			"Auto-recovered: session ended with uncommitted work" --tokens 0 2>/dev/null; then
			log "  -> RECOVERED successfully"
			((RECOVERED++))
		else
			log "  -> Recovery FAILED (plan-db-safe.sh returned error)"
		fi
	else
		# No evidence of work — mark blocked so it gets retried
		log "BLOCKING task $TASK_CODE (db_id=$DB_ID): no work detected, resetting for retry"
		"$SCRIPTS_DIR/plan-db.sh" update-task "$DB_ID" blocked \
			"Session ended without completion — no file changes detected" 2>/dev/null || true
	fi

	# Track plans that need sync
	if [[ ! "$SYNCED_PLANS" == *"$PLAN_ID"* ]]; then
		SYNCED_PLANS="$SYNCED_PLANS $PLAN_ID"
	fi
done <<<"$STUCK_TASKS"

# Sync counters for all affected plans
for PID in $SYNCED_PLANS; do
	[[ -z "$PID" ]] && continue
	log "Syncing counters for plan $PID"
	"$SCRIPTS_DIR/plan-db.sh" sync "$PID" 2>/dev/null || true
done

log "Recovery complete: $RECOVERED task(s) recovered"
exit 0
