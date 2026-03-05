#!/usr/bin/env bash
# mesh-cleanup.sh — Detect and kill orphan AI agent processes on mesh nodes.
# Version: 2.0.0
# Usage: mesh-cleanup.sh [--peer <name>] [--all] [--plan <id>] [--dry-run] [--reset-stale]
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CLAUDE_HOME="${CLAUDE_HOME:-$HOME/.claude}"
DB="${CLAUDE_DB:-$CLAUDE_HOME/data/dashboard.db}"

source "$SCRIPT_DIR/lib/peers.sh"

C='\033[0;36m' G='\033[0;32m' Y='\033[1;33m' R='\033[0;31m' N='\033[0m'
info()  { echo -e "${C}[cleanup]${N} $*"; }
ok()    { echo -e "${G}[cleanup]${N} $*"; }
warn()  { echo -e "${Y}[cleanup]${N} $*" >&2; }
err()   { echo -e "${R}[cleanup]${N} $*" >&2; }

DRY_RUN=false
TARGET_PEER=""
ALL_PEERS=false
RESET_STALE=false
PLAN_ID=""
MAX_AGE_MIN=10
JSON_OUTPUT=false

usage() {
  cat >&2 <<'EOF'
Usage: mesh-cleanup.sh [OPTIONS]

Detect and kill orphan AI agent processes. Three modes:
  1. Orphan scan: find processes with no active DB task (default)
  2. Dedup: kill duplicate processes for same task (always on)
  3. Plan nuke: kill ALL processes for a specific plan (--plan)

Options:
  --peer <name>    Target a specific peer (default: local)
  --all            Clean all active peers
  --plan <id>      Kill ALL processes for this plan (nuke mode)
  --dry-run        Report without killing
  --reset-stale    Reset stale in_progress tasks to pending
  --max-age <min>  Orphan age threshold in minutes (default: 10)
  --json           Output JSON summary
  --help           Show this help
EOF
  exit 1
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --peer)        TARGET_PEER="${2:-}"; shift 2 ;;
    --all)         ALL_PEERS=true; shift ;;
    --plan)        PLAN_ID="${2:-}"; shift 2 ;;
    --dry-run)     DRY_RUN=true; shift ;;
    --reset-stale) RESET_STALE=true; shift ;;
    --max-age)     MAX_AGE_MIN="${2:-10}"; shift 2 ;;
    --json)        JSON_OUTPUT=true; shift ;;
    --help|-h)     usage ;;
    *)             shift ;;
  esac
done

_db() { sqlite3 "$DB" "$@" 2>/dev/null; }

_active_plan_ids() {
  _db "SELECT DISTINCT plan_id FROM tasks WHERE status='in_progress';" | sort -u
}

_ssh_cmd() {
  local peer="$1" cmd="$2"
  local ssh_dest
  ssh_dest="$(peers_get "$peer" ssh_alias 2>/dev/null || echo "$peer")"
  ssh -o ConnectTimeout=5 -o BatchMode=yes -o StrictHostKeyChecking=accept-new \
    "$ssh_dest" "$cmd" 2>/dev/null
}

# Convert ps etime (DD-HH:MM:SS / HH:MM:SS / MM:SS) to minutes
_etime_to_minutes() {
  local et="$1" days=0 hours=0 mins=0
  if [[ "$et" == *-* ]]; then
    days="${et%%-*}"; et="${et#*-}"
  fi
  IFS=: read -ra parts <<< "$et"
  case ${#parts[@]} in
    3) hours="${parts[0]}"; mins="${parts[1]}" ;;
    2) mins="${parts[0]}" ;;
    1) mins=0 ;;
  esac
  days=$((10#$days)); hours=$((10#$hours)); mins=$((10#$mins))
  echo $(( days * 1440 + hours * 60 + mins ))
}

# Grep pattern for executor-spawned processes
_proc_pattern() {
  echo '(execute-plan\.sh|copilot-worker\.sh|delegate\.sh|claude.*(-p |--dangerously)|copilot.*-p |gh copilot.*-p )'
}

# Extract plan ID from a command string
_extract_plan_id() {
  local cmd="$1"
  if [[ "$cmd" =~ execute-plan\.sh[[:space:]]+([0-9]+) ]]; then
    echo "${BASH_REMATCH[1]}"
  elif [[ "$cmd" =~ /execute[[:space:]]+([0-9]+) ]]; then
    echo "${BASH_REMATCH[1]}"
  elif [[ "$cmd" =~ plan-([0-9]+) ]]; then
    echo "${BASH_REMATCH[1]}"
  elif [[ "$cmd" =~ update-task[[:space:]]+([0-9]+) ]]; then
    echo "task:${BASH_REMATCH[1]}"
  elif [[ "$cmd" =~ copilot-worker\.sh[[:space:]]+([0-9]+) ]]; then
    echo "task:${BASH_REMATCH[1]}"
  fi
}

# ============================================================================
# Remote cleanup — single SSH call with all logic embedded
# ============================================================================
_cleanup_remote() {
  local peer="$1"
  info "Scanning $peer via SSH..."

  local plan_filter=""
  [[ -n "$PLAN_ID" ]] && plan_filter="$PLAN_ID"

  # Build remote script: collect procs + DB state, return structured output
  local remote_script
  remote_script="$(cat <<REMOTE_EOF
export PATH="/opt/homebrew/bin:/usr/local/bin:\$HOME/.local/bin:\$HOME/.claude/scripts:\$PATH"
DB="\$HOME/.claude/data/dashboard.db"

# Counts before
total_ai=\$(ps aux | grep -cE '(claude|copilot)' || echo 0)
echo "===META==="
echo "total_ai_procs:\$total_ai"

echo "===PROCS==="
ps -eo pid,etime,command 2>/dev/null | grep -E '(execute-plan|copilot-worker|delegate\.sh|claude.*-p|copilot.*-p|gh copilot.*-p)' | grep -vE '(mesh-cleanup|mesh-heartbeat|grep|ps -eo)' || true

echo "===ACTIVE==="
sqlite3 "\$DB" "SELECT DISTINCT plan_id FROM tasks WHERE status='in_progress';" 2>/dev/null || true

echo "===STALE==="
sqlite3 "\$DB" "SELECT id,plan_id,task_id FROM tasks WHERE status='in_progress' AND (executor_last_activity IS NULL OR executor_last_activity < datetime('now','-30 minutes'));" 2>/dev/null || true

echo "===DEDUP==="
# Find task_ids with >1 running process (retried zombies)
ps -eo pid,command 2>/dev/null | grep -oE 'update-task [0-9]+' | awk '{print \$2}' | sort | uniq -c | awk '\$1>1{print \$2}' || true
ps -eo pid,command 2>/dev/null | grep -oE 'copilot-worker\.sh [0-9]+' | awk '{print \$2}' | sort | uniq -c | awk '\$1>1{print \$2}' || true
REMOTE_EOF
)"

  local output
  output="$(_ssh_cmd "$peer" "$remote_script")" || {
    err "Cannot reach $peer via SSH"; return
  }

  local section="" total_ai=0
  local proc_lines=() active_plans=() stale_tasks=() dedup_tasks=()

  while IFS= read -r line; do
    case "$line" in
      "===META===")   section="meta"; continue ;;
      "===PROCS===")  section="procs"; continue ;;
      "===ACTIVE===") section="active"; continue ;;
      "===STALE===")  section="stale"; continue ;;
      "===DEDUP===")  section="dedup"; continue ;;
    esac
    case "$section" in
      meta) [[ "$line" == total_ai_procs:* ]] && total_ai="${line#*:}" ;;
      procs) [[ -n "$line" ]] && proc_lines+=("$line") ;;
      active) [[ -n "$line" ]] && active_plans+=("$line") ;;
      stale) [[ -n "$line" ]] && stale_tasks+=("$line") ;;
      dedup) [[ -n "$line" ]] && dedup_tasks+=("$line") ;;
    esac
  done <<< "$output"

  info "$peer: ${#proc_lines[@]} executor procs, $total_ai total AI procs"

  # Collect PIDs to kill
  local kill_pids=()
  local found=0 killed=0 stale_reset=0

  for line in "${proc_lines[@]}"; do
    [[ -z "$line" ]] && continue
    local pid etime cmd
    pid="$(echo "$line" | awk '{print $1}')"
    etime="$(echo "$line" | awk '{print $2}')"
    cmd="$(echo "$line" | awk '{$1=""; $2=""; print}' | sed 's/^ *//')"

    local age_min
    age_min=$(_etime_to_minutes "$etime")

    local extracted_plan
    extracted_plan="$(_extract_plan_id "$cmd")"

    # Plan nuke mode: kill everything matching this plan
    if [[ -n "$plan_filter" ]]; then
      if [[ "$extracted_plan" == "$plan_filter" || "$cmd" == *"plan-${plan_filter}"* || "$cmd" == *"plan/${plan_filter}"* ]]; then
        ((found++)) || true
        kill_pids+=("$pid")
        $DRY_RUN && warn "NUKE [dry-run]: PID=$pid age=${age_min}m cmd=$(echo "$cmd" | cut -c1-80)"
        continue
      fi
      continue  # skip non-matching in nuke mode
    fi

    # Normal mode: age-based orphan detection
    [[ "$age_min" -lt "$MAX_AGE_MIN" ]] && continue

    local is_orphan=true
    if [[ -n "$extracted_plan" && "$extracted_plan" != task:* ]]; then
      for ap in "${active_plans[@]}"; do
        [[ "$ap" == "$extracted_plan" ]] && { is_orphan=false; break; }
      done
    fi

    if $is_orphan; then
      ((found++)) || true
      kill_pids+=("$pid")
      $DRY_RUN && warn "ORPHAN [dry-run]: PID=$pid age=${age_min}m plan=${extracted_plan:-?} cmd=$(echo "$cmd" | cut -c1-80)"
    fi
  done

  # Report
  if [[ ${#kill_pids[@]} -eq 0 ]]; then
    ok "$peer: Clean — no orphans"
  elif $DRY_RUN; then
    warn "$peer: Found ${#kill_pids[@]} process(es) to kill — dry-run"
  else
    # Kill remotely: SIGSTOP first (freeze to prevent respawn), then SIGKILL
    local pids_str="${kill_pids[*]}"
    local kill_script="
PIDS=\"$pids_str\"
for p in \$PIDS; do kill -STOP \$p 2>/dev/null; done
sleep 0.5
ALL=\$(ps -eo pid,command | grep -E '(copilot|claude|execute-plan)' | grep -v grep | awk '{printf \"%s \", \$1}')
for p in \$ALL \$PIDS; do kill -STOP \$p 2>/dev/null; done
sleep 0.5
ALL2=\$(ps -eo pid,command | grep -E '(copilot|claude|execute-plan)' | grep -v grep | awk '{printf \"%s \", \$1}')
for p in \$ALL2 \$ALL \$PIDS; do kill -9 \$p 2>/dev/null; done
echo KILLED"
    _ssh_cmd "$peer" "$kill_script" >/dev/null || true
    killed=${#kill_pids[@]}
    ok "$peer: Killed $killed process(es) (SIGSTOP+SIGKILL)"
  fi

  # Reset stale tasks remotely
  if $RESET_STALE && [[ ${#stale_tasks[@]} -gt 0 ]]; then
    local ids=()
    for st in "${stale_tasks[@]}"; do
      ids+=("$(echo "$st" | cut -d'|' -f1)")
    done
    local id_list
    id_list="$(IFS=,; echo "${ids[*]}")"
    local sql="UPDATE tasks SET status='pending',executor_status=NULL,executor_session_id=NULL WHERE id IN ($id_list) AND status='in_progress';"
    _ssh_cmd "$peer" "sqlite3 \$HOME/.claude/data/dashboard.db \"$sql\"" >/dev/null || true
    stale_reset=${#ids[@]}
    ok "$peer: Reset $stale_reset stale task(s) to pending"
  fi

  $JSON_OUTPUT && printf '{"peer":"%s","found":%d,"killed":%d,"stale_reset":%d,"total_ai":%s}\n' \
    "$peer" "$found" "$killed" "$stale_reset" "$total_ai"
}

# ============================================================================
# Local cleanup
# ============================================================================
_cleanup_local() {
  info "Scanning local processes..."
  local tmpfile found=0 killed=0 stale_reset=0
  tmpfile=$(mktemp)

  ps -eo pid,ppid,etime,command 2>/dev/null | \
    grep -E '(execute-plan\.sh|copilot-worker\.sh|delegate\.sh|claude.*-p |copilot.*-p |claude.*--dangerously)' | \
    grep -vE '(mesh-cleanup|mesh-heartbeat|grep|ps -eo)' > "$tmpfile" || true

  local active_plans
  active_plans="$(_active_plan_ids)"
  local kill_pids=()

  while IFS= read -r line; do
    [[ -z "$line" ]] && continue
    local pid ppid etime cmd
    pid="$(echo "$line" | awk '{print $1}')"
    ppid="$(echo "$line" | awk '{print $2}')"
    etime="$(echo "$line" | awk '{print $3}')"
    cmd="$(echo "$line" | awk '{$1=""; $2=""; $3=""; print}' | sed 's/^ *//')"

    local age_min extracted_plan
    age_min=$(_etime_to_minutes "$etime")
    extracted_plan="$(_extract_plan_id "$cmd")"

    [[ "$ppid" == "$$" ]] && continue

    # Plan nuke mode
    if [[ -n "$PLAN_ID" ]]; then
      if [[ "$extracted_plan" == "$PLAN_ID" || "$cmd" == *"plan-${PLAN_ID}"* || "$cmd" == *"plan/${PLAN_ID}"* ]]; then
        ((found++)) || true; kill_pids+=("$pid")
        $DRY_RUN && warn "NUKE [dry-run]: PID=$pid age=${age_min}m cmd=$(echo "$cmd" | cut -c1-80)"
      fi
      continue
    fi

    # Age-based orphan detection
    [[ "$age_min" -lt "$MAX_AGE_MIN" ]] && continue

    local is_orphan=true
    if [[ -n "$extracted_plan" && "$extracted_plan" != task:* ]] && echo "$active_plans" | grep -qw "$extracted_plan"; then
      is_orphan=false
    elif [[ "$extracted_plan" == task:* ]]; then
      local tid="${extracted_plan#task:}"
      local ts; ts=$(_db "SELECT status FROM tasks WHERE id=$tid;")
      [[ "$ts" == "in_progress" ]] && is_orphan=false
    fi

    if $is_orphan; then
      ((found++)) || true; kill_pids+=("$pid")
      $DRY_RUN && warn "ORPHAN [dry-run]: PID=$pid age=${age_min}m plan=${extracted_plan:-?} cmd=$(echo "$cmd" | cut -c1-80)"
    fi
  done < "$tmpfile"
  rm -f "$tmpfile"

  if [[ ${#kill_pids[@]} -eq 0 ]]; then
    ok "No orphans found locally"
  elif $DRY_RUN; then
    warn "Found ${#kill_pids[@]} process(es) to kill — dry-run"
  else
    # SIGSTOP first to prevent respawn chains, then SIGKILL
    for p in "${kill_pids[@]}"; do
      kill -STOP "$p" 2>/dev/null || true
    done
    sleep 0.5
    for p in "${kill_pids[@]}"; do
      kill -9 "$p" 2>/dev/null && ((killed++)) || true
    done
    ok "Killed $killed/${#kill_pids[@]} process(es)"
  fi

  if $RESET_STALE; then
    stale_reset=$(_reset_stale_local)
  fi

  $JSON_OUTPUT && printf '{"peer":"local","found":%d,"killed":%d,"stale_reset":%d}\n' \
    "$found" "$killed" "$stale_reset"
}

_reset_stale_local() {
  local count
  count=$(_db "SELECT COUNT(*) FROM tasks WHERE status='in_progress' AND (executor_last_activity IS NULL OR executor_last_activity < datetime('now','-30 minutes'));")
  if [[ "${count:-0}" -gt 0 ]]; then
    _db "UPDATE tasks SET status='pending',executor_status=NULL,executor_session_id=NULL WHERE status='in_progress' AND (executor_last_activity IS NULL OR executor_last_activity < datetime('now','-30 minutes'));"
    ok "Reset $count stale task(s) to pending"
  fi
  echo "${count:-0}"
}

# ============================================================================
# Dispatch
# ============================================================================
_cleanup_host() {
  local peer="$1" self
  self="$(peers_self 2>/dev/null || echo "")"
  if [[ "$peer" == "$self" || "$peer" == "local" ]]; then
    _cleanup_local
  else
    _cleanup_remote "$peer"
  fi
}

peers_load 2>/dev/null || true

if $ALL_PEERS; then
  for p in $(peers_list 2>/dev/null); do
    _cleanup_host "$p"
  done
elif [[ -n "$TARGET_PEER" ]]; then
  _cleanup_host "$TARGET_PEER"
else
  _cleanup_host "local"
fi
