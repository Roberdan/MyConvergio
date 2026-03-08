#!/usr/bin/env bash
set -euo pipefail

source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/lib/test-helpers.sh"
setup_test_env

SETTINGS_JSON="$REPO_ROOT/settings.json"

fail() {
	echo "[FAIL] $1" >&2
	exit 1
}

pass() {
	echo "[PASS] $1"
}

[[ -f "$SETTINGS_JSON" ]] || fail "settings.json must exist"

pre_count="$(python3 -c "import json; h=json.load(open('$SETTINGS_JSON'))['hooks']; pre=[x for x in h if x.get('event')=='PreToolUse']; print(len(pre))")"
[[ "$pre_count" -eq 1 ]] || fail "Expected exactly 1 PreToolUse event entry (got $pre_count)"
pass "PreToolUse has one event entry"

post_count="$(python3 -c "import json; h=json.load(open('$SETTINGS_JSON'))['hooks']; post=[x for x in h if x.get('event')=='PostToolUse']; print(len(post))")"
[[ "$post_count" -eq 1 ]] || fail "Expected exactly 1 PostToolUse event entry (got $post_count)"
pass "PostToolUse has one event entry"

pre_command="$(jq -r '.hooks[] | select(.event=="PreToolUse") | .hooks[0].command' "$SETTINGS_JSON")"
[[ "$pre_command" == "~/.claude/scripts/c hook pre" ]] || fail "PreToolUse hook command must be c hook pre"
pass "PreToolUse uses c hook pre"

post_command="$(jq -r '.hooks[] | select(.event=="PostToolUse") | .hooks[0].command' "$SETTINGS_JSON")"
[[ "$post_command" == "~/.claude/scripts/c hook post" ]] || fail "PostToolUse hook command must be c hook post"
pass "PostToolUse uses c hook post"

user_prompt_submit_count="$(jq '[.hooks[] | select(.event=="UserPromptSubmit")] | length' "$SETTINGS_JSON")"
[[ "$user_prompt_submit_count" -eq 0 ]] || fail "UserPromptSubmit must remain unchanged (expected absent)"
pass "UserPromptSubmit unchanged (absent)"

stop_count="$(jq '[.hooks[] | select(.event=="Stop")] | length' "$SETTINGS_JSON")"
[[ "$stop_count" -eq 4 ]] || fail "Stop hooks must remain unchanged (expected 4 entries, got $stop_count)"
pass "Stop hooks unchanged"

echo "[OK] T8-03 criteria satisfied"
