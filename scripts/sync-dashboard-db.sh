#!/bin/bash
# sync-dashboard-db.sh - Sincronizza dashboard.db tra Mac e Linux
# Usage: sync-dashboard-db.sh [push|pull|status]
#
# Modes:
#   pull   - Linux → Mac (default, Linux is source of truth)
#   push   - Mac → Linux
#   status - Compare both databases

set -e

# Load configuration from file (keeps sensitive info out of script)
CONFIG_FILE="$HOME/.claude/config/sync-db.conf"
if [[ -f "$CONFIG_FILE" ]]; then
	source "$CONFIG_FILE"
else
	echo "ERROR: Config file not found: $CONFIG_FILE"
	echo "Create it with REMOTE_HOST, REMOTE_DB, LOCAL_DB settings"
	exit 1
fi

# Defaults (can be overridden in config)
LOCAL_DB="${LOCAL_DB:-$HOME/.claude/data/dashboard.db}"
REMOTE_DB="${REMOTE_DB:-~/.claude/data/dashboard.db}"
BACKUP_DIR="$HOME/.claude/data/backups"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

log_info() { echo -e "${GREEN}[INFO]${NC} $1"; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }

check_ssh() {
	if ! ssh -o ConnectTimeout=5 "$REMOTE_HOST" "echo ok" &>/dev/null; then
		log_error "Cannot connect to $REMOTE_HOST"
		exit 1
	fi
}

ensure_backup_dir() {
	mkdir -p "$BACKUP_DIR"
}

backup_local() {
	ensure_backup_dir
	cp "$LOCAL_DB" "$BACKUP_DIR/dashboard_local_$TIMESTAMP.db"
	log_info "Local backup: $BACKUP_DIR/dashboard_local_$TIMESTAMP.db"
}

backup_remote() {
	ssh -o ConnectTimeout=10 "$REMOTE_HOST" "mkdir -p ~/.claude/data/backups && cp $REMOTE_DB ~/.claude/data/backups/dashboard_remote_$TIMESTAMP.db"
	log_info "Remote backup created"
}

show_status() {
	log_info "=== Local DB (Mac) ==="
	sqlite3 "$LOCAL_DB" "SELECT id, name, status, tasks_done||'/'||tasks_total as progress, COALESCE(execution_host, '-') as host FROM plans WHERE status != 'done' OR completed_at > datetime('now', '-7 days') ORDER BY id DESC LIMIT 10;"

	echo ""
	log_info "=== Remote DB (Linux) ==="
	ssh -o ConnectTimeout=10 "$REMOTE_HOST" "sqlite3 $REMOTE_DB \"SELECT id, name, status, tasks_done||'/'||tasks_total as progress, COALESCE(execution_host, '-') as host FROM plans WHERE status != 'done' OR completed_at > datetime('now', '-7 days') ORDER BY id DESC LIMIT 10;\""
}

sync_plans() {
	local direction=$1
	local source_db source_host target_db

	if [[ "$direction" == "pull" ]]; then
		log_info "Syncing: Linux → Mac"

		# Get plans from remote that are more recent
		ssh -o ConnectTimeout=10 "$REMOTE_HOST" "sqlite3 $REMOTE_DB \"
            SELECT id, status, tasks_done, tasks_total,
                   COALESCE(completed_at, ''), COALESCE(updated_at, '')
            FROM plans WHERE status = 'done' OR updated_at IS NOT NULL;
        \"" | while IFS='|' read -r id status tasks_done tasks_total completed_at updated_at; do
			# Update local if remote is done and local isn't, or remote is more recent
			local_status=$(sqlite3 "$LOCAL_DB" "SELECT status FROM plans WHERE id=$id;" 2>/dev/null || echo "")

			if [[ "$local_status" != "$status" ]] || [[ "$local_status" != "done" && "$status" == "done" ]]; then
				log_info "Updating plan $id: $local_status → $status ($tasks_done/$tasks_total)"
				sqlite3 "$LOCAL_DB" "
                    UPDATE plans SET
                        status='$status',
                        tasks_done=$tasks_done,
                        completed_at=$([ -n "$completed_at" ] && echo \"'$completed_at'\" || echo "NULL"),
                        updated_at=CURRENT_TIMESTAMP
                    WHERE id=$id;
                "
				# Also sync tasks for this plan
				sqlite3 "$LOCAL_DB" "UPDATE tasks SET status='done', completed_at=CURRENT_TIMESTAMP WHERE plan_id=$id AND status != 'done';"
				sqlite3 "$LOCAL_DB" "UPDATE waves SET status='done', tasks_done=tasks_total, completed_at=CURRENT_TIMESTAMP WHERE plan_id=$id AND status != 'done';"
			fi
		done

	elif [[ "$direction" == "push" ]]; then
		log_info "Syncing: Mac → Linux"

		sqlite3 "$LOCAL_DB" "
            SELECT id, status, tasks_done, tasks_total,
                   COALESCE(completed_at, ''), COALESCE(updated_at, '')
            FROM plans WHERE status = 'done' OR updated_at IS NOT NULL;
        " | while IFS='|' read -r id status tasks_done tasks_total completed_at updated_at; do
			remote_status=$(ssh -o ConnectTimeout=10 "$REMOTE_HOST" "sqlite3 $REMOTE_DB \"SELECT status FROM plans WHERE id=$id;\"" 2>/dev/null || echo "")

			if [[ "$remote_status" != "$status" ]] || [[ "$remote_status" != "done" && "$status" == "done" ]]; then
				log_info "Updating remote plan $id: $remote_status → $status ($tasks_done/$tasks_total)"
				ssh -o ConnectTimeout=10 "$REMOTE_HOST" "sqlite3 $REMOTE_DB \"
                    UPDATE plans SET
                        status='$status',
                        tasks_done=$tasks_done,
                        completed_at=$([ -n "$completed_at" ] && echo \"'$completed_at'\" || echo 'NULL'),
                        updated_at=CURRENT_TIMESTAMP
                    WHERE id=$id;
                    UPDATE tasks SET status='done', completed_at=CURRENT_TIMESTAMP WHERE plan_id=$id AND status != 'done';
                    UPDATE waves SET status='done', tasks_done=tasks_total, completed_at=CURRENT_TIMESTAMP WHERE plan_id=$id AND status != 'done';
                \""
			fi
		done
	fi
}

full_pull() {
	log_info "Full database pull from Linux"
	backup_local
	scp "$REMOTE_HOST:$REMOTE_DB" "$LOCAL_DB.new"
	mv "$LOCAL_DB.new" "$LOCAL_DB"
	log_info "Database replaced with remote copy"
}

full_push() {
	log_info "Full database push to Linux"
	backup_remote
	scp "$LOCAL_DB" "$REMOTE_HOST:$REMOTE_DB"
	log_info "Remote database replaced with local copy"
}

copy_plan() {
	local plan_id=$1
	local direction=$2

	if [[ -z "$plan_id" ]]; then
		log_error "Plan ID required. Usage: $0 copy-plan <id> [push|pull]"
		exit 1
	fi

	direction="${direction:-push}"

	if [[ "$direction" == "push" ]]; then
		log_info "Copying plan $plan_id: Local → Remote"
		scp "$LOCAL_DB" "$REMOTE_HOST:/tmp/source_dashboard.db"
		ssh -o ConnectTimeout=10 "$REMOTE_HOST" "sqlite3 $REMOTE_DB \"
            ATTACH '/tmp/source_dashboard.db' AS src;
            INSERT OR REPLACE INTO plans SELECT * FROM src.plans WHERE id=$plan_id;
            INSERT OR REPLACE INTO waves SELECT * FROM src.waves WHERE plan_id=$plan_id;
            INSERT OR REPLACE INTO tasks SELECT * FROM src.tasks WHERE plan_id=$plan_id;
            DETACH src;
        \" && rm /tmp/source_dashboard.db"
		log_info "Plan $plan_id copied to remote"
	else
		log_info "Copying plan $plan_id: Remote → Local"
		scp "$REMOTE_HOST:$REMOTE_DB" "/tmp/source_dashboard.db"
		sqlite3 "$LOCAL_DB" "
            ATTACH '/tmp/source_dashboard.db' AS src;
            INSERT OR REPLACE INTO plans SELECT * FROM src.plans WHERE id=$plan_id;
            INSERT OR REPLACE INTO waves SELECT * FROM src.waves WHERE plan_id=$plan_id;
            INSERT OR REPLACE INTO tasks SELECT * FROM src.tasks WHERE plan_id=$plan_id;
            DETACH src;
        "
		rm /tmp/source_dashboard.db
		log_info "Plan $plan_id copied to local"
	fi
}

# Main
case "${1:-status}" in
pull)
	check_ssh
	backup_local
	sync_plans pull
	log_info "Sync complete (Linux → Mac)"
	;;
push)
	check_ssh
	backup_remote
	sync_plans push
	log_info "Sync complete (Mac → Linux)"
	;;
full-pull)
	check_ssh
	full_pull
	;;
full-push)
	check_ssh
	full_push
	;;
status)
	check_ssh
	show_status
	;;
copy-plan)
	check_ssh
	copy_plan "$2" "$3"
	;;
*)
	echo "Usage: $0 [pull|push|full-pull|full-push|copy-plan|status]"
	echo ""
	echo "  pull              - Sync completed plans from remote to local"
	echo "  push              - Sync completed plans from local to remote"
	echo "  full-pull         - Replace local DB with remote (backup first)"
	echo "  full-push         - Replace remote DB with local (backup first)"
	echo "  copy-plan <id>    - Copy specific plan to remote (push, default)"
	echo "  copy-plan <id> pull - Copy specific plan from remote"
	echo "  status            - Show recent plans on both machines"
	echo ""
	echo "Config: $CONFIG_FILE"
	exit 1
	;;
esac
