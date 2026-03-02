#!/bin/bash
# Interactive dashboard navigation — view stack, digit input, mesh control center
# Version: 3.0.0

CLAUDE_HOME="${CLAUDE_HOME:-$HOME/.claude}"

# View state: "main" | "completed" | "detail" | "mesh" | "analytics"
VIEW_MODE="main"
VIEW_PLAN_ID=""
INPUT_BUF=""
MESH_REFRESH=10

_status_bar() {
	local now
	now=$(date "+%H:%M:%S")
	echo -e "${GRAY}Updated: ${WHITE}$now${NC} ${GRAY}│ Theme: ${TH_PRIMARY:-$CYAN}${TH_NAME:-classic}${NC}"
	case "$VIEW_MODE" in
	main | completed | detail)
		printf "${GRAY}[${WHITE}R${GRAY}]efresh [${WHITE}C${GRAY}]ompleted [${WHITE}M${GRAY}]esh [${WHITE}A${GRAY}]nalytics [${WHITE}T${GRAY}]heme [${WHITE}W${GRAY}]eb [${WHITE}B${GRAY}]ack [${WHITE}Q${GRAY}]uit [${WHITE}P${GRAY}]ush [${WHITE}L${GRAY}]inux ${GRAY}| ${WHITE}<num>${GRAY}+Enter=plan${NC}"
		;;
	mesh)
		printf "${GRAY}[${WHITE}B${GRAY}]ack [${WHITE}R${GRAY}]efresh [${WHITE}G${GRAY}]migrate [${WHITE}S${GRAY}]ync [${WHITE}D${GRAY}]ispatch [${WHITE}H${GRAY}]eartbeat [${WHITE}A${GRAY}]uth [${WHITE}E${GRAY}]nv [${WHITE}Q${GRAY}]uit${NC}"
		;;
	analytics)
		printf "${GRAY}[${WHITE}B${GRAY}]ack [${WHITE}R${GRAY}]efresh [${WHITE}Q${GRAY}]uit${NC}"
		;;
	esac
}

_render_current_view() {
	quick_sync
	case "$VIEW_MODE" in
	main)
		PLAN_ID=""
		render_dashboard
		;;
	completed)
		echo -e "${BOLD}${CYAN}╔════════════════════════════════════════════════════════════════════╗${NC}"
		echo -e "${BOLD}${CYAN}║${NC}          ${BOLD}${WHITE}Completed Plans${NC}                              ${BOLD}${CYAN}║${NC}"
		echo -e "${BOLD}${CYAN}╚════════════════════════════════════════════════════════════════════╝${NC}"
		echo ""
		EXPAND_COMPLETED=0
		_render_completed_plans
		echo ""
		;;
	detail)
		PLAN_ID="$VIEW_PLAN_ID"
		EXPAND_COMPLETED=1
		_render_single_plan
		;;
	mesh)
		_mesh_collect_data
		_render_mesh_detail
		;;
	analytics)
		_render_token_analytics 2>/dev/null || {
			echo -e "${YELLOW}Token analytics not available yet (requires dashboard-render-tokens.sh).${NC}"
		}
		;;
	esac
}

# Theme cycling: uses dynamic THEME_LIST from dashboard-themes.sh
_cycle_theme() {
	local current="${DASHBOARD_THEME:-neon_grid}"
	local next="${THEME_LIST[0]:-neon_grid}" found=0
	local i
	for ((i = 0; i < ${#THEME_LIST[@]}; i++)); do
		if [[ "${THEME_LIST[$i]}" == "$current" ]]; then
			next="${THEME_LIST[$(((i + 1) % ${#THEME_LIST[@]}))]}"
			found=1
			break
		fi
	done
	[[ $found -eq 0 ]] && next="${THEME_LIST[0]:-neon_grid}"
	DASHBOARD_THEME="$next"
	_theme_load "$DASHBOARD_THEME"
	_theme_save "$DASHBOARD_THEME"
}

_handle_digit_input() {
	local first_digit="$1"
	INPUT_BUF="$first_digit"
	printf "\r${CYAN}Plan #: %s_${NC}%40s" "$INPUT_BUF" " "
	while true; do
		local ch="" rc=0
		read -t 5 -n 1 ch 2>/dev/null || rc=$?
		if [[ $rc -gt 128 ]]; then
			INPUT_BUF=""
			return 1
		elif [[ -z "$ch" ]]; then
			break
		elif [[ "$ch" =~ ^[0-9]$ ]]; then
			INPUT_BUF+="$ch"
			printf "\r${CYAN}Plan #: %s_${NC}%40s" "$INPUT_BUF" " "
		elif [[ "$ch" == $'\x7f' || "$ch" == $'\b' ]]; then
			if [[ ${#INPUT_BUF} -gt 1 ]]; then
				INPUT_BUF="${INPUT_BUF:0:${#INPUT_BUF}-1}"
			else
				INPUT_BUF=""
				return 1
			fi
			printf "\r${CYAN}Plan #: %s_${NC}%40s" "$INPUT_BUF" " "
		elif [[ "$ch" == $'\x1b' ]]; then
			INPUT_BUF=""
			return 1
		fi
	done
	if [[ -n "$INPUT_BUF" ]]; then
		local exists
		exists=$(dbq "SELECT COUNT(*) FROM plans WHERE id = $INPUT_BUF;" 2>/dev/null || echo "0")
		if [[ "$exists" -gt 0 ]]; then
			VIEW_PLAN_ID="$INPUT_BUF"
			VIEW_MODE="detail"
			return 0
		else
			printf "\r${RED}Plan #%s not found${NC}%40s" "$INPUT_BUF" " "
			sleep 1
			INPUT_BUF=""
			return 1
		fi
	fi
	return 1
}

_run_interactive_loop() {
	set +e
	trap 'echo -e "\n${YELLOW}Dashboard closed.${NC}"; exit 0' INT
	clear
	while true; do
		_render_current_view
		echo ""
		_status_bar
		echo ""
		local key="" timeout="$REFRESH_INTERVAL"
		[[ "$VIEW_MODE" == "mesh" ]] && timeout="$MESH_REFRESH"
		read -t "$timeout" -n 1 key 2>/dev/null || true
		case "$key" in
		q | Q)
			echo -e "\n${YELLOW}Dashboard closed.${NC}"
			exit 0
			;;
		b | B)
			if [[ "$VIEW_MODE" != "main" ]]; then
				VIEW_MODE="main"
				VIEW_PLAN_ID=""
			fi
			;;
		c | C)
			[[ "$VIEW_MODE" == "main" ]] && VIEW_MODE="completed"
			;;
		m | M)
			[[ "$VIEW_MODE" == "main" ]] && VIEW_MODE="mesh"
			;;
		a | A)
			if [[ "$VIEW_MODE" == "mesh" ]]; then
				_mesh_action_auth
				echo -e "\n${GRAY}Press any key to continue...${NC}"
				read -n 1 -s
			elif [[ "$VIEW_MODE" == "main" || "$VIEW_MODE" == "completed" || "$VIEW_MODE" == "detail" ]]; then
				VIEW_MODE="analytics"
			fi
			;;
		t | T)
			_cycle_theme
			;;
		w | W)
			local scripts_dir
			scripts_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
			open "http://localhost:8420"
			exec /opt/homebrew/bin/python3 "$scripts_dir/dashboard_web/server.py" --port 8420
			;;
		r | R) ;;
		g | G)
			if [[ "$VIEW_MODE" == "mesh" ]]; then
				_mesh_action_migrate
				echo -e "\n${GRAY}Press any key to continue...${NC}"
				read -n 1 -s
			fi
			;;
		s | S)
			if [[ "$VIEW_MODE" == "mesh" ]]; then
				_mesh_action_sync
				echo -e "\n${GRAY}Press any key to continue...${NC}"
				read -n 1 -s
			fi
			;;
		d | D)
			if [[ "$VIEW_MODE" == "mesh" ]]; then
				_mesh_action_dispatch
				echo -e "\n${GRAY}Press any key to continue...${NC}"
				read -n 1 -s
			fi
			;;
		h | H)
			if [[ "$VIEW_MODE" == "mesh" ]]; then
				_mesh_action_heartbeat
				echo -e "\n${GRAY}Press any key to continue...${NC}"
				read -n 1 -s
			fi
			;;
		e | E)
			if [[ "$VIEW_MODE" == "mesh" ]]; then
				_mesh_action_env
				echo -e "\n${GRAY}Press any key to continue...${NC}"
				read -n 1 -s
			fi
			;;
		p | P)
			echo ""
			_handle_remote_action "push"
			echo -e "\n${GRAY}Press any key to continue...${NC}"
			read -n 1 -s
			;;
		l | L)
			echo ""
			_handle_remote_action "status"
			echo -e "\n${GRAY}Press any key to continue...${NC}"
			read -n 1 -s
			;;
		[0-9])
			_handle_digit_input "$key" || true
			;;
		"") ;;
		esac
		clear
	done
}
