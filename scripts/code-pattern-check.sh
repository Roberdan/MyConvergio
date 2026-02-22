#!/usr/bin/env bash
# Code Pattern Check - Automated pattern detection (no AI)
# 8 grep-based checks for common issues Copilot catches.
# Each check returns {pass, findings[]}. Overall exit 0 always (findings in JSON).
# Usage: code-pattern-check.sh [--files f1 f2 ...] [--diff-base main] [--json]
# Version: 1.0.0
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/lib/code-pattern-checks.sh"

# --- Argument parsing ---
FILES=()
DIFF_BASE=""
JSON_OUTPUT=0

while [[ $# -gt 0 ]]; do
	case "$1" in
	--files)
		shift
		while [[ $# -gt 0 && ! "$1" =~ ^-- ]]; do
			FILES+=("$1")
			shift
		done
		;;
	--diff-base)
		DIFF_BASE="${2:-main}"
		shift 2
		;;
	--json)
		JSON_OUTPUT=1
		shift
		;;
	*)
		shift
		;;
	esac
done

# If no files specified and diff-base given, get changed files from diff
if [[ ${#FILES[@]} -eq 0 && -n "$DIFF_BASE" ]]; then
	while IFS= read -r f; do
		[[ -f "$f" ]] && FILES+=("$f")
	done < <(git diff --name-only --diff-filter=ACMR "${DIFF_BASE}...HEAD" 2>/dev/null || true)
fi

# If still no files, get staged + modified files
if [[ ${#FILES[@]} -eq 0 ]]; then
	while IFS= read -r f; do
		[[ -f "$f" ]] && FILES+=("$f")
	done < <(git diff --name-only --diff-filter=ACMR HEAD 2>/dev/null || true)
	while IFS= read -r f; do
		[[ -f "$f" ]] && FILES+=("$f")
	done < <(git diff --name-only --cached --diff-filter=ACMR 2>/dev/null || true)
fi

# Filter to code files only (skip images, binaries, etc.)
CODE_FILES=()
for f in "${FILES[@]}"; do
	if [[ "$f" =~ \.(ts|tsx|js|jsx|py|sh|sql|prisma|mjs|cjs)$ ]]; then
		CODE_FILES+=("$f")
	fi
done

if [[ ${#CODE_FILES[@]} -eq 0 ]]; then
	jq -n '{total_files: 0, checks: 0, p1: 0, p2: 0, pass: true, results: []}'
	exit 0
fi

# Export CODE_FILES for check functions
export CODE_FILES

# --- Run all 8 checks ---
RESULTS=()
RESULTS+=("$(check_unguarded_json_parse)")
RESULTS+=("$(check_unguarded_method_call)")
RESULTS+=("$(check_react_lazy_named_export)")
RESULTS+=("$(check_load_all_paginate)")
RESULTS+=("$(check_duplicate_class_names)")
RESULTS+=("$(check_unused_parameters)")
RESULTS+=("$(check_insecure_file_write)")
RESULTS+=("$(check_missing_error_boundary)")

# --- Aggregate ---
ALL_JSON=$(printf '%s\n' "${RESULTS[@]}" | jq -s '.')

SUMMARY=$(echo "$ALL_JSON" | jq '{
	total_files: ('"${#CODE_FILES[@]}"'),
	checks: length,
	p1: [.[] | select(.severity == "P1" and .pass == false)] | length,
	p2: [.[] | select(.severity == "P2" and .pass == false)] | length,
	pass: (all(.pass)),
	results: .
}')

if [[ "$JSON_OUTPUT" -eq 1 ]]; then
	echo "$SUMMARY"
else
	# Human-readable output
	echo "=== Code Pattern Check ==="
	echo "Files: ${#CODE_FILES[@]} | Checks: 8"
	echo ""
	echo "$ALL_JSON" | jq -r '.[] | select(.pass == false) |
		"[\(.severity)] \(.check): \(.findings | length) finding(s)\(.findings[] | "\n  - \(.file // "N/A"):\(.line // "?") \(.body | .[0:100])")"'
	echo ""
	P1=$(echo "$SUMMARY" | jq '.p1')
	P2=$(echo "$SUMMARY" | jq '.p2')
	PASS=$(echo "$SUMMARY" | jq '.pass')
	if [[ "$PASS" == "true" ]]; then
		echo "RESULT: PASS (0 findings)"
	else
		echo "RESULT: ${P1} P1, ${P2} P2 findings"
	fi
fi
