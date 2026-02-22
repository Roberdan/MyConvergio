#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TESTS_DIR="$SCRIPT_DIR"

python3 - "$TESTS_DIR" <<'PY'
import sys
from pathlib import Path

tests_dir = Path(sys.argv[1])
test_files = sorted(tests_dir.rglob("test-*.sh"))

failures = []
seen_basenames = {}

for path in test_files:
    basename = path.name
    if basename in seen_basenames:
        failures.append(
            f"Duplicate test basename found: {basename} in {seen_basenames[basename]} and {path}"
        )
    else:
        seen_basenames[basename] = path

    content = path.read_text()
    if "SCRIPT_DIR=" not in content:
        failures.append(f"Missing SCRIPT_DIR in {path}")

if failures:
    print("FAIL: test file consolidation checks failed")
    for failure in failures:
        print(f"- {failure}")
    sys.exit(1)

print(f"PASS: checked {len(test_files)} test files, no duplicates, all define SCRIPT_DIR")
PY
