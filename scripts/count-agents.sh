#!/usr/bin/env bash
# count-agents.sh — Count unique and per-platform agent files.
# v2.0.0
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(dirname "$SCRIPT_DIR")"

# Non-agent .md files in .claude/agents/ (docs, not agents)
EXCLUDE_NAMES="CONSTITUTION.md|CommonValuesAndPrinciples.md|MICROSOFT_VALUES.md|SECURITY_FRAMEWORK_TEMPLATE.md|EXECUTION_DISCIPLINE.md"

# Per-platform counts
CLAUDE_COUNT=$(
	find "$ROOT_DIR/.claude/agents" -name '*.md' | grep -Ev "$EXCLUDE_NAMES" | wc -l | tr -d ' '
)
COPILOT_COUNT=$(find "$ROOT_DIR/copilot-agents" -name '*.agent.md' | wc -l | tr -d ' ')

# Unique agent count (deduplicated across platforms)
CLAUDE_NAMES=$(find "$ROOT_DIR/.claude/agents" -name '*.md' | grep -Ev "$EXCLUDE_NAMES" | xargs -I{} basename {} .md | sort)
COPILOT_NAMES=$(find "$ROOT_DIR/copilot-agents" -name '*.agent.md' | xargs -I{} basename {} .agent.md | sort)
UNIQUE_COUNT=$(printf '%s\n%s\n' "$CLAUDE_NAMES" "$COPILOT_NAMES" | sort -u | wc -l | tr -d ' ')

COUNTS_LINE="unique:${UNIQUE_COUNT} claude:${CLAUDE_COUNT} copilot:${COPILOT_COUNT}"
TEMPLATE_LINE="<!-- AGENT_COUNTS: ${COUNTS_LINE} -->"

sync_docs() {
	python3 - "$ROOT_DIR" "$TEMPLATE_LINE" "$UNIQUE_COUNT" "$CLAUDE_COUNT" "$COPILOT_COUNT" <<'PY'
import re
import sys
from pathlib import Path

root = Path(sys.argv[1])
template_line = sys.argv[2]
unique_count = sys.argv[3]
claude_count = sys.argv[4]
copilot_count = sys.argv[5]

for rel in ("README.md", "AGENTS.md"):
    path = root / rel
    if not path.exists():
        continue
    content = path.read_text(encoding="utf-8")
    if "<!-- AGENT_COUNTS: " not in content:
        raise SystemExit(f"ERROR: Missing AGENT_COUNTS template in {path}")
    content = re.sub(r"^<!-- AGENT_COUNTS: .* -->$", template_line, content, flags=re.M)
    if rel == "README.md":
        content = re.sub(r"badge/agents-\d+-", f"badge/agents-{unique_count}-", content)
    if rel == "AGENTS.md":
        content = re.sub(r"\*\*v[0-9.]+\*\* \| \d+ Unique Agents \| Multi-Provider Orchestrator",
                         f"**v10.15.0** | {unique_count} Unique Agents | Multi-Provider Orchestrator",
                         content)
        content = re.sub(r"supports both \*\*Claude Code\*\* \(\d+ agent files\) and \*\*GitHub Copilot CLI\*\* \(\d+ agent files\)",
                         f"supports both **Claude Code** ({claude_count} agent files) and **GitHub Copilot CLI** ({copilot_count} agent files)",
                         content)
        content = re.sub(r"- \d+ Claude agent files across 8 categories",
                         f"- {claude_count} Claude agent files across 8 categories",
                         content)
        content = re.sub(r"- \d+ Copilot agent files for GitHub Copilot users",
                         f"- {copilot_count} Copilot agent files for GitHub Copilot users",
                         content)
        content = re.sub(r"\*\*Total\*\*: \d+ agent files \(\d+ Claude \+ \d+ Copilot\)",
                         f"**Total**: {int(claude_count) + int(copilot_count)} agent files ({claude_count} Claude + {copilot_count} Copilot)",
                         content)
    path.write_text(content, encoding="utf-8")
PY
}

check_docs() {
	local failed=0
	for file in "$ROOT_DIR/README.md" "$ROOT_DIR/AGENTS.md"; do
		if [[ ! -f "$file" ]]; then
			continue
		fi
		if ! grep -Fqx "$TEMPLATE_LINE" "$file"; then
			echo "ERROR: Agent counts out of sync in $file. Run: bash scripts/count-agents.sh --sync-docs" >&2
			failed=1
		fi
	done
	return "$failed"
}

case "${1:-}" in
--sync-docs)
	sync_docs
	echo "$COUNTS_LINE"
	;;
--check-docs)
	echo "$COUNTS_LINE"
	check_docs
	;;
"")
	echo "$COUNTS_LINE"
	;;
*)
	echo "Usage: $0 [--sync-docs|--check-docs]" >&2
	exit 1
	;;
esac
