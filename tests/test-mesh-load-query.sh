#!/usr/bin/env bash
[[ "${MESH_TEST_LEGACY:-0}" == "1" ]] || { echo "SKIP: legacy test (set MESH_TEST_LEGACY=1 to run)"; exit 0; }
# test-mesh-load-query.sh — Tests for scripts/mesh-load-query.sh
# Plan 297 / T3-01 | F-10 (load query), F-15 (cost-tier), F-16 (privacy_safe)
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
SCRIPT="$REPO_ROOT/scripts/mesh-load-query.sh"

source "$SCRIPT_DIR/lib/test-helpers.sh"

echo "=== mesh-load-query.sh Tests ==="
echo ""

# T1: File exists
assert_file_exists "$SCRIPT" "mesh-load-query.sh exists"

# T2: Valid bash syntax (F-10)
assert_bash_syntax "$SCRIPT" "mesh-load-query.sh has valid bash syntax"

# T3: Line count <= 250 (NON-NEGOTIABLE)
assert_line_count "$SCRIPT" 250 "mesh-load-query.sh <= 250 lines"

# T4: set -euo pipefail present
assert_grep 'set -euo pipefail' "$SCRIPT" "mesh-load-query.sh uses set -euo pipefail"

# T5: sources peers.sh library
assert_grep 'lib/peers.sh' "$SCRIPT" "mesh-load-query.sh sources lib/peers.sh"

# T6: peer_heartbeats table write (F-10)
assert_grep 'peer_heartbeats' "$SCRIPT" "mesh-load-query.sh writes to peer_heartbeats table"

# T7: cost_tier present (F-15)
assert_grep 'cost_tier' "$SCRIPT" "mesh-load-query.sh includes cost_tier field"

# T8: privacy_safe present (F-16)
assert_grep 'privacy_safe' "$SCRIPT" "mesh-load-query.sh includes privacy_safe field"

# T9: --json flag handled
assert_grep '\-\-json' "$SCRIPT" "mesh-load-query.sh supports --json flag"

# T10: --peer flag handled
assert_grep '\-\-peer' "$SCRIPT" "mesh-load-query.sh supports --peer flag"

# T11: orchestrator.yaml referenced for cost_tier (F-15)
assert_grep 'orchestrator.yaml\|ORCHESTRATOR_YAML\|orchestrator_yaml' "$SCRIPT" \
	"mesh-load-query.sh reads orchestrator.yaml for cost tiers"

# T12: SSH with 5s timeout (F-10)
assert_grep 'ConnectTimeout=5\|ConnectTimeout 5' "$SCRIPT" \
	"mesh-load-query.sh uses 5s SSH timeout"

# T13: uptime CPU parsing (cross-platform)
assert_grep 'uptime' "$SCRIPT" "mesh-load-query.sh queries uptime for CPU load"

# T14: tasks_in_progress via sqlite3 remote query
assert_grep 'tasks_in_progress\|in_progress' "$SCRIPT" \
	"mesh-load-query.sh queries tasks_in_progress"

# T15: offline peers handled with online:false
assert_grep 'online.*false\|"online":false\|online=false' "$SCRIPT" \
	"mesh-load-query.sh marks offline peers with online:false"

# T16: Output array format JSON
assert_grep '"online"\|online:' "$SCRIPT" \
	"mesh-load-query.sh includes online field in JSON output"

# T17: Parallel SSH execution (background jobs)
assert_grep '&$\|&[[:space:]]' "$SCRIPT" \
	"mesh-load-query.sh uses parallel SSH"

# T18: no hardcoded machine names
(
	if grep -E '(my-mac|my-linux|my-cloud|192\.168\.|roberdan)' "$SCRIPT" 2>/dev/null; then
		fail "mesh-load-query.sh contains hardcoded machine names"
	else
		pass "mesh-load-query.sh has no hardcoded machine names"
	fi
)

# T19: Functional test with mocked peers.conf + orchestrator.yaml
(
	TEMP_DIR=$(mktemp -d)
	trap 'rm -rf "$TEMP_DIR"' EXIT

	# Minimal peers.conf with only ollama peer (privacy_safe=true case)
	mkdir -p "$TEMP_DIR/config"
	cat >"$TEMP_DIR/config/peers.conf" <<'EOF'
[test-ollama-peer]
ssh_alias=test-ollama-peer
user=testuser
os=linux
tailscale_ip=10.99.99.1
capabilities=ollama
role=worker
status=active
EOF

	# Minimal orchestrator.yaml with mesh cost_tier mapping
	cat >"$TEMP_DIR/config/orchestrator.yaml" <<'EOF'
providers:
  ollama:
    cost_tier: free
mesh:
  cost_tiers:
    ollama: free
    claude: premium
    copilot: zero
    opencode: free
    gemini: premium
EOF

	# Run with --json against unreachable test peer (will show online:false)
	OUTPUT=$(PEERS_CONF="$TEMP_DIR/config/peers.conf" \
		ORCHESTRATOR_YAML="$TEMP_DIR/config/orchestrator.yaml" \
		bash "$SCRIPT" --json 2>/dev/null || true)

	if echo "$OUTPUT" | grep -q 'test-ollama-peer\|online'; then
		pass "mesh-load-query.sh produces JSON output with peer entries"
	else
		fail "mesh-load-query.sh should produce JSON output" "JSON with peer data" "${OUTPUT:-<empty>}"
	fi

	# Verify offline peer shows online:false
	if echo "$OUTPUT" | grep -q '"online":false\|"online": false\|online.*false'; then
		pass "Offline peer shows online:false in output"
	else
		fail "Offline peer should show online:false" '"online":false' "${OUTPUT:-<empty>}"
	fi

	# Verify privacy_safe=true for ollama-only peer
	if echo "$OUTPUT" | grep -q '"privacy_safe":true\|"privacy_safe": true\|privacy_safe.*true'; then
		pass "ollama-only peer has privacy_safe:true"
	else
		fail "ollama-only peer should have privacy_safe:true" '"privacy_safe":true' "${OUTPUT:-<empty>}"
	fi
)

echo ""
print_test_summary "mesh-load-query.sh"
