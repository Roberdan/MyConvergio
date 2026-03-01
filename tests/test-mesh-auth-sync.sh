#!/usr/bin/env bash
# test-mesh-auth-sync.sh — Tests for scripts/mesh-auth-sync.sh
# Verifies syntax, required patterns, and subcommand structure (no real SSH)
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
SCRIPT="$REPO_ROOT/scripts/mesh-auth-sync.sh"

source "$SCRIPT_DIR/lib/test-helpers.sh"
setup_temp_dir

echo "=== mesh-auth-sync.sh Tests ==="
echo ""

# T1: File exists
assert_file_exists "$SCRIPT" "mesh-auth-sync.sh exists"

# T2: Bash syntax check
TESTS_RUN=$((TESTS_RUN + 1))
if bash -n "$SCRIPT" 2>/dev/null; then
	pass "bash -n syntax valid"
else
	fail "bash -n syntax check failed"
fi

# T3: Executable
assert_executable "$SCRIPT" "mesh-auth-sync.sh is executable"

# T4: shebang is #!/usr/bin/env bash
TESTS_RUN=$((TESTS_RUN + 1))
first_line="$(sed -n '1p' "$SCRIPT")"
if [[ "$first_line" == "#!/usr/bin/env bash" ]]; then
	pass "shebang is #!/usr/bin/env bash"
else
	fail "shebang check" "#!/usr/bin/env bash" "$first_line"
fi

# T5: set -euo pipefail present
TESTS_RUN=$((TESTS_RUN + 1))
if grep -q 'set -euo pipefail' "$SCRIPT"; then
	pass "set -euo pipefail present"
else
	fail "set -euo pipefail missing"
fi

# T6: sources peers.sh
TESTS_RUN=$((TESTS_RUN + 1))
if grep -q 'peers.sh' "$SCRIPT"; then
	pass "sources scripts/lib/peers.sh"
else
	fail "does not source peers.sh"
fi

# T7: credentials.json referenced (Claude Code sync)
TESTS_RUN=$((TESTS_RUN + 1))
if grep -q 'credentials.json' "$SCRIPT"; then
	pass "references credentials.json"
else
	fail "credentials.json not referenced"
fi

# T8: gh auth token referenced (Copilot sync)
TESTS_RUN=$((TESTS_RUN + 1))
if grep -q 'gh auth token' "$SCRIPT"; then
	pass "references 'gh auth token'"
else
	fail "'gh auth token' not found"
fi

# T9: permission 600 set on remote
TESTS_RUN=$((TESTS_RUN + 1))
if grep -q '600' "$SCRIPT"; then
	pass "permission 600 referenced"
else
	fail "permission 600 not referenced"
fi

# T10: no /tmp used for credentials
TESTS_RUN=$((TESTS_RUN + 1))
if grep -q '> /tmp.*token\|> /tmp.*secret\|> /tmp.*key\|/tmp.*cred' "$SCRIPT"; then
	fail "credentials written to /tmp (SECURITY VIOLATION)"
else
	pass "no credentials written to /tmp"
fi

# T11: no http:// (must use SSH)
TESTS_RUN=$((TESTS_RUN + 1))
if grep -q 'http://' "$SCRIPT"; then
	fail "uses http:// (SECURITY VIOLATION — must use SSH)"
else
	pass "no http:// (SSH-only transport)"
fi

# T12: CLAUDE_HOME used (not hardcoded paths)
TESTS_RUN=$((TESTS_RUN + 1))
if grep -q 'CLAUDE_HOME' "$SCRIPT"; then
	pass "uses CLAUDE_HOME variable"
else
	fail "CLAUDE_HOME not used — uses hardcoded paths?"
fi

# T13: no personal hostnames
TESTS_RUN=$((TESTS_RUN + 1))
if grep -qE 'roberdan|omarchy|mariodan' "$SCRIPT"; then
	fail "personal hostnames found (C-07 violation)"
else
	pass "no personal hostnames"
fi

# T14: NEVER log credential values (no echo of token/key variable contents)
TESTS_RUN=$((TESTS_RUN + 1))
# Look for direct echo of secret variable contents (not help text)
if grep -qE 'echo.*\$TOKEN|echo.*\$KEY|echo.*\$SECRET|info.*\$token|ok.*\$token' "$SCRIPT"; then
	fail "potential credential value logging detected"
else
	pass "no credential value logging"
fi

# T15: under 250 lines
TESTS_RUN=$((TESTS_RUN + 1))
line_count="$(wc -l <"$SCRIPT")"
if [[ "$line_count" -le 250 ]]; then
	pass "under 250 lines ($line_count)"
else
	fail "exceeds 250 lines" "<=250" "$line_count"
fi

# T16: status subcommand in script
TESTS_RUN=$((TESTS_RUN + 1))
if grep -q 'cmd_status\|status)' "$SCRIPT"; then
	pass "status subcommand present"
else
	fail "status subcommand missing"
fi

# T17: push subcommand in script
TESTS_RUN=$((TESTS_RUN + 1))
if grep -q 'cmd_push\|push)' "$SCRIPT"; then
	pass "push subcommand present"
else
	fail "push subcommand missing"
fi

# T18: --peer and --all flags handled
TESTS_RUN=$((TESTS_RUN + 1))
if grep -q '\-\-peer\|\-\-all' "$SCRIPT"; then
	pass "--peer and --all flags handled"
else
	fail "--peer / --all flags not found"
fi

# T19: disclaimer about full access
TESTS_RUN=$((TESTS_RUN + 1))
if grep -qi 'full access\|own and control\|grant.*access' "$SCRIPT"; then
	pass "disclaimer about token access present"
else
	fail "security disclaimer missing"
fi

# T20: OpenCode referenced
TESTS_RUN=$((TESTS_RUN + 1))
if grep -qi 'opencode' "$SCRIPT"; then
	pass "OpenCode referenced"
else
	fail "OpenCode not referenced"
fi

# T21: Ollama referenced
TESTS_RUN=$((TESTS_RUN + 1))
if grep -qi 'ollama' "$SCRIPT"; then
	pass "Ollama referenced"
else
	fail "Ollama not referenced"
fi

# Summary
echo ""
echo "=== Results: $TESTS_PASSED/$TESTS_RUN passed, $TESTS_FAILED failed ==="
[[ "$TESTS_FAILED" -eq 0 ]] && exit 0 || exit 1
