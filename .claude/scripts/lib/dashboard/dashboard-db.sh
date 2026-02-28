#!/bin/bash
# Dashboard database operations and utility functions
# Version: 2.0.0

# Concurrency-safe sqlite3 wrapper: busy_timeout=5000ms, retries on lock
dbq() {
	sqlite3 "$DB" ".timeout 5000" "$@" 2>/dev/null || {
		sleep 1
		sqlite3 "$DB" ".timeout 5000" "$@" 2>/dev/null || echo ""
	}
}

# Snapshot: single DB connection, all queries, results in global vars
# Call once per render cycle. Modules read from DB_SNAP_* vars instead of querying.
DB_SNAP_DIR=""

db_snapshot() {
	DB_SNAP_DIR=$(mktemp -d "${TMPDIR:-/tmp}/dashboard-snap.XXXXXX")
	sqlite3 "$DB" ".timeout 5000" ".mode list" ".separator |" "
		-- Overview counts
		SELECT 'OVERVIEW',
			(SELECT COUNT(*) FROM plans WHERE status='done'),
			(SELECT COUNT(*) FROM plans WHERE status='doing'),
			(SELECT COUNT(*) FROM plans WHERE status='todo'),
			(SELECT COUNT(*) FROM plans),
			(SELECT COUNT(*) FROM tasks t JOIN waves w ON t.wave_id_fk=w.id JOIN plans p ON w.plan_id=p.id WHERE p.status='doing' AND t.status='done'),
			(SELECT COUNT(*) FROM tasks t JOIN waves w ON t.wave_id_fk=w.id JOIN plans p ON w.plan_id=p.id WHERE p.status='doing' AND t.status='in_progress'),
			(SELECT COUNT(*) FROM tasks t JOIN waves w ON t.wave_id_fk=w.id JOIN plans p ON w.plan_id=p.id WHERE p.status='doing');

		-- Active plans
		SELECT 'ACTIVE_PLAN',
			p.id, p.name, p.status, p.updated_at, p.started_at, p.created_at, p.project_id,
			(SELECT COUNT(*) FROM waves WHERE plan_id=p.id),
			(SELECT COUNT(*) FROM waves WHERE plan_id=p.id AND tasks_done=tasks_total AND tasks_total>0),
			(SELECT COUNT(*) FROM tasks WHERE wave_id_fk IN (SELECT id FROM waves WHERE plan_id=p.id)),
			(SELECT COUNT(*) FROM tasks WHERE status='done' AND wave_id_fk IN (SELECT id FROM waves WHERE plan_id=p.id)),
			COALESCE(p.worktree_path, ''),
			COALESCE(p.parallel_mode, ''),
			COALESCE((SELECT host FROM plans WHERE id=p.id), ''),
			REPLACE(REPLACE(COALESCE(p.human_summary, COALESCE(p.description, '')), char(10), ' '), char(13), ''),
			COALESCE(p.branch_name, 'main'),
			COALESCE((SELECT SUM(total_tokens) FROM token_usage WHERE project_id=p.project_id), 0)
		FROM plans p WHERE p.status='doing' ORDER BY p.started_at DESC;

		-- Pipeline plans
		SELECT 'PIPELINE_PLAN',
			p.id, p.name, p.created_at, p.project_id,
			REPLACE(REPLACE(COALESCE(p.human_summary, COALESCE(p.description, '')), char(10), ' '), char(13), '')
		FROM plans p WHERE p.status='todo' ORDER BY p.created_at DESC;

		-- Completed count + last 24h
		SELECT 'COMPLETED_STATS',
			(SELECT COUNT(*) FROM plans WHERE status='done'),
			(SELECT COUNT(*) FROM plans WHERE status='done' AND datetime(COALESCE(completed_at, updated_at, created_at)) >= datetime('now', '-1 day'));
	" >"$DB_SNAP_DIR/snapshot.txt" 2>/dev/null || true
}

# Read snapshot lines by prefix
db_snap_get() {
	local prefix="$1"
	[[ -n "$DB_SNAP_DIR" && -f "$DB_SNAP_DIR/snapshot.txt" ]] && grep "^${prefix}|" "$DB_SNAP_DIR/snapshot.txt" | sed "s/^${prefix}|//" || echo ""
}

db_snap_cleanup() {
	[[ -n "$DB_SNAP_DIR" && -d "$DB_SNAP_DIR" ]] && rm -rf "$DB_SNAP_DIR" 2>/dev/null || true
}

# Cross-platform date to epoch (Mac uses -j, Linux uses -d)
date_to_epoch() {
	local dt="$1"
	if [[ "$(uname)" == "Darwin" ]]; then
		date -j -f "%Y-%m-%d %H:%M:%S" "$dt" +%s 2>/dev/null || echo 0
	else
		date -d "$dt" +%s 2>/dev/null || echo 0
	fi
}

# Cross-platform date-only to epoch
date_only_to_epoch() {
	local dt="$1"
	if [[ "$(uname)" == "Darwin" ]]; then
		date -j -f "%Y-%m-%d" "$dt" +%s 2>/dev/null || echo 0
	else
		date -d "$dt" +%s 2>/dev/null || echo 0
	fi
}

# Function to format elapsed time
format_elapsed() {
	local seconds=${1:-0}
	if [ "$seconds" -lt 60 ]; then
		echo "${seconds}s"
	elif [ "$seconds" -lt 3600 ]; then
		local mins=$((seconds / 60))
		echo "${mins}m"
	elif [ "$seconds" -lt 86400 ]; then
		local hours=$((seconds / 3600))
		local mins=$(((seconds % 3600) / 60))
		echo "${hours}h ${mins}m"
	else
		local days=$((seconds / 86400))
		local hours=$(((seconds % 86400) / 3600))
		echo "${days}d ${hours}h"
	fi
}

# Function to format tokens (K for thousands, M for millions)
format_tokens() {
	local tokens=${1:-0}
	if [ "$tokens" -lt 1000 ]; then
		echo "${tokens}"
	elif [ "$tokens" -lt 1000000 ]; then
		local k=$((tokens / 1000))
		echo "${k}K"
	else
		local m=$((tokens / 1000000))
		echo "${m}M"
	fi
}

# Convert agentic description to human-readable summary
truncate_desc() {
	local desc="${1:-}"
	[ -z "$desc" ] && return
	# Strip agentic patterns: Worktree paths, workflow blocks, agent instructions
	desc=$(echo "$desc" | sed -E \
		-e 's/Worktree: [^ ]+ \([^)]*\)\.?//' \
		-e 's/Worktree: [^ ]+\.?//' \
		-e 's/ *(WORKFLOW|IMPORTANT|NOTE|CONSTRAINT|EXECUTION|AGENT|WARNING|CONTEXT|BRANCH|PLAN_ID|STATUS):.*$//' \
		-e 's#/Users/[^ ]+##g' \
		-e 's/\(branch [^)]*\)//g' \
		-e 's/plan\/[0-9]+-[^ ]*//g')
	# Humanize: underscores to spaces, collapse spaces, trim edges
	desc=$(echo "$desc" | sed -E \
		-e 's/_/ /g' \
		-e 's/  +/ /g' \
		-e 's/^[ .]+//' \
		-e 's/[ .]+$//')
	# Skip if empty or too short after cleanup
	[ ${#desc} -lt 5 ] && return
	# Truncate to 120 chars
	if [ ${#desc} -gt 120 ]; then
		echo "${desc:0:117}..."
	else
		echo "$desc"
	fi
}

# Format line count (K for thousands)
format_lines() {
	local lines=${1:-0}
	if [ "$lines" -lt 1000 ]; then
		echo "$lines"
	elif [ "$lines" -lt 10000 ]; then
		local whole=$((lines / 1000))
		local frac=$(((lines % 1000) / 100))
		echo "${whole}.${frac}K"
	else
		echo "$((lines / 1000))K"
	fi
}

# Weighted progress using effort_level (1/2/3) and Thor validation gate.
# A task counts as "done" ONLY if validated by Thor (validated_at IS NOT NULL).
# Returns "done_weight|total_weight"
calc_weighted_progress() {
	local plan_filter="$1" # SQL WHERE clause fragment for wave selection
	dbq "
		SELECT
			COALESCE(SUM(CASE WHEN t.status='done' AND t.validated_at IS NOT NULL
				THEN COALESCE(t.effort_level, 1) ELSE 0 END), 0),
			COALESCE(SUM(COALESCE(t.effort_level, 1)), 0)
		FROM tasks t
		WHERE t.status NOT IN ('cancelled', 'skipped')
		AND t.wave_id_fk IN (SELECT id FROM waves WHERE $plan_filter AND status != 'cancelled')
	"
}

# Render a progress bar from percentage
# Usage: render_bar <percentage> <bar_length>
render_bar() {
	local pct="$1" blen="${2:-20}"
	local filled=$((pct * blen / 100))
	local empty=$((blen - filled))
	local bar="${GREEN}"
	for ((i = 0; i < filled; i++)); do bar+="█"; done
	bar+="${GRAY}"
	for ((i = 0; i < empty; i++)); do bar+="░"; done
	bar+="${NC}"
	echo -e "$bar"
}
