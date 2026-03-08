#!/usr/bin/env bash
set -euo pipefail

source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/lib/test-helpers.sh"
setup_test_env

DISPATCHER="$REPO_ROOT/scripts/plan-db.sh"

fail() {
	echo "[FAIL] $1" >&2
	exit 1
}

pass() {
	echo "[PASS] $1"
}

[[ -f "$DISPATCHER" ]] || fail "scripts/plan-db.sh must exist"
[[ -x "$DISPATCHER" ]] || fail "scripts/plan-db.sh must be executable"
pass "plan-db dispatcher exists and is executable"

trace_file="$(mktemp)"
trap 'rm -f "$trace_file"' EXIT

bash -x "$DISPATCHER" status claude >/dev/null 2>"$trace_file"

modules_text="$(sed -n 's/.*source .*\/\(plan-db-[^ ]*\.sh\).*/\1/p' "$trace_file" | sort -u | tr '\n' ' ')"

[[ " ${modules_text} " == *" plan-db-core.sh "* ]] || fail "status must source plan-db-core.sh"
[[ " ${modules_text} " == *" plan-db-display.sh "* ]] || fail "status must source plan-db-display.sh"

for module in \
	plan-db-import.sh \
	plan-db-validate.sh \
	plan-db-drift.sh \
	plan-db-conflicts.sh \
	plan-db-cluster.sh \
	plan-db-remote.sh \
	plan-db-delegate.sh \
	plan-db-intelligence.sh \
	plan-db-agents.sh \
	plan-db-knowledge.sh \
	plan-db-crud.sh \
	plan-db-create.sh \
	plan-db-read.sh \
	plan-db-update.sh \
	plan-db-delete.sh; do
	[[ " ${modules_text} " != *" ${module} "* ]] || fail "status must not source ${module}"
done
pass "status lazy-loads only required modules"

echo "[OK] T9-02 criteria satisfied"
