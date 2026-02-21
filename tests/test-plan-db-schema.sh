#!/usr/bin/env bash
# test-plan-db-schema.sh - Verify plan-db-schema.md matches actual DB schema
set -euo pipefail

WORKTREE_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DB_PATH="$HOME/.claude/data/dashboard.db"
SCHEMA_DOC="$WORKTREE_ROOT/reference/operational/plan-db-schema.md"

# ANSI colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

failures=0
warnings=0

# Helper function to extract column names from markdown table
# Reads lines starting from line N, extracts column names until empty line
extract_columns_from_md() {
    local table_name="$1"
    local columns=()
    
    # Find the table section and extract column names
    # The format is: | Column | Type | Constraints | Default |
    # We want the Column names from the table
    local in_table=false
    local found_header=false
    local table_pattern="^### $table_name$"
    
    while IFS= read -r line; do
        if [[ "$line" =~ $table_pattern ]]; then
            in_table=true
            continue
        fi
        
        if [[ "$in_table" == true ]]; then
            # Look for the table header
            if [[ "$line" =~ ^\|[[:space:]]*Column[[:space:]]*\| && "$found_header" == false ]]; then
                found_header=true
                continue
            fi
            
            # Skip the separator line
            if [[ "$line" =~ ^\|[-[:space:]]+\| && "$found_header" == true ]]; then
                continue
            fi
            
            # Once we have the header, extract column names
            if [[ "$found_header" == true ]]; then
                # Extract column name from table row
                if [[ "$line" =~ ^\|[[:space:]]*([a-z_]+)[[:space:]]*\| ]]; then
                    local col="${BASH_REMATCH[1]}"
                    columns+=("$col")
                else
                    # Empty line or non-table line means end of table
                    break
                fi
            fi
        fi
    done < "$SCHEMA_DOC"
    
    printf '%s\n' "${columns[@]}"
}

# Get actual columns from database
get_db_columns() {
    local table_name="$1"
    sqlite3 "$DB_PATH" "PRAGMA table_info($table_name);" | cut -d'|' -f2
}

# Compare documented columns with actual DB columns
verify_table_schema() {
    local table_name="$1"
    echo -e "\n${YELLOW}Checking table: $table_name${NC}"
    
    # Get documented columns
    local -a doc_columns
    mapfile -t doc_columns < <(extract_columns_from_md "$table_name")
    
    if [[ ${#doc_columns[@]} -eq 0 ]]; then
        echo -e "${RED}✗ FAIL: No columns found in documentation for $table_name${NC}"
        ((failures++))
        return 1
    fi
    
    # Get actual columns from DB
    local -a db_columns
    mapfile -t db_columns < <(get_db_columns "$table_name")
    
    if [[ ${#db_columns[@]} -eq 0 ]]; then
        echo -e "${RED}✗ FAIL: Table $table_name not found in database${NC}"
        ((failures++))
        return 1
    fi
    
    echo "  Documented columns: ${#doc_columns[@]}"
    echo "  Actual DB columns: ${#db_columns[@]}"
    
    # Create associative arrays for comparison
    local -A doc_map
    local -A db_map
    
    for col in "${doc_columns[@]}"; do
        doc_map[$col]=1
    done
    
    for col in "${db_columns[@]}"; do
        db_map[$col]=1
    done
    
    local table_ok=true
    
    # Check for columns in DB but not in docs
    for col in "${db_columns[@]}"; do
        if [[ ! -v doc_map[$col] ]]; then
            echo -e "${RED}  ✗ Column '$col' exists in DB but not in documentation${NC}"
            ((failures++))
            table_ok=false
        fi
    done
    
    # Check for columns in docs but not in DB
    for col in "${doc_columns[@]}"; do
        if [[ ! -v db_map[$col] ]]; then
            echo -e "${RED}  ✗ Column '$col' documented but not in DB${NC}"
            ((failures++))
            table_ok=false
        fi
    done
    
    if [[ "$table_ok" == true ]]; then
        echo -e "${GREEN}  ✓ All columns match${NC}"
        return 0
    else
        return 1
    fi
}

# Verify type consistency for a specific column
verify_column_type() {
    local table_name="$1"
    local column_name="$2"
    local expected_type="$3"
    
    local actual_type
    actual_type=$(sqlite3 "$DB_PATH" "PRAGMA table_info($table_name);" | \
        grep "^[0-9]*|$column_name|" | cut -d'|' -f3)
    
    if [[ -z "$actual_type" ]]; then
        echo -e "${YELLOW}  ⚠ Column $table_name.$column_name not found${NC}"
        ((warnings++))
        return 1
    fi
    
    if [[ "$actual_type" != "$expected_type" ]]; then
        echo -e "${YELLOW}  ⚠ Type mismatch: $table_name.$column_name - expected $expected_type, got $actual_type${NC}"
        ((warnings++))
        return 1
    fi
    
    return 0
}

# Main test execution
main() {
    echo "==================================================================="
    echo "Plan DB Schema Verification Test"
    echo "==================================================================="
    echo "Database: $DB_PATH"
    echo "Schema Doc: $SCHEMA_DOC"
    
    # Verify prerequisites
    if [[ ! -f "$DB_PATH" ]]; then
        echo -e "${RED}✗ FAIL: Database not found at $DB_PATH${NC}"
        exit 1
    fi
    
    if [[ ! -f "$SCHEMA_DOC" ]]; then
        echo -e "${RED}✗ FAIL: Schema documentation not found at $SCHEMA_DOC${NC}"
        exit 1
    fi
    
    # Verify core tables
    verify_table_schema "plans"
    verify_table_schema "waves"
    verify_table_schema "tasks"
    
    # Spot check critical column types
    echo -e "\n${YELLOW}Spot-checking critical column types${NC}"
    verify_column_type "plans" "id" "INTEGER"
    verify_column_type "plans" "status" "TEXT"
    verify_column_type "waves" "id" "INTEGER"
    verify_column_type "waves" "position" "INTEGER"
    verify_column_type "tasks" "id" "INTEGER"
    verify_column_type "tasks" "wave_id_fk" "INTEGER"
    verify_column_type "tasks" "wave_id" "TEXT"
    
    # Summary
    echo ""
    echo "==================================================================="
    if [[ $failures -eq 0 ]]; then
        echo -e "${GREEN}✓ PASS: Schema documentation matches database${NC}"
        if [[ $warnings -gt 0 ]]; then
            echo -e "${YELLOW}  (with $warnings warnings)${NC}"
        fi
        exit 0
    else
        echo -e "${RED}✗ FAIL: $failures schema mismatches found${NC}"
        if [[ $warnings -gt 0 ]]; then
            echo -e "${YELLOW}  (and $warnings warnings)${NC}"
        fi
        exit 1
    fi
}

main "$@"
