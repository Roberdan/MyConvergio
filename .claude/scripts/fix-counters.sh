#!/bin/bash
# Fix DB counters - ensures plan/wave counters match actual task counts

# Version: 1.1.0
DB_FILE="${CLAUDE_DATA:-$HOME/.claude/data}/dashboard.db"

echo "Fixing wave counters..."
sqlite3 "$DB_FILE" "
UPDATE waves SET 
  tasks_done = (SELECT COUNT(*) FROM tasks t WHERE t.wave_id_fk = waves.id AND t.status = 'done'),
  tasks_total = (SELECT COUNT(*) FROM tasks t WHERE t.wave_id_fk = waves.id);
"

echo "Fixing wave status..."
sqlite3 "$DB_FILE" "
UPDATE waves SET status = 'done', completed_at = COALESCE(completed_at, datetime('now'))
WHERE tasks_done = tasks_total AND tasks_total > 0 AND status NOT IN ('done', 'blocked');
"

echo "Fixing plan counters..."
sqlite3 "$DB_FILE" "
UPDATE plans SET 
  tasks_done = (SELECT COUNT(*) FROM tasks t WHERE t.plan_id = plans.id AND t.status = 'done'),
  tasks_total = (SELECT COUNT(*) FROM tasks t WHERE t.plan_id = plans.id);
"

echo "Fixing plan status..."
sqlite3 "$DB_FILE" "
UPDATE plans SET status = 'done', completed_at = COALESCE(completed_at, datetime('now'))
WHERE tasks_done = tasks_total AND tasks_total > 0 AND status = 'doing';
"

echo "Verification:"
MISMATCH_COUNT=$(sqlite3 "$DB_FILE" "
SELECT COUNT(*) FROM (
  SELECT p.id FROM plans p
  WHERE p.tasks_done != (SELECT COUNT(*) FROM tasks t WHERE t.plan_id = p.id AND t.status = 'done')
  UNION ALL
  SELECT w.id FROM waves w
  WHERE w.tasks_done != (SELECT COUNT(*) FROM tasks t WHERE t.wave_id_fk = w.id AND t.status = 'done')
);")
echo "Mismatched counters: $MISMATCH_COUNT"
if [[ "$MISMATCH_COUNT" -gt 0 ]]; then
	sqlite3 -header -column "$DB_FILE" "
SELECT 'PLAN MISMATCHES' as type, p.id, p.name, p.tasks_done, p.tasks_total,
       (SELECT COUNT(*) FROM tasks t WHERE t.plan_id = p.id AND t.status = 'done') as actual_done
FROM plans p
WHERE p.tasks_done != (SELECT COUNT(*) FROM tasks t WHERE t.plan_id = p.id AND t.status = 'done')
UNION ALL
SELECT 'WAVE MISMATCHES' as type, w.id, w.wave_id, w.tasks_done, w.tasks_total,
       (SELECT COUNT(*) FROM tasks t WHERE t.wave_id_fk = w.id AND t.status = 'done') as actual_done
FROM waves w
WHERE w.tasks_done != (SELECT COUNT(*) FROM tasks t WHERE t.wave_id_fk = w.id AND t.status = 'done')
LIMIT 10;
"
fi
echo "Done."
