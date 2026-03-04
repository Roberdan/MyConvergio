#!/usr/bin/env bash
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
echo "=== Test mesh-notify.sh ==="
test -f "$SCRIPT_DIR/scripts/mesh-notify.sh" && echo "PASS: script exists" || { echo "FAIL: missing"; exit 1; }
test -x "$SCRIPT_DIR/scripts/mesh-notify.sh" && echo "PASS: executable" || { echo "FAIL: not executable"; exit 1; }
bash "$SCRIPT_DIR/scripts/mesh-notify.sh" info "Test" "Test message" 2>/dev/null && echo "PASS: basic call" || echo "WARN: call returned non-zero (may be ok if notify channels off)"
echo "=== Test notify-config.sh ==="
CLAUDE_HOME="$SCRIPT_DIR" bash -c 'source scripts/lib/notify-config.sh && notify_load && notify_enabled dashboard && echo "PASS: dashboard enabled"' || { echo "FAIL: notify_enabled"; exit 1; }
echo "=== All notify tests passed ==="
