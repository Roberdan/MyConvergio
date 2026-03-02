#!/bin/bash
# Mesh control center actions — interactive commands from dashboard mesh view
# Version: 1.0.0
# Called from dashboard-navigation.sh when in mesh view mode

CLAUDE_HOME="${CLAUDE_HOME:-$HOME/.claude}"

_mesh_action_migrate() {
	echo ""
	echo -e "${BOLD}${WHITE}━━ MESH MIGRATE ━━${NC}"
	echo -e "${GRAY}Migra un piano attivo su un altro peer${NC}"
	echo ""
	dbq "SELECT id, name, COALESCE(execution_host,'local') FROM plans WHERE status='doing' ORDER BY id" 2>/dev/null | while IFS='|' read -r pid pname phost; do
		echo -e "  ${YELLOW}#${pid}${NC} ${WHITE}${pname}${NC} ${GRAY}(${phost})${NC}"
	done
	echo ""
	echo -ne "${CYAN}Plan ID da migrare (o Enter per annullare): ${NC}"
	local plan_id=""
	read -r plan_id
	[[ -z "$plan_id" ]] && return
	echo ""
	for name in $MESH_PEER_NAMES; do
		local online=$(_mesh_get "${name}.online")
		local role=$(_mesh_get "${name}.role")
		[[ "$role" == "coordinator" ]] && continue
		local status_icon="${RED}○${NC}"
		[[ "$online" == "1" ]] && status_icon="${GREEN}●${NC}"
		echo -e "  ${status_icon} ${WHITE}${name}${NC}"
	done
	echo ""
	echo -ne "${CYAN}Target peer (o Enter per annullare): ${NC}"
	local peer=""
	read -r peer
	[[ -z "$peer" ]] && return
	echo ""
	echo -e "${YELLOW}Eseguendo: mesh-migrate.sh ${plan_id} ${peer}${NC}"
	echo ""
	"$CLAUDE_HOME/scripts/mesh-migrate.sh" "$plan_id" "$peer" 2>&1
}

_mesh_action_sync() {
	echo ""
	echo -e "${BOLD}${WHITE}━━ MESH SYNC ALL ━━${NC}"
	echo -e "${GRAY}Sincronizza config + repos + verifica su tutti i peer${NC}"
	echo ""
	echo -ne "${CYAN}Dry-run prima? [Y/n]: ${NC}"
	local dry=""
	read -n 1 dry
	echo ""
	if [[ "$dry" != "n" && "$dry" != "N" ]]; then
		"$CLAUDE_HOME/scripts/mesh-sync-all.sh" --dry-run 2>&1
		echo ""
		echo -ne "${CYAN}Procedere con sync reale? [y/N]: ${NC}"
		local proceed=""
		read -n 1 proceed
		echo ""
		[[ "$proceed" != "y" && "$proceed" != "Y" ]] && return
	fi
	"$CLAUDE_HOME/scripts/mesh-sync-all.sh" 2>&1
}

_mesh_action_dispatch() {
	echo ""
	echo -e "${BOLD}${WHITE}━━ MESH DISPATCH ━━${NC}"
	echo -e "${GRAY}Dispatcha task pendenti ai peer disponibili${NC}"
	echo ""
	local doing_plans
	doing_plans=$(dbq "SELECT id, name FROM plans WHERE status='doing' ORDER BY id" 2>/dev/null)
	if [[ -z "$doing_plans" ]]; then
		echo -e "${YELLOW}Nessun piano attivo da dispatchare${NC}"
		return
	fi
	echo "$doing_plans" | while IFS='|' read -r pid pname; do
		echo -e "  ${YELLOW}#${pid}${NC} ${WHITE}${pname}${NC}"
	done
	echo ""
	echo -ne "${CYAN}Plan ID (o 'all' per tutti, Enter per annullare): ${NC}"
	local plan_input=""
	read -r plan_input
	[[ -z "$plan_input" ]] && return
	if [[ "$plan_input" == "all" ]]; then
		"$CLAUDE_HOME/scripts/mesh-dispatcher.sh" --all-plans 2>&1
	else
		"$CLAUDE_HOME/scripts/mesh-dispatcher.sh" --plan "$plan_input" 2>&1
	fi
}

_mesh_action_heartbeat() {
	echo ""
	echo -e "${BOLD}${WHITE}━━ MESH HEARTBEAT STATUS ━━${NC}"
	echo ""
	"$CLAUDE_HOME/scripts/mesh-heartbeat.sh" status 2>&1
}

_mesh_action_auth() {
	echo ""
	echo -e "${BOLD}${WHITE}━━ MESH AUTH SYNC ━━${NC}"
	echo ""
	echo -ne "${CYAN}Push a tutti o un peer specifico? [all/nome peer]: ${NC}"
	local target=""
	read -r target
	[[ -z "$target" ]] && return
	if [[ "$target" == "all" ]]; then
		"$CLAUDE_HOME/scripts/mesh-auth-sync.sh" push --all 2>&1
	else
		"$CLAUDE_HOME/scripts/mesh-auth-sync.sh" push --peer "$target" 2>&1
	fi
}

_mesh_action_env() {
	echo ""
	echo -e "${BOLD}${WHITE}━━ MESH ENV SETUP ━━${NC}"
	echo -e "${GRAY}Installa tools + configura un nuovo peer${NC}"
	echo ""
	for name in $MESH_PEER_NAMES; do
		local online=$(_mesh_get "${name}.online")
		local status_icon="${RED}○${NC}"
		[[ "$online" == "1" ]] && status_icon="${GREEN}●${NC}"
		echo -e "  ${status_icon} ${WHITE}${name}${NC}"
	done
	echo ""
	echo -ne "${CYAN}Peer da configurare (Enter per annullare): ${NC}"
	local peer=""
	read -r peer
	[[ -z "$peer" ]] && return
	echo ""
	echo -e "${YELLOW}Eseguendo: mesh-env-setup.sh --full --peer ${peer}${NC}"
	"$CLAUDE_HOME/scripts/mesh-env-setup.sh" --full --peer "$peer" 2>&1
}
