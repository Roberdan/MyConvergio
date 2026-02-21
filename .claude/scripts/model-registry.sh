#!/bin/bash
# model-registry.sh: Manage model registry (refresh/list/diff/check)
set -euo pipefail

# Helper: get CLI versions
get_cli_versions() {
	local versions
	versions="{}"
	for provider in claude copilot opencode gemini; do
		case "$provider" in
		claude)
			v=$(claude --version 2>/dev/null | head -1 || echo "unknown")
			;;
		copilot)
			v=$(gh --version 2>/dev/null | head -1 || echo "unknown")
			;;
		opencode)
			v=$(opencode --version 2>/dev/null | head -1 || echo "unknown")
			;;
		gemini)
			v=$(gemini --version 2>/dev/null | head -1 || echo "unknown")
			;;
		esac
		versions=$(jq --arg p "$provider" --arg v "$v" '. + {($p): $v}' <<<"$versions")
	done
	echo "$versions"
}

# Helper: parse orchestrator.yaml for model multipliers
parse_yaml_models() {
	local config="${CLAUDE_HOME:-$HOME/.claude}/config/orchestrator.yaml"
	yq eval '.providers' "$config" | jq '.'
}

# Helper: parse Copilot model multipliers from model-strategy.md
parse_copilot_multipliers() {
	awk '/\| Model/{flag=1;next} /All Copilot models available/{flag=0} flag' commands/planner-modules/model-strategy.md |
		awk -F'|' '{if(NF>2){gsub(/`/,"",$2); print $2,$3}}' |
		awk '{print $1,$2}'
}

# Subcommand: refresh
if [[ "$1" == "refresh" ]]; then
	mkdir -p data
	cli_versions=$(get_cli_versions)
	providers=$(parse_yaml_models)
	last_updated=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
	jq -n --argjson cli_versions "$cli_versions" --argjson providers "$providers" --arg last_updated "$last_updated" '{last_updated: $last_updated, cli_versions: $cli_versions, providers: $providers}' >data/models-registry.json
	echo "Refreshed model registry."
	exit 0
fi

# Subcommand: list
if [[ "$1" == "list" ]]; then
	jq '.providers' data/models-registry.json
	exit 0
fi

# Subcommand: diff
if [[ "$1" == "diff" ]]; then
	diff data/models-registry.json data/models-registry.json.bak || echo "No diff"
	exit 0
fi

# Subcommand: check
if [[ "$1" == "check" ]]; then
	jq '.providers[].models[].multiplier' data/models-registry.json | head -5
	exit 0
fi
