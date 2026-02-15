#!/bin/bash
# Generate repository context for Claude Code
# Creates .claude-index with structure, symbols, and patterns
# Usage: repo-index.sh [output-dir]

# Version: 1.1.0
set -e

# Check dependencies
for dep in jq; do
	command -v "$dep" &>/dev/null || {
		echo "ERROR: $dep not installed"
		exit 1
	}
done
# Optional tools: tokei, eza, fd, rg (graceful fallback if missing)

OUTPUT_DIR="${1:-.claude}"
mkdir -p "$OUTPUT_DIR"

echo "=== Indexing repository for Claude ==="

# 1. Basic info
INFO_FILE="$OUTPUT_DIR/repo-info.md"
{
	echo "# Repository Info"
	echo "Generated: $(date '+%Y-%m-%d %H:%M')"
	echo ""

	if command -v onefetch &>/dev/null; then
		echo "## Overview"
		onefetch --no-art --no-color-palette 2>/dev/null || true
	fi

	echo ""
	echo "## Languages"
	tokei --compact 2>/dev/null || echo "tokei not installed"

	echo ""
	echo "## Structure (top 3 levels)"
	eza --tree --level=3 --icons=never -I 'node_modules|.git|dist|build|vendor' 2>/dev/null ||
		find . -maxdepth 3 -type d ! -path '*/\.*' ! -path '*/node_modules/*' | head -50
} >"$INFO_FILE"
echo "Created: $INFO_FILE"

# 2. Symbol index (functions, classes, types)
SYMBOLS_FILE="$OUTPUT_DIR/symbols.txt"
CTAGS_BIN=$(command -v ctags 2>/dev/null || echo "")
if [[ -z "$CTAGS_BIN" ]]; then
	# Try common locations
	for p in /opt/homebrew/bin/ctags /usr/local/bin/ctags /usr/bin/ctags; do
		[[ -x "$p" ]] && CTAGS_BIN="$p" && break
	done
fi
if [[ -n "$CTAGS_BIN" ]] && [[ -x "$CTAGS_BIN" ]]; then
	"$CTAGS_BIN" -R --exclude=node_modules --exclude=.git --exclude=dist \
		--exclude=build --exclude=vendor --exclude='*.min.*' \
		--fields=+lKS --kinds-all='*' -f "$SYMBOLS_FILE" . 2>/dev/null
	echo "Created: $SYMBOLS_FILE ($(/usr/bin/wc -l <"$SYMBOLS_FILE" | tr -d ' ') symbols)"
else
	echo "Skipped: symbols.txt (universal-ctags not found)"
fi

# 3. Entry points and main files
ENTRY_FILE="$OUTPUT_DIR/entry-points.md"
{
	echo "# Entry Points"
	echo ""
	echo "## Package manifests"
	for f in package.json Cargo.toml pyproject.toml go.mod build.gradle pom.xml; do
		[ -f "$f" ] && echo "- $f"
	done

	echo ""
	echo "## Main/Index files"
	fd -t f -d 3 '(main|index|app|server)\.(ts|js|py|go|rs)$' 2>/dev/null | head -20

	echo ""
	echo "## Config files"
	fd -t f -d 2 '(config|settings|env)\.' 2>/dev/null | head -10

	echo ""
	echo "## Test directories"
	fd -t d '(test|spec|__tests__)' -d 2 2>/dev/null | head -5
} >"$ENTRY_FILE"
echo "Created: $ENTRY_FILE"

# 4. API patterns (if applicable)
API_FILE="$OUTPUT_DIR/api-patterns.md"
{
	echo "# API Patterns"
	echo ""
	echo "## Route definitions"
	rg -l '(app\.(get|post|put|delete)|router\.|@(Get|Post|Put|Delete))' 2>/dev/null | head -10

	echo ""
	echo "## API endpoints (sample)"
	rg -o --no-filename "['\"](/api/[^'\"]+)['\"]" 2>/dev/null | sort -u | head -20
} >"$API_FILE"
echo "Created: $API_FILE"

# 5. Dependencies summary
DEPS_FILE="$OUTPUT_DIR/dependencies.md"
{
	echo "# Dependencies"
	echo ""
	if [ -f "package.json" ]; then
		echo "## npm (package.json)"
		jq -r '.dependencies // {} | keys[]' package.json 2>/dev/null | head -20
	fi
	if [ -f "requirements.txt" ]; then
		echo "## Python (requirements.txt)"
		head -20 requirements.txt
	fi
	if [ -f "Cargo.toml" ]; then
		echo "## Rust (Cargo.toml)"
		rg '^\w+ = ' Cargo.toml | head -20
	fi
} >"$DEPS_FILE"
echo "Created: $DEPS_FILE"

echo ""
echo "=== Index complete ==="
echo "Files created in: $OUTPUT_DIR/"
ls -la "$OUTPUT_DIR/"
