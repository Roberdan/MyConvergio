#!/bin/bash
set -euo pipefail
# plan-db-safe.sh - Safe wrapper around plan-db.sh
# Auto-releases file locks, checks staleness, warns about uncommitted changes.
# VALIDATE-THEN-DONE: Validation runs BEFORE marking done (blocking, no bypass flags).
# CIRCUIT BREAKER: Auto-blocks tasks after MAX_REJECTIONS consecutive Thor rejections.
# Version: 4.0.0
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
	# Without this, agents can call plan-db-safe.sh done without doing work.
	# ======================================================================
	task_id_str=$(sqlite3 -cmd ".timeout 3000" "$DB_FILE" \
		"SELECT task_id FROM tasks WHERE id = $TASK_ID;" 2>/dev/null || echo "unknown")
	task_files=$(sqlite3 -cmd ".timeout 3000" "$DB_FILE" \
		"SELECT files FROM tasks WHERE id = $TASK_ID;" 2>/dev/null || echo "")
	task_effort=$(sqlite3 -cmd ".timeout 3000" "$DB_FILE" \
		"SELECT COALESCE(effort, 2) FROM tasks WHERE id = $TASK_ID;" 2>/dev/null || echo "2")
	task_verify=$(sqlite3 -cmd ".timeout 3000" "$DB_FILE" \
		"SELECT test_criteria FROM tasks WHERE id = $TASK_ID;" 2>/dev/null || echo "")
	task_type=$(sqlite3 -cmd ".timeout 3000" "$DB_FILE" \
		"SELECT COALESCE(type, 'code') FROM tasks WHERE id = $TASK_ID;" 2>/dev/null || echo "code")
	task_title=$(sqlite3 -cmd ".timeout 3000" "$DB_FILE" \
		"SELECT COALESCE(title, '') FROM tasks WHERE id = $TASK_ID;" 2>/dev/null || echo "")
	task_started=$(sqlite3 -cmd ".timeout 3000" "$DB_FILE" \
		"SELECT started_at FROM tasks WHERE id = $TASK_ID;" 2>/dev/null || echo "")

	# --- Guard 1: Time-based sanity check ---
	if [[ -n "$task_started" ]]; then
		started_epoch=$(date -d "$task_started" +%s 2>/dev/null || date -j -f "%Y-%m-%d %H:%M:%S" "$task_started" +%s 2>/dev/null || echo "0")
		now_epoch=$(date +%s)
		elapsed=$((now_epoch - started_epoch))
		min_seconds=60
		[[ "$task_effort" -ge 2 ]] && min_seconds=120
		[[ "$task_effort" -ge 3 ]] && min_seconds=300
		if [[ "$elapsed" -lt "$min_seconds" ]]; then
			echo "REJECTED: Task $task_id_str completed in ${elapsed}s (min ${min_seconds}s for effort=$task_effort). Suspiciously fast." >&2
			echo "  If this is a genuine quick fix, wait and retry, or use --force-time flag." >&2
			# Check for --force-time flag in remaining args
			force_time=false
			for arg in "$@"; do [[ "$arg" == "--force-time" ]] && force_time=true; done
			if [[ "$force_time" == false ]]; then
				exit 1
			else
				echo "WARN: --force-time used, proceeding despite fast completion" >&2
			fi
		fi
	fi

	# --- Guard 2: Git-diff proof (code/test/chore tasks must modify files) ---
	proof_of_work=false
	if [[ "$task_type" == "doc" || "$task_type" == "docs" ]]; then
		proof_of_work=true # Doc tasks may not touch code
	fi
	# Verification/closure tasks don't produce file changes
	task_title_lower=$(echo "$task_title" | tr '[:upper:]' '[:lower:]')
	if [[ "$task_type" == "chore" && "$task_title_lower" == create\ pr* ]]; then
		proof_of_work=true # PR creation/merge tasks
	fi
	if [[ "$task_type" == "test" ]] && [[ "$task_title_lower" == verify* || "$task_title_lower" == consolidate\ and\ verify* || "$task_title_lower" == run\ full\ validation* ]]; then
		proof_of_work=true # Verification-only tasks
	fi

	if [[ "$proof_of_work" == false && -n "$plan_id" ]]; then
		resolve_worktree() {
			# Try wave worktree first, then plan worktree, then pwd
			local wt=""
			local wave_fk=$(sqlite3 "$DB_FILE" "SELECT wave_id_fk FROM tasks WHERE id = $TASK_ID;" 2>/dev/null || echo "")
			if [[ -n "$wave_fk" ]]; then
				wt=$(sqlite3 "$DB_FILE" "SELECT worktree_path FROM waves WHERE id = $wave_fk;" 2>/dev/null || echo "")
			fi
			[[ -z "$wt" || ! -d "$wt" ]] && wt=$(sqlite3 "$DB_FILE" "SELECT worktree_path FROM plans WHERE id = $plan_id;" 2>/dev/null || echo "")
			[[ -z "$wt" || ! -d "$wt" ]] && wt="$(pwd)"
			echo "$wt"
		}
		work_dir=$(resolve_worktree)

		if [[ -d "$work_dir/.git" || -f "$work_dir/.git" ]]; then
			# Check: uncommitted changes OR recent commits (last 10 min)
			uncommitted=$(git -C "$work_dir" diff --name-only 2>/dev/null | head -20)
			staged=$(git -C "$work_dir" diff --cached --name-only 2>/dev/null | head -20)
			recent_commits=$(git -C "$work_dir" log --since="10 minutes ago" --name-only --pretty=format: 2>/dev/null | sort -u | head -20)
			all_changed="$uncommitted"$'\n'"$staged"$'\n'"$recent_commits"
			all_changed=$(echo "$all_changed" | sort -u | grep -v '^$' || true)

			if [[ -z "$all_changed" ]]; then
				echo "REJECTED: Task $task_id_str has ZERO file changes (no uncommitted, staged, or recent commits in $work_dir)." >&2
				echo "  You must modify at least one file before marking done." >&2
				exit 1
			fi

			# If task has specific files, verify at least one was touched
			if [[ -n "$task_files" && "$task_files" != "[]" && "$task_files" != "null" ]]; then
				file_match=false
				# Parse task_files (JSON array or pipe-separated)
				file_list=$(echo "$task_files" | tr -d '[]"' | tr ',' '\n' | tr '|' '\n' | sed 's/^ *//;s/ *$//' | grep -v '^$')
				while IFS= read -r expected_file; do
					[[ -z "$expected_file" ]] && continue
					# Check if any changed file matches (partial match for directory patterns)
					if echo "$all_changed" | grep -q "$expected_file"; then
						file_match=true
						break
					fi
				done <<<"$file_list"
				if [[ "$file_match" == false ]]; then
					echo "REJECTED: Task $task_id_str modified files but NONE match task spec files: $task_files" >&2
					echo "  Changed: $(echo "$all_changed" | head -5 | tr '\n' ', ')" >&2
					echo "  Expected: $task_files" >&2
					exit 1
				fi
			fi
			proof_of_work=true
			echo "[plan-db-safe] Proof-of-work: $(echo "$all_changed" | wc -l | tr -d ' ') file(s) changed" >&2
		fi
	fi

	# --- Guard 3: Run verify commands from test_criteria ---
	if [[ -n "$task_verify" && "$task_verify" != "[]" && "$task_verify" != "null" ]]; then
		verify_cmds=$(echo "$task_verify" | python3 -c "
import json,sys
try:
    data = json.load(sys.stdin)
    if isinstance(data, list):
        for item in data:
            if isinstance(item, str) and not item.startswith('No '):
                print(item)
    elif isinstance(data, dict):
        for v in data.get('verify', data.values()):
            if isinstance(v, str) and not v.startswith('No '):
                print(v)
except: pass
" 2>/dev/null || true)

		if [[ -n "$verify_cmds" ]]; then
			verify_failures=0
			while IFS= read -r vcmd; do
				[[ -z "$vcmd" ]] && continue
				# Skip non-executable verify criteria (prose descriptions)
				[[ "$vcmd" != *"/"* && "$vcmd" != *"."* && "$vcmd" != *"$"* ]] && continue
				echo "[plan-db-safe] Running verify: $vcmd" >&2
				if ! eval "$vcmd" >/dev/null 2>&1; then
					echo "REJECTED: Verify command failed: $vcmd" >&2
					verify_failures=$((verify_failures + 1))
				fi
			done <<<"$verify_cmds"
			if [[ "$verify_failures" -gt 0 ]]; then
				echo "REJECTED: $verify_failures verify command(s) failed for task $task_id_str" >&2
				exit 1
			fi
		fi
	fi

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
				echo "================================================================" >&2
				echo "  WAVE $wave_id: All executor work complete." >&2
				echo "  $need_thor task(s) in SUBMITTED status — need Thor validation." >&2
				echo "  Thor: plan-db.sh validate-task <id> $plan_id thor" >&2
				echo "  Or:   @validate (copilot) / Task(subagent_type='thor') (claude)" >&2
				echo "================================================================" >&2
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
