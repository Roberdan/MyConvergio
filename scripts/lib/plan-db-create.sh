#!/bin/bash
# Plan DB CREATE operations

_require_opt_value() {
local opt="$1"
local val="${2:-}"
[[ -n "$val" ]] && return 0
log_error "Missing $opt value"
set -u
exit 1
}

cmd_create() {
local project_id="$1" name="$2"
shift 2
local is_master=0 parent_id="NULL"
local source_file="" markdown_path="" worktree_path="" auto_worktree=0 description="" human_summary=""
set +u
while [[ $# -gt 0 ]]; do
case "$1" in
--source-file) source_file="$2"; shift 2 ;;
--markdown-path) markdown_path="$2"; shift 2 ;;
--worktree-path) worktree_path="$2"; shift 2 ;;
--auto-worktree)
auto_worktree=1
log_warn "--auto-worktree is deprecated. Use wave-level worktrees (default in new plans). Plan-level worktree created for backward compatibility."
shift ;;
--wave-worktrees) shift ;;
--description) description="$2"; shift 2 ;;
--human-summary) human_summary="$2"; shift 2 ;;
*) shift ;;
esac
done
set -u

local safe_project_id="$(sql_escape "$project_id")"
local safe_name="$(sql_escape "$name")"
[[ "$name" == *"-Main"* || "$name" == *"-Master"* ]] && is_master=1
if [[ $is_master -eq 0 ]]; then
local base_name="${name%%-Phase*}"
base_name="${base_name%%-[0-9]*}"
local master_id
master_id=$(sqlite3 "$DB_FILE" "SELECT id FROM plans WHERE project_id='$safe_project_id' AND name LIKE '$(sql_escape "$base_name")%' AND is_master=1 LIMIT 1;")
[[ -n "$master_id" ]] && parent_id="$master_id"
fi
if [[ -z "$description" && -n "$source_file" && -f "$source_file" ]]; then
description=$(grep -v '^\s*#' "$source_file" | grep -v '^\s*//' | grep -v '^\s*$' | head -1 | cut -c1-200)
fi

local sf_val="NULL" mp_val="NULL" md_val="NULL" wp_val="NULL" desc_val="NULL" hs_val="NULL"
[[ -n "$source_file" ]] && sf_val="'$(sql_escape "$source_file")'"
if [[ -n "$markdown_path" ]]; then
mp_val="'$(sql_escape "$markdown_path")'"
md_val="'$(sql_escape "$(dirname "$markdown_path")")'"
fi
[[ -n "$worktree_path" ]] && wp_val="'$(sql_escape "$(_normalize_path "$worktree_path")")'"
[[ -n "$description" ]] && desc_val="'$(sql_escape "$description")'"
[[ -n "$human_summary" ]] && hs_val="'$(sql_escape "$human_summary")'"

sqlite3 "$DB_FILE" "INSERT INTO plans (project_id, name, is_master, parent_plan_id, status, source_file, markdown_path, markdown_dir, worktree_path, description, human_summary) VALUES ('$safe_project_id', '$safe_name', $is_master, $parent_id, 'todo', $sf_val, $mp_val, $md_val, $wp_val, $desc_val, $hs_val);"
local plan_id
plan_id=$(sqlite3 "$DB_FILE" "SELECT id FROM plans WHERE project_id='$safe_project_id' AND name='$safe_name';")
sqlite3 "$DB_FILE" "INSERT INTO plan_versions (plan_id, version, change_type, change_reason, changed_by) VALUES ($plan_id, 1, 'created', 'Plan created', 'planner');"
log_info "Created plan: $name (ID: $plan_id)"

if [[ "$auto_worktree" -eq 1 ]]; then
local project_path
project_path=$(_expand_path "$(sqlite3 "$DB_FILE" "SELECT path FROM projects WHERE id='$safe_project_id';")")
[[ -z "$project_path" ]] && project_path=$(pwd)
local repo_name plan_slug wt_branch wt_path
repo_name=$(basename "$project_path")
plan_slug=$(echo "$name" | tr '[:upper:]' '[:lower:]' | sed 's/[^a-z0-9]/-/g' | sed 's/--*/-/g' | sed 's/-$//')
wt_branch="plan/${plan_id}-${plan_slug}"
wt_path="${project_path}/../${repo_name}-plan-${plan_id}"
(cd "$project_path" && "$SCRIPT_DIR/worktree-create.sh" "$wt_branch" "$wt_path") >&2
cmd_set_worktree "$plan_id" "$wt_path"
if [[ -z "$markdown_path" ]]; then
local plans_dir norm_mp norm_md
plans_dir="${HOME}/.claude/plans/${safe_project_id}"
mkdir -p "$plans_dir"
markdown_path="$plans_dir/${name}-Main.md"
norm_mp=$(_normalize_path "$markdown_path")
norm_md=$(_normalize_path "$plans_dir")
sqlite3 "$DB_FILE" "UPDATE plans SET markdown_path='$(sql_escape "$norm_mp")', markdown_dir='$(sql_escape "$norm_md")' WHERE id=$plan_id;"
log_info "Auto-set markdown: $markdown_path"
fi
fi
echo "$plan_id"
}

cmd_add_wave() {
local plan_id="$1" wave_id="$2" name="$3"
shift 3
local assignee="" planned_start="" planned_end="" estimated_hours="8" depends_on="" precondition="" merge_mode="sync" theme=""
set +u
while [[ $# -gt 0 ]]; do
case "$1" in
--merge-mode) _require_opt_value --merge-mode "${2:-}"; merge_mode="$2"; shift 2 ;;
--theme) _require_opt_value --theme "${2:-}"; theme="$2"; shift 2 ;;
--assignee) _require_opt_value --assignee "${2:-}"; assignee="$2"; shift 2 ;;
--planned-start) _require_opt_value --planned-start "${2:-}"; planned_start="$2"; shift 2 ;;
--planned-end) _require_opt_value --planned-end "${2:-}"; planned_end="$2"; shift 2 ;;
--estimated-hours) _require_opt_value --estimated-hours "${2:-}"; estimated_hours="$2"; shift 2 ;;
--depends-on) _require_opt_value --depends-on "${2:-}"; depends_on="$2"; shift 2 ;;
--precondition) _require_opt_value --precondition "${2:-}"; precondition="$2"; shift 2 ;;
*) assignee="$1"; shift ;;
esac
done
set -u

local project_id position
project_id=$(sqlite3 "$DB_FILE" "SELECT project_id FROM plans WHERE id = $plan_id;")
position=$(sqlite3 "$DB_FILE" "SELECT COALESCE(MAX(position), 0) + 1 FROM waves WHERE plan_id = $plan_id;")
local start_val="NULL" end_val="NULL" depends_val="NULL" precond_val="NULL" theme_val="NULL"
[[ -n "$planned_start" ]] && start_val="'$(sql_escape "$planned_start")'"
[[ -n "$planned_end" ]] && end_val="'$(sql_escape "$planned_end")'"
[[ -n "$depends_on" ]] && depends_val="'$(sql_escape "$depends_on")'"
[[ -n "$precondition" ]] && precond_val="'$(sql_escape "$precondition")'"
[[ -n "$theme" ]] && theme_val="'$(sql_escape "$theme")'"
local safe_wave_id="$(sql_escape "$wave_id")" safe_name="$(sql_escape "$name")" safe_assignee="$(sql_escape "$assignee")" safe_merge_mode="$(sql_escape "$merge_mode")"
sqlite3 "$DB_FILE" "INSERT INTO waves (project_id, plan_id, wave_id, name, status, assignee, position, estimated_hours, planned_start, planned_end, depends_on, precondition, merge_mode, theme) VALUES ('$project_id', $plan_id, '$safe_wave_id', '$safe_name', 'pending', '$safe_assignee', $position, $estimated_hours, $start_val, $end_val, $depends_val, $precond_val, '$safe_merge_mode', $theme_val);"
local db_wave_id
db_wave_id=$(sqlite3 "$DB_FILE" "SELECT id FROM waves WHERE plan_id=$plan_id AND wave_id='$safe_wave_id';")
log_info "Added wave: $name (ID: $db_wave_id)"
echo "$db_wave_id"
}

cmd_add_task() {
local db_wave_id="$1" task_id="$2" title="$3"
shift 3
local priority="P1" type="feature" assignee="" test_criteria="" model="sonnet" description="" executor_agent="" effort_level="1"
set +u
while [[ $# -gt 0 ]]; do
case "$1" in
--test-criteria) _require_opt_value --test-criteria "${2:-}"; test_criteria="$2"; shift 2 ;;
--model) _require_opt_value --model "${2:-}"; model="$2"; shift 2 ;;
--effort) _require_opt_value "--effort (1/2/3)" "${2:-}"; effort_level="$2"; shift 2 ;;
--description) _require_opt_value --description "${2:-}"; description="$2"; shift 2 ;;
--executor-agent) _require_opt_value --executor-agent "${2:-}"; executor_agent="$2"; shift 2 ;;
P0|P1|P2|P3) priority="$1"; shift ;;
bug|feature|chore|doc|test) type="$1"; shift ;;
haiku|sonnet|opus) model="$1"; shift ;;
*) [[ -z "$assignee" ]] && assignee="$1"; shift ;;
esac
done
set -u

local project_id wave_id_text plan_id
IFS='|' read -r project_id wave_id_text plan_id < <(sqlite3 "$DB_FILE" "SELECT project_id, wave_id, plan_id FROM waves WHERE id = $db_wave_id;")
local safe_task_id="$(sql_escape "$task_id")" safe_title="$(sql_escape "$title")" safe_priority="$(sql_escape "$priority")" safe_type="$(sql_escape "$type")" safe_assignee="$(sql_escape "$assignee")"
local safe_test_criteria="$(sql_escape "$test_criteria")" safe_model="$(sql_escape "$model")" safe_description="$(sql_escape "$description")" safe_executor_agent="$(sql_escape "$executor_agent")"
local tc_val="NULL" desc_val="NULL" exec_agent_val="NULL"
[[ -n "$test_criteria" ]] && tc_val="'$safe_test_criteria'"
[[ -n "$description" ]] && desc_val="'$safe_description'"
[[ -n "$executor_agent" ]] && exec_agent_val="'$safe_executor_agent'"

sqlite3 "$DB_FILE" "ALTER TABLE tasks ADD COLUMN effort_level INTEGER DEFAULT 1 CHECK(effort_level IN (1, 2, 3));" 2>/dev/null || true
sqlite3 "$DB_FILE" <<SQL
BEGIN TRANSACTION;
INSERT INTO tasks (project_id, wave_id, wave_id_fk, plan_id, task_id, title, description, status, priority, type, assignee, test_criteria, model, executor_agent, effort_level)
VALUES ('$project_id', '$wave_id_text', $db_wave_id, $plan_id, '$safe_task_id', '$safe_title', COALESCE($desc_val, '$safe_title'), 'pending', '$safe_priority', '$safe_type', '$safe_assignee', $tc_val, '$safe_model', $exec_agent_val, $effort_level);
UPDATE waves SET tasks_total = tasks_total + 1 WHERE id = $db_wave_id;
UPDATE plans SET tasks_total = tasks_total + 1 WHERE id = $plan_id;
COMMIT;
SQL
local db_task_id
db_task_id=$(sqlite3 "$DB_FILE" "SELECT id FROM tasks WHERE plan_id=$plan_id AND wave_id_fk=$db_wave_id AND task_id='$safe_task_id' ORDER BY id DESC LIMIT 1;")
log_info "Added task: $title (ID: $db_task_id)"
echo "$db_task_id"
}
