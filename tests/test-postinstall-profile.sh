#!/bin/bash
# Test: postinstall.js uses 'standard' as default profile
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

MYCONVERGIO="${MYCONVERGIO_HOME:-$HOME/GitHub/MyConvergio}"
TARGET="${MYCONVERGIO}/scripts/postinstall.js"

if [ ! -f "$TARGET" ]; then
	echo "SKIP: $TARGET not found (MyConvergio not cloned)"
	exit 0
fi

if grep -q 'MYCONVERGIO_PROFILE.*standard' "$TARGET"; then
	echo "PASS: default profile is 'standard'"
	exit 0
else
	echo "FAIL: default profile not set to 'standard'"
	exit 1
fi
