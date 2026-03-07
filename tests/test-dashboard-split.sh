#!/bin/bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
WEB="$ROOT/scripts/dashboard_web"
PASS=0
FAIL=0

pass() { echo "✓ $1"; PASS=$((PASS + 1)); }
fail() { echo "✗ $1"; FAIL=$((FAIL + 1)); }

for f in index.html app.js mission.js task-pipeline.js mesh.js org-chart.js websocket.js; do
  [[ -f "$WEB/$f" ]] && pass "$f exists" || fail "$f missing"
done

for f in app.js mission.js task-pipeline.js mesh.js org-chart.js websocket.js; do
  node --check "$WEB/$f" >/dev/null 2>&1 && pass "$f syntax" || fail "$f syntax"
done

grep -q 'mission.js' "$WEB/index.html" && pass "index sources mission.js" || fail "index missing mission.js"
grep -q 'org-chart.js' "$WEB/index.html" && pass "index sources org-chart.js" || fail "index missing org-chart.js"
grep -q 'mesh.js' "$WEB/index.html" && pass "index sources mesh.js" || fail "index missing mesh.js"
grep -q 'task-pipeline.js' "$WEB/index.html" && pass "index sources task-pipeline.js" || fail "index missing task-pipeline.js"

for f in "$WEB/index.html" "$WEB/app.js" "$WEB/mission.js" "$WEB/org-chart.js"; do
  lines=$(wc -l < "$f" | tr -d ' ')
  [[ "$lines" -le 400 ]] && pass "$(basename "$f") reasonable size ($lines)" || fail "$(basename "$f") too large ($lines)"
done

echo "Results: $PASS passed, $FAIL failed"
[[ $FAIL -eq 0 ]]
