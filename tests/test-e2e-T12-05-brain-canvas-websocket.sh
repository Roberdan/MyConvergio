#!/usr/bin/env bash
set -euo pipefail

source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/lib/test-helpers.sh"
setup_test_env

TARGET="$REPO_ROOT/scripts/dashboard_web/brain-canvas.js"

fail() {
  echo "[FAIL] $1" >&2
  exit 1
}

[[ -f "$TARGET" ]] || fail "brain-canvas.js must exist at $TARGET"

grep -q "ws.*brain" "$TARGET" || fail "brain-canvas.js must reference /ws/brain websocket endpoint"
grep -q "WebSocket" "$TARGET" || fail "brain-canvas.js must initialize WebSocket client"

echo "[OK] T12-05 websocket criteria satisfied"
