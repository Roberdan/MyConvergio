#!/usr/bin/env bash
# delegate-utils.sh - Shared utilities for worker delegation scripts
# Version: 1.0.0

DELEGATE_UTILS_DB_FILE="${DELEGATE_UTILS_DB_FILE:-${CLAUDE_HOME:-$HOME/.claude}/data/dashboard.db}"
DELEGATE_UTILS_SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

delegate_utils_sql_escape() {
	printf '%s' "$1" | sed "s/'/''/g"
}

parse_yaml_field() {
	local yaml_file="${1:?yaml_file required}"
	local field_expr="${2:?field expression required}"

	if ! command -v yq >/dev/null 2>&1; then
		echo "ERROR: yq not installed" >&2
		return 1
	fi
	if [[ ! -f "$yaml_file" ]]; then
		echo "ERROR: YAML file not found: $yaml_file" >&2
		return 1
	fi

	yq eval "$field_expr" "$yaml_file"
}

check_cli_available() {
	local provider="${1:?provider required}"
	local yaml_file="${2:-${CLAUDE_HOME:-$HOME/.claude}/config/orchestrator.yaml}"
	local auth_check cli_bin

	auth_check="$(parse_yaml_field "$yaml_file" ".providers.${provider}.auth_check" 2>/dev/null || true)"
	if [[ -z "$auth_check" || "$auth_check" == "null" ]]; then
		echo "ERROR: auth_check not configured for provider '$provider'" >&2
		return 1
	fi

	cli_bin="${auth_check%% *}"
	if ! command -v "$cli_bin" >/dev/null 2>&1; then
		echo "ERROR: CLI not installed: $cli_bin" >&2
		return 1
	fi

	if [[ "$provider" == "copilot" ]]; then
		if [[ -n "${GH_TOKEN:-}" || -n "${COPILOT_TOKEN:-}" ]]; then
			return 0
		fi
	fi

	bash -lc "$auth_check" >/dev/null 2>&1
}

read_task_spec() {
	local task_db_id="${1:?task_db_id required}"

	if [[ ! "$task_db_id" =~ ^[0-9]+$ ]]; then
		echo "ERROR: task_db_id must be numeric" >&2
		return 1
	fi

	sqlite3 "$DELEGATE_UTILS_DB_FILE" "
SELECT json_object(
  'db_task_id', t.id,
  'task_id', t.task_id,
  'title', t.title,
  'description', COALESCE(t.description,''),
  'test_criteria', COALESCE(t.test_criteria,''),
  'wave_db_id', w.id,
  'wave_id', w.wave_id,
  'wave_name', w.name,
  'plan_id', p.id,
  'plan_name', p.name,
  'project_id', p.project_id,
  'worktree_path', COALESCE(p.worktree_path,'')
)
FROM tasks t
JOIN waves w ON t.wave_id_fk = w.id
JOIN plans p ON t.plan_id = p.id
WHERE t.id = $task_db_id;
"
}

build_prompt() {
	local spec_json="${1:?spec_json required}"
	local framework="${2:-unknown}"
	local task_id title description test_criteria wave_id worktree_raw worktree

	task_id="$(echo "$spec_json" | jq -r '.task_id')"
	title="$(echo "$spec_json" | jq -r '.title')"
	description="$(echo "$spec_json" | jq -r '.description')"
	test_criteria="$(echo "$spec_json" | jq -r '.test_criteria')"
	wave_id="$(echo "$spec_json" | jq -r '.wave_id')"
	worktree_raw="$(echo "$spec_json" | jq -r '.worktree_path')"
	worktree="${worktree_raw/#\~/$HOME}"

	cat <<PROMPT
# Task Execution: ${task_id} (${title})

## CRITICAL RULES
1. Work ONLY in: ${worktree}
2. NEVER checkout or work on main/master branch
3. Run \`worktree-guard.sh "${worktree}"\` FIRST. If it fails, STOP.
4. Follow TDD: write tests FIRST, then implement

## Task
**Wave**: ${wave_id} | **Task**: ${task_id} | **Framework**: ${framework}

${description}

## Test Criteria
${test_criteria}
PROMPT
}

log_delegation() {
	local task_db_id="${1:-NULL}" plan_id="${2:-NULL}" project_id="${3:-}"
	local provider="${4:-}" model="${5:-}" prompt_tokens="${6:-0}" response_tokens="${7:-0}"
	local duration_ms="${8:-0}" exit_code="${9:-1}" thor_result="${10:-UNKNOWN}"
	local cost_estimate="${11:-0}" privacy_level="${12:-public}"
	local project_id_esc provider_esc model_esc thor_result_esc privacy_level_esc

	project_id_esc="$(delegate_utils_sql_escape "$project_id")"
	provider_esc="$(delegate_utils_sql_escape "$provider")"
	model_esc="$(delegate_utils_sql_escape "$model")"
	thor_result_esc="$(delegate_utils_sql_escape "$thor_result")"
	privacy_level_esc="$(delegate_utils_sql_escape "$privacy_level")"

	sqlite3 "$DELEGATE_UTILS_DB_FILE" "
INSERT INTO delegation_log (
  task_db_id, plan_id, project_id, provider, model,
  prompt_tokens, response_tokens, duration_ms, exit_code,
  thor_result, cost_estimate, privacy_level
) VALUES (
  $task_db_id, $plan_id, '$project_id_esc', '$provider_esc', '$model_esc',
  $prompt_tokens, $response_tokens, $duration_ms, $exit_code,
  '$thor_result_esc', $cost_estimate, '$privacy_level_esc'
);"
}

verify_work_done() {
	local worktree_path="${1:?worktree_path required}"
	local wt="${worktree_path/#\~/$HOME}"
	local stat

	if [[ ! -d "$wt" ]]; then
		echo "ERROR: Worktree not found: $wt" >&2
		return 1
	fi

	stat="$(git -C "$wt" diff --stat)"
	if [[ -z "$stat" ]]; then
		stat="$(git -C "$wt" diff --cached --stat)"
	fi

	if [[ -z "$stat" ]]; then
		echo "No changes detected in $wt" >&2
		return 1
	fi

	printf '%s\n' "$stat"
	return 0
}

safe_update_task() {
	local task_db_id="${1:?task_db_id required}"
	local status="${2:?status required}"
	local notes="${3:-}"
	shift 3 || true

	if "$DELEGATE_UTILS_SCRIPT_DIR/plan-db-safe.sh" update-task "$task_db_id" "$status" "$notes" "$@"; then
		return 0
	fi

	echo "WARN: plan-db-safe update failed for task $task_db_id, attempting recovery..." >&2
	local plan_id
	plan_id="$(sqlite3 "$DELEGATE_UTILS_DB_FILE" "SELECT plan_id FROM tasks WHERE id = $task_db_id;" 2>/dev/null || true)"
	if [[ -n "$plan_id" ]]; then
		"$DELEGATE_UTILS_SCRIPT_DIR/plan-db.sh" sync "$plan_id" >/dev/null 2>&1 || true
	fi

	if "$DELEGATE_UTILS_SCRIPT_DIR/plan-db-safe.sh" update-task "$task_db_id" "$status" "$notes" "$@"; then
		return 0
	fi

	echo "ERROR: safe_update_task failed after recovery for task $task_db_id" >&2
	"$DELEGATE_UTILS_SCRIPT_DIR/plan-db.sh" update-task "$task_db_id" blocked \
		"safe_update_task recovery failed" >/dev/null 2>&1 || true
	return 1
}
