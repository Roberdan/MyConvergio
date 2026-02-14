#!/usr/bin/env bash
# Grafana HTTP API helper
# Replaces Grafana MCP (13.8k token overhead)

set -euo pipefail

# Load from .env if exists
if [ -f "$HOME/.claude/.env" ]; then
  source "$HOME/.claude/.env"
fi

GRAFANA_URL="${GRAFANA_URL:-${GRAFANA_URL:-http://localhost:3000}}"
GRAFANA_API_KEY="${GRAFANA_API_KEY:-}"

if [ -z "$GRAFANA_API_KEY" ]; then
  echo "Error: GRAFANA_API_KEY not set" >&2
  echo "Set in ~/.claude/.env or export GRAFANA_API_KEY=glsa_..." >&2
  exit 1
fi

grafana_query() {
  local endpoint="$1"
  shift
  curl -s -H "Authorization: Bearer $GRAFANA_API_KEY" \
    "$GRAFANA_URL/api/$endpoint" "$@"
}

case "${1:-help}" in
  dashboards)
    # List dashboards
    grafana_query "search?type=dash-db" | jq -r '.[] | "\(.uid) \(.title)"'
    ;;

  dashboard)
    # Get dashboard by UID
    if [ -z "${2:-}" ]; then
      echo "Usage: $0 dashboard <uid>" >&2
      exit 1
    fi
    grafana_query "dashboards/uid/$2" | jq .
    ;;

  datasources)
    # List datasources
    grafana_query "datasources" | jq -r '.[] | "\(.uid) \(.type) \(.name)"'
    ;;

  datasource)
    # Get datasource by UID
    if [ -z "${2:-}" ]; then
      echo "Usage: $0 datasource <uid>" >&2
      exit 1
    fi
    grafana_query "datasources/uid/$2" | jq .
    ;;

  alerts)
    # List alert rules
    grafana_query "v1/provisioning/alert-rules" | jq -r '.[] | "\(.uid) \(.title)"'
    ;;

  health)
    # Health check
    curl -s "$GRAFANA_URL/api/health" | jq .
    ;;

  help|*)
    cat <<EOF
Grafana CLI Helper

Usage: $0 <command> [args]

Commands:
  dashboards              List all dashboards
  dashboard <uid>         Get dashboard by UID
  datasources             List datasources
  datasource <uid>        Get datasource by UID
  alerts                  List alert rules
  health                  Health check

Environment:
  GRAFANA_URL            Grafana instance URL (default: ${GRAFANA_URL:-http://localhost:3000})
  GRAFANA_API_KEY        API key (required)

Example:
  export GRAFANA_API_KEY=glsa_...
  $0 dashboards
  $0 dashboard abc123xyz
EOF
    ;;
esac
