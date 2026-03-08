#!/usr/bin/env bash
set -euo pipefail

source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/lib/test-helpers.sh"
setup_test_env

CLAUDE_FILE="${REPO_ROOT}/CLAUDE.md"
CHANGELOG_FILE="${REPO_ROOT}/CHANGELOG.md"
ARCHIVE_FILE="${REPO_ROOT}/CHANGELOG-archive.md"

fail() {
  echo "[FAIL] $1" >&2
  exit 1
}

pass() {
  echo "[PASS] $1"
}

[[ -f "$CLAUDE_FILE" ]] || fail "CLAUDE.md must exist"
[[ -f "$CHANGELOG_FILE" ]] || fail "CHANGELOG.md must exist"

claude_size=$(wc -c < "$CLAUDE_FILE" | tr -d ' ')
[[ "$claude_size" -lt 16000 ]] || fail "CLAUDE.md must be <16000 bytes (got ${claude_size})"
pass "CLAUDE.md size is compact (${claude_size} bytes)"

[[ -f "$ARCHIVE_FILE" ]] || fail "CHANGELOG-archive.md must exist"
pass "CHANGELOG archive file exists"

python3 - "$CHANGELOG_FILE" <<'PY'
import re
import sys
from datetime import datetime, timedelta, timezone

path = sys.argv[1]
text = open(path, "r", encoding="utf-8").read()
cutoff = datetime.now(timezone.utc).replace(tzinfo=None) - timedelta(days=30)
pattern = re.compile(r"^## \[[^\]]+\] - (\d{2} [A-Za-z]{3} \d{4})$", re.MULTILINE)

old = []
for match in pattern.finditer(text):
    dt = datetime.strptime(match.group(1), "%d %b %Y")
    if dt < cutoff:
        old.append(match.group(1))

if old:
    print(f"[FAIL] CHANGELOG.md contains entries older than 30 days: {', '.join(old)}", file=sys.stderr)
    raise SystemExit(1)

print("[PASS] CHANGELOG.md keeps only the last 30 days of dated releases")
PY

echo "[OK] T7-02 criteria satisfied"
