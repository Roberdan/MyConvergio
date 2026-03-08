#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TESTS_DIR="$SCRIPT_DIR"

python3 - "$TESTS_DIR" <<'PY'
import sys
from pathlib import Path

tests_dir = Path(sys.argv[1])
test_files = sorted(tests_dir.rglob("test-*.sh"))
scoped_targets = [
    "test-integration-chat-schema-migration.sh",
    "test-integration-github-schema-migration.sh",
    "test-integration-plan-db-update-commit-tracking.sh",
    "test-unit-T7-01-agent-lazy-load.sh",
    "test-unit-T7-02-doc-compaction.sh",
    "test-unit-T7-03-agent-trim.sh",
    "test-unit-T7-04-command-size.sh",
    "test-unit-T8-01-hook-dispatcher.sh",
    "test-unit-T8-02-post-dispatcher.sh",
    "test-unit-T8-03-settings-hook-dispatchers.sh",
    "test-integration-hook-perf.sh",
    "test-unit-T9-01-digest-dispatcher.sh",
    "test-unit-T9-02-plan-db-lazy-source.sh",
    "test-unit-T9-03-sql-utils-consolidation.sh",
    "test-unit-T9-04-validation-dedupe.sh",
    "test-unit-T10-01-rust-claude-core.sh",
    "test-unit-T11-02-build-claude-core.sh",
    "test-unit-T11-03-claude-core-wrapper.sh",
    "test-unit-T11-04-claude-core-dispatcher-hooks.sh",
    "test-integration-T12-01-axum-server-scaffold.sh",
    "test-e2e-T12-05-brain-canvas-websocket.sh",
    "test-unit-T13-02-makefile-install-tiers.sh",
    "test-integration-T13-03-migrate-python-tests.sh",
    "test-e2e-T13-03-claude-core-integration.sh",
    "test-unit-agent-tokens.sh",
    "test-unit-T14-01-agent-profiles.sh",
    "test-unit-T14-02-agent-context-loader.sh",
    "test-integration-T14-03-context-loader-wiring.sh",
]

failures = []
seen_basenames = {}
files_by_name = {path.name: path for path in test_files}

for expected in scoped_targets:
    if expected not in files_by_name:
        failures.append(f"Missing categorized test file: {expected}")

for path in test_files:
    basename = path.name
    if basename in seen_basenames:
        failures.append(
            f"Duplicate test basename found: {basename} in {seen_basenames[basename]} and {path}"
        )
    else:
        seen_basenames[basename] = path

    content = path.read_text()
    if basename in scoped_targets:
        if "test-helpers.sh" not in content:
            failures.append(f"Missing shared helper source in {path}")
        if "setup_test_env" not in content:
            failures.append(f"Missing setup_test_env call in {path}")
        if "SCRIPT_DIR=" in content or "REPO_ROOT=" in content or "WORKTREE_ROOT=" in content:
            failures.append(f"Found duplicated setup variable assignment in {path}")

if failures:
    print("FAIL: test file consolidation checks failed")
    for failure in failures:
        print(f"- {failure}")
    sys.exit(1)

print(f"PASS: checked {len(test_files)} test files, consolidation constraints satisfied")
PY
