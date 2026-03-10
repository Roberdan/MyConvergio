#!/usr/bin/env bash
# delegate-utils.sh — Utility functions for worker scripts
# Auto-generated stub for missing functions

_DU_DB="${PLAN_DB_FILE:-${DB_FILE:-$HOME/.claude/data/dashboard.db}}"
_DU_SCRIPTS="${SCRIPT_DIR:-$HOME/.claude/scripts}"

safe_update_task() {
    local task_id="$1" status="$2"
    shift 2
    local notes="" tokens="" output_data=""
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --tokens) tokens="$2"; shift 2 ;;
            --output-data) output_data="$2"; shift 2 ;;
            *) notes="${notes:+$notes }$1"; shift ;;
        esac
    done
    if [[ "$status" == "done" ]]; then
        "${_DU_SCRIPTS}/plan-db-safe.sh" update-task "$task_id" done "$notes" \
            ${output_data:+--output-data "$output_data"} 2>/dev/null || \
        sqlite3 "$_DU_DB" "UPDATE tasks SET status='submitted', notes='$notes', tokens=${tokens:-0} WHERE id=$task_id;"
    else
        sqlite3 "$_DU_DB" "UPDATE tasks SET status='$status', notes='$notes', tokens=${tokens:-0} WHERE id=$task_id;" 2>/dev/null
    fi
}

verify_work_done() {
    local wt="${1:-.}"
    [[ -d "$wt" ]] || return 1
    local changes
    changes="$(git -C "$wt" status --porcelain 2>/dev/null)"
    [[ -n "$changes" ]]
}

log_delegation() {
    local task_id="${1:-}" plan_id="${2:-}" project_id="${3:-}" agent="${4:-}" model="${5:-}"
    local prompt_tokens="${6:-0}" output_tokens="${7:-0}" duration_ms="${8:-0}" exit_code="${9:-0}"
    local thor_result="${10:-UNKNOWN}" retry="${11:-0}" status="${12:-unknown}"
    sqlite3 "$_DU_DB" "
        INSERT OR IGNORE INTO delegation_log (task_id, plan_id, project_id, agent, model, prompt_tokens, output_tokens, duration_ms, exit_code, thor_result, retry_count, status, created_at)
        VALUES ('$task_id', $plan_id, '$project_id', '$agent', '$model', $prompt_tokens, $output_tokens, $duration_ms, $exit_code, '$thor_result', $retry, '$status', datetime('now'));
    " 2>/dev/null || true
}
