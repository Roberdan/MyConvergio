#!/bin/bash
# Plan DB Validation - Thor validation functions
# Sourced by plan-db.sh

# Thor validates plan - ACTUAL validation checks
# Version: 1.4.0

# Validate a single task by DB id or task_id within a plan
# Usage: validate-task <task_db_id_or_task_id> [plan_id] [validated_by] [--force] [--report 'JSON']
# Sets validated_at + validated_by + validation_report on the task
cmd_validate_task() {
	local identifier="$1"
	local plan_id="${2:-}"
	local validated_by="${3:-thor}"
	local force=false
	local report=""

	# Check for flags in any argument position
	local skip_next=false
	for i in "$@"; do
		if [[ "$skip_next" == true ]]; then
			skip_next=false
			continue
		fi
		case "$i" in
		--force) force=true ;;
		--report)
			skip_next=true
			;;
		esac
	done
	# Extract --report value
	local prev=""
	for arg in "$@"; do
		if [[ "$prev" == "--report" ]]; then
			report="$arg"
		fi
		prev="$arg"
	done

	local task_db_id=""

	# If numeric, try as DB id first
	if [[ "$identifier" =~ ^[0-9]+$ ]]; then
		task_db_id=$(sqlite3 "$DB_FILE" "SELECT id FROM tasks WHERE id = $identifier;" 2>/dev/null || echo "")
	fi

	# If not found or non-numeric, try as task_id within plan
	if [[ -z "$task_db_id" && -n "$plan_id" ]]; then
		task_db_id=$(sqlite3 "$DB_FILE" "SELECT id FROM tasks WHERE task_id = '$(sql_escape "$identifier")' AND plan_id = $plan_id;" 2>/dev/null || echo "")
	fi

	if [[ -z "$task_db_id" ]]; then
		log_error "Task not found: $identifier (plan: ${plan_id:-any})"
		return 1
	fi

	# Verify task is done before validating
	local task_status
	task_status=$(sqlite3 "$DB_FILE" "SELECT status FROM tasks WHERE id = $task_db_id;")
	if [[ "$task_status" != "done" ]]; then
		log_error "Task $identifier status is '$task_status' — only 'done' tasks can be validated"
		return 1
	fi

	# Check if already validated
	local already_validated
	already_validated=$(sqlite3 "$DB_FILE" "SELECT validated_at FROM tasks WHERE id = $task_db_id;")
	if [[ -n "$already_validated" ]]; then
		echo -e "${YELLOW}Task $identifier already validated at $already_validated${NC}"
		return 0
	fi

	# Enforce Thor agent requirement unless --force is used
	if [[ "$force" == false ]]; then
		if [[ "$validated_by" != "thor" && "$validated_by" != "thor-quality-assurance-guardian" ]]; then
			log_warn "Validator '$validated_by' is not a Thor agent. Use --force to validate without Thor agent verification."
			return 1
		fi
	else
		# Log warning if --force is used
		if [[ "$validated_by" != "thor" && "$validated_by" != "thor-quality-assurance-guardian" ]]; then
			log_warn "Task validated with --force (no Thor agent verification)"
		fi
	fi

	# Build UPDATE with optional validation_report
	local report_clause=""
	if [[ -n "$report" ]]; then
		report_clause=", validation_report = '$(sql_escape "$report")'"
	fi
	sqlite3 "$DB_FILE" "UPDATE tasks SET validated_at = datetime('now'), validated_by = '$(sql_escape "$validated_by")'${report_clause} WHERE id = $task_db_id;"

	local task_id_text
	task_id_text=$(sqlite3 "$DB_FILE" "SELECT task_id FROM tasks WHERE id = $task_db_id;")
	echo -e "${GREEN}Task $task_id_text validated by $validated_by${NC}"
	[[ -n "$report" ]] && echo -e "${GREEN}  Validation report saved ($(echo "$report" | grep -c . || echo 0) lines)${NC}"
	return 0
}

# Validate all done tasks in a wave
# Usage: validate-wave <wave_db_id> [validated_by]
cmd_validate_wave() {
	local wave_db_id="$1"
	local validated_by="${2:-thor}"

	local wave_info
	wave_info=$(sqlite3 -separator '|' "$DB_FILE" "SELECT wave_id, plan_id, tasks_done, tasks_total FROM waves WHERE id = $wave_db_id;")
	if [[ -z "$wave_info" ]]; then
		log_error "Wave not found: $wave_db_id"
		return 1
	fi

	local wave_id plan_id tasks_done tasks_total
	IFS='|' read -r wave_id plan_id tasks_done tasks_total <<<"$wave_info"

	# Check all tasks in wave are done
	local not_done
	not_done=$(sqlite3 "$DB_FILE" "SELECT COUNT(*) FROM tasks WHERE wave_id_fk = $wave_db_id AND status <> 'done';")
	if [[ "$not_done" -gt 0 ]]; then
		log_error "Wave $wave_id has $not_done tasks not yet done — cannot validate"
		return 1
	fi

	# Check if all done tasks have been validated by Thor
	local not_validated
	not_validated=$(sqlite3 "$DB_FILE" "SELECT COUNT(*) FROM tasks WHERE wave_id_fk = $wave_db_id AND status = 'done' AND validated_at IS NULL;")
	if [[ "$not_validated" -gt 0 ]]; then
		log_error "Wave $wave_id has $not_validated done tasks NOT validated by Thor — run per-task validation first"
		# List the unvalidated tasks
		sqlite3 "$DB_FILE" "SELECT task_id, title FROM tasks WHERE wave_id_fk = $wave_db_id AND status = 'done' AND validated_at IS NULL;" | while IFS='|' read -r tid title; do
			echo "  - $tid: $title"
		done
		return 1
	fi

	# All tasks already validated - mark wave as done
	echo -e "${YELLOW}Wave $wave_id: all tasks already validated${NC}"

	# Mark wave as validated
	sqlite3 "$DB_FILE" "UPDATE waves SET status = 'done', completed_at = COALESCE(completed_at, datetime('now')) WHERE id = $wave_db_id;"

	return 0
}

cmd_validate() {
	local plan_id="$1"
	local validated_by="${2:-thor}"
	local errors=0
	local warnings=0

	echo -e "${BLUE}======= THOR VALIDATION - Plan $plan_id =======${NC}"
	echo ""

	local project_id=$(sqlite3 "$DB_FILE" "SELECT project_id FROM plans WHERE id = $plan_id;")

	# Check 1: Counter sync - waves
	echo -e "${YELLOW}[1/7] Wave counter sync...${NC}"
	local wave_issues=$(sqlite3 "$DB_FILE" "
        SELECT w.wave_id, w.tasks_done, w.tasks_total,
               (SELECT COUNT(*) FROM tasks t WHERE t.wave_id_fk = w.id AND t.status = 'done') as actual_done,
               (SELECT COUNT(*) FROM tasks t WHERE t.wave_id_fk = w.id) as actual_total
        FROM waves w WHERE w.plan_id = $plan_id
        AND (w.tasks_done != (SELECT COUNT(*) FROM tasks t WHERE t.wave_id_fk = w.id AND t.status = 'done')
             OR w.tasks_total != (SELECT COUNT(*) FROM tasks t WHERE t.wave_id_fk = w.id));
    ")
	if [ -n "$wave_issues" ]; then
		echo -e "${RED}  ERROR: Wave counters out of sync${NC}"
		echo "$wave_issues"
		((errors++))
	else
		echo -e "${GREEN}  OK${NC}"
	fi

	# Check 2: Orphan tasks
	echo -e "${YELLOW}[2/7] Orphan tasks...${NC}"
	local orphans=$(sqlite3 "$DB_FILE" "
        SELECT t.id, t.task_id, t.wave_id FROM tasks t
        WHERE t.plan_id = $plan_id
        AND NOT EXISTS (SELECT 1 FROM waves w WHERE w.id = t.wave_id_fk);
    ")
	if [ -n "$orphans" ]; then
		echo -e "${RED}  ERROR: Orphan tasks found${NC}"
		echo "$orphans"
		((errors++))
	else
		echo -e "${GREEN}  OK${NC}"
	fi

	# Check 3: Incomplete tasks in done waves
	echo -e "${YELLOW}[3/7] Incomplete in done waves...${NC}"
	local incomplete=$(sqlite3 "$DB_FILE" "
        SELECT w.wave_id, t.task_id, t.status FROM tasks t
        JOIN waves w ON t.wave_id_fk = w.id
        WHERE w.plan_id = $plan_id AND w.status = 'done' AND t.status != 'done';
    ")
	if [ -n "$incomplete" ]; then
		echo -e "${RED}  ERROR: Incomplete tasks in done waves${NC}"
		echo "$incomplete"
		((errors++))
	else
		echo -e "${GREEN}  OK${NC}"
	fi

	# Check 4: Plan counter sync
	echo -e "${YELLOW}[4/7] Plan counter sync...${NC}"
	local plan_totals=$(sqlite3 "$DB_FILE" "
        SELECT p.tasks_done, p.tasks_total,
               (SELECT COALESCE(SUM(tasks_done), 0) FROM waves WHERE plan_id = p.id) as actual_done,
               (SELECT COALESCE(SUM(tasks_total), 0) FROM waves WHERE plan_id = p.id) as actual_total
        FROM plans p WHERE p.id = $plan_id
        AND (p.tasks_done != (SELECT COALESCE(SUM(tasks_done), 0) FROM waves WHERE plan_id = p.id)
             OR p.tasks_total != (SELECT COALESCE(SUM(tasks_total), 0) FROM waves WHERE plan_id = p.id));
    ")
	if [ -n "$plan_totals" ]; then
		echo -e "${RED}  ERROR: Plan counters out of sync${NC}"
		((errors++))
	else
		echo -e "${GREEN}  OK${NC}"
	fi

	# Check 5: Date consistency
	echo -e "${YELLOW}[5/7] Date consistency...${NC}"
	local bad_dates=$(sqlite3 "$DB_FILE" "
        SELECT wave_id FROM waves WHERE plan_id = $plan_id AND planned_end < planned_start;
    ")
	if [ -n "$bad_dates" ]; then
		echo -e "${YELLOW}  WARNING: Waves with end < start${NC}"
		((warnings++))
	else
		echo -e "${GREEN}  OK${NC}"
	fi

	# Check 6: executor_agent presence for done tasks
	echo -e "${YELLOW}[6/7] Executor agent tracking...${NC}"
	local missing_agent=$(sqlite3 "$DB_FILE" "
	    SELECT COUNT(*) FROM tasks t
	    JOIN waves w ON t.wave_id_fk = w.id
	    WHERE w.plan_id = $plan_id AND t.status = 'done' AND (t.executor_agent IS NULL OR t.executor_agent = '');
	")
	if [ "$missing_agent" -gt 0 ]; then
		echo -e "${YELLOW}  WARNING: $missing_agent done tasks missing executor_agent${NC}"
		((warnings++))
	else
		echo -e "${GREEN}  OK${NC}"
	fi

	# Check 7: output_data JSON validity
	echo -e "${YELLOW}[7/7] Output data JSON validity...${NC}"
	local invalid_json=0
	local tasks_with_output
	tasks_with_output=$(sqlite3 "$DB_FILE" "
	    SELECT t.task_id, t.output_data FROM tasks t
	    JOIN waves w ON t.wave_id_fk = w.id
	    WHERE w.plan_id = $plan_id AND t.output_data IS NOT NULL AND t.output_data != '';
	")
	while IFS='|' read -r tid output; do
		[[ -z "$tid" ]] && continue
		if ! echo "$output" | jq -e . >/dev/null 2>&1; then
			echo -e "${RED}  ERROR: Task $tid has invalid JSON in output_data${NC}"
			((invalid_json++))
		fi
	done <<<"$tasks_with_output"
	if [ "$invalid_json" -gt 0 ]; then
		echo -e "${RED}  ERROR: $invalid_json tasks with invalid output_data JSON${NC}"
		((errors++))
	else
		echo -e "${GREEN}  OK${NC}"
	fi

	echo ""
	if [ $errors -gt 0 ]; then
		echo -e "${RED}FAILED: $errors errors, $warnings warnings${NC}"
		echo -e "${YELLOW}Run 'plan-db.sh sync $plan_id' to fix${NC}"
		return 1
	fi

	sqlite3 "$DB_FILE" "UPDATE plans SET validated_at = datetime('now'), validated_by = '$validated_by' WHERE id = $plan_id;"

	# Check for unvalidated done tasks — refuse to bulk-validate them (must use per-task Thor)
	local unvalidated_count=$(sqlite3 "$DB_FILE" "
        SELECT COUNT(*) FROM tasks t
        JOIN waves w ON t.wave_id_fk = w.id
        WHERE w.plan_id = $plan_id AND t.status = 'done' AND t.validated_at IS NULL;
    ")
	if [ "$unvalidated_count" -gt 0 ]; then
		log_warn "$unvalidated_count done tasks lack per-task Thor validation — run validate-task for each"
		sqlite3 "$DB_FILE" "
            SELECT t.task_id, t.title FROM tasks t
            JOIN waves w ON t.wave_id_fk = w.id
            WHERE w.plan_id = $plan_id AND t.status = 'done' AND t.validated_at IS NULL;
        " | while IFS='|' read -r tid title; do
			echo "  - $tid: $title"
		done
	fi

	# Bulk task validation removed (was a bypass hole)
	# Tasks must be validated individually via validate-task

	local version=$(sqlite3 "$DB_FILE" "SELECT COALESCE(MAX(version), 0) + 1 FROM plan_versions WHERE plan_id = $plan_id;")
	sqlite3 "$DB_FILE" "
        INSERT INTO plan_versions (plan_id, version, change_type, change_reason, changed_by, changed_host)
        VALUES ($plan_id, $version, 'validated', 'Validated - 0 errors', '$validated_by', '${PLAN_DB_HOST:-unknown}');
    "
	echo -e "${GREEN}PASSED: Plan $plan_id validated by $validated_by (host: ${PLAN_DB_HOST:-unknown})${NC}"

	# Auto-close plan if all tasks are done
	local tasks_done tasks_total current_status
	IFS='|' read -r tasks_done tasks_total current_status < <(sqlite3 "$DB_FILE" "SELECT tasks_done, tasks_total, status FROM plans WHERE id = $plan_id;")

	if [[ "$tasks_total" -gt 0 && "$tasks_done" -eq "$tasks_total" && "$current_status" != "done" ]]; then
		sqlite3 "$DB_FILE" "UPDATE plans SET status = 'done', completed_at = datetime('now'), execution_host = '${PLAN_DB_HOST:-unknown}' WHERE id = $plan_id;"
		echo -e "${GREEN}AUTO-CLOSE: Plan $plan_id marked as done (all $tasks_total tasks complete)${NC}"

		# Record auto-close in version history
		local close_version=$(sqlite3 "$DB_FILE" "SELECT COALESCE(MAX(version), 0) + 1 FROM plan_versions WHERE plan_id = $plan_id;")
		sqlite3 "$DB_FILE" "
            INSERT INTO plan_versions (plan_id, version, change_type, change_reason, changed_by, changed_host)
            VALUES ($plan_id, $close_version, 'completed', 'Auto-closed after Thor validation', '$validated_by', '${PLAN_DB_HOST:-unknown}');
        "
	fi

	return 0
}

# Validate F-xx requirements from plan markdown
cmd_validate_fxx() {
	local plan_id="$1"
	local verified=0
	local pending=0

	echo -e "${BLUE}======= F-xx VALIDATION - Plan $plan_id =======${NC}"
	echo ""

	# Try markdown_path first (exact file), fallback to markdown_dir search
	local plan_file=$(sqlite3 "$DB_FILE" "SELECT markdown_path FROM plans WHERE id = $plan_id;")
	local plan_name=$(sqlite3 "$DB_FILE" "SELECT name FROM plans WHERE id = $plan_id;")

	if [[ -z "$plan_file" || ! -f "$plan_file" ]]; then
		local markdown_dir=$(sqlite3 "$DB_FILE" "SELECT markdown_dir FROM plans WHERE id = $plan_id;")
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
			local fxx="${BASH_REMATCH[1]}"
			local req_text=$(echo "$line" | sed 's/.*F-[0-9]*[[:space:]]*|[[:space:]]*\([^|]*\).*/\1/' | head -c 40)

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

	[[ $pending -gt 0 ]] && {
		echo -e "${RED}FAILED: $pending not verified${NC}"
		return 1
	}
	[[ $verified -eq 0 ]] && {
		echo -e "${YELLOW}WARNING: No F-xx found${NC}"
		return 0
	}

	echo -e "${GREEN}PASSED: All $verified verified${NC}"
	return 0
}

# Detect cycles in wave dependency graph (DFS 3-color)
# Usage: detect_precondition_cycles <plan_id>
# Returns 0 if no cycles, 1 if cycle found (prints path to stderr)
detect_precondition_cycles() {
	local plan_id="$1"

	# Query all waves for this plan
	local wave_data
	wave_data=$(sqlite3 "$DB_FILE" \
		"SELECT wave_id, COALESCE(depends_on,''), COALESCE(precondition,'') FROM waves WHERE plan_id = $plan_id ORDER BY position;" \
		2>/dev/null) || true

	# Nothing to check
	[[ -z "$wave_data" ]] && return 0

	# Build adjacency list using temp files (portable across
	# bash versions; avoids associative array edge cases)
	local tmpdir
	tmpdir=$(mktemp -d /tmp/cycle-detect-XXXXXX)
	trap "rm -rf '$tmpdir'" EXIT INT TERM

	# Collect all wave_ids
	local -a all_waves=()
	while IFS='|' read -r wid depends_on precondition; do
		all_waves+=("$wid")
		local adj_file="$tmpdir/adj_${wid}"
		touch "$adj_file"

		# Source 1: depends_on field (comma-separated wave_ids)
		if [[ -n "$depends_on" ]]; then
			local dep
			for dep in $(echo "$depends_on" | tr ',' ' '); do
				dep=$(echo "$dep" | xargs) # trim whitespace
				[[ -n "$dep" ]] && echo "$dep" >>"$adj_file"
			done
		fi

		# Source 2: precondition JSON - extract wave_id refs
		if [[ -n "$precondition" && "$precondition" != "null" ]]; then
			local json_deps
			json_deps=$(echo "$precondition" |
				jq -r '.[].wave_id // empty' 2>/dev/null) || true
			if [[ -n "$json_deps" ]]; then
				echo "$json_deps" >>"$adj_file"
			fi
		fi

		# Deduplicate adjacency entries
		if [[ -s "$adj_file" ]]; then
			sort -u "$adj_file" -o "$adj_file"
		fi
	done <<<"$wave_data"

	# DFS 3-color: white=0, gray=1, black=2
	for wid in "${all_waves[@]}"; do
		echo "0" >"$tmpdir/color_${wid}"
	done

	echo "0" >"$tmpdir/result"

	# Recursive DFS visit
	_dfs_visit() {
		local node="$1"
		local color_file="$tmpdir/color_${node}"

		# Skip if wave_id is referenced but not in this plan
		[[ ! -f "$color_file" ]] && return 0

		local color
		color=$(<"$color_file")

		# Already fully processed
		[[ "$color" == "2" ]] && return 0

		# Gray = back edge = cycle
		if [[ "$color" == "1" ]]; then
			local cycle_path=""
			if [[ -f "$tmpdir/path" ]]; then
				local in_cycle=0
				while IFS= read -r p; do
					if [[ "$p" == "$node" ]]; then
						in_cycle=1
					fi
					if [[ $in_cycle -eq 1 ]]; then
						[[ -n "$cycle_path" ]] && cycle_path="${cycle_path} -> "
						cycle_path="${cycle_path}${p}"
					fi
				done <"$tmpdir/path"
				cycle_path="${cycle_path} -> ${node}"
			else
				cycle_path="${node} -> ${node}"
			fi
			echo "CYCLE DETECTED: $cycle_path" >&2
			echo "1" >"$tmpdir/result"
			return 1
		fi

		# Mark gray (in progress)
		echo "1" >"$color_file"
		echo "$node" >>"$tmpdir/path"

		# Visit all neighbors
		local adj_file="$tmpdir/adj_${node}"
		if [[ -f "$adj_file" && -s "$adj_file" ]]; then
			while IFS= read -r neighbor; do
				[[ -z "$neighbor" ]] && continue
				if ! _dfs_visit "$neighbor"; then
					return 1
				fi
			done <"$adj_file"
		fi

		# Mark black (done)
		echo "2" >"$color_file"

		# Remove node from path stack
		if [[ -f "$tmpdir/path" ]]; then
			local new_path
			new_path=$(grep -v "^${node}$" "$tmpdir/path" 2>/dev/null) || true
			echo "$new_path" >"$tmpdir/path"
		fi

		return 0
	}

	# Run DFS from each unvisited node
	for wid in "${all_waves[@]}"; do
		local color
		color=$(<"$tmpdir/color_${wid}")
		if [[ "$color" == "0" ]]; then
			>"$tmpdir/path"
			if ! _dfs_visit "$wid"; then
				return 1
			fi
		fi
	done

	return 0
}

# Check plan readiness for execution (BLOCKS if metadata missing)
cmd_check_readiness() {
	local plan_id="$1"
	local errors=0
	echo -e "${BLUE}======= READINESS CHECK - Plan $plan_id =======${NC}"

	# Check 0: Cycle detection in preconditions
	echo -e "${YELLOW}[0/N] Precondition cycle detection...${NC}"
	if ! detect_precondition_cycles "$plan_id"; then
		echo -e "${RED}  FAIL: Circular dependencies in wave preconditions${NC}"
		errors=$((errors + 1))
	else
		echo -e "${GREEN}  OK: No cycles${NC}"
	fi

	local src=$(sqlite3 "$DB_FILE" "SELECT source_file FROM plans WHERE id=$plan_id;")
	local wt=$(sqlite3 "$DB_FILE" "SELECT worktree_path FROM plans WHERE id=$plan_id;")
	if [[ -z "$src" ]]; then
		echo -e "${RED}  FAIL: source_file not set${NC}"
		errors=$((errors + 1))
	else echo -e "${GREEN}  OK: source_file${NC}"; fi
	local wave_wt_count=$(sqlite3 "$DB_FILE" "SELECT COUNT(*) FROM waves WHERE plan_id=$plan_id AND worktree_path IS NOT NULL AND worktree_path <> '';" 2>/dev/null || echo "0")
	if [[ -z "$wt" && "$wave_wt_count" -eq 0 ]]; then
		echo -e "${RED}  FAIL: No worktree set (plan-level or wave-level). Use wave-worktree.sh create or --auto-worktree${NC}"
		errors=$((errors + 1))
	elif [[ -n "$wt" ]]; then
		echo -e "${GREEN}  OK: plan worktree_path ($wt)${NC}"
	else
		echo -e "${GREEN}  OK: wave-level worktrees ($wave_wt_count waves with worktree)${NC}"
	fi
	local no_desc=$(sqlite3 "$DB_FILE" "SELECT COUNT(*) FROM tasks WHERE plan_id=$plan_id AND status='pending' AND (description IS NULL OR description='');")
	local no_tc=$(sqlite3 "$DB_FILE" "SELECT COUNT(*) FROM tasks WHERE plan_id=$plan_id AND status='pending' AND (test_criteria IS NULL OR test_criteria='');")
	if [[ "$no_desc" -gt 0 ]]; then
		echo -e "${RED}  FAIL: $no_desc tasks missing description${NC}"
		errors=$((errors + 1))
	else echo -e "${GREEN}  OK: all tasks have description${NC}"; fi
	if [[ "$no_tc" -gt 0 ]]; then
		echo -e "${RED}  FAIL: $no_tc tasks missing test_criteria${NC}"
		errors=$((errors + 1))
	else echo -e "${GREEN}  OK: all tasks have test_criteria${NC}"; fi
	[[ $errors -gt 0 ]] && {
		echo -e "${RED}BLOCKED: $errors issues. Fix before /execute.${NC}"
		return 1
	}
	echo -e "${GREEN}READY: Plan $plan_id is ready for execution${NC}"
	return 0
}

# Sync counters
cmd_sync() {
	local plan_id="$1"
	log_info "Syncing counters for plan $plan_id..."

	sqlite3 "$DB_FILE" "
        UPDATE waves SET
            tasks_done = (SELECT COUNT(*) FROM tasks WHERE tasks.wave_id_fk = waves.id AND tasks.status = 'done'),
            tasks_total = (SELECT COUNT(*) FROM tasks WHERE tasks.wave_id_fk = waves.id)
        WHERE plan_id = $plan_id;
    "
	sqlite3 "$DB_FILE" "
        UPDATE waves SET status = 'done', completed_at = COALESCE(completed_at, datetime('now'))
        WHERE plan_id = $plan_id AND tasks_done = tasks_total AND tasks_total > 0 AND status NOT IN ('done', 'merging');
    "
	sqlite3 "$DB_FILE" "
        UPDATE plans SET
            tasks_done = (SELECT COALESCE(SUM(tasks_done), 0) FROM waves WHERE waves.plan_id = plans.id),
            tasks_total = (SELECT COALESCE(SUM(tasks_total), 0) FROM waves WHERE waves.plan_id = plans.id)
        WHERE id = $plan_id;
    "

	sqlite3 -header -column "$DB_FILE" "
        SELECT wave_id, name, status, tasks_done || '/' || tasks_total as progress
        FROM waves WHERE plan_id = $plan_id ORDER BY position;
    "
	log_info "Sync complete"
}

# Evaluate wave preconditions - returns READY, SKIP, or BLOCKED
# Usage: cmd_evaluate_wave <wave_db_id>
# Output: JSON to stdout
cmd_evaluate_wave() {
	local wave_db_id="$1"

	# Get wave metadata
	local wave_row
	wave_row=$(sqlite3 "$DB_FILE" \
		"SELECT plan_id, wave_id, precondition FROM waves WHERE id = $wave_db_id;")
	if [[ -z "$wave_row" ]]; then
		echo '{"result":"BLOCKED","wave_id":"?","details":[{"error":"wave not found"}]}'
		return 1
	fi

	local plan_id wave_id precondition
	plan_id=$(echo "$wave_row" | cut -d'|' -f1)
	wave_id=$(echo "$wave_row" | cut -d'|' -f2)
	precondition=$(echo "$wave_row" | cut -d'|' -f3-)

	# No precondition = always READY
	if [[ -z "$precondition" || "$precondition" == "null" ]]; then
		echo "{\"result\":\"READY\",\"wave_id\":\"$wave_id\",\"details\":[]}"
		return 0
	fi

	# Validate JSON
	if ! echo "$precondition" | jq -e '.' >/dev/null 2>&1; then
		echo "{\"result\":\"BLOCKED\",\"wave_id\":\"$wave_id\",\"details\":[{\"error\":\"invalid precondition JSON\"}]}"
		return 1
	fi

	local cond_count
	cond_count=$(echo "$precondition" | jq 'length')
	local details="[]"
	local final_result="READY"

	for ((i = 0; i < cond_count; i++)); do
		local cond cond_type met="false"
		cond=$(echo "$precondition" | jq -c ".[$i]")
		cond_type=$(echo "$cond" | jq -r '.type')

		case "$cond_type" in
		wave_status)
			local target_wave_id target_status actual_status
			target_wave_id=$(echo "$cond" | jq -r '.wave_id')
			target_status=$(echo "$cond" | jq -r '.status')
			actual_status=$(sqlite3 "$DB_FILE" \
				"SELECT status FROM waves WHERE plan_id = $plan_id AND wave_id = '$target_wave_id';")
			if [[ "$actual_status" == "$target_status" ]]; then
				met="true"
			else
				if [[ "$final_result" != "SKIP" ]]; then final_result="BLOCKED"; fi
			fi
			;;
		output_match)
			local task_id output_path equals_val actual_data extracted
			task_id=$(echo "$cond" | jq -r '.task_id')
			output_path=$(echo "$cond" | jq -r '.output_path')
			equals_val=$(echo "$cond" | jq -r '.equals')
			actual_data=$(sqlite3 "$DB_FILE" \
				"SELECT output_data FROM tasks WHERE plan_id = $plan_id AND task_id = '$task_id';")
			if [[ -n "$actual_data" ]]; then
				extracted=$(echo "$actual_data" | jq -r "$output_path" 2>/dev/null || echo "")
				if [[ "$extracted" == "$equals_val" ]]; then
					met="true"
				else
					if [[ "$final_result" != "SKIP" ]]; then final_result="BLOCKED"; fi
				fi
			else
				if [[ "$final_result" != "SKIP" ]]; then final_result="BLOCKED"; fi
			fi
			;;
		skip_if)
			local task_id output_path equals_val actual_data extracted
			task_id=$(echo "$cond" | jq -r '.task_id')
			output_path=$(echo "$cond" | jq -r '.output_path')
			equals_val=$(echo "$cond" | jq -r '.equals')
			actual_data=$(sqlite3 "$DB_FILE" \
				"SELECT output_data FROM tasks WHERE plan_id = $plan_id AND task_id = '$task_id';")
			if [[ -n "$actual_data" ]]; then
				extracted=$(echo "$actual_data" | jq -r "$output_path" 2>/dev/null || echo "")
				if [[ "$extracted" == "$equals_val" ]]; then
					met="true"
					final_result="SKIP"
				fi
			fi
			# skip_if not met is fine - does not block
			;;
		*)
			if [[ "$final_result" != "SKIP" ]]; then final_result="BLOCKED"; fi
			;;
		esac

		details=$(echo "$details" | jq \
			--argjson cond "$cond" \
			--argjson met "$met" \
			'. + [{"condition": $cond, "met": $met}]')
	done

	echo "$details" | jq -c \
		--arg result "$final_result" \
		--arg wave_id "$wave_id" \
		'{"result": $result, "wave_id": $wave_id, "details": .}'
	return 0
}
