#!/usr/bin/env bash
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

source "${SCRIPT_DIR}/lib/test-helpers.sh"

TARGET_ROOT="$HOME/GitHub/MyConvergio"
VERSION_FILE="${TARGET_ROOT}/VERSION"
PACKAGE_JSON="${TARGET_ROOT}/package.json"

main() {
  echo "=== test-tf-sync-myconvergio.sh ==="

  assert_file_exists "${TARGET_ROOT}/scripts/project-audit.sh" "project-audit.sh is synced"
  assert_file_exists "${TARGET_ROOT}/scripts/lib/project-audit-checks.sh" "project-audit-checks.sh is synced"
  assert_file_exists "${TARGET_ROOT}/skills/optimize-project/SKILL.md" "optimize-project skill is synced"
  assert_file_exists "${TARGET_ROOT}/copilot-agents/optimize-project.agent.md" "optimize-project agent is synced"

  local system_version package_version
  system_version="$(awk -F= '/^SYSTEM_VERSION=/{print $2; exit}' "${VERSION_FILE}")"
  package_version="$(jq -r '.version' "${PACKAGE_JSON}")"

  if [ "${system_version}" = "7.1.1" ]; then
    pass "VERSION SYSTEM_VERSION bumped to 7.1.1"
  else
    fail "VERSION SYSTEM_VERSION bumped to 7.1.1" "7.1.1" "${system_version}"
  fi

  if [ "${package_version}" = "6.3.1" ]; then
    pass "package.json version bumped to 6.3.1"
  else
    fail "package.json version bumped to 6.3.1" "6.3.1" "${package_version}"
  fi

  exit_with_summary "tf-sync-myconvergio"
}

main "$@"
