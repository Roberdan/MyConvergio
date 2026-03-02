#!/bin/bash
# Dashboard delegation stats module
# Provides render_delegation_stats() for dashboard-mini.sh

# Source delegation_log (assume path is set by caller)

# shellcheck source=../../data/delegation_log
DELEGATION_LOG="${DELEGATION_LOG:-$HOME/.claude/data/delegation_log}"

render_delegation_stats() {
  # Provider distribution
  local providers
  providers=$(awk -F'|' '{print $2}' "$DELEGATION_LOG" | sort | uniq -c | sort -nr)
  echo "Provider distribution:"
  echo "$providers"

  # Thor pass rate per model
  local models
  models=$(awk -F'|' '{print $3}' "$DELEGATION_LOG" | sort | uniq)
  echo "Thor pass rate per model:"
  for model in $models; do
    local total pass rate color
    total=$(awk -F'|' -v m="$model" '$3==m{c++} END{print c+0}' "$DELEGATION_LOG")
    pass=$(awk -F'|' -v m="$model" '$3==m && $5=="PASS"{c++} END{print c+0}' "$DELEGATION_LOG")
    rate=$((total>0 ? pass*100/total : 0))
    color="\033[0;32m"
    [ $rate -lt 70 ] && color="\033[0;31m"
    echo -e "  $model: ${color}${rate}%\033[0m ($pass/$total)"
    [ $rate -lt 70 ] && echo -e "  ALERT: $model pass rate <70%"
  done

  # Cost savings estimate
  local savings
  savings=$(awk -F'|' '{s+=$6} END{print s+0}' "$DELEGATION_LOG")
  echo "Estimated cost savings: $savings tokens"
}
