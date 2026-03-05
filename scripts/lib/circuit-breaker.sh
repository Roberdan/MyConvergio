#!/bin/bash
# circuit-breaker.sh - Track consecutive Thor rejections, auto-block after threshold
# Version: 1.0.0
# Sourced by plan-db-safe.sh
#
# Requires: DB_FILE, DATA_DIR, AUDIT_LOG, REJECTION_COUNTER_DIR, MAX_REJECTIONS

circuit_breaker_track_rejection() {
	local task_db_id="$1"
	local plan_id="${2:-}"

	mkdir -p "$REJECTION_COUNTER_DIR"
	local counter_file="$REJECTION_COUNTER_DIR/task-${task_db_id}.count"

	local count=1
	if [[ -f "$counter_file" ]]; then
		count=$(cat "$counter_file")
		count=$((count + 1))
	fi
	echo "$count" >"$counter_file"

	if [[ $count -ge $MAX_REJECTIONS ]]; then
		local task_id_text
		task_id_text=$(sqlite3 "$DB_FILE" "SELECT task_id FROM tasks WHERE id = $task_db_id;" 2>/dev/null || echo "unknown")

		echo "CIRCUIT BREAKER: Task $task_id_text rejected $count times - AUTO-BLOCKING" >&2

		sqlite3 "$DB_FILE" "UPDATE tasks SET status = 'blocked', notes = 'AUTO-BLOCKED: $count consecutive Thor rejections (circuit breaker)' WHERE id = $task_db_id;"

		local timestamp
		timestamp=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
		local wave_id
		wave_id=$(sqlite3 "$DB_FILE" "SELECT wave_id FROM waves w JOIN tasks t ON t.wave_id_fk = w.id WHERE t.id = $task_db_id;" 2>/dev/null || echo "unknown")

		local audit_entry="{\"timestamp\":\"$timestamp\",\"event\":\"circuit_breaker_triggered\",\"task_db_id\":$task_db_id,\"task_id\":\"$task_id_text\",\"plan_id\":${plan_id:-null},\"wave_id\":\"$wave_id\",\"consecutive_rejections\":$count,\"max_rejections\":$MAX_REJECTIONS,\"action\":\"auto_blocked\"}"

		mkdir -p "$DATA_DIR"
		if command -v flock >/dev/null 2>&1; then
			(
				flock -x 200
				echo "$audit_entry" >>"$AUDIT_LOG"
			) 200>"$AUDIT_LOG.lock"
		else
			echo "$audit_entry" >>"$AUDIT_LOG"
		fi

		rm -f "$counter_file"
		return 1
	fi

	return 0
}

circuit_breaker_reset() {
	local task_db_id="$1"
	local counter_file="$REJECTION_COUNTER_DIR/task-${task_db_id}.count"
	rm -f "$counter_file"
}
