# Helper functions for plan-db.sh
# SQL escaping utilities

# Helper: Escape single quotes for SQL
sql_escape() {
    local input="$1"
    # Replace each single quote with two single quotes (SQL standard escaping)
    printf '%s\n' "${input//\'/\'\'}"
}

