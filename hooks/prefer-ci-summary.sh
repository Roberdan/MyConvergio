#!/usr/bin/env bash
# prefer-ci-summary.sh - PreToolUse hook on Bash
# Intercepts verbose CI commands and suggests ci-summary.sh instead.
# Saves ~95% tokens per verification cycle.
#
# Hook type: PreToolUse on Bash
# Detects: npm run lint, npm run typecheck, npm run build (standalone)
# Allows: ci-summary.sh, release scripts, piped commands with grep/head

INPUT=$(cat)
COMMAND=$(echo "$INPUT" | jq -r '.tool_input.command // empty' 2>/dev/null)

[ -z "$COMMAND" ] && exit 0

# Allow ci-summary itself
echo "$COMMAND" | grep -q "ci-summary\|ci:summary" && exit 0

# Allow release/pre-push scripts (they have their own filtering)
echo "$COMMAND" | grep -qE "release|pre-push|pre-release" && exit 0

# Allow piped commands (user is already filtering)
echo "$COMMAND" | grep -qE "\|.*grep|\|.*head|\|.*tail|\|.*wc" && exit 0

# Allow commands with --reporter, --format (already compact)
echo "$COMMAND" | grep -q "\-\-reporter" && exit 0
echo "$COMMAND" | grep -q "\-\-format" && exit 0

# Allow gh commands (GitHub CLI)
echo "$COMMAND" | grep -qE "^gh " && exit 0

# Detect standalone verbose CI commands
VERBOSE_PATTERN="^npm run (lint|typecheck|build|test:unit)( |$)"
if echo "$COMMAND" | grep -qE "$VERBOSE_PATTERN"; then
  # Check if ci-summary.sh exists in current project
  if [ -f "./scripts/ci-summary.sh" ]; then
    echo "TOKEN-WASTE: Use './scripts/ci-summary.sh' or 'npm run ci:summary' instead."
    echo "Verbose command detected: $COMMAND"
    echo "ci-summary.sh produces ~20 lines vs ~2000+ lines, saving ~95% tokens."
    echo "For single steps: ./scripts/ci-summary.sh --lint|--types|--build|--unit|--i18n"
    exit 0
  fi
fi

# Detect chained verbose commands
CHAIN_PATTERN="npm run lint.*&&.*npm run typecheck|npm run typecheck.*&&.*npm run build"
if echo "$COMMAND" | grep -qE "$CHAIN_PATTERN"; then
  if [ -f "./scripts/ci-summary.sh" ]; then
    echo "TOKEN-WASTE: Use 'npm run ci:summary' instead of chained verbose commands."
    echo "Detected: $COMMAND"
    echo "ci-summary.sh runs all steps and outputs only errors/warnings (~20 lines)."
    exit 0
  fi
fi

exit 0
