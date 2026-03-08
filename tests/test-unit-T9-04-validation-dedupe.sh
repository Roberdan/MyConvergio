#!/usr/bin/env bash
set -euo pipefail

source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/lib/test-helpers.sh"
setup_test_env

PLAN_VALIDATE="$REPO_ROOT/scripts/lib/plan-db-validate.sh"
HOOK_CHECKS="$REPO_ROOT/hooks/lib/hook-checks.sh"
DISPATCHER="$REPO_ROOT/hooks/dispatcher.sh"

fail() {
	echo "[FAIL] $1" >&2
	exit 1
}

pass() {
	echo "[PASS] $1"
}

[[ -f "$PLAN_VALIDATE" ]] || fail "scripts/lib/plan-db-validate.sh must exist"
[[ -f "$HOOK_CHECKS" ]] || fail "hooks/lib/hook-checks.sh must exist"
[[ -f "$DISPATCHER" ]] || fail "hooks/dispatcher.sh must exist"
pass "validation files exist"

rg -q "VALIDATION OWNERSHIP MATRIX" "$PLAN_VALIDATE" || fail "plan-db-validate.sh must document validation ownership matrix"
pass "validation ownership matrix documented"

rg -q "plan_db_validation_owner" "$PLAN_VALIDATE" || fail "plan-db-validate.sh must expose ownership helper"
pass "ownership helper exists"

if rg -q "check_enforce_plan_db_safe|check_enforce_plan_reviews|check_enforce_thor_completion" "$HOOK_CHECKS"; then
	fail "hooks/lib/hook-checks.sh must remove redundant blocking checks owned by plan-db scripts"
fi
pass "redundant hook-level blocking checks removed"

rg -q "check_plan_db_validation_hints" "$HOOK_CHECKS" || fail "hook-checks must provide non-blocking plan-db ownership hints"
pass "hook ownership hint check exists"

if rg -q "check_enforce_plan_db_safe|check_enforce_plan_reviews|check_enforce_thor_completion" "$DISPATCHER"; then
	fail "hooks/dispatcher.sh must not route deprecated duplicate enforcement checks"
fi
pass "dispatcher routes no deprecated duplicate checks"

rg -q "check_plan_db_validation_hints" "$DISPATCHER" || fail "hooks/dispatcher.sh must route check_plan_db_validation_hints"
pass "dispatcher routes ownership hint check"

echo "[OK] T9-04 criteria satisfied"
