#!/bin/bash
# Debug hook to see what input we receive
# Version: 1.1.0
set -uo pipefail
LOG="$HOME/.claude/logs/hook-debug.log"
mkdir -p "$(dirname "$LOG")"
echo "=== $(date) ===" >>"$LOG"
echo "ARGS: $@" >>"$LOG"
echo "ENV CLAUDE_*:" >>"$LOG"
env | grep -i claude >>"$LOG" 2>/dev/null || echo "(none)" >>"$LOG"
echo "STDIN:" >>"$LOG"
cat >>"$LOG"
echo "" >>"$LOG"
exit 0
