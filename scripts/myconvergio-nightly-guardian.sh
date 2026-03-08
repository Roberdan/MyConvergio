#!/usr/bin/env bash
set -euo pipefail

# MyConvergio nightly guardian: triage GitHub issues and run safe auto-remediation.

CLAUDE_HOME="${CLAUDE_HOME:-$HOME/.claude}"
REPO_PATH_DEFAULT="${HOME}/GitHub/MyConvergio"
CONFIG_FILE="${MYCONVERGIO_NIGHTLY_CONFIG:-${REPO_PATH_DEFAULT}/config/myconvergio-nightly.conf}"
# shellcheck disable=SC1090
[[ -f "$CONFIG_FILE" ]] && source "$CONFIG_FILE"

REPO_PATH="${MYCONVERGIO_REPO_PATH:-$REPO_PATH_DEFAULT}"
REPO_SLUG="${MYCONVERGIO_GITHUB_REPO:-Roberdan/MyConvergio}"
DEFAULT_BRANCH="${MYCONVERGIO_DEFAULT_BRANCH:-master}"
MODEL="${MYCONVERGIO_MODEL:-gpt-5.3-codex}"
MAX_ITEMS="${MYCONVERGIO_MAX_ITEMS:-6}"
FIX_TIMEOUT_SEC="${MYCONVERGIO_FIX_TIMEOUT_SEC:-5400}"
RUN_FIXES="${MYCONVERGIO_RUN_FIXES:-true}"
REQUIRE_HUMAN_REVIEW="${MYCONVERGIO_REQUIRE_HUMAN_REVIEW:-true}"
MAX_CHANGES_PER_RUN="${MYCONVERGIO_MAX_CHANGES_PER_RUN:-3}"
MAX_STALE_PR_DAYS="${MYCONVERGIO_MAX_STALE_PR_DAYS:-7}"
PROJECT_AGENT_REL_PATH="${MYCONVERGIO_PROJECT_AGENT_REL_PATH:-.github/agents/night-maintenance.agent.md}"
DB_FILE="${CLAUDE_DB:-$CLAUDE_HOME/data/dashboard.db}"
REPORT_DIR="$CLAUDE_HOME/data/nightly-jobs"

RUN_ID="myconvergio-nightly-$(date -u +%Y%m%d-%H%M%S)"
HOST_NAME="$(hostname -s 2>/dev/null || echo unknown)"
RUN_ROW_ID=""
LAST_FAILED_COMMAND=""

log() { printf '[myconvergio-nightly] %s\n' "$*"; }
require_cmd() { command -v "$1" >/dev/null 2>&1 || { log "Missing command: $1"; exit 1; }; }
sql_escape() { printf '%s' "$1" | sed "s/'/''/g"; }
json_or_default() {
  local default_json="$1"
  shift
  local raw
  raw="$("$@" 2>/dev/null || true)"
  if [[ -n "$raw" ]] && jq -e . >/dev/null 2>&1 <<<"$raw"; then
    printf '%s' "$raw"
  else
    printf '%s' "$default_json"
  fi
}
finalize_on_exit() {
  local exit_code=$?
  if [[ "$exit_code" -ne 0 && -n "$RUN_ROW_ID" ]]; then
    sqlite3 "$DB_FILE" <<SQL >/dev/null 2>&1 || true
UPDATE nightly_jobs
SET finished_at = datetime('now'),
    status = 'failed',
    summary = '$(sql_escape "Nightly guardian failed (exit ${exit_code}). Last command: ${LAST_FAILED_COMMAND:-unknown}")'
WHERE id = ${RUN_ROW_ID}
  AND status = 'running';
SQL
  fi
  return "$exit_code"
}

trap 'LAST_FAILED_COMMAND="$BASH_COMMAND"' ERR
trap finalize_on_exit EXIT

require_cmd jq
require_cmd sqlite3
require_cmd git
require_cmd gh
require_cmd timeout
if [[ "$RUN_FIXES" == "true" ]]; then
  require_cmd copilot
  require_cmd make
  require_cmd shellcheck
fi

[[ -d "$REPO_PATH/.git" ]] || { log "Repository not found at $REPO_PATH"; exit 1; }
mkdir -p "$REPORT_DIR" "$(dirname "$DB_FILE")"

PROJECT_AGENT_FILE="${REPO_PATH}/${PROJECT_AGENT_REL_PATH}"
PROJECT_AGENT_CONTENT=""
[[ -f "$PROJECT_AGENT_FILE" ]] && PROJECT_AGENT_CONTENT="$(cat "$PROJECT_AGENT_FILE")"

sqlite3 "$DB_FILE" <<'SQL'
CREATE TABLE IF NOT EXISTS nightly_jobs (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  run_id TEXT,
  started_at DATETIME DEFAULT CURRENT_TIMESTAMP,
  finished_at DATETIME,
  host TEXT,
  status TEXT NOT NULL CHECK(status IN ('running','ok','action_required','failed')),
  total_issues INTEGER DEFAULT 0,
  actionable_issues INTEGER DEFAULT 0,
  processed_items INTEGER DEFAULT 0,
  fixed_items INTEGER DEFAULT 0,
  branch_name TEXT,
  pr_url TEXT,
  summary TEXT,
  report_json TEXT
);
CREATE INDEX IF NOT EXISTS idx_nightly_jobs_started ON nightly_jobs(started_at DESC);
SQL

RUN_ROW_ID="$(sqlite3 "$DB_FILE" "INSERT INTO nightly_jobs(run_id,host,status) VALUES('$(sql_escape "$RUN_ID")','$(sql_escape "$HOST_NAME")','running'); SELECT last_insert_rowid();")"

ISSUES_BUG="$(json_or_default '[]' gh issue list --repo "$REPO_SLUG" --state open --label bug --limit "$MAX_ITEMS" --json number,title,body,url,labels,updatedAt)"
ISSUES_REGRESSION="$(json_or_default '[]' gh issue list --repo "$REPO_SLUG" --state open --label regression --limit "$MAX_ITEMS" --json number,title,body,url,labels,updatedAt)"
ISSUES_CRITICAL="$(json_or_default '[]' gh issue list --repo "$REPO_SLUG" --state open --label critical --limit "$MAX_ITEMS" --json number,title,body,url,labels,updatedAt)"

ALL_TRIAGE="$(jq -c -n --argjson bug "$ISSUES_BUG" --argjson regression "$ISSUES_REGRESSION" --argjson critical "$ISSUES_CRITICAL" \
  '($bug + $regression + $critical) | unique_by(.number)')"
ACTIONABLE_ISSUES_JSON="$(jq -c \
  '[ .[] | select((((.title // "") + " " + (.body // "")) | ascii_downcase | test("error|crash|broken|stale|shellcheck"))) ] | .[:'"$MAX_ITEMS"']' \
  <<<"$ALL_TRIAGE")"

TOTAL_ISSUES="$(jq 'length' <<<"$ALL_TRIAGE")"
ACTIONABLE_ISSUES="$(jq 'length' <<<"$ACTIONABLE_ISSUES_JSON")"
TOP_ACTIONABLE="$(jq -c 'map({number,title,url,updatedAt}) | .[:3]' <<<"$ACTIONABLE_ISSUES_JSON")"

STATUS="ok"
SUMMARY="No actionable GitHub issues."
BRANCH_NAME=""
PR_URL=""
FIXED_ITEMS=0
PROCESSED_ITEMS="$ACTIONABLE_ISSUES"

close_stale_guardian_prs() {
  local prs_json stale_json
  prs_json="$(json_or_default '[]' gh pr list --repo "$REPO_SLUG" --state open --limit 100 --json number,url,headRefName,updatedAt)"
  stale_json="$(jq -c --argjson days "$MAX_STALE_PR_DAYS" \
    '[ .[] | select((.headRefName // "") | startswith("nightly/guardian-")) | select((.updatedAt | fromdateiso8601) < (now - ($days * 86400))) ]' \
    <<<"$prs_json")"
  while IFS= read -r pr_number; do
    [[ -n "$pr_number" ]] && gh pr close --repo "$REPO_SLUG" "$pr_number" --comment \
      "Closing stale nightly guardian PR (older than ${MAX_STALE_PR_DAYS} days)." >/dev/null 2>&1 || true
  done < <(jq -r '.[].number' <<<"$stale_json")
}

run_fix_flow() {
  cd "$REPO_PATH"
  git fetch origin "$DEFAULT_BRANCH" --quiet
  git checkout "$DEFAULT_BRANCH" --quiet
  git pull --rebase origin "$DEFAULT_BRANCH" --quiet

  BRANCH_NAME="nightly/guardian-$(date -u +%Y%m%d-%H%M)"
  git checkout -B "$BRANCH_NAME" --quiet

  local prompt
  prompt=$(cat <<EOF
You are the MyConvergio nightly maintenance Copilot agent.
Repository: ${REPO_SLUG}
Actionable issues (${ACTIONABLE_ISSUES}): ${TOP_ACTIONABLE}

Execute a bounded remediation sweep:
1. Address only high-confidence fixes tied to actionable issues.
2. Keep change scope minimal and capped to ${MAX_CHANGES_PER_RUN} files.
3. Run and pass:
   - shellcheck on all tracked .sh files
   - make test
4. Prepare changes for human review only. Do not merge.
EOF
)
  if [[ -n "$PROJECT_AGENT_CONTENT" ]]; then
    prompt="${prompt}"$'\n\n'"Repository runbook (MUST follow):"$'\n'"${PROJECT_AGENT_CONTENT}"
  fi
  timeout "$FIX_TIMEOUT_SEC" copilot --yolo --add-dir "$REPO_PATH" --model "$MODEL" -p "$prompt"

  mapfile -t sh_files < <(find . -type f -name '*.sh' -not -path './.git/*' | sort)
  ((${#sh_files[@]} > 0)) && shellcheck "${sh_files[@]}"
  make test

  git add -A
  if git diff --cached --quiet; then
    return 2
  fi

  FIXED_ITEMS="$(git diff --name-only --cached | sed '/^$/d' | wc -l | tr -d ' ')"
  if (( FIXED_ITEMS > MAX_CHANGES_PER_RUN )); then
    return 3
  fi

  git commit -m "fix: nightly guardian remediation" \
    -m "Co-authored-by: Copilot <223556219+Copilot@users.noreply.github.com>" >/dev/null
  git push -u origin "$BRANCH_NAME" >/dev/null 2>&1
  PR_URL="$(gh pr create --repo "$REPO_SLUG" --base "$DEFAULT_BRANCH" --head "$BRANCH_NAME" \
    --title "fix: nightly guardian remediation ($(date -u +%F))" \
    --body "Automated nightly triage and remediation.\n\n- Total triaged: ${TOTAL_ISSUES}\n- Actionable: ${ACTIONABLE_ISSUES}\n- Fixed files: ${FIXED_ITEMS}\n- Human review required: ${REQUIRE_HUMAN_REVIEW}" 2>/dev/null || true)"
}

close_stale_guardian_prs

if (( ACTIONABLE_ISSUES > 0 )); then
  if [[ "$RUN_FIXES" != "true" ]]; then
    STATUS="action_required"
    SUMMARY="Actionable issues found; RUN_FIXES=false."
  else
    set +e
    run_fix_flow
    FIX_EXIT=$?
    set -e
    case "$FIX_EXIT" in
      0) STATUS="action_required"; SUMMARY="Nightly remediation PR created for human review."; [[ -n "$PR_URL" ]] && SUMMARY="Nightly remediation PR: $PR_URL" ;;
      2) STATUS="action_required"; SUMMARY="Actionable issues found but no deterministic patch produced." ;;
      3) STATUS="action_required"; SUMMARY="Proposed fixes exceed MAX_CHANGES_PER_RUN=${MAX_CHANGES_PER_RUN}." ;;
      *) STATUS="failed"; SUMMARY="Nightly auto-remediation failed." ;;
    esac
  fi
fi

REPORT_JSON="$(jq -n \
  --arg run_id "$RUN_ID" \
  --arg host "$HOST_NAME" \
  --arg status "$STATUS" \
  --arg summary "$SUMMARY" \
  --arg branch "$BRANCH_NAME" \
  --arg pr_url "$PR_URL" \
  --argjson total_issues "$TOTAL_ISSUES" \
  --argjson actionable_issues "$ACTIONABLE_ISSUES" \
  --argjson processed_items "$PROCESSED_ITEMS" \
  --argjson fixed_items "${FIXED_ITEMS:-0}" \
  --argjson top_actionable "$TOP_ACTIONABLE" \
  '{run_id:$run_id,host:$host,status:$status,summary:$summary,branch:$branch,pr_url:$pr_url,
    total_issues:$total_issues,actionable_issues:$actionable_issues,processed_items:$processed_items,
    fixed_items:$fixed_items,top_actionable:$top_actionable}')"

REPORT_PATH="$REPORT_DIR/${RUN_ID}.json"
printf '%s\n' "$REPORT_JSON" > "$REPORT_PATH"
printf '%s\n' "$REPORT_JSON" > "$REPORT_DIR/latest-myconvergio-nightly.json"

sqlite3 "$DB_FILE" <<SQL
UPDATE nightly_jobs
SET finished_at = datetime('now'),
    status = '$(sql_escape "$STATUS")',
    total_issues = ${TOTAL_ISSUES},
    actionable_issues = ${ACTIONABLE_ISSUES},
    processed_items = ${PROCESSED_ITEMS},
    fixed_items = ${FIXED_ITEMS:-0},
    branch_name = '$(sql_escape "$BRANCH_NAME")',
    pr_url = '$(sql_escape "$PR_URL")',
    summary = '$(sql_escape "$SUMMARY")',
    report_json = '$(sql_escape "$REPORT_JSON")'
WHERE id = ${RUN_ROW_ID};
SQL

if [[ "$STATUS" == "failed" ]]; then
  log "FAILED: $SUMMARY"
  exit 1
fi

log "$STATUS: $SUMMARY"
log "Report: $REPORT_PATH"
