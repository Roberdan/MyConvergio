#!/bin/bash
# Token Estimator - Estimate and reconcile token usage for plan tasks
# Usage: token-estimator.sh <estimate|reconcile> <args>
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DB_FILE="${HOME}/.claude/data/dashboard.db"
export PATH="$SCRIPT_DIR:$PATH"

# Hardcoded defaults for first-plan-ever (no historical data)
DEFAULT_EFFORT_1=15000
DEFAULT_EFFORT_2=40000
DEFAULT_EFFORT_3=90000

# --- Helpers ---

get_historical_avg() {
	local effort="$1"
	local token_range
	case "$effort" in
	1) token_range="estimated_tokens <= 25000" ;;
	2) token_range="estimated_tokens > 25000 AND estimated_tokens <= 60000" ;;
	3) token_range="estimated_tokens > 60000" ;;
	*)
		echo "0"
		return
		;;
	esac
	local avg
	avg=$(sqlite3 "$DB_FILE" "
        SELECT COALESCE(CAST(ROUND(AVG(actual_tokens)) AS INTEGER), 0)
        FROM plan_token_estimates
        WHERE actual_tokens IS NOT NULL AND $token_range;
    " 2>/dev/null || echo "0")
	echo "${avg:-0}"
}

get_default_for_effort() {
	local effort="$1"
	local hist
	hist=$(get_historical_avg "$effort")
	if [[ "$hist" -gt 0 ]]; then
		echo "$hist"
		return
	fi
	case "$effort" in
	1) echo "$DEFAULT_EFFORT_1" ;;
	2) echo "$DEFAULT_EFFORT_2" ;;
	3) echo "$DEFAULT_EFFORT_3" ;;
	*) echo "$DEFAULT_EFFORT_2" ;;
	esac
}

# --- Subcommands ---

cmd_estimate() {
	local plan_id="${1:?plan_id required}"
	local spec_file="${2:?spec_file required}"
	shift 2
	local dry_run=0
	while [[ $# -gt 0 ]]; do
		case "$1" in
		--dry-run)
			dry_run=1
			shift
			;;
		*) shift ;;
		esac
	done

	if [[ ! -f "$spec_file" ]]; then
		echo "ERROR: Spec file not found: $spec_file" >&2
		exit 1
	fi

	# Check if historical data exists
	local hist_count
	hist_count=$(sqlite3 "$DB_FILE" "
        SELECT COUNT(*) FROM plan_token_estimates WHERE actual_tokens IS NOT NULL;
    " 2>/dev/null || echo "0")

	if [[ "$hist_count" -eq 0 ]]; then
		echo "[INFO] No historical data — using hardcoded defaults (effort 1=${DEFAULT_EFFORT_1}, 2=${DEFAULT_EFFORT_2}, 3=${DEFAULT_EFFORT_3})"
	else
		echo "[INFO] Using historical calibration from $hist_count samples"
	fi

	# Parse spec (JSON or YAML): extract tasks with effort
	local tasks
	tasks=$(python3 -c "
import json, sys
spec_path = '$spec_file'
with open(spec_path) as f:
    if spec_path.endswith(('.yaml', '.yml')):
        import yaml; spec = yaml.safe_load(f)
    else:
        spec = json.load(f)
pid = spec.get('plan_id', $plan_id)
for wave in spec.get('waves', []):
    wid = wave.get('id', 'W0')
    for task in wave.get('tasks', []):
        tid = task.get('id', 'T0-00')
        effort = task.get('effort', 2)
        title = task.get('title', '')
        print(f'{tid}|{effort}|{title}|{wid}')
" 2>/dev/null)

	if [[ -z "$tasks" ]]; then
		echo "ERROR: No tasks found in spec file" >&2
		exit 1
	fi

	local total_tokens=0 task_count=0
	echo ""
	printf "%-10s %-6s %-12s %s\n" "Task" "Effort" "Est.Tokens" "Title"
	printf "%-10s %-6s %-12s %s\n" "----" "------" "----------" "-----"

	while IFS='|' read -r tid effort title wid; do
		local est_tokens
		est_tokens=$(get_default_for_effort "$effort")
		total_tokens=$((total_tokens + est_tokens))
		task_count=$((task_count + 1))

		printf "%-10s %-6s %-12s %s\n" "$tid" "$effort" "$est_tokens" "$title"

		if [[ "$dry_run" -eq 0 ]]; then
			plan-db.sh estimate-tokens "$plan_id" task "$tid" "$est_tokens" \
				--notes "effort=$effort, auto-estimated" 2>/dev/null || true
		fi
	done <<<"$tasks"

	echo ""
	echo "Total: $task_count tasks, $total_tokens estimated tokens"
	[[ "$dry_run" -eq 1 ]] && echo "[DRY-RUN] No DB writes performed"
}

cmd_reconcile() {
	local plan_id="${1:?plan_id required}"
	shift
	local dry_run=0
	while [[ $# -gt 0 ]]; do
		case "$1" in
		--dry-run)
			dry_run=1
			shift
			;;
		*) shift ;;
		esac
	done

	# Get estimates for this plan from plan_token_estimates
	local estimates
	estimates=$(sqlite3 -separator '|' "$DB_FILE" "
        SELECT e.id, e.scope_id, e.estimated_tokens
        FROM plan_token_estimates e
        WHERE e.plan_id = $plan_id AND e.scope = 'task' AND e.actual_tokens IS NULL;
    " 2>/dev/null || echo "")

	if [[ -z "$estimates" ]]; then
		echo "[INFO] No unreconciled estimates for plan $plan_id"
		return 0
	fi

	# Get actual token usage from tasks table
	local actuals
	actuals=$(sqlite3 -separator '|' "$DB_FILE" "
        SELECT task_id, COALESCE(tokens, 0)
        FROM tasks
        WHERE plan_id = $plan_id AND status = 'done' AND tokens > 0;
    " 2>/dev/null || echo "")

	# Build lookup of task_id -> actual_tokens
	declare -A actual_map=()
	while IFS='|' read -r tid tokens; do
		[[ -z "$tid" ]] && continue
		actual_map["$tid"]="$tokens"
	done <<<"$actuals"

	local updated=0 high_variance=0
	echo ""
	printf "%-10s %-12s %-12s %-10s %s\n" "Task" "Estimated" "Actual" "Variance%" "Status"
	printf "%-10s %-12s %-12s %-10s %s\n" "----" "---------" "------" "---------" "------"

	while IFS='|' read -r est_id scope_id est_tokens; do
		[[ -z "$est_id" ]] && continue
		local actual="${actual_map[$scope_id]:-}"
		if [[ -z "$actual" ]]; then
			printf "%-10s %-12s %-12s %-10s %s\n" "$scope_id" "$est_tokens" "-" "-" "pending"
			continue
		fi

		local variance_pct=0
		if [[ "$est_tokens" -gt 0 ]]; then
			variance_pct=$(python3 -c "print(round(($actual - $est_tokens) * 100.0 / $est_tokens, 1))")
		fi
		local abs_var="${variance_pct#-}"

		local status="ok"
		if python3 -c "exit(0 if $abs_var > 100 else 1)" 2>/dev/null; then
			status="HIGH-VARIANCE"
			high_variance=$((high_variance + 1))
		fi

		printf "%-10s %-12s %-12s %-10s %s\n" "$scope_id" "$est_tokens" "$actual" "${variance_pct}%" "$status"

		if [[ "$dry_run" -eq 0 ]]; then
			plan-db.sh update-token-actuals "$est_id" "$actual" 2>/dev/null || true
			updated=$((updated + 1))

			# Flag high variance as learning
			if [[ "$status" == "HIGH-VARIANCE" ]]; then
				plan-db.sh add-learning "$plan_id" "token-estimation" "warning" \
					"High variance on $scope_id: est=$est_tokens actual=$actual (${variance_pct}%)" \
					--detail "Token estimate variance exceeded 100% threshold. Actual=$actual vs Estimated=$est_tokens." \
					--task-id "$scope_id" --actionable 2>/dev/null || true
			fi
		fi
	done <<<"$estimates"

	echo ""
	echo "Reconciled: $updated estimates updated, $high_variance high-variance flagged"
	[[ "$dry_run" -eq 1 ]] && echo "[DRY-RUN] No DB writes performed"
}

# --- Main ---

case "${1:-}" in
estimate)
	shift
	cmd_estimate "$@"
	;;
reconcile)
	shift
	cmd_reconcile "$@"
	;;
-h | --help | "")
	echo "Usage: token-estimator.sh <command> [args]"
	echo ""
	echo "Commands:"
	echo "  estimate <plan_id> <spec_file> [--dry-run]"
	echo "    Read spec (JSON or YAML), estimate tokens per task using historical data"
	echo "  reconcile <plan_id> [--dry-run]"
	echo "    Compare estimates with actuals, flag high variance"
	echo ""
	echo "Defaults (no history): effort 1=${DEFAULT_EFFORT_1}, 2=${DEFAULT_EFFORT_2}, 3=${DEFAULT_EFFORT_3}"
	;;
*)
	echo "ERROR: Unknown command '$1'. Use -h for help." >&2
	exit 1
	;;
esac
