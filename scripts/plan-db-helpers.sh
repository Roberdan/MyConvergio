# DEPRECATED: sql_escape() is now defined in lib/plan-db-core.sh (canonical location).
# This file is only sourced by plan-db-fixed-functions.sh (also deprecated).
# Safe to delete after verification.
#
# Helper functions for plan-db.sh
# SQL escaping utilities

# Helper: Escape single quotes for SQL
# Version: 1.2.0
sql_escape() {
	local input="$1"
	# Replace each single quote with two single quotes (SQL standard escaping)
	printf '%s\n' "${input//\'/\'\'}"
}
