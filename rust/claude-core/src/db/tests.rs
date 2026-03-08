use super::{PlanDb, TaskStatus, UpdateTaskArgs, ValidateTaskArgs};

fn seed_schema(db: &PlanDb) {
    db.connection()
        .execute_batch(
            "
            CREATE TABLE projects (
              id TEXT PRIMARY KEY,
              name TEXT NOT NULL
            );
            CREATE TABLE plans (
              id INTEGER PRIMARY KEY,
              project_id TEXT NOT NULL,
              name TEXT NOT NULL,
              status TEXT NOT NULL,
              tasks_done INTEGER DEFAULT 0,
              tasks_total INTEGER DEFAULT 0
            );
            CREATE TABLE waves (
              id INTEGER PRIMARY KEY,
              plan_id INTEGER NOT NULL,
              wave_id TEXT NOT NULL,
              name TEXT NOT NULL,
              status TEXT NOT NULL,
              tasks_done INTEGER DEFAULT 0,
              tasks_total INTEGER DEFAULT 0,
              position INTEGER DEFAULT 0
            );
            CREATE TABLE tasks (
              id INTEGER PRIMARY KEY,
              project_id TEXT NOT NULL,
              plan_id INTEGER NOT NULL,
              wave_id_fk INTEGER NOT NULL,
              wave_id TEXT NOT NULL,
              task_id TEXT NOT NULL,
              title TEXT NOT NULL,
              status TEXT NOT NULL,
              started_at TEXT,
              completed_at TEXT,
              notes TEXT,
              tokens INTEGER,
              output_data TEXT,
              executor_host TEXT,
              validated_at TEXT,
              validated_by TEXT,
              validation_report TEXT
            );
            ",
        )
        .expect("schema");
}

#[test]
fn db_status_filters_by_project() {
    let db = PlanDb::open_in_memory().expect("db");
    seed_schema(&db);

    db.connection()
        .execute("INSERT INTO projects(id,name) VALUES('p1','P1'),('p2','P2')", [])
        .expect("projects");
    db.connection()
        .execute(
            "INSERT INTO plans(id,project_id,name,status,tasks_done,tasks_total)
             VALUES(1,'p1','Plan A','doing',1,3),(2,'p2','Plan B','doing',0,2)",
            [],
        )
        .expect("plans");
    db.connection()
        .execute(
            "INSERT INTO waves(id,plan_id,wave_id,name,status,tasks_done,tasks_total,position)
             VALUES(10,1,'W1','Wave 1','in_progress',1,2,1),(20,2,'W1','Wave 1','in_progress',0,1,1)",
            [],
        )
        .expect("waves");
    db.connection()
        .execute(
            "INSERT INTO tasks(id,project_id,plan_id,wave_id_fk,wave_id,task_id,title,status)
             VALUES(100,'p1',1,10,'W1','T1','Task 1','in_progress'),(200,'p2',2,20,'W1','T2','Task 2','in_progress')",
            [],
        )
        .expect("tasks");

    let status = db.status(Some("p1")).expect("status");
    assert_eq!(status.active_plans.len(), 1);
    assert_eq!(status.active_plans[0].project_id, "p1");
    assert_eq!(status.in_progress_tasks.len(), 1);
    assert_eq!(status.in_progress_tasks[0].project_id, "p1");
}

#[test]
fn db_update_task_is_injection_safe() {
    let db = PlanDb::open_in_memory().expect("db");
    seed_schema(&db);
    db.connection()
        .execute("INSERT INTO projects(id,name) VALUES('p1','P1')", [])
        .expect("projects");
    db.connection()
        .execute(
            "INSERT INTO plans(id,project_id,name,status,tasks_done,tasks_total) VALUES(1,'p1','Plan A','doing',0,1)",
            [],
        )
        .expect("plans");
    db.connection()
        .execute(
            "INSERT INTO waves(id,plan_id,wave_id,name,status,tasks_done,tasks_total,position) VALUES(10,1,'W1','Wave 1','pending',0,1,1)",
            [],
        )
        .expect("waves");
    db.connection()
        .execute(
            "INSERT INTO tasks(id,project_id,plan_id,wave_id_fk,wave_id,task_id,title,status) VALUES(100,'p1',1,10,'W1','T1','Task 1','pending')",
            [],
        )
        .expect("tasks");

    let args = UpdateTaskArgs {
        notes: Some("x'; DROP TABLE tasks; --".to_string()),
        ..UpdateTaskArgs::default()
    };
    db.update_task(100, TaskStatus::InProgress, &args)
        .expect("update-task");
    let count: i64 = db
        .connection()
        .query_row("SELECT COUNT(*) FROM tasks", [], |row| row.get(0))
        .expect("tasks still exists");
    assert_eq!(count, 1);
}

#[test]
fn db_validate_task_submitted_to_done() {
    let db = PlanDb::open_in_memory().expect("db");
    seed_schema(&db);
    db.connection()
        .execute("INSERT INTO projects(id,name) VALUES('p1','P1')", [])
        .expect("projects");
    db.connection()
        .execute(
            "INSERT INTO plans(id,project_id,name,status,tasks_done,tasks_total) VALUES(1,'p1','Plan A','doing',0,1)",
            [],
        )
        .expect("plans");
    db.connection()
        .execute(
            "INSERT INTO waves(id,plan_id,wave_id,name,status,tasks_done,tasks_total,position) VALUES(10,1,'W1','Wave 1','pending',0,1,1)",
            [],
        )
        .expect("waves");
    db.connection()
        .execute(
            "INSERT INTO tasks(id,project_id,plan_id,wave_id_fk,wave_id,task_id,title,status) VALUES(100,'p1',1,10,'W1','T1','Task 1','submitted')",
            [],
        )
        .expect("tasks");

    let args = ValidateTaskArgs {
        identifier: "100".to_string(),
        validated_by: "thor".to_string(),
        ..ValidateTaskArgs::default()
    };
    let result = db.validate_task(&args).expect("validate-task");
    assert_eq!(result.old_status, "submitted");
    assert_eq!(result.new_status, "done");
}

#[test]
fn db_execution_tree_contains_waves_and_tasks() {
    let db = PlanDb::open_in_memory().expect("db");
    seed_schema(&db);
    db.connection()
        .execute("INSERT INTO projects(id,name) VALUES('p1','P1')", [])
        .expect("projects");
    db.connection()
        .execute(
            "INSERT INTO plans(id,project_id,name,status,tasks_done,tasks_total) VALUES(1,'p1','Plan A','doing',1,2)",
            [],
        )
        .expect("plans");
    db.connection()
        .execute(
            "INSERT INTO waves(id,plan_id,wave_id,name,status,tasks_done,tasks_total,position) VALUES(10,1,'W1','Wave 1','in_progress',1,2,1)",
            [],
        )
        .expect("waves");
    db.connection()
        .execute(
            "INSERT INTO tasks(id,project_id,plan_id,wave_id_fk,wave_id,task_id,title,status) VALUES
             (100,'p1',1,10,'W1','T1','Task 1','done'),
             (101,'p1',1,10,'W1','T2','Task 2','pending')",
            [],
        )
        .expect("tasks");

    let tree = db.execution_tree(1).expect("execution-tree");
    assert_eq!(tree.waves.len(), 1);
    assert_eq!(tree.waves[0].tasks.len(), 2);
}

#[test]
fn db_crdt_required_tables_are_declared() {
    let tables = super::crdt::required_crdt_tables();
    assert_eq!(
        tables,
        vec!["plan_reviews", "tasks", "waves", "host_heartbeats"]
    );
}

#[test]
fn db_crdt_sync_subcommand_is_supported() {
    let db = PlanDb::open_in_memory().expect("db");
    seed_schema(&db);
    let error = db
        .run_subcommand(&["sync".to_string()])
        .expect_err("sync should require peer argument");
    assert!(error.to_string().contains("usage: sync <peer>"));
}
