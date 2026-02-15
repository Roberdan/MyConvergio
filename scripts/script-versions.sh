#!/usr/bin/env bash
# script-versions.sh — Auto-generated index of all scripts with versions
# Usage: script-versions.sh [--json|--stale|--category <name>]
# Resolves scripts dir: ~/.claude/scripts → npm global → script's own dir
# Version: 1.1.0
set -euo pipefail

# Resolve scripts directory (supports ~/.claude, npm global install, local clone)
if [[ -d "${HOME}/.claude/scripts" ]]; then
	SCRIPTS_DIR="${HOME}/.claude/scripts"
elif [[ -d "$(npm root -g 2>/dev/null)/myconvergio/scripts" ]]; then
	SCRIPTS_DIR="$(npm root -g)/myconvergio/scripts"
else
	SCRIPTS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
fi
MODE="${1:-table}"
CAT_FILTER="${2:-}"

# Category detection from filename
categorize() {
	local name="$1"
	case "$name" in
	*-digest.sh | service-digest.sh) echo "digest" ;;
	plan-db*.sh | planner-*.sh | generate-task-md.sh) echo "plan-db" ;;
	worktree-*.sh) echo "worktree" ;;
	collect-*.sh | dashboard-*.sh | init-dashboard-db.sh | sync-dashboard-db.sh) echo "dashboard" ;;
	migrate-*.sh | migrate-v*.sh) echo "migration" ;;
	ci-*.sh) echo "ci" ;;
	pr-*.sh) echo "pr" ;;
	claude-*.sh | tmux-*.sh | kitty-*.sh | orchestrate.sh | worker-launch.sh | detect-terminal.sh) echo "orchestration" ;;
	session-*.sh | memory-save.sh) echo "session" ;;
	agent-*.sh) echo "agent-tools" ;;
	*-helper.sh) echo "helpers" ;;
	copilot-*.sh | sync-*.sh) echo "sync" ;;
	context-*.sh | repo-index.sh | stale-check.sh) echo "context" ;;
	thor-*.sh | verify-*.sh | wave-overlap.sh) echo "validation" ;;
	*) echo "misc" ;;
	esac
}

extract_version() {
	local file="$1"
	grep -m1 "^# Version:" "$file" 2>/dev/null | sed 's/^# Version:[[:space:]]*//' || echo ""
}

extract_purpose() {
	local file="$1"
	# Take first comment line after shebang that looks like a description
	sed -n '2,5p' "$file" | grep -m1 "^#" | sed 's/^#[[:space:]]*//' | cut -c1-60 || echo ""
}

# Collect data
declare -a NAMES=() VERSIONS=() CATEGORIES=() PURPOSES=()
for script in "$SCRIPTS_DIR"/*.sh; do
	[[ ! -f "$script" ]] && continue
	name=$(basename "$script")
	[[ "$name" == "script-versions.sh" ]] && continue # skip self
	ver=$(extract_version "$script")
	cat=$(categorize "$name")
	purpose=$(extract_purpose "$script")
	NAMES+=("$name")
	VERSIONS+=("${ver:-none}")
	CATEGORIES+=("$cat")
	PURPOSES+=("$purpose")
done

# --- Output modes ---
if [[ "$MODE" == "--json" ]]; then
	echo "["
	for i in "${!NAMES[@]}"; do
		comma=","
		[[ $i -eq $((${#NAMES[@]} - 1)) ]] && comma=""
		printf '  {"name":"%s","version":"%s","category":"%s"}%s\n' \
			"${NAMES[$i]}" "${VERSIONS[$i]}" "${CATEGORIES[$i]}" "$comma"
	done
	echo "]"
	exit 0
fi

if [[ "$MODE" == "--stale" ]]; then
	echo "=== Scripts without version ==="
	found=0
	for i in "${!NAMES[@]}"; do
		if [[ "${VERSIONS[$i]}" == "none" ]]; then
			echo "  ${NAMES[$i]}"
			found=$((found + 1))
		fi
	done
	[[ "$found" -eq 0 ]] && echo "  (none — all scripts have versions)"
	echo "Total: ${#NAMES[@]} scripts, $found without version"
	exit 0
fi

if [[ "$MODE" == "--category" && -n "$CAT_FILTER" ]]; then
	printf "%-40s %s\n" "SCRIPT" "VERSION"
	printf "%-40s %s\n" "------" "-------"
	for i in "${!NAMES[@]}"; do
		[[ "${CATEGORIES[$i]}" == "$CAT_FILTER" ]] &&
			printf "%-40s %s\n" "${NAMES[$i]}" "${VERSIONS[$i]}"
	done
	exit 0
fi

# Default: grouped table
SEEN_CATS=()
for cat in "${CATEGORIES[@]}"; do
	skip=false
	for seen in "${SEEN_CATS[@]+"${SEEN_CATS[@]}"}"; do
		[[ "$seen" == "$cat" ]] && {
			skip=true
			break
		}
	done
	$skip && continue
	SEEN_CATS+=("$cat")
done

# Sort categories alphabetically
IFS=$'\n' SORTED_CATS=($(printf '%s\n' "${SEEN_CATS[@]}" | sort))
unset IFS

echo "=== Script Index (${#NAMES[@]} scripts) ==="
echo ""
for cat in "${SORTED_CATS[@]}"; do
	# Count scripts in category
	count=0
	for i in "${!NAMES[@]}"; do
		[[ "${CATEGORIES[$i]}" == "$cat" ]] && count=$((count + 1))
	done
	echo "[$cat] ($count)"
	for i in "${!NAMES[@]}"; do
		[[ "${CATEGORIES[$i]}" != "$cat" ]] && continue
		printf "  %-38s %-8s %s\n" "${NAMES[$i]}" "${VERSIONS[$i]}" "${PURPOSES[$i]}"
	done
	echo ""
done

# Summary
total=${#NAMES[@]}
stale=0
for v in "${VERSIONS[@]}"; do [[ "$v" == "none" ]] && stale=$((stale + 1)); done
echo "Total: $total | Versioned: $((total - stale)) | Missing: $stale"
