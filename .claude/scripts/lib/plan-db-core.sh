#!/bin/bash
# Plan DB Core - Shared utilities
# Sourced by plan-db.sh

DB_FILE="${HOME}/.claude/data/dashboard.db"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
RED='\033[0;31m'
NC='\033[0m'

log_info() { echo -e "${GREEN}[OK]${NC} $1" >&2; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $1" >&2; }
log_error() { echo -e "${RED}[ERROR]${NC} $1" >&2; }

# Initialize DB if needed
init_db() {
    if [[ ! -f "$DB_FILE" ]]; then
        mkdir -p "$(dirname "$DB_FILE")"
        sqlite3 "$DB_FILE" < "$SCRIPT_DIR/init-db.sql"
        log_info "Database initialized"
    fi
}

# Escape single quotes for SQL
sql_escape() {
    printf '%s' "$1" | sed "s/'/''/g"
}
