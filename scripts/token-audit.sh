#!/bin/bash
set -euo pipefail
# token-audit.sh: Check instruction file sizes against token budget
# See rules/token-budget.md for limits

CLAUDE_DIR="${HOME}/.claude"
WARN_ONLY="${WARN_ONLY:-true}"
EXIT_CODE=0

check_size() {
  local file="$1"
  local max_bytes="$2"
  local label="$3"
  if [[ ! -f "$file" ]]; then return; fi
  local size
  size=$(wc -c < "$file")
  if [[ $size -gt $max_bytes ]]; then
    echo "[WARN] ${label}: ${size} bytes (max: ${max_bytes})"
    [[ "$WARN_ONLY" != "true" ]] && EXIT_CODE=1
  fi
}

echo "=== Token Audit ==="

check_size "${CLAUDE_DIR}/CLAUDE.md" 16384 "CLAUDE.md"
check_size "${CLAUDE_DIR}/AGENTS.md" 16384 "AGENTS.md"

for f in "${CLAUDE_DIR}"/rules/*.md; do
  check_size "$f" 8192 "rules/$(basename "$f")"
done

for f in "${CLAUDE_DIR}"/skills/*/SKILL.md; do
  [[ -f "$f" ]] || continue
  check_size "$f" 6144 "skills/$(basename "$(dirname "$f")")/SKILL.md"
done

for f in "${CLAUDE_DIR}"/agents/*/*.md; do
  [[ -f "$f" ]] || continue
  check_size "$f" 6144 "agents/$(basename "$(dirname "$f")")/$(basename "$f")"
done

if [[ $EXIT_CODE -eq 0 ]]; then
  echo "All files within budget"
fi
exit $EXIT_CODE
