#!/bin/bash
# env-var-audit.sh — Verify all env vars are documented
# Extracts env var references from source, checks .env.example
# ADAPT: Change SRC_DIR, ENV_PATTERN, DOC_FILE, EXTENSIONS
set -euo pipefail

# ADAPT: Source directory
SRC_DIR="src"
# ADAPT: Pattern to match env var access
# Node/Vite:  'import\.meta\.env\.[A-Z_][A-Z0-9_]*'
# Node/CJS:   'process\.env\.[A-Z_][A-Z0-9_]*'
# Python:     'os\.environ\[.[A-Z_][A-Z0-9_]*.\]|os\.getenv\(.[A-Z_][A-Z0-9_]*'
ENV_PATTERN='import\.meta\.env\.[A-Z_][A-Z0-9_]*'
# ADAPT: How to extract the var name from the match
# Vite:    sed 's/.*import\.meta\.env\.//'
# Node:    sed 's/.*process\.env\.//'
# Python:  varies
EXTRACT_CMD="sed 's/.*import\.meta\.env\.//'"
# ADAPT: Documentation file
DOC_FILE=".env.example"
# ADAPT: File extensions to scan
EXTENSIONS="--include=*.ts --include=*.tsx --include=*.js --include=*.jsx"

if [ ! -f "$DOC_FILE" ]; then
	echo "[env-var-audit] No $DOC_FILE found — skipping"
	exit 0
fi

# Extract env var names from source
# shellcheck disable=SC2086
ENV_VARS=$(grep -rhoE "$ENV_PATTERN" "$SRC_DIR" $EXTENSIONS 2>/dev/null |
	eval "$EXTRACT_CMD" |
	sort -u || true)

if [ -z "$ENV_VARS" ]; then
	echo "[env-var-audit] No env var references found"
	exit 0
fi

MISSING=()
TOTAL=0
for VAR in $ENV_VARS; do
	TOTAL=$((TOTAL + 1))
	if ! grep -qE "^${VAR}=" "$DOC_FILE" 2>/dev/null; then
		MISSING+=("$VAR")
	fi
done

if [ ${#MISSING[@]} -gt 0 ]; then
	echo "[env-var-audit] WARNING: ${#MISSING[@]}/$TOTAL env vars not in $DOC_FILE:"
	for M in "${MISSING[@]}"; do
		echo "  - $M"
	done
	# ADAPT: exit 1 to block, exit 0 to warn only
	exit 0
fi

echo "[env-var-audit] All $TOTAL env vars documented in $DOC_FILE"
