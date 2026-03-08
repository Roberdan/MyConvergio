#!/usr/bin/env bash
# sql-utils.sh - Canonical SQL literal helpers for shell scripts
# Version: 1.0.0

sql_escape() {
	printf '%s' "${1-}" | tr '\n\r' '  ' | sed "s/'/''/g"
}

sql_lit() {
	printf '%s' "$(sql_escape "${1-}")"
}

sql_quote() {
	printf "'%s'" "$(sql_escape "${1-}")"
}

sql_quote_or_null() {
	if [[ -n "${1-}" ]]; then
		sql_quote "$1"
	else
		printf 'NULL'
	fi
}
