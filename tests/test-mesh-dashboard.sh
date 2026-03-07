#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
API="$ROOT/scripts/dashboard_web/api_mesh.py"
JS="$ROOT/scripts/dashboard_web/mesh.js"
WS="$ROOT/scripts/dashboard_web/websocket.js"
PLAN="$ROOT/scripts/dashboard_web/mesh-plan-ops.js"

python3 -m py_compile "$API" || { echo "✗ api_mesh.py syntax"; exit 1; }
node --check "$JS" >/dev/null 2>&1 || { echo "✗ mesh.js syntax"; exit 1; }
node --check "$WS" >/dev/null 2>&1 || { echo "✗ websocket.js syntax"; exit 1; }
node --check "$PLAN" >/dev/null 2>&1 || { echo "✗ mesh-plan-ops.js syntax"; exit 1; }

grep -q 'def api_mesh' "$API" || { echo "✗ api_mesh missing"; exit 1; }
grep -q 'parse_peers_conf' "$API" || { echo "✗ peer config parsing missing"; exit 1; }
grep -q 'updateMeshPeers' "$JS" || { echo "✗ updateMeshPeers missing"; exit 1; }
grep -q 'renderMeshStrip' "$WS" || { echo "✗ renderMeshStrip missing"; exit 1; }
grep -q 'showStartPlanDialog' "$PLAN" || { echo "✗ mesh plan dialog missing"; exit 1; }

echo "✓ current mesh dashboard checks passed"
