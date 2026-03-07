#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
HOOK="$SCRIPT_DIR/hooks/enforce-execution-preflight.sh"

echo "Testing enforce-execution-preflight.sh..."

TMP_HOME="$(mktemp -d)"
trap 'rm -rf "$TMP_HOME"' EXIT
mkdir -p "$TMP_HOME/.claude/data/execution-preflight"

run_hook() {
	local json="$1"
	HOME="$TMP_HOME" bash -c "echo '$json' | bash '$HOOK'"
}

ALLOW_JSON='{"toolName":"bash","toolArgs":{"command":"echo ok"}}'
[[ -z "$(run_hook "$ALLOW_JSON")" ]] || {
	echo "FAIL: non-risky command should pass"
	exit 1
}

RISKY_JSON='{"toolName":"bash","toolArgs":{"command":"execute-plan.sh 123"}}'
run_hook "$RISKY_JSON" | grep -q 'missing execution preflight snapshot' || {
	echo "FAIL: missing snapshot should deny risky command"
	exit 1
}

cat >"$TMP_HOME/.claude/data/execution-preflight/plan-123.json" <<'EOF'
{"generated_epoch":4102444800,"warnings":[]}
EOF
[[ -z "$(run_hook "$RISKY_JSON")" ]] || {
	echo "FAIL: fresh clean snapshot should allow risky command"
	exit 1
}

cat >"$TMP_HOME/.claude/data/execution-preflight/plan-123.json" <<'EOF'
{"generated_epoch":4102444800,"warnings":["dirty_worktree"]}
EOF
run_hook "$RISKY_JSON" | grep -q 'dirty_worktree' || {
	echo "FAIL: dirty worktree should deny risky command"
	exit 1
}

echo "PASS: enforce-execution-preflight.sh behaves as expected"
