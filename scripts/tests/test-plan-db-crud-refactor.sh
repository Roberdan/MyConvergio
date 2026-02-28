#!/usr/bin/env bash
set -euo pipefail

export PATH="$HOME/.claude/scripts:$PATH"
CRUD_FILE="$HOME/.claude/scripts/lib/plan-db-crud.sh"
DB_FILE="$HOME/.claude/data/dashboard.db"

fail() {
  echo "FAIL: $1" >&2
  exit 1
}

line_count=$(wc -l "$CRUD_FILE" | awk '{print $1}')
[[ "$line_count" -lt 200 ]] || fail "plan-db-crud.sh must be <200 lines (got $line_count)"

name="test-refactor-$(date +%s)-$$"
plan_id="$(plan-db.sh create virtualbpm "$name" --source-file /dev/null --human-summary test 2>${TMPDIR:-/tmp}/test-plan-create.err)" || fail "plan-db.sh create failed: $(cat ${TMPDIR:-/tmp}/test-plan-create.err)"
[[ -n "$plan_id" ]] || fail "plan-db.sh create did not return plan id"

plan-db.sh execution-tree "$plan_id" >${TMPDIR:-/tmp}/test-plan-tree.out 2>${TMPDIR:-/tmp}/test-plan-tree.err || fail "execution-tree failed: $(cat ${TMPDIR:-/tmp}/test-plan-tree.err)"

sqlite3 "$DB_FILE" "DELETE FROM tasks WHERE plan_id=$plan_id; DELETE FROM waves WHERE plan_id=$plan_id; DELETE FROM plans WHERE id=$plan_id;" >/dev/null 2>&1 || true
rm -f ${TMPDIR:-/tmp}/test-plan-create.err ${TMPDIR:-/tmp}/test-plan-tree.out ${TMPDIR:-/tmp}/test-plan-tree.err

echo "PASS: plan-db CRUD refactor acceptance checks"
