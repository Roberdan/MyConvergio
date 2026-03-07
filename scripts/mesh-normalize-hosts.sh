#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CLAUDE_HOME="${CLAUDE_HOME:-$HOME/.claude}"
DB_PATH="${CLAUDE_DB:-${PLAN_DB_FILE:-$CLAUDE_HOME/data/dashboard.db}}"
DRY_RUN=false

usage() {
  cat <<'USAGE'
Usage: mesh-normalize-hosts.sh [--dry-run]

One-time migration that normalizes plans.execution_host and tasks.executor_host
using canonical peer names from peers.conf.
USAGE
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --dry-run) DRY_RUN=true; shift ;;
    --help|-h) usage; exit 0 ;;
    *)
      echo "ERROR: Unknown argument: $1" >&2
      usage >&2
      exit 2
      ;;
  esac
done

if [[ ! -f "$DB_PATH" ]]; then
  echo "ERROR: Database not found: $DB_PATH" >&2
  exit 1
fi

# shellcheck source=scripts/lib/peers.sh
source "$SCRIPT_DIR/lib/peers.sh"
peers_load

sql_quote() {
  printf "%s" "$1" | sed "s/'/''/g"
}

trim() {
  local s="$1"
  s="${s#"${s%%[![:space:]]*}"}"
  s="${s%"${s##*[![:space:]]}"}"
  printf "%s" "$s"
}

SQL_FILE="$(mktemp)"
trap 'rm -f "$SQL_FILE"' EXIT

{
  echo "BEGIN IMMEDIATE;"
  echo "CREATE TEMP TABLE host_map (variant TEXT PRIMARY KEY, canonical TEXT NOT NULL);"
} >"$SQL_FILE"

add_variant() {
  local canonical="$1"
  local variant_raw="$2"
  local variant
  variant="$(trim "$variant_raw")"
  [[ -z "$canonical" || -z "$variant" ]] && return 0

  local q_canonical q_variant
  q_canonical="$(sql_quote "$canonical")"
  q_variant="$(sql_quote "$variant")"
  printf "INSERT OR IGNORE INTO host_map(variant, canonical) VALUES ('%s', '%s');\n" \
    "$q_variant" "$q_canonical" >>"$SQL_FILE"
}

# Build peer variants -> canonical mapping for each section in peers.conf
for peer in $_PEERS_ALL; do
  add_variant "$peer" "$peer"
  add_variant "$peer" "$(peers_get "$peer" ssh_alias 2>/dev/null || true)"
  add_variant "$peer" "$(peers_get "$peer" dns_name 2>/dev/null || true)"
done

# Local machine historical variants -> peers_self canonical name
SELF_PEER="$(peers_self || true)"
if [[ -n "$SELF_PEER" ]]; then
  HN_SHORT="$(hostname -s 2>/dev/null || true)"
  HN_FULL="$(hostname 2>/dev/null || true)"
  LOCAL_HOSTNAME="$(scutil --get LocalHostName 2>/dev/null || true)"
  COMPUTER_NAME="$(scutil --get ComputerName 2>/dev/null | tr -d "'" || true)"

  add_variant "$SELF_PEER" "$HN_SHORT"
  add_variant "$SELF_PEER" "$HN_FULL"
  add_variant "$SELF_PEER" "$LOCAL_HOSTNAME"
  add_variant "$SELF_PEER" "$COMPUTER_NAME"

  # Common macOS DNS-style variants seen historically
  [[ -n "$HN_SHORT" ]] && add_variant "$SELF_PEER" "${HN_SHORT}.lan"
  [[ -n "$LOCAL_HOSTNAME" ]] && add_variant "$SELF_PEER" "${LOCAL_HOSTNAME}.lan"
  [[ -n "$COMPUTER_NAME" ]] && add_variant "$SELF_PEER" "${COMPUTER_NAME}.lan"
fi

cat >>"$SQL_FILE" <<'SQL'
CREATE TEMP TABLE _counts(name TEXT PRIMARY KEY, value INTEGER);

UPDATE plans
SET execution_host = (SELECT m.canonical FROM host_map m WHERE m.variant = plans.execution_host)
WHERE execution_host IN (SELECT variant FROM host_map)
  AND execution_host <> (SELECT m.canonical FROM host_map m WHERE m.variant = plans.execution_host);
INSERT INTO _counts(name, value) VALUES ('plans', changes());

UPDATE tasks
SET executor_host = (SELECT m.canonical FROM host_map m WHERE m.variant = tasks.executor_host)
WHERE executor_host IN (SELECT variant FROM host_map)
  AND executor_host <> (SELECT m.canonical FROM host_map m WHERE m.variant = tasks.executor_host);
INSERT INTO _counts(name, value) VALUES ('tasks', changes());

DELETE FROM peer_heartbeats
WHERE peer_name LIKE 'test-%';
INSERT INTO _counts(name, value) VALUES ('heartbeats', changes());

SELECT
  COALESCE((SELECT value FROM _counts WHERE name='plans'), 0) || '|' ||
  COALESCE((SELECT value FROM _counts WHERE name='tasks'), 0) || '|' ||
  COALESCE((SELECT value FROM _counts WHERE name='heartbeats'), 0);
COMMIT;
SQL

if $DRY_RUN; then
  cat "$SQL_FILE"
  exit 0
fi

result="$(sqlite3 -batch "$DB_PATH" <"$SQL_FILE")"
IFS='|' read -r plans_count tasks_count heartbeats_count <<<"$result"

echo "Normalized ${plans_count:-0} plans, ${tasks_count:-0} tasks. Cleaned ${heartbeats_count:-0} test heartbeats."
