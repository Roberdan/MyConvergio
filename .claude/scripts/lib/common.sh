#!/bin/bash
# common.sh - Shared utility functions for scripts
# Version: 1.0.0
# Used by: execute-plan.sh, sync-dashboard-db.sh, pr-ops.sh, sync-to-myconvergio.sh

# ============================================================================
# Colors
# ============================================================================
export RED='\033[0;31m'
export GREEN='\033[0;32m'
export YELLOW='\033[1;33m'
export BLUE='\033[0;34m'
export CYAN='\033[0;36m'
export NC='\033[0m'

# ============================================================================
# Logging functions
# ============================================================================
log() { echo -e "${BLUE}[INFO]${NC} $1"; }
log_info() { echo -e "${GREEN}[INFO]${NC} $1"; }
success() { echo -e "${GREEN}[OK]${NC} $1"; }
warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
error() { echo -e "${RED}[ERROR]${NC} $1" >&2; }
log_error() { echo -e "${RED}[ERROR]${NC} $1" >&2; }
step() { echo -e "${CYAN}  -->${NC} $1"; }

# ============================================================================
# SQL escape helper
# ============================================================================
sql_escape() {
    echo "${1//\'/\'\'}"
}

# ============================================================================
# SSH connectivity check
# ============================================================================
check_ssh() {
    local remote_host="${1:-$REMOTE_HOST}"
    if ! ssh -o ConnectTimeout=5 "$remote_host" "echo ok" &>/dev/null; then
        log_error "Cannot connect to $remote_host"
        return 1
    fi
    return 0
}

# ============================================================================
# Backup directory setup
# ============================================================================
ensure_backup_dir() {
    local backup_dir="${1:-$BACKUP_DIR}"
    mkdir -p "$backup_dir"
}

# ============================================================================
# Command availability check
# ============================================================================
require_commands() {
    local missing=0
    for cmd in "$@"; do
        if ! command -v "$cmd" &>/dev/null; then
            error "Required command not found: $cmd"
            missing=$((missing + 1))
        fi
    done
    if [[ $missing -gt 0 ]]; then
        return 1
    fi
    return 0
}

# ============================================================================
# Database query helper (for scripts using SQLite)
# ============================================================================
db_query() {
    local db_file="${1:-$DB_FILE}"
    shift
    sqlite3 -cmd ".timeout 5000" "$db_file" "$@"
}
