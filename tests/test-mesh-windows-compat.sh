#!/usr/bin/env bash
# test-mesh-windows-compat.sh — Windows peer compatibility tests
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
REPO_ROOT="$SCRIPT_DIR"

source "$SCRIPT_DIR/tests/lib/test-helpers.sh"

MESH_ENV_LIB="$REPO_ROOT/scripts/lib/mesh-env-tools.sh"
PEERS_LIB="$REPO_ROOT/scripts/lib/peers.sh"
API_PEERS_PY="$REPO_ROOT/scripts/dashboard_web/api_peers.py"
SCHTASKS_TEMPLATE="$REPO_ROOT/config/mesh-heartbeat.schtasks.template"

run_detect_os_mock() {
local uname_value="$1"
local mock_wsl="${2:-0}"
local mock_dir="$TEST_TEMP_DIR/mock-$RANDOM-$RANDOM"
mkdir -p "$mock_dir"

	cat >"$mock_dir/uname" <<'EOF_UNAME'
#!/usr/bin/env bash
if [[ "$#" -eq 0 || "${1:-}" == "-s" ]]; then
  echo "${MOCK_UNAME_OUTPUT:-Unknown}"
else
  /usr/bin/uname "$@"
fi
EOF_UNAME

cat >"$mock_dir/grep" <<'EOF_GREP'
#!/usr/bin/env bash
if [[ "${MOCK_WSL_GREP:-0}" == "1" ]]; then
  args="$*"
  if [[ "$args" == *"microsoft"* && "$args" == *"/proc/version"* ]]; then
    exit 0
  fi
fi
/usr/bin/grep "$@"
EOF_GREP

chmod +x "$mock_dir/uname" "$mock_dir/grep"

	PATH="$mock_dir:$PATH" MOCK_UNAME_OUTPUT="$uname_value" MOCK_WSL_GREP="$mock_wsl" \
		bash -c "source '$MESH_ENV_LIB'; detect_os"
}

echo "=== Windows Compatibility Tests ==="
echo ""

auto_cleanup_temp_dir

# T1: detect_os MINGW -> windows
RESULT="$(run_detect_os_mock 'MINGW64_NT-10.0')"
if [[ "$RESULT" == "windows" ]]; then
pass "T1: detect_os maps MINGW64_NT-10.0 to windows"
else
fail "T1: detect_os MINGW mapping" "windows" "$RESULT"
fi

# T2: detect_os MSYS -> windows
RESULT="$(run_detect_os_mock 'MSYS_NT-10.0')"
if [[ "$RESULT" == "windows" ]]; then
pass "T2: detect_os maps MSYS_NT-10.0 to windows"
else
fail "T2: detect_os MSYS mapping" "windows" "$RESULT"
fi

# T3: detect_os CYGWIN -> windows
RESULT="$(run_detect_os_mock 'CYGWIN_NT-10.0')"
if [[ "$RESULT" == "windows" ]]; then
pass "T3: detect_os maps CYGWIN_NT-10.0 to windows"
else
fail "T3: detect_os CYGWIN mapping" "windows" "$RESULT"
fi

# T4: detect_os WSL emulation -> windows (mock grep /proc/version)
RESULT="$(run_detect_os_mock 'Linux' '1')"
if [[ "$RESULT" == "windows" ]]; then
pass "T4: detect_os maps Linux+WSL marker to windows"
else
fail "T4: detect_os WSL mapping" "windows" "$RESULT"
fi

# Setup peers.conf for _remote_claude_home tests
TEMP_CONF="$TEST_TEMP_DIR/peers.conf"
cat >"$TEMP_CONF" <<'EOF_PEERS'
[win-peer]
ssh_alias=win-peer
user=alice
os=windows
role=worker
status=active

[linux-peer]
ssh_alias=linux-peer
user=bob
os=linux
role=worker
status=active
EOF_PEERS

# T5: _remote_claude_home windows peer
RESULT="$(PEERS_CONF="$TEMP_CONF" bash -c "source '$PEERS_LIB'; peers_load; _remote_claude_home win-peer")"
if [[ "$RESULT" == '%USERPROFILE%\.claude' ]]; then
pass "T5: _remote_claude_home returns Windows claude home"
else
fail "T5: _remote_claude_home windows" "%USERPROFILE%\\.claude" "$RESULT"
fi

# T6: _remote_claude_home linux peer
RESULT="$(PEERS_CONF="$TEMP_CONF" bash -c "source '$PEERS_LIB'; peers_load; _remote_claude_home linux-peer")"
if [[ "$RESULT" == '~/.claude' ]]; then
pass "T6: _remote_claude_home returns Linux claude home"
else
fail "T6: _remote_claude_home linux" "~/.claude" "$RESULT"
fi

# T7: _VALID_OS includes windows in api_peers.py
TESTS_RUN=$((TESTS_RUN + 1))
if python3 -c "import importlib.util; s=importlib.util.spec_from_file_location('api_peers', '$API_PEERS_PY'); m=importlib.util.module_from_spec(s); s.loader.exec_module(m); import sys; sys.exit(0 if 'windows' in m._VALID_OS else 1)" >/dev/null 2>&1; then
echo -e "${GREEN}✓${NC} T7: api_peers._VALID_OS includes windows"
TESTS_PASSED=$((TESTS_PASSED + 1))
else
echo -e "${RED}✗${NC} T7: api_peers._VALID_OS includes windows"
TESTS_FAILED=$((TESTS_FAILED + 1))
fi

# T8: schtasks template exists and valid XML
assert_file_exists "$SCHTASKS_TEMPLATE" "T8a: mesh-heartbeat.schtasks.template exists"

TESTS_RUN=$((TESTS_RUN + 1))
if python3 -c "import re, xml.etree.ElementTree as ET; data=open('$SCHTASKS_TEMPLATE','rb').read().decode('utf-8', errors='replace'); data=re.sub(r'encoding=\"[^\"]+\"', 'encoding=\"UTF-8\"', data, count=1); ET.fromstring(data)" >/dev/null 2>&1; then
echo -e "${GREEN}✓${NC} T8b: schtasks template is valid XML"
TESTS_PASSED=$((TESTS_PASSED + 1))
else
echo -e "${RED}✗${NC} T8b: schtasks template is valid XML"
TESTS_FAILED=$((TESTS_FAILED + 1))
fi

echo ""
print_test_summary "test-mesh-windows-compat.sh"
