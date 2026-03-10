use crate::db::PlanDb;
use axum::http::StatusCode;
use axum::response::{IntoResponse, Response};
use axum::Json;
use rusqlite::types::ValueRef;
use rusqlite::{Connection, Params, Row};
use serde_json::{json, Map, Value};
use std::collections::HashSet;
use std::path::PathBuf;
use tokio::sync::broadcast;

const AGENT_ACTIVITY_SCHEMA: &str =
    "CREATE TABLE IF NOT EXISTS agent_activity (id INTEGER PRIMARY KEY AUTOINCREMENT, agent_id TEXT NOT NULL, task_db_id INTEGER, plan_id INTEGER, agent_type TEXT NOT NULL, model TEXT, description TEXT, status TEXT NOT NULL DEFAULT 'running', tokens_in INTEGER DEFAULT 0, tokens_out INTEGER DEFAULT 0, tokens_total INTEGER DEFAULT 0, cost_usd REAL DEFAULT 0, started_at TEXT NOT NULL DEFAULT (datetime('now')), completed_at TEXT, duration_s REAL, host TEXT, region TEXT, metadata TEXT, parent_session TEXT)";

const AGENT_ACTIVITY_COLUMNS: &[(&str, &str)] = &[
    ("agent_type", "TEXT NOT NULL DEFAULT 'legacy'"),
    ("model", "TEXT"),
    ("description", "TEXT"),
    ("status", "TEXT NOT NULL DEFAULT 'completed'"),
    ("tokens_in", "INTEGER DEFAULT 0"),
    ("tokens_out", "INTEGER DEFAULT 0"),
    ("tokens_total", "INTEGER DEFAULT 0"),
    ("cost_usd", "REAL DEFAULT 0"),
    ("started_at", "TEXT"),
    ("completed_at", "TEXT"),
    ("duration_s", "REAL"),
    ("host", "TEXT"),
    ("region", "TEXT"),
    ("metadata", "TEXT"),
    ("parent_session", "TEXT"),
];

fn table_columns(conn: &Connection, table: &str) -> Result<HashSet<String>, ApiError> {
    let sql = format!("PRAGMA table_info({table})");
    let mut stmt = conn
        .prepare(&sql)
        .map_err(|err| ApiError::internal(format!("table info prepare failed: {err}")))?;
    let rows = stmt
        .query_map([], |row| row.get::<_, String>(1))
        .map_err(|err| ApiError::internal(format!("table info query failed: {err}")))?;
    let columns = rows
        .collect::<rusqlite::Result<Vec<_>>>()
        .map_err(|err| ApiError::internal(format!("table info decode failed: {err}")))?;
    Ok(columns.into_iter().collect())
}

fn ensure_agent_activity_schema(conn: &Connection) -> Result<(), ApiError> {
    conn.execute_batch(AGENT_ACTIVITY_SCHEMA)
        .map_err(|err| ApiError::internal(format!("agent_activity create failed: {err}")))?;

    let mut columns = table_columns(conn, "agent_activity")?;
    for (name, spec) in AGENT_ACTIVITY_COLUMNS {
        if columns.contains(*name) {
            continue;
        }
        conn.execute_batch(&format!(
            "ALTER TABLE agent_activity ADD COLUMN {name} {spec}"
        ))
        .map_err(|err| ApiError::internal(format!("agent_activity alter failed: {err}")))?;
        columns.insert((*name).to_string());
    }

    if columns.contains("action") {
        conn.execute_batch("UPDATE agent_activity SET agent_type = COALESCE(NULLIF(action,''), NULLIF(agent_type,''), 'legacy') WHERE action IS NOT NULL AND action != ''")
            .map_err(|err| ApiError::internal(format!("agent_activity type backfill failed: {err}")))?;
    }
    if columns.contains("details") {
        conn.execute_batch("UPDATE agent_activity SET description = COALESCE(NULLIF(description,''), NULLIF(details,'')) WHERE (description IS NULL OR description = '') AND details IS NOT NULL")
            .map_err(|err| ApiError::internal(format!("agent_activity description backfill failed: {err}")))?;
    }
    if columns.contains("created_at") {
        conn.execute_batch("UPDATE agent_activity SET started_at = COALESCE(NULLIF(started_at,''), created_at, datetime('now')) WHERE started_at IS NULL OR started_at = ''")
            .map_err(|err| ApiError::internal(format!("agent_activity started_at backfill failed: {err}")))?;
    }
    conn.execute_batch(
        "UPDATE agent_activity SET agent_type = COALESCE(NULLIF(agent_type,''), 'legacy') WHERE COALESCE(agent_type,'') = '';
         UPDATE agent_activity SET model = COALESCE(NULLIF(model,''), agent_type, 'unknown') WHERE COALESCE(model,'') = '';
         UPDATE agent_activity SET status = COALESCE(NULLIF(status,''), 'completed') WHERE COALESCE(status,'') = '';
         UPDATE agent_activity SET region = COALESCE(NULLIF(region,''), 'prefrontal') WHERE COALESCE(region,'') = '';
         UPDATE agent_activity SET started_at = COALESCE(NULLIF(started_at,''), datetime('now')) WHERE started_at IS NULL OR started_at = '';
         DELETE FROM agent_activity WHERE id NOT IN (SELECT MAX(id) FROM agent_activity GROUP BY agent_id);
         CREATE UNIQUE INDEX IF NOT EXISTS uq_agent_activity_agent_id ON agent_activity(agent_id);",
    )
    .map_err(|err| ApiError::internal(format!("agent_activity repair failed: {err}")))?;

    Ok(())
}

#[derive(Clone, Debug)]
pub struct ServerState {
    pub db_path: PathBuf,
    pub ws_tx: broadcast::Sender<Value>,
}

impl ServerState {
    pub fn new(db_path: PathBuf) -> Self {
        if let Ok(conn) = Connection::open(&db_path) {
            let _ = conn.execute_batch("PRAGMA journal_mode=WAL; PRAGMA synchronous=NORMAL;");
            if let Err(err) = ensure_agent_activity_schema(&conn) {
                eprintln!("[migration] agent_activity schema repair failed: {err:?}");
            }
            let migrations = &[
                // Tables
                "CREATE TABLE IF NOT EXISTS agent_runs (id INTEGER PRIMARY KEY AUTOINCREMENT, plan_id INTEGER, wave_id TEXT, task_id TEXT, agent_name TEXT, agent_role TEXT, model TEXT, peer_name TEXT, status TEXT DEFAULT 'running', started_at TEXT DEFAULT (datetime('now')), last_heartbeat TEXT, current_task TEXT)",
                "CREATE TABLE IF NOT EXISTS nightly_jobs (id INTEGER PRIMARY KEY AUTOINCREMENT, run_id TEXT, job_name TEXT DEFAULT 'guardian', started_at DATETIME DEFAULT CURRENT_TIMESTAMP, finished_at DATETIME, host TEXT, status TEXT NOT NULL CHECK(status IN ('running','ok','action_required','failed')), sentry_unresolved INTEGER DEFAULT 0, github_open_issues INTEGER DEFAULT 0, processed_items INTEGER DEFAULT 0, fixed_items INTEGER DEFAULT 0, branch_name TEXT, pr_url TEXT, summary TEXT, report_json TEXT)",
                "CREATE TABLE IF NOT EXISTS nightly_job_definitions (id INTEGER PRIMARY KEY AUTOINCREMENT, name TEXT NOT NULL UNIQUE, description TEXT, schedule TEXT NOT NULL DEFAULT '0 3 * * *', script_path TEXT NOT NULL, target_host TEXT DEFAULT 'local', enabled INTEGER NOT NULL DEFAULT 1, created_at DATETIME DEFAULT CURRENT_TIMESTAMP)",
                "CREATE TABLE IF NOT EXISTS github_events (id INTEGER PRIMARY KEY AUTOINCREMENT, plan_id INTEGER, event_type TEXT, status TEXT DEFAULT 'pending', created_at TEXT DEFAULT (datetime('now')))",
                "CREATE TABLE IF NOT EXISTS earned_skills (id INTEGER PRIMARY KEY AUTOINCREMENT, name TEXT NOT NULL UNIQUE, domain TEXT, content TEXT NOT NULL, confidence TEXT DEFAULT 'low', hit_count INTEGER DEFAULT 0, source TEXT DEFAULT 'earned', created_at TEXT DEFAULT (datetime('now')), updated_at TEXT DEFAULT (datetime('now')))",
                "CREATE TABLE IF NOT EXISTS plan_commits (id INTEGER PRIMARY KEY AUTOINCREMENT, plan_id INTEGER, commit_sha TEXT, commit_message TEXT, lines_added INTEGER DEFAULT 0, lines_removed INTEGER DEFAULT 0, files_changed INTEGER DEFAULT 0, authored_at TEXT, created_at TEXT DEFAULT (datetime('now')))",
                // Performance indexes — agent_activity
                "CREATE INDEX IF NOT EXISTS idx_agent_activity_status ON agent_activity(status)",
                "CREATE INDEX IF NOT EXISTS idx_agent_activity_plan ON agent_activity(plan_id)",
                "CREATE INDEX IF NOT EXISTS idx_agent_activity_task ON agent_activity(task_db_id)",
                "CREATE INDEX IF NOT EXISTS idx_agent_activity_started_at ON agent_activity(started_at DESC)",
                "CREATE INDEX IF NOT EXISTS idx_agent_activity_status_started ON agent_activity(status, started_at DESC)",
                "CREATE INDEX IF NOT EXISTS idx_agent_activity_status_completed ON agent_activity(status, completed_at DESC)",
                "CREATE INDEX IF NOT EXISTS idx_agent_activity_model ON agent_activity(model)",
                // Performance indexes — agent_runs
                "CREATE INDEX IF NOT EXISTS idx_agent_runs_started_at ON agent_runs(started_at DESC)",
                "CREATE INDEX IF NOT EXISTS idx_agent_runs_status ON agent_runs(status)",
                "CREATE INDEX IF NOT EXISTS idx_agent_runs_peer ON agent_runs(peer_name)",
                // Performance indexes — mesh/events/tokens
                "CREATE INDEX IF NOT EXISTS idx_nightly_jobs_started ON nightly_jobs(started_at DESC)",
                "CREATE INDEX IF NOT EXISTS idx_mesh_events_created_at ON mesh_events(created_at DESC)",
                "CREATE INDEX IF NOT EXISTS idx_mesh_events_status ON mesh_events(status)",
                "CREATE INDEX IF NOT EXISTS idx_token_usage_model ON token_usage(model)",
                "CREATE INDEX IF NOT EXISTS idx_token_usage_created_at ON token_usage(created_at)",
                "CREATE INDEX IF NOT EXISTS idx_github_events_plan_status ON github_events(plan_id, status)",
                "CREATE INDEX IF NOT EXISTS idx_plan_commits_plan_id ON plan_commits(plan_id)",
                "CREATE INDEX IF NOT EXISTS idx_projects_name ON projects(name COLLATE NOCASE)",
                // Ideas tables
                "CREATE TABLE IF NOT EXISTS ideas (id INTEGER PRIMARY KEY AUTOINCREMENT, title TEXT NOT NULL, description TEXT, tags TEXT, priority TEXT DEFAULT 'P2' CHECK(priority IN ('P0','P1','P2','P3')), status TEXT DEFAULT 'draft' CHECK(status IN ('draft','elaborating','ready','promoted','archived')), project_id TEXT REFERENCES projects(id) ON DELETE SET NULL, links TEXT, plan_id INTEGER, created_at DATETIME DEFAULT CURRENT_TIMESTAMP, updated_at DATETIME DEFAULT CURRENT_TIMESTAMP)",
                "CREATE TABLE IF NOT EXISTS idea_notes (id INTEGER PRIMARY KEY AUTOINCREMENT, idea_id INTEGER NOT NULL REFERENCES ideas(id) ON DELETE CASCADE, content TEXT NOT NULL, created_at DATETIME DEFAULT CURRENT_TIMESTAMP)",
                "CREATE INDEX IF NOT EXISTS idx_ideas_status ON ideas(status)",
                "CREATE INDEX IF NOT EXISTS idx_ideas_project ON ideas(project_id)",
                "CREATE INDEX IF NOT EXISTS idx_idea_notes_idea ON idea_notes(idea_id)",
                // ALTER TABLE migrations
                "ALTER TABLE nightly_jobs ADD COLUMN job_name TEXT DEFAULT 'guardian'",
                "ALTER TABLE nightly_jobs ADD COLUMN log_stdout TEXT",
                "ALTER TABLE nightly_jobs ADD COLUMN log_stderr TEXT",
                "ALTER TABLE nightly_jobs ADD COLUMN log_file_path TEXT",
                "ALTER TABLE nightly_jobs ADD COLUMN duration_sec INTEGER",
                "ALTER TABLE nightly_jobs ADD COLUMN config_snapshot TEXT",
                "ALTER TABLE nightly_jobs ADD COLUMN exit_code INTEGER",
                "ALTER TABLE nightly_jobs ADD COLUMN error_detail TEXT",
                "ALTER TABLE nightly_jobs ADD COLUMN trigger_source TEXT DEFAULT 'scheduled'",
                "ALTER TABLE nightly_jobs ADD COLUMN parent_run_id TEXT",
                "ALTER TABLE nightly_job_definitions ADD COLUMN project_id TEXT DEFAULT 'mirrorbuddy'",
                "ALTER TABLE nightly_job_definitions ADD COLUMN run_fixes INTEGER DEFAULT 1",
                "ALTER TABLE nightly_job_definitions ADD COLUMN timeout_sec INTEGER DEFAULT 5400",
                "ALTER TABLE agent_activity ADD COLUMN parent_session TEXT",
            ];
            let mut ok = 0;
            let mut skip = 0;
            for sql in migrations {
                match conn.execute_batch(sql) {
                    Ok(_) => ok += 1,
                    Err(e) => {
                        let msg = e.to_string();
                        if msg.contains("duplicate column") || msg.contains("already exists") {
                            skip += 1;
                        } else {
                            let preview: String = sql.chars().take(50).collect();
                            eprintln!("[migration] ERROR on '{preview}...': {e}");
                        }
                    }
                }
            }
            // Verify critical tables exist
            let check = conn.prepare(
                "SELECT name FROM sqlite_master WHERE type='table' AND name='agent_activity'",
            );
            let exists = check
                .map(|mut s| s.exists([]))
                .unwrap_or(Ok(false))
                .unwrap_or(false);
            if !exists {
                eprintln!("[migration] CRITICAL: agent_activity table missing after migration!");
            }
            eprintln!(
                "[migration] {ok} applied, {skip} skipped (already exist), agent_activity={exists}"
            );
        }
        let (ws_tx, _) = broadcast::channel(256);
        Self { db_path, ws_tx }
    }

    pub fn open_db(&self) -> Result<PlanDb, ApiError> {
        PlanDb::open_sqlite_path(&self.db_path)
            .map_err(|err| ApiError::internal(format!("db open failed: {err}")))
    }
}

#[derive(Debug)]
pub struct ApiError {
    status: StatusCode,
    message: String,
}

impl ApiError {
    pub fn bad_request(message: impl Into<String>) -> Self {
        Self {
            status: StatusCode::BAD_REQUEST,
            message: message.into(),
        }
    }

    pub fn internal(message: impl Into<String>) -> Self {
        Self {
            status: StatusCode::INTERNAL_SERVER_ERROR,
            message: message.into(),
        }
    }
}

impl IntoResponse for ApiError {
    fn into_response(self) -> Response {
        (
            self.status,
            Json(json!({"ok": false, "error": self.message})),
        )
            .into_response()
    }
}

pub fn query_rows<P: Params>(
    conn: &Connection,
    sql: &str,
    params: P,
) -> Result<Vec<Value>, ApiError> {
    let mut stmt = conn
        .prepare(sql)
        .map_err(|err| ApiError::internal(format!("prepare failed: {err}")))?;
    let rows = stmt
        .query_map(params, row_to_json)
        .map_err(|err| ApiError::internal(format!("query failed: {err}")))?;
    rows.collect::<rusqlite::Result<Vec<_>>>()
        .map_err(|err| ApiError::internal(format!("row decode failed: {err}")))
}

pub fn query_one<P: Params>(
    conn: &Connection,
    sql: &str,
    params: P,
) -> Result<Option<Value>, ApiError> {
    Ok(query_rows(conn, sql, params)?.into_iter().next())
}

fn row_to_json(row: &Row<'_>) -> rusqlite::Result<Value> {
    let mut object = Map::new();
    for (idx, column) in row.as_ref().column_names().iter().enumerate() {
        let value = row.get_ref(idx)?;
        let json_value = match value {
            ValueRef::Null => Value::Null,
            ValueRef::Integer(v) => Value::from(v),
            ValueRef::Real(v) => Value::from(v),
            ValueRef::Text(v) => Value::from(String::from_utf8_lossy(v).to_string()),
            ValueRef::Blob(v) => Value::from(format!("blob:{}", v.len())),
        };
        object.insert((*column).to_string(), json_value);
    }
    Ok(Value::Object(object))
}
