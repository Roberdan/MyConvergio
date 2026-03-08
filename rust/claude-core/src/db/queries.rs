pub const SELECT_ACTIVE_PLANS_ALL: &str = r#"
SELECT id, project_id, name, status, tasks_done, tasks_total
FROM plans
WHERE status = 'doing'
ORDER BY id
LIMIT 5
"#;

pub const SELECT_ACTIVE_PLANS_BY_PROJECT: &str = r#"
SELECT id, project_id, name, status, tasks_done, tasks_total
FROM plans
WHERE status = 'doing' AND project_id = ?1
ORDER BY id
"#;

pub const SELECT_IN_PROGRESS_TASKS_ALL: &str = r#"
SELECT id, project_id, task_id, title, wave_id
FROM tasks
WHERE status = 'in_progress'
ORDER BY id
LIMIT 5
"#;

pub const SELECT_IN_PROGRESS_TASKS_BY_PROJECT: &str = r#"
SELECT id, project_id, task_id, title, wave_id
FROM tasks
WHERE status = 'in_progress' AND project_id = ?1
ORDER BY id
"#;

pub const SELECT_TASK_STATUS_BY_ID: &str = "SELECT status FROM tasks WHERE id = ?1";
pub const SELECT_PLAN_STATUS_BY_TASK_ID: &str = r#"
SELECT p.status
FROM tasks t
JOIN plans p ON p.id = t.plan_id
WHERE t.id = ?1
"#;

pub const UPDATE_TASK_IN_PROGRESS: &str = r#"
UPDATE tasks
SET status = 'in_progress',
    started_at = COALESCE(started_at, CURRENT_TIMESTAMP),
    executor_host = COALESCE(?2, executor_host),
    notes = ?3,
    tokens = COALESCE(?4, tokens),
    output_data = COALESCE(?5, output_data)
WHERE id = ?1
"#;

pub const UPDATE_TASK_SUBMITTED: &str = r#"
UPDATE tasks
SET status = 'submitted',
    completed_at = COALESCE(completed_at, CURRENT_TIMESTAMP),
    executor_host = COALESCE(?2, executor_host),
    notes = ?3,
    tokens = COALESCE(?4, tokens),
    output_data = COALESCE(?5, output_data)
WHERE id = ?1
"#;

pub const UPDATE_TASK_GENERIC: &str = r#"
UPDATE tasks
SET status = ?2,
    executor_host = COALESCE(?3, executor_host),
    notes = ?4,
    tokens = COALESCE(?5, tokens),
    output_data = COALESCE(?6, output_data)
WHERE id = ?1
"#;

pub const UPDATE_TASK_DONE: &str = r#"
UPDATE tasks
SET status = 'done',
    started_at = COALESCE(started_at, CURRENT_TIMESTAMP),
    completed_at = COALESCE(completed_at, CURRENT_TIMESTAMP),
    executor_host = COALESCE(?2, executor_host),
    notes = ?3,
    tokens = COALESCE(?4, tokens),
    output_data = COALESCE(?5, output_data)
WHERE id = ?1
"#;

pub const SELECT_TASK_FOR_VALIDATION_BY_ID: &str = r#"
SELECT id, task_id, status, validated_at
FROM tasks
WHERE id = ?1
"#;

pub const SELECT_TASK_FOR_VALIDATION_BY_TASK_ID_AND_PLAN: &str = r#"
SELECT id, task_id, status, validated_at
FROM tasks
WHERE task_id = ?1 AND plan_id = ?2
LIMIT 1
"#;

pub const UPDATE_VALIDATE_SUBMITTED: &str = r#"
UPDATE tasks
SET status = 'done',
    completed_at = COALESCE(completed_at, CURRENT_TIMESTAMP),
    validated_at = CURRENT_TIMESTAMP,
    validated_by = ?2,
    validation_report = COALESCE(?3, validation_report)
WHERE id = ?1 AND status = 'submitted'
"#;

pub const UPDATE_VALIDATE_DONE: &str = r#"
UPDATE tasks
SET validated_at = COALESCE(validated_at, CURRENT_TIMESTAMP),
    validated_by = ?2,
    validation_report = COALESCE(?3, validation_report)
WHERE id = ?1
"#;

pub const SELECT_PLAN_NODE: &str = r#"
SELECT id, name, status
FROM plans
WHERE id = ?1
"#;

pub const SELECT_WAVE_NODES: &str = r#"
SELECT id, wave_id, name, status, tasks_done, tasks_total
FROM waves
WHERE plan_id = ?1
ORDER BY position, id
"#;

pub const SELECT_TASK_NODES_BY_WAVE: &str = r#"
SELECT id, task_id, title, status
FROM tasks
WHERE wave_id_fk = ?1
ORDER BY id
"#;
