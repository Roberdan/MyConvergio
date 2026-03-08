#!/bin/bash
# idea-jar.sh — Capture, elaborate, promote ideas
# Version: 1.0.0
set -euo pipefail

export PATH="/opt/homebrew/bin:/usr/local/bin:$PATH"
DB_PATH="${DB_PATH:-$HOME/.claude/data/dashboard.db}"

# Colors
BOLD=$(tput bold 2>/dev/null || true)
RESET=$(tput sgr0 2>/dev/null || true)
GREEN=$(tput setaf 2 2>/dev/null || true)
YELLOW=$(tput setaf 3 2>/dev/null || true)
CYAN=$(tput setaf 6 2>/dev/null || true)
RED=$(tput setaf 1 2>/dev/null || true)

db() { sqlite3 "$DB_PATH" "$@"; }

usage() {
  cat <<EOF
${BOLD}idea-jar.sh${RESET} — Capture, elaborate, promote ideas

${BOLD}USAGE${RESET}
  idea-jar.sh <command> [options]

${BOLD}COMMANDS${RESET}
  add "title" [--desc "text"] [--tags "a,b"] [--priority P1] [--project id]
  list [--status draft] [--priority P0] [--limit 20]
  edit <id> [--title "new"] [--desc "new"] [--status ready] [--tags "x,y"]
  note <id> "note text"
  promote <id>
  delete <id> [--force]

${BOLD}PRIORITIES${RESET}  P0 (critical) P1 (high) P2 (normal, default) P3 (low)
${BOLD}STATUSES${RESET}    draft | ready | promoted | archived
EOF
}

status_color() {
  case "$1" in
    promoted) printf '%s' "${GREEN}" ;;
    ready)    printf '%s' "${CYAN}" ;;
    archived) printf '%s' "${YELLOW}" ;;
    *)        printf '%s' "" ;;
  esac
}

cmd_add() {
  local title="" desc="" tags="[]" priority="P2" project_id=""
  local positional=()
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --desc)     desc="$2";       shift 2 ;;
      --tags)     tags=$(printf '"%s"' "$2" | sed 's/,/","/g; s/^/[/; s/$/]/'); shift 2 ;;
      --priority) priority="$2";   shift 2 ;;
      --project)  project_id="$2"; shift 2 ;;
      *)          positional+=("$1"); shift ;;
    esac
  done
  [[ ${#positional[@]} -gt 0 ]] && title="${positional[0]}"
  [[ -z "$title" ]] && { echo "${RED}Error: title required${RESET}"; exit 1; }

  local now; now=$(date -u '+%Y-%m-%d %H:%M:%S')
  local id
  id=$(db "INSERT INTO ideas (title, description, tags, priority, project_id, status, created_at, updated_at)
        VALUES ('$(printf '%s' "$title" | sed "s/'/''/g")',
                '$(printf '%s' "$desc"  | sed "s/'/''/g")',
                '$tags', '$priority',
                '$(printf '%s' "$project_id" | sed "s/'/''/g")',
                'draft', '$now', '$now');
        SELECT last_insert_rowid();")
  echo "${GREEN}${BOLD}Added idea #${id}:${RESET} $title  ${YELLOW}[$priority]${RESET}"
}

cmd_list() {
  local status_filter="" priority_filter="" limit=20
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --status)   status_filter="$2";   shift 2 ;;
      --priority) priority_filter="$2"; shift 2 ;;
      --limit)    limit="$2";           shift 2 ;;
      *)          shift ;;
    esac
  done

  local where="WHERE 1=1"
  [[ -n "$status_filter" ]]   && where+=" AND status='$status_filter'"
  [[ -n "$priority_filter" ]] && where+=" AND priority='$priority_filter'"

  local rows
  rows=$(db "SELECT id, priority, status, title FROM ideas $where ORDER BY priority, created_at DESC LIMIT $limit;")

  if [[ -z "$rows" ]]; then
    echo "${YELLOW}No ideas found.${RESET}"
    return
  fi

  printf "${BOLD}%-5s %-4s %-10s %s${RESET}\n" "ID" "PRI" "STATUS" "TITLE"
  printf '%s\n' "$(printf '%.0s-' {1..60})"
  while IFS='|' read -r id pri status title; do
    local sc; sc=$(status_color "$status")
    printf "%-5s ${YELLOW}%-4s${RESET} ${sc}%-10s${RESET} %s\n" "$id" "$pri" "$status" "$title"
  done <<< "$rows"
}

cmd_edit() {
  local id="${1:-}"; shift || true
  [[ -z "$id" ]] && { echo "${RED}Error: id required${RESET}"; exit 1; }

  local sets=()
  local now; now=$(date -u '+%Y-%m-%d %H:%M:%S')
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --title)  sets+=("title='$(printf '%s' "$2" | sed "s/'/''/g")'"); shift 2 ;;
      --desc)   sets+=("description='$(printf '%s' "$2" | sed "s/'/''/g")'"); shift 2 ;;
      --status) sets+=("status='$2'"); shift 2 ;;
      --tags)   local t; t=$(printf '"%s"' "$2" | sed 's/,/","/g; s/^/[/; s/$/]/'); sets+=("tags='$t'"); shift 2 ;;
      *)        shift ;;
    esac
  done

  [[ ${#sets[@]} -eq 0 ]] && { echo "${YELLOW}Nothing to update.${RESET}"; exit 0; }
  sets+=("updated_at='$now'")
  local set_clause; set_clause=$(IFS=','; echo "${sets[*]}")

  db "UPDATE ideas SET $set_clause WHERE id=$id;"
  echo "${GREEN}Updated idea #${id}${RESET}"
}

cmd_note() {
  local id="${1:-}"; shift || true
  local content="${1:-}"
  [[ -z "$id" || -z "$content" ]] && { echo "${RED}Error: id and note text required${RESET}"; exit 1; }

  local now; now=$(date -u '+%Y-%m-%d %H:%M:%S')
  db "INSERT INTO idea_notes (idea_id, content, created_at)
      VALUES ($id, '$(printf '%s' "$content" | sed "s/'/''/g")', '$now');"
  echo "${GREEN}Note added to idea #${id}${RESET}"
}

cmd_promote() {
  local id="${1:-}"
  [[ -z "$id" ]] && { echo "${RED}Error: id required${RESET}"; exit 1; }

  local now; now=$(date -u '+%Y-%m-%d %H:%M:%S')
  db "UPDATE ideas SET status='promoted', updated_at='$now' WHERE id=$id;"
  local json
  json=$(db ".mode json" "SELECT * FROM ideas WHERE id=$id;")
  echo "${GREEN}${BOLD}Promoted idea #${id}${RESET}"
  echo ""
  echo "${CYAN}--- Idea JSON (for /planner input) ---${RESET}"
  echo "$json"
}

cmd_delete() {
  local id="${1:-}"; shift || true
  local force=false
  [[ "${1:-}" == "--force" ]] && force=true

  [[ -z "$id" ]] && { echo "${RED}Error: id required${RESET}"; exit 1; }

  local title
  title=$(db "SELECT title FROM ideas WHERE id=$id;" 2>/dev/null || true)
  [[ -z "$title" ]] && { echo "${RED}Idea #${id} not found.${RESET}"; exit 1; }

  if [[ "$force" == false ]]; then
    printf "Delete idea #%s: %s? [y/N] " "$id" "$title"
    read -r answer
    [[ "$answer" != "y" && "$answer" != "Y" ]] && { echo "Aborted."; exit 0; }
  fi

  db "DELETE FROM idea_notes WHERE idea_id=$id; DELETE FROM ideas WHERE id=$id;"
  echo "${YELLOW}Deleted idea #${id}: ${title}${RESET}"
}

# Main dispatch
CMD="${1:-}"
[[ -z "$CMD" || "$CMD" == "--help" || "$CMD" == "-h" ]] && { usage; exit 0; }
shift

case "$CMD" in
  add)     cmd_add "$@" ;;
  list)    cmd_list "$@" ;;
  edit)    cmd_edit "$@" ;;
  note)    cmd_note "$@" ;;
  promote) cmd_promote "$@" ;;
  delete)  cmd_delete "$@" ;;
  *)       echo "${RED}Unknown command: $CMD${RESET}"; usage; exit 1 ;;
esac
