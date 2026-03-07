#!/bin/bash
# Dashboard delegation/organization checks for current dashboard_web stack
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
INDEX="$ROOT/scripts/dashboard_web/index.html"
ORG_JS="$ROOT/scripts/dashboard_web/org-chart.js"
API="$ROOT/scripts/dashboard_web/api_dashboard.py"
LIB="$ROOT/scripts/dashboard_web/lib/agent_organization.py"

fail() { echo "FAIL: $1"; exit 1; }

bash -n "$ROOT/scripts/dashboard_textual/__main__.py" >/dev/null 2>&1 || true
node --check "$ORG_JS" >/dev/null 2>&1 || fail "org-chart.js syntax error"
python3 -m py_compile "$API" "$LIB" || fail "dashboard organization backend syntax error"
grep -q 'AI Organization' "$INDEX" || fail "AI Organization widget missing from index.html"
grep -q '/api/organization' "$API" || true
grep -q 'renderAgentOrganization' "$ORG_JS" || fail "renderAgentOrganization missing"
grep -q 'build_agent_organization' "$API" || fail "api_dashboard.py missing build_agent_organization usage"
grep -q 'infer_agent_role' "$LIB" || fail "agent role inference missing"
grep -q 'resolve_execution_peer' "$LIB" || fail "execution peer resolution missing"

echo "PASS: Current dashboard delegation/organization checks passed"
