#!/usr/bin/env bash
set -euo pipefail
GREEN='\033[0;32m'; YELLOW='\033[1;33m'; RED='\033[0;31m'; NC='\033[0m'
[[ -t 1 ]] || GREEN='' YELLOW='' RED='' NC=''
BACKUP_ROOT="$HOME/.myconvergio-backups"
SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
SCRIPT_NAME="$(basename -- "$0")"
MODE='full'
BACKUP_PATH=''
LATEST=false
NO_SAFETY_BACKUP=false
ARCHIVE_ITEMS=0
DB_ITEMS=0
RESTORED_MODE_LABEL=''
log() { printf '%b[%s]%b %s\n' "$1" "$2" "$NC" "$3"; }
info() { log "$YELLOW" INFO "$1"; }
ok() { log "$GREEN" OK "$1"; }
warn() { log "$YELLOW" WARN "$1"; }
err() { log "$RED" ERROR "$1" >&2; }
die() { err "$1"; exit 1; }
usage() {
  cat <<USAGE
Usage: $(basename "$0") [backup-dir] [--full|--db-only|--config-only|--agents-only] [--latest] [--no-safety-backup]
Modes:
  --full         Restore everything (.myconvergio + .claude + copilot)
  --db-only      Restore only SQLite databases
  --config-only  Restore config files (rules, hooks, settings)
  --agents-only  Restore only agent definitions
Options:
  --latest            Auto-select latest backup and force --full
  --no-safety-backup  Skip automatic pre-restore safety backup
  -h, --help          Show help
USAGE
}
if command -v sha256sum >/dev/null 2>&1; then
  CHECKSUM_CMD=(sha256sum)
elif command -v shasum >/dev/null 2>&1; then
  CHECKSUM_CMD=(shasum -a 256)
else
  die 'Missing checksum utility: sha256sum or shasum'
fi
sha256() { "${CHECKSUM_CMD[@]}" "$1" | awk '{print $1}'; }
resolve_backups() {
  mapfile -t AVAILABLE_BACKUPS < <(
    for p in "$BACKUP_ROOT"/backup-*; do
      [[ -d "$p" ]] && printf '%s\n' "$p"
    done | sort -r
  )
  [[ ${#AVAILABLE_BACKUPS[@]} -gt 0 ]] || die "No backups found in $BACKUP_ROOT"
}
print_available_backups() {
  info 'Available backups (newest first):'
  local idx=1 p
  for p in "${AVAILABLE_BACKUPS[@]}"; do
    printf '  %d) %s\n' "$idx" "$p"
    idx=$((idx + 1))
  done
}
pick_backup_interactive() {
  [[ -t 0 ]] || die 'No backup path provided and no interactive TTY for selection'
  local choice
  while true; do
    read -r -p 'Select backup number: ' choice
    [[ "$choice" =~ ^[0-9]+$ ]] || { warn 'Please enter a numeric value'; continue; }
    (( choice >= 1 && choice <= ${#AVAILABLE_BACKUPS[@]} )) || { warn 'Selection out of range'; continue; }
    BACKUP_PATH="${AVAILABLE_BACKUPS[$((choice - 1))]}"
    return
  done
}
parse_manifest_items() {
  local manifest="$1"
  python3 - "$manifest" <<'PY'
import json,sys
m=sys.argv[1]
with open(m,'r',encoding='utf-8') as f:
    data=json.load(f)
base=data.get('backup_dir','')
for item in data.get('items',[]):
    path=item.get('path','')
    rel=path[len(base):].lstrip('/') if base and path.startswith(base) else ''
    print('\t'.join([
        item.get('status',''),
        path,
        rel,
        item.get('sha256','')
    ]))
PY
}
validate_manifest_checksums() {
  local manifest="$BACKUP_PATH/manifest.json"
  [[ -f "$manifest" ]] || die "manifest.json not found in $BACKUP_PATH"
  command -v python3 >/dev/null 2>&1 || die 'python3 is required to parse manifest.json'
  local validated=0 status path rel expected candidate actual
  while IFS=$'\t' read -r status path rel expected; do
    [[ "$status" == 'backed_up' ]] || continue
    [[ -n "$expected" ]] || continue
    if [[ -n "$rel" ]]; then
      candidate="$BACKUP_PATH/$rel"
    elif [[ "$path" == */databases/* ]]; then
      candidate="$BACKUP_PATH/databases/$(basename -- "$path")"
    else
      candidate="$BACKUP_PATH/$(basename -- "$path")"
    fi
    [[ -f "$candidate" ]] || die "Manifest item missing: $candidate"
    actual="$(sha256 "$candidate")"
    [[ "$actual" == "$expected" ]] || die "Checksum mismatch: $candidate"
    validated=$((validated + 1))
  done < <(parse_manifest_items "$manifest")
  (( validated > 0 )) || die 'No checksummed items found in manifest.json'
  ok "Manifest checksum validation passed ($validated items)"
}
create_safety_backup() {
  [[ "$NO_SAFETY_BACKUP" == true ]] && { warn 'Skipping safety backup (--no-safety-backup)'; return; }
  local backup_script="$SCRIPT_DIR/myconvergio-backup.sh"
  [[ -x "$backup_script" ]] || die "Required safety backup script not executable: $backup_script"
  info 'Creating safety backup before restore...'
  "$backup_script"
  ok 'Safety backup completed'
}
restore_archive() {
  local archive="$1" dest="$2"
  [[ -f "$archive" ]] || { warn "Archive not found, skipping: $archive"; return; }
  local count
  count="$(tar -tzf "$archive" | awk 'END{print NR+0}')"
  tar -xzf "$archive" -C "$dest"
  ARCHIVE_ITEMS=$((ARCHIVE_ITEMS + count))
  ok "Restored archive: $(basename -- "$archive") ($count entries)"
}
restore_claude_subset() {
  local archive="$BACKUP_PATH/claude.tar.gz"; [[ -f "$archive" ]] || die 'Missing claude.tar.gz in backup'
  local -a members=("$@")
  local member count
  for member in "${members[@]}"; do
    if tar -tzf "$archive" "$member" >/dev/null 2>&1; then
      count="$(tar -tzf "$archive" "$member" | awk 'END{print NR+0}')"
      tar -xzf "$archive" -C "$HOME" "$member"
      ARCHIVE_ITEMS=$((ARCHIVE_ITEMS + count))
      ok "Restored $member ($count entries)"
    else
      warn "Path not found in claude.tar.gz: $member"
    fi
  done
}
integrity_check_db() {
  local db="$1" result
  result="$(sqlite3 "$db" 'PRAGMA integrity_check;' | tr -d '\r')"
  [[ "$result" == 'ok' ]] || die "DB integrity check failed for $db: $result"
}
restore_databases() {
  command -v sqlite3 >/dev/null 2>&1 || die 'sqlite3 is required for database restore'
  local db_dir="$BACKUP_PATH/databases"
  [[ -d "$db_dir" ]] || { warn "No databases directory in backup: $db_dir"; return; }
  local src name rel dest
  shopt -s nullglob
  for src in "$db_dir"/*; do
    [[ -f "$src" ]] || continue
    name="$(basename -- "$src")"
    rel="${name//__//}"
    dest="$HOME/$rel"
    mkdir -p "$(dirname -- "$dest")"
    cp "$src" "$dest"
    integrity_check_db "$dest"
    DB_ITEMS=$((DB_ITEMS + 1))
    ok "Restored DB: $dest"
  done
  shopt -u nullglob
}
if [[ "$SCRIPT_NAME" == 'myconvergio-rollback' ]]; then
  LATEST=true
  MODE='full'
fi
while [[ $# -gt 0 ]]; do
  case "$1" in
    --full) MODE='full' ;;
    --db-only) MODE='db-only' ;;
    --config-only) MODE='config-only' ;;
    --agents-only) MODE='agents-only' ;;
    --latest) LATEST=true; MODE='full' ;;
    --no-safety-backup) NO_SAFETY_BACKUP=true ;;
    -h|--help) usage; exit 0 ;;
    -*) die "Unknown option: $1" ;;
    *) [[ -z "$BACKUP_PATH" ]] || die 'Only one backup path argument is allowed'; BACKUP_PATH="$1" ;;
  esac
  shift
done
resolve_backups
print_available_backups
if [[ "$LATEST" == true ]]; then
  BACKUP_PATH="${AVAILABLE_BACKUPS[0]}"
  info "Auto-selected latest backup: $BACKUP_PATH"
elif [[ -z "$BACKUP_PATH" ]]; then
  pick_backup_interactive
fi
[[ -d "$BACKUP_PATH" ]] || die "Backup directory not found: $BACKUP_PATH"
info "Selected backup: $BACKUP_PATH"
validate_manifest_checksums
create_safety_backup
if [[ "$MODE" == 'full' ]]; then
  warn 'Full restore selected: stop running services before proceeding'
fi
case "$MODE" in
  full)
    restore_archive "$BACKUP_PATH/myconvergio.tar.gz" "$HOME"
    restore_archive "$BACKUP_PATH/claude.tar.gz" "$HOME"
    mkdir -p "$HOME/.config"
    restore_archive "$BACKUP_PATH/github-copilot-config.tar.gz" "$HOME/.config"
    restore_databases
    RESTORED_MODE_LABEL='full'
    ;;
  db-only)
    restore_databases
    RESTORED_MODE_LABEL='db-only'
    ;;
  config-only)
    restore_claude_subset '.claude/rules' '.claude/hooks' '.claude/settings.json' '.claude/settings.local.json' '.claude/settings-templates'
    RESTORED_MODE_LABEL='config-only'
    ;;
  agents-only)
    restore_claude_subset '.claude/agents' '.claude/copilot-agents'
    RESTORED_MODE_LABEL='agents-only'
    ;;
  *)
    die "Invalid mode: $MODE"
    ;;
esac
ok "Restore complete (mode=$RESTORED_MODE_LABEL)"
printf 'Restored entries: %d\n' "$ARCHIVE_ITEMS"
printf 'Restored databases: %d\n' "$DB_ITEMS"
