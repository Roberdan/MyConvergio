#!/bin/bash
# plan-checkpoint.sh — Save/restore plan execution state for context continuity
# Solves: coordinator context compaction losing plan state mid-execution
# Called by: preserve-context.sh (PreCompact hook), coordinator manually, plan-db-safe.sh
# Version: 1.0.0
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DB_FILE="$HOME/.claude/data/dashboard.db"
CHECKPOINT_DIR="$HOME/.claude/data/checkpoints"
MEMORY_DIR=""

usage() {
	cat <<'EOF'
Usage: plan-checkpoint.sh <command> [args]
  save <plan_id>              Save plan state to checkpoint file + auto-memory
  restore <plan_id>           Print checkpoint for context injection
  save-auto [transcript]      Auto-detect plan_id from DB (for hooks)
  status                      List all active checkpoints
EOF
	exit 1
}

# Resolve project memory dir from plan's project path
resolve_memory_dir() {
	local plan_id="$1"
	local project_path
	project_path=$(sqlite3 "$DB_FILE" "
		SELECT p.path FROM projects p
		JOIN plans pl ON pl.project_id = p.id
		WHERE pl.id = $plan_id;" 2>/dev/null || echo "")

	if [[ -n "$project_path" ]]; then
		local slug
		slug=$(echo "$project_path" | sed 's|/|-|g; s|^-||')
		MEMORY_DIR="$HOME/.claude/projects/-${slug}/memory"
	fi
}

# Core: save plan state
save_checkpoint() {
	local plan_id="$1"
	mkdir -p "$CHECKPOINT_DIR"

	# Query all state in one sqlite3 call
	local state
	state=$(sqlite3 -json "$DB_FILE" "
		SELECT
			pl.id as plan_id,
			pl.name as plan_name,
			pl.status as plan_status,
			(SELECT branch_name FROM waves WHERE plan_id = pl.id AND status = 'in_progress' LIMIT 1) as branch,
			(SELECT worktree_path FROM waves WHERE plan_id = pl.id AND status = 'in_progress' LIMIT 1) as worktree,
			(SELECT w.wave_id FROM waves w WHERE w.plan_id = pl.id AND w.status = 'in_progress' LIMIT 1) as current_wave,
			(SELECT w.id FROM waves w WHERE w.plan_id = pl.id AND w.status = 'in_progress' LIMIT 1) as wave_db_id,
			(SELECT pr_number FROM waves WHERE plan_id = pl.id AND pr_number IS NOT NULL ORDER BY id DESC LIMIT 1) as last_pr
		FROM plans pl WHERE pl.id = $plan_id;
	" 2>/dev/null) || {
		echo "ERROR: Plan $plan_id not found" >&2
		return 1
	}

	# Task summary per wave
	local tasks
	tasks=$(sqlite3 "$DB_FILE" "
		SELECT t.task_id, t.status, t.title
		FROM tasks t
		JOIN waves w ON t.wave_id_fk = w.id
		WHERE w.plan_id = $plan_id
		ORDER BY w.id, t.id;
	" 2>/dev/null) || tasks=""

	# Count by status
	local done_count pending_count inprog_count submitted_count
	done_count=$(echo "$tasks" | grep -c '|done|' || true)
	pending_count=$(echo "$tasks" | grep -c '|pending|' || true)
	inprog_count=$(echo "$tasks" | grep -c '|in_progress|' || true)
	submitted_count=$(echo "$tasks" | grep -c '|submitted|' || true)

	# Extract fields from JSON
	local plan_name branch worktree current_wave wave_db_id last_pr
	plan_name=$(echo "$state" | /usr/bin/python3 -c "import json,sys; d=json.load(sys.stdin)[0]; print(d.get('plan_name',''))" 2>/dev/null || echo "")
	branch=$(echo "$state" | /usr/bin/python3 -c "import json,sys; d=json.load(sys.stdin)[0]; print(d.get('branch') or '')" 2>/dev/null || echo "")
	worktree=$(echo "$state" | /usr/bin/python3 -c "import json,sys; d=json.load(sys.stdin)[0]; print(d.get('worktree') or '')" 2>/dev/null || echo "")
	current_wave=$(echo "$state" | /usr/bin/python3 -c "import json,sys; d=json.load(sys.stdin)[0]; print(d.get('current_wave') or '')" 2>/dev/null || echo "")
	wave_db_id=$(echo "$state" | /usr/bin/python3 -c "import json,sys; d=json.load(sys.stdin)[0]; print(d.get('wave_db_id') or '')" 2>/dev/null || echo "")
	last_pr=$(echo "$state" | /usr/bin/python3 -c "import json,sys; d=json.load(sys.stdin)[0]; print(d.get('last_pr') or '')" 2>/dev/null || echo "")

	local timestamp
	timestamp=$(date '+%Y-%m-%d %H:%M:%S')

	# Build task details section
	local task_details=""
	while IFS='|' read -r tid tstatus ttitle; do
		[[ -z "$tid" ]] && continue
		case "$tstatus" in
		done) task_details="${task_details}- [x] ${tid}: ${ttitle}\n" ;;
		submitted) task_details="${task_details}- [~] ${tid}: ${ttitle} (Thor pending)\n" ;;
		in_progress) task_details="${task_details}- [>] ${tid}: ${ttitle} (running)\n" ;;
		pending) task_details="${task_details}- [ ] ${tid}: ${ttitle}\n" ;;
		*) task_details="${task_details}- [?] ${tid}: ${ttitle} [${tstatus}]\n" ;;
		esac
	done <<<"$tasks"

	# Write checkpoint file
	local checkpoint_file="$CHECKPOINT_DIR/plan-${plan_id}.md"
	{
		echo "# Plan $plan_id Checkpoint"
		echo "Updated: $timestamp"
		echo ""
		echo "## State"
		echo "- **Plan**: $plan_name [$plan_id]"
		echo "- **Wave**: $current_wave (DB: $wave_db_id)"
		echo "- **Branch**: $branch"
		echo "- **Worktree**: $worktree"
		echo "- **Last PR**: ${last_pr:-none}"
		echo "- **Tasks**: $done_count done, $submitted_count submitted, $inprog_count in_progress, $pending_count pending"
		echo ""
		echo "## Task Details"
		printf '%b' "$task_details"
		echo ""
		echo "## Recovery"
		echo '```bash'
		echo "plan-db.sh execution-tree $plan_id"
		echo "cd $worktree"
		echo '```'
	} >"$checkpoint_file"

	echo "$checkpoint_file"

	# Also update auto-memory if available
	resolve_memory_dir "$plan_id"
	if [[ -n "$MEMORY_DIR" ]] && [[ -d "$MEMORY_DIR" ]]; then
		update_memory "$plan_id" "$current_wave" "$wave_db_id" "$branch" "$worktree" \
			"$done_count" "$submitted_count" "$inprog_count" "$pending_count" "$last_pr"
	fi
}

# Update MEMORY.md with checkpoint section
update_memory() {
	local plan_id="$1" wave="$2" wave_db="$3" branch="$4" worktree="$5"
	local done="$6" submitted="$7" inprog="$8" pending="$9" pr="${10:-}"

	local memory_file="$MEMORY_DIR/MEMORY.md"
	[[ -f "$memory_file" ]] || return 0

	local marker_start="## Active Plan Checkpoint"
	local marker_end="## "
	local checkpoint_block
	checkpoint_block=$(
		cat <<BLOCK
## Active Plan Checkpoint
- PLAN_ID: $plan_id | WAVE: $wave (DB:$wave_db) | BRANCH: $branch
- WORKTREE: $worktree | PR: ${pr:-none}
- Tasks: $done done, $submitted submitted, $inprog running, $pending pending
- Recovery: \`plan-db.sh execution-tree $plan_id\` then \`cd $worktree\`
BLOCK
	)

	# Replace existing checkpoint block or append
	if grep -q "$marker_start" "$memory_file" 2>/dev/null; then
		# Use python for reliable multi-line replacement
		/usr/bin/python3 -c "
import re, sys
content = open('$memory_file').read()
pattern = r'## Active Plan Checkpoint\n.*?(?=\n## |\Z)'
replacement = '''$checkpoint_block'''
result = re.sub(pattern, replacement, content, flags=re.DOTALL)
open('$memory_file', 'w').write(result)
" 2>/dev/null
	else
		echo "" >>"$memory_file"
		echo "$checkpoint_block" >>"$memory_file"
	fi
}

# Auto-detect active plan from DB
save_auto() {
	local plan_id
	plan_id=$(sqlite3 "$DB_FILE" "
		SELECT id FROM plans WHERE status = 'doing' ORDER BY id DESC LIMIT 1;
	" 2>/dev/null || echo "")

	if [[ -z "$plan_id" ]]; then
		echo "No active plan found" >&2
		exit 0
	fi

	save_checkpoint "$plan_id"
}

# Restore: print checkpoint content for context injection
restore_checkpoint() {
	local plan_id="$1"
	local checkpoint_file="$CHECKPOINT_DIR/plan-${plan_id}.md"

	if [[ -f "$checkpoint_file" ]]; then
		cat "$checkpoint_file"
	else
		echo "No checkpoint for plan $plan_id" >&2
		# Fallback: generate fresh from DB
		save_checkpoint "$plan_id" >/dev/null
		[[ -f "$checkpoint_file" ]] && cat "$checkpoint_file"
	fi
}

# Status: list all checkpoints
show_status() {
	if [[ ! -d "$CHECKPOINT_DIR" ]] || [[ -z "$(ls "$CHECKPOINT_DIR"/*.md 2>/dev/null)" ]]; then
		echo "No checkpoints found"
		return 0
	fi

	for f in "$CHECKPOINT_DIR"/plan-*.md; do
		local pid
		pid=$(basename "$f" .md | sed 's/plan-//')
		local updated
		updated=$(stat -f '%Sm' -t '%Y-%m-%d %H:%M' "$f" 2>/dev/null || echo "?")
		local wave
		wave=$(grep -m1 'Wave' "$f" | sed 's/.*Wave[*]*: //' | sed 's/ .*//' || echo "?")
		echo "Plan $pid | $wave | Updated: $updated"
	done
}

# Main dispatch
case "${1:-}" in
save) save_checkpoint "${2:?plan_id required}" ;;
restore) restore_checkpoint "${2:?plan_id required}" ;;
save-auto) save_auto ;;
status) show_status ;;
*) usage ;;
esac
