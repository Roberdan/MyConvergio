#!/bin/bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CSS="$ROOT/scripts/dashboard_web/themes.css"
PY="$ROOT/scripts/dashboard_textual/themes.py"

themes=(synthwave ghost matrix dark light vintage tron fallout convergio)
aliases_ok=0

for theme in "${themes[@]}"; do
  grep -q "\\[data-theme=\"$theme\"\\]" "$CSS" || { echo "✗ missing CSS theme $theme"; exit 1; }
done

cd "$ROOT/scripts"
python3 - <<'PY'
from dashboard_textual.themes import THEMES, THEME_NAMES
assert "neon-grid" in THEMES
assert "synthwave" in THEMES
assert "ghost-shell" in THEMES
assert len(THEME_NAMES) >= 3
print("PASS textual themes")
PY
cd "$ROOT"

lines=$(wc -l < "$CSS" | tr -d ' ')
[[ "$lines" -le 260 ]] || { echo "✗ themes.css unexpectedly large ($lines)"; exit 1; }
echo "✓ dashboard theme checks passed"
