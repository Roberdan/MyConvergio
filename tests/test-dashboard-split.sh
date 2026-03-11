#!/bin/bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
WEB="$ROOT/scripts/dashboard_web"
PASS=0
FAIL=0

pass() { echo "✓ $1"; PASS=$((PASS + 1)); }
fail() { echo "✗ $1"; FAIL=$((FAIL + 1)); }

for f in index.html app.js mission.js task-pipeline.js mesh.js websocket.js widget-drag.js; do
  [[ -f "$WEB/$f" ]] && pass "$f exists" || fail "$f missing"
done

for f in app.js mission.js task-pipeline.js mesh.js websocket.js widget-drag.js; do
  node --check "$WEB/$f" >/dev/null 2>&1 && pass "$f syntax" || fail "$f syntax"
done

grep -q 'mission.js' "$WEB/index.html" && pass "index sources mission.js" || fail "index missing mission.js"
grep -q 'mesh.js' "$WEB/index.html" && pass "index sources mesh.js" || fail "index missing mesh.js"
grep -q 'task-pipeline.js' "$WEB/index.html" && pass "index sources task-pipeline.js" || fail "index missing task-pipeline.js"
! grep -q 'org-chart.js' "$WEB/index.html" && pass "index no longer sources org-chart.js" || fail "index still sources org-chart.js"
! grep -q 'live-system.js' "$WEB/index.html" && pass "index no longer sources live-system.js" || fail "index still sources live-system.js"

for f in "$WEB/index.html" "$WEB/mission.js" "$WEB/widget-drag.js"; do
  lines=$(wc -l < "$f" | tr -d ' ')
  [[ "$lines" -le 400 ]] && pass "$(basename "$f") reasonable size ($lines)" || fail "$(basename "$f") too large ($lines)"
done

app_lines=$(wc -l < "$WEB/app.js" | tr -d ' ')
[[ "$app_lines" -le 450 ]] && pass "app.js reasonable size ($app_lines)" || fail "app.js too large ($app_lines)"

echo "Results: $PASS passed, $FAIL failed"
[[ $FAIL -eq 0 ]]
