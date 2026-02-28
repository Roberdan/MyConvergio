#!/usr/bin/env bash
# count-agents.sh — Count Claude and Copilot agent files.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(dirname "$SCRIPT_DIR")"

CLAUDE_COUNT=$(
	find "$ROOT_DIR/.claude/agents" -name '*.md' \
		! -name 'CONSTITUTION.md' \
		! -name 'CommonValuesAndPrinciples.md' \
		! -name 'MICROSOFT_VALUES.md' \
		! -name 'SECURITY_FRAMEWORK_TEMPLATE.md' \
		! -name 'EXECUTION_DISCIPLINE.md' | wc -l | tr -d ' '
)
COPILOT_COUNT=$(find "$ROOT_DIR/copilot-agents" -name '*.agent.md' | wc -l | tr -d ' ')
TOTAL_COUNT=$((CLAUDE_COUNT + COPILOT_COUNT))
COUNTS_LINE="claude:${CLAUDE_COUNT} copilot:${COPILOT_COUNT} total:${TOTAL_COUNT}"
TEMPLATE_LINE="<!-- AGENT_COUNTS: ${COUNTS_LINE} -->"

sync_docs() {
	for file in "$ROOT_DIR/README.md" "$ROOT_DIR/AGENTS.md"; do
		if [[ ! -f "$file" ]]; then
			continue
		fi
		if grep -q '^<!-- AGENT_COUNTS: ' "$file"; then
			sed -i "s|^<!-- AGENT_COUNTS: .* -->$|${TEMPLATE_LINE}|g" "$file"
		else
			echo "ERROR: Missing AGENT_COUNTS template in $file" >&2
			exit 1
		fi
	done
}

check_docs() {
	local failed=0
	for file in "$ROOT_DIR/README.md" "$ROOT_DIR/AGENTS.md"; do
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
