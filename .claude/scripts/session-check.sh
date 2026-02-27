#!/usr/bin/env bash
# Version: 1.0.0
# Fast session status script — outputs JSON in <5s
# No web calls except gh pr list (3s timeout)
set -euo pipefail

DB="$HOME/.claude/data/dashboard.db"
TIMESTAMP=$(date -u '+%Y-%m-%dT%H:%M:%SZ')

# --- Git status ---
BRANCH=$(git -C "$HOME/.claude" rev-parse --abbrev-ref HEAD 2>/dev/null || echo "unknown")
PORCELAIN=$(git -C "$HOME/.claude" status --porcelain 2>/dev/null || echo "")
UNCOMMITTED=$(echo "$PORCELAIN" | grep -c . || true)
UNPUSHED=$(git -C "$HOME/.claude" rev-list "@{u}..HEAD" --count 2>/dev/null || echo 0)
CLEAN=$([[ "$UNCOMMITTED" -eq 0 && "$UNPUSHED" -eq 0 ]] && echo true || echo false)

GIT_STATUS=$(jq -n \
	--arg branch "$BRANCH" \
	--argjson clean "$CLEAN" \
	--argjson uncommitted "$UNCOMMITTED" \
	--argjson unpushed "$UNPUSHED" \
	'{branch: $branch, clean: $clean, uncommitted: $uncommitted, unpushed: $unpushed}')

# --- Plans from DB ---
PLANS_JSON="[]"
STUCK_WAVE_MESSAGES="[]"
STALE_TASK_MESSAGES="[]"

if [[ -f "$DB" ]]; then
	# Active/recent plans (doing or todo)
	PLANS_ROWS=$(sqlite3 -separator $'\t' "$DB" \
		"SELECT id, name, status, tasks_done, tasks_total FROM plans
     WHERE status IN ('doing','todo')
     ORDER BY id DESC LIMIT 10;" 2>/dev/null || echo "")

	if [[ -n "$PLANS_ROWS" ]]; then
		PLANS_JSON=$(echo "$PLANS_ROWS" | awk -F'\t' '{
      printf "{\"id\":%s,\"name\":%s,\"status\":%s,\"progress\":\"%s/%s\",\"waves_stuck\":0}\n",
        $1, "\"" $2 "\"", "\"" $3 "\"", $4, $5
    }' | jq -s '.')
	fi

	# Waves stuck in merging state — count per plan
	STUCK_WAVES=$(sqlite3 -separator $'\t' "$DB" \
		"SELECT w.plan_id, p.name, w.wave_id, COUNT(*) as cnt
     FROM waves w
     JOIN plans p ON p.id = w.plan_id
     WHERE w.status = 'merging'
     GROUP BY w.plan_id, p.name, w.wave_id;" 2>/dev/null || echo "")

	if [[ -n "$STUCK_WAVES" ]]; then
		# Update waves_stuck count per plan in PLANS_JSON
		while IFS=$'\t' read -r plan_id plan_name wave_id cnt; do
			PLANS_JSON=$(echo "$PLANS_JSON" | jq \
				--argjson pid "$plan_id" \
				--argjson cnt "$cnt" \
				'map(if .id == $pid then .waves_stuck += $cnt else . end)')
			STUCK_WAVE_MESSAGES=$(echo "$STUCK_WAVE_MESSAGES" | jq \
				--arg msg "Wave $wave_id stuck in merging state (plan $plan_id: $plan_name)" \
				'. + [$msg]')
		done <<<"$STUCK_WAVES"
	fi

	# Stale in_progress tasks (older than 2h)
	STALE_TASKS=$(sqlite3 -separator $'\t' "$DB" \
		"SELECT t.task_id, t.title, t.plan_id
     FROM tasks t
     WHERE t.status = 'in_progress'
       AND t.started_at < datetime('now', '-2 hours')
     LIMIT 5;" 2>/dev/null || echo "")

	if [[ -n "$STALE_TASKS" ]]; then
		while IFS=$'\t' read -r task_id title plan_id; do
			STALE_TASK_MESSAGES=$(echo "$STALE_TASK_MESSAGES" | jq \
				--arg msg "Task $task_id ('$title') in_progress >2h (plan $plan_id)" \
				'. + [$msg]')
		done <<<"$STALE_TASKS"
	fi
fi

# --- Open PRs (gh with 3s timeout) ---
OPEN_PRS="[]"
if command -v gh &>/dev/null; then
	PR_RAW=$(timeout 3 gh pr list --state open --limit 5 \
		--json number,title,state,statusCheckRollup 2>/dev/null || echo "[]")
	if [[ "$PR_RAW" != "[]" && -n "$PR_RAW" ]]; then
		OPEN_PRS=$(echo "$PR_RAW" | jq '[.[] | {
      number: .number,
      title: .title,
      state: .state,
      ci: (
        if (.statusCheckRollup | length) == 0 then "unknown"
        elif (.statusCheckRollup | all(.conclusion == "SUCCESS")) then "passing"
        elif (.statusCheckRollup | any(.conclusion == "FAILURE")) then "failing"
        else "pending"
        end
      )
    }]' 2>/dev/null || echo "[]")
	fi
fi

# --- Forgotten array ---
FORGOTTEN="[]"
if [[ "$UNCOMMITTED" -gt 0 ]]; then
	FORGOTTEN=$(echo "$FORGOTTEN" | jq --argjson n "$UNCOMMITTED" \
		'. + ["\($n) uncommitted file(s) in current directory"]')
fi
if [[ "$UNPUSHED" -gt 0 ]]; then
	FORGOTTEN=$(echo "$FORGOTTEN" | jq --argjson n "$UNPUSHED" \
		'. + ["\($n) unpushed commit(s)"]')
fi
FORGOTTEN=$(echo "$FORGOTTEN" | jq \
	--argjson stuck "$STUCK_WAVE_MESSAGES" \
	--argjson stale "$STALE_TASK_MESSAGES" \
	'. + $stuck + $stale')

# --- Next steps ---
NEXT_STEPS="[]"

# Per plan: remaining tasks
if [[ -f "$DB" ]]; then
	REMAINING=$(sqlite3 -separator $'\t' "$DB" \
		"SELECT id, name, (tasks_total - tasks_done) as remaining
     FROM plans
     WHERE status IN ('doing','todo') AND (tasks_total - tasks_done) > 0
     ORDER BY id DESC LIMIT 5;" 2>/dev/null || echo "")
	if [[ -n "$REMAINING" ]]; then
		while IFS=$'\t' read -r pid pname rem; do
			NEXT_STEPS=$(echo "$NEXT_STEPS" | jq \
				--arg msg "Complete remaining $rem task(s) in plan $pid ($pname)" \
				'. + [$msg]')
		done <<<"$REMAINING"
	fi
fi

# Stuck waves
if [[ $(echo "$STUCK_WAVE_MESSAGES" | jq 'length') -gt 0 ]]; then
	NEXT_STEPS=$(echo "$NEXT_STEPS" | jq \
		'. + ["Fix stuck merging waves (see forgotten array)"]')
fi

# Unpushed commits
if [[ "$UNPUSHED" -gt 0 ]]; then
	NEXT_STEPS=$(echo "$NEXT_STEPS" | jq '. + ["Push unpushed commits"]')
fi

# PRs ready to merge
MERGEABLE_PRS=$(echo "$OPEN_PRS" | jq '[.[] | select(.ci == "passing")] | length')
if [[ "$MERGEABLE_PRS" -gt 0 ]]; then
	NEXT_STEPS=$(echo "$NEXT_STEPS" | jq \
		--argjson n "$MERGEABLE_PRS" \
		'. + ["Merge \($n) PR(s) with passing CI"]')
fi

# --- Final JSON ---
jq -n \
	--arg ts "$TIMESTAMP" \
	--argjson git_status "$GIT_STATUS" \
	--argjson plans "$PLANS_JSON" \
	--argjson open_prs "$OPEN_PRS" \
	--argjson forgotten "$FORGOTTEN" \
	--argjson next_steps "$NEXT_STEPS" \
	'{
    timestamp: $ts,
    git_status: $git_status,
    plans: $plans,
    open_prs: $open_prs,
    forgotten: $forgotten,
    next_steps: $next_steps
  }'
