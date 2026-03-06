#!/bin/bash
set -euo pipefail
# plan-db-safe.sh - Safe wrapper around plan-db.sh
# Auto-releases file locks, checks staleness, warns about uncommitted changes.
# VALIDATE-THEN-DONE: Validation runs BEFORE marking done (blocking, no bypass flags).
# CIRCUIT BREAKER: Auto-blocks tasks after MAX_REJECTIONS consecutive Thor rejections.
# Version: 4.2.0 - Worktree lookup: task wave → any wave → plan fallback

# PATH hardening: ensure pnpm/node/python tools are findable
export PATH="$HOME/.npm-global/bin:$HOME/.local/bin:/opt/homebrew/bin:/usr/local/bin:$PATH"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DB_FILE="$HOME/.claude/data/dashboard.db"
DATA_DIR="$HOME/.claude/data"
AUDIT_LOG="$DATA_DIR/thor-audit.jsonl"
REJECTION_COUNTER_DIR="$DATA_DIR/rejection-counters"
source "$SCRIPT_DIR/plan-db-verify.sh"

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
		# Worktree lookup: task's own wave → any wave in plan → plan-level
		worktree=$(sqlite3 -cmd ".timeout 3000" "$DB_FILE" \
			"SELECT w.worktree_path FROM waves w JOIN tasks t ON t.wave_id_fk = w.id
			 WHERE t.id = $TASK_ID AND w.worktree_path IS NOT NULL AND w.worktree_path <> ''
			 LIMIT 1;" 2>/dev/null || echo "")
		if [[ -z "$worktree" ]]; then
			worktree=$(sqlite3 -cmd ".timeout 3000" "$DB_FILE" \
				"SELECT worktree_path FROM waves
				 WHERE plan_id = $plan_id AND worktree_path IS NOT NULL AND worktree_path <> ''
				 ORDER BY position DESC LIMIT 1;" 2>/dev/null || echo "")
		fi
		if [[ -z "$worktree" ]]; then
			worktree=$(sqlite3 -cmd ".timeout 3000" "$DB_FILE" \
				"SELECT worktree_path FROM plans WHERE id = $plan_id;" 2>/dev/null || echo "")
		fi
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
		"$SCRIPT_DIR/file-lock.sh" release-task "$TASK_ID" >/dev/null 2>/dev/null || true
	fi

	# --- AUTO-TRANSITION: pending→in_progress if needed (prevents plan-db.sh rejection) ---
	current_status=$(sqlite3 -cmd ".timeout 3000" "$DB_FILE" \
		"SELECT status FROM tasks WHERE id = $TASK_ID;" 2>/dev/null || echo "")
	if [[ "$current_status" == "pending" ]]; then
		echo "[plan-db-safe] Auto-transition: pending→in_progress for task $TASK_ID" >&2
		sqlite3 -cmd ".timeout 3000" "$DB_FILE" \
			"UPDATE tasks SET status = 'in_progress', started_at = datetime('now') WHERE id = $TASK_ID;"
	fi

	# ======================================================================
	# PROOF-OF-WORK GATE (v3.4.0): Verify ACTUAL changes before marking done
	# ======================================================================
	if ! plan_db_safe_verify_task "$TASK_ID" "$plan_id" "$@"; then
		exit 1
	fi
	task_id_str="${PLAN_DB_SAFE_TASK_ID_STR:-unknown}"

	# --- DELEGATE: set task to 'submitted' (NOT done) ---
	# plan-db-safe.sh NEVER sets 'done'. It sets 'submitted' = executor finished, Thor pending.
	# Only validate-task (Thor) can transition submitted → done (enforced by SQLite trigger).
	PLAN_DB_SAFE_CALLER=1 "$SCRIPT_DIR/plan-db.sh" "update-task" "$TASK_ID" "submitted" "${@:4}"

	echo "[plan-db-safe] Task $task_id_str set to SUBMITTED (proof-of-work passed). Thor validation REQUIRED." >&2

	# --- POST-SUBMIT: Log audit + check wave readiness ---
	if [[ -n "$plan_id" ]]; then
		wave_db_id=$(sqlite3 -cmd ".timeout 3000" "$DB_FILE" \
			"SELECT wave_id_fk FROM tasks WHERE id = $TASK_ID;" 2>/dev/null || echo "")
		wave_id=$(sqlite3 -cmd ".timeout 3000" "$DB_FILE" \
			"SELECT w.wave_id FROM waves w JOIN tasks t ON t.wave_id_fk = w.id WHERE t.id = $TASK_ID;" 2>/dev/null || echo "unknown")

		# Log proof-of-work audit entry
		if [[ -x "$SCRIPT_DIR/thor-audit-log.sh" ]]; then
			"$SCRIPT_DIR/thor-audit-log.sh" "$plan_id" "$task_id_str" "$wave_id" \
				'["proof-of-work","git-diff","time-check"]' '[]' "plan-db-safe-pow" "0" "0.5" 2>/dev/null || true
		fi

		# Check wave: all executor work complete? (submitted + done + cancelled + skipped = all)
		if [[ -n "$wave_db_id" ]]; then
			still_working=$(sqlite3 "$DB_FILE" \
				"SELECT COUNT(*) FROM tasks WHERE wave_id_fk = $wave_db_id AND status NOT IN ('done', 'submitted', 'cancelled', 'skipped');" 2>/dev/null || echo "1")
			need_thor=$(sqlite3 "$DB_FILE" \
				"SELECT COUNT(*) FROM tasks WHERE wave_id_fk = $wave_db_id AND status = 'submitted';" 2>/dev/null || echo "1")

			if [[ "$still_working" -eq 0 && "$need_thor" -gt 0 ]]; then
				echo "" >&2
				echo "[plan-db-safe] Wave $wave_id: All executor work complete. Auto-validating $need_thor submitted task(s)..." >&2

				# F-12: Auto-validate all submitted tasks in this wave
				local submitted_ids
				submitted_ids=$(sqlite3 "$DB_FILE" \
					"SELECT id FROM tasks WHERE wave_id_fk = $wave_db_id AND status = 'submitted';" 2>/dev/null || echo "")
				while IFS= read -r sub_id; do
					[[ -z "$sub_id" ]] && continue
					echo "[plan-db-safe] Auto-Thor: validate-task $sub_id $plan_id" >&2
					"$SCRIPT_DIR/plan-db.sh" validate-task "$sub_id" "$plan_id" 2>/dev/null || {
						echo "WARN: Auto-Thor failed for task $sub_id — manual validation needed" >&2
					}
				done <<<"$submitted_ids"
			fi

			# Check if everything is done AND validated (all tasks = done, not submitted)
			all_done=$(sqlite3 "$DB_FILE" \
				"SELECT COUNT(*) FROM tasks WHERE wave_id_fk = $wave_db_id AND status NOT IN ('done', 'cancelled', 'skipped');" 2>/dev/null || echo "1")
			if [[ "$all_done" -eq 0 ]]; then
				# All tasks are done (Thor-validated) — safe for wave completion
				echo "[plan-db-safe] Wave $wave_id: all tasks done + Thor-validated" >&2
				"$SCRIPT_DIR/plan-db.sh" validate-wave "$wave_db_id" "thor" 2>/dev/null || true

				# Wave-per-worktree: trigger merge
				if [[ -x "$SCRIPT_DIR/wave-worktree.sh" ]]; then
					wave_wt=$(sqlite3 "$DB_FILE" \
						"SELECT worktree_path FROM waves WHERE id = $wave_db_id AND worktree_path IS NOT NULL AND worktree_path <> '';" 2>/dev/null || echo "")
					if [[ -n "$wave_wt" ]]; then
						echo "[plan-db-safe] Wave $wave_id: wave-worktree merge..." >&2
						"$SCRIPT_DIR/wave-worktree.sh" merge "$plan_id" "$wave_db_id" 2>&1 || {
							echo "WARN: Wave $wave_id merge failed" >&2
						}
					fi
				fi

				# Check plan completion
				waves_not_done=$(sqlite3 "$DB_FILE" \
					"SELECT COUNT(*) FROM waves WHERE plan_id = $plan_id AND status NOT IN ('done', 'cancelled');" 2>/dev/null || echo "1")
				if [[ "$waves_not_done" -eq 0 ]]; then
					echo "[plan-db-safe] All waves complete — syncing plan $plan_id..." >&2
					"$SCRIPT_DIR/plan-db.sh" sync "$plan_id" 2>/dev/null || true
					"$SCRIPT_DIR/plan-db.sh" complete "$plan_id" 2>/dev/null || {
						echo "WARN: Auto-complete plan $plan_id failed" >&2
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
