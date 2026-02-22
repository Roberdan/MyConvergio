#!/bin/bash
# GREEN test: problems[] count >= 7
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
yq eval '.problems | length' config/cross-repo-learnings.yaml | grep -E '[7-9]|[1-9][0-9]' && exit 0 || exit 1
