#!/bin/bash
# Session Setup hook: model-registry-refresh.sh
# Checks mtime of models-registry.json. >14 days → background refresh. >7 days → info notification.
# Checks CLI versions vs registry, reports upgrades. <2s, non-blocking.

set -euo pipefail

REGISTRY="models-registry.json"
MTIME=$(stat -f %m "$REGISTRY" 2>/dev/null || echo 0)
NOW=$(date +%s)
AGE=$(( (NOW - MTIME) / 86400 ))

if [ "$AGE" -gt 14 ]; then
  nohup bash hooks/model-registry-refresh-bg.sh &>/dev/null &
  echo "INFO: $REGISTRY is $AGE days old (>14). Background refresh started."
elif [ "$AGE" -gt 7 ]; then
  echo "INFO: $REGISTRY is $AGE days old (>7). Consider refreshing."
fi

# CLI version check
CLI_VERSION=$(copilot --version 2>/dev/null | awk '{print $NF}')
REG_VERSION=$(jq -r '.cli_version' "$REGISTRY" 2>/dev/null || echo "")
if [ "$CLI_VERSION" != "$REG_VERSION" ] && [ -n "$REG_VERSION" ]; then
  echo "INFO: CLI version $CLI_VERSION differs from registry $REG_VERSION. Upgrade recommended."
fi

exit 0
