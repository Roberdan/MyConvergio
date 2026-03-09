#!/usr/bin/env bash
set -euo pipefail
# mesh-health.sh — Compact health report for all mesh nodes
# Usage: mesh-health.sh [--peer NAME]

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SCRIPT_DIR/lib/peers.sh"
peers_load

TARGET_PEER=""
[[ "${1:-}" == "--peer" ]] && TARGET_PEER="${2:-}"

SELF="$(peers_self)"
LOCAL_SHA="$(cd ~/.claude && git rev-parse --short HEAD)"

_check_peer() {
  local peer="$1" is_self=false
  [[ "$peer" == "$SELF" ]] && is_self=true

  if ! $is_self && ! peers_check "$peer" 2>/dev/null; then
    printf "%-10s %-8s %-8s %-5s %-5s %-6s %-6s %s\n" "$peer" "OFFLINE" "-" "-" "-" "-" "-" "-"
    return
  fi

  local sha branch clean stash_n db_cols server stale_br
  if $is_self; then
    sha="$(cd ~/.claude && git rev-parse --short HEAD)"
    branch="$(cd ~/.claude && git branch --show-current)"
    clean="$(cd ~/.claude && git status --porcelain | wc -l | tr -d ' ')"
    stash_n="$(cd ~/.claude && git stash list | wc -l | tr -d ' ')"
    stale_br="$(cd ~/.claude && git branch | grep -cv '^\* main$\|^  main$' || echo 0)"
    db_cols="$(sqlite3 ~/.claude/data/dashboard.db "SELECT COUNT(*) FROM pragma_table_info('nightly_jobs')" 2>/dev/null || echo "?")"
    server="$(curl -sf http://localhost:8420/api/health 2>/dev/null | grep -o '"ok":true' | head -1 || echo "")"
  else
    local dest user target prefix
    dest="$(peers_best_route "$peer")"
    user="$(peers_get "$peer" "user" 2>/dev/null || echo "")"
    target="${user:+${user}@}${dest}"
    prefix="export PATH=/opt/homebrew/bin:/usr/local/bin:\$PATH"
    local info
    info="$(ssh -n -o ConnectTimeout=5 -o BatchMode=yes "$target" "$prefix; cd ~/.claude && printf 'SHA=%s BRANCH=%s CLEAN=%s STASH=%s STALE=%s DBCOL=%s SERVER=%s' \"\$(git rev-parse --short HEAD)\" \"\$(git branch --show-current)\" \"\$(git status --porcelain | wc -l | tr -d ' ')\" \"\$(git stash list | wc -l | tr -d ' ')\" \"\$(git branch | grep -cv '^\* main\$' | tr -d ' ')\" \"\$(sqlite3 data/dashboard.db \"SELECT COUNT(*) FROM pragma_table_info('nightly_jobs')\" 2>/dev/null || echo ?)\" \"\$(curl -sf http://localhost:8420/api/health 2>/dev/null | grep -o '\"ok\":true' | head -1 || echo '')\"" 2>/dev/null || echo "SHA=? BRANCH=? CLEAN=? STASH=? STALE=? DBCOL=? SERVER=")"
    sha="$(echo "$info" | sed -n 's/.*SHA=\([^ ]*\).*/\1/p')"
    branch="$(echo "$info" | sed -n 's/.*BRANCH=\([^ ]*\).*/\1/p')"
    clean="$(echo "$info" | sed -n 's/.*CLEAN=\([^ ]*\).*/\1/p')"
    stash_n="$(echo "$info" | sed -n 's/.*STASH=\([^ ]*\).*/\1/p')"
    stale_br="$(echo "$info" | sed -n 's/.*STALE=\([^ ]*\).*/\1/p')"
    db_cols="$(echo "$info" | sed -n 's/.*DBCOL=\([^ ]*\).*/\1/p')"
    server="$(echo "$info" | sed -n 's/.*SERVER=\([^ ]*\).*/\1/p')"
  fi

  local sha_ok="✓"; [[ "${sha:0:7}" != "$LOCAL_SHA" ]] && sha_ok="✗"
  local clean_ok="✓"; [[ "${clean:-0}" != "0" ]] && clean_ok="${clean}!"
  local server_ok="✓"; [[ -z "$server" ]] && server_ok="—"
  local stale_ok="✓"; [[ "${stale_br:-0}" != "0" ]] && stale_ok="${stale_br}!"

  printf "%-10s %-8s %-8s %-5s %-5s %-6s %-6s %s\n" \
    "$peer" "$sha$sha_ok" "$branch" "$clean_ok" "${stash_n:-0}" "$db_cols" "$server_ok" "$stale_ok"
}

printf "%-10s %-8s %-8s %-5s %-5s %-6s %-6s %s\n" "NODE" "COMMIT" "BRANCH" "CLEAN" "STASH" "DB" "SERVER" "STALE"
printf "%-10s %-8s %-8s %-5s %-5s %-6s %-6s %s\n" "----" "------" "------" "-----" "-----" "------" "------" "-----"

if [[ -n "$TARGET_PEER" ]]; then
  _check_peer "$TARGET_PEER"
else
  for peer in $(peers_list); do
    _check_peer "$peer"
  done
fi
