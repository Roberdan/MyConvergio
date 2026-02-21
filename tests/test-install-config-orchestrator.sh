#!/bin/bash
# Test: install-config.json references orchestrator scripts
set -euo pipefail

MYCONVERGIO="${MYCONVERGIO_HOME:-$HOME/GitHub/MyConvergio}"
TARGET="${MYCONVERGIO}/scripts/install-config.json"

if [ ! -f "$TARGET" ]; then
	echo "SKIP: $TARGET not found (MyConvergio not cloned)"
	exit 0
fi

if grep -qE 'delegate.sh|env-vault.sh|model-registry.sh|worktree-safety.sh' "$TARGET"; then
	echo "PASS: orchestrator scripts present in install-config.json"
	exit 0
else
	echo "FAIL: orchestrator scripts missing in install-config.json"
	exit 1
fi
