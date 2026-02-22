#!/bin/bash
# GREEN test: quality_gates[] count >= 4
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
yq eval '.quality_gates | length' config/cross-repo-learnings.yaml | grep -E '[4-9]|[1-9][0-9]' && exit 0 || exit 1
