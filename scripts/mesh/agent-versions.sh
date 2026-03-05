#!/usr/bin/env bash
set -euo pipefail

# agent-versions.sh — Scan all ecosystem components and report versions
# Usage: agent-versions.sh [--json|--check]

CLAUDE_DIR="${HOME}/.claude"
MODE="${1:-table}"

# Framework docs to skip (not agents)
SKIP_FILES="CONSTITUTION.md|CommonValuesAndPrinciples.md|MICROSOFT_VALUES.md|EXECUTION_DISCIPLINE.md|SECURITY_FRAMEWORK_TEMPLATE.md"

extract_version() {
	local file="$1"
	local version=""
	local in_frontmatter=false
	while IFS= read -r line; do
		if [[ "$line" == "---" ]]; then
			if $in_frontmatter; then
				break
			fi
			in_frontmatter=true
			continue
		fi
		if $in_frontmatter && [[ "$line" =~ ^version:[[:space:]]*\"?([0-9]+\.[0-9]+\.[0-9]+)\"? ]]; then
			version="${BASH_REMATCH[1]}"
			break
		fi
	done <"$file"
	echo "$version"
}

extract_name() {
	local file="$1"
	local name=""
	local in_frontmatter=false
	while IFS= read -r line; do
		if [[ "$line" == "---" ]]; then
			if $in_frontmatter; then
				break
			fi
			in_frontmatter=true
			continue
		fi
		if $in_frontmatter && [[ "$line" =~ ^name:[[:space:]]*(.+) ]]; then
			name="${BASH_REMATCH[1]}"
			break
		fi
	done <"$file"
	# Fallback: filename without extension
	if [[ -z "$name" ]]; then
		name=$(basename "$file" .md)
		name=${name%.agent}
	fi
	echo "$name"
}

classify_type() {
	local file="$1"
	case "$file" in
	*/copilot-agents/*) echo "copilot-agent" ;;
	*/skills/*) echo "skill" ;;
	*/commands/*) echo "command" ;;
	*/agents/*) echo "agent" ;;
	*) echo "unknown" ;;
	esac
}

relative_path() {
	local file="$1"
	echo "${file#"${CLAUDE_DIR}"/}"
}

# Collect all component files
declare -a FILES=()

# Agents
while IFS= read -r f; do
	local_name=$(basename "$f")
	if [[ ! "$local_name" =~ ^($SKIP_FILES)$ ]]; then
		FILES+=("$f")
	fi
done < <(find "${CLAUDE_DIR}/agents" -name "*.md" -type f 2>/dev/null | sort)

# Copilot agents
while IFS= read -r f; do
	FILES+=("$f")
done < <(find "${CLAUDE_DIR}/copilot-agents" -name "*.agent.md" -type f 2>/dev/null | sort)

# Skills
while IFS= read -r f; do
	FILES+=("$f")
done < <(find "${CLAUDE_DIR}/skills" -name "SKILL.md" -type f 2>/dev/null | sort)

# Commands
while IFS= read -r f; do
	FILES+=("$f")
done < <(find "${CLAUDE_DIR}/commands" -name "*.md" -type f 2>/dev/null | sort)

# Process
missing=0
entries=()

for file in "${FILES[@]}"; do
	name=$(extract_name "$file")
	version=$(extract_version "$file")
	type=$(classify_type "$file")
	rel=$(relative_path "$file")

	if [[ -z "$version" ]]; then
		version="MISSING"
		((missing++)) || true
	fi

	entries+=("${name}|${type}|${version}|${rel}")
done

# Output
case "$MODE" in
--json)
	echo "["
	for i in "${!entries[@]}"; do
		IFS='|' read -r name type version rel <<<"${entries[$i]}"
		comma=","
		if [[ $i -eq $((${#entries[@]} - 1)) ]]; then
			comma=""
		fi
		echo "  {\"name\":\"${name}\",\"type\":\"${type}\",\"version\":\"${version}\",\"path\":\"${rel}\"}${comma}"
	done
	echo "]"
	;;
--check)
	if [[ $missing -gt 0 ]]; then
		echo "ERROR: ${missing} component(s) missing version field:"
		for entry in "${entries[@]}"; do
			IFS='|' read -r name type version rel <<<"$entry"
			if [[ "$version" == "MISSING" ]]; then
				echo "  - ${rel}"
			fi
		done
		exit 1
	else
		echo "OK: All ${#entries[@]} components have version fields."
	fi
	;;
*)
	# Table output
	printf "%-40s %-15s %-10s %s\n" "NAME" "TYPE" "VERSION" "PATH"
	printf "%-40s %-15s %-10s %s\n" "----" "----" "-------" "----"
	for entry in "${entries[@]}"; do
		IFS='|' read -r name type version rel <<<"$entry"
		printf "%-40s %-15s %-10s %s\n" "$name" "$type" "$version" "$rel"
	done
	echo ""
	echo "Total: ${#entries[@]} components (${missing} missing version)"
	;;
esac
