#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PRECHECK="$SCRIPT_DIR/scripts/execution-preflight.sh"

echo "Testing execution-preflight.sh..."

[[ -x "$PRECHECK" ]] || {
	echo "FAIL: execution-preflight.sh missing or not executable"
	exit 1
}

TMP_REPO="$(mktemp -d)"
trap 'rm -rf "$TMP_REPO"' EXIT

git -C "$TMP_REPO" init >/dev/null 2>&1
git -C "$TMP_REPO" checkout -b test-preflight >/dev/null 2>&1
touch "$TMP_REPO/README.md"
OUTPUT="$("$PRECHECK" "$TMP_REPO")"

echo "$OUTPUT" | jq -e '.repo_root and .branch and (.warnings | type == "array")' >/dev/null
echo "$OUTPUT" | jq -e '.branch == "test-preflight"' >/dev/null
echo "$OUTPUT" | jq -e '.warnings | index("missing_troubleshooting")' >/dev/null
echo "$OUTPUT" | jq -e '.warnings | index("missing_ci_knowledge")' >/dev/null
echo "$OUTPUT" | jq -e '.warnings | index("missing_changelog")' >/dev/null

echo "PASS: execution-preflight.sh returns expected readiness warnings"
