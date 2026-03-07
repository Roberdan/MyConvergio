#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PROMPT_SCRIPT="$SCRIPT_DIR/scripts/copilot-task-prompt.sh"

echo "Testing copilot-task-prompt.sh..."

[[ -f "$PROMPT_SCRIPT" ]] || {
	echo "FAIL: copilot-task-prompt.sh not found"
	exit 1
}

grep -q "COALESCE(w.worktree_path, p.worktree_path, '')" "$PROMPT_SCRIPT" || {
	echo "FAIL: prompt does not prefer wave worktree path"
	exit 1
}

grep -q 'execution-preflight.sh "\$WT"' "$PROMPT_SCRIPT" || {
	echo "FAIL: prompt setup missing execution-preflight.sh"
	exit 1
}

grep -q "Execution Readiness Snapshot" "$PROMPT_SCRIPT" || {
	echo "FAIL: prompt missing execution readiness snapshot section"
	exit 1
}

grep -q "missing troubleshooting" "$PROMPT_SCRIPT" || {
	echo "FAIL: prompt missing readiness warning guidance"
	exit 1
}

echo "PASS: copilot-task-prompt.sh includes readiness guardrails"
