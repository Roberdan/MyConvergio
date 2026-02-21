#!/bin/bash
# Version Check Hook - Detects Claude Code, copilot-cli, opencode, gemini updates
# Stores versions in data/.cli-versions.json and .claude-code-version for backward compat
# Version: 2.0.0
set -euo pipefail

VERSION_FILE="$HOME/.claude/data/.claude-code-version"
VERSIONS_JSON="$HOME/.claude/data/.cli-versions.json"

# Get versions
CLAUDE_VERSION=$(claude --version 2>/dev/null | head -1 | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' || echo "unknown")
COPILOT_VERSION=$(copilot --version 2>/dev/null | head -1 | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' || echo "unknown")
COPILOTCLI_VERSION=$(copilot-cli --version 2>/dev/null | head -1 | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' || echo "unknown")
OPENCODE_VERSION=$(opencode --version 2>/dev/null | head -1 | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' || echo "unknown")
GEMINI_VERSION=$(gemini --version 2>/dev/null | head -1 | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' || echo "unknown")

# Store JSON
mkdir -p "$(dirname "$VERSIONS_JSON")"
echo "{\n  \"claude\": \"$CLAUDE_VERSION\",\n  \"copilot\": \"$COPILOT_VERSION\",\n  \"copilot-cli\": \"$COPILOTCLI_VERSION\",\n  \"opencode\": \"$OPENCODE_VERSION\",\n  \"gemini\": \"$GEMINI_VERSION\"\n}" > "$VERSIONS_JSON"

# Backward compat: .claude-code-version
[[ "$CLAUDE_VERSION" == "unknown" ]] && exit 0
if [[ ! -f "$VERSION_FILE" ]]; then
  mkdir -p "$(dirname "$VERSION_FILE")"
  echo "$CLAUDE_VERSION" > "$VERSION_FILE"
  exit 0
fi
LAST_VERSION=$(cat "$VERSION_FILE" 2>/dev/null || echo "unknown")
if [[ "$CLAUDE_VERSION" != "$LAST_VERSION" ]]; then
  echo "$CLAUDE_VERSION" > "$VERSION_FILE"
  cat <<EOF
{"notification": "Claude Code updated: $LAST_VERSION -> $CLAUDE_VERSION. Run @sentinel-ecosystem-guardian for ecosystem alignment.", "severity": "info"}
EOF
fi

exit 0
