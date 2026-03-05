#!/usr/bin/env bash
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# test-agent-validation.sh
# Validates ALL agent .md files have valid YAML frontmatter, version header, and are ≤250 lines

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
AGENTS_DIR="${REPO_ROOT}/agents"
COPILOT_AGENTS_DIR="${REPO_ROOT}/copilot-agents"

TOTAL_FILES=0
FAILED_FILES=0
PASSED_FILES=0
TEMP_FILE_LIST=$(mktemp)

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Cleanup on exit
trap 'rm -f "$TEMP_FILE_LIST"' EXIT

echo "================================"
echo "Agent Validation Test"
echo "================================"
echo ""

validate_agent_file() {
	local file="$1"
	local filename=$(basename "$file")
	local errors=()

	# Check if file exists and is readable
	if [[ ! -r "$file" ]]; then
		errors+=("File not readable")
		return 1
	fi

	# Check line count (≤250 lines)
	local line_count=$(wc -l <"$file" | tr -d ' ')
	if [[ $line_count -gt 250 ]]; then
		errors+=("File has ${line_count} lines (max 250 allowed)")
	fi

	# Check for YAML frontmatter (starts with ---)
	local first_line=$(head -n 1 "$file")
	if [[ "$first_line" != "---" ]]; then
		errors+=("Missing YAML frontmatter (file must start with '---')")
	fi

	# Extract frontmatter (between first two --- markers)
	local frontmatter_end=$(awk '/^---$/{n++; if(n==2){print NR; exit}}' "$file")

	if [[ -z "$frontmatter_end" ]]; then
		errors+=("YAML frontmatter not properly closed (missing second '---')")
	else
		# Extract frontmatter content
		local frontmatter=$(sed -n "1,${frontmatter_end}p" "$file")

		# Check for required 'name' field
		if ! echo "$frontmatter" | grep -q "^name:"; then
			errors+=("Missing required 'name' field in frontmatter")
		fi

		# Check for 'description' field (mentioned in task)
		if ! echo "$frontmatter" | grep -q "^description:"; then
			errors+=("Missing 'description' field in frontmatter")
		fi

		# Check for 'tools' field (mentioned in task)
		if ! echo "$frontmatter" | grep -q "^tools:"; then
			errors+=("Missing 'tools' field in frontmatter")
		fi

		# Check for 'model' field (mentioned in task)
		if ! echo "$frontmatter" | grep -q "^model:"; then
			errors+=("Missing 'model' field in frontmatter")
		fi
	fi

	# Check for version header (looking for version: field in frontmatter)
	if [[ -n "$frontmatter_end" ]]; then
		local frontmatter=$(sed -n "1,${frontmatter_end}p" "$file")
		if ! echo "$frontmatter" | grep -q "^version:"; then
			errors+=("Missing 'version' field in frontmatter")
		fi
	fi

	# Report results
	if [[ ${#errors[@]} -eq 0 ]]; then
		echo -e "${GREEN}✓ PASS${NC}: $filename"
		return 0
	else
		echo -e "${RED}✗ FAIL${NC}: $filename"
		for error in "${errors[@]}"; do
			echo -e "  ${YELLOW}→${NC} $error"
		done
		return 1
	fi
}

# Reference docs in agents/ that are NOT agent definitions (no frontmatter needed)
EXCLUDE_PATTERN="CONSTITUTION.md|SECURITY_FRAMEWORK_TEMPLATE.md|MICROSOFT_VALUES.md|CommonValuesAndPrinciples.md|EXECUTION_DISCIPLINE.md"

# Find and validate all .md files in agents/ directory
if [[ -d "$AGENTS_DIR" ]]; then
	echo "Scanning: $AGENTS_DIR"
	echo "---"
	find "$AGENTS_DIR" -type f -name "*.md" >"$TEMP_FILE_LIST"
	while IFS= read -r file; do
		[[ -z "$file" ]] && continue
		# Skip reference docs that aren't agent definitions
		if echo "$(basename "$file")" | grep -qE "^($EXCLUDE_PATTERN)$"; then
			echo -e "${YELLOW}⊘ SKIP${NC}: $(basename "$file") (reference doc, not agent)"
			continue
		fi
		TOTAL_FILES=$((TOTAL_FILES + 1))
		if validate_agent_file "$file"; then
			PASSED_FILES=$((PASSED_FILES + 1))
		else
			FAILED_FILES=$((FAILED_FILES + 1))
		fi
	done <"$TEMP_FILE_LIST"
	echo ""
fi

# Find and validate all .md files in copilot-agents/ directory
if [[ -d "$COPILOT_AGENTS_DIR" ]]; then
	echo "Scanning: $COPILOT_AGENTS_DIR"
	echo "---"
	find "$COPILOT_AGENTS_DIR" -type f -name "*.md" >"$TEMP_FILE_LIST"
	while IFS= read -r file; do
		[[ -z "$file" ]] && continue
		TOTAL_FILES=$((TOTAL_FILES + 1))
		if validate_agent_file "$file"; then
			PASSED_FILES=$((PASSED_FILES + 1))
		else
			FAILED_FILES=$((FAILED_FILES + 1))
		fi
	done <"$TEMP_FILE_LIST"
	echo ""
fi

# Print summary
echo "================================"
echo "Summary"
echo "================================"
echo "Total files checked: $TOTAL_FILES"
echo -e "${GREEN}Passed${NC}: $PASSED_FILES"
if [[ $FAILED_FILES -gt 0 ]]; then
	echo -e "${RED}Failed${NC}: $FAILED_FILES"
fi
echo ""

# Exit with appropriate code
if [[ $FAILED_FILES -gt 0 ]]; then
	echo -e "${RED}VALIDATION FAILED${NC}: $FAILED_FILES file(s) have validation errors"
	exit 1
else
	echo -e "${GREEN}ALL TESTS PASSED${NC}"
	exit 0
fi
