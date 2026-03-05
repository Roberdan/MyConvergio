#!/bin/bash
# plan-db-verify.sh - Proof-of-work verification helpers for plan-db-safe.sh

plan_db_safe_resolve_worktree() {
	local task_db_id="$1"
	local plan_id="$2"
	local wt=""
	local wave_fk
	wave_fk=$(sqlite3 "$DB_FILE" "SELECT wave_id_fk FROM tasks WHERE id = $task_db_id;" 2>/dev/null || echo "")
	if [[ -n "$wave_fk" ]]; then
		wt=$(sqlite3 "$DB_FILE" "SELECT worktree_path FROM waves WHERE id = $wave_fk;" 2>/dev/null || echo "")
	fi
	[[ -z "$wt" || ! -d "$wt" ]] && wt=$(sqlite3 "$DB_FILE" "SELECT worktree_path FROM plans WHERE id = $plan_id;" 2>/dev/null || echo "")
	# Expand tilde to $HOME (tilde not expanded inside double quotes)
	[[ "$wt" == "~/"* ]] && wt="$HOME/${wt:2}"
	[[ "$wt" == "~" ]] && wt="$HOME"
	[[ -z "$wt" || ! -d "$wt" ]] && wt="$(pwd)"
	echo "$wt"
}

plan_db_safe_verify_task() {
	local task_db_id="$1"
	local plan_id="$2"
	shift 2

	local task_id_str task_files task_effort task_verify task_type task_title task_started
	task_id_str=$(sqlite3 -cmd ".timeout 3000" "$DB_FILE" \
		"SELECT task_id FROM tasks WHERE id = $task_db_id;" 2>/dev/null || echo "unknown")
	task_files=$(sqlite3 -cmd ".timeout 3000" "$DB_FILE" \
		"SELECT files FROM tasks WHERE id = $task_db_id;" 2>/dev/null || echo "")
	task_effort=$(sqlite3 -cmd ".timeout 3000" "$DB_FILE" \
		"SELECT COALESCE(effort, 2) FROM tasks WHERE id = $task_db_id;" 2>/dev/null || echo "2")
	task_verify=$(sqlite3 -cmd ".timeout 3000" "$DB_FILE" \
		"SELECT test_criteria FROM tasks WHERE id = $task_db_id;" 2>/dev/null || echo "")
	task_type=$(sqlite3 -cmd ".timeout 3000" "$DB_FILE" \
		"SELECT COALESCE(type, 'code') FROM tasks WHERE id = $task_db_id;" 2>/dev/null || echo "code")
	task_title=$(sqlite3 -cmd ".timeout 3000" "$DB_FILE" \
		"SELECT COALESCE(title, '') FROM tasks WHERE id = $task_db_id;" 2>/dev/null || echo "")
	task_started=$(sqlite3 -cmd ".timeout 3000" "$DB_FILE" \
		"SELECT started_at FROM tasks WHERE id = $task_db_id;" 2>/dev/null || echo "")
	PLAN_DB_SAFE_TASK_ID_STR="$task_id_str"

	if [[ -n "$task_started" ]]; then
		local started_epoch now_epoch elapsed min_seconds force_time
		started_epoch=$(date -d "$task_started" +%s 2>/dev/null || date -j -f "%Y-%m-%d %H:%M:%S" "$task_started" +%s 2>/dev/null || echo "0")
		now_epoch=$(date +%s)
		elapsed=$((now_epoch - started_epoch))
		min_seconds=60
		[[ "$task_effort" -ge 2 ]] && min_seconds=120
		[[ "$task_effort" -ge 3 ]] && min_seconds=300
		if [[ "$elapsed" -lt "$min_seconds" ]]; then
			echo "REJECTED: Task $task_id_str completed in ${elapsed}s (min ${min_seconds}s for effort=$task_effort). Suspiciously fast." >&2
			echo "  If this is a genuine quick fix, wait and retry, or use --force-time flag." >&2
			force_time=false
			for arg in "$@"; do
				[[ "$arg" == "--force-time" ]] && force_time=true
			done
			if [[ "$force_time" == false ]]; then
				return 1
			else
				echo "WARN: --force-time used, proceeding despite fast completion" >&2
			fi
		fi
	fi

	local proof_of_work task_title_lower
	proof_of_work=false
	if [[ "$task_type" == "doc" || "$task_type" == "docs" ]]; then
		proof_of_work=true
	fi
	task_title_lower=$(echo "$task_title" | tr '[:upper:]' '[:lower:]')
	if [[ "$task_type" == "chore" && "$task_title_lower" == create\ pr* ]]; then
		proof_of_work=true
	fi
	if [[ "$task_type" == "test" ]] && [[ "$task_title_lower" == verify* || "$task_title_lower" == consolidate\ and\ verify* || "$task_title_lower" == run\ full\ validation* ]]; then
		proof_of_work=true
	fi

	if [[ "$proof_of_work" == false && -n "$plan_id" ]]; then
		local work_dir uncommitted staged recent_commits all_changed file_match file_list
		work_dir=$(plan_db_safe_resolve_worktree "$task_db_id" "$plan_id")
		if [[ -d "$work_dir/.git" || -f "$work_dir/.git" ]]; then
			uncommitted=$(git -C "$work_dir" diff --name-only 2>/dev/null | head -20)
			staged=$(git -C "$work_dir" diff --cached --name-only 2>/dev/null | head -20)
			recent_commits=$(git -C "$work_dir" log --since="10 minutes ago" --name-only --pretty=format: 2>/dev/null | sort -u | head -20)
			all_changed="$uncommitted"$'\n'"$staged"$'\n'"$recent_commits"
			all_changed=$(echo "$all_changed" | sort -u | grep -v '^$' || true)

			if [[ -z "$all_changed" ]]; then
				echo "REJECTED: Task $task_id_str has ZERO file changes (no uncommitted, staged, or recent commits in $work_dir)." >&2
				echo "  You must modify at least one file before marking done." >&2
				return 1
			fi

			if [[ -n "$task_files" && "$task_files" != "[]" && "$task_files" != "null" ]]; then
				file_match=false
				file_list=$(echo "$task_files" | tr -d '[]"' | tr ',' '\n' | tr '|' '\n' | sed 's/^ *//;s/ *$//' | grep -v '^$')
				while IFS= read -r expected_file; do
					[[ -z "$expected_file" ]] && continue
					if echo "$all_changed" | grep -q "$expected_file"; then
						file_match=true
						break
					fi
				done <<<"$file_list"
				if [[ "$file_match" == false ]]; then
					echo "REJECTED: Task $task_id_str modified files but NONE match task spec files: $task_files" >&2
					echo "  Changed: $(echo "$all_changed" | head -5 | tr '\n' ', ')" >&2
					echo "  Expected: $task_files" >&2
					return 1
				fi
			fi
			proof_of_work=true
			echo "[plan-db-safe] Proof-of-work: $(echo "$all_changed" | wc -l | tr -d ' ') file(s) changed" >&2
		fi
	fi

	if [[ -n "$task_verify" && "$task_verify" != "[]" && "$task_verify" != "null" ]]; then
		local verify_cmds
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
			local verify_failures=0
			local verify_work_dir
			verify_work_dir=$(plan_db_safe_resolve_worktree "$task_db_id" "$plan_id")
			while IFS= read -r vcmd; do
				[[ -z "$vcmd" ]] && continue
				[[ "$vcmd" != *"/"* && "$vcmd" != *"."* && "$vcmd" != *"$"* ]] && continue
				echo "[plan-db-safe] Running verify: $vcmd (in $verify_work_dir)" >&2
				if ! (cd "$verify_work_dir" && export PATH="$HOME/.npm-global/bin:$HOME/.local/bin:/opt/homebrew/bin:/usr/local/bin:$PATH" && bash -c "$vcmd") >/dev/null 2>&1; then
					echo "REJECTED: Verify command failed: $vcmd" >&2
					verify_failures=$((verify_failures + 1))
				fi
			done <<<"$verify_cmds"
			if [[ "$verify_failures" -gt 0 ]]; then
				echo "REJECTED: $verify_failures verify command(s) failed for task $task_id_str" >&2
				return 1
			fi
		fi
	fi

	return 0
}
