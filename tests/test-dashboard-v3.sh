#!/bin/bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
WEB="$ROOT_DIR/scripts/dashboard_web"
PYROOT="$ROOT_DIR/scripts"
PASS=0
FAIL=0

pass() { PASS=$((PASS + 1)); printf "  PASS: %s\n" "$1"; }
fail() { FAIL=$((FAIL + 1)); printf "  FAIL: %s\n" "$1"; }

echo "=== WEB DASHBOARD V3 ==="
grep -q 'Convergio Control Room v3.0' "$WEB/index.html" && pass "v3 footer present" || fail "v3 footer missing"
grep -q 'Mesh Network' "$WEB/index.html" && pass "Mesh widget present" || fail "Mesh widget missing"
! grep -q 'AI Organization' "$WEB/index.html" && pass "AI Organization widget removed" || fail "AI Organization widget still present"
! grep -q 'Live Neural System' "$WEB/index.html" && pass "Live Neural System widget removed" || fail "Live Neural System widget still present"
! grep -q '/api/organization' "$WEB/app.js" && pass "organization API removed from app" || fail "organization API still wired"
! grep -q '/api/live-system' "$WEB/app.js" && pass "live-system API removed from app" || fail "live-system API still wired"

for f in "$WEB/app.js" "$WEB/mission.js" "$WEB/mesh.js" "$WEB/task-pipeline.js" "$WEB/widget-drag.js"; do
  node --check "$f" >/dev/null 2>&1 && pass "$(basename "$f") syntax OK" || fail "$(basename "$f") syntax error"
done

echo ""
echo "=== PYTHON TUI ==="
PYTHON="${PYTHON:-python3}"
cd "$PYROOT"
$PYTHON -c "from dashboard_textual.models import Plan, Wave, Task, Peer, TokenStats" 2>/dev/null && pass "Python models import" || fail "Python models import"
$PYTHON -c "from dashboard_textual.db import DashboardDB" 2>/dev/null && pass "Python db import" || fail "Python db import"
$PYTHON -m py_compile dashboard_textual/app.py 2>/dev/null && pass "Python app syntax" || fail "Python app syntax"
$PYTHON -m py_compile dashboard_textual/themes.py 2>/dev/null && pass "Python themes syntax" || fail "Python themes syntax"
cd "$ROOT_DIR"

echo ""
echo "=== RESULTS: $PASS passed, $FAIL failed ==="
[[ $FAIL -eq 0 ]]
