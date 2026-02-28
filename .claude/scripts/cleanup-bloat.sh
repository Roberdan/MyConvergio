#!/bin/bash
# cleanup-bloat.sh: age-based reaper for debug/ and archive for completed plan data
# Target: reduce repo bloat (3.8 GB → <1 GB)
set -euo pipefail

DEBUG_DIR="${HOME}/.claude/debug"
PROJECTS_DIR="${HOME}/.claude/projects"
SESSION_ENV_DIR="${HOME}/.claude/session-env"
PLANS_DIR="${HOME}/.claude/plans"
ARCHIVE_DIR="${HOME}/.claude/plans/archive"
DRY_RUN="${DRY_RUN:-false}"
DEBUG_MAX_AGE_DAYS="${DEBUG_MAX_AGE_DAYS:-7}"
VERBOSE="${VERBOSE:-false}"

log() { echo "[cleanup] $*"; }
vlog() { [[ "$VERBOSE" == "true" ]] && log "$@" || true; }

confirm_or_dry() {
  if [[ "$DRY_RUN" == "true" ]]; then
    log "DRY-RUN: would delete $1"
    return 1
  fi
  return 0
}

cleanup_debug() {
  log "=== Cleaning debug/ (files older than ${DEBUG_MAX_AGE_DAYS} days) ==="
  local count=0
  if [[ ! -d "$DEBUG_DIR" ]]; then
    log "No debug/ directory found"
    return
  fi
  while IFS= read -r -d '' f; do
    if confirm_or_dry "$f"; then
      rm -f "$f"
      ((count++))
    fi
  done < <(find "$DEBUG_DIR" -type f -mtime "+${DEBUG_MAX_AGE_DAYS}" -print0 2>/dev/null)
  # Remove empty dirs left behind
  find "$DEBUG_DIR" -type d -empty -delete 2>/dev/null || true
  log "Removed $count files from debug/"
}

cleanup_empty_session_envs() {
  log "=== Cleaning empty session-env dirs ==="
  local count=0
  if [[ ! -d "$SESSION_ENV_DIR" ]]; then
    log "No session-env/ directory found"
    return
  fi
  while IFS= read -r -d '' d; do
    if confirm_or_dry "$d"; then
      rmdir "$d" 2>/dev/null && ((count++))
    fi
  done < <(find "$SESSION_ENV_DIR" -maxdepth 1 -type d -empty -print0 2>/dev/null)
  log "Removed $count empty session-env dirs"
}

archive_completed_plans() {
  log "=== Archiving completed plan dirs ==="
  mkdir -p "$ARCHIVE_DIR"
  local count=0
  if [[ ! -d "$PLANS_DIR" ]]; then
    log "No plans/ directory found"
    return
  fi
  for plan_dir in "$PLANS_DIR"/*/; do
    [[ -d "$plan_dir" ]] || continue
    local base
    base="$(basename "$plan_dir")"
    [[ "$base" == "archive" ]] && continue
    # Check if plan dir has a done marker or is old (>30 days, no recent changes)
    local last_mod
    last_mod=$(find "$plan_dir" -type f -printf '%T@\n' 2>/dev/null | sort -n | tail -1)
    if [[ -z "$last_mod" ]]; then
      # Empty plan dir — remove
      if confirm_or_dry "$plan_dir"; then
        rmdir "$plan_dir" 2>/dev/null && ((count++))
      fi
      continue
    fi
    local age_days
    age_days=$(( ($(date +%s) - ${last_mod%.*}) / 86400 ))
    if [[ $age_days -gt 30 ]]; then
      if confirm_or_dry "$plan_dir → archive"; then
        mv "$plan_dir" "$ARCHIVE_DIR/$base"
        ((count++))
      fi
    fi
  done
  log "Archived/removed $count plan dirs"
}

cleanup_empty_project_dirs() {
  log "=== Cleaning empty project dirs ==="
  local count=0
  if [[ ! -d "$PROJECTS_DIR" ]]; then
    log "No projects/ directory found"
    return
  fi
  while IFS= read -r -d '' d; do
    if confirm_or_dry "$d"; then
      rmdir "$d" 2>/dev/null && ((count++))
    fi
  done < <(find "$PROJECTS_DIR" -type d -empty -print0 2>/dev/null)
  log "Removed $count empty project dirs"
}

summary() {
  log "=== Summary ==="
  local total=0
  for d in "$DEBUG_DIR" "$SESSION_ENV_DIR" "$PLANS_DIR" "$PROJECTS_DIR"; do
    if [[ -d "$d" ]]; then
      local size
      size=$(du -sh "$d" 2>/dev/null | cut -f1)
      log "  $d: $size"
    fi
  done
}

main() {
  log "Starting cleanup (DRY_RUN=$DRY_RUN)"
  cleanup_debug
  cleanup_empty_session_envs
  archive_completed_plans
  cleanup_empty_project_dirs
  summary
  log "Done"
}

main "$@"
