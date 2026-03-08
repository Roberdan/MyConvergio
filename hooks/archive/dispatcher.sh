#!/usr/bin/env bash
# dispatcher.sh — unified PreToolUse Bash dispatcher (ADR-0027 c-dispatcher pattern)
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=hooks/lib/hook-checks.sh
source "$SCRIPT_DIR/lib/hook-checks.sh"

ROUTE_BASH_CHECKS="check_gh_auto_token check_env_vault_guard check_worktree_guard check_warn_bash_antipatterns check_prefer_ci_summary check_warn_infra_plan_drift check_enforce_execution_preflight check_plan_db_validation_hints"

route_for_tool() {
	case "${1:-}" in
	bash | shell) echo "$ROUTE_BASH_CHECKS" ;;
	*) echo "" ;;
	esac
}

self_test() {
	command -v jq >/dev/null 2>&1 || {
		echo "self-test: jq missing" >&2
		return 1
	}
	[[ -f "$SCRIPT_DIR/lib/hook-checks.sh" ]] || {
		echo "self-test: missing hooks/lib/hook-checks.sh" >&2
		return 1
	}
	local required=(
		check_gh_auto_token check_worktree_guard check_warn_bash_antipatterns
		check_prefer_ci_summary check_warn_infra_plan_drift
		check_enforce_execution_preflight check_plan_db_validation_hints
	)
	local fn
	for fn in "${required[@]}"; do
		declare -F "$fn" >/dev/null || {
			echo "self-test: missing function $fn" >&2
			return 1
		}
	done
	[[ -n "$(route_for_tool bash)" ]] || {
		echo "self-test: missing bash route" >&2
		return 1
	}
	echo "dispatcher self-test: OK"
}

if [[ "${1:-}" == "--self-test" ]]; then
	self_test
	exit $?
fi

INPUT_JSON="$(cat)"
IFS=$'\t' read -r TOOL_NAME COMMAND <<<"$(printf '%s' "$INPUT_JSON" | jq -r '[((.toolName // .tool_name // "") | ascii_downcase), (.toolArgs.command // .tool_input.command // "")] | @tsv' 2>/dev/null || printf '\t')"

[[ -n "${TOOL_NAME:-}" ]] || exit 0
CHECKS="$(route_for_tool "$TOOL_NAME")"
[[ -n "$CHECKS" ]] || exit 0

export INPUT_JSON TOOL_NAME COMMAND DISPATCH_DECISION_JSON DISPATCH_ENV_GH_TOKEN

for check_fn in $CHECKS; do
	"$check_fn" || rc=$?
	rc="${rc:-0}"
	if [[ "$rc" -eq 2 ]]; then
		exit 2
	fi
	if [[ -n "${DISPATCH_DECISION_JSON:-}" ]]; then
		printf '%s\n' "$DISPATCH_DECISION_JSON"
		exit 0
	fi
	rc=0
done

if [[ -n "${DISPATCH_ENV_GH_TOKEN:-}" ]]; then
	jq -cn --arg token "$DISPATCH_ENV_GH_TOKEN" '{result:"approve",env:{GH_TOKEN:$token}}'
fi

exit 0
