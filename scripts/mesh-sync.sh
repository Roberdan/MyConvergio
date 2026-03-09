#!/usr/bin/env bash
set -euo pipefail
# mesh-sync.sh — Sync all mesh nodes to master's main branch
# Usage: mesh-sync.sh [--peer NAME] [--dry-run] [--force]

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SCRIPT_DIR/lib/peers.sh"
peers_load

SELF="$(peers_self)"
DRY_RUN=false FORCE=false TARGET_PEER=""
while [[ $# -gt 0 ]]; do
  case "$1" in
    --peer) TARGET_PEER="$2"; shift 2 ;;
    --dry-run) DRY_RUN=true; shift ;;
    --force) FORCE=true; shift ;;
    *) echo "Usage: mesh-sync.sh [--peer NAME] [--dry-run] [--force]" >&2; exit 1 ;;
  esac
done

LOCAL_SHA="$(cd ~/.claude && git rev-parse --short HEAD)"
echo "Master ($SELF): $LOCAL_SHA on $(cd ~/.claude && git branch --show-current)"

_ssh_cmd() {
  local peer="$1" dest user gh_acct
  dest="$(peers_best_route "$peer")"
  user="$(peers_get "$peer" "user" 2>/dev/null || echo "")"
  gh_acct="$(peers_get "$peer" "gh_account" 2>/dev/null || echo "")"
  local target="${user:+${user}@}${dest}"
  local prefix="export PATH=/opt/homebrew/bin:/usr/local/bin:\$PATH"
  [[ -n "$gh_acct" ]] && prefix="$prefix; gh auth switch --user $gh_acct 2>/dev/null || true"
  shift
  ssh -n -o ConnectTimeout=10 -o BatchMode=yes -o StrictHostKeyChecking=accept-new "$target" "$prefix; $*"
}

_sync_peer() {
  local peer="$1"
  [[ "$peer" == "$SELF" ]] && return 0

  if ! peers_check "$peer" 2>/dev/null; then
    echo "  ⚠ $peer: OFFLINE — skipped"
    return 0
  fi

  local remote_sha
  remote_sha="$(_ssh_cmd "$peer" "cd ~/.claude && git rev-parse --short HEAD 2>/dev/null" || echo "?")"

  if [[ "$remote_sha" == "$LOCAL_SHA" ]]; then
    echo "  ✓ $peer: already at $LOCAL_SHA"
    return 0
  fi

  echo "  ▸ $peer: $remote_sha → $LOCAL_SHA"
  if $DRY_RUN; then return 0; fi

  local gh_acct
  gh_acct="$(peers_get "$peer" "gh_account" 2>/dev/null || echo "")"
  local git_remote="github"

  _ssh_cmd "$peer" "cd ~/.claude && git stash -q 2>/dev/null || true && git fetch $git_remote main -q && git checkout main -q 2>/dev/null && git reset --hard $git_remote/main -q" 2>&1 || {
    if $FORCE; then
      echo "    fetch failed, trying direct push..."
      cd ~/.claude && git push "$(peers_best_route "$peer"):~/.claude" main:main-sync --force -q 2>/dev/null
      _ssh_cmd "$peer" "cd ~/.claude && git checkout main-sync -q 2>/dev/null; git branch -M main-sync main; git checkout main -q" 2>&1
    else
      echo "    ✗ git sync failed (use --force to override)"
      return 1
    fi
  }

  # Trigger DB migrations via Rust server restart or standalone script
  local health
  health="$(_ssh_cmd "$peer" "curl -sf http://localhost:8420/api/health 2>/dev/null | head -c 100" || echo "")"
  if [[ -n "$health" ]]; then
    echo "    ↻ Rust server running — migrations applied on next restart"
  else
    _ssh_cmd "$peer" "cd ~/.claude && bash scripts/apply-migrations.sh 2>/dev/null" || echo "    ⚠ migrations: apply manually"
  fi

  # Cleanup stale branches and stash
  _ssh_cmd "$peer" "cd ~/.claude && git branch | grep -v '^\* main$' | grep -v '^  main$' | xargs -r git branch -D 2>/dev/null; git stash clear 2>/dev/null" || true

  # Verify
  remote_sha="$(_ssh_cmd "$peer" "cd ~/.claude && git rev-parse --short HEAD" || echo "?")"
  if [[ "$remote_sha" == "$LOCAL_SHA" ]]; then
    echo "  ✓ $peer: synced to $LOCAL_SHA"
  else
    echo "  ✗ $peer: expected $LOCAL_SHA, got $remote_sha"
    return 1
  fi
}

echo "Syncing mesh nodes..."
if [[ -n "$TARGET_PEER" ]]; then
  _sync_peer "$TARGET_PEER"
else
  for peer in $(peers_others); do
    _sync_peer "$peer"
  done
fi
echo "Done."
