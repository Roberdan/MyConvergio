#!/usr/bin/env bash
# sync-to-myconvergio.sh — Sync ~/.claude → MyConvergio (public repo)
# Version: 2.0.0 - Modularized
# Usage: sync-to-myconvergio.sh [--dry-run] [--verbose] [--category <cat>]
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Source shared libraries
source "${SCRIPT_DIR}/lib/common.sh"
source "${SCRIPT_DIR}/lib/sync-to-myconvergio-ops.sh"

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
	"scripts:migrate-plan-to-linux.sh"
	"scripts:remote-repo-sync.sh"
)

# Personal path patterns to detect (not actual secrets, but shouldn't be hardcoded)
PERSONAL_PATTERNS=(
	"$HOME"
	"/home/roberdan"
	"danieleroberti"
)

# Counters
NEW=0
UPDATED=0
UNCHANGED=0
BLOCKED=0
SANITIZE_WARN=0

# Export for use in sourced module
export NEW UPDATED UNCHANGED BLOCKED SANITIZE_WARN DRY_RUN VERBOSE SOURCE_DIR TARGET_REPO TARGET_DIR
export BLOCKLIST PERSONAL_PATTERNS

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

# Header
echo -e "${BLUE}MyConvergio Sync v2.0.0${NC} | ${CYAN}$CATEGORY${NC}"
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
