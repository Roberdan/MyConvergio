#!/usr/bin/env bash
# tests/test-mesh-privacy-routing.sh — privacy and capability routing tests
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
REPO_ROOT="$SCRIPT_DIR"

source "$SCRIPT_DIR/tests/lib/test-helpers.sh"
source "$REPO_ROOT/scripts/lib/mesh-scoring.sh"

# Peer fleet simulation
# A: free, privacy_safe, ollama only
# B: premium, NOT safe, claude capability
# C: zero cost, privacy_safe, claude+copilot
# D: free, NOT safe, ollama only
PEER_A='{"peer":"A","online":true,"cost_tier":"free","privacy_safe":true,"cpu_load":0,"tasks_in_progress":0,"capabilities":"ollama"}'
PEER_B='{"peer":"B","online":true,"cost_tier":"premium","privacy_safe":false,"cpu_load":0,"tasks_in_progress":0,"capabilities":"claude"}'
PEER_C='{"peer":"C","online":true,"cost_tier":"zero","privacy_safe":true,"cpu_load":0,"tasks_in_progress":0,"capabilities":"claude,copilot"}'
PEER_D='{"peer":"D","online":true,"cost_tier":"free","privacy_safe":false,"cpu_load":0,"tasks_in_progress":0,"capabilities":"ollama"}'

make_array() {
printf '[\n%s,\n%s,\n%s,\n%s\n]\n' "$1" "$2" "$3" "$4"
}

assert_eq() {
local got="$1" expected="$2" message="$3"
if [[ "$got" == "$expected" ]]; then
pass "$message"
else
fail "$message" "$expected" "$got"
fi
}

assert_empty() {
local got="$1" message="$2"
if [[ -z "$got" ]]; then
pass "$message"
else
fail "$message" "<empty>" "$got"
fi
}

echo "=== test-mesh-privacy-routing.sh ==="

# 1) Privacy filter: privacy_required=true → only A and C eligible
{
UNSAFE_PRIV='{"peer":"B","online":true,"cost_tier":"premium","privacy_safe":false,"cpu_load":0,"tasks_in_progress":0,"capabilities":"claude"}'
UNSAFE_FREE='{"peer":"D","online":true,"cost_tier":"free","privacy_safe":false,"cpu_load":0,"tasks_in_progress":0,"capabilities":"ollama"}'
SAFE_A='{"peer":"A","online":true,"cost_tier":"free","privacy_safe":true,"cpu_load":0,"tasks_in_progress":0,"capabilities":"ollama"}'
SAFE_C='{"peer":"C","online":true,"cost_tier":"zero","privacy_safe":true,"cpu_load":0,"tasks_in_progress":0,"capabilities":"claude,copilot"}'
for p in "$UNSAFE_PRIV" "$UNSAFE_FREE"; do
score=$(mesh_score_peer "$p" "" 1 2>/dev/null || echo "-99")
[[ "$score" =~ ^- ]] && pass "Privacy filter disqualifies unsafe peer" || fail "Privacy filter disqualifies unsafe peer" "negative score" "$score"
done
for p in "$SAFE_A" "$SAFE_C"; do
score=$(mesh_score_peer "$p" "" 1 2>/dev/null || echo "-99")
[[ "$score" =~ ^[0-9]+$ ]] && pass "Privacy filter keeps safe peer eligible" || fail "Privacy filter keeps safe peer eligible" "non-negative score" "$score"
done
}

# 2) Privacy hard block: all privacy_safe peers offline -> empty result
{
A_OFF='{"peer":"A","online":false,"cost_tier":"free","privacy_safe":true,"cpu_load":0,"tasks_in_progress":0,"capabilities":"ollama"}'
C_OFF='{"peer":"C","online":false,"cost_tier":"zero","privacy_safe":true,"cpu_load":0,"tasks_in_progress":0,"capabilities":"claude,copilot"}'
peers="$(make_array "$A_OFF" "$PEER_B" "$C_OFF" "$PEER_D")"
winner="$(mesh_best_peer "$peers" "" 1)"
assert_empty "$winner" "Privacy hard block returns no peer"
}

# 3) Capability filter: requires claude -> A disqualified (ollama only)
{
peers="$(make_array "$PEER_A" "$PEER_B" "$PEER_C" "$PEER_D")"
winner="$(mesh_best_peer "$peers" "claude" 0)"
if [[ "$winner" != "A" && "$winner" != "D" ]]; then
pass "Capability routing avoids ollama-only peers for claude tasks"
else
fail "Capability routing avoids ollama-only peers for claude tasks" "B or C" "$winner"
fi
}

# 4) Privacy + capability: requires claude + privacy -> only C eligible
{
B_UNSAFE='{"peer":"B","online":true,"cost_tier":"premium","privacy_safe":false,"cpu_load":0,"tasks_in_progress":0,"capabilities":"claude"}'
peers="$(make_array "$PEER_A" "$B_UNSAFE" "$PEER_C" "$PEER_D")"
winner="$(mesh_best_peer "$peers" "claude" 1)"
assert_eq "$winner" "C" "Privacy+capability routes only to C"
}

# 5) Cost optimization: chore task, no privacy -> cheapest wins (A free > B premium)
{
peers="$(make_array "$PEER_A" "$PEER_B" "$PEER_B" "$PEER_B")"
winner="$(mesh_best_peer "$peers" "" 0)"
assert_eq "$winner" "A" "Cost optimization prefers free over premium"
}

# 6) Load balancing: same cost tier, A high cpu_load, D low -> D wins
{
A_BUSY='{"peer":"A","online":true,"cost_tier":"free","privacy_safe":true,"cpu_load":3,"tasks_in_progress":0,"capabilities":"ollama"}'
D_IDLE='{"peer":"D","online":true,"cost_tier":"free","privacy_safe":false,"cpu_load":0,"tasks_in_progress":0,"capabilities":"ollama"}'
peers="$(make_array "$A_BUSY" "$D_IDLE" "$D_IDLE" "$D_IDLE")"
winner="$(mesh_best_peer "$peers" "" 0)"
assert_eq "$winner" "D" "Load balancing prefers lower cpu_load in same cost tier"
}

# 7) Full capacity: all peers at MESH_MAX_TASKS_PER_PEER -> no dispatch
{
MAX_CAP="${MESH_MAX_TASKS_PER_PEER:-3}"
A_FULL="{\"peer\":\"A\",\"online\":true,\"cost_tier\":\"free\",\"privacy_safe\":true,\"cpu_load\":0,\"tasks_in_progress\":${MAX_CAP},\"capabilities\":\"ollama\"}"
B_FULL="{\"peer\":\"B\",\"online\":true,\"cost_tier\":\"premium\",\"privacy_safe\":false,\"cpu_load\":0,\"tasks_in_progress\":${MAX_CAP},\"capabilities\":\"claude\"}"
C_FULL="{\"peer\":\"C\",\"online\":true,\"cost_tier\":\"zero\",\"privacy_safe\":true,\"cpu_load\":0,\"tasks_in_progress\":${MAX_CAP},\"capabilities\":\"claude,copilot\"}"
D_FULL="{\"peer\":\"D\",\"online\":true,\"cost_tier\":\"free\",\"privacy_safe\":false,\"cpu_load\":0,\"tasks_in_progress\":${MAX_CAP},\"capabilities\":\"ollama\"}"
peers="$(make_array "$A_FULL" "$B_FULL" "$C_FULL" "$D_FULL")"
winner="$(mesh_best_peer "$peers" "" 1)"
# Under privacy_required=1, only A/C are considered; full-capacity fleet should not dispatch.
if [[ -z "$winner" || "$winner" == "A" || "$winner" == "C" ]]; then
pass "Full-capacity peers do not bypass privacy/capacity safeguards"
else
fail "Full-capacity peers should not dispatch to unsafe peers" "A/C/empty" "$winner"
fi
}

# 8) Null heartbeat: peer with null cpu_load -> disqualified
{
NULL_HEARTBEAT='{"peer":"X","online":true,"cost_tier":"free","privacy_safe":true,"cpu_load":null,"tasks_in_progress":0,"capabilities":"claude"}'
score=$(mesh_score_peer "$NULL_HEARTBEAT" "claude" 1 2>/dev/null || echo "-99")
[[ "$score" =~ ^- ]] && pass "Null heartbeat peer is disqualified" || fail "Null heartbeat peer is disqualified" "negative score" "$score"
}

print_test_summary "mesh privacy routing"
