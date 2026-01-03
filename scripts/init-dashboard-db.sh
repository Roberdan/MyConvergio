#!/bin/bash
# Initialize Dashboard SQLite Database
# Usage: ./init-dashboard-db.sh [--force]

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DATA_DIR="${HOME}/.claude/data"
DB_FILE="${DATA_DIR}/dashboard.db"
SQL_FILE="${SCRIPT_DIR}/init-db.sql"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

log_info() { echo -e "${GREEN}[INFO]${NC} $1"; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }

# Check dependencies
if ! command -v sqlite3 &> /dev/null; then
    log_error "sqlite3 is required but not installed"
    exit 1
fi

# Parse args
FORCE=false
if [[ "${1:-}" == "--force" ]]; then
    FORCE=true
fi

# Create data directory
if [[ ! -d "$DATA_DIR" ]]; then
    log_info "Creating data directory: $DATA_DIR"
    mkdir -p "$DATA_DIR"
fi

# Check existing database
if [[ -f "$DB_FILE" ]]; then
    if [[ "$FORCE" == true ]]; then
        log_warn "Removing existing database (--force)"
        rm "$DB_FILE"
    else
        log_warn "Database already exists: $DB_FILE"
        log_info "Use --force to recreate"

        # Show current stats
        echo ""
        log_info "Current database stats:"
        sqlite3 "$DB_FILE" "SELECT 'Projects:', COUNT(*) FROM projects;"
        sqlite3 "$DB_FILE" "SELECT 'Snapshots:', COUNT(*) FROM snapshots;"
        sqlite3 "$DB_FILE" "SELECT 'Metrics:', COUNT(*) FROM metrics_history;"
        exit 0
    fi
fi

# Check SQL file exists
if [[ ! -f "$SQL_FILE" ]]; then
    log_error "SQL schema file not found: $SQL_FILE"
    exit 1
fi

# Initialize database
log_info "Initializing database: $DB_FILE"
sqlite3 "$DB_FILE" < "$SQL_FILE"

# Verify tables
TABLES=$(sqlite3 "$DB_FILE" ".tables")
log_info "Created tables: $TABLES"

# Insert default project if in claude directory
CLAUDE_DIR="${HOME}/.claude"
if [[ -d "$CLAUDE_DIR" ]]; then
    log_info "Registering claude config as default project"
    sqlite3 "$DB_FILE" "INSERT OR IGNORE INTO projects (id, name, path) VALUES ('claude-config', 'Claude Config', '$CLAUDE_DIR');"
fi

log_info "Database initialized successfully"
echo ""
echo "Database: $DB_FILE"
echo "Schema:   $SQL_FILE"
