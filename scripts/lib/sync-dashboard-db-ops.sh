#!/bin/bash
# sync-dashboard-db-ops.sh - DB sync operations (push/pull/incremental)
# Extracted from sync-dashboard-db.sh for modularization
# Version: 1.1.0 - Fixed task-level sync detection + trigger safety

# ============================================================================
# Internal: restore task triggers after sync operations
# ============================================================================
_restore_task_triggers() {
	sqlite3 "$LOCAL_DB" "
		CREATE TRIGGER IF NOT EXISTS task_done_counter
		AFTER UPDATE OF status ON tasks
		WHEN NEW.status = 'done' AND OLD.status != 'done'
		BEGIN
			UPDATE waves SET tasks_done = tasks_done + 1 WHERE id = NEW.wave_id_fk;
			UPDATE plans SET tasks_done = tasks_done + 1 WHERE id = NEW.plan_id;
		END;
		CREATE TRIGGER IF NOT EXISTS task_undone_counter
		AFTER UPDATE OF status ON tasks
		WHEN OLD.status = 'done' AND NEW.status != 'done'
		BEGIN
			UPDATE waves SET tasks_done = tasks_done - 1 WHERE id = NEW.wave_id_fk;
			UPDATE plans SET tasks_done = tasks_done - 1 WHERE id = NEW.plan_id;
		END;
		CREATE TRIGGER IF NOT EXISTS enforce_thor_done
		BEFORE UPDATE OF status ON tasks
		WHEN NEW.status = 'done' AND OLD.status <> 'done'
		BEGIN
			SELECT RAISE(ABORT, 'BLOCKED: Only Thor can set status=done. validated_by must be thor/thor-quality-assurance-guardian/thor-per-wave/forced-admin.')
			WHERE OLD.status <> 'submitted'
				OR NEW.validated_by IS NULL
				OR NEW.validated_by NOT IN ('thor', 'thor-quality-assurance-guardian', 'thor-per-wave', 'forced-admin');
		END;
	" 2>/dev/null
}

# ============================================================================
# Schema-safe sync: handles column mismatches between local and remote DBs
# ============================================================================
_sync_table_safe() {
	local db_path="$1" attached_db="$2" table="$3" where_clause="$4"
	# Step 1: Get common columns (own ATTACH session)
	local common_cols
	common_cols=$(sqlite3 "$db_path" "
		ATTACH '$attached_db' AS _src;
		SELECT GROUP_CONCAT(name) FROM (
			SELECT p1.name FROM pragma_table_info('$table') p1
			INNER JOIN _src.pragma_table_info('$table') p2 ON p1.name = p2.name
			ORDER BY p1.cid
		);
	" 2>&1)
	if [[ -z "$common_cols" || "$common_cols" == *"Error"* ]]; then
		log_warn "No common columns for $table (db=$attached_db): $common_cols"
		return 1
	fi
	# Step 2: Do the INSERT OR REPLACE (own ATTACH session)
	sqlite3 "$db_path" "
		ATTACH '$attached_db' AS _src;
		INSERT OR REPLACE INTO $table ($common_cols) SELECT $common_cols FROM _src.$table WHERE $where_clause;
	" 2>&1
}

# ============================================================================
# Resolve SSH host from canonical hostname (uses MESH_HOSTS from config)
# ============================================================================
_resolve_ssh_host() {
	local canonical="$1"
	local varname="MESH_HOST_${canonical}"
	local resolved="${!varname}"
	if [[ -n "$resolved" ]]; then
		echo "$resolved"
	else
		echo "$REMOTE_HOST"
	fi
}

# ============================================================================
# Backup operations
# ============================================================================
backup_local() {
	ensure_backup_dir "$BACKUP_DIR"
	cp "$LOCAL_DB" "$BACKUP_DIR/dashboard_local_$TIMESTAMP.db"
	log_info "Local backup: $BACKUP_DIR/dashboard_local_$TIMESTAMP.db"
}

backup_remote() {
	ssh -o ConnectTimeout=10 "$REMOTE_HOST" "mkdir -p ~/.claude/data/backups && cp $REMOTE_DB ~/.claude/data/backups/dashboard_remote_$TIMESTAMP.db"
	log_info "Remote backup created"
}

# ============================================================================
# Status display
# ============================================================================
show_status() {
	log_info "=== Local DB (Mac) ==="
	sqlite3 "$LOCAL_DB" "SELECT id, name, status, tasks_done||'/'||tasks_total as progress, COALESCE(execution_host, '-') as host FROM plans WHERE status != 'done' OR completed_at > datetime('now', '-7 days') ORDER BY id DESC LIMIT 10;"

	echo ""
	log_info "=== Remote DB (Linux) ==="
	ssh -o ConnectTimeout=10 "$REMOTE_HOST" "sqlite3 $REMOTE_DB \"SELECT id, name, status, tasks_done||'/'||tasks_total as progress, COALESCE(execution_host, '-') as host FROM plans WHERE status != 'done' OR completed_at > datetime('now', '-7 days') ORDER BY id DESC LIMIT 10;\""
}

# ============================================================================
# Plan synchronization
# ============================================================================
sync_plans() {
	local direction=$1
	if [[ "$direction" == "pull" ]]; then
		log_info "Syncing: Linux → Mac (full plan data)"
		scp "$REMOTE_HOST:$REMOTE_DB" "/tmp/sync_source.db"
		local plan_ids
		plan_ids=$(sqlite3 "$LOCAL_DB" "
			ATTACH '/tmp/sync_source.db' AS src;
			SELECT DISTINCT src_p.id FROM src.plans src_p
			LEFT JOIN plans p ON p.id = src_p.id
			LEFT JOIN src.tasks src_t ON src_t.plan_id = src_p.id
			LEFT JOIN tasks t ON t.id = src_t.id
			WHERE src_p.status != COALESCE(p.status, '')
			   OR src_p.tasks_done != COALESCE(p.tasks_done, 0)
			   OR p.id IS NULL
			   OR src_t.status != COALESCE(t.status, '');
			DETACH src;
		" 2>/dev/null)
		# Pre-compute common columns once
		local plan_cols wave_cols task_cols
		plan_cols=$(sqlite3 "$LOCAL_DB" "ATTACH '/tmp/sync_source.db' AS _src; SELECT GROUP_CONCAT(name) FROM (SELECT p1.name FROM pragma_table_info('plans') p1 INNER JOIN _src.pragma_table_info('plans') p2 ON p1.name = p2.name ORDER BY p1.cid);" 2>&1)
		wave_cols=$(sqlite3 "$LOCAL_DB" "ATTACH '/tmp/sync_source.db' AS _src; SELECT GROUP_CONCAT(name) FROM (SELECT p1.name FROM pragma_table_info('waves') p1 INNER JOIN _src.pragma_table_info('waves') p2 ON p1.name = p2.name ORDER BY p1.cid);" 2>&1)
		task_cols=$(sqlite3 "$LOCAL_DB" "ATTACH '/tmp/sync_source.db' AS _src; SELECT GROUP_CONCAT(name) FROM (SELECT p1.name FROM pragma_table_info('tasks') p1 INNER JOIN _src.pragma_table_info('tasks') p2 ON p1.name = p2.name ORDER BY p1.cid);" 2>&1)
		for id in $plan_ids; do
			[[ -z "$id" ]] && continue
			log_info "Pull plan $id"
			sqlite3 "$LOCAL_DB" "
				DROP TRIGGER IF EXISTS enforce_thor_done;
				DROP TRIGGER IF EXISTS task_done_counter;
				DROP TRIGGER IF EXISTS task_undone_counter;
				ATTACH '/tmp/sync_source.db' AS _src;
				INSERT OR REPLACE INTO plans ($plan_cols) SELECT $plan_cols FROM _src.plans WHERE id=$id;
				INSERT OR REPLACE INTO waves ($wave_cols) SELECT $wave_cols FROM _src.waves WHERE plan_id=$id;
				INSERT OR REPLACE INTO tasks ($task_cols) SELECT $task_cols FROM _src.tasks WHERE plan_id=$id;
				DETACH _src;
				UPDATE waves SET tasks_done = (SELECT COUNT(*) FROM tasks WHERE tasks.wave_id_fk = waves.id AND tasks.status = 'done'), tasks_total = (SELECT COUNT(*) FROM tasks WHERE tasks.wave_id_fk = waves.id) WHERE plan_id = $id;
				UPDATE plans SET tasks_done = (SELECT COALESCE(SUM(tasks_done), 0) FROM waves WHERE waves.plan_id = plans.id), tasks_total = (SELECT COALESCE(SUM(tasks_total), 0) FROM waves WHERE waves.plan_id = plans.id) WHERE id = $id;
			" 2>&1 || log_warn "Sync failed for plan $id"
		done
		# Restore triggers after sync
		_restore_task_triggers
		rm -f /tmp/sync_source.db

	elif [[ "$direction" == "push" ]]; then
		log_info "Syncing: Mac → Linux (full plan data)"
		scp "$LOCAL_DB" "$REMOTE_HOST:/tmp/sync_source.db"
		ssh -o ConnectTimeout=10 "$REMOTE_HOST" bash -s -- "$REMOTE_DB" <<'PUSH_SCRIPT'
DB="$1"
# Schema-safe column intersection helper
_common_cols() {
	local tbl="$1"
	local lcols rcols
	lcols=$(sqlite3 "$DB" "PRAGMA table_info($tbl);" | cut -d'|' -f2 | sort)
	rcols=$(sqlite3 "$DB" "PRAGMA src.table_info($tbl);" | cut -d'|' -f2 | sort)
	comm -12 <(echo "$lcols") <(echo "$rcols") | tr '\n' ',' | sed 's/,$//'
}
for id in $(sqlite3 "$DB" "
	ATTACH '/tmp/sync_source.db' AS src;
	SELECT DISTINCT src_p.id FROM src.plans src_p LEFT JOIN plans p ON p.id = src_p.id
	LEFT JOIN src.tasks src_t ON src_t.plan_id = src_p.id
	LEFT JOIN tasks t ON t.id = src_t.id
	WHERE src_p.status != COALESCE(p.status, '')
	   OR src_p.tasks_done != COALESCE(p.tasks_done, 0)
	   OR p.id IS NULL
	   OR src_t.status != COALESCE(t.status, '');
	DETACH src;
"); do
	[ -z "$id" ] && continue
	echo "[INFO] Push plan $id"
	sqlite3 "$DB" "ATTACH '/tmp/sync_source.db' AS src;"
	PCOLS=$(_common_cols "plans")
	WCOLS=$(_common_cols "waves")
	TCOLS=$(_common_cols "tasks")
	sqlite3 "$DB" "
		DROP TRIGGER IF EXISTS enforce_thor_done;
		DROP TRIGGER IF EXISTS task_done_counter;
		DROP TRIGGER IF EXISTS task_undone_counter;
		ATTACH '/tmp/sync_source.db' AS src;
		INSERT OR REPLACE INTO plans ($PCOLS) SELECT $PCOLS FROM src.plans WHERE id=$id;
		INSERT OR REPLACE INTO waves ($WCOLS) SELECT $WCOLS FROM src.waves WHERE plan_id=$id;
		INSERT OR REPLACE INTO tasks ($TCOLS) SELECT $TCOLS FROM src.tasks WHERE plan_id=$id;
		DETACH src;
		UPDATE waves SET tasks_done = (SELECT COUNT(*) FROM tasks WHERE tasks.wave_id_fk = waves.id AND tasks.status = 'done'), tasks_total = (SELECT COUNT(*) FROM tasks WHERE tasks.wave_id_fk = waves.id) WHERE plan_id = $id;
		UPDATE plans SET tasks_done = (SELECT COALESCE(SUM(tasks_done), 0) FROM waves WHERE waves.plan_id = plans.id), tasks_total = (SELECT COALESCE(SUM(tasks_total), 0) FROM waves WHERE waves.plan_id = plans.id) WHERE id = $id;
		CREATE TRIGGER IF NOT EXISTS task_done_counter AFTER UPDATE OF status ON tasks WHEN NEW.status = 'done' AND OLD.status != 'done' BEGIN UPDATE waves SET tasks_done = tasks_done + 1 WHERE id = NEW.wave_id_fk; UPDATE plans SET tasks_done = tasks_done + 1 WHERE id = NEW.plan_id; END;
		CREATE TRIGGER IF NOT EXISTS task_undone_counter AFTER UPDATE OF status ON tasks WHEN OLD.status = 'done' AND NEW.status != 'done' BEGIN UPDATE waves SET tasks_done = tasks_done - 1 WHERE id = NEW.wave_id_fk; UPDATE plans SET tasks_done = tasks_done - 1 WHERE id = NEW.plan_id; END;
		CREATE TRIGGER IF NOT EXISTS enforce_thor_done BEFORE UPDATE OF status ON tasks WHEN NEW.status = 'done' AND OLD.status <> 'done' BEGIN SELECT RAISE(ABORT, 'BLOCKED: Only Thor can set status=done.') WHERE OLD.status <> 'submitted' OR NEW.validated_by IS NULL OR NEW.validated_by NOT IN ('thor','thor-quality-assurance-guardian','thor-per-wave','forced-admin'); END;
	"
done
rm -f /tmp/sync_source.db
PUSH_SCRIPT
	fi
}

# ============================================================================
# Full sync operations
# ============================================================================
full_pull() {
	backup_local
	scp "$REMOTE_HOST:$REMOTE_DB" "$LOCAL_DB.new" && mv "$LOCAL_DB.new" "$LOCAL_DB"
	log_info "Full pull complete"
}

full_push() {
	backup_remote
	scp "$LOCAL_DB" "$REMOTE_HOST:$REMOTE_DB"
	log_info "Full push complete"
}

# ============================================================================
# Copy single plan
# ============================================================================
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
		ssh -o ConnectTimeout=10 "$REMOTE_HOST" bash -s -- "$REMOTE_DB" "$plan_id" <<'COPY_PUSH'
DB="$1"; PID="$2"
_common_cols() {
	local tbl="$1"
	comm -12 <(sqlite3 "$DB" "PRAGMA table_info($tbl);" | cut -d'|' -f2 | sort) \
	         <(sqlite3 "$DB" "PRAGMA src.table_info($tbl);" | cut -d'|' -f2 | sort) | tr '\n' ',' | sed 's/,$//'
}
sqlite3 "$DB" "ATTACH '/tmp/source_dashboard.db' AS src;"
PCOLS=$(_common_cols "plans"); WCOLS=$(_common_cols "waves"); TCOLS=$(_common_cols "tasks")
sqlite3 "$DB" "
	DROP TRIGGER IF EXISTS enforce_thor_done;
	DROP TRIGGER IF EXISTS task_done_counter;
	DROP TRIGGER IF EXISTS task_undone_counter;
	ATTACH '/tmp/source_dashboard.db' AS src;
	INSERT OR REPLACE INTO plans ($PCOLS) SELECT $PCOLS FROM src.plans WHERE id=$PID;
	INSERT OR REPLACE INTO waves ($WCOLS) SELECT $WCOLS FROM src.waves WHERE plan_id=$PID;
	INSERT OR REPLACE INTO tasks ($TCOLS) SELECT $TCOLS FROM src.tasks WHERE plan_id=$PID;
	DETACH src;
	UPDATE waves SET tasks_done = (SELECT COUNT(*) FROM tasks WHERE tasks.wave_id_fk = waves.id AND tasks.status = 'done'), tasks_total = (SELECT COUNT(*) FROM tasks WHERE tasks.wave_id_fk = waves.id) WHERE plan_id = $PID;
	UPDATE plans SET tasks_done = (SELECT COALESCE(SUM(tasks_done), 0) FROM waves WHERE waves.plan_id = plans.id), tasks_total = (SELECT COALESCE(SUM(tasks_total), 0) FROM waves WHERE waves.plan_id = plans.id) WHERE id = $PID;
	CREATE TRIGGER IF NOT EXISTS task_done_counter AFTER UPDATE OF status ON tasks WHEN NEW.status = 'done' AND OLD.status != 'done' BEGIN UPDATE waves SET tasks_done = tasks_done + 1 WHERE id = NEW.wave_id_fk; UPDATE plans SET tasks_done = tasks_done + 1 WHERE id = NEW.plan_id; END;
	CREATE TRIGGER IF NOT EXISTS task_undone_counter AFTER UPDATE OF status ON tasks WHEN OLD.status = 'done' AND NEW.status != 'done' BEGIN UPDATE waves SET tasks_done = tasks_done - 1 WHERE id = NEW.wave_id_fk; UPDATE plans SET tasks_done = tasks_done - 1 WHERE id = NEW.plan_id; END;
	CREATE TRIGGER IF NOT EXISTS enforce_thor_done BEFORE UPDATE OF status ON tasks WHEN NEW.status = 'done' AND OLD.status <> 'done' BEGIN SELECT RAISE(ABORT, 'BLOCKED: Only Thor can set status=done.') WHERE OLD.status <> 'submitted' OR NEW.validated_by IS NULL OR NEW.validated_by NOT IN ('thor','thor-quality-assurance-guardian','thor-per-wave','forced-admin'); END;
" && rm /tmp/source_dashboard.db
COPY_PUSH
		log_info "Plan $plan_id copied to remote (counters resynced)"
	else
		log_info "Copying plan $plan_id: Remote → Local"
		scp "$REMOTE_HOST:$REMOTE_DB" "/tmp/source_dashboard.db"
		# Drop triggers, sync, recalculate, restore — all in one session
		# Get common columns for each table
		local plan_cols wave_cols task_cols
		plan_cols=$(sqlite3 "$LOCAL_DB" "ATTACH '/tmp/source_dashboard.db' AS _src; SELECT GROUP_CONCAT(name) FROM (SELECT p1.name FROM pragma_table_info('plans') p1 INNER JOIN _src.pragma_table_info('plans') p2 ON p1.name = p2.name ORDER BY p1.cid);" 2>&1)
		wave_cols=$(sqlite3 "$LOCAL_DB" "ATTACH '/tmp/source_dashboard.db' AS _src; SELECT GROUP_CONCAT(name) FROM (SELECT p1.name FROM pragma_table_info('waves') p1 INNER JOIN _src.pragma_table_info('waves') p2 ON p1.name = p2.name ORDER BY p1.cid);" 2>&1)
		task_cols=$(sqlite3 "$LOCAL_DB" "ATTACH '/tmp/source_dashboard.db' AS _src; SELECT GROUP_CONCAT(name) FROM (SELECT p1.name FROM pragma_table_info('tasks') p1 INNER JOIN _src.pragma_table_info('tasks') p2 ON p1.name = p2.name ORDER BY p1.cid);" 2>&1)
		if [[ -z "$task_cols" || "$task_cols" == *"Error"* ]]; then
			log_warn "Schema detection failed for plan $plan_id: $task_cols"
			rm -f /tmp/source_dashboard.db
			return 1
		fi
		# Session 1: Drop triggers and sync all data
		sqlite3 "$LOCAL_DB" "
			DROP TRIGGER IF EXISTS enforce_thor_done;
			DROP TRIGGER IF EXISTS task_done_counter;
			DROP TRIGGER IF EXISTS task_undone_counter;
			ATTACH '/tmp/source_dashboard.db' AS _src;
			INSERT OR REPLACE INTO plans ($plan_cols) SELECT $plan_cols FROM _src.plans WHERE id=$plan_id;
			INSERT OR REPLACE INTO waves ($wave_cols) SELECT $wave_cols FROM _src.waves WHERE plan_id=$plan_id;
			INSERT OR REPLACE INTO tasks ($task_cols) SELECT $task_cols FROM _src.tasks WHERE plan_id=$plan_id;
		" 2>&1 || log_warn "Data sync failed for plan $plan_id"
		rm -f /tmp/source_dashboard.db
		# Session 2: Recalculate counters (separate session ensures data is committed)
		sqlite3 "$LOCAL_DB" "
			UPDATE waves SET tasks_done = (SELECT COUNT(*) FROM tasks WHERE tasks.wave_id_fk = waves.id AND tasks.status = 'done'), tasks_total = (SELECT COUNT(*) FROM tasks WHERE tasks.wave_id_fk = waves.id) WHERE plan_id = $plan_id;
			UPDATE plans SET tasks_done = (SELECT COALESCE(SUM(tasks_done), 0) FROM waves WHERE waves.plan_id = plans.id), tasks_total = (SELECT COALESCE(SUM(tasks_total), 0) FROM waves WHERE waves.plan_id = plans.id) WHERE id = $plan_id;
		" 2>&1 || log_warn "Counter recalc failed for plan $plan_id"
		_restore_task_triggers
		log_info "Plan $plan_id copied to local (counters resynced)"
	fi
}

# ============================================================================
# Incremental sync
# ============================================================================
incremental_sync() {
	local last_sync=""
	local sync_file="$HOME/.claude/data/last-sync.txt"
	[[ -f "$sync_file" ]] && last_sync=$(cat "$sync_file")

	local since_clause=""
	if [[ -n "$last_sync" ]]; then
		since_clause="AND updated_at > '$last_sync'"
		log_info "Incremental sync since: $last_sync"
	else
		since_clause="AND updated_at > datetime('now', '-24 hours')"
		log_info "First sync: last 24 hours"
	fi

	# Resolve local hostname for execution_host routing
	local local_host="${LOCAL_CANONICAL_HOST:-${HOSTNAME:-$(hostname -s 2>/dev/null || hostname)}}"
	local_host="${local_host%.local}"
	local safe_local_host
	safe_local_host=$(sql_lit "$local_host")

	# PUSH: locally-executed plans changed since last sync
	local pid
	sqlite3 "$LOCAL_DB" "
		SELECT id FROM plans
		WHERE (execution_host IS NULL OR execution_host = '' OR execution_host = '$safe_local_host')
		$since_clause;
	" 2>/dev/null | while read -r pid; do
		[[ -z "$pid" ]] && continue
		log_info "Push plan $pid → remote (local)"
		copy_plan "$pid" "push"
	done

	# PULL: active plans executed on remote hosts (no since filter - always pull latest)
	# Only sync plans that are actively running (doing/todo), skip done/cancelled
	sqlite3 "$LOCAL_DB" "
		SELECT DISTINCT id, COALESCE(execution_host, '') FROM plans
		WHERE execution_host IS NOT NULL AND execution_host != ''
		AND execution_host != '$safe_local_host' AND status IN ('doing', 'todo');
	" 2>/dev/null | while IFS='|' read -r pid exec_host; do
		[[ -z "$pid" ]] && continue
		local ssh_host
		ssh_host=$(_resolve_ssh_host "$exec_host")
		if [[ "$ssh_host" == "localhost" ]]; then
			log_info "Skip plan $pid — execution_host=$exec_host is local"
			continue
		fi
		log_info "Pull plan $pid ← $exec_host (via $ssh_host)"
		# Override REMOTE_HOST for this copy_plan call
		local saved_host="$REMOTE_HOST"
		REMOTE_HOST="$ssh_host"
		copy_plan "$pid" "pull" || log_warn "Failed to pull plan $pid from $exec_host"
		REMOTE_HOST="$saved_host"
	done

	# Sync token_usage (T4-06)
	local token_count
	token_count=$(sqlite3 "$LOCAL_DB" "SELECT COUNT(*) FROM token_usage WHERE 1=1 $since_clause;" 2>/dev/null || echo 0)

	if [[ "$token_count" -gt 0 ]]; then
		log_info "Syncing $token_count token_usage rows"
		sqlite3 "$LOCAL_DB" ".dump token_usage" | ssh -o ConnectTimeout=10 "$REMOTE_HOST" \
			"sqlite3 $REMOTE_DB" 2>/dev/null || log_warn "Token sync partial"
	fi

	# Sync heartbeats (batch: build SQL locally, execute once on remote)
	local heartbeat_sql=""
	while IFS='|' read -r host seen count os; do
		local safe_host safe_seen safe_os
		safe_host=$(sql_lit "$host")
		safe_seen=$(sql_lit "$seen")
		safe_os=$(sql_lit "$os")
		heartbeat_sql="${heartbeat_sql}INSERT OR REPLACE INTO host_heartbeats (host, last_seen, plan_count, os) VALUES ('$safe_host', '$safe_seen', $count, '$safe_os');"
	done < <(sqlite3 "$LOCAL_DB" "SELECT host, last_seen, plan_count, os FROM host_heartbeats;" 2>/dev/null)

	if [[ -n "$heartbeat_sql" ]]; then
		ssh -o ConnectTimeout=10 "$REMOTE_HOST" "sqlite3 $REMOTE_DB \"BEGIN TRANSACTION;${heartbeat_sql}COMMIT;\"" 2>/dev/null || log_warn "Heartbeat sync partial"
	fi

	date '+%Y-%m-%d %H:%M:%S' >"$sync_file"
	log_info "Incremental sync complete"
}

# ============================================================================
# Diagnostics
# ============================================================================
diagnose_sync() {
	log_info "=== DIAGNOSTIC MODE ==="
	log_info "Config: LOCAL_DB=$LOCAL_DB REMOTE_DB=$REMOTE_DB REMOTE_HOST=$REMOTE_HOST"

	local sync_file="$HOME/.claude/data/last-sync.txt"
	if [[ -f "$sync_file" ]]; then
		log_info "Last sync: $(cat "$sync_file")"
	else
		log_warn "No last-sync.txt found (first sync)"
	fi

	log_info "--- Local DB check ---"
	if [[ ! -f "$LOCAL_DB" ]]; then
		log_error "Local DB missing: $LOCAL_DB"
		return 1
	fi
	ls -la "$LOCAL_DB"
	sqlite3 "$LOCAL_DB" "SELECT 'plans:', COUNT(*) FROM plans; SELECT 'tasks:', COUNT(*) FROM tasks; SELECT 'waves:', COUNT(*) FROM waves;" 2>&1 || log_error "Local DB query failed"

	log_info "--- SSH connectivity ---"
	ssh -v -o ConnectTimeout=5 "$REMOTE_HOST" "echo 'SSH OK'; ls -la $REMOTE_DB" 2>&1

	log_info "--- Remote DB check ---"
	ssh -o ConnectTimeout=10 "$REMOTE_HOST" "sqlite3 $REMOTE_DB \"SELECT 'plans:', COUNT(*) FROM plans; SELECT 'tasks:', COUNT(*) FROM tasks; SELECT 'waves:', COUNT(*) FROM waves;\"" 2>&1 || log_error "Remote DB query failed"

	log_info "--- Running incremental sync with tracing ---"
	(
		set -x
		incremental_sync
	) 2>&1

	log_info "=== DIAGNOSTIC COMPLETE ==="
}
