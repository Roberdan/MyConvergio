#!/bin/bash
# Dashboard cleanup checks for the current dashboard_web stack
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
INDEX="$ROOT/scripts/dashboard_web/index.html"
APP_JS="$ROOT/scripts/dashboard_web/app.js"
MESH_JS="$ROOT/scripts/dashboard_web/mesh.js"

fail() { echo "FAIL: $1"; exit 1; }

bash -n "$ROOT/scripts/dashboard_textual/__main__.py" >/dev/null 2>&1 || true
node --check "$APP_JS" >/dev/null 2>&1 || fail "app.js syntax error"
node --check "$MESH_JS" >/dev/null 2>&1 || fail "mesh.js syntax error"
grep -q 'Mesh Network' "$INDEX" || fail "Mesh Network widget missing from index.html"
grep -q 'Augmented Brain' "$INDEX" || fail "Augmented Brain widget missing from index.html"
grep -q 'AI Organization' "$INDEX" && fail "AI Organization widget still present in index.html" || true
grep -q 'Live Neural System' "$INDEX" && fail "Live Neural System widget still present in index.html" || true
grep -q '/api/organization' "$APP_JS" && fail "organization API still wired in app.js" || true
grep -q '/api/live-system' "$APP_JS" && fail "live-system API still wired in app.js" || true

echo "PASS: Dashboard cleanup checks passed"
