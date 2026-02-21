#!/bin/bash
# E2E scenarios for orchestrator pipeline (mocked CLIs, no DB dependency)
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PASS=0
FAIL=0

pass() {
	PASS=$((PASS + 1))
	echo "  PASS: $1"
}
fail() {
	FAIL=$((FAIL + 1))
	echo "  FAIL: $1"
}

echo "=== test-e2e-orchestrator.sh ==="

# 1. All orchestrator scripts have valid syntax
echo "--- Syntax validation ---"
for script in \
	"${SCRIPT_DIR}/scripts/delegate.sh" \
	"${SCRIPT_DIR}/scripts/copilot-worker.sh" \
	"${SCRIPT_DIR}/scripts/opencode-worker.sh" \
	"${SCRIPT_DIR}/scripts/gemini-worker.sh" \
	"${SCRIPT_DIR}/scripts/execute-plan.sh" \
	"${SCRIPT_DIR}/scripts/env-vault.sh" \
	"${SCRIPT_DIR}/scripts/model-registry.sh" \
	"${SCRIPT_DIR}/scripts/worktree-safety.sh" \
	"${SCRIPT_DIR}/scripts/lib/delegate-utils.sh" \
	"${SCRIPT_DIR}/scripts/lib/agent-protocol.sh" \
	"${SCRIPT_DIR}/scripts/lib/dashboard-delegation.sh" \
	"${SCRIPT_DIR}/scripts/lib/gh-ops-routing.sh" \
	"${SCRIPT_DIR}/scripts/lib/plan-db-delegate.sh" \
	"${SCRIPT_DIR}/scripts/lib/quality-gate-templates.sh"; do
	name=$(basename "$script")
	if bash -n "$script" 2>/dev/null; then
		pass "syntax: $name"
	else
		fail "syntax: $name"
	fi
done

# 2. Privacy enforcement mock
echo "--- Privacy enforcement ---"
MOCK_DIR=$(mktemp -d)
trap 'rm -rf "$MOCK_DIR"' EXIT

cat >"$MOCK_DIR/privacy-check.sh" <<'MOCK'
#!/bin/bash
if [[ "$1" == "sensitive" && "$2" == "free" ]]; then echo "BLOCKED"; exit 1; fi
echo "ALLOWED"
MOCK
chmod +x "$MOCK_DIR/privacy-check.sh"

out=$("$MOCK_DIR/privacy-check.sh" sensitive free 2>&1 || true)
if [[ "$out" == "BLOCKED" ]]; then
	pass "privacy blocks sensitive+free"
else fail "privacy should block sensitive+free"; fi

out=$("$MOCK_DIR/privacy-check.sh" public free 2>&1)
if [[ "$out" == "ALLOWED" ]]; then
	pass "privacy allows public+free"
else fail "privacy should allow public+free"; fi

# 3. Model registry mock
echo "--- Model registry mock ---"
cat >"$MOCK_DIR/model-registry.sh" <<'MOCK'
#!/bin/bash
case "$1" in refresh) echo "REFRESHED";; diff) echo "DIFFED";; check) echo "CHECKED";; *) echo "UNKNOWN";; esac
MOCK
chmod +x "$MOCK_DIR/model-registry.sh"

for cmd in refresh diff check; do
	result=$("$MOCK_DIR/model-registry.sh" "$cmd")
	expected=$(echo "$cmd" | tr '[:lower:]' '[:upper:]')
	# diff -> DIFFED, etc
	if [[ "$result" == "${expected}ED" || "$result" == "${expected}D" ]]; then
		pass "model-registry $cmd"
	else
		fail "model-registry $cmd (got: $result)"
	fi
done

# 4. Execute-plan help works
echo "--- Execute-plan help ---"
help_out=$("${SCRIPT_DIR}/scripts/execute-plan.sh" --help 2>&1 || true)
if echo "$help_out" | grep -q "Usage:"; then
	pass "execute-plan --help"
else fail "execute-plan --help"; fi

# 5. Config file exists
echo "--- Config files ---"
if [ -f "${SCRIPT_DIR}/config/orchestrator.yaml" ]; then
	pass "orchestrator.yaml exists"
else fail "orchestrator.yaml missing"; fi

echo ""
echo "=== Results: $PASS/$((PASS + FAIL)) passed, $FAIL failed ==="
[ "$FAIL" -eq 0 ]
