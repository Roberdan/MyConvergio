#!/usr/bin/env bash
# mesh-migrate-db.sh — DB migration helpers for mesh-migrate.sh
# Bash 3.2 compatible | v2.0.0

set -euo pipefail

CLAUDE_HOME="${CLAUDE_HOME:-$HOME/.claude}"
DB="${CLAUDE_HOME}/data/dashboard.db"
SSH_OPTS="-o ConnectTimeout=10 -o BatchMode=yes -o StrictHostKeyChecking=accept-new"
REMOTE_DB="~/.claude/data/dashboard.db"

# Stop local services holding DB connections (heartbeat, dashboard)
_migrate_db_quiesce() {
	echo "==> Quiescing local DB connections"

	# Stop heartbeat daemon if running
	if [[ -f "${CLAUDE_HOME}/data/mesh-heartbeat.pid" ]]; then
		local hb_pid
		hb_pid=$(cat "${CLAUDE_HOME}/data/mesh-heartbeat.pid" 2>/dev/null || echo "")
		if [[ -n "$hb_pid" ]] && kill -0 "$hb_pid" 2>/dev/null; then
			echo "  Stopping heartbeat daemon (PID ${hb_pid})"
			"${CLAUDE_HOME}/scripts/mesh-heartbeat.sh" stop 2>/dev/null || kill "$hb_pid" 2>/dev/null || true
		fi
	fi

	# Find and report active DB connections (informational)
	local db_pids
	db_pids=$(lsof "$DB" 2>/dev/null | awk 'NR>1{print $2}' | sort -u || echo "")
	if [[ -n "$db_pids" ]]; then
		echo "  Active DB connections: $(echo "$db_pids" | tr '\n' ' ')"
		echo "  Waiting 2s for connections to release..."
		sleep 2
	else
		echo "  No active DB connections"
	fi
}

# Restart services stopped by quiesce
_migrate_db_resume() {
	echo "==> Resuming local services"
	"${CLAUDE_HOME}/scripts/mesh-heartbeat.sh" start 2>/dev/null || true
}

# Flush WAL before copy with retry + quiesce protocol (C-04)
_migrate_db_checkpoint() {
	local wal="${DB}-wal" shm="${DB}-shm"
	local max_retries=3 attempt=0

	_migrate_db_quiesce

	while [[ $attempt -lt $max_retries ]]; do
		attempt=$((attempt + 1))
		echo "==> Checkpointing local DB (attempt ${attempt}/${max_retries})"
		sqlite3 "$DB" ".timeout 10000" "PRAGMA wal_checkpoint(TRUNCATE);" 2>/dev/null || true

		# Verify WAL is empty or gone
		if [[ ! -f "$wal" ]] || [[ ! -s "$wal" ]]; then
			echo "Checkpoint complete — WAL clean"
			return 0
		fi

		if [[ $attempt -lt $max_retries ]]; then
			echo "  WAL still has content, retrying in 3s..."
			sleep 3
		fi
	done

	# WAL not empty after retries — warn but don't block (copy will include WAL files)
	echo "WARN: WAL not fully flushed after ${max_retries} attempts — will copy WAL files too" >&2
}

# Stop remote DB connections before overwriting (C-04)
# Args: target_dest
_migrate_db_quiesce_remote() {
	local dest="$1"
	echo "==> Quiescing remote DB connections on ${dest}"

	# Stop remote heartbeat daemon
	ssh $SSH_OPTS "$dest" \
		"~/.claude/scripts/mesh-heartbeat.sh stop 2>/dev/null || true" 2>/dev/null || true

	# Checkpoint remote WAL (prevent corruption on overwrite)
	ssh $SSH_OPTS "$dest" \
		"sqlite3 ~/.claude/data/dashboard.db '.timeout 5000' 'PRAGMA wal_checkpoint(TRUNCATE);' 2>/dev/null || true" \
		2>/dev/null || true

	# Brief pause for connections to close
	sleep 1
}

# Copy DB (+ WAL/SHM if present) to target and verify integrity (C-04)
# Args: target_dest
_migrate_db_copy() {
	local dest="$1"
	local wal="${DB}-wal" shm="${DB}-shm"

	_migrate_db_quiesce_remote "$dest"

	echo "==> Copying DB to ${dest}:${REMOTE_DB}"
	scp -o ConnectTimeout=10 -o BatchMode=yes "$DB" "${dest}:${REMOTE_DB}"

	# Copy WAL/SHM files if they exist and have content (belt-and-suspenders)
	if [[ -f "$wal" ]] && [[ -s "$wal" ]]; then
		echo "  Copying WAL file ($(wc -c <"$wal") bytes)"
		scp -o ConnectTimeout=10 -o BatchMode=yes "$wal" "${dest}:${REMOTE_DB}-wal"
	else
		# Clean up remote WAL/SHM if local is clean
		ssh $SSH_OPTS "$dest" "rm -f ~/.claude/data/dashboard.db-wal ~/.claude/data/dashboard.db-shm" 2>/dev/null || true
	fi
	if [[ -f "$shm" ]] && [[ -s "$shm" ]]; then
		scp -o ConnectTimeout=10 -o BatchMode=yes "$shm" "${dest}:${REMOTE_DB}-shm"
	fi

	echo "==> Verifying integrity on target"
	local result
	result=$(ssh $SSH_OPTS "$dest" \
		"sqlite3 ~/.claude/data/dashboard.db '.timeout 5000' 'PRAGMA integrity_check;'" \
		2>/dev/null || echo "error")
	if [[ "$result" != "ok" ]]; then
		echo "ERROR: integrity_check failed: ${result}" >&2
		return 1
	fi
	echo "Integrity check: ok"
	return 0
}

# Remap absolute home paths in plans/waves tables on target
# Args: target_dest source_home target_home
_migrate_db_remap_paths() {
	local dest="$1"
	local src_home="$2"
	local tgt_home="$3"

	# If both use ~ prefix, no remap needed
	if [[ "$src_home" == "$tgt_home" ]]; then
		echo "Path prefix identical — no remap needed"
		return 0
	fi

	echo "==> Remapping paths: ${src_home} → ${tgt_home}"

	# Remap plans.worktree_path
	local plan_count
	plan_count=$(ssh $SSH_OPTS "$dest" \
		"sqlite3 ~/.claude/data/dashboard.db '.timeout 5000' \
     \"SELECT COUNT(*) FROM plans WHERE worktree_path LIKE '${src_home}%';\"" \
		2>/dev/null || echo "0")
	echo "  Plans to remap: ${plan_count}"

	ssh $SSH_OPTS "$dest" \
		"sqlite3 ~/.claude/data/dashboard.db '.timeout 5000' \
     \"UPDATE plans SET worktree_path=REPLACE(worktree_path,'${src_home}','${tgt_home}') \
       WHERE worktree_path LIKE '${src_home}%';\""

	# Remap waves.worktree_path
	local wave_count
	wave_count=$(ssh $SSH_OPTS "$dest" \
		"sqlite3 ~/.claude/data/dashboard.db '.timeout 5000' \
     \"SELECT COUNT(*) FROM waves WHERE worktree_path LIKE '${src_home}%';\"" \
		2>/dev/null || echo "0")
	echo "  Waves to remap: ${wave_count}"

	ssh $SSH_OPTS "$dest" \
		"sqlite3 ~/.claude/data/dashboard.db '.timeout 5000' \
     \"UPDATE waves SET worktree_path=REPLACE(worktree_path,'${src_home}','${tgt_home}') \
       WHERE worktree_path LIKE '${src_home}%';\""

	echo "Path remap complete"
}

# Transfer plan ownership to target host (C-01, C-03)
# Args: plan_id target_dest target_hostname
_migrate_transfer_plan() {
	local plan_id="$1"
	local dest="$2"
	local target_host="$3"

	# Validate plan_id numeric
	if ! [[ "$plan_id" =~ ^[0-9]+$ ]]; then
		echo "ERROR: plan_id must be numeric, got: ${plan_id}" >&2
		return 1
	fi

	echo "==> Transferring plan ${plan_id} to ${target_host}"

	# Reset in_progress tasks to pending on target
	local reset_count
	reset_count=$(ssh $SSH_OPTS "$dest" \
		"sqlite3 ~/.claude/data/dashboard.db '.timeout 5000' \
     \"SELECT COUNT(*) FROM tasks WHERE status='in_progress' \
       AND wave_id_fk IN (SELECT id FROM waves WHERE plan_id=${plan_id});\"" \
		2>/dev/null || echo "0")
	echo "  Resetting ${reset_count} in_progress task(s) to pending"

	ssh $SSH_OPTS "$dest" \
		"sqlite3 ~/.claude/data/dashboard.db '.timeout 5000' \
     \"UPDATE tasks SET status='pending' WHERE status='in_progress' \
       AND wave_id_fk IN (SELECT id FROM waves WHERE plan_id=${plan_id});\""

	# Update execution_host on target
	ssh $SSH_OPTS "$dest" \
		"sqlite3 ~/.claude/data/dashboard.db '.timeout 5000' \
     \"UPDATE plans SET execution_host='${target_host}' WHERE id=${plan_id}; \
       UPDATE tasks SET executor_host='${target_host}' WHERE plan_id=${plan_id};\""

	# Release plan claim on source
	echo "  Releasing plan ${plan_id} on source"
	sqlite3 "$DB" ".timeout 5000" \
		"UPDATE plans SET execution_host='' WHERE id=${plan_id};" 2>/dev/null || true

	echo "Transfer complete: plan ${plan_id} → ${target_host}"
}

# Rollback: restore target DB from backup (C-03)
# Args: target_dest backup_path
_migrate_db_rollback() {
	local dest="$1"
	local backup_path="$2"

	echo "==> Rolling back target DB from ${backup_path}"
	ssh $SSH_OPTS "$dest" \
		"cp '${backup_path}' ~/.claude/data/dashboard.db && \
     sqlite3 ~/.claude/data/dashboard.db '.timeout 5000' 'PRAGMA integrity_check;'" \
		2>/dev/null || {
		echo "ERROR: rollback failed — manual restore required on ${dest}" >&2
		return 1
	}
	echo "Rollback complete — source plan remains active"
}
