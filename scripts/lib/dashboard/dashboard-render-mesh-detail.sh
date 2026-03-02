#!/bin/bash
# Full mesh topology detail view — htop-style horizontal node boxes
# Version: 2.0.0 | Exports: _render_mesh_detail
_MESH_BOX_W=28
_MESH_BOX_H=8
MESH_DISPATCH_TARGET=""
MESH_DISPATCH_FROM=""
MESH_DISPATCH_TTL=0
MESH_DISPATCH_LAST_CHECK=0

_mesh_health_color() {
	local name="$1"
	local status=$(_mesh_get "${name}.status")
	local online=$(_mesh_get "${name}.online")
	if [[ "$status" == "inactive" ]]; then
		echo "$GRAY"
	elif [[ "$online" != "1" ]]; then
		echo "${TH_ERROR:-$RED}"
	else
		local cpu_raw=$(_mesh_get "${name}.cpu" "0")
		local cpu_int="${cpu_raw%%.*}"
		local ncpu=$(sysctl -n hw.ncpu 2>/dev/null || nproc 2>/dev/null || echo 4)
		[[ ${cpu_int:-0} -ge $((ncpu * 70 / 100)) ]] && echo "${TH_WARNING:-$YELLOW}" || echo "${TH_SUCCESS:-$GREEN}"
	fi
}

_mesh_detect_dispatch() {
	[[ ! -f "$DB" ]] && return
	local now
	now=$(date +%s)
	if [[ $((now - MESH_DISPATCH_LAST_CHECK)) -lt 5 ]]; then return; fi
	MESH_DISPATCH_LAST_CHECK=$now
	local dispatch_info
	dispatch_info=$(dbq "SELECT t.execution_host, t.task_id FROM tasks t
		WHERE t.status='in_progress' AND t.execution_host IS NOT NULL
		AND t.execution_host != '' AND datetime(t.updated_at) >= datetime('now', '-15 seconds')
		ORDER BY t.updated_at DESC LIMIT 1;" 2>/dev/null)
	if [[ -n "$dispatch_info" ]]; then
		local host task_id target_peer=""
		host=$(echo "$dispatch_info" | cut -d'|' -f1)
		task_id=$(echo "$dispatch_info" | cut -d'|' -f2)
		for name in $MESH_PEER_NAMES; do
			local alias=$(_mesh_get "${name}.ts_ip")
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
		echo -e "  ${BOLD}${TH_INFO:-$CYAN}  ${MESH_DISPATCH_FROM:-?} ═══════▶ ${WHITE}${MESH_DISPATCH_TARGET}${NC}${TH_INFO:-$CYAN} ${GRAY}(dispatched)${NC}"
	else
		echo -e "  ${TH_INFO:-$CYAN}[dispatched → ${WHITE}${MESH_DISPATCH_TARGET}${TH_INFO:-$CYAN}]${NC}"
	fi
	((MESH_DISPATCH_TTL--)) || true
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
		age="$(format_elapsed $((now - newest_hb))) ago"
	fi
	echo ""
	echo -e "${GRAY}  Last heartbeat: ${WHITE}${age}${NC}${GRAY} | Coordinator: ${WHITE}${MESH_COORDINATOR:-?}${NC}${GRAY} | Stale: ${WHITE}${MESH_STALE_WINDOW}s${NC}"
	echo -e "  ${GRAY}Keys: ${TH_PRIMARY:-$CYAN}G${NC}${GRAY}=migrate ${TH_PRIMARY:-$CYAN}S${NC}${GRAY}=sync ${TH_PRIMARY:-$CYAN}D${NC}${GRAY}=dispatch ${TH_PRIMARY:-$CYAN}H${NC}${GRAY}=heartbeat ${TH_PRIMARY:-$CYAN}A${NC}${GRAY}=auth ${TH_PRIMARY:-$CYAN}E${NC}${GRAY}=env${NC}"
}

# Render one node box to a temp file (7 lines)
# Usage: _render_node_box_file <name> <file>
_render_node_box_file() {
	local name="$1" outfile="$2"
	local w=$_MESH_BOX_W
	local hc
	hc=$(_mesh_health_color "$name")
	# Flash highlight if dispatch target
	if [[ "$name" == "${MESH_DISPATCH_TARGET:-}" && ${MESH_DISPATCH_TTL:-0} -gt 0 ]]; then
		hc="${BOLD}${TH_INFO:-$CYAN}"
	fi
	local role=$(_mesh_get "${name}.role")
	local os=$(_mesh_get "${name}.os")
	local online=$(_mesh_get "${name}.online")
	local cpu_raw=$(_mesh_get "${name}.cpu" "0")
	local cpu_int="${cpu_raw%%.*}"
	local tasks=$(_mesh_get "${name}.tasks" "0")
	local tasks_int="${tasks%%.*}"
	local caps=$(_mesh_get "${name}.caps")
	local priv=$(_mesh_get "${name}.privacy" "0")
	local status=$(_mesh_get "${name}.status")
	local role_icon="*"
	[[ "$role" == "coordinator" || "$role" == "hybrid" ]] && role_icon="+"
	local os_icon="[L]"
	[[ "$os" == "macos" ]] && os_icon="[M]"
	local cap_str=""
	case ",$caps," in *",claude,"*) cap_str+="${TH_SUCCESS:-$GREEN}[CLU]${NC}" ;; esac
	case ",$caps," in *",copilot,"*) cap_str+="${TH_INFO:-$CYAN}[COP]${NC}" ;; esac
	case ",$caps," in *",ollama,"*) cap_str+="${TH_WARNING:-$YELLOW}[OLL]${NC}" ;; esac

	local priv_icon="open"
	[[ "$priv" == "1" ]] && priv_icon="priv"
	local status_text="ONLINE"
	[[ "$status" == "inactive" ]] && status_text="INACTIVE"
	[[ "$online" != "1" && "$status" != "inactive" ]] && status_text="OFFLINE"
	local iw=$((w - 4))
	{
		local name_part="${role_icon} ${name}"
		local after=$((w - 2 - ${#name_part} - 4))
		[[ $after -lt 0 ]] && after=0
		local after_line=""
		for ((i = 0; i < after; i++)); do after_line+="${TH_INNER_H:--}"; done
		printf "${hc}${TH_INNER_TL:-+}${TH_INNER_H:--} %s %s${TH_INNER_TR:-+}${NC}\n" "$name_part" "$after_line"
		printf "${hc}${TH_INNER_V:-|}${NC} ${os_icon}  ${GRAY}${role}${NC}%*s${hc}${status_text}${NC} ${hc}${TH_INNER_V:-|}${NC}\n" $((iw - 8 - ${#role} - ${#status_text})) ""
		if [[ "$online" == "1" ]]; then
			local bar_w=10 filled=$((cpu_int * bar_w / 100)) bar="" ebar=""
			[[ $filled -gt $bar_w ]] && filled=$bar_w
			local empty=$((bar_w - filled))
			for ((i = 0; i < filled; i++)); do bar+="${TH_BAR_FILL:-#}"; done
			for ((i = 0; i < empty; i++)); do ebar+="${TH_BAR_EMPTY:-.}"; done
			local bc="${TH_SUCCESS:-$GREEN}"
			[[ ${cpu_int:-0} -ge 80 ]] && bc="${TH_ERROR:-$RED}" || { [[ ${cpu_int:-0} -ge 40 ]] && bc="${TH_WARNING:-$YELLOW}"; }
			printf "${hc}${TH_INNER_V:-|}${NC} CPU ${bc}%s${GRAY}%s${NC} %3d%% %*s${hc}${TH_INNER_V:-|}${NC}\n" \
				"$bar" "$ebar" "${cpu_int:-0}" $((iw - bar_w - 9)) ""
		else
			printf "${hc}${TH_INNER_V:-|}${NC} CPU ${GRAY}..........${NC}  ---%% %*s${hc}${TH_INNER_V:-|}${NC}\n" $((iw - 20)) ""
		fi
		printf "${hc}${TH_INNER_V:-|}${NC} Tasks ${WHITE}%s${NC}/${MESH_MAX_TASKS}%*s${hc}${TH_INNER_V:-|}${NC}\n" \
			"${tasks_int}" $((iw - 10)) ""
		printf "${hc}${TH_INNER_V:-|}${NC} %s%*s${hc}${TH_INNER_V:-|}${NC}\n" "${cap_str}" $((iw - ${#caps} - 2)) ""
		local lock_icon="       "
		[[ "$priv" == "1" ]] && lock_icon="[PRIV] "
		printf "${hc}${TH_INNER_V:-|}${NC} ${TH_MUTED:-$GRAY}%s%s${NC}%*s${hc}${TH_INNER_V:-|}${NC}\n" \
			"$lock_icon" "$priv_icon" $((iw - 12)) ""
		local bot_inner=""
		for ((i = 0; i < w - 2; i++)); do bot_inner+="${TH_INNER_H:--}"; done
		printf "${hc}${TH_INNER_BL:-+}%s${TH_INNER_BR:-+}${NC}\n" "$bot_inner"
	} >"$outfile"
}

_render_mesh_detail() {
	# Ensure data is collected
	[[ -z "$MESH_PEER_NAMES" ]] && _mesh_collect_data

	# Check for recent dispatch events
	_mesh_detect_dispatch

	local total=0
	for n in $MESH_PEER_NAMES; do ((total++)) || true; done

	# Section header using grid layout
	if type _grid_section &>/dev/null; then
		_grid_section "MESH NETWORK" "nodes:${total} online:${MESH_ONLINE_COUNT} tasks:${MESH_TOTAL_TASKS}"
	else
		echo -e "${TH_PRIMARY:-$CYAN}--- MESH NETWORK --- nodes:${total} online:${MESH_ONLINE_COUNT} tasks:${MESH_TOTAL_TASKS}${NC}"
	fi
	echo ""

	# Render boxes side-by-side (horizontal htop-style)
	local tmpdir
	tmpdir=$(mktemp -d "${TMPDIR:-/tmp}/mesh-dash.XXXXXX")
	local idx=0
	for name in $MESH_PEER_NAMES; do
		_render_node_box_file "$name" "$tmpdir/box_${idx}"
		((idx++)) || true
	done

	# Paste boxes side-by-side (8 lines per box)
	local line
	for ((line = 1; line <= _MESH_BOX_H; line++)); do
		local row="  "
		for ((i = 0; i < idx; i++)); do
			local box_line=""
			box_line=$(sed -n "${line}p" "$tmpdir/box_${i}" 2>/dev/null || true)
			row+="${box_line}  "
		done
		echo -e "$row"
	done

	# Backbone connection line between boxes
	echo ""
	if [[ $idx -ge 2 ]]; then
		local conn="  "
		for name in $MESH_PEER_NAMES; do
			local on=$(_mesh_get "${name}.online")
			local st=$(_mesh_get "${name}.status")
			if [[ "$on" == "1" && "$st" != "inactive" ]]; then
				local seg=""
				for ((i = 0; i < _MESH_BOX_W; i++)); do seg+="${TH_BORDER_H:-=}"; done
				conn+="${TH_SUCCESS:-$GREEN}${seg}${NC}  "
			else
				local seg=""
				for ((i = 0; i < _MESH_BOX_W; i++)); do seg+="-"; done
				conn+="${GRAY}${seg}${NC}  "
			fi
		done
		echo -e "$conn"
		echo -e "  ${GRAY}${TH_BACKBONE:-MESH BACKBONE}${NC}"
	fi

	rm -rf "$tmpdir" 2>/dev/null

	_render_mesh_footer
	_render_dispatch_arrow
}
