#!/usr/bin/env bash
set -euo pipefail

DB_FILE="${CLAUDE_DATA:-$HOME/.claude/data}/dashboard.db"
MODE="${1:---check}"
BACKUP_DIR="${HOME}/.claude/backups"

usage() {
  cat <<'EOF'
Usage: dashboard-db-repair.sh [--check|--apply]

Repairs dashboard.db inconsistencies that break dashboard accuracy:
- orphan plan_versions rows
- empty plans with invalid project references
- plan/wave counter drift
- stale wave statuses
- plans marked doing with no running/submitted work
EOF
}

[[ -f "$DB_FILE" ]] || { echo "ERROR: DB not found: $DB_FILE" >&2; exit 1; }

case "$MODE" in
--check | --apply) ;;
--help | -h) usage; exit 0 ;;
*)
  usage >&2
  exit 2
  ;;
esac

sql() {
  sqlite3 "$DB_FILE" "$1"
}

count_query() {
  sql "SELECT COUNT(*) FROM ($1);"
}

fk_count() {
  sql "PRAGMA foreign_key_check;" | awk 'NF {count++} END {print count+0}'
}

report() {
  local orphan_versions bad_plans plan_mismatch wave_mismatch stale_doing fk_violations
  orphan_versions=$(count_query "SELECT id FROM plan_versions WHERE plan_id IS NOT NULL AND plan_id NOT IN (SELECT id FROM plans)")
  bad_plans=$(count_query "SELECT p.id FROM plans p WHERE p.project_id IS NOT NULL AND p.project_id NOT IN (SELECT id FROM projects)")
  plan_mismatch=$(count_query "SELECT p.id FROM plans p LEFT JOIN tasks t ON t.plan_id = p.id GROUP BY p.id HAVING p.tasks_done != COALESCE(SUM(CASE WHEN t.status='done' THEN 1 ELSE 0 END),0) OR p.tasks_total != COUNT(t.id)")
  wave_mismatch=$(count_query "SELECT w.id FROM waves w LEFT JOIN tasks t ON t.wave_id_fk = w.id GROUP BY w.id HAVING w.tasks_done != COALESCE(SUM(CASE WHEN t.status='done' THEN 1 ELSE 0 END),0) OR w.tasks_total != COUNT(t.id)")
  stale_doing=$(count_query "SELECT p.id FROM plans p LEFT JOIN tasks t ON t.plan_id = p.id WHERE p.status='doing' GROUP BY p.id HAVING SUM(CASE WHEN t.status='in_progress' THEN 1 ELSE 0 END)=0 AND SUM(CASE WHEN t.status='submitted' THEN 1 ELSE 0 END)=0 AND SUM(CASE WHEN t.status='pending' THEN 1 ELSE 0 END)>0")
  fk_violations=$(fk_count)

  cat <<EOF
DB repair report
  orphan_plan_versions: $orphan_versions
  invalid_project_plans: $bad_plans
  plan_counter_mismatches: $plan_mismatch
  wave_counter_mismatches: $wave_mismatch
  stale_doing_plans: $stale_doing
  foreign_key_violations: $fk_violations
EOF
}

if [[ "$MODE" == "--check" ]]; then
  report
  exit 0
fi

mkdir -p "$BACKUP_DIR"
backup_path="$BACKUP_DIR/dashboard-db-$(date +%Y%m%d-%H%M%S).sqlite"
cp "$DB_FILE" "$backup_path"
echo "Backup: $backup_path"

sqlite3 "$DB_FILE" <<'SQL'
BEGIN IMMEDIATE;

DELETE FROM plan_versions
WHERE plan_id IS NOT NULL
  AND plan_id NOT IN (SELECT id FROM plans);

DELETE FROM plans
WHERE project_id IS NOT NULL
  AND project_id NOT IN (SELECT id FROM projects)
  AND id NOT IN (SELECT DISTINCT plan_id FROM tasks WHERE plan_id IS NOT NULL)
  AND id NOT IN (SELECT DISTINCT plan_id FROM waves WHERE plan_id IS NOT NULL);

UPDATE waves
SET tasks_done = (
      SELECT COUNT(*) FROM tasks t
      WHERE t.wave_id_fk = waves.id AND t.status = 'done'
    ),
    tasks_total = (
      SELECT COUNT(*) FROM tasks t
      WHERE t.wave_id_fk = waves.id
    );

UPDATE plans
SET tasks_done = (
      SELECT COUNT(*) FROM tasks t
      WHERE t.plan_id = plans.id AND t.status = 'done'
    ),
    tasks_total = (
      SELECT COUNT(*) FROM tasks t
      WHERE t.plan_id = plans.id
    );

UPDATE waves
SET status = 'merging',
    completed_at = COALESCE(completed_at, datetime('now'))
WHERE status NOT IN ('done', 'merging', 'cancelled')
  AND tasks_total > 0
  AND NOT EXISTS (
    SELECT 1 FROM tasks t
    WHERE t.wave_id_fk = waves.id
      AND t.status NOT IN ('done', 'cancelled', 'skipped')
  );

UPDATE waves
SET status = 'blocked'
WHERE status NOT IN ('done', 'merging', 'cancelled')
  AND EXISTS (
    SELECT 1 FROM tasks t
    WHERE t.wave_id_fk = waves.id
      AND t.status = 'blocked'
  );

UPDATE waves
SET status = 'in_progress'
WHERE status NOT IN ('done', 'merging', 'cancelled', 'blocked')
  AND EXISTS (
    SELECT 1 FROM tasks t
    WHERE t.wave_id_fk = waves.id
      AND t.status IN ('done', 'in_progress', 'submitted')
  );

UPDATE waves
SET status = 'pending'
WHERE status NOT IN ('done', 'merging', 'cancelled', 'blocked')
  AND NOT EXISTS (
    SELECT 1 FROM tasks t
    WHERE t.wave_id_fk = waves.id
      AND t.status IN ('done', 'in_progress', 'submitted', 'blocked')
  );

UPDATE plans
SET status = 'todo',
    execution_host = NULL
WHERE status = 'doing'
  AND id IN (
    SELECT p.id
    FROM plans p
    LEFT JOIN tasks t ON t.plan_id = p.id
    GROUP BY p.id
    HAVING SUM(CASE WHEN t.status='in_progress' THEN 1 ELSE 0 END)=0
       AND SUM(CASE WHEN t.status='submitted' THEN 1 ELSE 0 END)=0
       AND SUM(CASE WHEN t.status='pending' THEN 1 ELSE 0 END)>0
  );

COMMIT;
SQL

report
