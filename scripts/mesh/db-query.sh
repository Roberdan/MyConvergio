#!/usr/bin/env bash
set -euo pipefail

DEFAULT_DB="${HOME}/.claude/data/dashboard.db"
DB_PATH="$DEFAULT_DB"

usage() {
  cat <<'EOF'
Usage: db-query.sh [--db /path/to/file.db] "SQL_QUERY"

Executes a SQLite query with JSON output after validating referenced columns.
Default database: ~/.claude/data/dashboard.db
EOF
}

if [[ "${1:-}" == "--help" || "${1:-}" == "-h" ]]; then
  usage
  exit 0
fi

if [[ "${1:-}" == "--db" ]]; then
  if [[ -z "${2:-}" ]]; then
    echo "Error: --db requires a database path." >&2
    usage
    exit 1
  fi
  DB_PATH="$2"
  shift 2
fi

if [[ $# -lt 1 ]]; then
  echo "Error: SQL query is required." >&2
  usage
  exit 1
fi

SQL_QUERY="$*"

if [[ ! -f "$DB_PATH" ]]; then
  echo "Error: Database not found: $DB_PATH" >&2
  exit 1
fi

python3 - "$DB_PATH" "$SQL_QUERY" <<'PYCODE'
from __future__ import annotations

import re
import sqlite3
import sys


def split_select_items(select_expr: str) -> list[str]:
    items: list[str] = []
    buf: list[str] = []
    depth = 0
    for ch in select_expr:
        if ch == "(":
            depth += 1
        elif ch == ")" and depth > 0:
            depth -= 1
        if ch == "," and depth == 0:
            items.append("".join(buf).strip())
            buf = []
        else:
            buf.append(ch)
    tail = "".join(buf).strip()
    if tail:
        items.append(tail)
    return items


def strip_literals(sql: str) -> str:
    sql = re.sub(r"'(?:''|[^'])*'", "''", sql)
    sql = re.sub(r'"(?:""|[^"])*"', '""', sql)
    return sql


def normalize_identifier(identifier: str) -> str:
    return identifier.strip().strip("`[]\"")


db_path = sys.argv[1]
sql_query = sys.argv[2]
clean_sql = strip_literals(sql_query)

from_join_pattern = re.compile(
    r"\b(?:FROM|JOIN)\s+([A-Za-z_][\w$]*)(?:\s+(?:AS\s+)?([A-Za-z_][\w$]*))?",
    re.IGNORECASE,
)
qualified_col_pattern = re.compile(r"\b([A-Za-z_][\w$]*)\.([A-Za-z_][\w$]*)\b")
keywords = {
    "AS",
    "AND",
    "OR",
    "NOT",
    "IN",
    "IS",
    "NULL",
    "CASE",
    "WHEN",
    "THEN",
    "ELSE",
    "END",
    "DISTINCT",
    "DESC",
    "ASC",
}

alias_to_table: dict[str, str] = {}
for match in from_join_pattern.finditer(clean_sql):
    table = normalize_identifier(match.group(1))
    alias = normalize_identifier(match.group(2) or table)
    alias_to_table[alias] = table

tables = sorted(set(alias_to_table.values()))
if not tables:
    sys.exit(0)

conn = sqlite3.connect(db_path)
conn.row_factory = sqlite3.Row

table_columns: dict[str, set[str]] = {}
for table in tables:
    table_escaped = table.replace('"', '""')
    pragma_rows = conn.execute(f'PRAGMA table_info("{table_escaped}")').fetchall()
    if not pragma_rows:
        print(f"Error: Table '{table}' not found in database.", file=sys.stderr)
        conn.close()
        sys.exit(1)
    table_columns[table] = {str(row["name"]) for row in pragma_rows}

invalid_messages: list[str] = []

for qualifier, col in qualified_col_pattern.findall(clean_sql):
    if qualifier not in alias_to_table:
        continue
    table = alias_to_table[qualifier]
    if col not in table_columns[table]:
        available = ", ".join(sorted(table_columns[table]))
        invalid_messages.append(
            f"Invalid column '{col}' in table '{table}'. Available columns: {available}"
        )

select_match = re.search(r"\bSELECT\b(.*?)\bFROM\b", clean_sql, re.IGNORECASE | re.DOTALL)
if select_match and len(tables) == 1:
    only_table = tables[0]
    for item in split_select_items(select_match.group(1)):
        expr = re.sub(r"\s+AS\s+[A-Za-z_][\w$]*\s*$", "", item, flags=re.IGNORECASE).strip()
        expr = re.sub(r"\s+[A-Za-z_][\w$]*\s*$", "", expr).strip()
        if expr in {"*", f"{only_table}.*"}:
            continue
        if "." in expr:
            continue
        if "(" in expr or ")" in expr:
            continue
        if re.fullmatch(r"\d+(?:\.\d+)?", expr):
            continue
        candidate_match = re.fullmatch(r"[A-Za-z_][\w$]*", expr)
        if not candidate_match:
            continue
        candidate = candidate_match.group(0)
        if candidate.upper() in keywords:
            continue
        if candidate not in table_columns[only_table]:
            available = ", ".join(sorted(table_columns[only_table]))
            invalid_messages.append(
                f"Invalid column '{candidate}' in table '{only_table}'. Available columns: {available}"
            )

conn.close()

if invalid_messages:
    for message in sorted(set(invalid_messages)):
        print(f"Error: {message}", file=sys.stderr)
    sys.exit(1)
PYCODE

sqlite3 -json "$DB_PATH" "$SQL_QUERY"
