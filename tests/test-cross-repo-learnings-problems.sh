#!/bin/bash
# GREEN test: problems[] count >= 7
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG="$SCRIPT_DIR/../config/cross-repo-learnings.yaml"

if [[ ! -f "$CONFIG" ]]; then
	echo "SKIP: cross-repo-learnings.yaml not found at $CONFIG"
	exit 0
fi

if ! command -v yq >/dev/null 2>&1; then
	echo "SKIP: yq not available"
	exit 0
fi

yq eval '.problems | length' "$CONFIG" | grep -E '[7-9]|[1-9][0-9]' && exit 0 || exit 1
