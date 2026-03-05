#!/usr/bin/env bash
# notify-config.sh — Notification config loader (sourced, not executed)

[[ "${BASH_SOURCE[0]}" == "${0}" ]] && { echo "ERROR: must be sourced." >&2; exit 1; }

_NOTIFY_CONF="${CLAUDE_HOME:-$HOME/.claude}/config/notifications.conf"

notify_load() {
  [[ ! -f "$_NOTIFY_CONF" ]] && return 1
  local section=""
  while IFS= read -r line || [[ -n "$line" ]]; do
    line="${line%%#*}"
    line="${line#"${line%%[![:space:]]*}"}"
    line="${line%"${line##*[![:space:]]}"}"
    [[ -z "$line" ]] && continue
    if [[ "$line" =~ ^\[(.+)\]$ ]]; then
      section="${BASH_REMATCH[1]}"
    elif [[ -n "$section" && "$line" =~ ^([^=]+)=(.*)$ ]]; then
      eval "_NOTIFY_${section}_${BASH_REMATCH[1]}='${BASH_REMATCH[2]}'"
    fi
  done < "$_NOTIFY_CONF"
}

notify_enabled() {
  local channel="${1:-}"
  [[ -z "$channel" ]] && return 1
  eval "local val=\"\${_NOTIFY_${channel}_enabled:-false}\""
  [[ "$val" == "true" ]]
}

notify_get() {
  local channel="${1:-}" key="${2:-}"
  [[ -z "$channel" || -z "$key" ]] && return 1
  eval "local val=\"\${_NOTIFY_${channel}_${key}:-}\""
  [[ -n "$val" ]] && echo "$val" || return 1
}
