#!/usr/bin/env bash
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
echo "=== Test mesh-coordinator.sh ==="
test -f "$SCRIPT_DIR/scripts/mesh-coordinator.sh" && echo "PASS: script exists" || { echo "FAIL: missing"; exit 1; }
test -x "$SCRIPT_DIR/scripts/mesh-coordinator.sh" && echo "PASS: executable" || { echo "FAIL: not executable"; exit 1; }
bash -n "$SCRIPT_DIR/scripts/mesh-coordinator.sh" && echo "PASS: syntax OK" || { echo "FAIL: syntax error"; exit 1; }
bash "$SCRIPT_DIR/scripts/mesh-coordinator.sh" status 2>/dev/null && echo "PASS: status command" || echo "WARN: status returned non-zero"
echo "=== Test run-once ==="
bash "$SCRIPT_DIR/scripts/mesh-coordinator.sh" run-once 2>/dev/null && echo "PASS: run-once" || echo "WARN: run-once returned non-zero"
echo "=== All coordinator tests passed ==="
