#!/bin/bash
# Plan DB Core - Shared utilities
# Sourced by plan-db.sh

# Version: 1.5.0
DB_FILE="${HOME}/.claude/data/dashboard.db"
AUDIT_LOG="${AUDIT_LOG:-${HOME}/.claude/data/thor-audit.jsonl}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

# Export hostname for distributed execution tracking
# Strip .local suffix for consistency (macOS hostname vs DB stored values)
PLAN_DB_HOST="${HOSTNAME:-$(hostname -s 2>/dev/null || hostname)}"
export PLAN_DB_HOST="${PLAN_DB_HOST%.local}"

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
RED='\033[0;31m'
NC='\033[0m'

log_info() { echo -e "${GREEN}[OK]${NC} $1" >&2; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $1" >&2; }
log_error() { echo -e "${RED}[ERROR]${NC} $1" >&2; }

# SQLite wrapper with busy timeout and performance PRAGMAs
db_query() {
	sqlite3 -cmd ".timeout 5000" \
		-cmd "PRAGMA cache_size = -8000" \
		-cmd "PRAGMA temp_store = MEMORY" \
		"$DB_FILE" "$@"
}

# Initialize DB if needed
init_db() {
	if [[ ! -f "$DB_FILE" ]]; then
		mkdir -p "$(dirname "$DB_FILE")"
		sqlite3 "$DB_FILE" <"$SCRIPT_DIR/init-db.sql"
		sqlite3 "$DB_FILE" "PRAGMA journal_mode=WAL; PRAGMA synchronous=NORMAL; PRAGMA cache_size=-8000; PRAGMA temp_store=MEMORY; PRAGMA mmap_size=268435456;"
		log_info "Database initialized"
	fi
	# Migration: add 'submitted' status + enforce_thor_done trigger (v5.0.0)
	_migrate_submitted_status 2>/dev/null || true
	# Migration: ensure task_undone_counter + wave_auto_complete are correct
	_migrate_counter_triggers 2>/dev/null || true
}

# Migration: add 'submitted' status to CHECK constraint + Thor enforcement trigger
_migrate_submitted_status() {
	# Check if already migrated
	local has_submitted
	has_submitted=$(sqlite3 "$DB_FILE" "SELECT sql FROM sqlite_master WHERE name = 'tasks' AND type = 'table' AND sql LIKE '%submitted%';" 2>/dev/null || echo "")
	if [[ -n "$has_submitted" ]]; then
		# Already migrated — ensure trigger exists (idempotent)
		sqlite3 "$DB_FILE" "
			DROP TRIGGER IF EXISTS enforce_thor_done;
			CREATE TRIGGER enforce_thor_done
			BEFORE UPDATE OF status ON tasks
			WHEN NEW.status = 'done' AND OLD.status <> 'done'
			BEGIN
				SELECT RAISE(ABORT, 'BLOCKED: Only Thor can set status=done. validated_by must be thor/thor-quality-assurance-guardian/thor-per-wave/forced-admin.')
				WHERE OLD.status <> 'submitted'
					OR NEW.validated_by IS NULL
					OR NEW.validated_by NOT IN ('thor', 'thor-quality-assurance-guardian', 'thor-per-wave', 'forced-admin');
			END;
		" 2>/dev/null || true
		return 0
	fi

	# Add 'submitted' to CHECK constraint via writable_schema
	sqlite3 "$DB_FILE" "
		PRAGMA writable_schema = ON;
		UPDATE sqlite_master SET sql = replace(sql,
			'CHECK(status IN (''pending'', ''in_progress'', ''done'', ''blocked'', ''skipped'', ''cancelled''))',
			'CHECK(status IN (''pending'', ''in_progress'', ''submitted'', ''done'', ''blocked'', ''skipped'', ''cancelled''))')
		WHERE name = 'tasks' AND type = 'table';
		PRAGMA writable_schema = OFF;
	"

	# Rebuild schema cache after writable_schema modification
	sqlite3 "$DB_FILE" "VACUUM;" 2>/dev/null || true

	# Verify integrity
	local integrity
	integrity=$(sqlite3 "$DB_FILE" "PRAGMA integrity_check;" 2>/dev/null || echo "error")
	if [[ "$integrity" != "ok" ]]; then
		echo "[migration] WARNING: integrity_check after schema update: $integrity" >&2
	fi

	# Create enforcement trigger: ONLY Thor can transition submitted → done
	sqlite3 "$DB_FILE" "
		DROP TRIGGER IF EXISTS enforce_thor_done;
		CREATE TRIGGER enforce_thor_done
		BEFORE UPDATE OF status ON tasks
		WHEN NEW.status = 'done' AND OLD.status <> 'done'
		BEGIN
			SELECT RAISE(ABORT, 'BLOCKED: Only Thor can set status=done. validated_by must be thor/thor-quality-assurance-guardian/thor-per-wave/forced-admin.')
			WHERE OLD.status <> 'submitted'
				OR NEW.validated_by IS NULL
				OR NEW.validated_by NOT IN ('thor', 'thor-quality-assurance-guardian', 'thor-per-wave', 'forced-admin');
		END;
	"

	echo "[migration] Added 'submitted' status + enforce_thor_done trigger (v5.0.0)" >&2
}

# Migration: ensure counter triggers are correct (task_undone_counter + wave_auto_complete with merging)
_migrate_counter_triggers() {
	# task_undone_counter: decrement counters when task leaves 'done' (e.g., Thor re-review)
	local has_undone
	has_undone=$(sqlite3 "$DB_FILE" "SELECT name FROM sqlite_master WHERE name = 'task_undone_counter' AND type = 'trigger';" 2>/dev/null || echo "")
	if [[ -z "$has_undone" ]]; then
		sqlite3 "$DB_FILE" "
			CREATE TRIGGER IF NOT EXISTS task_undone_counter
			AFTER UPDATE OF status ON tasks
			WHEN OLD.status = 'done' AND NEW.status <> 'done'
			BEGIN
				UPDATE waves SET tasks_done = MAX(0, tasks_done - 1) WHERE id = NEW.wave_id_fk;
				UPDATE plans SET tasks_done = MAX(0, tasks_done - 1) WHERE id = NEW.plan_id;
			END;
		" 2>/dev/null || true
	fi

	# wave_auto_complete: should transition to 'merging' (not 'done') and exclude merging/cancelled
	local wave_trigger_sql
	wave_trigger_sql=$(sqlite3 "$DB_FILE" "SELECT sql FROM sqlite_master WHERE name = 'wave_auto_complete' AND type = 'trigger';" 2>/dev/null || echo "")
	if echo "$wave_trigger_sql" | grep -q "status = 'done'" 2>/dev/null; then
		sqlite3 "$DB_FILE" "
			DROP TRIGGER IF EXISTS wave_auto_complete;
			CREATE TRIGGER wave_auto_complete
			AFTER UPDATE OF tasks_done ON waves
			WHEN NEW.tasks_done = NEW.tasks_total AND NEW.tasks_total > 0
				AND NEW.status NOT IN ('done', 'merging', 'cancelled')
			BEGIN
				UPDATE waves SET status = 'merging', completed_at = COALESCE(completed_at, datetime('now')) WHERE id = NEW.id;
			END;
		" 2>/dev/null || true
	fi
}

# Escape single quotes for SQL
sql_escape() {
	printf '%s' "$1" | tr '\n\r' '  ' | sed "s/'/''/g"
}

# Convert YAML spec to temp JSON, or pass JSON through unchanged.
# Usage: effective_path=$(yaml_to_json_temp "$spec_file")
# Caller MUST rm "$effective_path" when done IF input was YAML.
yaml_to_json_temp() {
	local spec_file="$1"
	if [[ "$spec_file" == *.yaml || "$spec_file" == *.yml ]]; then
		local tmp
		tmp=$(mktemp /tmp/plan-spec-XXXX.json)
		python3 -c "import yaml, json, sys; print(json.dumps(yaml.safe_load(open(sys.argv[1]))))" "$spec_file" >"$tmp" || {
			log_error "Failed to convert YAML to JSON: $spec_file"
			rm -f "$tmp"
			return 1
		}
		echo "$tmp"
	else
		echo "$spec_file"
	fi
}

# ============================================================
# SSH and Sync Configuration Helpers
# ============================================================

# Load sync configuration from sync-db.conf
load_sync_config() {
	local config_file="${HOME}/.claude/config/sync-db.conf"

	# Set defaults
	REMOTE_HOST="${REMOTE_HOST:-omarchy-ts}"
	REMOTE_DB="${REMOTE_DB:-~/.claude/data/dashboard.db}"

	# Source config file if it exists
	if [[ -f "$config_file" ]]; then
		source "$config_file"
	fi
}

# Check SSH connectivity to remote host
# Returns: 0 if connectable, 1 if not
ssh_check() {
	load_sync_config
	ssh -o ConnectTimeout=5 -o BatchMode=yes "$REMOTE_HOST" "echo ok" &>/dev/null
	return $?
}

# Get remote host from config
get_remote_host() {
	load_sync_config
	echo "$REMOTE_HOST"
}

# Check if local and remote ~/.claude configs are in sync
# Returns: SYNCED (both at same commit), PUSHED (auto-pushed local changes), DIVERGED (manual intervention needed)
config_sync_check() {
	load_sync_config

	# Get local HEAD
	local local_head
	local_head=$(cd ~/.claude && git rev-parse HEAD 2>/dev/null) || {
		echo "ERROR"
		return 1
	}

	# Check if remote is accessible
	if ! ssh_check; then
		echo "OFFLINE"
		return 0
	fi

	# Get remote HEAD
	local remote_head
	remote_head=$(ssh -o ConnectTimeout=5 "$REMOTE_HOST" "cd ~/.claude && git rev-parse HEAD 2>/dev/null") || {
		echo "ERROR"
		return 1
	}

	# Compare commits
	if [[ "$local_head" == "$remote_head" ]]; then
		echo "SYNCED"
		return 0
	fi

	# Check if remote is behind local (can be fast-forwarded)
	local merge_base
	merge_base=$(cd ~/.claude && git merge-base HEAD "$remote_head" 2>/dev/null)

	if [[ "$merge_base" == "$remote_head" ]]; then
		# Remote is behind, auto-push
		if "$SCRIPT_DIR/sync-claude-config.sh" push &>/dev/null; then
			echo "PUSHED"
			return 0
		else
			echo "PUSH_FAILED"
			return 1
		fi
	fi

	# Diverged - manual intervention needed
	echo "DIVERGED"
	return 2
}
