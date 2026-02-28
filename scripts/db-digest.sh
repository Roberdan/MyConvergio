#!/usr/bin/env bash
set -euo pipefail
# DB Digest - Compact dashboard DB summaries for plans/tasks/waves
# Usage: db-digest.sh <plans|tasks|waves|stats> [plan_id] [--no-cache] [--compact]
# Version: 1.0.0

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/lib/digest-cache.sh"

DB_FILE="${PLAN_DB_FILE:-$HOME/.claude/data/dashboard.db}"
CACHE_TTL=10
NO_CACHE=0
COMPACT=0

digest_check_compact "$@"

require_db() {
  [[ -f "$DB_FILE" ]] || {
    jq -n --arg db "$DB_FILE" '{status:"error",msg:"dashboard DB not found",db:$db}' >&2
    exit 1
  }
}

require_cols() {
  local table="$1"
  shift
  local col missing=0
  for col in "$@"; do
    local exists
    exists=$(sqlite3 "$DB_FILE" "SELECT COUNT(*) FROM pragma_table_info('$table') WHERE name='$col';")
    if [[ "$exists" != "1" ]]; then
      echo "missing:$col"
      missing=1
    fi
  done
  [[ "$missing" -eq 0 ]]
}

validate_or_die() {
  local table="$1"
  shift
  local misses
  misses=$(require_cols "$table" "$@" || true)
  [[ -z "$misses" ]] && return 0
  jq -n --arg table "$table" --arg miss "$misses" \
    '{status:"error",msg:"schema validation failed",table:$table,missing:($miss | split("\n") | map(select(length>0) | sub("^missing:";"")))}' >&2
  exit 1
}

cmd_plans() {
  validate_or_die plans id project_id name status tasks_done tasks_total
  sqlite3 -json "$DB_FILE" "
    SELECT
      id,
      project_id,
      name,
      status,
      tasks_done,
      tasks_total,
      CASE WHEN tasks_total > 0 THEN ROUND((tasks_done * 100.0) / tasks_total, 1) ELSE 0 END AS progress_pct
    FROM plans
    WHERE status IN ('todo','doing')
    ORDER BY
      CASE status WHEN 'doing' THEN 0 WHEN 'todo' THEN 1 ELSE 2 END,
      updated_at DESC,
      id DESC;
  "
}

cmd_tasks() {
  local plan_id="${1:-}"
  [[ "$plan_id" =~ ^[0-9]+$ ]] || {
    echo '{"status":"error","msg":"plan_id required for tasks"}' >&2
    exit 1
  }
  validate_or_die tasks id plan_id status
  sqlite3 -json "$DB_FILE" "
    WITH base AS (
      SELECT status, COUNT(*) AS cnt
      FROM tasks
      WHERE plan_id = $plan_id
      GROUP BY status
    )
    SELECT
      $plan_id AS plan_id,
      (SELECT COUNT(*) FROM tasks WHERE plan_id = $plan_id) AS total_tasks,
      COALESCE((SELECT cnt FROM base WHERE status='pending'),0) AS pending,
      COALESCE((SELECT cnt FROM base WHERE status='in_progress'),0) AS in_progress,
      COALESCE((SELECT cnt FROM base WHERE status='submitted'),0) AS submitted,
      COALESCE((SELECT cnt FROM base WHERE status='done'),0) AS done,
      COALESCE((SELECT cnt FROM base WHERE status='blocked'),0) AS blocked,
      COALESCE((SELECT cnt FROM base WHERE status='cancelled'),0) AS cancelled,
      COALESCE((SELECT cnt FROM base WHERE status='skipped'),0) AS skipped;
  " | jq '.[0]'
}

cmd_waves() {
  local plan_id="${1:-}"
  [[ "$plan_id" =~ ^[0-9]+$ ]] || {
    echo '{"status":"error","msg":"plan_id required for waves"}' >&2
    exit 1
  }
  validate_or_die waves id plan_id wave_id name status tasks_done tasks_total
  sqlite3 -json "$DB_FILE" "
    SELECT
      id,
      wave_id,
      name,
      status,
      tasks_done,
      tasks_total,
      CASE WHEN tasks_total > 0 THEN ROUND((tasks_done * 100.0) / tasks_total, 1) ELSE 0 END AS progress_pct,
      merge_mode,
      theme
    FROM waves
    WHERE plan_id = $plan_id
    ORDER BY position ASC, id ASC;
  "
}

cmd_stats() {
  validate_or_die plans id status
  sqlite3 -json "$DB_FILE" "
    SELECT
      COUNT(*) AS total_plans,
      SUM(CASE WHEN status = 'done' THEN 1 ELSE 0 END) AS done,
      SUM(CASE WHEN status IN ('todo','doing') THEN 1 ELSE 0 END) AS active,
      SUM(CASE WHEN status = 'cancelled' THEN 1 ELSE 0 END) AS cancelled
    FROM plans;
  " | jq '.[0]'
}

print_help() {
  cat <<'EOF_HELP'
DB Digest - Compact dashboard DB summaries

Usage:
  db-digest.sh plans [--no-cache] [--compact]
  db-digest.sh tasks <plan_id> [--no-cache] [--compact]
  db-digest.sh waves <plan_id> [--no-cache] [--compact]
  db-digest.sh stats [--no-cache] [--compact]
  db-digest.sh --help

Options:
  --no-cache   Skip cache and fetch fresh data
  --compact    Keep only decision-critical fields
EOF_HELP
}

COMMAND=""
PLAN_ID=""
for arg in "$@"; do
  case "$arg" in
  --no-cache)
    NO_CACHE=1
    ;;
  --compact)
    ;;
  --help|-h|help)
    print_help
    exit 0
    ;;
  plans|tasks|waves|stats)
    [[ -z "$COMMAND" ]] && COMMAND="$arg"
    ;;
  *)
    [[ -z "$PLAN_ID" ]] && PLAN_ID="$arg"
    ;;
  esac
done

[[ -n "$COMMAND" ]] || {
  print_help
  exit 0
}

require_db
CACHE_KEY="db-${COMMAND}-${PLAN_ID:-none}"
if [[ "$NO_CACHE" -eq 0 ]] && digest_cache_get "$CACHE_KEY" "$CACHE_TTL"; then
  exit 0
fi

case "$COMMAND" in
plans)
  RESULT=$(cmd_plans)
  FILTER='map({id, status, progress_pct})'
  ;;
tasks)
  RESULT=$(cmd_tasks "$PLAN_ID")
  FILTER='{plan_id, total_tasks, in_progress, submitted, done, blocked}'
  ;;
waves)
  RESULT=$(cmd_waves "$PLAN_ID")
  FILTER='map({id, wave_id, status, progress_pct, merge_mode})'
  ;;
stats)
  RESULT=$(cmd_stats)
  FILTER='{total_plans, active, done, cancelled}'
  ;;
*)
  print_help
  exit 1
  ;;
esac

echo "$RESULT" | digest_cache_set "$CACHE_KEY"
echo "$RESULT" | COMPACT=$COMPACT digest_compact_filter "$FILTER"
