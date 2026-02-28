#!/bin/bash
# Interactive dashboard navigation (view stack + digit input)
# Version: 1.1.0

# View state: "main", "completed", "detail"
VIEW_MODE="main"
VIEW_PLAN_ID=""
INPUT_BUF=""

_status_bar() {
	local now
	now=$(date "+%H:%M:%S")
	echo -e "${GRAY}Aggiornato: ${WHITE}$now${NC}"
	case "$VIEW_MODE" in
	main)
		printf "${GRAY}[${WHITE}R${GRAY}]efresh [${WHITE}C${GRAY}]ompletati [${WHITE}Q${GRAY}]uit [${WHITE}P${GRAY}]ush [${WHITE}L${GRAY}]inux ${GRAY}| ${WHITE}<num>${GRAY}+Enter=piano${NC}"
		;;
	completed)
		printf "${GRAY}[${WHITE}B${GRAY}]ack [${WHITE}R${GRAY}]efresh [${WHITE}Q${GRAY}]uit ${GRAY}| ${WHITE}<num>${GRAY}+Enter=piano${NC}"
		;;
	detail)
		printf "${GRAY}[${WHITE}B${GRAY}]ack [${WHITE}R${GRAY}]efresh [${WHITE}Q${GRAY}]uit ${GRAY}| ${WHITE}<num>${GRAY}+Enter=altro piano${NC}"
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
		echo -e "${BOLD}${CYAN}║${NC}          ${BOLD}${WHITE}Piani Completati${NC}                            ${BOLD}${CYAN}║${NC}"
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
	esac
}

_handle_digit_input() {
	local first_digit="$1"
	INPUT_BUF="$first_digit"
	printf "\r${CYAN}Piano #: %s_${NC}%40s" "$INPUT_BUF" " "
	while true; do
		local ch=""
		local rc=0
		read -t 5 -n 1 ch 2>/dev/null || rc=$?
		if [[ $rc -gt 128 ]]; then
			# Timeout (rc=142 on macOS) — cancel input
			INPUT_BUF=""
			return 1
		elif [[ -z "$ch" ]]; then
			# Enter pressed (read returns 0, empty string)
			break
		elif [[ "$ch" =~ ^[0-9]$ ]]; then
			INPUT_BUF+="$ch"
			printf "\r${CYAN}Piano #: %s_${NC}%40s" "$INPUT_BUF" " "
		elif [[ "$ch" == $'\x7f' || "$ch" == $'\b' ]]; then
			if [[ ${#INPUT_BUF} -gt 1 ]]; then
				INPUT_BUF="${INPUT_BUF:0:${#INPUT_BUF}-1}"
			else
				INPUT_BUF=""
				return 1
			fi
			printf "\r${CYAN}Piano #: %s_${NC}%40s" "$INPUT_BUF" " "
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
			printf "\r${RED}Piano #%s non trovato${NC}%40s" "$INPUT_BUF" " "
			sleep 1
			INPUT_BUF=""
			return 1
		fi
	fi
	return 1
}

_run_interactive_loop() {
	# Disable errexit for interactive loop — transient errors must not kill the UI
	set +e
	trap 'echo -e "\n${YELLOW}Dashboard terminata.${NC}"; exit 0' INT
	clear
	while true; do
		_render_current_view
		echo ""
		_status_bar
		echo ""
		key=""
		read -t "$REFRESH_INTERVAL" -n 1 key 2>/dev/null || true
		case "$key" in
		q | Q)
			echo -e "\n${YELLOW}Dashboard terminata.${NC}"
			exit 0
			;;
		b | B)
			if [[ "$VIEW_MODE" == "detail" || "$VIEW_MODE" == "completed" ]]; then
				VIEW_MODE="main"
				VIEW_PLAN_ID=""
			fi
			;;
		c | C)
			[[ "$VIEW_MODE" == "main" ]] && VIEW_MODE="completed"
			;;
		r | R) ;;
		p | P)
			echo ""
			_handle_remote_action "push"
			echo -e "\n${GRAY}Premi un tasto per continuare...${NC}"
			read -n 1 -s
			;;
		l | L)
			echo ""
			_handle_remote_action "status"
			echo -e "\n${GRAY}Premi un tasto per continuare...${NC}"
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
