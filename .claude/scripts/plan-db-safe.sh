#!/bin/bash
# plan-db-safe.sh - Safe wrapper around plan-db.sh
# Auto-releases file locks, checks staleness, warns about uncommitted changes.
# AUTO-VALIDATES tasks/waves/plan after marking done (prevents 0% progress bug).
# Version: 3.0.0
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DB_FILE="$HOME/.claude/data/dashboard.db"

COMMAND="${1:-}"
TASK_ID="${2:-}"
STATUS="${3:-}"

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
		"$SCRIPT_DIR/plan-db.sh" validate-task "$TASK_ID" "$plan_id" "executor-auto" --force 2>/dev/null || {
			echo "WARN: Auto-validate task $TASK_ID failed (non-blocking)" >&2
		}

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
				"$SCRIPT_DIR/plan-db.sh" validate-wave "$wave_db_id" "executor-auto" 2>/dev/null || {
					echo "WARN: Auto-validate wave $wave_db_id failed (non-blocking)" >&2
				}

				# Check if ALL waves in plan are done
				waves_not_done=$(sqlite3 "$DB_FILE" \
					"SELECT COUNT(*) FROM waves WHERE plan_id = $plan_id AND status <> 'done';" 2>/dev/null || echo "1")
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
