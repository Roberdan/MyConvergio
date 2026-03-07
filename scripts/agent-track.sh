#!/usr/bin/env bash
set -euo pipefail
# agent-track.sh — Lightweight agent activity tracker for brain visualization
# Usage: agent-track.sh start|complete|list|stats (see case branches below)
# Standalone — no dependency on plan-db.sh being in PATH.

DB="${PLAN_DB:-$HOME/.claude/data/dashboard.db}"
_esc() { printf '%s' "${1//\'/\'\'}"; }

case "${1:-}" in
  start) # <id> <type> <desc> [--task N] [--plan N] [--model M] [--host H] [--parent S]
    shift; [[ $# -lt 3 ]] && { echo "Usage: agent-track.sh start <id> <type> <desc>" >&2; exit 2; }
    AID="$1"; shift; TYPE="$1"; shift; DESC="$1"; shift
    TID="" PID="" MDL="" HOST="$(hostname -s)" PSESS=""
    while [[ $# -gt 0 ]]; do case "$1" in
      --task) TID="$2"; shift 2;; --plan) PID="$2"; shift 2;;
      --model) MDL="$2"; shift 2;; --host) HOST="$2"; shift 2;;
      --parent) PSESS="$2"; shift 2;; *) shift;; esac; done
    TV="${TID:+$TID}"; TV="${TV:-NULL}"; PV="${PID:+$PID}"; PV="${PV:-NULL}"
    PSV="${PSESS:+'$(_esc "$PSESS")'}"; PSV="${PSV:-NULL}"
    sqlite3 "$DB" "INSERT INTO agent_activity (agent_id,agent_type,description,task_db_id,plan_id,model,host,status,parent_session) \
      VALUES ('$(_esc "$AID")','$(_esc "$TYPE")','$(_esc "$DESC")',$TV,$PV,'$(_esc "${MDL:-unknown}")','$(_esc "$HOST")','running',$PSV);"
    echo "{\"ok\":true,\"agent_id\":\"$AID\"}" ;;

  complete) # <agent_id> [--tokens-in N] [--tokens-out N] [--cost N] [--status S]
    shift; [[ $# -lt 1 ]] && { echo "Usage: agent-track.sh complete <id>" >&2; exit 2; }
    AID="$1"; shift; ST="completed" TIN=0 TOUT=0 COST=0
    while [[ $# -gt 0 ]]; do case "$1" in
      --status) ST="$2"; shift 2;; --tokens-in) TIN="$2"; shift 2;;
      --tokens-out) TOUT="$2"; shift 2;; --cost) COST="$2"; shift 2;; *) shift;; esac; done
    sqlite3 "$DB" "UPDATE agent_activity SET status='$ST',completed_at=datetime('now'), \
      tokens_in=$TIN,tokens_out=$TOUT,tokens_total=$TIN+$TOUT,cost_usd=$COST, \
      duration_s=CAST((julianday('now')-julianday(started_at))*86400 AS REAL) \
      WHERE agent_id='$(_esc "$AID")' AND status='running';"
    sqlite3 "$DB" "UPDATE tasks SET tokens_total=tokens_total+$TIN+$TOUT,cost_usd=cost_usd+$COST, \
      agent_count=agent_count+1 WHERE id=(SELECT task_db_id FROM agent_activity \
      WHERE agent_id='$(_esc "$AID")' AND task_db_id IS NOT NULL);" 2>/dev/null || true
    echo "{\"ok\":true,\"agent_id\":\"$AID\",\"status\":\"$ST\"}" ;;

  list) # [--running] [--plan N]
    shift; F="1=1"
    while [[ $# -gt 0 ]]; do case "$1" in
      --running) F="$F AND status='running'"; shift;; --plan) F="$F AND plan_id=$2"; shift 2;; *) shift;; esac; done
    sqlite3 -json "$DB" "SELECT agent_id,agent_type,status,model,description,started_at,duration_s \
      FROM agent_activity WHERE $F ORDER BY started_at DESC LIMIT 50;" ;;

  stats) # [--plan N]
    shift; PF=""; [[ "${1:-}" == "--plan" ]] && PF="WHERE plan_id=$2"
    sqlite3 -json "$DB" "SELECT COUNT(*) as total, \
      SUM(CASE WHEN status='running' THEN 1 ELSE 0 END) as running, \
      SUM(tokens_total) as tokens,ROUND(SUM(cost_usd),4) as cost FROM agent_activity $PF;" ;;

  *) echo "Usage: agent-track.sh start|complete|list|stats" >&2; exit 2;;
esac
