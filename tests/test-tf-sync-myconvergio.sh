#!/usr/bin/env bash
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

source "${SCRIPT_DIR}/lib/test-helpers.sh"

TARGET_ROOT="$HOME/GitHub/MyConvergio"

main() {
	echo "=== test-tf-sync-myconvergio.sh ==="

	if [[ ! -d "$TARGET_ROOT" ]]; then
		echo "SKIP: MyConvergio repo not found at $TARGET_ROOT"
		exit 0
	fi

	assert_file_exists "${TARGET_ROOT}/scripts/project-audit.sh" "project-audit.sh is synced"
	assert_file_exists "${TARGET_ROOT}/scripts/lib/project-audit-checks.sh" "project-audit-checks.sh is synced"
	assert_file_exists "${TARGET_ROOT}/skills/optimize-project/SKILL.md" "optimize-project skill is synced"
	assert_file_exists "${TARGET_ROOT}/copilot-agents/optimize-project.agent.md" "optimize-project agent is synced"

	exit_with_summary "tf-sync-myconvergio"
}

main "$@"
