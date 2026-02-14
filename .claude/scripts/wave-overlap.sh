#!/bin/bash
# wave-overlap.sh - Detect file overlap between tasks in the same wave
# Prevents parallel agents from touching the same files
# Backend: SQLite (dashboard.db) tasks table
# Usage: wave-overlap.sh <command> [args]
#
# Commands:
#   check-wave <plan_id> <wave_db_id>  - Check overlap within a wave
#   check-plan <plan_id>               - Check all waves in a plan
#   check-spec <spec.json>             - Check a spec file before import
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/lib/plan-db-core.sh"

# Extract file targets from task text (description + test_criteria)
_extract_files_from_text() {
	echo "$1" | grep -oE '[a-zA-Z0-9_/.@-]+\.(ts|tsx|js|jsx|py|rs|go|sh|sql|css|scss|json|md|toml|yaml|yml|prisma|graphql)' |
		sort -u || true
}

# Get tasks with their files for a specific wave
_wave_tasks_files() {
	local plan_id="$1" wave_db_id="$2"
	db_query "
		SELECT json_group_array(json_object(
			'task_id', task_id, 'title', title, 'db_id', id,
			'text', COALESCE(description,'') || ' ' || COALESCE(test_criteria,'')
		))
		FROM tasks
		WHERE plan_id=$plan_id AND wave_id_fk=$wave_db_id
		AND status != 'skipped';
	"
}

# Find overlapping files between task pairs (bash 3.x compatible)
_find_overlaps() {
	local tasks_json="$1"
	local count
	count=$(echo "$tasks_json" | jq 'length')
	[[ "$count" -lt 2 ]] && echo '{"overlaps":[],"risk":"none"}' && return 0

	local overlaps="[]"
	local max_overlap=0
	local tmpdir
	tmpdir=$(mktemp -d)
	trap "rm -rf '$tmpdir'" RETURN

	# Build file sets per task (using temp files instead of associative arrays)
	local tids=""
	for ((i = 0; i < count; i++)); do
		local tid text files_list
		tid=$(echo "$tasks_json" | jq -r ".[$i].task_id")
		text=$(echo "$tasks_json" | jq -r ".[$i].text")
		files_list=$(_extract_files_from_text "$text")
		echo "$files_list" >"$tmpdir/$tid"
		tids="$tids $tid"
	done

	# Compare all pairs using indexed access
	local tid_arr=($tids)
	local n=${#tid_arr[@]}

	for ((i = 0; i < n; i++)); do
		for ((j = i + 1; j < n; j++)); do
			local tid_a="${tid_arr[$i]}" tid_b="${tid_arr[$j]}"
			local files_a files_b
			files_a=$(cat "$tmpdir/$tid_a")
			files_b=$(cat "$tmpdir/$tid_b")
			[[ -z "$files_a" || -z "$files_b" ]] && continue

			local shared=()
			while IFS= read -r fa; do
				[[ -z "$fa" ]] && continue
				if echo "$files_b" | grep -qF "$fa"; then
					shared+=("$fa")
				fi
			done <<<"$files_a"

			if [[ ${#shared[@]} -gt 0 ]]; then
				local shared_json
				shared_json=$(printf '%s\n' "${shared[@]}" | jq -R . | jq -s .)
				overlaps=$(echo "$overlaps" | jq \
					--arg a "$tid_a" --arg b "$tid_b" \
					--argjson files "$shared_json" \
					'. + [{"task_a":$a,"task_b":$b,"shared_files":$files}]')
				[[ ${#shared[@]} -gt $max_overlap ]] && max_overlap=${#shared[@]}
			fi
		done
	done

	local risk="none"
	[[ $max_overlap -gt 0 ]] && risk="warning"
	[[ $max_overlap -gt 2 ]] && risk="critical"

	jq -n --argjson overlaps "$overlaps" --arg risk "$risk" \
		--argjson max "$max_overlap" \
		'{"overlaps":$overlaps,"risk":$risk,"max_shared_files":$max}'
}

cmd_check_wave() {
	local plan_id="$1" wave_db_id="$2"
	local wave_info
	wave_info=$(db_query "
		SELECT json_object('wave_id', wave_id, 'name', name, 'tasks_total', tasks_total)
		FROM waves WHERE id=$wave_db_id AND plan_id=$plan_id;
	")
	[[ -z "$wave_info" ]] && echo '{"error":"wave not found"}' && return 2

	local tasks
	tasks=$(_wave_tasks_files "$plan_id" "$wave_db_id")
	local result
	result=$(_find_overlaps "$tasks")

	echo "$result" | jq --argjson w "$wave_info" '. + {wave:$w}'
	local risk
	risk=$(echo "$result" | jq -r '.risk')
	[[ "$risk" == "critical" ]] && return 2
	[[ "$risk" == "warning" ]] && return 1
	return 0
}

cmd_check_plan() {
	local plan_id="$1"
	local waves
	waves=$(db_query "
		SELECT json_group_array(json_object('db_id', id, 'wave_id', wave_id, 'name', name))
		FROM waves WHERE plan_id=$plan_id ORDER BY position;
	")
	local wave_count
	wave_count=$(echo "$waves" | jq 'length')

	local results="[]" worst_risk="none"

	for ((i = 0; i < wave_count; i++)); do
		local wid wname wave_db_id
		wid=$(echo "$waves" | jq -r ".[$i].wave_id")
		wname=$(echo "$waves" | jq -r ".[$i].name")
		wave_db_id=$(echo "$waves" | jq -r ".[$i].db_id")

		local result
		result=$(cmd_check_wave "$plan_id" "$wave_db_id" 2>/dev/null) || true
		local risk
		risk=$(echo "$result" | jq -r '.risk')

		# Only include waves with issues
		if [[ "$risk" != "none" ]]; then
			results=$(echo "$results" | jq --argjson r "$result" '. + [$r]')
			[[ "$risk" == "critical" ]] && worst_risk="critical"
			[[ "$risk" == "warning" && "$worst_risk" == "none" ]] && worst_risk="warning"
		fi
	done

	jq -n --argjson plan_id "$plan_id" --argjson waves "$results" \
		--arg risk "$worst_risk" --argjson total "$wave_count" \
		'{plan_id:$plan_id,waves_checked:$total,waves_with_overlap:$waves,
		  overall_risk:$risk}'
}

cmd_check_spec() {
	local spec_file="$1"
	[[ ! -f "$spec_file" ]] && echo '{"error":"spec file not found"}' && return 2

	local waves
	waves=$(jq -c '.waves // []' "$spec_file")
	local wave_count
	wave_count=$(echo "$waves" | jq 'length')
	local results="[]" worst_risk="none"

	for ((i = 0; i < wave_count; i++)); do
		local wid tasks
		wid=$(echo "$waves" | jq -r ".[$i].id")
		tasks=$(echo "$waves" | jq -c ".[$i].tasks // []")
		local task_count
		task_count=$(echo "$tasks" | jq 'length')
		[[ "$task_count" -lt 2 ]] && continue

		# Build tasks_json compatible with _find_overlaps
		local tasks_json="[]"
		for ((t = 0; t < task_count; t++)); do
			local tid files_arr text
			tid=$(echo "$tasks" | jq -r ".[$t].id")
			files_arr=$(echo "$tasks" | jq -r ".[$t].files[]? // empty" 2>/dev/null | tr '\n' ' ')
			text="$files_arr $(echo "$tasks" | jq -r ".[$t].do // empty")"
			tasks_json=$(echo "$tasks_json" | jq \
				--arg id "$tid" --arg text "$text" \
				'. + [{"task_id":$id,"text":$text}]')
		done

		local result
		result=$(_find_overlaps "$tasks_json")
		local risk
		risk=$(echo "$result" | jq -r '.risk')

		if [[ "$risk" != "none" ]]; then
			result=$(echo "$result" | jq --arg w "$wid" '. + {wave_id:$w}')
			results=$(echo "$results" | jq --argjson r "$result" '. + [$r]')
			[[ "$risk" == "critical" ]] && worst_risk="critical"
			[[ "$risk" == "warning" && "$worst_risk" == "none" ]] && worst_risk="warning"
		fi
	done

	jq -n --arg spec "$spec_file" --argjson waves "$results" \
		--arg risk "$worst_risk" --argjson total "$wave_count" \
		'{spec:$spec,waves_checked:$total,waves_with_overlap:$waves,
		  overall_risk:$risk}'
}

# Dispatch
case "${1:-help}" in
check-wave) cmd_check_wave "${2:?plan_id required}" "${3:?wave_db_id required}" ;;
check-plan) cmd_check_plan "${2:?plan_id required}" ;;
check-spec) cmd_check_spec "${2:?spec_file required}" ;;
*)
	echo "Usage: wave-overlap.sh <command> [args]"
	echo "  check-wave <plan_id> <wave_db_id>  - Overlap within a wave"
	echo "  check-plan <plan_id>               - Check all waves"
	echo "  check-spec <spec.json>             - Check before import"
	;;
esac
