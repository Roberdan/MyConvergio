#!/bin/bash
# F-xx requirement validation functions

# Validate F-xx requirements from plan markdown
cmd_validate_fxx() {
	local plan_id="$1"
	local verified=0
	local pending=0

	echo -e "${BLUE}======= F-xx VALIDATION - Plan $plan_id =======${NC}"
	echo ""

	local plan_file plan_name
	plan_file=$(sqlite3 "$DB_FILE" "SELECT markdown_path FROM plans WHERE id = $plan_id;")
	plan_name=$(sqlite3 "$DB_FILE" "SELECT name FROM plans WHERE id = $plan_id;")

	if [[ -z "$plan_file" || ! -f "$plan_file" ]]; then
		local markdown_dir
		markdown_dir=$(sqlite3 "$DB_FILE" "SELECT markdown_dir FROM plans WHERE id = $plan_id;")
		[[ -z "$markdown_dir" ]] && markdown_dir="$HOME/.claude/plans/active/${plan_name}"
		plan_file=""
		for f in "$markdown_dir/plan.md" "$markdown_dir/${plan_name}.md" "$markdown_dir"/*.md; do
			[[ -f "$f" ]] && {
				plan_file="$f"
				break
			}
		done
	fi

	if [[ -z "$plan_file" || ! -f "$plan_file" ]]; then
		log_error "Plan markdown not found. Set markdown_path: plan-db.sh create ... --markdown-path <file>"
		return 1
	fi

	echo -e "${GREEN}File: $plan_file${NC}"
	echo ""

	while IFS= read -r line; do
		if [[ "$line" =~ \|[[:space:]]*(F-[0-9]+)[[:space:]]*\| ]]; then
			local fxx
			fxx="${BASH_REMATCH[1]}"
			local req_text
			req_text=$(echo "$line" | sed 's/.*F-[0-9]*[[:space:]]*|[[:space:]]*\([^|]*\).*/\1/' | head -c 40)
			if [[ "$line" =~ \[x\] ]] || [[ "$line" =~ \[X\] ]]; then
				echo -e "  ${GREEN}[x]${NC} $fxx - ${req_text}..."
				((verified++))
			elif [[ "$line" =~ \[[[:space:]]*\] ]]; then
				echo -e "  ${RED}[ ]${NC} $fxx - ${req_text}..."
				((pending++))
			fi
		fi
	done <"$plan_file"

	echo ""
	echo -e "Verified: ${GREEN}$verified${NC} | Pending: ${RED}$pending${NC}"
	if [[ $pending -gt 0 ]]; then
		echo -e "${RED}FAILED: $pending not verified${NC}"
		return 1
	fi
	if [[ $verified -eq 0 ]]; then
		echo -e "${YELLOW}WARNING: No F-xx found${NC}"
		return 0
	fi

	echo -e "${GREEN}PASSED: All $verified verified${NC}"
	return 0
}
