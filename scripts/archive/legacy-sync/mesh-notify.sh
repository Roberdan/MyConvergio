#!/usr/bin/env bash
# mesh-notify.sh — Multi-channel notification dispatcher
# Usage: mesh-notify.sh <severity> <title> <message> [--link URL] [--plan-id N]
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CLAUDE_HOME="${CLAUDE_HOME:-$HOME/.claude}"
DB="${CLAUDE_DB:-$CLAUDE_HOME/data/dashboard.db}"
source "$SCRIPT_DIR/lib/notify-config.sh"
notify_load 2>/dev/null || true

SEVERITY="${1:-info}"; TITLE="${2:-Notification}"; MESSAGE="${3:-}"; shift 3 || true
LINK="" PLAN_ID=""
while [[ $# -gt 0 ]]; do
  case "$1" in
    --link) LINK="${2:-}"; shift 2 ;;
    --plan-id) PLAN_ID="${2:-}"; shift 2 ;;
    *) shift ;;
  esac
done

_macos_notify() {
  notify_enabled macos || return 0
  local prio="$SEVERITY"
  [[ "$prio" == "action_required" ]] && prio="critical"
  osascript -e "display notification \"$MESSAGE\" with title \"$TITLE\" subtitle \"[$prio]\"" 2>/dev/null || true
  [[ -n "$LINK" ]] && osascript -e "open location \"$LINK\"" 2>/dev/null || true
}

_ntfy_notify() {
  notify_enabled ntfy || return 0
  local server topic prio
  server=$(notify_get ntfy server 2>/dev/null || echo "https://ntfy.sh")
  topic=$(notify_get ntfy topic 2>/dev/null || echo "convergio-mesh")
  case "$SEVERITY" in
    critical|action_required) prio="urgent" ;;
    warning) prio="high" ;;
    *) prio="default" ;;
  esac
  local args=(-s -d "$MESSAGE" -H "Title: $TITLE" -H "Priority: $prio")
  [[ -n "$LINK" ]] && args+=(-H "Click: $LINK")
  curl "${args[@]}" "$server/$topic" >/dev/null 2>&1 || true
}

_dashboard_notify() {
  notify_enabled dashboard || return 0
  local proj_id="claude"
  [[ -n "$PLAN_ID" ]] && proj_id=$(sqlite3 "$DB" "SELECT COALESCE(project_id,'claude') FROM plans WHERE id=$PLAN_ID;" 2>/dev/null || echo "claude")
  local ntype="info"
  [[ "$SEVERITY" == "warning" || "$SEVERITY" == "critical" ]] && ntype="warning"
  [[ "$SEVERITY" == "action_required" ]] && ntype="error"
  sqlite3 "$DB" "INSERT INTO notifications (project_id, type, severity, title, message, source_table, source_id, link, link_type) VALUES ('$proj_id', '$ntype', '${SEVERITY}', '$(echo "$TITLE" | sed "s/'/''/g")', '$(echo "$MESSAGE" | sed "s/'/''/g")', 'mesh-coordinator', '', '${LINK:-}', 'deeplink');" 2>/dev/null || true
}

_telegram_notify() {
  notify_enabled telegram || return 0
  local token chat_id
  token=$(notify_get telegram bot_token 2>/dev/null || echo "")
  chat_id=$(notify_get telegram chat_id 2>/dev/null || echo "")
  [[ -z "$token" || -z "$chat_id" ]] && return 0
  local text="*$TITLE*\n$MESSAGE"
  [[ -n "$LINK" ]] && text+="\n[Open]($LINK)"
  curl -s -X POST "https://api.telegram.org/bot$token/sendMessage" \
    -d "chat_id=$chat_id" -d "text=$text" -d "parse_mode=Markdown" >/dev/null 2>&1 || true
}

_macos_notify
_ntfy_notify
_dashboard_notify
_telegram_notify
