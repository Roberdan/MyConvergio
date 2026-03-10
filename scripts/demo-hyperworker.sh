#!/usr/bin/env bash
# demo-hyperworker.sh — Simulates realistic task execution for hyperDemo plans
# Progresses tasks: pending → in_progress → submitted → done (Thor validated)
set -euo pipefail

DB="${HOME}/.claude/data/dashboard.db"
HOSTS=("m3max" "omarchy" "m1mario")
MODELS=("gpt-5-mini")

log() { echo "[$(date +%H:%M:%S)] $*"; }
rand() { echo $(( RANDOM % ($2 - $1 + 1) + $1 )); }
pick() { local arr=("$@"); echo "${arr[RANDOM % ${#arr[@]}]}"; }

# SQLite with WAL mode and retry to avoid locking
sq() { sqlite3 "$DB" ".timeout 5000" "$1" 2>/dev/null || true; }

update_plan_counters() {
  sq "UPDATE plans SET
    tasks_done = (SELECT COUNT(*) FROM tasks WHERE plan_id=$1 AND status='done')
  WHERE id=$1;"
}

TASK_CTR=0
complete_task() {
  local task_id=$1 plan_id=$2
  local tokens=$(rand 5000 45000)
  local lines=$(rand 20 350)
  local duration=$(rand 30 600)
  local model=$(pick "${MODELS[@]}")
  # Round-robin host distribution
  local host="${HOSTS[$((TASK_CTR % 3))]}"
  TASK_CTR=$((TASK_CTR + 1))

  log "  Task $task_id → in_progress ($host/$model)"
  sq "UPDATE tasks SET status='in_progress', started_at=datetime('now'),
    executor_host='$host', model='$model'
    WHERE id=$task_id;"

  # Also update the plan's execution host to match the current task's host
  sq "UPDATE plans SET execution_host='$host' WHERE id=$plan_id;"

  sleep $(rand 4 10)

  log "  Task $task_id → submitted (${lines}L, ${tokens}tok)"
  sq "UPDATE tasks SET status='submitted',
    tokens=$tokens,
    output_data=json_object('summary','Done','lines_added',$lines,'lines_removed',$(rand 0 50),'files_changed',$(rand 1 8),'duration_s',$duration)
    WHERE id=$task_id;"

  sleep $(rand 2 5)

  log "  Task $task_id → done ✓"
  sq "UPDATE tasks SET status='done', completed_at=datetime('now'),
    validated_at=datetime('now'), validated_by='thor'
    WHERE id=$task_id;"

  update_plan_counters "$plan_id"
}

process_wave() {
  local plan_id=$1 wave=$2
  local tasks
  tasks=$(sq "SELECT id FROM tasks WHERE plan_id=$plan_id AND wave_id='$wave' AND status IN ('pending','in_progress') ORDER BY RANDOM();")
  [ -z "$tasks" ] && return
  log "Plan $plan_id / $wave — $(echo "$tasks" | wc -l | tr -d ' ') tasks"
  for tid in $tasks; do
    complete_task "$tid" "$plan_id" &
  done
  wait
}

main() {
  log "🚀 HyperDemo Worker starting..."

  # Enable WAL mode for concurrent access
  sq "PRAGMA journal_mode=WAL;"

  local plan_ids
  plan_ids=$(sq "SELECT id FROM plans WHERE project_id='hyperDemo' AND status='doing' ORDER BY id;")
  [ -z "$plan_ids" ] && { log "No active plans"; exit 0; }

  # Process in staggered batches of 5 plans — more realistic pacing
  local batch_size=5
  local plan_arr=($plan_ids)
  local total=${#plan_arr[@]}

  for wave in W1; do
    log "━━━ $wave across $total plans ━━━"
    local i=0
    while [ $i -lt $total ]; do
      local end=$((i + batch_size))
      [ $end -gt $total ] && end=$total
      log "  Batch $((i/batch_size + 1)): plans ${plan_arr[$i]}..${plan_arr[$((end-1))]}"
      for j in $(seq $i $((end - 1))); do
        process_wave "${plan_arr[$j]}" "$wave" &
      done
      wait
      i=$end
      sleep 3
    done
    log "✓ $wave complete"
  done

  # Complete plans one by one with small delay
  for pid in $plan_ids; do
    local rem=$(sq "SELECT COUNT(*) FROM tasks WHERE plan_id=$pid AND status!='done';")
    if [ "${rem:-0}" -eq 0 ]; then
      sq "UPDATE plans SET status='done', completed_at=datetime('now'), updated_at=datetime('now') WHERE id=$pid;"
      log "✓ Plan $pid COMPLETE"
      sleep 1
    fi
  done

  log "🏁 Done!"
}

main "$@"
