#!/usr/bin/env bash
# mesh-load-query.sh — Query CPU load and task state across online mesh peers
# Version: 1.1.0
# Usage: mesh-load-query.sh [--json] [--peer NAME]
# Output: JSON array [{peer, cpu_load, tasks_in_progress, mem_used_gb, mem_total_gb, capabilities, cost_tier, privacy_safe, online}]
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
cpu=0
if [ "$(uname)" = "Darwin" ]; then
  # macOS load average
  cpu=$(uptime 2>/dev/null | sed -E 's/.*load averages?: *([0-9]+\.[0-9]+).*/\1/')
elif [[ "$(uname -s)" == MINGW* || "$(uname -s)" == MSYS* || "$(uname -s)" == CYGWIN* ]]; then
  # Windows: use PowerShell
  cpu="$(powershell.exe -NoProfile -Command '(Get-CimInstance Win32_Processor).LoadPercentage' 2>/dev/null || echo 0)"
else
  # Linux load average
  cpu=$(uptime 2>/dev/null | sed -E 's/.*load averages?: *([0-9]+\.[0-9]+).*/\1/')
fi
db="$HOME/.claude/data/dashboard.db"
tasks=0
if [ -f "$db" ] && command -v sqlite3 >/dev/null 2>&1; then
  tasks=$(sqlite3 "$db" "SELECT COUNT(*) FROM tasks WHERE status='in_progress';" 2>/dev/null || echo 0)
fi
# RAM: macOS -> sysctl/vm_stat | Linux -> /proc/meminfo (output in GB)
mem_total=0 mem_used=0
if [ "$(uname)" = "Darwin" ]; then
  mem_total=$(sysctl -n hw.memsize 2>/dev/null | awk '{printf "%.1f", $1/1073741824}')
  pages_free=$(vm_stat 2>/dev/null | awk '/Pages free/ {gsub(/\./,"",$3); print $3}')
  pages_inactive=$(vm_stat 2>/dev/null | awk '/Pages inactive/ {gsub(/\./,"",$3); print $3}')
  page_size=$(sysctl -n hw.pagesize 2>/dev/null || echo 16384)
  free_bytes=$(( (${pages_free:-0} + ${pages_inactive:-0}) * ${page_size} ))
  total_bytes=$(sysctl -n hw.memsize 2>/dev/null || echo 0)
  used_bytes=$(( total_bytes - free_bytes ))
  mem_used=$(echo "$used_bytes" | awk '{printf "%.1f", $1/1073741824}')
elif [[ "$(uname -s)" == MINGW* || "$(uname -s)" == MSYS* || "$(uname -s)" == CYGWIN* ]]; then
  # Windows: use PowerShell
  mem_info="$(powershell.exe -NoProfile -Command '$os=Get-CimInstance Win32_OperatingSystem; "{0}|{1}" -f [math]::Round(($os.TotalVisibleMemorySize-$os.FreePhysicalMemory)/1MB,1), [math]::Round($os.TotalVisibleMemorySize/1MB,1)' 2>/dev/null || echo '0|0')"
  mem_used="${mem_info%%|*}"
  mem_total="${mem_info##*|}"
else
  mem_total=$(awk '/MemTotal/ {printf "%.1f", $2/1048576}' /proc/meminfo 2>/dev/null)
  mem_avail=$(awk '/MemAvailable/ {printf "%.1f", $2/1048576}' /proc/meminfo 2>/dev/null)
  mem_used=$(echo "$mem_total $mem_avail" | awk '{printf "%.1f", $1-$2}')
fi
printf '%s %s %s %s\n' "${cpu:-0}" "${tasks:-0}" "${mem_used:-0}" "${mem_total:-0}"
REMOTE
}

_ssh() {
	local peer="$1"
	shift
	local target user dest
	target="$(peers_best_route "$peer" 2>/dev/null)" || return 1
	user="$(peers_get "$peer" "user" 2>/dev/null || echo "")"
	dest="${user:+${user}@}${target}"
	ssh -o ConnectTimeout=5 -o StrictHostKeyChecking=accept-new \
		-o BatchMode=yes -o LogLevel=quiet "$dest" "$@" 2>/dev/null
}

_get_remote_load() {
	local peer="$1" os="$2"
	if [[ "$os" == "windows" ]]; then
		_ssh "$peer" "powershell.exe -NoProfile -Command '(Get-CimInstance Win32_Processor).LoadPercentage'"
	else
		_ssh "$peer" "uptime | grep -oE 'load averages?: [0-9]+\\.[0-9]+' | grep -oE '[0-9]+\\.[0-9]+$'"
	fi
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
	printf '{"peer":"%s","cpu_load":null,"tasks_in_progress":null,"mem_used_gb":null,"mem_total_gb":null,"capabilities":"%s","cost_tier":"%s","privacy_safe":%s,"online":false}\n' \
		"$name" "$caps" "$cost_tier" "$privacy_safe" >"$result_file"
	_upsert_heartbeat "$name" "$caps" "null"
}

_query_peer() {
	local name="$1" result_file="$2"
	local caps cost_tier privacy_safe os
	caps="$(peers_get "$name" "capabilities" 2>/dev/null || echo "")"
	cost_tier="$(_cost_tier_for_caps "$caps")"
	privacy_safe="$(_privacy_safe_for_caps "$caps")"
	os="$(peers_get "$name" "os" 2>/dev/null || echo "linux")"

	if ! peers_best_route "$name" >/dev/null 2>&1; then
		_write_offline "$name" "$caps" "$cost_tier" "$privacy_safe" "$result_file"
		return
	fi

	local raw cpu tasks mem_used mem_total mem_info
	if [[ "$os" == "windows" ]]; then
		cpu="$(_get_remote_load "$name" "$os" || echo "0")"
		mem_info="$(_ssh "$name" "powershell.exe -NoProfile -Command '\$os=Get-CimInstance Win32_OperatingSystem; \"{0}|{1}\" -f [math]::Round((\$os.TotalVisibleMemorySize-\$os.FreePhysicalMemory)/1MB,1), [math]::Round(\$os.TotalVisibleMemorySize/1MB,1)'" || echo "0|0")"
		mem_used="${mem_info%%|*}"
		mem_total="${mem_info##*|}"
		tasks="$(_ssh "$name" "powershell.exe -NoProfile -Command '\$db=Join-Path \$env:USERPROFILE ''.claude\\data\\dashboard.db''; if (Test-Path \$db -and (Get-Command sqlite3 -ErrorAction SilentlyContinue)) { sqlite3 \$db \"SELECT COUNT(*) FROM tasks WHERE status=''in_progress'';\" } else { 0 }'" || echo "0")"
		raw="${cpu:-0} ${tasks:-0} ${mem_used:-0} ${mem_total:-0}"
	elif ! raw="$(_ssh "$name" "bash -s" <<<"$(_remote_cmd)")"; then
		_write_offline "$name" "$caps" "$cost_tier" "$privacy_safe" "$result_file"
		return
	fi

	cpu="$(echo "$raw" | awk '{print $1}')"
	tasks="$(echo "$raw" | awk '{print $2}')"
	mem_used="$(echo "$raw" | awk '{print $3}')"
	mem_total="$(echo "$raw" | awk '{print $4}')"
	cpu="${cpu:-0}"
	tasks="${tasks:-0}"
	mem_used="${mem_used:-0}"
	mem_total="${mem_total:-0}"

	printf '{"peer":"%s","cpu_load":%s,"tasks_in_progress":%s,"mem_used_gb":%s,"mem_total_gb":%s,"capabilities":"%s","cost_tier":"%s","privacy_safe":%s,"online":true}\n' \
		"$name" "$cpu" "$tasks" "$mem_used" "$mem_total" "$caps" "$cost_tier" "$privacy_safe" >"$result_file"
	_upsert_heartbeat "$name" "$caps" \
		"{\"cpu_load\":$cpu,\"tasks_in_progress\":$tasks,\"mem_used_gb\":$mem_used,\"mem_total_gb\":$mem_total,\"cost_tier\":\"$cost_tier\",\"privacy_safe\":$privacy_safe}"
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
