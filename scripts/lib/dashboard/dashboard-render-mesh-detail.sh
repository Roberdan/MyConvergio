#!/bin/bash
# Full mesh topology detail view (htop/btop style)
# Version: 1.0.0
# Renders node boxes with CPU bars, capabilities, connections, health colors
# Exports: _render_mesh_detail

# Box dimensions + dispatch state
_MESH_BOX_W=30
_MESH_BOX_H=7
MESH_DISPATCH_TARGET=""
MESH_DISPATCH_FROM=""
MESH_DISPATCH_TTL=0
MESH_DISPATCH_LAST_CHECK=0

_mesh_health_color() {
	local name="$1"
	local status=$(_mesh_get "${name}.status")
	local online=$(_mesh_get "${name}.online")
	if [[ "$status" == "inactive" ]]; then echo "$GRAY"
	elif [[ "$online" != "1" ]]; then echo "$RED"
	else
		local cpu_raw=$(_mesh_get "${name}.cpu" "0")
		local cpu_int="${cpu_raw%%.*}"
		local ncpu=$(sysctl -n hw.ncpu 2>/dev/null || nproc 2>/dev/null || echo 4)
		[[ ${cpu_int:-0} -ge $(( ncpu * 70 / 100 )) ]] && echo "$YELLOW" || echo "$GREEN"
	fi
}

_render_node_box() {
	local name="$1" w="${2:-$_MESH_BOX_W}" prefix="${3:-}"
	local hc=$(_mesh_health_color "$name")
	# Flash highlight if this node is the dispatch target
	if [[ "$name" == "${MESH_DISPATCH_TARGET:-}" && ${MESH_DISPATCH_TTL:-0} -gt 0 ]]; then
		hc="${BOLD}${CYAN}"
	fi
	local role=$(_mesh_get "${name}.role")
	local os=$(_mesh_get "${name}.os")
	local online=$(_mesh_get "${name}.online")
	local cpu_raw=$(_mesh_get "${name}.cpu" "0")
	local cpu_int="${cpu_raw%%.*}"
	local tasks=$(_mesh_get "${name}.tasks" "0")
	local caps=$(_mesh_get "${name}.caps")
	local priv=$(_mesh_get "${name}.privacy" "0")
	local status=$(_mesh_get "${name}.status")

	# Role + OS icons
	local role_icon="●"
	[[ "$role" == "coordinator" || "$role" == "hybrid" ]] && role_icon="★"
	local os_icon="🐧"
	[[ "$os" == "macos" ]] && os_icon="🍎"

	# Capability badges
	local cap_str=""
	case ",$caps," in *",claude,"*) cap_str+="${GREEN}[CLU]${NC} " ;; esac
	case ",$caps," in *",copilot,"*) cap_str+="${CYAN}[COP]${NC} " ;; esac
	case ",$caps," in *",ollama,"*) cap_str+="${YELLOW}[OLL]${NC} " ;; esac

	# Privacy indicator
	local priv_icon="🔓"
	[[ "$priv" == "1" ]] && priv_icon="🔒"

	# Status text
	local status_text="ONLINE"
	if [[ "$status" == "inactive" ]]; then status_text="INACTIVE"
	elif [[ "$online" != "1" ]]; then status_text="OFFLINE"
	fi

	# Inner width for content (w - 4 for borders + padding)
	local iw=$(( w - 4 ))

	# Top border with name
	local name_display="${name}"
	printf "${prefix}${hc}┌─ %-${iw}s ─┐${NC}\n" "$name_display"

	# Line 1: role + OS + status
	printf "${prefix}${hc}│${NC} ${BOLD}${role_icon} ${role}${NC} ${os_icon}  %*s ${hc}│${NC}\n" $(( iw - 14 )) "${status_text}"

	# Line 2: CPU bar
	if [[ "$online" == "1" ]]; then
		local bar=$(render_bar "${cpu_int:-0}" 12)
		printf "${prefix}${hc}│${NC} CPU ${bar} %3s%% ${hc}│${NC}\n" "${cpu_int:-0}"
	else
		printf "${prefix}${hc}│${NC} CPU ${GRAY}────────────${NC}  ─── ${hc}│${NC}\n"
	fi

	# Line 3: Tasks
	if [[ "$online" == "1" ]]; then
		local tasks_int="${tasks%%.*}"
		printf "${prefix}${hc}│${NC} Tasks: ${WHITE}%s${NC}/${MESH_MAX_TASKS}%*s${hc}│${NC}\n" "${tasks_int}" $(( iw - 12 )) ""
	else
		printf "${prefix}${hc}│${NC} Tasks: ${GRAY}─${NC}%*s${hc}│${NC}\n" $(( iw - 9 )) ""
	fi

	# Line 4: Capabilities
	printf "${prefix}${hc}│${NC} ${cap_str}%*s${hc}│${NC}\n" $(( iw - ${#caps} + 2 )) ""

	# Line 5: Privacy
	printf "${prefix}${hc}│${NC} ${priv_icon} %s%*s${hc}│${NC}\n" \
		"$([[ "$priv" == "1" ]] && echo "private" || echo "open")" $(( iw - 11 )) ""

	# Bottom border
	local bottom=""
	for (( i=0; i < w - 2; i++ )); do bottom+="─"; done
	printf "${prefix}${hc}└${bottom}┘${NC}\n"
}

_render_mesh_connections() {
	local layout="$1"
	if [[ "$layout" == "horizontal" ]]; then
		local conn="  "
		for name in $MESH_PEER_NAMES; do
			local on=$(_mesh_get "${name}.online") st=$(_mesh_get "${name}.status")
			if [[ "$on" == "1" && "$st" != "inactive" ]]; then
				conn+="${GREEN}╠$(printf '═%.0s' $(seq 1 $((_MESH_BOX_W-2))))╣${NC}  "
			else
				conn+="${GRAY}$(printf '┄%.0s' $(seq 1 $_MESH_BOX_W))${NC}  "
			fi
		done
		echo -e "$conn"
	fi
	# Vertical connections handled inline in _render_mesh_detail
}

_render_mesh_footer() {
	local now
	now=$(date +%s)
	local newest_hb=0
	if [[ -f "$DB" ]]; then
		newest_hb=$(dbq "SELECT COALESCE(MAX(last_seen), 0) FROM peer_heartbeats;" 2>/dev/null)
	fi
	local age="n/a"
	if [[ ${newest_hb:-0} -gt 0 ]]; then
		age="$(format_elapsed $(( now - newest_hb ))) ago"
	fi
	echo ""
	echo -e "${GRAY}  Last heartbeat: ${WHITE}${age}${NC}${GRAY} │ Coordinator: ${WHITE}${MESH_COORDINATOR:-?}${NC}${GRAY} │ Refresh: ${WHITE}10s${NC}"
}

_mesh_detect_dispatch() {
	[[ ! -f "$DB" ]] && return
	local now
	now=$(date +%s)
	# Only check every 5 seconds
	if [[ $(( now - MESH_DISPATCH_LAST_CHECK )) -lt 5 ]]; then return; fi
	MESH_DISPATCH_LAST_CHECK=$now
	# Find tasks dispatched in last 15 seconds
	local dispatch_info
	dispatch_info=$(dbq "SELECT t.execution_host, t.task_id FROM tasks t
		WHERE t.status='in_progress' AND t.execution_host IS NOT NULL
		AND t.execution_host != '' AND datetime(t.updated_at) >= datetime('now', '-15 seconds')
		ORDER BY t.updated_at DESC LIMIT 1;" 2>/dev/null)
	if [[ -n "$dispatch_info" ]]; then
		local host task_id
		host=$(echo "$dispatch_info" | cut -d'|' -f1)
		task_id=$(echo "$dispatch_info" | cut -d'|' -f2)
		# Map execution_host to peer name (hostname match)
		local target_peer=""
		for name in $MESH_PEER_NAMES; do
			local alias=$(_mesh_get "${name}.ts_ip")
			local ssh=$(_mesh_get "${name}.ssh_alias" 2>/dev/null)
			if [[ "$host" == *"$name"* || "$name" == *"$host"* || "$host" == "$alias" ]]; then
				target_peer="$name"
				break
			fi
		done
		if [[ -n "$target_peer" && "$target_peer" != "$MESH_DISPATCH_TARGET" ]]; then
			MESH_DISPATCH_TARGET="$target_peer"
			MESH_DISPATCH_FROM="${MESH_COORDINATOR:-?}"
			MESH_DISPATCH_TTL=2
		fi
	fi
}

_render_dispatch_arrow() {
	[[ -z "${MESH_DISPATCH_TARGET:-}" || ${MESH_DISPATCH_TTL:-0} -le 0 ]] && return
	local cols=${COLUMNS:-$(tput cols 2>/dev/null || echo 80)}
	echo ""
	if [[ $cols -ge 80 ]]; then
		echo -e "  ${BOLD}${CYAN}  ${MESH_DISPATCH_FROM:-?} ═══════▶ ${WHITE}${MESH_DISPATCH_TARGET}${NC}${CYAN} ${GRAY}(dispatched)${NC}"
	else
		echo -e "  ${CYAN}[dispatched → ${WHITE}${MESH_DISPATCH_TARGET}${CYAN}]${NC}"
	fi
	(( MESH_DISPATCH_TTL-- )) || true
}

_render_mesh_detail() {
	# Ensure data is collected
	[[ -z "$MESH_PEER_NAMES" ]] && _mesh_collect_data

	# Check for recent dispatch events
	_mesh_detect_dispatch

	echo -e "${BOLD}${CYAN}╔════════════════════════════════════════════════════════════════════╗${NC}"
	echo -e "${BOLD}${CYAN}║${NC}          ${BOLD}${WHITE}🌐 Mesh Network — Topology${NC}                     ${BOLD}${CYAN}║${NC}"
	echo -e "${BOLD}${CYAN}╚════════════════════════════════════════════════════════════════════╝${NC}"
	echo ""
	echo -e "  ${GRAY}Nodes: ${WHITE}$(echo $MESH_PEER_NAMES | wc -w | tr -d ' ')${NC}${GRAY} │ Online: ${GREEN}${MESH_ONLINE_COUNT}${NC}${GRAY} │ Tasks: ${CYAN}${MESH_TOTAL_TASKS}${NC}"
	echo ""

	local cols=${COLUMNS:-$(tput cols 2>/dev/null || echo 80)}
	local layout="vertical"
	[[ $cols -ge 120 ]] && layout="horizontal"

	if [[ "$layout" == "horizontal" ]]; then
		# Render boxes side by side using paste-like approach
		local tmpdir
		tmpdir=$(mktemp -d "${TMPDIR:-/tmp}/mesh-dash.XXXXXX")
		local idx=0
		for name in $MESH_PEER_NAMES; do
			_render_node_box "$name" "$_MESH_BOX_W" "" >"$tmpdir/box_${idx}"
			(( idx++ )) || true
		done
		# Paste boxes side-by-side
		local max_lines=$_MESH_BOX_H
		for (( line=1; line<=max_lines; line++ )); do
			local row="  "
			for (( i=0; i<idx; i++ )); do
				local box_line
				box_line=$(sed -n "${line}p" "$tmpdir/box_${i}" 2>/dev/null || echo "")
				row+="${box_line}  "
			done
			echo -e "$row"
		done
		rm -rf "$tmpdir" 2>/dev/null
		echo ""
		_render_mesh_connections "horizontal"
	else
		# Stack vertically
		for name in $MESH_PEER_NAMES; do
			_render_node_box "$name" "$_MESH_BOX_W" "  "
			local next_name=""
			local found=0
			for n in $MESH_PEER_NAMES; do
				[[ $found -eq 1 ]] && next_name="$n" && break
				[[ "$n" == "$name" ]] && found=1
			done
			if [[ -n "$next_name" ]]; then
				local on=$(_mesh_get "${name}.online")
				[[ "$on" == "1" ]] && echo -e "  ${GREEN}  ║${NC}" || echo -e "  ${GRAY}  ┆${NC}"
			fi
		done
	fi

	_render_mesh_footer
	_render_dispatch_arrow
}
