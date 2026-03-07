#!/bin/bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
MISSION="$ROOT/scripts/dashboard_web/mission.js"
PIPE="$ROOT/scripts/dashboard_web/task-pipeline.js"
API="$ROOT/scripts/dashboard_web/api_dashboard.py"

pass() { echo "PASS $1"; }
fail() { echo "FAIL $1"; exit 1; }

grep -q 'pendingWaves' "$MISSION" || fail "mission.js missing pending wave rendering"
grep -q 'wave-row' "$MISSION" || fail "mission.js missing wave rows"
grep -q 'renderTaskPipeline' "$PIPE" || fail "task-pipeline.js missing pipeline renderer"
grep -q 'SELECT wave_id,name,status,tasks_done,tasks_total,position FROM waves' "$API" || fail "api_dashboard.py missing wave query"
node --check "$MISSION" >/dev/null 2>&1 || fail "mission.js syntax error"
node --check "$PIPE" >/dev/null 2>&1 || fail "task-pipeline.js syntax error"

echo "PASS current dashboard wave checks"
