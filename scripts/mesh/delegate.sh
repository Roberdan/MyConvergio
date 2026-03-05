#!/usr/bin/env bash
# delegate.sh - Smart routing for delegated task execution
# Usage: delegate.sh <db_task_id> [--engine <claude|copilot|opencode|gemini>] [--model <model>]
# Version: 1.0.0
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DB_FILE="${DB_FILE:-${CLAUDE_HOME:-$HOME/.claude}/data/dashboard.db}"
ORCHESTRATOR_YAML="${ORCHESTRATOR_YAML:-${SCRIPT_DIR}/../config/orchestrator.yaml}"
DELEGATE_UTILS="${SCRIPT_DIR}/lib/delegate-utils.sh"

if [[ ! -f "$DELEGATE_UTILS" ]]; then
	echo "ERROR: Missing utilities: $DELEGATE_UTILS" >&2
	exit 1
fi
source "$DELEGATE_UTILS"

TASK_DB_ID="${1:-}"
shift || true
FORCE_ENGINE=""
FORCE_MODEL=""

while [[ $# -gt 0 ]]; do
	case "$1" in
	--engine)
		FORCE_ENGINE="${2:-}"
		shift 2
		;;
	--model)
		FORCE_MODEL="${2:-}"
		shift 2
		;;
	*) shift ;;
	esac
done

if [[ -z "$TASK_DB_ID" || ! "$TASK_DB_ID" =~ ^[0-9]+$ ]]; then
	echo "Usage: delegate.sh <db_task_id> [--engine <agent>] [--model <model>]" >&2
	exit 1
fi

if [[ ! -f "$DB_FILE" ]]; then
	echo "ERROR: DB not found: $DB_FILE" >&2
	exit 1
fi
if [[ ! -f "$ORCHESTRATOR_YAML" ]]; then
	echo "ERROR: orchestrator.yaml not found: $ORCHESTRATOR_YAML" >&2
	exit 1
fi

read_task_row() {
	sqlite3 "$DB_FILE" "
SELECT
  COALESCE(t.executor_agent, ''),
  COALESCE(t.model, ''),
  COALESCE(NULLIF(t.project_id,''), p.project_id, ''),
  COALESCE(t.plan_id, 0),
  COALESCE(p.worktree_path, '')
FROM tasks t
LEFT JOIN plans p ON p.id = t.plan_id
WHERE t.id = $TASK_DB_ID;
"
}

policy_json() {
	local project_id="${1:-}" task_model="${2:-}"
	ruby -ryaml -rjson -e '
cfg = YAML.load_file(ARGV[0]) || {}
project_id = ARGV[1].to_s
task_model = ARGV[2].to_s
providers = cfg.fetch("providers", {}) || {}
projects = cfg.fetch("projects", {}) || {}
budget = cfg.fetch("budget", {}) || {}
privacy = projects.fetch(project_id, {}).fetch("privacy", "public")
premium = providers.each_with_object([]) { |(k,v), out| out << k if (v || {})["cost_tier"] == "premium" }
mult = nil
providers.each_value do |provider|
  models = (provider || {})["models"] || []
  model = models.find { |m| (m || {})["id"].to_s == task_model }
  if model
    mult = model["multiplier"]
    break
  end
end
print({
  privacy: privacy,
  enforce_budget: budget.fetch("enforce_budget", false),
  max_premium_per_day: budget.fetch("max_premium_per_day", 0).to_f,
  premium_providers: premium,
  model_multiplier: mult
}.to_json)
' "$ORCHESTRATOR_YAML" "$project_id" "$task_model"
}

is_numeric_nonzero() {
	[[ "$1" =~ ^[0-9]+([.][0-9]+)?$ ]] && [[ "$1" != "0" ]] && [[ "$1" != "0.0" ]]
}

contains_provider() {
	local provider="${1:?provider required}"
	shift || true
	local item
	for item in "$@"; do
		[[ "$item" == "$provider" ]] && return 0
	done
	return 1
}

TASK_ROW="$(read_task_row)"
if [[ -z "$TASK_ROW" ]]; then
	echo "ERROR: task not found for db_task_id=$TASK_DB_ID" >&2
	exit 1
fi

IFS='|' read -r TASK_AGENT TASK_MODEL PROJECT_ID PLAN_ID WORKTREE_PATH <<<"$TASK_ROW"
[[ -n "$FORCE_ENGINE" ]] && TASK_AGENT="$FORCE_ENGINE"
[[ -n "$FORCE_MODEL" ]] && TASK_MODEL="$FORCE_MODEL"
[[ -z "$TASK_AGENT" || "$TASK_AGENT" == "null" ]] && TASK_AGENT="copilot"
[[ "$TASK_AGENT" == "codex" ]] && TASK_AGENT="copilot"

WORKTREE_PATH="${WORKTREE_PATH/#\~/$HOME}"
WORKTREE_SAFETY="${SCRIPT_DIR}/worktree-safety.sh"
if [[ -x "$WORKTREE_SAFETY" && -n "$WORKTREE_PATH" ]]; then
	(cd "$WORKTREE_PATH" && "$WORKTREE_SAFETY" pre-check) || exit $?
fi

POLICY_JSON="$(policy_json "$PROJECT_ID" "$TASK_MODEL")"
PROJECT_PRIVACY="$(echo "$POLICY_JSON" | jq -r '.privacy // "public"')"
ENFORCE_BUDGET="$(echo "$POLICY_JSON" | jq -r '.enforce_budget // false')"
MAX_PREMIUM_PER_DAY="$(echo "$POLICY_JSON" | jq -r '.max_premium_per_day // 0')"
MODEL_MULTIPLIER="$(echo "$POLICY_JSON" | jq -r '.model_multiplier // "null"')"
mapfile -t PREMIUM_PROVIDERS < <(echo "$POLICY_JSON" | jq -r '.premium_providers[]?')

if [[ "$PROJECT_PRIVACY" == "sensitive" && "$MODEL_MULTIPLIER" =~ ^0([.]0+)?$ ]]; then
	log_delegation "$TASK_DB_ID" "$PLAN_ID" "$PROJECT_ID" "$TASK_AGENT" "$TASK_MODEL" \
		0 0 0 3 "BLOCKED_PRIVACY" 0 "$PROJECT_PRIVACY"
	echo "BLOCKED: privacy policy (sensitive project + free model)." >&2
	exit 3
fi

ROUTE_TARGET=""
WORKER_SCRIPT=""
case "$TASK_AGENT" in
claude)
	ROUTE_TARGET="task-executor"
	;;
copilot)
	ROUTE_TARGET="copilot-worker.sh"
	WORKER_SCRIPT="${SCRIPT_DIR}/copilot-worker.sh"
	;;
opencode)
	ROUTE_TARGET="opencode-worker.sh"
	WORKER_SCRIPT="${SCRIPT_DIR}/opencode-worker.sh"
	;;
gemini)
	ROUTE_TARGET="gemini-worker.sh"
	WORKER_SCRIPT="${SCRIPT_DIR}/gemini-worker.sh"
	;;
*)
	log_delegation "$TASK_DB_ID" "$PLAN_ID" "$PROJECT_ID" "$TASK_AGENT" "$TASK_MODEL" \
		0 0 0 2 "BLOCKED_ROUTE" 0 "$PROJECT_PRIVACY"
	echo "ERROR: Unsupported executor_agent '$TASK_AGENT'" >&2
	exit 2
	;;
esac

TODAY_PREMIUM_COUNT=0
if [[ "${#PREMIUM_PROVIDERS[@]}" -gt 0 ]]; then
	SQL_LIST=""
	for provider in "${PREMIUM_PROVIDERS[@]}"; do
		escaped="$(delegate_utils_sql_escape "$provider")"
		[[ -n "$SQL_LIST" ]] && SQL_LIST+=","
		SQL_LIST+="'$escaped'"
	done
	TODAY_PREMIUM_COUNT="$(sqlite3 "$DB_FILE" "
SELECT COUNT(*) FROM delegation_log
WHERE date(created_at) = date('now','localtime')
  AND provider IN ($SQL_LIST);
")"
fi

if [[ "$ENFORCE_BUDGET" == "true" ]] && contains_provider "$TASK_AGENT" "${PREMIUM_PROVIDERS[@]}"; then
	MAX_PREMIUM_INT="$(printf '%.0f' "$MAX_PREMIUM_PER_DAY" 2>/dev/null || echo 0)"
	if [[ "$TODAY_PREMIUM_COUNT" -ge "$MAX_PREMIUM_INT" ]]; then
		log_delegation "$TASK_DB_ID" "$PLAN_ID" "$PROJECT_ID" "$TASK_AGENT" "$TASK_MODEL" \
			0 0 0 4 "BLOCKED_BUDGET" 0 "$PROJECT_PRIVACY"
		echo "BLOCKED: budget policy (premium daily cap reached)." >&2
		exit 4
	fi
fi

echo "Routing task $TASK_DB_ID -> $ROUTE_TARGET (agent=$TASK_AGENT model=$TASK_MODEL)"

EXIT_CODE=0
case "$TASK_AGENT" in
claude)
	if ! command -v task-executor >/dev/null 2>&1; then
		echo "ERROR: task-executor command not found" >&2
		EXIT_CODE=127
	else
		worker_args=("$TASK_DB_ID")
		[[ -n "$TASK_MODEL" ]] && worker_args+=(--model "$TASK_MODEL")
		task-executor "${worker_args[@]}" || EXIT_CODE=$?
	fi
	;;
*)
	if [[ ! -x "$WORKER_SCRIPT" ]]; then
		echo "ERROR: worker script missing or not executable: $WORKER_SCRIPT" >&2
		EXIT_CODE=127
	else
		worker_args=("$TASK_DB_ID")
		[[ -n "$TASK_MODEL" ]] && worker_args+=(--model "$TASK_MODEL")
		"$WORKER_SCRIPT" "${worker_args[@]}" || EXIT_CODE=$?
	fi
	;;
esac

COST_ESTIMATE=0
if is_numeric_nonzero "$MODEL_MULTIPLIER"; then
	COST_ESTIMATE="$MODEL_MULTIPLIER"
fi
log_delegation "$TASK_DB_ID" "$PLAN_ID" "$PROJECT_ID" "$TASK_AGENT" "$TASK_MODEL" \
	0 0 0 "$EXIT_CODE" "ROUTED" "$COST_ESTIMATE" "$PROJECT_PRIVACY"

exit "$EXIT_CODE"
