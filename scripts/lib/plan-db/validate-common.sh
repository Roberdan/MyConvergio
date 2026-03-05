#!/bin/bash
# Plan DB Validation - Common helpers and readiness gates
# Sourced by lib/plan-db-validate.sh

# Version: 1.0.0

# Validation counters shared by gate modules
thor_reset_validation_counters() {
THOR_VALIDATE_ERRORS=0
THOR_VALIDATE_WARNINGS=0
}

thor_add_validation_error() {
THOR_VALIDATE_ERRORS=$((THOR_VALIDATE_ERRORS + 1))
}

thor_add_validation_warning() {
THOR_VALIDATE_WARNINGS=$((THOR_VALIDATE_WARNINGS + 1))
}

thor_is_allowed_validator() {
local validator="$1"
echo "$validator" | grep -qE '^(thor|thor-quality-assurance-guardian|thor-per-wave)$'
}

thor_extract_report_arg() {
local prev=""
local arg
for arg in "$@"; do
if [[ "$prev" == "--report" ]]; then
echo "$arg"
return 0
fi
prev="$arg"
done
echo ""
}

thor_resolve_task_db_id() {
local identifier="$1"
local plan_id="${2:-}"
local task_db_id=""

if [[ "$identifier" =~ ^[0-9]+$ ]]; then
task_db_id=$(sqlite3 "$DB_FILE" "SELECT id FROM tasks WHERE id = $identifier;" 2>/dev/null || echo "")
fi

if [[ -z "$task_db_id" && -n "$plan_id" ]]; then
task_db_id=$(sqlite3 "$DB_FILE" "SELECT id FROM tasks WHERE task_id = '$(sql_escape "$identifier")' AND plan_id = $plan_id;" 2>/dev/null || echo "")
fi

echo "$task_db_id"
}

# Detect cycles in wave dependency graph (DFS 3-color)
# Usage: detect_precondition_cycles <plan_id>
# Returns 0 if no cycles, 1 if cycle found (prints path to stderr)
detect_precondition_cycles() {
local plan_id="$1"

local wave_data
wave_data=$(sqlite3 "$DB_FILE" \
"SELECT wave_id, COALESCE(depends_on,''), COALESCE(precondition,'') FROM waves WHERE plan_id = $plan_id ORDER BY position;" \
2>/dev/null) || true

[[ -z "$wave_data" ]] && return 0

local tmpdir
tmpdir=$(mktemp -d /tmp/cycle-detect-XXXXXX)
trap "rm -rf '$tmpdir'" EXIT INT TERM

local -a all_waves=()
while IFS='|' read -r wid depends_on precondition; do
all_waves+=("$wid")
local adj_file="$tmpdir/adj_${wid}"
touch "$adj_file"

if [[ -n "$depends_on" ]]; then
local dep
for dep in $(echo "$depends_on" | tr ',' ' '); do
dep=$(echo "$dep" | xargs)
[[ -n "$dep" ]] && echo "$dep" >>"$adj_file"
done
fi

if [[ -n "$precondition" && "$precondition" != "null" ]]; then
local json_deps
json_deps=$(echo "$precondition" |
jq -r '.[].wave_id // empty' 2>/dev/null) || true
if [[ -n "$json_deps" ]]; then
echo "$json_deps" >>"$adj_file"
fi
fi

if [[ -s "$adj_file" ]]; then
sort -u "$adj_file" -o "$adj_file"
fi
done <<<"$wave_data"

local wid
for wid in "${all_waves[@]}"; do
echo "0" >"$tmpdir/color_${wid}"
done

_dfs_visit() {
local node="$1"
local color_file="$tmpdir/color_${node}"

[[ ! -f "$color_file" ]] && return 0

local color
color=$(<"$color_file")
[[ "$color" == "2" ]] && return 0

if [[ "$color" == "1" ]]; then
local cycle_path=""
if [[ -f "$tmpdir/path" ]]; then
local in_cycle=0
while IFS= read -r p; do
if [[ "$p" == "$node" ]]; then
in_cycle=1
fi
if [[ $in_cycle -eq 1 ]]; then
[[ -n "$cycle_path" ]] && cycle_path="${cycle_path} -> "
cycle_path="${cycle_path}${p}"
fi
done <"$tmpdir/path"
cycle_path="${cycle_path} -> ${node}"
else
cycle_path="${node} -> ${node}"
fi
echo "CYCLE DETECTED: $cycle_path" >&2
return 1
fi

echo "1" >"$color_file"
echo "$node" >>"$tmpdir/path"

local adj_file="$tmpdir/adj_${node}"
if [[ -f "$adj_file" && -s "$adj_file" ]]; then
local neighbor
while IFS= read -r neighbor; do
[[ -z "$neighbor" ]] && continue
if ! _dfs_visit "$neighbor"; then
return 1
fi
done <"$adj_file"
fi

echo "2" >"$color_file"
if [[ -f "$tmpdir/path" ]]; then
local new_path
new_path=$(grep -v "^${node}$" "$tmpdir/path" 2>/dev/null) || true
echo "$new_path" >"$tmpdir/path"
fi

return 0
}

for wid in "${all_waves[@]}"; do
local color
color=$(<"$tmpdir/color_${wid}")
if [[ "$color" == "0" ]]; then
>"$tmpdir/path"
if ! _dfs_visit "$wid"; then
return 1
fi
fi
done

return 0
}

# Check plan readiness for execution (BLOCKS if metadata missing)
cmd_check_readiness() {
local plan_id="$1"
local errors=0
echo -e "${BLUE}======= READINESS CHECK - Plan $plan_id =======${NC}"

echo -e "${YELLOW}[0/N] Precondition cycle detection...${NC}"
if ! detect_precondition_cycles "$plan_id"; then
echo -e "${RED}  FAIL: Circular dependencies in wave preconditions${NC}"
errors=$((errors + 1))
else
echo -e "${GREEN}  OK: No cycles${NC}"
fi

local src wt
src=$(sqlite3 "$DB_FILE" "SELECT source_file FROM plans WHERE id=$plan_id;")
wt=$(sqlite3 "$DB_FILE" "SELECT worktree_path FROM plans WHERE id=$plan_id;")

if [[ -z "$src" ]]; then
echo -e "${RED}  FAIL: source_file not set${NC}"
errors=$((errors + 1))
else
echo -e "${GREEN}  OK: source_file${NC}"
fi

local wave_wt_count
wave_wt_count=$(sqlite3 "$DB_FILE" "SELECT COUNT(*) FROM waves WHERE plan_id=$plan_id AND worktree_path IS NOT NULL AND worktree_path <> '';" 2>/dev/null || echo "0")
if [[ -z "$wt" && "$wave_wt_count" -eq 0 ]]; then
echo -e "${RED}  FAIL: No worktree set (plan-level or wave-level). Use wave-worktree.sh create or --auto-worktree${NC}"
errors=$((errors + 1))
elif [[ -n "$wt" ]]; then
echo -e "${GREEN}  OK: plan worktree_path ($wt)${NC}"
else
echo -e "${GREEN}  OK: wave-level worktrees ($wave_wt_count waves with worktree)${NC}"
fi

local no_desc no_tc
no_desc=$(sqlite3 "$DB_FILE" "SELECT COUNT(*) FROM tasks WHERE plan_id=$plan_id AND status='pending' AND (description IS NULL OR description='');")
no_tc=$(sqlite3 "$DB_FILE" "SELECT COUNT(*) FROM tasks WHERE plan_id=$plan_id AND status='pending' AND (test_criteria IS NULL OR test_criteria='');")

if [[ "$no_desc" -gt 0 ]]; then
echo -e "${RED}  FAIL: $no_desc tasks missing description${NC}"
errors=$((errors + 1))
else
echo -e "${GREEN}  OK: all tasks have description${NC}"
fi

if [[ "$no_tc" -gt 0 ]]; then
echo -e "${RED}  FAIL: $no_tc tasks missing test_criteria${NC}"
errors=$((errors + 1))
else
echo -e "${GREEN}  OK: all tasks have test_criteria${NC}"
fi

# ── Planner Process Gates (Rule 14: MANDATORY for 3+ tasks) ──
local task_count
task_count=$(sqlite3 "$DB_FILE" "SELECT COUNT(*) FROM tasks WHERE plan_id=$plan_id;")
if [[ "$task_count" -ge 3 ]]; then
  _check_planner_process_gates "$plan_id" || errors=$((errors + $?))
fi

if [[ $errors -gt 0 ]]; then
echo -e "${RED}BLOCKED: $errors issues. Fix before /execute.${NC}"
return 1
fi

echo -e "${GREEN}READY: Plan $plan_id is ready for execution${NC}"
return 0
}

# Planner process validation — ensures review/business/challenger/approval steps ran
_check_planner_process_gates() {
  local plan_id="$1"
  local gate_errors=0

  echo -e "${YELLOW}[P] Planner Process Gates (Rule 14)...${NC}"

  local review_count biz_count challenger_count approval_count
  review_count=$(sqlite3 "$DB_FILE" \
    "SELECT COUNT(*) FROM plan_reviews WHERE plan_id=$plan_id AND reviewer_agent LIKE '%reviewer%' AND reviewer_agent NOT LIKE '%challenger%';" 2>/dev/null || echo "0")
  biz_count=$(sqlite3 "$DB_FILE" \
    "SELECT COUNT(*) FROM plan_reviews WHERE plan_id=$plan_id AND (reviewer_agent LIKE '%business%' OR reviewer_agent LIKE '%advisor%');" 2>/dev/null || echo "0")
  challenger_count=$(sqlite3 "$DB_FILE" \
    "SELECT COUNT(*) FROM plan_reviews WHERE plan_id=$plan_id AND reviewer_agent LIKE '%challenger%';" 2>/dev/null || echo "0")
  approval_count=$(sqlite3 "$DB_FILE" \
    "SELECT COUNT(*) FROM plan_reviews WHERE plan_id=$plan_id AND reviewer_agent='user-approval';" 2>/dev/null || echo "0")

  if [[ "$review_count" -eq 0 ]]; then
    echo -e "${RED}  FAIL: No plan-reviewer record. Run Step 3.1 (plan intelligence review).${NC}"
    gate_errors=$((gate_errors + 1))
  else
    local review_verdict
    review_verdict=$(sqlite3 "$DB_FILE" \
      "SELECT verdict FROM plan_reviews WHERE plan_id=$plan_id AND reviewer_agent LIKE '%reviewer%' AND reviewer_agent NOT LIKE '%challenger%' ORDER BY id DESC LIMIT 1;")
    echo -e "${GREEN}  OK: plan-reviewer (verdict: $review_verdict)${NC}"
  fi

  if [[ "$biz_count" -eq 0 ]]; then
    echo -e "${RED}  FAIL: No business-advisor record. Run Step 3.1 (business assessment).${NC}"
    gate_errors=$((gate_errors + 1))
  else
    echo -e "${GREEN}  OK: plan-business-advisor${NC}"
  fi

  if [[ "$challenger_count" -eq 0 ]]; then
    echo -e "${RED}  FAIL: No challenger-review record. Run Step 3.3 (challenger review).${NC}"
    gate_errors=$((gate_errors + 1))
  else
    local challenger_verdict
    challenger_verdict=$(sqlite3 "$DB_FILE" \
      "SELECT verdict FROM plan_reviews WHERE plan_id=$plan_id AND reviewer_agent LIKE '%challenger%' ORDER BY id DESC LIMIT 1;")
    echo -e "${GREEN}  OK: plan-challenger (verdict: $challenger_verdict)${NC}"
  fi

  if [[ "$approval_count" -eq 0 ]]; then
    echo -e "${RED}  FAIL: No user-approval record. Run: plan-db.sh approve $plan_id${NC}"
    gate_errors=$((gate_errors + 1))
  else
    echo -e "${GREEN}  OK: user-approval${NC}"
  fi

  return $gate_errors
}
