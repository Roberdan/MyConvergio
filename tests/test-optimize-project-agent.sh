#!/bin/bash
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

source "$(dirname "${BASH_SOURCE[0]}")/lib/test-helpers.sh"

REPO_ROOT="$(get_repo_root)"
AGENT_FILE="${REPO_ROOT}/copilot-agents/optimize-project.agent.md"

main() {
  echo "=== test-optimize-project-agent.sh ==="
  assert_file_exists "$AGENT_FILE" "optimize project agent definition is present"
  assert_grep 'project-audit.sh' "$AGENT_FILE" "agent references project-audit.sh"
  exit_with_summary "optimize-project-agent"
}

main "$@"
