#!/usr/bin/env bash
# post-dispatcher.sh — unified PostToolUse dispatcher for Bash/Shell/Write hooks
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
VERIFY_HOOK="$SCRIPT_DIR/verify-before-claim.sh"
PII_HOOK="$SCRIPT_DIR/pii-advisory.sh"

route_for_tool() {
	case "${1:-}" in
	bash | shell) echo "$VERIFY_HOOK $PII_HOOK" ;;
	write | writefile) echo "$VERIFY_HOOK" ;;
	*) echo "" ;;
	esac
}

self_test() {
	command -v jq >/dev/null 2>&1 || {
		echo "self-test: jq missing" >&2
		return 1
	}
	[[ -f "$VERIFY_HOOK" ]] || {
		echo "self-test: missing hooks/verify-before-claim.sh" >&2
		return 1
	}
	[[ -f "$PII_HOOK" ]] || {
		echo "self-test: missing hooks/pii-advisory.sh" >&2
		return 1
	}
	[[ -n "$(route_for_tool bash)" ]] || {
		echo "self-test: missing bash route" >&2
		return 1
	}
	[[ -n "$(route_for_tool shell)" ]] || {
		echo "self-test: missing shell route" >&2
		return 1
	}
	[[ -n "$(route_for_tool write)" ]] || {
		echo "self-test: missing write route" >&2
		return 1
	}
	echo "post-dispatcher self-test: OK"
}

if [[ "${1:-}" == "--self-test" ]]; then
	self_test
	exit $?
fi

INPUT_JSON="$(cat)"
TOOL_NAME="$(printf '%s' "$INPUT_JSON" | jq -r '(.toolName // .tool_name // "") | ascii_downcase' 2>/dev/null || echo "")"
[[ -n "$TOOL_NAME" ]] || exit 0

ROUTE="$(route_for_tool "$TOOL_NAME")"
[[ -n "$ROUTE" ]] || exit 0

for hook_script in $ROUTE; do
	printf '%s' "$INPUT_JSON" | "$hook_script"
done

exit 0
