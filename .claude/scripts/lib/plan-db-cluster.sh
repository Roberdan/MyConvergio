#!/bin/bash
# Plan DB Cluster - Distributed execution support
# Functions for claim/release/heartbeat/liveness checking
# Sourced by plan-db.sh

# ============================================================
# cmd_claim <plan_id> [--force]
# ============================================================
# Atomically claim a plan for execution on this host
# Sets execution_host to $PLAN_DB_HOST and status to 'doing'
# Prevents double-claiming unless --force is used
# Checks config sync before claiming
# SSH timeout (seconds) - configurable via environment variable
PLAN_DB_SSH_TIMEOUT="${PLAN_DB_SSH_TIMEOUT:-5}"

# Version: 1.1.0
cmd_claim() {
	local plan_id="$1"
	local force=0

	if [[ "${2:-}" == "--force" ]]; then
		force=1
	fi

	# Verify plan_id is a number
	if ! [[ "$plan_id" =~ ^[0-9]+$ ]]; then
		log_error "Invalid plan_id: $plan_id"
		return 1
	fi

	# Check config sync before claiming
	local sync_status
	sync_status=$(config_sync_check)

	if [[ "$sync_status" == "DIVERGED" ]]; then
		log_error "Config diverged between local and remote. Run 'dbsync pull' or 'dbsync push' to resolve."
		return 1
	elif [[ "$sync_status" == "ERROR" ]]; then
		log_warn "Could not verify config sync status. Proceeding anyway."
	elif [[ "$sync_status" == "PUSHED" ]]; then
		log_info "Auto-pushed local config changes to remote"
	fi

	init_db

	local safe_host
	safe_host=$(sql_escape "$PLAN_DB_HOST")

	if [[ $force -eq 1 ]]; then
		# Force claim: unconditional update
		sqlite3 "$DB_FILE" <<-EOF
			UPDATE plans
			SET execution_host = '${safe_host}',
			    status = 'doing',
			    started_at = COALESCE(started_at, datetime('now'))
			WHERE id = $plan_id;
		EOF

		log_info "Force-claimed plan $plan_id on $PLAN_DB_HOST"
		return 0
	fi

	# Atomic claim: only if unclaimed or already claimed by this host
	local rows_updated
	rows_updated=$(
		sqlite3 "$DB_FILE" <<-EOF
			UPDATE plans
			SET execution_host = '${safe_host}',
			    status = 'doing',
			    started_at = COALESCE(started_at, datetime('now'))
			WHERE id = $plan_id
			  AND (execution_host IS NULL OR execution_host = '${safe_host}');
			SELECT changes();
		EOF
	)

	if [[ "$rows_updated" -eq 0 ]]; then
		# Plan is claimed by someone else
		local current_host
		current_host=$(sqlite3 "$DB_FILE" "SELECT execution_host FROM plans WHERE id = $plan_id")

		log_error "Plan $plan_id already claimed by $current_host. Use --force to override."
		return 1
	fi

	log_info "Claimed plan $plan_id on $PLAN_DB_HOST"
	return 0
}

# ============================================================
# cmd_release <plan_id>
# ============================================================
# Release a plan claim (set execution_host to NULL)
# Only works if this host currently owns the claim
cmd_release() {
	local plan_id="$1"

	# Verify plan_id is a number
	if ! [[ "$plan_id" =~ ^[0-9]+$ ]]; then
		log_error "Invalid plan_id: $plan_id"
		return 1
	fi

	init_db

	local safe_host
	safe_host=$(sql_escape "$PLAN_DB_HOST")

	local rows_updated
	rows_updated=$(
		sqlite3 "$DB_FILE" <<-EOF
			UPDATE plans
			SET execution_host = NULL
			WHERE id = $plan_id
			  AND execution_host = '${safe_host}';
			SELECT changes();
		EOF
	)

	if [[ "$rows_updated" -eq 0 ]]; then
		local current_host
		current_host=$(sqlite3 "$DB_FILE" "SELECT execution_host FROM plans WHERE id = $plan_id")

		if [[ -n "$current_host" ]] && [[ "$current_host" != "$PLAN_DB_HOST" ]]; then
			log_error "Cannot release plan $plan_id: claimed by $current_host"
			return 1
		else
			log_warn "Plan $plan_id was not claimed"
			return 0
		fi
	fi

	log_info "Released plan $plan_id"
	return 0
}

# ============================================================
# cmd_heartbeat
# ============================================================
# Write/update heartbeat record for this host
# Records: host, timestamp, count of 'doing' plans, OS
cmd_heartbeat() {
	init_db

	# Count plans currently claimed by this host with status='doing'
	local plan_count
	plan_count=$(sqlite3 "$DB_FILE" "SELECT COUNT(*) FROM plans WHERE execution_host = '$PLAN_DB_HOST' AND status = 'doing'")

	# Get OS name
	local os_name
	os_name=$(uname -s)

	# Insert or replace heartbeat
	local safe_host
	safe_host=$(sql_escape "$PLAN_DB_HOST")
	sqlite3 "$DB_FILE" <<-EOF
		INSERT OR REPLACE INTO host_heartbeats (host, last_seen, plan_count, os)
		VALUES ('${safe_host}', datetime('now'), $plan_count, '$os_name');
	EOF

	log_info "Heartbeat recorded for $PLAN_DB_HOST (plan_count=$plan_count)"
	return 0
}

# ============================================================
# cmd_is_alive <host>
# ============================================================
# Check if a host is alive
# 1. Check heartbeat: if last_seen < 5 minutes ago -> ALIVE
# 2. If stale or no record: try SSH -> ALIVE/UNREACHABLE
# 3. If heartbeat exists but stale and SSH fails -> STALE
# Output: ALIVE|STALE|UNREACHABLE
cmd_is_alive() {
	local host="$1"

	if [[ -z "$host" ]]; then
		log_error "Usage: cmd_is_alive <host>"
		return 1
	fi

	init_db

	# Check heartbeat table
	local last_seen
	last_seen=$(sqlite3 "$DB_FILE" "SELECT last_seen FROM host_heartbeats WHERE host = '$(sql_escape "$host")'")

	if [[ -n "$last_seen" ]]; then
		# Check if heartbeat is recent (within 5 minutes)
		local age_seconds
		age_seconds=$(sqlite3 "$DB_FILE" "SELECT CAST((julianday('now') - julianday('$last_seen')) * 86400 AS INTEGER)")

		if [[ $age_seconds -lt 300 ]]; then
			# Fresh heartbeat (< 5 minutes)
			echo "ALIVE"
			return 0
		fi

		# Heartbeat is stale, try SSH
		if ssh -o ConnectTimeout="${PLAN_DB_SSH_TIMEOUT}" -o BatchMode=yes "$host" "echo ok" &>/dev/null; then
			echo "ALIVE"
			return 0
		else
			echo "STALE"
			return 0
		fi
	fi

	# No heartbeat record, try SSH directly
	if ssh -o ConnectTimeout="${PLAN_DB_SSH_TIMEOUT}" -o BatchMode=yes "$host" "echo ok" &>/dev/null; then
		echo "ALIVE"
		return 0
	else
		echo "UNREACHABLE"
		return 0
	fi
}
