#!/usr/bin/env bash
set -euo pipefail

source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/lib/test-helpers.sh"
setup_test_env

COPILOT_WORKER="$REPO_ROOT/scripts/copilot-worker.sh"
PROMPT_SCRIPT="$REPO_ROOT/scripts/copilot-task-prompt.sh"
DELEGATE_SCRIPT="$REPO_ROOT/scripts/delegate.sh"

fail() {
  echo "[FAIL] $1" >&2
  exit 1
}

pass() {
  echo "[PASS] $1"
}

grep -q "agent-context-loader.sh" "$COPILOT_WORKER" || fail "copilot-worker must wire agent-context-loader"
pass "copilot-worker wires agent-context-loader"

grep -q "agent-context-loader.sh" "$PROMPT_SCRIPT" || fail "copilot-task-prompt must load context via agent-context-loader"
grep -q 'AGENT_ROLE=' "$PROMPT_SCRIPT" || fail "copilot-task-prompt must accept an agent role argument"
pass "copilot-task-prompt supports role-based context loader"

grep -q 'copilot-task-prompt.sh" "\$TASK_DB_ID" "executor"' "$DELEGATE_SCRIPT" || fail "delegate fallback (task-executor path) must request executor role context"
pass "delegate fallback requests executor context"

echo "[OK] T14-03 criteria satisfied"
