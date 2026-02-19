#!/bin/bash
# cleanup-empty-dbs.sh - Remove orphaned 0-byte .db files from ~/.claude
# Version: 1.0.0
# Idempotent: safe to run multiple times
set -euo pipefail

CLAUDE_HOME="${HOME}/.claude"
LOG_PREFIX="[cleanup-empty-dbs]"

# Known orphaned DB files (verified: zero references in scripts/dashboard)
ORPHANED_DBS=(
	"${CLAUDE_HOME}/plans/plans.db"
	"${CLAUDE_HOME}/plans/mirrorbuddy/plans.db"
	"${CLAUDE_HOME}/plan-tracker.db"
	"${CLAUDE_HOME}/data/plans.db"
	"${CLAUDE_HOME}/data/thor.db"
)

# Active DB (never touch)
ACTIVE_DB="${CLAUDE_HOME}/data/dashboard.db"

log_info() { echo "$LOG_PREFIX [INFO]  $1"; }
log_warn() { echo "$LOG_PREFIX [WARN]  $1"; }
log_skip() { echo "$LOG_PREFIX [SKIP]  $1"; }

show_help() {
	echo "Usage: $0 [scan|clean|--help]"
	echo "  scan   - List all 0-byte .db files (default)"
	echo "  clean  - Remove orphaned 0-byte .db files"
	echo "  --help - Show this help"
}

# Scan: find ALL 0-byte .db files under ~/.claude
scan_empty_dbs() {
	log_info "Scanning for 0-byte .db files under ${CLAUDE_HOME}/"
	local found=0
	while IFS= read -r -d '' db_file; do
		if [[ -f "$db_file" && ! -s "$db_file" ]]; then
			local status="ORPHANED"
			if [[ "$db_file" == "$ACTIVE_DB" ]]; then
				status="ACTIVE (needs init)"
			fi
			echo "  [$status] $db_file"
			found=$((found + 1))
		fi
	done < <(find "$CLAUDE_HOME" -name "*.db" -print0 2>/dev/null)

	if [[ "$found" -eq 0 ]]; then
		log_info "No 0-byte .db files found. Clean."
	else
		log_info "Found $found empty .db file(s)"
	fi
}

# Clean: remove orphaned 0-byte .db files
clean_orphaned_dbs() {
	local removed=0
	local skipped=0

	for db_file in "${ORPHANED_DBS[@]}"; do
		if [[ ! -e "$db_file" ]]; then
			log_skip "$db_file (already removed)"
			skipped=$((skipped + 1))
			continue
		fi

		if [[ -s "$db_file" ]]; then
			log_warn "$db_file is NOT empty ($(wc -c <"$db_file") bytes) -- skipping"
			skipped=$((skipped + 1))
			continue
		fi

		rm "$db_file"
		log_info "Removed: $db_file"
		removed=$((removed + 1))

		# Clean up empty parent directories (but not ~/.claude itself)
		local parent
		parent=$(dirname "$db_file")
		if [[ "$parent" != "$CLAUDE_HOME" && -d "$parent" ]]; then
			rmdir "$parent" 2>/dev/null && log_info "Removed empty dir: $parent" || true
		fi
	done

	# Safety check: if active DB is empty, warn (don't auto-init)
	if [[ -f "$ACTIVE_DB" && ! -s "$ACTIVE_DB" ]]; then
		log_warn "Active DB is 0 bytes: $ACTIVE_DB"
		log_warn "Run: ~/.claude/scripts/init-dashboard-db.sh --force"
	fi

	log_info "Done: removed=$removed skipped=$skipped"
}

# Main
case "${1:-scan}" in
scan)
	scan_empty_dbs
	;;
clean)
	clean_orphaned_dbs
	;;
--help | -h)
	show_help
	;;
*)
	show_help
	exit 1
	;;
esac
