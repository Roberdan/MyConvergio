#!/bin/bash
# RED test: CHANGELOG.md must mention Convergio Orchestrator and ADR-0010
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if ! grep -q 'Convergio Orchestrator' CHANGELOG.md; then
  echo 'Missing Convergio Orchestrator in CHANGELOG.md'
  exit 1
fi
if ! grep -q 'ADR-0010' CHANGELOG.md; then
  echo 'Missing ADR-0010 in CHANGELOG.md'
  exit 1
fi
echo 'PASS'
exit 0
