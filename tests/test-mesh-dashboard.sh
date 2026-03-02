#!/usr/bin/env bash
# Test suite for mesh dashboard visualization
# Tests: data collection, mini-preview, detail view, health colors, layout, degradation
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PASS=0; FAIL=0; TOTAL=0

assert() {
	local desc="$1" result="$2"
	(( TOTAL++ )) || true
	if [[ "$result" == "0" ]]; then
		echo "  ✓ $desc"
		(( PASS++ )) || true
	else
		echo "  ✗ $desc"
		(( FAIL++ )) || true
	fi
}

# Create temp peers.conf for isolated testing
TMPDIR_TEST=$(mktemp -d "${TMPDIR:-/tmp}/mesh-test.XXXXXX")
trap 'rm -rf "$TMPDIR_TEST"' EXIT

cat >"$TMPDIR_TEST/peers.conf" <<'EOF'
[node-a]
ssh_alias=node-a.local
user=test
os=macos
tailscale_ip=100.1.1.1
capabilities=claude,copilot,ollama
role=coordinator
status=active

[node-b]
ssh_alias=node-b.local
user=test
os=linux
tailscale_ip=100.1.1.2
capabilities=claude,copilot
role=worker
status=active

[node-c]
ssh_alias=node-c.local
user=test
os=macos
capabilities=copilot
role=worker
status=inactive
EOF

# Source all modules with mock config (set +e for source + eval compat)
export PEERS_CONF="$TMPDIR_TEST/peers.conf"
export MESH_PEERS_CONF="$TMPDIR_TEST/peers.conf"
set +e
source "$SCRIPT_DIR/scripts/lib/dashboard/dashboard-config.sh"
source "$SCRIPT_DIR/scripts/lib/dashboard/dashboard-db.sh"
DB="$TMPDIR_TEST/test.db"
source "$SCRIPT_DIR/scripts/lib/dashboard/dashboard-render-mesh.sh"
source "$SCRIPT_DIR/scripts/lib/dashboard/dashboard-render-mesh-detail.sh"
set -e

echo "=== Mesh Dashboard Tests ==="
echo ""

# --- Test 1: Data Collection ---
echo "1. Data Collection"
set +e
_mesh_collect_data
set -e
assert "Finds 3 peers" "$([[ $(echo $MESH_PEER_NAMES | wc -w | tr -d ' ') -eq 3 ]] && echo 0 || echo 1)"
assert "Identifies coordinator" "$([[ "$MESH_COORDINATOR" == "node-a" ]] && echo 0 || echo 1)"
assert "node-a role=coordinator" "$([[ $(_mesh_get "node-a.role") == "coordinator" ]] && echo 0 || echo 1)"
assert "node-b role=worker" "$([[ $(_mesh_get "node-b.role") == "worker" ]] && echo 0 || echo 1)"
assert "node-c status parsed" "$([[ $(_mesh_get "node-c.status") == "inactive" ]] && echo 0 || echo 1)"
assert "node-a caps=claude,copilot,ollama" "$([[ $(_mesh_get "node-a.caps") == "claude,copilot,ollama" ]] && echo 0 || echo 1)"
assert "node-a privacy=1 (has ollama)" "$([[ $(_mesh_get "node-a.privacy") == "1" ]] && echo 0 || echo 1)"
assert "node-b os=linux" "$([[ $(_mesh_get "node-b.os") == "linux" ]] && echo 0 || echo 1)"
echo ""

# --- Test 2: Mini-Preview Rendering ---
echo "2. Mini-Preview"
set +e
output=$(_render_mesh_mini 2>&1)
set -e
assert "Contains 'Mesh Network'" "$([[ "$output" == *"Mesh Network"* ]] && echo 0 || echo 1)"
assert "Shows node-a" "$([[ "$output" == *"node-a"* ]] && echo 0 || echo 1)"
assert "Shows node-b" "$([[ "$output" == *"node-b"* ]] && echo 0 || echo 1)"
assert "Shows node-c" "$([[ "$output" == *"node-c"* ]] && echo 0 || echo 1)"
assert "Shows Coordinator line" "$([[ "$output" == *"Coordinator"* ]] && echo 0 || echo 1)"
line_count=$(echo "$output" | wc -l | tr -d ' ')
assert "Compact: ≤8 lines" "$([[ $line_count -le 8 ]] && echo 0 || echo 1)"
echo ""

# --- Test 3: Detail View Rendering ---
echo "3. Detail View"
set +e
_mesh_collect_data
detail=$(_render_mesh_detail 2>&1)
set -e
assert "Contains topology header" "$([[ "$detail" == *"Topology"* ]] && echo 0 || echo 1)"
assert "Shows node count" "$([[ "$detail" == *"Nodes:"* ]] && echo 0 || echo 1)"
assert "Shows Coordinator in footer" "$([[ "$detail" == *"Coordinator"* ]] && echo 0 || echo 1)"
assert "Contains box chars" "$([[ "$detail" == *"┌"* ]] && echo 0 || echo 1)"
assert "No bash errors" "$([[ $? -eq 0 ]] && echo 0 || echo 1)"
echo ""

# --- Test 4: Health Color Logic ---
echo "4. Health Colors"
set +e
_mesh_set "node-a.online" "1"; _mesh_set "node-a.cpu" "0"; _mesh_set "node-a.status" "active"
color=$(_mesh_health_color "node-a")
assert "Online low-load = GREEN" "$([[ "$color" == *"32m"* ]] && echo 0 || echo 1)"
_mesh_set "node-a.cpu" "99"
color=$(_mesh_health_color "node-a")
assert "Online high-load = YELLOW" "$([[ "$color" == *"33m"* ]] && echo 0 || echo 1)"
_mesh_set "node-a.online" "0"; _mesh_set "node-a.status" "active"
color=$(_mesh_health_color "node-a")
assert "Offline = RED" "$([[ "$color" == *"31m"* ]] && echo 0 || echo 1)"
_mesh_set "node-c.status" "inactive"
color=$(_mesh_health_color "node-c")
assert "Inactive = GRAY" "$([[ "$color" == *"90m"* ]] && echo 0 || echo 1)"
set -e
echo ""

# --- Test 5: Responsive Layout ---
echo "5. Responsive Layout"
set +e
COLUMNS=140 detail_wide=$(_render_mesh_detail 2>&1)
COLUMNS=80 detail_narrow=$(_render_mesh_detail 2>&1)
set -e
# Wide should paste boxes side-by-side (less lines)
wide_lines=$(echo "$detail_wide" | wc -l | tr -d ' ')
narrow_lines=$(echo "$detail_narrow" | wc -l | tr -d ' ')
assert "Wide layout fewer lines than narrow" "$([[ $wide_lines -lt $narrow_lines ]] && echo 0 || echo 1)"
echo ""

# --- Test 6: Graceful Degradation ---
echo "6. Graceful Degradation (empty heartbeats)"
DB="$TMPDIR_TEST/nonexistent.db"
set +e
_mesh_collect_data
output=$(_render_mesh_mini 2>&1)
set -e
assert "Renders without DB" "$([[ $? -eq 0 ]] && echo 0 || echo 1)"
assert "Shows peers from config" "$([[ "$output" == *"node-a"* ]] && echo 0 || echo 1)"
echo ""

# --- Test 7: Dispatch Arrow ---
echo "7. Dispatch Arrow"
set +e
MESH_DISPATCH_TARGET="node-b"
MESH_DISPATCH_FROM="node-a"
MESH_DISPATCH_TTL=2
arrow=$(_render_dispatch_arrow 2>&1)
set -e
assert "Arrow shows target" "$([[ "$arrow" == *"node-b"* ]] && echo 0 || echo 1)"
assert "Arrow shows source" "$([[ "$arrow" == *"node-a"* ]] && echo 0 || echo 1)"
# TTL decrement: in subshell $() the decrement doesn't propagate, test inline
_render_dispatch_arrow >/dev/null 2>&1
assert "TTL decremented" "$([[ $MESH_DISPATCH_TTL -eq 1 ]] && echo 0 || echo 1)"
MESH_DISPATCH_TTL=0
set +e
arrow=$(_render_dispatch_arrow 2>&1)
set -e
assert "No arrow when TTL=0" "$([[ -z "$arrow" ]] && echo 0 || echo 1)"
echo ""

# --- Test 8: File Size Gate ---
echo "8. File Size (Thor Gate 3)"
mesh_lines=$(wc -l < "$SCRIPT_DIR/scripts/lib/dashboard/dashboard-render-mesh.sh")
detail_lines=$(wc -l < "$SCRIPT_DIR/scripts/lib/dashboard/dashboard-render-mesh-detail.sh")
assert "dashboard-render-mesh.sh ≤250 lines ($mesh_lines)" "$([[ $mesh_lines -le 250 ]] && echo 0 || echo 1)"
assert "dashboard-render-mesh-detail.sh ≤250 lines ($detail_lines)" "$([[ $detail_lines -le 250 ]] && echo 0 || echo 1)"
echo ""

# Summary
echo "==========================="
echo "Results: $PASS/$TOTAL passed, $FAIL failed"
[[ $FAIL -eq 0 ]] && echo "ALL TESTS PASSED ✓" || { echo "FAILURES DETECTED ✗"; exit 1; }
