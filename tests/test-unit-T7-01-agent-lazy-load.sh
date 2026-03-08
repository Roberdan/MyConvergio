#!/usr/bin/env bash
set -euo pipefail

source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/lib/test-helpers.sh"
setup_test_env

AGENTS_FILE="${REPO_ROOT}/AGENTS.md"
REFERENCE_DIR="${REPO_ROOT}/reference/agents"

fail() {
  echo "[FAIL] $1" >&2
  exit 1
}

pass() {
  echo "[PASS] $1"
}

[[ -f "$AGENTS_FILE" ]] || fail "AGENTS.md must exist"
[[ -d "$REFERENCE_DIR" ]] || fail "reference/agents directory must exist"

size_bytes=$(wc -c < "$AGENTS_FILE" | tr -d ' ')
[[ "$size_bytes" -lt 8000 ]] || fail "AGENTS.md must be <8000 bytes (got ${size_bytes})"
pass "AGENTS.md size under 8000 bytes"

grep -q "## Agent Index" "$AGENTS_FILE" || fail "AGENTS.md must expose Agent Index section"
grep -q "@reference/agents/" "$AGENTS_FILE" || fail "AGENTS.md must reference lazy-loaded agent manifests"
pass "AGENTS.md uses @reference/agents lazy references"

# Require at least one manifest file for lazy-load map
manifest_count=$(find "$REFERENCE_DIR" -type f -name '*.md' | wc -l | tr -d ' ')
[[ "$manifest_count" -ge 1 ]] || fail "reference/agents must contain markdown manifests"
pass "reference/agents manifests exist (${manifest_count})"

echo "[OK] T7-01 criteria satisfied"
