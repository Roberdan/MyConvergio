#!/bin/bash
# Token Tracking Hook - Optimized with async writes
# Records token usage to the dashboard database
# Version: 1.1.0
#
# Usage:
#   track-tokens.sh <project_id> <agent> <model> <input_tokens> <output_tokens>
#   OR via environment variables
#   OR via JSON stdin
set -uo pipefail

source ~/.claude/hooks/lib/common.sh 2>/dev/null || true

# Escape single quotes for safe SQL interpolation
sql_escape() { printf '%s' "$1" | sed "s/'/''/g"; }

DB_FILE="$HOME/.claude/data/dashboard.db"

# Cleanup background processes on exit
trap 'wait 2>/dev/null' EXIT

# Async SQLite write (non-blocking)
record_sqlite_async() {
	local project_id="$1" plan_id="${2:-NULL}" wave_id="${3:-}" task_id="${4:-}"
	local agent="$5" model="$6" input_tokens="$7" output_tokens="$8" cost_usd="${9:-0}"

	[[ ! -f "$DB_FILE" ]] && return 1

	# Background write - doesn't block hook
	{
		local exec_host="${HOSTNAME:-$(hostname -s 2>/dev/null || hostname)}"
		exec_host="${exec_host%.local}"
		local safe_project_id safe_wave_id safe_task_id safe_agent safe_model safe_exec_host
		safe_project_id=$(sql_escape "$project_id")
		safe_wave_id=$(sql_escape "$wave_id")
		safe_task_id=$(sql_escape "$task_id")
		safe_agent=$(sql_escape "$agent")
		safe_model=$(sql_escape "$model")
		safe_exec_host=$(sql_escape "$exec_host")
		sqlite3 "$DB_FILE" "
      INSERT INTO token_usage (project_id, plan_id, wave_id, task_id, agent, model, input_tokens, output_tokens, cost_usd, execution_host)
      VALUES ('$safe_project_id', $plan_id, '$safe_wave_id', '$safe_task_id', '$safe_agent', '$safe_model', $input_tokens, $output_tokens, $cost_usd, '$safe_exec_host');
    " 2>/dev/null
	} &

	echo "Recorded: $input_tokens + $output_tokens tokens ($agent)"
}

# Async DB write (fallback when direct DB insert is not available)
record_api_async() {
	local json="$1"
	local db="$HOME/.claude/data/dashboard.db"
	{ sqlite3 "$db" ".timeout 3000" "INSERT INTO token_usage (project_id, agent, model, input_tokens, output_tokens, cost_usd, created_at) SELECT json_extract('$json','$.project_id'), json_extract('$json','$.agent'), json_extract('$json','$.model'), json_extract('$json','$.input_tokens'), json_extract('$json','$.output_tokens'), json_extract('$json','$.cost_usd'), datetime('now');" 2>/dev/null; } &
	echo "Recorded tokens via DB"
}

# Parse hook event types (TeammateIdle, TaskCompleted)
if [[ "${1:-}" == "teammate-idle" ]] || [[ "${1:-}" == "task-completed" ]]; then
	event_type="$1"
	if [[ ! -t 0 ]]; then
		json=$(cat)
		agent_name=$(echo "$json" | jq -r '.agent_name // .teammate_name // "unknown"' 2>/dev/null)
		project_id=$(echo "$json" | jq -r '.project // "unknown"' 2>/dev/null)
		if [[ -f "$DB_FILE" ]]; then
			{
				exec_host="${HOSTNAME:-$(hostname -s 2>/dev/null || hostname)}"
				exec_host="${exec_host%.local}"
				safe_project_id=$(sql_escape "$project_id")
				safe_agent_name=$(sql_escape "$agent_name")
				safe_event_type=$(sql_escape "$event_type")
				safe_exec_host=$(sql_escape "$exec_host")
				sqlite3 "$DB_FILE" "
				INSERT INTO token_usage (project_id, agent, model, input_tokens, output_tokens, cost_usd, execution_host)
				VALUES ('$safe_project_id', '${safe_agent_name}:${safe_event_type}', 'team-event', 0, 0, 0, '$safe_exec_host');
				" 2>/dev/null
			} &
		fi
	fi
# Parse positional args
elif [[ $# -ge 5 ]]; then
	record_sqlite_async "$1" "NULL" "" "" "$2" "$3" "$4" "$5" "${6:-0}"
elif [[ -n "${PROJECT_ID:-}" ]] && [[ -n "${AGENT:-}" ]] && [[ -n "${MODEL:-}" ]]; then
	record_sqlite_async "$PROJECT_ID" "${PLAN_ID:-NULL}" "${WAVE_ID:-}" "${TASK_ID:-}" \
		"$AGENT" "$MODEL" "${INPUT_TOKENS:-0}" "${OUTPUT_TOKENS:-0}" "${COST_USD:-0}"
elif [[ ! -t 0 ]]; then
	json=$(cat)
	[[ -n "$json" ]] && record_api_async "$json"
fi

exit 0
