#!/bin/bash
# plan-db-safe.sh - Safe wrapper around plan-db.sh
# Auto-releases file locks, checks staleness, warns about uncommitted changes.
# AUTO-VALIDATES tasks/waves/plan after marking done (prevents 0% progress bug).
# CIRCUIT BREAKER: Auto-blocks tasks after MAX_REJECTIONS consecutive Thor rejections.
# Version: 3.1.0
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DB_FILE="$HOME/.claude/data/dashboard.db"
DATA_DIR="$HOME/.claude/data"
AUDIT_LOG="$DATA_DIR/thor-audit.jsonl"
REJECTION_COUNTER_DIR="$DATA_DIR/rejection-counters"

# Circuit breaker configuration
MAX_REJECTIONS="${MAX_REJECTIONS:-3}"

COMMAND="${1:-}"
TASK_ID="${2:-}"
STATUS="${3:-}"

# ============================================================================
# CIRCUIT BREAKER: Track consecutive rejections, auto-block after threshold
# ============================================================================
circuit_breaker_track_rejection() {
	local task_db_id="$1"
	local plan_id="${2:-}"

	mkdir -p "$REJECTION_COUNTER_DIR"
	local counter_file="$REJECTION_COUNTER_DIR/task-${task_db_id}.count"

	# Increment counter
	local count=1
	if [[ -f "$counter_file" ]]; then
		count=$(cat "$counter_file")
		count=$((count + 1))
	fi
	echo "$count" >"$counter_file"

	# Check threshold
	if [[ $count -ge $MAX_REJECTIONS ]]; then
		# Auto-block task
		local task_id_text
		task_id_text=$(sqlite3 "$DB_FILE" "SELECT task_id FROM tasks WHERE id = $task_db_id;" 2>/dev/null || echo "unknown")

		echo "CIRCUIT BREAKER: Task $task_id_text rejected $count times - AUTO-BLOCKING" >&2

		# Set task to blocked
		sqlite3 "$DB_FILE" "UPDATE tasks SET status = 'blocked', notes = 'AUTO-BLOCKED: $count consecutive Thor rejections (circuit breaker)' WHERE id = $task_db_id;"

		# Log to thor-audit.jsonl
		local timestamp
		timestamp=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
		local wave_id
		wave_id=$(sqlite3 "$DB_FILE" "SELECT wave_id FROM waves w JOIN tasks t ON t.wave_id_fk = w.id WHERE t.id = $task_db_id;" 2>/dev/null || echo "unknown")

		local audit_entry="{\"timestamp\":\"$timestamp\",\"event\":\"circuit_breaker_triggered\",\"task_db_id\":$task_db_id,\"task_id\":\"$task_id_text\",\"plan_id\":${plan_id:-null},\"wave_id\":\"$wave_id\",\"consecutive_rejections\":$count,\"max_rejections\":$MAX_REJECTIONS,\"action\":\"auto_blocked\"}"

		# Atomic append
		mkdir -p "$DATA_DIR"
		if command -v flock >/dev/null 2>&1; then
			(
				flock -x 200
				echo "$audit_entry" >>"$AUDIT_LOG"
			) 200>"$AUDIT_LOG.lock"
		else
			echo "$audit_entry" >>"$AUDIT_LOG"
		fi

		# Clean up counter
		rm -f "$counter_file"

		return 1
	fi

	return 0
}

circuit_breaker_reset() {
	local task_db_id="$1"
	local counter_file="$REJECTION_COUNTER_DIR/task-${task_db_id}.count"
	rm -f "$counter_file"
}

# ============================================================================
# HOOK: update-task <id> done — pre-checks + post-validation
# ============================================================================
if [[ "$COMMAND" == "update-task" && "$STATUS" == "done" ]]; then
	# --- PRE-CHECKS (existing) ---

	# Check staleness before marking done
	if [[ -x "$SCRIPT_DIR/stale-check.sh" ]]; then
		stale_result=$("$SCRIPT_DIR/stale-check.sh" check "$TASK_ID" 2>/dev/null || echo "ok")
		if [[ "$stale_result" == *"stale=true"* ]]; then
			echo "ERROR: Stale files detected for task $TASK_ID. Rebase before marking done." >&2
			exit 1
		fi
	fi

	# Resolve plan_id for this task
	plan_id=$(sqlite3 -cmd ".timeout 3000" "$DB_FILE" \
		"SELECT plan_id FROM tasks WHERE id = $TASK_ID;" 2>/dev/null || echo "")

	# Warn about uncommitted changes (don't block)
	if [[ -n "$plan_id" ]]; then
		worktree=$(sqlite3 -cmd ".timeout 3000" "$DB_FILE" \
			"SELECT worktree_path FROM plans WHERE id = $plan_id;" 2>/dev/null || echo "")
		if [[ -n "$worktree" && -d "$worktree" ]]; then
			dirty_count=$(git -C "$worktree" status --porcelain 2>/dev/null | grep -c "" || echo "0")
			if [[ "$dirty_count" -gt 0 ]]; then
				echo "WARN: $dirty_count uncommitted file(s) in $worktree for task $TASK_ID" >&2
				echo "WARN: Remember to commit before session end" >&2
				git -C "$worktree" status --porcelain 2>/dev/null | head -5 | sed 's/^/  /' >&2
			fi
		fi
	fi

	# Release file locks held by this task
	if [[ -x "$SCRIPT_DIR/file-lock.sh" ]]; then
		"$SCRIPT_DIR/file-lock.sh" release-task "$TASK_ID" 2>/dev/null || true
	fi

	# --- DELEGATE: mark task done (bypass guard — we ARE the safe wrapper) ---
	PLAN_DB_SAFE_CALLER=1 "$SCRIPT_DIR/plan-db.sh" "$@"

	# --- POST-DONE: auto-validate task (prevents 0% progress bug) ---
	if [[ -n "$plan_id" ]]; then
		echo "[plan-db-safe] Auto-validating task $TASK_ID..." >&2

		# Track validation timing
		validation_start=$(date +%s)
		validation_result="pass"

		"$SCRIPT_DIR/plan-db.sh" validate-task "$TASK_ID" "$plan_id" "executor-auto" --force 2>/dev/null || {
			echo "WARN: Auto-validate task $TASK_ID failed (non-blocking)" >&2
			validation_result="fail"

			# Circuit breaker: track consecutive rejections
			circuit_breaker_track_rejection "$TASK_ID" "$plan_id" || {
				echo "ERROR: Circuit breaker triggered - task $TASK_ID auto-blocked after $MAX_REJECTIONS rejections" >&2
				exit 1
			}
		}

		# Reset circuit breaker on successful validation
		if [[ "$validation_result" == "pass" ]]; then
			circuit_breaker_reset "$TASK_ID"
		fi

		validation_end=$(date +%s)
		validation_duration=$((validation_end - validation_start))

		# Log to Thor audit trail
		wave_id=$(sqlite3 -cmd ".timeout 3000" "$DB_FILE" \
			"SELECT w.wave_id FROM waves w JOIN tasks t ON t.wave_id_fk = w.id WHERE t.id = $TASK_ID;" 2>/dev/null || echo "unknown")
		task_id_str=$(sqlite3 -cmd ".timeout 3000" "$DB_FILE" \
			"SELECT task_id FROM tasks WHERE id = $TASK_ID;" 2>/dev/null || echo "unknown")

		if [[ "$validation_result" == "pass" ]]; then
			gates_passed='["task-status","auto-validate"]'
			gates_failed='[]'
			confidence=1.0
		else
			gates_passed='[]'
			gates_failed='["auto-validate"]'
			confidence=0.0
		fi

		if [[ -x "$SCRIPT_DIR/thor-audit-log.sh" ]]; then
			"$SCRIPT_DIR/thor-audit-log.sh" "$plan_id" "$task_id_str" "$wave_id" \
				"$gates_passed" "$gates_failed" "executor-auto" "$validation_duration" "$confidence" 2>/dev/null || true
		fi

		# Check if all tasks in this wave are done + validated
		wave_db_id=$(sqlite3 -cmd ".timeout 3000" "$DB_FILE" \
			"SELECT wave_id_fk FROM tasks WHERE id = $TASK_ID;" 2>/dev/null || echo "")
		if [[ -n "$wave_db_id" ]]; then
			not_done=$(sqlite3 "$DB_FILE" \
				"SELECT COUNT(*) FROM tasks WHERE wave_id_fk = $wave_db_id AND status <> 'done';" 2>/dev/null || echo "1")
			not_validated=$(sqlite3 "$DB_FILE" \
				"SELECT COUNT(*) FROM tasks WHERE wave_id_fk = $wave_db_id AND status = 'done' AND validated_at IS NULL;" 2>/dev/null || echo "1")

			if [[ "$not_done" -eq 0 && "$not_validated" -eq 0 ]]; then
				wave_id=$(sqlite3 "$DB_FILE" "SELECT wave_id FROM waves WHERE id = $wave_db_id;" 2>/dev/null || echo "?")
				echo "[plan-db-safe] Wave $wave_id complete — auto-validating..." >&2

				# Track wave validation timing
				wave_validation_start=$(date +%s)
				wave_validation_result="pass"

				"$SCRIPT_DIR/plan-db.sh" validate-wave "$wave_db_id" "executor-auto" 2>/dev/null || {
					echo "WARN: Auto-validate wave $wave_db_id failed (non-blocking)" >&2
					wave_validation_result="fail"
				}

				wave_validation_end=$(date +%s)
				wave_validation_duration=$((wave_validation_end - wave_validation_start))

				# Log wave validation to Thor audit trail
				if [[ "$wave_validation_result" == "pass" ]]; then
					wave_gates_passed='["wave-complete","all-tasks-validated"]'
					wave_gates_failed='[]'
					wave_confidence=1.0
				else
					wave_gates_passed='[]'
					wave_gates_failed='["wave-validation"]'
					wave_confidence=0.0
				fi

				if [[ -x "$SCRIPT_DIR/thor-audit-log.sh" ]]; then
					"$SCRIPT_DIR/thor-audit-log.sh" "$plan_id" "wave-$wave_id" "$wave_id" \
						"$wave_gates_passed" "$wave_gates_failed" "executor-auto" "$wave_validation_duration" "$wave_confidence" 2>/dev/null || true
				fi

				# Wave-per-worktree: trigger merge if wave model is active
				if [[ "$wave_validation_result" == "pass" && -x "$SCRIPT_DIR/wave-worktree.sh" ]]; then
					# Check if this plan uses wave-level worktrees
					wave_wt=$(sqlite3 "$DB_FILE" \
						"SELECT worktree_path FROM waves WHERE id = $wave_db_id AND worktree_path IS NOT NULL AND worktree_path <> '';" 2>/dev/null || echo "")
					if [[ -n "$wave_wt" ]]; then
						echo "[plan-db-safe] Wave $wave_id: wave-worktree merge..." >&2
						if "$SCRIPT_DIR/wave-worktree.sh" merge "$plan_id" "$wave_db_id" 2>&1; then
							echo "[plan-db-safe] Wave $wave_id merged successfully" >&2
						else
							echo "WARN: Wave $wave_id merge failed — wave stays in 'merging' state" >&2
							# Stop cascade: don't check plan completion if merge failed
							exit 0
						fi
					fi
				fi

				# Check if ALL waves in plan are done
				waves_not_done=$(sqlite3 "$DB_FILE" \
					"SELECT COUNT(*) FROM waves WHERE plan_id = $plan_id AND status NOT IN ('done');" 2>/dev/null || echo "1")
				if [[ "$waves_not_done" -eq 0 ]]; then
					echo "[plan-db-safe] All waves complete — syncing + completing plan $plan_id..." >&2
					"$SCRIPT_DIR/plan-db.sh" sync "$plan_id" 2>/dev/null || true
					"$SCRIPT_DIR/plan-db.sh" validate "$plan_id" "executor-auto" 2>/dev/null || true
					# complete may fail if Thor gate enforced — that's OK
					"$SCRIPT_DIR/plan-db.sh" complete "$plan_id" 2>/dev/null || {
						echo "WARN: Auto-complete plan $plan_id failed (Thor validation may be required)" >&2
					}
				fi
			fi
		fi
	fi

	exit 0
fi

# ============================================================================
# ALL OTHER COMMANDS: delegate directly
# ============================================================================
exec "$SCRIPT_DIR/plan-db.sh" "$@"
