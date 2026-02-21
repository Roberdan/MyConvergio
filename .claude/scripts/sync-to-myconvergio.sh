#!/usr/bin/env bash
# sync-to-myconvergio.sh — Sync ~/.claude → MyConvergio (public repo)
# Version: 1.0.0
# Usage: sync-to-myconvergio.sh [--dry-run] [--verbose] [--category <cat>]
set -euo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SOURCE_DIR="$HOME/.claude"
TARGET_REPO="$HOME/GitHub/MyConvergio"
TARGET_DIR="$TARGET_REPO/.claude"

DRY_RUN=false
VERBOSE=false
CATEGORY="all"

# Blocklist: NEVER synced to public repo (category/relative-path)
BLOCKLIST=(
	"agents:release_management/mirrorbuddy-hardening-checks.md"
	"agents:research_report/Reports"
	"agents:research_report/output"
	"agents:strategic-planner.md"
	"scripts:sync-claude-config.sh"
	"scripts:sync-dashboard-db.sh"
)

# Personal path patterns to detect (not actual secrets, but shouldn't be hardcoded)
PERSONAL_PATTERNS=(
	"$HOME"
	"/home/$USER"
	# Add your personal email or username patterns here
)

usage() {
	echo "Usage: $(basename "$0") [--dry-run] [--verbose] [--category agents|scripts|skills|rules|copilot|reference|all]"
	echo "Sync ~/.claude (source of truth) → MyConvergio (public repo, sanitized)"
}

while [[ $# -gt 0 ]]; do
	case $1 in
	--dry-run)
		DRY_RUN=true
		shift
		;;
	--verbose | -v)
		VERBOSE=true
		shift
		;;
	--category)
		CATEGORY="$2"
		shift 2
		;;
	--help | -h)
		usage
		exit 0
		;;
	*)
		echo -e "${RED}Unknown: $1${NC}"
		usage
		exit 1
		;;
	esac
done

# Counters
NEW=0
UPDATED=0
UNCHANGED=0
BLOCKED=0
SANITIZE_WARN=0

is_blocked() {
	local rel_path="$1" category="$2"
	local entry
	for entry in "${BLOCKLIST[@]}"; do
		local cat="${entry%%:*}"
		local pattern="${entry#*:}"
		if [[ "$category" == "$cat" ]] && [[ "$rel_path" == "$pattern"* ]]; then
			return 0
		fi
	done
	return 1
}

check_sanitization() {
	local file="$1"
	local warnings=0
	for pattern in "${PERSONAL_PATTERNS[@]}"; do
		if grep -q "$pattern" "$file" 2>/dev/null; then
			echo -e "    ${YELLOW}⚠ Contains: $pattern${NC}"
			warnings=$((warnings + 1))
		fi
	done
	return $warnings
}

sync_dir() {
	local src_base="$1"
	local tgt_base="$2"
	local label="$3"
	local cat_key="${4:-NONE}"

	if [ ! -d "$src_base" ]; then
		echo -e "${YELLOW}SKIP: $label (source not found: $src_base)${NC}"
		return
	fi

	echo -e "\n${CYAN}=== $label ===${NC}"
	echo -e "  Source: $src_base"
	echo -e "  Target: $tgt_base"

	while IFS= read -r src_file; do
		local rel_path="${src_file#$src_base/}"

		# Skip non-content files
		[[ "$rel_path" == .* ]] && continue
		[[ "$rel_path" == "logs/"* ]] && continue
		[[ "$(basename "$rel_path")" == ".DS_Store" ]] && continue

		# Check blocklist
		if is_blocked "$rel_path" "$cat_key"; then
			BLOCKED=$((BLOCKED + 1))
			if [ "$VERBOSE" = true ]; then
				echo -e "  ${RED}BLOCKED${NC}: $rel_path"
			fi
			continue
		fi

		local tgt_file="$tgt_base/$rel_path"

		# Sanitization check
		local san_ok=true
		if ! check_sanitization "$src_file" 2>/dev/null; then
			san_ok=false
			SANITIZE_WARN=$((SANITIZE_WARN + 1))
		fi

		if [ ! -f "$tgt_file" ]; then
			echo -e "  ${GREEN}NEW${NC}: $rel_path"
			NEW=$((NEW + 1))
			if [ "$DRY_RUN" = false ]; then
				mkdir -p "$(dirname "$tgt_file")"
				cp "$src_file" "$tgt_file"
			fi
		elif ! diff -q "$src_file" "$tgt_file" >/dev/null 2>&1; then
			echo -e "  ${YELLOW}UPDATED${NC}: $rel_path"
			UPDATED=$((UPDATED + 1))
			if [ "$DRY_RUN" = false ]; then
				cp "$src_file" "$tgt_file"
			fi
			if [ "$VERBOSE" = true ]; then
				diff --brief "$tgt_file" "$src_file" 2>/dev/null || true
			fi
		else
			UNCHANGED=$((UNCHANGED + 1))
			if [ "$VERBOSE" = true ]; then
				echo -e "  UNCHANGED: $rel_path"
			fi
		fi
	done < <(find "$src_base" -type f | sort)
}

sync_copilot() {
	local src_base="$SOURCE_DIR/copilot-agents"
	local tgt_base="$TARGET_REPO/copilot-agents"

	if [ ! -d "$src_base" ]; then
		echo -e "${YELLOW}SKIP: copilot-agents (source not found)${NC}"
		return
	fi

	echo -e "\n${CYAN}=== Copilot CLI Agents ===${NC}"
	echo -e "  Source: $src_base"
	echo -e "  Target: $tgt_base"

	for src_file in "$src_base"/*.agent.md; do
		[ -f "$src_file" ] || continue
		local filename
		filename=$(basename "$src_file")
		local tgt_file="$tgt_base/$filename"

		if [ ! -f "$tgt_file" ]; then
			echo -e "  ${GREEN}NEW${NC}: $filename"
			NEW=$((NEW + 1))
			if [ "$DRY_RUN" = false ]; then
				mkdir -p "$tgt_base"
				cp "$src_file" "$tgt_file"
			fi
		elif ! diff -q "$src_file" "$tgt_file" >/dev/null 2>&1; then
			echo -e "  ${YELLOW}UPDATED${NC}: $filename"
			UPDATED=$((UPDATED + 1))
			if [ "$DRY_RUN" = false ]; then
				cp "$src_file" "$tgt_file"
			fi
		else
			UNCHANGED=$((UNCHANGED + 1))
			if [ "$VERBOSE" = true ]; then
				echo -e "  UNCHANGED: $filename"
			fi
		fi
	done
}

# Header
echo -e "${BLUE}MyConvergio Sync v1.0.0${NC} | ${CYAN}$CATEGORY${NC}"
echo -e "Source: $SOURCE_DIR → Target: $TARGET_REPO"
[ "$DRY_RUN" = true ] && echo -e "${YELLOW}DRY RUN${NC}"

# Validate target repo exists
if [ ! -d "$TARGET_REPO/.git" ]; then
	echo -e "${RED}Error: $TARGET_REPO is not a git repository${NC}"
	exit 1
fi

# Execute sync per category
case "$CATEGORY" in
agents) sync_dir "$SOURCE_DIR/agents" "$TARGET_DIR/agents" "Agents" "agents" ;;
scripts) sync_dir "$SOURCE_DIR/scripts" "$TARGET_DIR/scripts" "Scripts" "scripts" ;;
skills) sync_dir "$SOURCE_DIR/skills" "$TARGET_DIR/skills" "Skills" "skills" ;;
rules) sync_dir "$SOURCE_DIR/rules" "$TARGET_DIR/rules" "Rules" "rules" ;;
copilot) sync_copilot ;;
reference) sync_dir "$SOURCE_DIR/reference" "$TARGET_DIR/reference" "Reference" "reference" ;;
all)
	sync_dir "$SOURCE_DIR/agents" "$TARGET_DIR/agents" "Agents" "agents"
	sync_dir "$SOURCE_DIR/scripts" "$TARGET_DIR/scripts" "Scripts" "scripts"
	sync_dir "$SOURCE_DIR/skills" "$TARGET_DIR/skills" "Skills" "skills"
	sync_dir "$SOURCE_DIR/rules" "$TARGET_DIR/rules" "Rules" "rules"
	sync_copilot
	sync_dir "$SOURCE_DIR/reference" "$TARGET_DIR/reference" "Reference" "reference"
	;;
*)
	echo -e "${RED}Unknown category: $CATEGORY${NC}"
	usage
	exit 1
	;;
esac

# Summary
echo ""
echo -e "${BLUE}═══ Summary ═══${NC}"
echo -e "  New:              ${GREEN}$NEW${NC}"
echo -e "  Updated:          ${YELLOW}$UPDATED${NC}"
echo -e "  Unchanged:        $UNCHANGED"
echo -e "  Blocked:          ${RED}$BLOCKED${NC}"
if [ "$SANITIZE_WARN" -gt 0 ]; then
	echo -e "  ${YELLOW}⚠ Sanitization warnings: $SANITIZE_WARN${NC}"
	echo -e "  ${YELLOW}  Review files above for personal paths before committing${NC}"
fi

if [ "$DRY_RUN" = true ]; then
	echo -e "\n${YELLOW}Run without --dry-run to apply${NC}"
elif [ $NEW -gt 0 ] || [ $UPDATED -gt 0 ]; then
	echo -e "\n${GREEN}✅ Sync complete${NC} — Review: cd $TARGET_REPO && git diff --stat"
else
	echo -e "\n${GREEN}✅ Already up to date${NC}"
fi
