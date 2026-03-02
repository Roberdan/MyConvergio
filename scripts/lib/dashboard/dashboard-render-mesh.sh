#!/bin/bash
# Mesh network data collection and mini-preview rendering
# Version: 2.0.0 — True mesh topology + theme support
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
	elif [[ "$online" != "1" ]]; then printf '%b' "${TH_NODE_OFFLINE:-$RED}"
	else
		local cpu_raw=$(_mesh_get "${name}.cpu" "0")
		local cpu_int="${cpu_raw%%.*}"
		local ncpu=$(sysctl -n hw.ncpu 2>/dev/null || nproc 2>/dev/null || echo 4)
		if [[ ${cpu_int:-0} -ge $(( ncpu * 70 / 100 )) ]]; then printf '%b' "$YELLOW"
		else printf '%b' "${TH_NODE_ONLINE:-$GREEN}"; fi
	fi
}

_mesh_peer_icon() {
	local name="$1" status=$(_mesh_get "${name}.status") online=$(_mesh_get "${name}.online")
	if [[ "$status" == "inactive" ]]; then echo "◌"
	elif [[ "$online" == "1" ]]; then echo "●"
	else echo "○"; fi
}

# Build a themed node label: "icon star name [CAPS] STATUS cpu%"
_mesh_node_label() {
	local name="$1"
	local color=$(_mesh_peer_color "$name")
	local icon=$(_mesh_peer_icon "$name")
	local role=$(_mesh_get "${name}.role")
	local online=$(_mesh_get "${name}.online")
	local cpu=$(_mesh_get "${name}.cpu" "0") cpu_int="${cpu%%.*}"
	local caps=$(_mesh_get "${name}.caps") caps_short=""
	case ",$caps," in *",claude,"*) caps_short+="C" ;; esac
	case ",$caps," in *",copilot,"*) caps_short+="P" ;; esac
	case ",$caps," in *",ollama,"*) caps_short+="O" ;; esac
	local role_badge="●"
	[[ "$role" == "coordinator" || "$role" == "hybrid" ]] && role_badge="★"
	local status_str=""
	if [[ "$online" == "1" ]]; then
		status_str="${GREEN}ON${NC}"
	else
		status_str="${TH_NODE_OFFLINE:-$RED}OFF${NC}"
	fi
	# CPU bar (themed)
	local cpu_bar=""
	if [[ "$online" == "1" ]]; then
		local fill=$(( cpu_int * 5 / 100 ))
		local empty=$(( 5 - fill ))
		local fb="" eb=""
		for (( i=0; i<fill; i++ )); do fb+="${TH_BAR_FILL:-▓}"; done
		for (( i=0; i<empty; i++ )); do eb+="${TH_BAR_EMPTY:-░}"; done
		cpu_bar="${GREEN}${fb}${GRAY}${eb}${NC}"
	else
		cpu_bar="${GRAY}─────${NC}"
	fi
	printf "${color}${icon}${NC} ${GRAY}${role_badge}${NC} ${BOLD}${WHITE}%-8s${NC} ${GRAY}[${caps_short}]${NC} ${status_str} ${cpu_bar}" "$name"
}

_render_mesh_mini() {
	_mesh_collect_data
	local total=0 names_arr=()
	for n in $MESH_PEER_NAMES; do names_arr+=("$n"); (( total++ )) || true; done

	echo ""
	# Section header (themed)
	local hdr_extra="${GRAY}(${GREEN}${MESH_ONLINE_COUNT}${GRAY}/${total} online, ${CYAN}${MESH_TOTAL_TASKS}${GRAY} tasks)${NC}"
	if [[ -n "${TH_SECTION_L:-}" ]]; then
		echo -e "${TH_PRIMARY}${TH_SECTION_L}${BOLD}${WHITE}MESH NETWORK${NC}${TH_PRIMARY}${TH_SECTION_R}${NC} ${hdr_extra}"
	else
		echo -e "${BOLD}${WHITE}🌐 Mesh Network${NC} ${hdr_extra}"
	fi

	# Draw themed box top
	_th_box_top 57 "${TH_SECONDARY:-$GRAY}" 2>/dev/null || true

	# Coordinator at top of triangle
	local coord=""
	local workers=()
	for n in "${names_arr[@]}"; do
		local role=$(_mesh_get "${n}.role")
		if [[ "$role" == "coordinator" || "$role" == "hybrid" ]]; then
			coord="$n"
		else
			workers+=("$n")
		fi
	done
	[[ -z "$coord" ]] && coord="${names_arr[0]}" && workers=("${names_arr[@]:1}")

	# Coordinator node (centered)
	local coord_label
	coord_label=$(_mesh_node_label "$coord")
	local coord_color=$(_mesh_peer_color "$coord")
	echo -e "  ${TH_SECONDARY:-$GRAY}${TH_BORDER_V:-│}${NC}          ${coord_label}          ${TH_SECONDARY:-$GRAY}${TH_BORDER_V:-│}${NC}"

	# Connection lines from coordinator to workers
	if [[ ${#workers[@]} -ge 2 ]]; then
		echo -e "  ${TH_SECONDARY:-$GRAY}${TH_BORDER_V:-│}${NC}              ${coord_color}┌──────┘ └──────┐${NC}              ${TH_SECONDARY:-$GRAY}${TH_BORDER_V:-│}${NC}"
		echo -e "  ${TH_SECONDARY:-$GRAY}${TH_BORDER_V:-│}${NC}              ${coord_color}│${NC}                ${coord_color}│${NC}              ${TH_SECONDARY:-$GRAY}${TH_BORDER_V:-│}${NC}"
	elif [[ ${#workers[@]} -eq 1 ]]; then
		echo -e "  ${TH_SECONDARY:-$GRAY}${TH_BORDER_V:-│}${NC}                    ${coord_color}│${NC}                         ${TH_SECONDARY:-$GRAY}${TH_BORDER_V:-│}${NC}"
	fi

	# Worker nodes side by side
	if [[ ${#workers[@]} -ge 2 ]]; then
		local w1_label w2_label
		w1_label=$(_mesh_node_label "${workers[0]}")
		w2_label=$(_mesh_node_label "${workers[1]}")
		echo -e "  ${TH_SECONDARY:-$GRAY}${TH_BORDER_V:-│}${NC} ${w1_label}  ${w2_label} ${TH_SECONDARY:-$GRAY}${TH_BORDER_V:-│}${NC}"
		# Backbone (bottom of triangle)
		local w1_color=$(_mesh_peer_color "${workers[0]}")
		local w2_color=$(_mesh_peer_color "${workers[1]}")
		echo -e "  ${TH_SECONDARY:-$GRAY}${TH_BORDER_V:-│}${NC}              ${w1_color}└────────${NC}${TH_PRIMARY:-$CYAN}◉${NC}${w2_color}────────┘${NC}              ${TH_SECONDARY:-$GRAY}${TH_BORDER_V:-│}${NC}"
		echo -e "  ${TH_SECONDARY:-$GRAY}${TH_BORDER_V:-│}${NC}                ${GRAY}${TH_BACKBONE:-MESH BACKBONE}${NC}                  ${TH_SECONDARY:-$GRAY}${TH_BORDER_V:-│}${NC}"
	elif [[ ${#workers[@]} -eq 1 ]]; then
		local w1_label
		w1_label=$(_mesh_node_label "${workers[0]}")
		echo -e "  ${TH_SECONDARY:-$GRAY}${TH_BORDER_V:-│}${NC}     ${w1_label}                    ${TH_SECONDARY:-$GRAY}${TH_BORDER_V:-│}${NC}"
	fi

	# Footer line + box bottom
	echo -e "  ${TH_SECONDARY:-$GRAY}${TH_BORDER_V:-│}${NC} ${GRAY}coord:${WHITE}${MESH_COORDINATOR:-?}${NC} ${GRAY}│ net:${GREEN}tailscale${NC} ${GRAY}│ stale:${WHITE}${MESH_STALE_WINDOW}s${NC}   ${TH_SECONDARY:-$GRAY}${TH_BORDER_V:-│}${NC}"
	_th_box_bot 57 "${TH_SECONDARY:-$GRAY}" 2>/dev/null || true
}
