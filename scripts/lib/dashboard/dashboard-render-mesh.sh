#!/bin/bash
# Mesh network data collection and mini-preview rendering
# Version: 1.0.0
# Sources: peers.conf, peer_heartbeats (SQLite), mesh-load-query.sh
# Exports: _mesh_collect_data, _render_mesh_mini

CLAUDE_HOME="${CLAUDE_HOME:-$HOME/.claude}"
MESH_PEERS_CONF="${PEERS_CONF:-$CLAUDE_HOME/config/peers.conf}"
MESH_MAX_TASKS=${MESH_MAX_TASKS_PER_PEER:-3}
MESH_STALE_WINDOW=${MESH_STALE_WINDOW:-300}

# Peer data stored via eval (bash 3.2 compatible, same pattern as peers.sh)
MESH_PEER_NAMES=""
MESH_ONLINE_COUNT=0
MESH_TOTAL_TASKS=0
MESH_COORDINATOR=""

_mesh_set() { eval "_MESH_${1//[-.]/_}=$(printf '%q' "$2")"; }
_mesh_get() { eval "printf '%s' \"\${_MESH_${1//[-.]/_}:-${2:-}}\""; }

_mesh_collect_data() {
	MESH_PEER_NAMES=""
	MESH_ONLINE_COUNT=0
	MESH_TOTAL_TASKS=0
	MESH_COORDINATOR=""

	# Load peers from peers.conf via peers.sh if available
	if type peers_load &>/dev/null; then
		peers_load 2>/dev/null
	else
		local _peers_lib="$CLAUDE_HOME/scripts/lib/peers.sh"
		[[ -f "$_peers_lib" ]] && source "$_peers_lib" && peers_load 2>/dev/null
	fi

	local now
	now=$(date +%s)

	# Parse peers.conf directly for all fields
	local name="" line
	while IFS= read -r line || [[ -n "$line" ]]; do
		line="${line%%#*}"
		while [[ "$line" == [[:space:]]* ]]; do line="${line#?}"; done
		while [[ "$line" == *[[:space:]] ]]; do line="${line%?}"; done
		[[ -z "$line" ]] && continue
		if [[ "$line" == "["*"]" ]]; then
			name="${line#[}"; name="${name%]}"
			MESH_PEER_NAMES="${MESH_PEER_NAMES:+$MESH_PEER_NAMES }$name"
			_mesh_set "${name}.status" "active"
			_mesh_set "${name}.online" "0"
			_mesh_set "${name}.cpu" "0"
			_mesh_set "${name}.tasks" "0"
			_mesh_set "${name}.role" "worker"
			_mesh_set "${name}.os" "linux"
			_mesh_set "${name}.caps" ""
			_mesh_set "${name}.privacy" "0"
			continue
		fi
		[[ -z "$name" ]] && continue
		local key="${line%%=*}" val="${line#*=}"
		case "$key" in
		role|os|status) _mesh_set "${name}.${key}" "$val" ;;
		capabilities) _mesh_set "${name}.caps" "$val" ;;
		tailscale_ip) _mesh_set "${name}.ts_ip" "$val" ;;
		esac
	done <"$MESH_PEERS_CONF"

	# Query peer_heartbeats for liveness + load
	if [[ -f "$DB" ]]; then
		local hb_data
		hb_data=$(dbq "SELECT peer_name, last_seen, load_json FROM peer_heartbeats;" 2>/dev/null)
		while IFS='|' read -r hb_name hb_seen hb_json; do
			[[ -z "$hb_name" ]] && continue
			local age=$(( now - ${hb_seen:-0} ))
			[[ $age -le $MESH_STALE_WINDOW ]] && _mesh_set "${hb_name}.online" "1"
			# Parse load_json fields with single python3 call
			local parsed
			parsed=$(/usr/bin/python3 -c "
import json,sys
try:
    d=json.loads(sys.stdin.read())
    print(d.get('cpu_load',0))
    print(d.get('tasks_in_progress',0))
    print(1 if d.get('privacy_safe') else 0)
except: print('0\n0\n0')
" <<<"$hb_json" 2>/dev/null || printf '0\n0\n0')
			local cpu_v tasks_v priv_v
			cpu_v=$(echo "$parsed" | sed -n '1p')
			tasks_v=$(echo "$parsed" | sed -n '2p')
			priv_v=$(echo "$parsed" | sed -n '3p')
			_mesh_set "${hb_name}.cpu" "${cpu_v:-0}"
			_mesh_set "${hb_name}.tasks" "${tasks_v:-0}"
			_mesh_set "${hb_name}.privacy" "${priv_v:-0}"
		done <<<"$hb_data"
	fi

	# Derive coordinator, privacy fallback, counts
	for name in $MESH_PEER_NAMES; do
		local role=$(_mesh_get "${name}.role")
		[[ "$role" == "coordinator" || "$role" == "hybrid" ]] && MESH_COORDINATOR="$name"
		local caps=$(_mesh_get "${name}.caps")
		case ",$caps," in *",ollama,"*) _mesh_set "${name}.privacy" "1" ;; esac
		[[ "$(_mesh_get "${name}.online")" == "1" ]] && (( MESH_ONLINE_COUNT++ )) || true
		local t=$(_mesh_get "${name}.tasks" "0")
		(( MESH_TOTAL_TASKS += ${t%%.*} )) || true
	done
}

_mesh_peer_color() {
	local name="$1"
	local status=$(_mesh_get "${name}.status")
	local online=$(_mesh_get "${name}.online")
	if [[ "$status" == "inactive" ]]; then printf '%b' "$GRAY"
	elif [[ "$online" != "1" ]]; then printf '%b' "$RED"
	else
		local cpu_raw=$(_mesh_get "${name}.cpu" "0")
		local cpu_int="${cpu_raw%%.*}"
		local ncpu=$(sysctl -n hw.ncpu 2>/dev/null || nproc 2>/dev/null || echo 4)
		if [[ ${cpu_int:-0} -ge $(( ncpu * 70 / 100 )) ]]; then printf '%b' "$YELLOW"
		else printf '%b' "$GREEN"; fi
	fi
}

_mesh_peer_icon() {
	local name="$1" status=$(_mesh_get "${name}.status") online=$(_mesh_get "${name}.online")
	if [[ "$status" == "inactive" ]]; then echo "◌"
	elif [[ "$online" == "1" ]]; then echo "●"
	else echo "○"; fi
}

_render_mesh_mini() {
	_mesh_collect_data
	local total=0
	for _ in $MESH_PEER_NAMES; do (( total++ )) || true; done
	echo ""
	echo -e "${BOLD}${WHITE}🌐 Mesh Network${NC} ${GRAY}(${GREEN}${MESH_ONLINE_COUNT}${GRAY}/${total} online, ${CYAN}${MESH_TOTAL_TASKS}${GRAY} tasks)${NC}"
	local name
	for name in $MESH_PEER_NAMES; do
		local color icon role_badge cpu_bar tasks_str
		color=$(_mesh_peer_color "$name")
		icon=$(_mesh_peer_icon "$name")
		local role=$(_mesh_get "${name}.role")
		[[ "$role" == "coordinator" || "$role" == "hybrid" ]] && role_badge="★" || role_badge="●"
		local cpu=$(_mesh_get "${name}.cpu" "0") cpu_int="${cpu%%.*}"
		local online=$(_mesh_get "${name}.online")
		if [[ "$online" == "1" ]]; then
			cpu_bar=$(render_bar "${cpu_int:-0}" 5)
			tasks_str="$(_mesh_get "${name}.tasks" "0")/${MESH_MAX_TASKS}"
		else
			cpu_bar="${GRAY}─────${NC}"
			tasks_str="─"
		fi
		local caps=$(_mesh_get "${name}.caps") caps_short=""
		case ",$caps," in *",claude,"*) caps_short+="C" ;; esac
		case ",$caps," in *",copilot,"*) caps_short+="P" ;; esac
		case ",$caps," in *",ollama,"*) caps_short+="O" ;; esac
		printf "  ${color}${icon}${NC} %-10s ${GRAY}${role_badge}${NC} ${cpu_bar} ${WHITE}%s${NC} ${GRAY}[${caps_short}]${NC}\n" "$name" "$tasks_str"
	done
	[[ -n "$MESH_COORDINATOR" ]] && echo -e "${GRAY}  └─ Coordinator: ${WHITE}${MESH_COORDINATOR}${NC}"
}
