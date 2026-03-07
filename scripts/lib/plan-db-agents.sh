#!/bin/bash
# plan-db-agents.sh: Agent activity tracking for brain visualization
# Provides: cmd_agent_start, cmd_agent_complete, cmd_agent_status, cmd_agent_tokens
# Usage: sourced by plan-db.sh dispatch
set -euo pipefail

cmd_agent_start() {
  local agent_id="${1:?agent_id required}"
  local agent_type="${2:?agent_type required}"
  local description="${3:?description required}"
  shift 3

  local task_db_id="" plan_id="" model="" host="$PLAN_DB_HOST" region=""

  while [[ $# -gt 0 ]]; do
    case "$1" in
      --task)  task_db_id="$2"; shift 2 ;;
      --plan)  plan_id="$2"; shift 2 ;;
      --model) model="$2"; shift 2 ;;
      --host)  host="$2"; shift 2 ;;
      --region) region="$2"; shift 2 ;;
      *) shift ;;
    esac
  done

  local task_val="NULL" plan_val="NULL" model_val="NULL" region_val="NULL"
  [[ -n "$task_db_id" ]] && task_val="$task_db_id"
  [[ -n "$plan_id" ]]    && plan_val="$plan_id"
  [[ -n "$model" ]]      && model_val="'$(sql_escape "$model")'"
  [[ -n "$region" ]]     && region_val="'$(sql_escape "$region")'"

  local row_id
  row_id=$(sqlite3 "$DB_FILE" "
    INSERT INTO agent_activity (agent_id, task_db_id, plan_id, agent_type, model, description, status, host, region)
    VALUES (
      '$(sql_escape "$agent_id")',
      $task_val,
      $plan_val,
      '$(sql_escape "$agent_type")',
      $model_val,
      '$(sql_escape "$description")',
      'running',
      '$(sql_escape "$host")',
      $region_val
    );
    SELECT last_insert_rowid();
  ")

  printf '{"ok":true,"id":%s,"agent_id":"%s","status":"running"}\n' \
    "$row_id" "$agent_id"
}

cmd_agent_complete() {
  local agent_id="${1:?agent_id required}"
  shift

  local tokens_in=0 tokens_out=0 cost=0 status="completed"

  while [[ $# -gt 0 ]]; do
    case "$1" in
      --tokens-in)  tokens_in="$2"; shift 2 ;;
      --tokens-out) tokens_out="$2"; shift 2 ;;
      --cost)       cost="$2"; shift 2 ;;
      --status)     status="$2"; shift 2 ;;
      *) shift ;;
    esac
  done

  local tokens_total=$((tokens_in + tokens_out))

  sqlite3 "$DB_FILE" "
    UPDATE agent_activity SET
      status = '$(sql_escape "$status")',
      tokens_in = $tokens_in,
      tokens_out = $tokens_out,
      tokens_total = $tokens_total,
      cost_usd = $cost,
      completed_at = datetime('now'),
      duration_s = ROUND((julianday('now') - julianday(started_at)) * 86400, 1)
    WHERE agent_id = '$(sql_escape "$agent_id")' AND status = 'running';
  "

  # Propagate totals to parent task if linked
  sqlite3 "$DB_FILE" "
    UPDATE tasks SET
      tokens_total = COALESCE(tokens_total, 0) + $tokens_total,
      cost_usd = COALESCE(cost_usd, 0) + $cost,
      agent_count = COALESCE(agent_count, 0) + 1
    WHERE id IN (
      SELECT task_db_id FROM agent_activity
      WHERE agent_id = '$(sql_escape "$agent_id")' AND task_db_id IS NOT NULL
    );
  "

  printf '{"ok":true,"agent_id":"%s","status":"%s","tokens_total":%d,"cost_usd":%s}\n' \
    "$agent_id" "$status" "$tokens_total" "$cost"
}

cmd_agent_status() {
  local plan_filter="" running_only=false

  while [[ $# -gt 0 ]]; do
    case "$1" in
      --plan)    plan_filter="$2"; shift 2 ;;
      --running) running_only=true; shift ;;
      *) shift ;;
    esac
  done

  local where_clauses=()
  [[ "$running_only" == "true" ]] && where_clauses+=("status = 'running'")
  [[ -n "$plan_filter" ]] && where_clauses+=("plan_id = $plan_filter")

  local where=""
  if [[ ${#where_clauses[@]} -gt 0 ]]; then
    where="WHERE $(IFS=' AND '; echo "${where_clauses[*]}")"
  fi

  sqlite3 -json "$DB_FILE" "
    SELECT id, agent_id, task_db_id, plan_id, agent_type, model,
           description, status, tokens_in, tokens_out, tokens_total,
           cost_usd, started_at, completed_at, duration_s, host, region
    FROM agent_activity $where
    ORDER BY started_at DESC LIMIT 50;
  " 2>/dev/null || echo "[]"
}

cmd_agent_tokens() {
  local plan_filter="" task_filter=""

  while [[ $# -gt 0 ]]; do
    case "$1" in
      --plan) plan_filter="$2"; shift 2 ;;
      --task) task_filter="$2"; shift 2 ;;
      *) shift ;;
    esac
  done

  local where_clauses=()
  [[ -n "$plan_filter" ]] && where_clauses+=("plan_id = $plan_filter")
  [[ -n "$task_filter" ]] && where_clauses+=("task_db_id = $task_filter")

  local where=""
  if [[ ${#where_clauses[@]} -gt 0 ]]; then
    where="WHERE $(IFS=' AND '; echo "${where_clauses[*]}")"
  fi

  local totals by_model by_type
  totals=$(sqlite3 -json "$DB_FILE" "
    SELECT COALESCE(SUM(tokens_in),0) AS total_in,
           COALESCE(SUM(tokens_out),0) AS total_out,
           COALESCE(SUM(tokens_total),0) AS total_tokens,
           COALESCE(SUM(cost_usd),0) AS total_cost,
           COUNT(*) AS agent_count
    FROM agent_activity $where;
  " 2>/dev/null || echo '[{"total_in":0,"total_out":0,"total_tokens":0,"total_cost":0,"agent_count":0}]')

  by_model=$(sqlite3 -json "$DB_FILE" "
    SELECT COALESCE(model,'unknown') AS model,
           SUM(tokens_total) AS tokens, SUM(cost_usd) AS cost, COUNT(*) AS runs
    FROM agent_activity $where
    GROUP BY model ORDER BY tokens DESC;
  " 2>/dev/null || echo "[]")

  by_type=$(sqlite3 -json "$DB_FILE" "
    SELECT agent_type, SUM(tokens_total) AS tokens,
           SUM(cost_usd) AS cost, COUNT(*) AS runs
    FROM agent_activity $where
    GROUP BY agent_type ORDER BY tokens DESC;
  " 2>/dev/null || echo "[]")

  # Build combined JSON
  local t_obj
  t_obj=$(echo "$totals" | python3 -c "
import sys, json
arr = json.load(sys.stdin)
d = arr[0] if arr else {}
print(json.dumps(d))
" 2>/dev/null || echo '{}')

  python3 -c "
import sys, json
totals = json.loads(sys.argv[1])
by_model = json.loads(sys.argv[2])
by_type = json.loads(sys.argv[3])
result = {**totals, 'by_model': {r['model']: r['tokens'] for r in by_model}, 'by_agent_type': {r['agent_type']: r['tokens'] for r in by_type}}
print(json.dumps(result))
" "$t_obj" "$by_model" "$by_type"
}
