#!/usr/bin/env bash
# mesh-test-helpers.sh: Shared setup/teardown primitives for mesh tests.

set -euo pipefail

# Tracks temp assets created by helpers so tests can clean them in one call.
MESH_TEST_CLEANUP_PATHS=()

mesh_test_register_cleanup() {
  local path="$1"
  [[ -n "$path" ]] && MESH_TEST_CLEANUP_PATHS+=("$path")
}

# mesh_test_create_db [db_path] [extra_sql]
# Creates a sqlite DB with common mesh tables: peer_heartbeats, plans, tasks.
mesh_test_create_db() {
  local db_path="${1:-}"
  local extra_sql="${2:-}"

  if [[ -z "$db_path" ]]; then
    local tmp_db
    tmp_db="$(mktemp "${TEST_TEMP_DIR:-/tmp}/mesh-test.XXXXXX")"
    db_path="${tmp_db}.db"
    mv "$tmp_db" "$db_path"
  fi

  mkdir -p "$(dirname "$db_path")"
  rm -f "$db_path"
  sqlite3 "$db_path" <<'SQL' >/dev/null
PRAGMA journal_mode=WAL;
CREATE TABLE IF NOT EXISTS peer_heartbeats (
  peer_name TEXT PRIMARY KEY,
  status TEXT,
  last_seen INTEGER,
  cpu_load REAL,
  mem_used_gb REAL,
  mem_total_gb REAL,
  tasks_in_progress INTEGER DEFAULT 0,
  cost_tier TEXT DEFAULT 'free',
  capabilities TEXT,
  privacy_safe TEXT,
  load_json TEXT
);
CREATE TABLE IF NOT EXISTS plans (
  id INTEGER PRIMARY KEY,
  status TEXT,
  execution_host TEXT,
  tasks_done INTEGER DEFAULT 0,
  tasks_total INTEGER DEFAULT 0,
  worktree_path TEXT
);
CREATE TABLE IF NOT EXISTS tasks (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  task_id TEXT,
  plan_id INTEGER,
  wave_id_fk INTEGER,
  title TEXT,
  status TEXT,
  executor_host TEXT,
  assigned_at INTEGER,
  validated_by TEXT,
  validated_at TEXT,
  completed_at TEXT,
  started_at TEXT,
  tokens INTEGER DEFAULT 0,
  executor_agent TEXT,
  executor_status TEXT,
  output_data TEXT
);
SQL

  if [[ -n "$extra_sql" ]]; then
    sqlite3 "$db_path" "$extra_sql"
  fi

  mesh_test_register_cleanup "$db_path"
  printf '%s\n' "$db_path"
}

# mesh_test_mock_ssh [script_body]
# Creates temp bin dir with executable mock ssh script and echoes bin path.
mesh_test_mock_ssh() {
  local script_body="${1:-}"
  local bin_dir
  bin_dir="$(mktemp -d "${TEST_TEMP_DIR:-/tmp}/mesh-mock-bin-XXXXXX")"

  if [[ -n "$script_body" ]]; then
    printf '%s\n' "$script_body" >"$bin_dir/ssh"
  else
    cat >"$bin_dir/ssh" <<'SH'
#!/usr/bin/env bash
set -euo pipefail
exit 0
SH
  fi

  chmod +x "$bin_dir/ssh"
  mesh_test_register_cleanup "$bin_dir"
  printf '%s\n' "$bin_dir"
}

# mesh_test_cleanup [path...]
# Removes explicit paths, or all tracked helper-created assets when no args.
mesh_test_cleanup() {
  local targets=()
  if [[ "$#" -gt 0 ]]; then
    targets=("$@")
  else
    targets=("${MESH_TEST_CLEANUP_PATHS[@]:-}")
  fi

  local p
  for p in "${targets[@]}"; do
    [[ -z "$p" ]] && continue
    rm -rf -- "$p" 2>/dev/null || true
  done
}
