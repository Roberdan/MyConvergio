#!/bin/bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CSS="$ROOT/scripts/dashboard_web/themes.css"
STYLE="$ROOT/scripts/dashboard_web/style.css"
BASE="$ROOT/scripts/dashboard_web/css/base.css"
PY="$ROOT/scripts/dashboard_textual/themes.py"

pass() { printf "PASS: %s\n" "$1"; }
fail() { printf "FAIL: %s\n" "$1"; exit 1; }

grep -q '\[data-theme="synthwave"\]' "$CSS" || fail "synthwave theme missing"
grep -q '\[data-theme="matrix"\]' "$CSS" || fail "matrix theme missing"
grep -q '\[data-theme="convergio"\]' "$CSS" || fail "convergio theme missing"
grep -q -- '--bg-deep:' "$CSS" || fail "theme variables missing"
grep -q -- '--cyan:' "$CSS" || fail "accent variables missing"
grep -q "@import url('css/base.css');" "$STYLE" || fail "style.css missing base import"
grep -q ':root' "$BASE" || fail "base.css missing root variables"
python3 -m py_compile "$PY" || fail "textual themes syntax error"
python3 - <<'PY' || exit 1
from pathlib import Path
src = Path("/Users/roberdan/.claude/scripts/dashboard_textual/themes.py").read_text()
assert "NEON_GRID" in src
assert "SYNTHWAVE" in src
assert "GHOST_SHELL" in src
print("PASS: textual themes content")
PY

echo "PASS: current dashboard design system checks"
