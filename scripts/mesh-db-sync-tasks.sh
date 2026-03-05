#!/usr/bin/env bash
# mesh-db-sync-tasks.sh — Sync task/plan statuses from remote peers to local DB
# Run periodically (e.g., every 60s) to keep dashboard current
set -euo pipefail

CLAUDE_HOME="${CLAUDE_HOME:-$HOME/.claude}"
DB="${CLAUDE_HOME}/data/dashboard.db"
PEERS_CONF="${CLAUDE_HOME}/config/peers.conf"
SSH_OPTS="-o ConnectTimeout=5 -o BatchMode=yes -o StrictHostKeyChecking=accept-new"

# Find active plans on remote hosts
active_plans=$(sqlite3 "$DB" ".timeout 3000" \
  "SELECT id, execution_host FROM plans WHERE status='doing' AND execution_host <> '' AND execution_host <> '$(hostname -s)';" 2>/dev/null || echo "")

[[ -z "$active_plans" ]] && exit 0

# For each remote plan, sync task statuses
while IFS='|' read -r plan_id exec_host; do
  [[ -z "$plan_id" ]] && continue
  
  # Find SSH destination from peers.conf
  dest=""
  if [[ -f "$PEERS_CONF" ]]; then
    while IFS= read -r line; do
      [[ "$line" =~ ^\[.*\]$ ]] && section="${line//[\[\]]/}" && continue
      [[ "$line" =~ ^ssh_alias=(.+)$ ]] && ssh_alias="${BASH_REMATCH[1]}" && continue
      [[ "$line" =~ ^user=(.+)$ ]] && continue
    done < "$PEERS_CONF"
  fi
  
  # Try all known peers to find the right host
  for peer_ssh in $(awk -F= '/^ssh_alias=/{print $2}' "$PEERS_CONF" 2>/dev/null); do
    remote_host=$(ssh $SSH_OPTS "$peer_ssh" "hostname -s" 2>/dev/null || echo "")
    if [[ "$remote_host" == "$exec_host" ]] || [[ "$remote_host" == "${exec_host%%.*}" ]]; then
      dest="$peer_ssh"
      break
    fi
  done
  
  [[ -z "$dest" ]] && continue
  
  # Pull task statuses from remote
  remote_tasks=$(ssh $SSH_OPTS "$dest" \
    "sqlite3 ~/.claude/data/dashboard.db '.timeout 3000' \
     \"SELECT id, status, validated_by FROM tasks WHERE plan_id=${plan_id} AND status NOT IN ('pending');\"" \
    2>/dev/null || echo "")
  
  [[ -z "$remote_tasks" ]] && continue
  
  # Apply to local DB
  while IFS='|' read -r task_db_id task_status task_validated; do
    [[ -z "$task_db_id" ]] && continue
    local_status=$(sqlite3 "$DB" ".timeout 3000" \
      "SELECT status FROM tasks WHERE id=${task_db_id};" 2>/dev/null || echo "")
    
    [[ "$local_status" == "$task_status" ]] && continue
    
    if [[ "$task_status" == "done" ]]; then
      # Must go through submitted first, then done with validated_by
      sqlite3 "$DB" ".timeout 3000" \
        "UPDATE tasks SET status='submitted' WHERE id=${task_db_id} AND status NOT IN ('submitted','done');" 2>/dev/null || true
      sqlite3 "$DB" ".timeout 3000" \
        "UPDATE tasks SET status='done', validated_by='${task_validated:-forced-admin}' WHERE id=${task_db_id} AND status='submitted';" 2>/dev/null || true
    else
      sqlite3 "$DB" ".timeout 3000" \
        "UPDATE tasks SET status='${task_status}' WHERE id=${task_db_id};" 2>/dev/null || true
    fi
  done <<< "$remote_tasks"
  
done <<< "$active_plans"
