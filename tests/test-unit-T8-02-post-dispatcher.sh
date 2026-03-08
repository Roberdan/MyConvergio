#!/usr/bin/env bash
set -euo pipefail

source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/lib/test-helpers.sh"
setup_test_env

POST_DISPATCHER="$REPO_ROOT/hooks/post-dispatcher.sh"
SETTINGS_JSON="$REPO_ROOT/settings.json"

fail() {
	echo "[FAIL] $1" >&2
	exit 1
}

pass() {
	echo "[PASS] $1"
}

[[ -f "$POST_DISPATCHER" ]] || fail "hooks/post-dispatcher.sh must exist"
[[ -x "$POST_DISPATCHER" ]] || fail "hooks/post-dispatcher.sh must be executable"
pass "post-dispatcher file exists and is executable"

bash "$POST_DISPATCHER" --self-test >/dev/null || fail "post-dispatcher self-test must pass"
pass "post-dispatcher self-test passes"

line_count="$(wc -l <"$POST_DISPATCHER" | tr -d ' ')"
[[ "$line_count" -le 250 ]] || fail "post-dispatcher must be <=250 lines (got $line_count)"
pass "post-dispatcher line count <=250"

post_dispatcher_count="$(jq '[.hooks[] | select(.event == "PostToolUse") | .hooks[] | select(.type == "command" and .command == "~/.claude/scripts/c hook post")] | length' "$SETTINGS_JSON")"
[[ "$post_dispatcher_count" -eq 1 ]] || fail "settings must register exactly one c hook post command (got $post_dispatcher_count)"
pass "settings register single c hook post command"

old_hook_count="$(jq '[.hooks[] | select(.event == "PostToolUse") | .hooks[] | select(.type == "command" and (.command == "~/.claude/hooks/verify-before-claim.sh" or .command == "~/.claude/hooks/pii-advisory.sh"))] | length' "$SETTINGS_JSON")"
[[ "$old_hook_count" -eq 0 ]] || fail "settings must not directly call verify-before-claim.sh or pii-advisory.sh (got $old_hook_count)"
pass "legacy sequential post hooks removed from settings"

echo "[OK] T8-02 criteria satisfied"
