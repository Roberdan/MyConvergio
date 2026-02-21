#!/bin/bash
# RED tests for env-vault-guard.sh
set -euo pipefail

fail() { echo "FAIL: $1"; exit 1; }

# Test 1: Syntax check
bash -n /Users/roberdan/.claude-convergio-orchestrator/hooks/env-vault-guard.sh || fail "Syntax check failed"

# Test 2: Secret pattern grep
if grep 'API_KEY\|SECRET\|PASSWORD' /Users/roberdan/.claude-convergio-orchestrator/hooks/env-vault-guard.sh; then echo "Secret pattern found"; else fail "Secret pattern not found"; fi

# Test 3: gitignore check
if grep 'gitignore' /Users/roberdan/.claude-convergio-orchestrator/hooks/env-vault-guard.sh; then echo "gitignore check found"; else fail "gitignore check not found"; fi

# Test 4: Line count
if [ $(wc -l < /Users/roberdan/.claude-convergio-orchestrator/hooks/env-vault-guard.sh) -lt 80 ]; then echo "Line count OK"; else fail "Line count not OK"; fi

echo "All GREEN tests passed."
