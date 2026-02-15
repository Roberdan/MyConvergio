#!/bin/bash
# Version Check Hook - Detects Claude Code updates
# Runs in Setup hook. Compares current version against last known.
# If different, notifies user to run @sentinel-ecosystem-guardian.
# Version: 1.1.0
set -euo pipefail

VERSION_FILE="$HOME/.claude/data/.claude-code-version"
CURRENT_VERSION=$(claude --version 2>/dev/null | head -1 | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' || echo "unknown")

[[ "$CURRENT_VERSION" == "unknown" ]] && exit 0

# First run: store version and exit
if [[ ! -f "$VERSION_FILE" ]]; then
	mkdir -p "$(dirname "$VERSION_FILE")"
	echo "$CURRENT_VERSION" >"$VERSION_FILE"
	exit 0
fi

LAST_VERSION=$(cat "$VERSION_FILE" 2>/dev/null || echo "unknown")

if [[ "$CURRENT_VERSION" != "$LAST_VERSION" ]]; then
	echo "$CURRENT_VERSION" >"$VERSION_FILE"
	cat <<EOF
{"notification": "Claude Code updated: $LAST_VERSION -> $CURRENT_VERSION. Run @sentinel-ecosystem-guardian for ecosystem alignment.", "severity": "info"}
EOF
fi

exit 0
