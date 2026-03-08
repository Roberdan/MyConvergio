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
python3 - "$PY" <<'PY'
import ast
import sys
from pathlib import Path

themes_path = Path(sys.argv[1])
module = ast.parse(themes_path.read_text(encoding="utf-8"))

theme_keys = set()
theme_names_declared = False
for node in module.body:
    if isinstance(node, ast.Assign):
        for target in node.targets:
            if isinstance(target, ast.Name) and target.id == "THEMES":
                if isinstance(node.value, ast.Dict):
                    for key in node.value.keys:
                        if isinstance(key, ast.Constant) and isinstance(key.value, str):
                            theme_keys.add(key.value)
            if isinstance(target, ast.Name) and target.id == "THEME_NAMES":
                if isinstance(node.value, ast.Call):
                    theme_names_declared = True

assert "neon-grid" in theme_keys
assert "synthwave" in theme_keys
assert "ghost-shell" in theme_keys
assert len(theme_keys) >= 3
assert theme_names_declared
print("PASS textual themes")
PY
cd "$ROOT"

lines=$(wc -l < "$CSS" | tr -d ' ')
[[ "$lines" -le 260 ]] || { echo "✗ themes.css unexpectedly large ($lines)"; exit 1; }
echo "✓ dashboard theme checks passed"
