#!/bin/bash
# Session Setup hook: model-registry-refresh.sh
# Checks CLI versions and stores them. Model registry via claude-core.
# Version: 3.0.0
set -euo pipefail

VERSIONS_JSON="$HOME/.claude/data/.cli-versions.json"
mkdir -p "$(dirname "$VERSIONS_JSON")"

# Quick version snapshot (non-blocking)
CLAUDE_V=$(claude --version 2>/dev/null | head -1 | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' || echo "unknown")

cat > "$VERSIONS_JSON" <<EOF
{"claude":"$CLAUDE_V","checked":"$(date -u +%Y-%m-%dT%H:%M:%SZ)"}
EOF

exit 0
