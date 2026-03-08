#!/usr/bin/env bash
set -euo pipefail

source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/lib/test-helpers.sh"
setup_test_env

SQL_UTILS="$REPO_ROOT/scripts/lib/sql-utils.sh"

fail() {
	echo "[FAIL] $1" >&2
	exit 1
}

pass() {
	echo "[PASS] $1"
}

[[ -f "$SQL_UTILS" ]] || fail "scripts/lib/sql-utils.sh must exist"
[[ -x "$SQL_UTILS" ]] || fail "scripts/lib/sql-utils.sh must be executable"
pass "canonical sql utils exists"

# shellcheck source=/dev/null
source "$SQL_UTILS"

escaped="$(sql_escape "O'Reilly"$'\n'"Books")"
[[ "$escaped" == "O''Reilly Books" ]] || fail "sql_escape must escape quotes and normalize newlines"
pass "sql_escape canonical behavior"

quoted="$(sql_quote "O'Reilly")"
[[ "$quoted" == "'O''Reilly'" ]] || fail "sql_quote must return SQL single-quoted literal"
pass "sql_quote behavior"

null_lit="$(sql_quote_or_null "")"
[[ "$null_lit" == "NULL" ]] || fail "sql_quote_or_null must return NULL for empty values"
pass "sql_quote_or_null behavior"

extra_defs="$(
	{
		rg "^[[:space:]]*sql_escape\\s*\\(" "$REPO_ROOT/scripts" "$REPO_ROOT/hooks" "$REPO_ROOT/copilot-config/hooks" \
			--glob "*.sh" -n || true
	} | awk -v canonical="$REPO_ROOT/scripts/lib/sql-utils.sh" 'index($0, canonical) == 0 && NF > 0 { c++ } END { print c + 0 }'
)"
[[ "$extra_defs" == "0" ]] || fail "sql_escape must be defined only in scripts/lib/sql-utils.sh (found $extra_defs extra definitions)"
pass "single sql_escape definition"

lib_refs="$(
	{
		grep -rn 'sql_escape' "$REPO_ROOT/scripts/lib/" || true
	} | awk 'index($0, "sql-utils.sh") == 0 && NF > 0 { c++ } END { print c + 0 }'
)"
[[ "$lib_refs" == "0" ]] || fail "scripts/lib must not reference sql_escape outside sql-utils.sh (found $lib_refs)"
pass "scripts/lib sql_escape references removed"

echo "[OK] T9-03 criteria satisfied"
