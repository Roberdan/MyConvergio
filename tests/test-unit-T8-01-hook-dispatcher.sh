#!/usr/bin/env bash
set -euo pipefail

source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/lib/test-helpers.sh"
setup_test_env

DISPATCHER="$REPO_ROOT/hooks/dispatcher.sh"
SETTINGS_JSON="$REPO_ROOT/settings.json"

fail() {
	echo "[FAIL] $1" >&2
	exit 1
}

pass() {
	echo "[PASS] $1"
}

[[ -f "$DISPATCHER" ]] || fail "hooks/dispatcher.sh must exist"
[[ -x "$DISPATCHER" ]] || fail "hooks/dispatcher.sh must be executable"
pass "dispatcher file exists and is executable"

bash "$DISPATCHER" --self-test >/dev/null || fail "dispatcher self-test must pass"
pass "dispatcher self-test passes"

line_count="$(wc -l <"$DISPATCHER" | tr -d ' ')"
[[ "$line_count" -le 250 ]] || fail "dispatcher must be <=250 lines (got $line_count)"
pass "dispatcher line count <=250"

bash_hook_count="$(jq '[.hooks[] | select(.event == "PreToolUse" and .matcher == "Bash") | .hooks[]] | length' "$SETTINGS_JSON")"
[[ "$bash_hook_count" -eq 1 ]] || fail "Bash PreToolUse must have exactly 1 hook (got $bash_hook_count)"
pass "Bash PreToolUse has single hook"

bash_hook_cmd="$(jq -r '.hooks[] | select(.event == "PreToolUse" and .matcher == "Bash") | .hooks[0].command' "$SETTINGS_JSON")"
[[ "$bash_hook_cmd" == "~/.claude/scripts/c hook pre" ]] || fail "Bash PreToolUse command must be ~/.claude/scripts/c hook pre"
pass "Bash PreToolUse uses c hook pre"

echo "[OK] T8-01 criteria satisfied"
