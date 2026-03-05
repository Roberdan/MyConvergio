#!/usr/bin/env bash
# prefer-ci-summary mapping helpers
# Version: 1.0.0

prefer_ci_summary_db_hint() {
  local base_cmd="$1"

  if echo "$base_cmd" | grep -qE "^plan-db\.sh (status|list|kanban|kanban-json)( |$)"; then
    echo "Use: db-digest.sh plans | db-digest.sh stats" >&2
    return 2
  fi

  if echo "$base_cmd" | grep -qE "^plan-db\.sh (json|execution-tree|get-context) ( |$)"; then
    echo "Use: db-digest.sh tasks <plan_id> | db-digest.sh waves <plan_id>" >&2
    return 2
  fi

  if echo "$base_cmd" | grep -qE "^sqlite3 .*dashboard\.db"; then
    echo "Use: db-digest.sh plans|tasks <plan_id>|waves <plan_id>|stats" >&2
    return 2
  fi

  return 0
}
