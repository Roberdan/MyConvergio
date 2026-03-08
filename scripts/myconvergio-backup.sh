#!/usr/bin/env bash
set -euo pipefail

GREEN='\033[0;32m'; YELLOW='\033[1;33m'; RED='\033[0;31m'; NC='\033[0m'
[[ -t 1 ]] || GREEN='' YELLOW='' RED='' NC=''

DRY_RUN=false; DB_ONLY=false
BACKUP_ROOT="$HOME/.myconvergio-backups"
TIMESTAMP="$(date +%Y%m%d-%H%M)"
BACKUP_DIR="$BACKUP_ROOT/backup-$TIMESTAMP"
DB_DIR="$BACKUP_DIR/databases"
MANIFEST_FILE="$BACKUP_DIR/manifest.json"
MANIFEST_ITEMS=''
TOTAL_BYTES=0

log() { printf '%b[%s]%b %s\n' "$1" "$2" "$NC" "$3"; }
info() { log "$YELLOW" INFO "$1"; }
ok() { log "$GREEN" OK "$1"; }
warn() { log "$YELLOW" WARN "$1"; }
err() { log "$RED" ERROR "$1" >&2; }
die() { err "$1"; exit 1; }

usage() {
  cat <<USAGE
Usage: $(basename "$0") [--dry-run] [--db-only]
  --dry-run  Show what would be backed up
  --db-only  Back up only SQLite databases
USAGE
}

for arg in "$@"; do
  case "$arg" in
    --dry-run) DRY_RUN=true ;;
    --db-only) DB_ONLY=true ;;
    -h|--help) usage; exit 0 ;;
    *) die "Unknown option: $arg" ;;
  esac
done

if command -v sha256sum >/dev/null 2>&1; then
  CHECKSUM=(sha256sum)
elif command -v shasum >/dev/null 2>&1; then
  CHECKSUM=(shasum -a 256)
else
  die "Missing checksum utility: sha256sum or shasum"
fi

fsize() {
  if stat -f%z "$1" >/dev/null 2>&1; then stat -f%z "$1"; else stat -c%s "$1"; fi
}

sha256() { "${CHECKSUM[@]}" "$1" | awk '{print $1}'; }

jescape() {
  local v="$1"
  v=${v//\\/\\\\}; v=${v//\"/\\\"}
  printf '%s' "$v"
}

add_item() {
  local path="$1" type="$2" status="$3" sum="$4" bytes="$5" item
  item=$(printf '{"path":"%s","type":"%s","status":"%s","sha256":"%s","size_bytes":%s}' \
    "$(jescape "$path")" "$(jescape "$type")" "$(jescape "$status")" "$(jescape "$sum")" "$bytes")
  [[ -z "$MANIFEST_ITEMS" ]] || MANIFEST_ITEMS+=$',\n'
  MANIFEST_ITEMS+="    $item"
}

backup_dir() {
  local src="$1" out="$BACKUP_DIR/$2"
  if [[ ! -d "$src" ]]; then warn "Skipping missing directory: $src"; add_item "$src" directory skipped_missing '' 0; return; fi
  if [[ "$DRY_RUN" == true ]]; then info "[DRY-RUN] Would archive: $src -> $out"; add_item "$src" directory dry_run '' 0; return; fi
  tar -czf "$out" -C "$(dirname "$src")" "$(basename "$src")"
  local sum bytes; sum="$(sha256 "$out")"; bytes="$(fsize "$out")"
  TOTAL_BYTES=$((TOTAL_BYTES + bytes)); add_item "$out" archive backed_up "$sum" "$bytes"; ok "Backed up $src"
}

integrity_check() {
  command -v sqlite3 >/dev/null 2>&1 || die "sqlite3 is required for integrity checks"
  local result; result="$(sqlite3 "$1" 'PRAGMA integrity_check;' | tr -d '\r')"
  [[ "$result" == ok ]] || die "Integrity check failed for $1: $result"
  ok "Integrity check passed: $1"
}

backup_db() {
  local db="$1"
  if [[ ! -f "$db" ]]; then warn "Skipping missing database: $db"; add_item "$db" database skipped_missing '' 0; return; fi
  if [[ "$DRY_RUN" == true ]]; then info "[DRY-RUN] Would integrity-check and back up DB: $db"; add_item "$db" database dry_run '' 0; return; fi
  integrity_check "$db"
  local rel safe out sum bytes
  rel="${db/#$HOME\//}"; safe="${rel//\//__}"; out="$DB_DIR/$safe"
  cp "$db" "$out"
  sum="$(sha256 "$out")"; bytes="$(fsize "$out")"
  TOTAL_BYTES=$((TOTAL_BYTES + bytes)); add_item "$out" database backed_up "$sum" "$bytes"; ok "Backed up database $db"
}

write_manifest() {
  local mode='full'; [[ "$DB_ONLY" == true ]] && mode='db_only'
  cat > "$MANIFEST_FILE" <<JSON
{
  "generated_at": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
  "backup_dir": "$(jescape "$BACKUP_DIR")",
  "mode": "$mode",
  "total_size_bytes": $TOTAL_BYTES,
  "items": [
$MANIFEST_ITEMS
  ]
}
JSON
}

print_rollback() {
  local latest='' p
  for p in "$BACKUP_ROOT"/backup-*; do
    [[ -d "$p" ]] || continue
    [[ -z "$latest" || "$p" > "$latest" ]] && latest="$p"
  done
  [[ -n "$latest" ]] || { warn 'No backups found for rollback instructions.'; return; }
  printf '\n%bmyconvergio rollback%b\n' "$GREEN" "$NC"
  printf 'Latest backup: %s\n' "$latest"
  printf 'Review manifest: cat "%s/manifest.json"\n' "$latest"
  printf '%s\n' "Restore ~/.myconvergio: tar -xzf \"$latest/myconvergio.tar.gz\" -C \"\$HOME\""
  printf '%s\n' "Restore ~/.claude: tar -xzf \"$latest/claude.tar.gz\" -C \"\$HOME\""
  printf '%s\n' "Restore copilot config: tar -xzf \"$latest/github-copilot-config.tar.gz\" -C \"\$HOME/.config\""
  printf 'Restore DB files: cp "%s/databases/"* <target-path>\n' "$latest"
}

[[ "$DRY_RUN" == true ]] || mkdir -p "$DB_DIR"
info "Starting backup (dry-run=$DRY_RUN, db-only=$DB_ONLY)"

if [[ "$DB_ONLY" == false ]]; then
  backup_dir "$HOME/.myconvergio" myconvergio.tar.gz
  backup_dir "$HOME/.claude" claude.tar.gz
  backup_dir "$HOME/.config/github-copilot" github-copilot-config.tar.gz
fi

backup_db "$HOME/.claude/data/dashboard.db"
if [[ -d "$HOME/.myconvergio/data" ]]; then
  shopt -s nullglob
  myconvergio_dbs=("$HOME/.myconvergio/data/"*.db)
  shopt -u nullglob
  if [[ ${#myconvergio_dbs[@]} -eq 0 ]]; then warn "No databases found in $HOME/.myconvergio/data"; fi
  for db in "${myconvergio_dbs[@]}"; do backup_db "$db"; done
else
  warn "Directory not found: $HOME/.myconvergio/data"
fi

if [[ "$DRY_RUN" == false ]]; then
  write_manifest
  local_sum="$(sha256 "$MANIFEST_FILE")"; local_bytes="$(fsize "$MANIFEST_FILE")"
  TOTAL_BYTES=$((TOTAL_BYTES + local_bytes)); add_item "$MANIFEST_FILE" manifest backed_up "$local_sum" "$local_bytes"
  write_manifest
  total_human="$(du -sh "$BACKUP_DIR" | awk '{print $1}')"
  ok "Backup completed: $BACKUP_DIR"
  ok "Total backup size: $total_human ($TOTAL_BYTES bytes)"
else
  info 'Dry-run completed. No files were created.'
fi

print_rollback
