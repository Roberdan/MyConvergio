#!/bin/bash
# Prune old cache/log artifacts to keep ~/.claude tidy.

set -euo pipefail

CLAUDE_HOME="${HOME}/.claude"

prune_dir() {
  local dir="$1"
  local days="$2"
  [ -d "$dir" ] || return 0
  find "$dir" -type f -mtime +"$days" -print -delete
}

# Logs and transient data
prune_dir "${CLAUDE_HOME}/logs" 30
prune_dir "${CLAUDE_HOME}/cache" 30
prune_dir "${CLAUDE_HOME}/telemetry" 30
prune_dir "${CLAUDE_HOME}/paste-cache" 30
