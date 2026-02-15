#!/bin/bash
# Plan DB Cross-Plan Conflict Detection
# Detects file/directory overlaps between plans in the same project.
# Sourced by plan-db.sh
#
# Commands:
#   conflict-check <plan_id>                     - Check plan vs active peers
#   conflict-check-spec <project_id> <spec.json> - Check spec before import

# Extract target files from a plan's tasks in DB
# Version: 1.2.0
_extract_plan_files_db() {
	db_query "
		SELECT DISTINCT t.description || ' ' || COALESCE(t.test_criteria,'')
		FROM tasks t WHERE t.plan_id=$1
		AND t.status IN ('pending','in_progress','done');
	" | grep -oE '[a-zA-Z0-9_/.@-]+\.(ts|tsx|js|jsx|py|rs|go|sh|sql|css|scss|json|md|toml|yaml|yml|prisma|graphql)' |
		sort -u || true
}

# Extract target files from a spec.json
_extract_spec_files() {
	jq -r '.waves[].tasks[].files[]? // empty' "$1" 2>/dev/null | sort -u || true
}

# Find active plans in a project, excluding a specific plan_id
_find_active_plans() {
	db_query "
		SELECT json_group_array(json_object(
			'id', id, 'name', name, 'status', status,
			'tasks_total', tasks_total, 'tasks_done', tasks_done
		))
		FROM plans
		WHERE project_id='$1' AND status IN ('todo','doing') AND id != ${2:-0}
		ORDER BY id;
	"
}

# Build JSON array from bash array of quoted strings
_to_json_array() {
	local arr=("$@")
	if [[ ${#arr[@]} -eq 0 ]]; then
		echo "[]"
	else
		printf '[%s]' "$(
			IFS=,
			echo "${arr[*]}"
		)"
	fi
}

# Calculate overlap between two newline-separated lists
# $1=files_a, $2=files_b, $3=mode (file|dir)
_calculate_overlap() {
	local files_a="$1" files_b="$2" mode="${3:-file}"
	if [[ -z "$files_a" || -z "$files_b" ]]; then
		echo "[]" && return
	fi
	local list_a="$files_a" list_b="$files_b"
	if [[ "$mode" == "dir" ]]; then
		list_a=$(echo "$files_a" | xargs -I{} dirname {} 2>/dev/null | sort -u)
		list_b=$(echo "$files_b" | xargs -I{} dirname {} 2>/dev/null | sort -u)
	fi
	local overlaps=()
	while IFS= read -r item; do
		[[ -z "$item" || "$item" == "." ]] && continue
		if echo "$list_b" | grep -qF -- "$item"; then
			[[ "$mode" == "dir" ]] && overlaps+=("\"$item/\"") || overlaps+=("\"$item\"")
		fi
	done <<<"$list_a"
	if [[ ${#overlaps[@]} -eq 0 ]]; then echo "[]"; else _to_json_array "${overlaps[@]}"; fi
}

# Assess risk: >3 files=major, >0 files or >2 dirs=minor, else none
_assess_risk() {
	local fc="$1" dc="$2"
	if [[ $fc -gt 3 ]]; then
		echo "major"
	elif [[ $fc -gt 0 || $dc -gt 2 ]]; then
		echo "minor"
	else echo "none"; fi
}

_recommend_action() {
	case "$1" in
	major) echo "merge_or_sequence" ;; minor) echo "review_overlap" ;; *) echo "proceed" ;;
	esac
}

# Check existing plan against all active peers in same project
# Exit: 0=clean, 1=minor, 2=major
cmd_check_conflicts() {
	local plan_id="$1"
	local plan_data
	plan_data=$(db_query "
		SELECT json_object('project_id', project_id, 'name', name, 'status', status)
		FROM plans WHERE id=$plan_id;")
	[[ -z "$plan_data" ]] && echo '{"error":"plan not found"}' && return 2

	local project_id plan_name new_files
	project_id=$(echo "$plan_data" | jq -r '.project_id')
	plan_name=$(echo "$plan_data" | jq -r '.name')
	new_files=$(_extract_plan_files_db "$plan_id")

	if [[ -z "$new_files" ]]; then
		jq -n --argjson id "$plan_id" --arg name "$plan_name" \
			'{plan_id:$id,plan_name:$name,conflicts:[],overall_risk:"none",
			  recommendation:"proceed",note:"no file targets detected in tasks"}'
		return 0
	fi
	_run_conflict_analysis "$plan_id" "$plan_name" "$project_id" "$new_files"
}

# Check spec.json against all active plans before import
# Exit: 0=clean, 1=minor, 2=major
cmd_check_conflicts_spec() {
	local project_id="$1" spec_file="$2"
	[[ ! -f "$spec_file" ]] && echo '{"error":"spec file not found"}' && return 2

	local new_files
	new_files=$(_extract_spec_files "$spec_file")
	if [[ -z "$new_files" ]]; then
		jq -n --arg proj "$project_id" \
			'{project_id:$proj,conflicts:[],overall_risk:"none",
			  recommendation:"proceed",note:"no file targets in spec"}'
		return 0
	fi
	_run_conflict_analysis "0" "(new spec)" "$project_id" "$new_files"
}

# Core analysis: compare file list against all active plans
_run_conflict_analysis() {
	local plan_id="$1" plan_name="$2" project_id="$3" new_files="$4"
	local active_plans plan_count
	active_plans=$(_find_active_plans "$project_id" "$plan_id")
	plan_count=$(echo "$active_plans" | jq 'length')

	if [[ "$plan_count" == "0" || "$plan_count" == "null" ]]; then
		jq -n --argjson id "$plan_id" --arg name "$plan_name" \
			'{plan_id:$id,plan_name:$name,conflicts:[],overall_risk:"none",
			  recommendation:"proceed",note:"no other active plans in project"}'
		return 0
	fi

	local conflicts="[]" worst_risk="none"
	for ((i = 0; i < plan_count; i++)); do
		local peer_id peer_name peer_status peer_files
		peer_id=$(echo "$active_plans" | jq -r ".[$i].id")
		peer_name=$(echo "$active_plans" | jq -r ".[$i].name")
		peer_status=$(echo "$active_plans" | jq -r ".[$i].status")
		peer_files=$(_extract_plan_files_db "$peer_id")
		[[ -z "$peer_files" ]] && continue

		local file_overlap dir_overlap fc dc risk rec
		file_overlap=$(_calculate_overlap "$new_files" "$peer_files" "file")
		dir_overlap=$(_calculate_overlap "$new_files" "$peer_files" "dir")
		fc=$(echo "$file_overlap" | jq 'length')
		dc=$(echo "$dir_overlap" | jq 'length')
		[[ $fc -eq 0 && $dc -eq 0 ]] && continue

		risk=$(_assess_risk "$fc" "$dc")
		rec=$(_recommend_action "$risk")
		[[ "$risk" == "major" ]] && worst_risk="major"
		[[ "$risk" == "minor" && "$worst_risk" == "none" ]] && worst_risk="minor"

		local entry
		entry=$(jq -n \
			--argjson peer_id "$peer_id" --arg peer_name "$peer_name" \
			--arg peer_status "$peer_status" \
			--argjson overlap_files "$file_overlap" \
			--argjson overlap_dirs "$dir_overlap" \
			--arg risk "$risk" --arg recommendation "$rec" \
			'{plan_id:$peer_id,plan_name:$peer_name,status:$peer_status,
			  overlap_files:$overlap_files,overlap_dirs:$overlap_dirs,
			  risk:$risk,recommendation:$recommendation}')
		conflicts=$(echo "$conflicts" | jq --argjson c "$entry" '. + [$c]')
	done

	jq -n --argjson plan_id "$plan_id" --arg plan_name "$plan_name" \
		--argjson conflicts "$conflicts" \
		--arg risk "$worst_risk" --arg rec "$(_recommend_action "$worst_risk")" \
		'{plan_id:$plan_id,plan_name:$plan_name,conflicts:$conflicts,
		  overall_risk:$risk,recommendation:$rec}'

	case "$worst_risk" in
	none) return 0 ;; minor) return 1 ;; major) return 2 ;;
	esac
}
