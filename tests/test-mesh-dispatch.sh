#!/usr/bin/env bash
# tests/test-mesh-dispatch.sh — Consolidated dispatch system tests (no real SSH)
# Plan 297 / T3-06 | F-10 through F-19
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

source "$SCRIPT_DIR/lib/test-helpers.sh"

echo "=== test-mesh-dispatch.sh: Dispatch system integration tests ==="
echo ""

# ── mesh-load-query.sh ────────────────────────────────────────────────────────

LOAD_QUERY="$REPO_ROOT/scripts/mesh-load-query.sh"

assert_file_exists "$LOAD_QUERY" "mesh-load-query.sh exists"
assert_bash_syntax "$LOAD_QUERY" "mesh-load-query.sh bash -n passes"
assert_grep '\-\-json' "$LOAD_QUERY" "mesh-load-query.sh --json flag present"
assert_grep 'peer_heartbeats' "$LOAD_QUERY" "mesh-load-query.sh peer_heartbeats write present"

echo ""

# ── mesh-dispatcher.sh ────────────────────────────────────────────────────────

DISPATCHER="$REPO_ROOT/scripts/mesh-dispatcher.sh"

assert_file_exists "$DISPATCHER" "mesh-dispatcher.sh exists"
assert_bash_syntax "$DISPATCHER" "mesh-dispatcher.sh bash -n passes"
assert_grep 'dry.run\|--dry-run' "$DISPATCHER" "mesh-dispatcher.sh --dry-run flag present"
assert_grep 'all.plans\|--all-plans' "$DISPATCHER" "mesh-dispatcher.sh --all-plans flag present"

echo ""

# ── mesh-scoring.sh ───────────────────────────────────────────────────────────

SCORING="$REPO_ROOT/scripts/lib/mesh-scoring.sh"

assert_file_exists "$SCORING" "mesh-scoring.sh exists"
assert_bash_syntax "$SCORING" "mesh-scoring.sh bash -n passes"
assert_grep 'mesh_score_peer' "$SCORING" "mesh-scoring.sh mesh_score_peer function present"
assert_grep 'mesh_best_peer' "$SCORING" "mesh-scoring.sh mesh_best_peer function present"

echo ""

# ── remote-dispatch.sh ────────────────────────────────────────────────────────

REMOTE="$REPO_ROOT/scripts/remote-dispatch.sh"

assert_file_exists "$REMOTE" "remote-dispatch.sh exists"
assert_bash_syntax "$REMOTE" "remote-dispatch.sh bash -n passes"
assert_grep 'peers_check' "$REMOTE" "remote-dispatch.sh peers_check call present"
assert_grep 'token_usage' "$REMOTE" "remote-dispatch.sh token_usage write present"

echo ""

# ── delegate.sh ───────────────────────────────────────────────────────────────

DELEGATE="$REPO_ROOT/scripts/delegate.sh"

assert_file_exists "$DELEGATE" "delegate.sh exists"
assert_bash_syntax "$DELEGATE" "delegate.sh bash -n passes"
assert_grep '\-\-host' "$DELEGATE" "delegate.sh --host flag present"
assert_grep 'remote-dispatch' "$DELEGATE" "delegate.sh remote-dispatch call present"

echo ""

# ── mesh-heartbeat.sh ─────────────────────────────────────────────────────────

HEARTBEAT="$REPO_ROOT/scripts/mesh-heartbeat.sh"

assert_file_exists "$HEARTBEAT" "mesh-heartbeat.sh exists"
assert_bash_syntax "$HEARTBEAT" "mesh-heartbeat.sh bash -n passes"
assert_grep 'start' "$HEARTBEAT" "mesh-heartbeat.sh start subcommand present"
assert_grep 'stop' "$HEARTBEAT" "mesh-heartbeat.sh stop subcommand present"
assert_grep 'status' "$HEARTBEAT" "mesh-heartbeat.sh status subcommand present"

echo ""

# ── orchestrator.yaml ─────────────────────────────────────────────────────────

YAML="$REPO_ROOT/config/orchestrator.yaml"

assert_file_exists "$YAML" "config/orchestrator.yaml exists"

# T: mesh section present
if python3 -c "
import sys, yaml
doc = yaml.safe_load(open('$YAML'))
assert 'mesh' in doc, 'mesh key missing'
" 2>/dev/null; then
	pass "orchestrator.yaml mesh section present and valid YAML"
else
	fail "orchestrator.yaml mesh section missing or YAML invalid"
fi

echo ""
print_test_summary "mesh-dispatch (F-10 through F-19)"
