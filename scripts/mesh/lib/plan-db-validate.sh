#!/bin/bash
# Plan DB Validation facade + shared helpers
# Sourced by plan-db.sh

# shellcheck source=lib/validate-task.sh
# shellcheck source=lib/validate-wave.sh
# shellcheck source=lib/validate-plan.sh
# shellcheck source=lib/validate-fxx.sh
PLAN_DB_VALIDATE_LIB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${PLAN_DB_VALIDATE_LIB_DIR}/validate-task.sh"
source "${PLAN_DB_VALIDATE_LIB_DIR}/validate-wave.sh"
source "${PLAN_DB_VALIDATE_LIB_DIR}/validate-plan.sh"
source "${PLAN_DB_VALIDATE_LIB_DIR}/validate-fxx.sh"

# Detect cycles in wave dependency graph (DFS 3-color)
# Usage: detect_precondition_cycles <plan_id>
# Returns 0 if no cycles, 1 if cycle found (prints path to stderr)
detect_precondition_cycles() {
	local plan_id="$1"

	# Query all waves for this plan
	local wave_data
	wave_data=$(sqlite3 "$DB_FILE" \
		"SELECT wave_id, COALESCE(depends_on,''), COALESCE(precondition,'') FROM waves WHERE plan_id = $plan_id ORDER BY position;" \
		2>/dev/null) || true

	# Nothing to check
	[[ -z "$wave_data" ]] && return 0

	# Build adjacency list using temp files (portable across
	# bash versions; avoids associative array edge cases)
	local tmpdir
	tmpdir=$(mktemp -d -t cycle-detect)
	trap "rm -rf '$tmpdir'" EXIT INT TERM

	# Collect all wave_ids
	local -a all_waves=()
	while IFS='|' read -r wid depends_on precondition; do
		all_waves+=("$wid")
		local adj_file="$tmpdir/adj_${wid}"
		touch "$adj_file"

		# Source 1: depends_on field (comma-separated wave_ids)
		if [[ -n "$depends_on" ]]; then
			local dep
			for dep in $(echo "$depends_on" | tr ',' ' '); do
				dep=$(echo "$dep" | xargs) # trim whitespace
				[[ -n "$dep" ]] && echo "$dep" >>"$adj_file"
			done
		fi

		# Source 2: precondition JSON - extract wave_id refs
		if [[ -n "$precondition" && "$precondition" != "null" ]]; then
			local json_deps
			json_deps=$(echo "$precondition" |
				jq -r '.[].wave_id // empty' 2>/dev/null) || true
			if [[ -n "$json_deps" ]]; then
				echo "$json_deps" >>"$adj_file"
			fi
		fi

		# Deduplicate adjacency entries
		if [[ -s "$adj_file" ]]; then
			sort -u "$adj_file" -o "$adj_file"
		fi
	done <<<"$wave_data"

	# DFS 3-color: white=0, gray=1, black=2
	for wid in "${all_waves[@]}"; do
		echo "0" >"$tmpdir/color_${wid}"
	done

	echo "0" >"$tmpdir/result"

	# Recursive DFS visit
	_dfs_visit() {
		local node="$1"
		local color_file="$tmpdir/color_${node}"

		# Skip if wave_id is referenced but not in this plan
		[[ ! -f "$color_file" ]] && return 0

		local color
		color=$(<"$color_file")

		# Already fully processed
		[[ "$color" == "2" ]] && return 0

		# Gray = back edge = cycle
		if [[ "$color" == "1" ]]; then
			local cycle_path=""
			if [[ -f "$tmpdir/path" ]]; then
				local in_cycle=0
				while IFS= read -r p; do
					if [[ "$p" == "$node" ]]; then
						in_cycle=1
					fi
					if [[ $in_cycle -eq 1 ]]; then
						[[ -n "$cycle_path" ]] && cycle_path="${cycle_path} -> "
						cycle_path="${cycle_path}${p}"
					fi
				done <"$tmpdir/path"
				cycle_path="${cycle_path} -> ${node}"
			else
				cycle_path="${node} -> ${node}"
			fi
			echo "CYCLE DETECTED: $cycle_path" >&2
			echo "1" >"$tmpdir/result"
			return 1
		fi

		# Mark gray (in progress)
		echo "1" >"$color_file"
		echo "$node" >>"$tmpdir/path"

		# Visit all neighbors
		local adj_file="$tmpdir/adj_${node}"
		if [[ -f "$adj_file" && -s "$adj_file" ]]; then
			while IFS= read -r neighbor; do
				[[ -z "$neighbor" ]] && continue
				if ! _dfs_visit "$neighbor"; then
					return 1
				fi
			done <"$adj_file"
		fi

		# Mark black (done)
		echo "2" >"$color_file"

		# Remove node from path stack
		if [[ -f "$tmpdir/path" ]]; then
			local new_path
			new_path=$(grep -v "^${node}$" "$tmpdir/path" 2>/dev/null) || true
			echo "$new_path" >"$tmpdir/path"
		fi

		return 0
	}

	# Run DFS from each unvisited node
	for wid in "${all_waves[@]}"; do
		local color
		color=$(<"$tmpdir/color_${wid}")
		if [[ "$color" == "0" ]]; then
			>"$tmpdir/path"
			if ! _dfs_visit "$wid"; then
				return 1
			fi
		fi
	done

	return 0
}
