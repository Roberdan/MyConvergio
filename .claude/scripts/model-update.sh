#!/usr/bin/env bash
# model-update.sh v1.0.0
# Update all Copilot agent model IDs from config/models.yaml.
# Usage: model-update.sh [--dry-run]
set -euo pipefail

CLAUDE_HOME="${CLAUDE_HOME:-$HOME/.claude}"
CONFIG="$CLAUDE_HOME/config/models.yaml"
AGENTS_DIR="$CLAUDE_HOME/copilot-agents"
DRY_RUN=false

[[ "${1:-}" == "--dry-run" ]] && DRY_RUN=true

if [[ ! -f "$CONFIG" ]]; then
	echo "ERROR: $CONFIG not found" >&2
	exit 1
fi

# Parse models.yaml — extract copilot model IDs and agent mappings
# Uses python3 for reliable YAML parsing
UPDATES=$(/usr/bin/python3 -c "
import yaml, sys, os

config = yaml.safe_load(open('$CONFIG'))
copilot = config.get('copilot', {})
agents = config.get('copilot_agents', {})

for agent_name, model_key in agents.items():
    model_id = copilot.get(model_key)
    if not model_id:
        print(f'WARN: {agent_name} references unknown key {model_key}', file=sys.stderr)
        continue
    agent_file = os.path.join('$AGENTS_DIR', f'{agent_name}.agent.md')
    if not os.path.exists(agent_file):
        print(f'SKIP: {agent_file} not found', file=sys.stderr)
        continue
    print(f'{agent_file}|{model_id}')
")

CHANGED=0
SKIPPED=0

while IFS='|' read -r file model_id; do
	[[ -z "$file" ]] && continue

	current=$(grep -m1 '^model:' "$file" 2>/dev/null | sed 's/^model: *//')
	if [[ "$current" == "$model_id" ]]; then
		((SKIPPED++))
		continue
	fi

	if $DRY_RUN; then
		echo "WOULD: $file: $current → $model_id"
	else
		sed -i '' "s/^model: .*/model: $model_id/" "$file"
		echo "UPDATED: $file: $current → $model_id"
	fi
	((CHANGED++))
done <<<"$UPDATES"

echo ""
echo "Summary: $CHANGED updated, $SKIPPED unchanged"
$DRY_RUN && echo "(dry-run — no files modified)"
