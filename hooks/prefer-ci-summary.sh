#!/usr/bin/env bash
# prefer-ci-summary.sh - PreToolUse hook on Bash
# Intercepts verbose commands and suggests token-efficient alternatives.
# Saves ~95% tokens per verification cycle.
#
# Hook type: PreToolUse on Bash

INPUT=$(cat)
COMMAND=$(echo "$INPUT" | jq -r '.tool_input.command // empty' 2>/dev/null)

[ -z "$COMMAND" ] && exit 0

# Allow our optimized scripts
echo "$COMMAND" | grep -q "ci-summary\|ci:summary\|ci-check" && exit 0

# Allow release/pre-push scripts (they have their own filtering)
echo "$COMMAND" | grep -qE "release|pre-push|pre-release" && exit 0

# Allow piped commands (user is already filtering)
echo "$COMMAND" | grep -qE "\|.*grep|\|.*head|\|.*tail|\|.*wc" && exit 0

# Allow commands with --reporter, --format, --oneline, --short, --stat
echo "$COMMAND" | grep -qE "\-\-(reporter|format|oneline|short|stat)" && exit 0

# --- GitHub CI logs ---
if echo "$COMMAND" | grep -qE "gh run view.*--log"; then
  if [ -f "./scripts/ci-check.sh" ]; then
    echo "TOKEN-WASTE: Use './scripts/ci-check.sh <run-id>' instead."
  elif [ -f "$HOME/.claude/scripts/ci-check.sh" ]; then
    echo "TOKEN-WASTE: Use '~/.claude/scripts/ci-check.sh <run-id>' instead."
  fi
  echo "ci-check.sh extracts only errors (~25 lines vs 100k+ tokens)."
  exit 0
fi
echo "$COMMAND" | grep -qE "^gh " && exit 0

# --- Verbose npm CI commands ---
if echo "$COMMAND" | grep -qE "^npm run (lint|typecheck|build|test:unit)( |$)"; then
  if [ -f "./scripts/ci-summary.sh" ]; then
    echo "TOKEN-WASTE: Use './scripts/ci-summary.sh' instead."
    echo "Detected: $COMMAND"
    echo "Steps: --lint|--types|--build|--unit|--i18n|--full"
    exit 0
  fi
fi

# --- Chained verbose commands ---
if echo "$COMMAND" | grep -qE "npm run lint.*&&.*npm run (typecheck|build)"; then
  if [ -f "./scripts/ci-summary.sh" ]; then
    echo "TOKEN-WASTE: Use 'npm run ci:summary' instead of chained commands."
    exit 0
  fi
fi

# --- Verbose git diff (prefer --stat or Read tool) ---
if echo "$COMMAND" | grep -qE "^git diff [^-].*\| head"; then
  echo "TOKEN-HINT: Use 'git diff --stat' for overview, then Read tool for specific files."
  exit 0
fi

# --- Verbose git log (prefer --oneline) ---
if echo "$COMMAND" | grep -qE "^git log[^|]*$" && ! echo "$COMMAND" | grep -q "oneline"; then
  echo "TOKEN-HINT: Use 'git log --oneline -N' to reduce output."
  exit 0
fi

exit 0
