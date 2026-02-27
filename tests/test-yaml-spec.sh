#!/bin/bash
# Test YAML spec support across plan-db scripts
# Version: 1.0.0
set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SCRIPT_DIR="$REPO_DIR/scripts"
source "$REPO_DIR/scripts/lib/plan-db-core.sh"

PASS=0
FAIL=0
TMPDIR=$(mktemp -d)
trap "rm -rf '$TMPDIR'" EXIT

pass() {
	PASS=$((PASS + 1))
	echo "  PASS: $1"
}
fail() {
	FAIL=$((FAIL + 1))
	echo "  FAIL: $1"
}

echo "=== Test: yaml_to_json_temp ==="

# Test 1: YAML file converts to JSON
cat >"$TMPDIR/test.yaml" <<'EOF'
waves:
  - id: W1
    name: Test Wave
    tasks:
      - id: T1-01
        do: Test task
        files:
          - src/app.ts
        verify:
          - "echo ok"
        effort: 1
EOF

result=$(yaml_to_json_temp "$TMPDIR/test.yaml")
if jq -e '.waves[0].id' "$result" >/dev/null 2>&1; then
	pass "YAML converts to valid JSON"
else
	fail "YAML conversion failed"
fi
# Verify it's a temp file (different path)
if [[ "$result" != "$TMPDIR/test.yaml" ]]; then
	pass "YAML returns temp file path"
else
	fail "YAML should return temp file, not original"
fi
rm -f "$result"

# Test 2: JSON file passes through unchanged
cat >"$TMPDIR/test.json" <<'EOF'
{"waves": [{"id": "W1", "name": "Test", "tasks": []}]}
EOF

result=$(yaml_to_json_temp "$TMPDIR/test.json")
if [[ "$result" == "$TMPDIR/test.json" ]]; then
	pass "JSON passes through unchanged"
else
	fail "JSON should return original path, got: $result"
fi

# Test 3: .yml extension also works
cp "$TMPDIR/test.yaml" "$TMPDIR/test.yml"
result=$(yaml_to_json_temp "$TMPDIR/test.yml")
if jq -e '.waves[0].id' "$result" >/dev/null 2>&1; then
	pass ".yml extension converts correctly"
else
	fail ".yml extension conversion failed"
fi
rm -f "$result"

echo ""
echo "=== Test: wave-overlap.sh check-spec with YAML ==="

export PATH="$REPO_DIR/scripts:$PATH"
output=$("$REPO_DIR/scripts/wave-overlap.sh" check-spec "$TMPDIR/test.yaml" 2>/dev/null) || true
if echo "$output" | jq -e '.waves_checked' >/dev/null 2>&1; then
	pass "wave-overlap.sh check-spec accepts YAML"
else
	fail "wave-overlap.sh check-spec failed with YAML"
fi

echo ""
echo "=== Test: plan-db-conflicts.sh with YAML ==="

# conflict-check-spec needs DB access, test the yaml_to_json_temp integration
# by checking the function is referenced in the file
if grep -q 'yaml_to_json_temp' "$REPO_DIR/scripts/lib/plan-db-conflicts.sh"; then
	pass "plan-db-conflicts.sh uses yaml_to_json_temp"
else
	fail "plan-db-conflicts.sh missing yaml_to_json_temp"
fi

echo ""
echo "=== Test: token-estimator.sh YAML support ==="

if grep -q 'yaml' "$REPO_DIR/scripts/token-estimator.sh"; then
	pass "token-estimator.sh has YAML support"
else
	fail "token-estimator.sh missing YAML support"
fi

echo ""
echo "=== Test: plan-db-import.sh spec copy extension ==="

if grep -q 'spec_ext' "$REPO_DIR/scripts/lib/plan-db-import.sh"; then
	pass "plan-db-import.sh preserves original extension"
else
	fail "plan-db-import.sh missing extension preservation"
fi

# Test render lookup supports both extensions (loops over yaml yml json)
if grep -q 'yaml yml json' "$REPO_DIR/scripts/lib/plan-db-import.sh"; then
	pass "plan-db-import.sh render supports YAML lookup"
else
	fail "plan-db-import.sh render missing YAML lookup"
fi

echo ""
echo "=== Results ==="
echo "Passed: $PASS  Failed: $FAIL"
[[ $FAIL -eq 0 ]] && echo "ALL TESTS PASSED" || {
	echo "SOME TESTS FAILED"
	exit 1
}
