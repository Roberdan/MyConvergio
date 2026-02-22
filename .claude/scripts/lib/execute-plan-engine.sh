#!/bin/bash
# execute-plan-engine.sh - Task execution and validation logic
# Extracted from execute-plan.sh for modularization
# Version: 1.0.0

# ============================================================================
# DB helpers
# ============================================================================
get_waves() {
	db_query "$DB_FILE" "SELECT id, wave_id, name, status FROM waves WHERE plan_id=$PLAN_ID ORDER BY id;"
}

get_wave_tasks() {
	local wave_db_id="$1"
	db_query "$DB_FILE" "SELECT id, task_id, status, title FROM tasks
		WHERE wave_id_fk=$wave_db_id
		ORDER BY id;"
}

# ============================================================================
# Generate task prompt for execution
# ============================================================================
build_task_prompt() {
	local task_db_id="$1"
	# Use existing prompt generator if available
	if [[ -x "${SCRIPT_DIR}/copilot-task-prompt.sh" ]]; then
		"${SCRIPT_DIR}/copilot-task-prompt.sh" "$task_db_id" 2>/dev/null
	else
		# Fallback: query DB directly
		db_query "$DB_FILE" "SELECT 'Task ID: '||task_id||char(10)||
			'Title: '||title||char(10)||
			'Description: '||COALESCE(description,'')||char(10)||
			'Test Criteria: '||COALESCE(test_criteria,'')
			FROM tasks WHERE id=$task_db_id;"
	fi
}

# ============================================================================
# Execute a single task via the selected engine
# ============================================================================
run_task() {
	local task_db_id="$1"
	local task_code="$2"

	# Resolve worktree: wave-level first (new model), fallback plan-level (old model)
	local worktree
	worktree=$(db_query "$DB_FILE" "SELECT COALESCE(w.worktree_path, p.worktree_path, '')
		FROM tasks t
		JOIN plans p ON t.plan_id = p.id
		LEFT JOIN waves w ON t.wave_id_fk = w.id
		WHERE t.id=$task_db_id;")
	worktree="${worktree/#\~/$HOME}"

	if [[ "$DRY_RUN" -eq 1 ]]; then
		step "DRY-RUN: would execute $task_code via $ENGINE"
		return 0
	fi

	# Build the prompt
	local prompt
	prompt="$(build_task_prompt "$task_db_id")"

	local exit_code=0

	# --- Strategy 1: delegate.sh (preferred) ---
	if [[ -x "$DELEGATE_SH" ]]; then
		step "Executing via delegate.sh (engine: $ENGINE)"
		local model_flag=""
		[[ -n "$MODEL" ]] && model_flag="--model $MODEL"
		# delegate.sh accepts: delegate.sh <task_db_id> [--engine <e>] [--model <m>]
		timeout "$TASK_TIMEOUT" "$DELEGATE_SH" "$task_db_id" \
			--engine "$ENGINE" $model_flag || exit_code=$?
		return $exit_code
	fi

	# --- Strategy 2: engine-specific fallback ---
	case "$ENGINE" in

	copilot)
		step "Executing via copilot-worker.sh"
		local model_arg="${MODEL:-}"
		if [[ -x "$COPILOT_WORKER" ]]; then
			local worker_args=("$task_db_id")
			[[ -n "$model_arg" ]] && worker_args+=(--model "$model_arg")
			worker_args+=(--timeout "$TASK_TIMEOUT")
			timeout "$TASK_TIMEOUT" "$COPILOT_WORKER" "${worker_args[@]}" || exit_code=$?
		else
			# Direct copilot invocation
			local model_flag=""
			[[ -n "$MODEL" ]] && model_flag="--model $MODEL"
			local dir_flag=""
			[[ -n "$worktree" && -d "$worktree" ]] && dir_flag="--add-dir $worktree"
			timeout "$TASK_TIMEOUT" copilot \
				--allow-all \
				--no-ask-user \
				$dir_flag \
				$model_flag \
				-p "$prompt" || exit_code=$?
		fi
		;;

	opencode)
		step "Executing via opencode"
		local model_flag=""
		[[ -n "$MODEL" ]] && model_flag="--model $MODEL"
		local cwd_flag=""
		[[ -n "$worktree" && -d "$worktree" ]] && cwd_flag="--cwd $worktree"
		timeout "$TASK_TIMEOUT" opencode \
			$cwd_flag \
			$model_flag \
			--prompt "$prompt" || exit_code=$?
		;;

	claude | *)
		step "Executing via claude CLI"
		local model_flag=""
		[[ -n "$MODEL" ]] && model_flag="--model $MODEL"
		local cwd_flag=""
		[[ -n "$worktree" && -d "$worktree" ]] && cwd_flag="--cwd $worktree"
		timeout "$TASK_TIMEOUT" claude \
			--dangerously-skip-permissions \
			$cwd_flag \
			$model_flag \
			-p "$prompt" || exit_code=$?
		;;
	esac

	return $exit_code
}

# ============================================================================
# Thor per-task validation
# ============================================================================
validate_task() {
	local task_db_id="$1"
	local task_code="$2"

	if [[ "$DRY_RUN" -eq 1 ]]; then
		step "DRY-RUN: would validate task $task_code via Thor"
		return 0
	fi

	step "Thor per-task validation: $task_code"
	if "${SCRIPT_DIR}/plan-db.sh" validate-task "$task_db_id" "$PLAN_ID" "execute-plan" 2>&1; then
		success "Thor: task $task_code PASS"
		return 0
	else
		warn "Thor: task $task_code REJECTED"
		return 1
	fi
}

# ============================================================================
# Thor per-wave validation
# ============================================================================
validate_wave() {
	local wave_db_id="$1"
	local wave_code="$2"

	if [[ "$DRY_RUN" -eq 1 ]]; then
		step "DRY-RUN: would validate wave $wave_code via Thor"
		return 0
	fi

	step "Thor per-wave validation: $wave_code"
	if "${SCRIPT_DIR}/plan-db.sh" validate-wave "$wave_db_id" "execute-plan" 2>&1; then
		success "Thor: wave $wave_code PASS"
		return 0
	else
		warn "Thor: wave $wave_code REJECTED"
		return 1
	fi
}

# ============================================================================
# Resume logic: find tasks to skip
# ============================================================================
SKIP_UNTIL_TASK=""

init_resume() {
	local from_task="$1"
	if [[ -n "$from_task" ]]; then
		SKIP_UNTIL_TASK="$from_task"
		log "Resume mode: skipping tasks before $from_task"
	fi
}

should_skip_task() {
	local task_code="$1"
	if [[ -n "$SKIP_UNTIL_TASK" ]]; then
		if [[ "$task_code" == "$SKIP_UNTIL_TASK" ]]; then
			# Found the start task — stop skipping
			SKIP_UNTIL_TASK=""
			return 1 # do NOT skip this task
		fi
		return 0 # skip
	fi
	return 1 # do NOT skip
}

# ============================================================================
# Main execution loop
# ============================================================================
execute_plan_waves() {
	local TOTAL_TASKS=0
	local DONE_TASKS=0
	local SKIPPED_TASKS=0
	local FAILED_TASKS=0

	while IFS='|' read -r wave_db_id wave_code wave_name wave_status; do
		echo ""
		log "=== Wave: $wave_code - $wave_name (status: $wave_status) ==="

		# Wave-per-worktree: create worktree for this wave if not exists
		if [[ -x "${SCRIPT_DIR}/wave-worktree.sh" && "$wave_status" != "done" ]]; then
			local wave_wt
			wave_wt=$(db_query "$DB_FILE" "SELECT COALESCE(worktree_path,'') FROM waves WHERE id=$wave_db_id;")
			if [[ -z "$wave_wt" ]]; then
				step "Creating wave worktree for $wave_code"
				"${SCRIPT_DIR}/wave-worktree.sh" create "$PLAN_ID" "$wave_db_id" 2>&1 || {
					warn "Failed to create wave worktree for $wave_code — using plan worktree"
				}
			fi
		fi

		# Skip already-completed waves (unless --from forces re-entry)
		if [[ "$wave_status" == "done" && -z "$FROM_TASK" ]]; then
			success "Wave $wave_code already done — skipping"
			continue
		fi

		# Track whether any tasks ran in this wave
		local wave_had_tasks=0
		local wave_failed=0

		while IFS='|' read -r task_db_id task_code task_status task_title; do
			TOTAL_TASKS=$((TOTAL_TASKS + 1))

			# Resume: skip tasks before --from target
			if should_skip_task "$task_code"; then
				step "Skipping $task_code (before resume point)"
				SKIPPED_TASKS=$((SKIPPED_TASKS + 1))
				continue
			fi

			# Skip already-done tasks
			if [[ "$task_status" == "done" && -z "$FROM_TASK" ]]; then
				step "$task_code: already done — skipping"
				DONE_TASKS=$((DONE_TASKS + 1))
				continue
			fi

			# Skip blocked tasks
			if [[ "$task_status" == "blocked" ]]; then
				warn "$task_code: blocked — skipping"
				FAILED_TASKS=$((FAILED_TASKS + 1))
				wave_failed=$((wave_failed + 1))
				continue
			fi

			wave_had_tasks=1
			step "Executing $task_code: $(echo "$task_title" | cut -c1-60)"

			# Run the task
			local task_exit=0
			run_task "$task_db_id" "$task_code" || task_exit=$?

			if [[ "$DRY_RUN" -eq 1 ]]; then
				DONE_TASKS=$((DONE_TASKS + 1))
				continue
			fi

			# Verify task status after execution
			local new_status
			new_status=$(db_query "$DB_FILE" "SELECT status FROM tasks WHERE id=$task_db_id;")

			if [[ "$new_status" == "done" ]]; then
				# Run Thor per-task validation
				local thor_exit=0
				validate_task "$task_db_id" "$task_code" || thor_exit=$?

				if [[ "$thor_exit" -ne 0 ]]; then
					warn "Task $task_code failed Thor validation — marked as needs-fix"
					FAILED_TASKS=$((FAILED_TASKS + 1))
					wave_failed=$((wave_failed + 1))
				else
					success "Task $task_code complete and validated"
					DONE_TASKS=$((DONE_TASKS + 1))
				fi
			else
				warn "Task $task_code ended with status=$new_status (exit=$task_exit)"
				FAILED_TASKS=$((FAILED_TASKS + 1))
				wave_failed=$((wave_failed + 1))
			fi

		done < <(get_wave_tasks "$wave_db_id")

		# Per-wave Thor validation (only if tasks ran and none failed)
		if [[ "$wave_had_tasks" -eq 1 && "$wave_failed" -eq 0 ]]; then
			echo ""
			local thor_wave_exit=0
			validate_wave "$wave_db_id" "$wave_code" || thor_wave_exit=$?

			if [[ "$thor_wave_exit" -ne 0 ]]; then
				warn "Wave $wave_code failed Thor validation — stopping execution"
				error "Fix wave issues before continuing. Resume with: execute-plan.sh $PLAN_ID --from <first-failed-task>"
				break
			fi

			# Wave-per-worktree: merge via PR after successful Thor validation
			if [[ -x "${SCRIPT_DIR}/wave-worktree.sh" ]]; then
				local wave_wt_check
				wave_wt_check=$(db_query "$DB_FILE" "SELECT COALESCE(worktree_path,'') FROM waves WHERE id=$wave_db_id;")
				if [[ -n "$wave_wt_check" ]]; then
					step "Wave $wave_code: merging via PR..."
					"${SCRIPT_DIR}/wave-worktree.sh" merge "$PLAN_ID" "$wave_db_id" 2>&1 || {
						warn "Wave $wave_code merge failed — manual intervention needed"
					}
				fi
			fi
		elif [[ "$wave_failed" -gt 0 ]]; then
			warn "Wave $wave_code had $wave_failed failed task(s) — skipping wave Thor validation"
		fi

	done < <(get_waves)

	# Summary
	echo ""
	log "=== EXECUTION SUMMARY ==="
	log "  Total tasks:   $TOTAL_TASKS"
	log "  Done:          $DONE_TASKS"
	log "  Skipped:       $SKIPPED_TASKS"
	log "  Failed:        $FAILED_TASKS"
	log "  Log:           $LOG_FILE"
	echo ""

	if [[ "$FAILED_TASKS" -gt 0 ]]; then
		warn "$FAILED_TASKS task(s) failed or blocked"
		warn "Check log: $LOG_FILE"
		warn "Resume with: execute-plan.sh $PLAN_ID --from <task_id> --engine $ENGINE"
		return 1
	else
		success "Plan $PLAN_ID execution complete"
		return 0
	fi
}
