#!/usr/bin/env bash
# tests/test-auth-sync.sh — Syntax and structure tests for scripts/mesh-auth-sync.sh
# Verifies: bash -n passes, required functions/subcommands present, no /tmp credential writes.
# No real SSH is performed.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
SCRIPT="$REPO_ROOT/scripts/mesh-auth-sync.sh"

source "$SCRIPT_DIR/lib/test-helpers.sh"

echo "=== test-auth-sync.sh: mesh-auth-sync.sh syntax and structure tests ==="
echo ""

# --- T1: Script file exists ---
assert_file_exists "$SCRIPT" "T1: mesh-auth-sync.sh exists at scripts/mesh-auth-sync.sh"

# --- T2: bash -n syntax check passes ---
TESTS_RUN=$((TESTS_RUN + 1))
if bash -n "$SCRIPT" 2>/dev/null; then
	pass "T2: bash -n syntax check passes"
else
	SYNTAX_ERR=$(bash -n "$SCRIPT" 2>&1 || true)
	fail "T2: bash -n syntax check failed" "no errors" "$SYNTAX_ERR"
fi

# --- T3: Script is executable ---
assert_executable "$SCRIPT" "T3: mesh-auth-sync.sh is executable"

# --- T4: Correct shebang ---
TESTS_RUN=$((TESTS_RUN + 1))
FIRST_LINE="$(sed -n '1p' "$SCRIPT")"
if [[ "$FIRST_LINE" == "#!/usr/bin/env bash" ]]; then
	pass "T4: shebang is #!/usr/bin/env bash"
else
	fail "T4: shebang check" "#!/usr/bin/env bash" "$FIRST_LINE"
fi

# --- T5: set -euo pipefail present ---
assert_grep "set -euo pipefail" "$SCRIPT" "T5: set -euo pipefail present"

# --- T6: push subcommand present (function or case label) ---
TESTS_RUN=$((TESTS_RUN + 1))
if grep -qE 'cmd_push|push\)' "$SCRIPT"; then
	pass "T6: push subcommand present (cmd_push or push) case)"
else
	fail "T6: push subcommand missing — expected cmd_push or push) case"
fi

# --- T7: status subcommand present ---
TESTS_RUN=$((TESTS_RUN + 1))
if grep -qE 'cmd_status|status\)' "$SCRIPT"; then
	pass "T7: status subcommand present (cmd_status or status) case)"
else
	fail "T7: status subcommand missing — expected cmd_status or status) case"
fi

# --- T8: sources scripts/lib/peers.sh ---
assert_grep "peers.sh" "$SCRIPT" "T8: sources scripts/lib/peers.sh"

# --- T9: references credentials.json (Claude credentials sync) ---
assert_grep "credentials.json" "$SCRIPT" "T9: references credentials.json"

# --- T10: uses gh auth token (Copilot sync) ---
assert_grep "gh auth token" "$SCRIPT" "T10: references 'gh auth token'"

# --- T11: permission 600 referenced (secure file permissions on remote) ---
assert_grep "600" "$SCRIPT" "T11: permission 600 referenced for secure remote files"

# --- T12: No /tmp credential writes ---
# Pattern: writing token/key/secret/credential content to /tmp
TESTS_RUN=$((TESTS_RUN + 1))
TMP_CRED_PATTERN='> /tmp.*(token|secret|key|cred)|/tmp.*(token|secret|key|cred).*>'
if grep -qiE "$TMP_CRED_PATTERN" "$SCRIPT"; then
	fail "T12: credentials written to /tmp (SECURITY VIOLATION)"
else
	pass "T12: no /tmp credential writes detected"
fi

# --- T13: Broader /tmp credential check (grep for common patterns) ---
TESTS_RUN=$((TESTS_RUN + 1))
# Check for any variable containing sensitive value written to /tmp
BROAD_TMP_PATTERN='/tmp/.*\.(json|env|token|key|secret|cred)'
if grep -qiE "$BROAD_TMP_PATTERN" "$SCRIPT"; then
	# Inspect the actual match to verify it's truly a credential write
	MATCH=$(grep -iE "$BROAD_TMP_PATTERN" "$SCRIPT" | head -1)
	fail "T13: potential credential file in /tmp" "no /tmp credential files" "$MATCH"
else
	pass "T13: no credential-named files in /tmp path"
fi

# --- T14: No plaintext HTTP (must use SSH transport) ---
TESTS_RUN=$((TESTS_RUN + 1))
if grep -q 'http://' "$SCRIPT"; then
	MATCH=$(grep 'http://' "$SCRIPT" | head -1)
	fail "T14: uses http:// (SECURITY VIOLATION — must use SSH)" "" "$MATCH"
else
	pass "T14: no http:// — SSH-only transport"
fi

# --- T15: uses CLAUDE_HOME variable (not hardcoded ~/.claude paths) ---
assert_grep "CLAUDE_HOME" "$SCRIPT" "T15: uses CLAUDE_HOME variable (no hardcoded home paths)"

# --- T16: --peer flag handled ---
TESTS_RUN=$((TESTS_RUN + 1))
if grep -q -- '--peer' "$SCRIPT"; then
	pass "T16: --peer flag handled"
else
	fail "T16: --peer flag not found"
fi

# --- T17: --all flag handled ---
TESTS_RUN=$((TESTS_RUN + 1))
if grep -q -- '--all' "$SCRIPT"; then
	pass "T17: --all flag handled"
else
	fail "T17: --all flag not found"
fi

# --- T18: Security disclaimer present ---
TESTS_RUN=$((TESTS_RUN + 1))
if grep -qiE 'full access|own and control|grant.*access' "$SCRIPT"; then
	pass "T18: security disclaimer about token access present"
else
	fail "T18: security disclaimer missing (tokens grant full access)"
fi

# --- T19: OpenCode referenced (opencode config sync) ---
TESTS_RUN=$((TESTS_RUN + 1))
if grep -qi 'opencode' "$SCRIPT"; then
	pass "T19: OpenCode sync referenced"
else
	fail "T19: OpenCode not referenced — missing sync support"
fi

# --- T20: Ollama referenced (ollama API key sync) ---
TESTS_RUN=$((TESTS_RUN + 1))
if grep -qi 'ollama' "$SCRIPT"; then
	pass "T20: Ollama sync referenced"
else
	fail "T20: Ollama not referenced — missing sync support"
fi

# --- T21: No credential value logging (no echo of $TOKEN / $KEY etc.) ---
TESTS_RUN=$((TESTS_RUN + 1))
if grep -qE 'echo.*\$TOKEN|echo.*\$KEY|echo.*\$SECRET|info.*\$token|ok.*\$token' "$SCRIPT"; then
	MATCH=$(grep -E 'echo.*\$TOKEN|echo.*\$KEY|echo.*\$SECRET' "$SCRIPT" | head -1)
	fail "T21: potential credential value logging detected" "" "$MATCH"
else
	pass "T21: no credential value logging detected"
fi

# --- T22: Under 250 lines ---
TESTS_RUN=$((TESTS_RUN + 1))
LINE_COUNT=$(wc -l <"$SCRIPT" | tr -d ' ')
if [[ "$LINE_COUNT" -le 250 ]]; then
	pass "T22: mesh-auth-sync.sh under 250 lines ($LINE_COUNT)"
else
	fail "T22: exceeds 250-line limit" "<=250" "$LINE_COUNT"
fi

# --- T23: No personal hostnames hardcoded ---
TESTS_RUN=$((TESTS_RUN + 1))
if grep -qE 'roberdan|omarchy|mariodan' "$SCRIPT"; then
	MATCH=$(grep -E 'roberdan|omarchy|mariodan' "$SCRIPT" | head -1)
	fail "T23: personal hostnames hardcoded (C-07 violation)" "" "$MATCH"
else
	pass "T23: no personal hostnames hardcoded"
fi

# --- T24: Script requires subcommand or shows usage on empty args ---
# Run with PEERS_CONF pointing to a dummy (so peers_load doesn't fail on missing file)
DUMMY_CONF="$(mktemp)"
trap 'rm -f "$DUMMY_CONF"' EXIT
cat >"$DUMMY_CONF" <<'EOF'
[dummy]
ssh_alias=dummy
user=nobody
os=linux
tailscale_ip=127.0.0.1
capabilities=claude
role=worker
status=active
EOF

TESTS_RUN=$((TESTS_RUN + 1))
# status is the default subcommand — it should at least attempt to run (may fail on SSH)
HELP_OUT=$(bash "$SCRIPT" --help 2>&1 || true)
if echo "$HELP_OUT" | grep -qi 'usage\|push\|status'; then
	pass "T24: --help shows usage with push/status subcommands"
else
	fail "T24: --help should show usage" "usage text with push|status" "$HELP_OUT"
fi

echo ""
print_test_summary "test-auth-sync.sh"
