#!/usr/bin/env bash
# mesh-scoring.sh — Peer scoring functions for mesh-dispatcher.sh (sourced library)
# Version: 1.0.0
# Usage: source scripts/lib/mesh-scoring.sh
# Guards against direct execution.
# F-13 (floating coordinator), F-15 (cost routing), F-16/F-17 (privacy)

[[ "${BASH_SOURCE[0]}" == "${0}" ]] && {
	echo "ERROR: mesh-scoring.sh must be sourced, not executed." >&2
	exit 1
}

MESH_MAX_TASKS_PER_PEER="${MESH_MAX_TASKS_PER_PEER:-3}"

# _json_field — extract scalar field from flat JSON object (bash 3.2 compat)
# Usage: _json_field <json> <field>
_json_field() {
	local json="$1" field="$2" val
	# Try quoted string value first
	val="$(echo "$json" | sed -n "s/.*\"${field}\":[[:space:]]*\"\([^\"]*\)\".*/\1/p" | head -1)"
	if [[ -n "$val" ]]; then
		echo "$val"
		return 0
	fi
	# Try unquoted (numbers, booleans, null)
	val="$(echo "$json" | sed -n "s/.*\"${field}\":[[:space:]]*\([^,}]*\).*/\1/p" | head -1)"
	echo "${val%[[:space:]]}"
}

# mesh_score_peer — score a peer JSON object against a task
# Usage: mesh_score_peer <peer_json> <required_capability> <privacy_required:0|1>
# Output: integer score (negative = disqualified), or prints DISQUALIFIED
# Returns exit code 1 when disqualified.
mesh_score_peer() {
	local peer_json="$1"
	local required_cap="${2:-}"
	local privacy_required="${3:-0}"

	local online cost_tier privacy_safe cpu_load tasks_in_progress capabilities
	online="$(_json_field "$peer_json" "online")"
	cost_tier="$(_json_field "$peer_json" "cost_tier")"
	privacy_safe="$(_json_field "$peer_json" "privacy_safe")"
	cpu_load="$(_json_field "$peer_json" "cpu_load")"
	tasks_in_progress="$(_json_field "$peer_json" "tasks_in_progress")"
	capabilities="$(_json_field "$peer_json" "capabilities")"

	# Offline peers are disqualified
	[[ "$online" != "true" ]] && echo "-99" && return 1

	# Null load = offline-equivalent; disqualify
	[[ "$cpu_load" == "null" || -z "$cpu_load" ]] && echo "-99" && return 1

	# Privacy: if task requires privacy and peer is not safe → DISQUALIFIED
	if [[ "$privacy_required" == "1" || "$privacy_required" == "true" ]]; then
		if [[ "$privacy_safe" != "true" ]]; then
			echo "-99"
			return 1
		fi
	fi

	local score=0

	# Capability check: +3 if peer has required capability
	if [[ -n "$required_cap" ]]; then
		case ",$capabilities," in
		*",${required_cap},"*) score=$((score + 3)) ;;
		esac
	fi

	# Cost tier scoring (F-15)
	case "$cost_tier" in
	free) score=$((score + 2)) ;;
	zero) score=$((score + 1)) ;;
	premium) score=$((score + 0)) ;;
	*) score=$((score + 0)) ;;
	esac

	# Privacy safety bonus: privacy_required=true AND privacy_safe=true → +3
	if [[ "$privacy_required" == "1" || "$privacy_required" == "true" ]]; then
		[[ "$privacy_safe" == "true" ]] && score=$((score + 3))
	fi

	# Load scoring: cpu_load normalized to 0-2 points (lower load = more points)
	# Use integer arithmetic: strip decimal, compare thresholds
	local cpu_int=0
	cpu_int="$(echo "$cpu_load" | sed 's/\..*//' 2>/dev/null || echo 0)"
	cpu_int="${cpu_int:-0}"
	if [[ "$cpu_int" -le 0 ]]; then
		score=$((score + 2))
	elif [[ "$cpu_int" -le 1 ]]; then
		score=$((score + 1))
	fi
	# cpu >= 2: +0

	# Capacity: if tasks_in_progress < MESH_MAX_TASKS_PER_PEER → +1
	local tip=0
	tip="${tasks_in_progress:-0}"
	[[ "$tip" =~ ^[0-9]+$ ]] || tip=0
	if [[ "$tip" -lt "$MESH_MAX_TASKS_PER_PEER" ]]; then
		score=$((score + 1))
	fi

	echo "$score"
	return 0
}

# mesh_best_peer — pick highest-scoring peer from JSON array for a task
# Usage: mesh_best_peer <peers_json_array> <required_capability> <privacy_required>
# Output: peer name of winner, or empty string if none qualify
mesh_best_peer() {
	local peers_json="$1"
	local required_cap="${2:-}"
	local privacy_required="${3:-0}"

	local best_peer="" best_score=-100
	local peer_line score peer_name

	# Parse JSON array line-by-line (one JSON object per entry)
	while IFS= read -r peer_line; do
		[[ -z "$peer_line" || "$peer_line" == "[" || "$peer_line" == "]" || "$peer_line" == "," ]] && continue
		peer_line="${peer_line%,}" # strip trailing comma

		score="$(mesh_score_peer "$peer_line" "$required_cap" "$privacy_required" 2>/dev/null || echo -99)"
		[[ "$score" =~ ^-?[0-9]+$ ]] || continue
		[[ "$score" -lt 0 ]] && continue

		if [[ "$score" -gt "$best_score" ]]; then
			best_score="$score"
			best_peer="$(_json_field "$peer_line" "peer")"
		fi
	done <<<"$peers_json"

	echo "$best_peer"
}
