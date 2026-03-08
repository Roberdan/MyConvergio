#!/usr/bin/env bash
set -euo pipefail
GREEN='\033[0;32m'; YELLOW='\033[1;33m'; RED='\033[0;31m'; BLUE='\033[0;34m'; NC='\033[0m'
[[ -t 1 ]] || GREEN='' YELLOW='' RED='' BLUE='' NC=''
SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd -- "$SCRIPT_DIR/.." && pwd)"
BACKUP_SCRIPT="$SCRIPT_DIR/myconvergio-backup.sh"
RESTORE_SCRIPT="$SCRIPT_DIR/myconvergio-restore.sh"
LOG_DIR="$HOME/.myconvergio-backups"
LOG_FILE="$LOG_DIR/migration-$(date +%Y%m%d).log"
DRY_RUN=false
STEP=0
BACKUP_PATH=''
VERSION_FILE=''
INSTALL_ROOT=''
SOURCE_VERSION=''
usage() {
  cat <<'USAGE'
Usage: migrate-v10-to-v11.sh [--dry-run]
  --dry-run   Show planned changes without modifying files
USAGE
}
log() { printf '%b[%s]%b %s\n' "$1" "$2" "$NC" "$3"; }
info() { log "$BLUE" INFO "$1"; }
ok() { log "$GREEN" OK "$1"; }
warn() { log "$YELLOW" WARN "$1"; }
err() { log "$RED" ERROR "$1" >&2; }
step() { STEP=$((STEP + 1)); log "$YELLOW" "STEP $STEP" "$1"; }
die() { err "$1"; exit 1; }
run() {
  if [[ "$DRY_RUN" == true ]]; then
    info "[DRY-RUN] $*"
  else
    "$@"
  fi
}
latest_backup_dir() {
  find "$LOG_DIR" -maxdepth 1 -type d -name 'backup-*' -print 2>/dev/null | sort -r | awk 'NR==1 {print; exit}'
}
restore_hint() {
  local backup_dir="$BACKUP_PATH"
  if [[ -z "$backup_dir" ]]; then
    backup_dir="$(latest_backup_dir)"
  fi
  if [[ -n "$backup_dir" && -x "$RESTORE_SCRIPT" ]]; then
    printf '\n'
    warn "Restore command:"
    printf '%s "%s" "%s" --full\n' "$RESTORE_SCRIPT" "$backup_dir" "--no-safety-backup"
  fi
}
on_error() {
  err "Migration failed. No further changes were applied."
  restore_hint
}
trap on_error ERR
detect_v10() {
  local candidates=("$HOME/.myconvergio/VERSION" "$HOME/GitHub/MyConvergio/VERSION")
  local file line
  for file in "${candidates[@]}"; do
    [[ -f "$file" ]] || continue
    line="$(awk 'NF {print; exit}' "$file" 2>/dev/null || true)"
    if [[ "$line" =~ ^10\. ]] || [[ "$line" =~ ^SYSTEM_VERSION=10\. ]]; then
      VERSION_FILE="$file"
      INSTALL_ROOT="$(cd -- "$(dirname -- "$file")" && pwd)"
      SOURCE_VERSION="$line"
      return 0
    fi
  done
  return 1
}

safe_copy_tree() {
  local src="$1" dest="$2" rel base_file dst_file
  [[ -d "$src" ]] || { warn "Source missing, skipped: $src"; return; }
  info "Sync: $src -> $dest"
  while IFS= read -r rel; do
    dst_file="$dest/$rel"
    base_file="$INSTALL_ROOT/.baseline/$rel"
    if [[ -f "$dst_file" ]]; then
      if [[ -f "$base_file" ]] && ! cmp -s "$dst_file" "$base_file"; then
        warn "Preserved customized file (baseline diff): $dst_file"
        continue
      fi
      if [[ ! -f "$base_file" ]] && ! cmp -s "$src/$rel" "$dst_file"; then
        warn "Preserved existing file (assumed customized): $dst_file"
        continue
      fi
    fi
    run mkdir -p "$(dirname -- "$dst_file")"
    run cp "$src/$rel" "$dst_file"
    info "Updated: $dst_file"
  done < <(cd "$src" && find . -type f -print | sed 's|^\./||')
}

migrate_db() {
  local db="$1"
  [[ -f "$db" ]] || return 0
  command -v sqlite3 >/dev/null 2>&1 || { warn "sqlite3 missing, skipping DB migration"; return; }
  info "Migrating DB schema: $db"
  if [[ "$DRY_RUN" == true ]]; then
    info "[DRY-RUN] Would apply schema updates to $db"
    return 0
  fi
  sqlite3 "$db" <<'SQL'
CREATE TABLE IF NOT EXISTS system_meta (
  key TEXT PRIMARY KEY,
  value TEXT NOT NULL
);
INSERT INTO system_meta(key, value) VALUES('schema_version', '11.0.0')
  ON CONFLICT(key) DO UPDATE SET value='11.0.0';
SQL
  if sqlite3 "$db" "SELECT count(*) FROM sqlite_master WHERE type='table' AND name='plans';" | grep -q '^1$'; then
    if sqlite3 "$db" "SELECT count(*) FROM pragma_table_info('plans') WHERE name='executor_agent';" | grep -q '^0$'; then
      sqlite3 "$db" "ALTER TABLE plans ADD COLUMN executor_agent TEXT DEFAULT 'copilot';"
      ok "Added plans.executor_agent"
    fi
  fi
  if sqlite3 "$db" "SELECT count(*) FROM sqlite_master WHERE type='table' AND name='tasks';" | grep -q '^1$'; then
    if sqlite3 "$db" "SELECT count(*) FROM pragma_table_info('tasks') WHERE name='output_data';" | grep -q '^0$'; then
      sqlite3 "$db" "ALTER TABLE tasks ADD COLUMN output_data TEXT DEFAULT NULL;"
      ok "Added tasks.output_data"
    fi
  fi
}

set_version_11() {
  local file="$1" tmp
  tmp="$(mktemp)"
  awk '
    BEGIN {done=0}
    /^SYSTEM_VERSION=/ {print "SYSTEM_VERSION=11.0.0"; done=1; next}
    {print}
    END {if (!done) print "SYSTEM_VERSION=11.0.0"}
  ' "$file" > "$tmp"
  run mv "$tmp" "$file"
}

update_json_defaults() {
  local file="$1"
  [[ -f "$file" ]] || return 0
  command -v python3 >/dev/null 2>&1 || { warn "python3 missing, skipped config update: $file"; return; }
  if [[ "$DRY_RUN" == true ]]; then
    info "[DRY-RUN] Would add default keys to $file"
    return 0
  fi
  python3 - "$file" <<'PY'
import json, sys
path = sys.argv[1]
with open(path, "r", encoding="utf-8") as fh:
    data = json.load(fh)
defaults = {
    "systemVersion": "11.0.0",
    "enableMigrationBackups": True,
    "migrationTrack": "v10-to-v11"
}
changed = False
for key, value in defaults.items():
    if key not in data:
        data[key] = value
        changed = True
if changed:
    with open(path, "w", encoding="utf-8") as fh:
        json.dump(data, fh, indent=2, sort_keys=True)
        fh.write("\n")
PY
}

for arg in "$@"; do
  case "$arg" in
    --dry-run) DRY_RUN=true ;;
    -h|--help) usage; exit 0 ;;
    *) die "Unknown option: $arg" ;;
  esac
done

mkdir -p "$LOG_DIR"
exec > >(tee -a "$LOG_FILE") 2>&1
info "Logging to $LOG_FILE"

step "Detecting v10.x installation"
detect_v10 || die "No v10.x installation found in ~/.myconvergio/VERSION or ~/GitHub/MyConvergio/VERSION."
ok "Detected source version: $SOURCE_VERSION ($VERSION_FILE)"

step "Mandatory pre-migration backup"
[[ -x "$BACKUP_SCRIPT" ]] || die "Missing executable backup script: $BACKUP_SCRIPT"
if [[ "$DRY_RUN" == true ]]; then
  info "[DRY-RUN] Would run backup script: $BACKUP_SCRIPT"
else
  backup_output="$("$BACKUP_SCRIPT" 2>&1)" || { printf '%s\n' "$backup_output"; die "Backup failed; migration aborted."; }
  printf '%s\n' "$backup_output"
  BACKUP_PATH="$(printf '%s\n' "$backup_output" | awk -F': ' '/Backup completed:/ {print $2}' | awk 'END{print}')"
  [[ -n "$BACKUP_PATH" ]] || BACKUP_PATH="$(latest_backup_dir)"
  [[ -n "$BACKUP_PATH" ]] || die "Backup succeeded but backup location could not be resolved."
  ok "Backup location: $BACKUP_PATH"
fi

step "Presenting migration plan"
cat <<PLAN
Planned migration changes:
  1) Sync rules/ and required files (preserve customized files)
  2) Sync hooks/ (keep custom user-added hooks untouched)
  3) Sync commands/ and skills/
  4) Run safe SQLite schema updates (idempotent ALTER logic)
  5) Update VERSION to SYSTEM_VERSION=11.0.0
  6) Update config defaults without overriding user values
  7) Run doctor verification if available
PLAN
read -r -p "Type 'yes' to proceed: " confirm
[[ "$confirm" == "yes" ]] || die "Migration aborted by user."

step "Copying rules and files"
safe_copy_tree "$REPO_ROOT/rules" "$INSTALL_ROOT/rules"
safe_copy_tree "$REPO_ROOT/config" "$INSTALL_ROOT/config"

step "Installing hooks"
safe_copy_tree "$REPO_ROOT/hooks" "$INSTALL_ROOT/hooks"

step "Updating commands and skills"
safe_copy_tree "$REPO_ROOT/commands" "$INSTALL_ROOT/commands"
safe_copy_tree "$REPO_ROOT/skills" "$INSTALL_ROOT/skills"

step "Migrating SQLite schemas"
migrate_db "$HOME/.myconvergio/data/dashboard.db"
for db in "$HOME/.myconvergio/data/"*.db; do
  [[ -f "$db" ]] || continue
  migrate_db "$db"
done

step "Updating version and config defaults"
set_version_11 "$VERSION_FILE"
update_json_defaults "$INSTALL_ROOT/settings.json"
update_json_defaults "$INSTALL_ROOT/settings.local.json"

step "Running doctor verification"
if [[ "$DRY_RUN" == true ]]; then
  info "[DRY-RUN] Would run: myconvergio doctor"
elif command -v myconvergio >/dev/null 2>&1; then
  myconvergio doctor || warn "Doctor reported warnings/errors."
elif [[ -x "$SCRIPT_DIR/myconvergio-doctor.sh" ]]; then
  "$SCRIPT_DIR/myconvergio-doctor.sh" || warn "Doctor script reported warnings/errors."
else
  warn "Doctor command is not available; skipped."
fi

ok "Migration to v11.0.0 completed."
restore_hint
