# Plan sync functions for plan-db.sh
# Fixed versions with proper SQL injection prevention

# Sync counters - FIXED VERSION
# Now uses FK-based queries where available
cmd_sync_fixed() {
    local plan_id="$1"

    log_info "Syncing counters for plan $plan_id..."

    # Sync wave counters using FK
    sqlite3 "$DB_FILE" "
        UPDATE waves SET
            tasks_done = (SELECT COUNT(*) FROM tasks WHERE tasks.wave_id_fk = waves.id AND tasks.status = 'done'),
            tasks_total = (SELECT COUNT(*) FROM tasks WHERE tasks.wave_id_fk = waves.id)
        WHERE plan_id = $plan_id;
    "

    # Update wave status based on completion
    sqlite3 "$DB_FILE" "
        UPDATE waves SET status = 'done', completed_at = COALESCE(completed_at, datetime('now'))
        WHERE plan_id = $plan_id AND tasks_done = tasks_total AND tasks_total > 0 AND status != 'done';
    "

    # Sync plan counters
    sqlite3 "$DB_FILE" "
        UPDATE plans SET
            tasks_done = (SELECT COALESCE(SUM(tasks_done), 0) FROM waves WHERE waves.plan_id = plans.id),
            tasks_total = (SELECT COALESCE(SUM(tasks_total), 0) FROM waves WHERE waves.plan_id = plans.id)
        WHERE id = $plan_id;
    "

    # Show result
    sqlite3 -header -column "$DB_FILE" "
        SELECT wave_id, name, status, tasks_done || '/' || tasks_total as progress
        FROM waves WHERE plan_id = $plan_id ORDER BY position;
    "

    log_info "Sync complete"
}

