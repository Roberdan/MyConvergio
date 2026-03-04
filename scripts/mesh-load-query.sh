#!/usr/bin/env bash
# mesh-load-query.sh — Query CPU load and task state across online mesh peers
# Version: 1.0.0
# Usage: mesh-load-query.sh [--json] [--peer NAME]
# Output: JSON array [{peer, cpu_load, tasks_in_progress, capabilities, cost_tier, privacy_safe, online}]
# Writes results to peer_heartbeats table (last_seen + load_json).
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CLAUDE_HOME="${CLAUDE_HOME:-$HOME/.claude}"
DB_PATH="${DB_PATH:-$CLAUDE_HOME/data/dashboard.db}"
ORCHESTRATOR_YAML="${ORCHESTRATOR_YAML:-$CLAUDE_HOME/config/orchestrator.yaml}"

source "$SCRIPT_DIR/lib/peers.sh"

JSON_OUTPUT=false
PEER_FILTER=""

while [[ $# -gt 0 ]]; do
	case "$1" in
	--json)
		JSON_OUTPUT=true
		shift
		;;
	--peer)
		PEER_FILTER="${2:-}"
		shift 2
		;;
	-h | --help)
		echo "Usage: $(basename "$0") [--json] [--peer NAME]"
		echo "  --json      Output JSON array"
		echo "  --peer NAME Query a single peer only"
		exit 0
		;;
	*)
		echo "Unknown option: $1" >&2
		exit 1
		;;
	esac
done

# COST_TIER_PAIRS: space-separated "cap=tier" tokens (bash 3.2 compatible, no declare -A)
COST_TIER_PAIRS=""

_parse_cost_tiers() {
	[[ ! -f "$ORCHESTRATOR_YAML" ]] && return 0
	local in_mesh=false in_tiers=false line
	while IFS= read -r line; do
		[[ "$line" =~ ^[[:space:]]*# ]] && continue
		if [[ "$line" =~ ^mesh: ]]; then
			in_mesh=true
			continue
		fi
		if $in_mesh && [[ "$line" =~ ^[[:space:]]+cost_tiers: ]]; then
			in_tiers=true
			continue
		fi
		if $in_tiers; then
			# Stop when we hit a top-level (non-indented) key
			if [[ "$line" =~ ^[a-z] ]]; then
				in_mesh=false
				in_tiers=false
				break
			fi
			if [[ "$line" =~ ^[[:space:]]+([a-z_]+):[[:space:]]*([a-z]+) ]]; then
				COST_TIER_PAIRS="${COST_TIER_PAIRS} ${BASH_REMATCH[1]}=${BASH_REMATCH[2]}"
			fi
		fi
	done <"$ORCHESTRATOR_YAML"
}

_tier_for_cap() {
	local cap="$1" pair key
	for pair in $COST_TIER_PAIRS; do
		key="${pair%%=*}"
		[[ "$key" == "$cap" ]] && echo "${pair#*=}" && return 0
	done
	echo "free"
}

_cost_tier_for_caps() {
	local caps="$1" tier="free" cap t
	IFS=',' read -ra cap_arr <<<"$caps"
	for cap in "${cap_arr[@]}"; do
		cap="${cap// /}"
		t="$(_tier_for_cap "$cap")"
		if [[ "$t" == "premium" ]]; then
			tier="premium"
			break
		fi
		[[ "$t" == "zero" && "$tier" != "premium" ]] && tier="zero"
	done
	echo "$tier"
}

_privacy_safe_for_caps() {
	local caps="$1" safe=true cap
	IFS=',' read -ra cap_arr <<<"$caps"
	for cap in "${cap_arr[@]}"; do
		cap="${cap// /}"
		case "$cap" in
		claude | copilot | gemini)
			safe=false
			break
			;;
		esac
	done
	echo "$safe"
}

# Remote script: collects CPU load + tasks_in_progress (piped via SSH stdin)
_remote_cmd() {
	cat <<'REMOTE'
set +e
# uptime: macOS -> "load averages: X Y Z" | Linux -> "load average: X, Y, Z"
cpu=$(uptime 2>/dev/null | sed -E 's/.*load averages?: *([0-9]+\.[0-9]+).*/\1/')
db="$HOME/.claude/data/dashboard.db"
tasks=0
if [ -f "$db" ] && command -v sqlite3 >/dev/null 2>&1; then
  tasks=$(sqlite3 "$db" "SELECT COUNT(*) FROM tasks WHERE status='in_progress';" 2>/dev/null || echo 0)
fi
printf '%s %s\n' "${cpu:-0}" "${tasks:-0}"
REMOTE
}

_upsert_heartbeat() {
	local peer_name="$1" caps="$2" load_json="$3"
	[[ ! -f "$DB_PATH" ]] && return 0
	local now
	now="$(date +%s)"
	sqlite3 "$DB_PATH" \
		"INSERT INTO peer_heartbeats (peer_name, last_seen, load_json, capabilities, updated_at)
		 VALUES ('$peer_name', $now, '$load_json', '$caps', datetime('now'))
		 ON CONFLICT(peer_name) DO UPDATE SET
		   last_seen=excluded.last_seen, load_json=excluded.load_json,
		   capabilities=excluded.capabilities, updated_at=excluded.updated_at;" 2>/dev/null || true
}

_write_offline() {
	local name="$1" caps="$2" cost_tier="$3" privacy_safe="$4" result_file="$5"
	printf '{"peer":"%s","cpu_load":null,"tasks_in_progress":null,"capabilities":"%s","cost_tier":"%s","privacy_safe":%s,"online":false}\n' \
		"$name" "$caps" "$cost_tier" "$privacy_safe" >"$result_file"
	_upsert_heartbeat "$name" "$caps" "null"
}

_query_peer() {
	local name="$1" result_file="$2"
	local caps cost_tier privacy_safe
	caps="$(peers_get "$name" "capabilities" 2>/dev/null || echo "")"
	cost_tier="$(_cost_tier_for_caps "$caps")"
	privacy_safe="$(_privacy_safe_for_caps "$caps")"

	local target user dest
	target="$(peers_best_route "$name" 2>/dev/null)" || {
		_write_offline "$name" "$caps" "$cost_tier" "$privacy_safe" "$result_file"
		return
	}
	user="$(peers_get "$name" "user" 2>/dev/null || echo "")"
	dest="${user:+${user}@}${target}"

	local raw
	if ! raw="$(ssh -o ConnectTimeout=5 -o StrictHostKeyChecking=accept-new \
		-o BatchMode=yes -o LogLevel=quiet \
		"$dest" "bash -s" <<<"$(_remote_cmd)" 2>/dev/null)"; then
		_write_offline "$name" "$caps" "$cost_tier" "$privacy_safe" "$result_file"
		return
	fi

	local cpu tasks
	cpu="$(echo "$raw" | awk '{print $1}')"
	tasks="$(echo "$raw" | awk '{print $2}')"
	cpu="${cpu:-0}"
	tasks="${tasks:-0}"

	printf '{"peer":"%s","cpu_load":%s,"tasks_in_progress":%s,"capabilities":"%s","cost_tier":"%s","privacy_safe":%s,"online":true}\n' \
		"$name" "$cpu" "$tasks" "$caps" "$cost_tier" "$privacy_safe" >"$result_file"
	_upsert_heartbeat "$name" "$caps" \
		"{\"cpu_load\":$cpu,\"tasks_in_progress\":$tasks,\"cost_tier\":\"$cost_tier\",\"privacy_safe\":$privacy_safe}"
}

main() {
	_parse_cost_tiers
	peers_load || {
		echo "ERROR: cannot load peers" >&2
		exit 1
	}

	local peer_names=()
	if [[ -n "$PEER_FILTER" ]]; then
		peer_names=("$PEER_FILTER")
	else
		while IFS= read -r p; do peer_names+=("$p"); done < <(peers_list)
	fi

	if [[ ${#peer_names[@]} -eq 0 ]]; then
		[[ "$JSON_OUTPUT" == true ]] && echo "[]" || echo "No active peers found."
		exit 0
	fi

	_TMP_DIR="$(mktemp -d)"
	trap 'rm -rf "${_TMP_DIR:-}"' EXIT

	# Launch parallel SSH queries (background)
	local pids=()
	for peer in "${peer_names[@]}"; do
		_query_peer "$peer" "$_TMP_DIR/${peer}.json" &
		pids+=($!)
	done
	for pid in "${pids[@]}"; do wait "$pid" 2>/dev/null || true; done

	if [[ "$JSON_OUTPUT" == true ]]; then
		local first=true
		echo "["
		for peer in "${peer_names[@]}"; do
			[[ ! -f "$_TMP_DIR/${peer}.json" ]] && continue
			$first || echo ","
			cat "$_TMP_DIR/${peer}.json"
			first=false
		done
		echo "]"
	else
		printf "%-20s %-8s %-12s %-22s %-10s %s\n" \
			"PEER" "ONLINE" "CPU_LOAD" "TASKS_IN_PROGRESS" "COST_TIER" "PRIVACY_SAFE"
		printf '%0.s-' {1..80}
		echo
		for peer in "${peer_names[@]}"; do
			[[ ! -f "$_TMP_DIR/${peer}.json" ]] && continue
			local e online cpu tasks tier priv
			e="$(cat "$_TMP_DIR/${peer}.json")"
			online="$(echo "$e" | sed -n 's/.*"online":\([^,}]*\).*/\1/p')"
			cpu="$(echo "$e" | sed -n 's/.*"cpu_load":\([^,}]*\).*/\1/p')"
			tasks="$(echo "$e" | sed -n 's/.*"tasks_in_progress":\([^,}]*\).*/\1/p')"
			tier="$(echo "$e" | sed -n 's/.*"cost_tier":"\([^"]*\)".*/\1/p')"
			priv="$(echo "$e" | sed -n 's/.*"privacy_safe":\([^,}]*\).*/\1/p')"
			printf "%-20s %-8s %-12s %-22s %-10s %s\n" \
				"$peer" "${online:-?}" "${cpu:-null}" "${tasks:-null}" "${tier:-?}" "${priv:-?}"
		done
	fi
}

main
