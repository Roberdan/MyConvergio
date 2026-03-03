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
	for file in "$ROOT_DIR/README.md" "$ROOT_DIR/AGENTS.md"; do
		if [[ ! -f "$file" ]]; then
			continue
		fi
		if grep -q '^<!-- AGENT_COUNTS: ' "$file"; then
			sed -i '' "s|^<!-- AGENT_COUNTS: .* -->$|${TEMPLATE_LINE}|g" "$file"
		else
			echo "ERROR: Missing AGENT_COUNTS template in $file" >&2
			exit 1
		fi
	done
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
