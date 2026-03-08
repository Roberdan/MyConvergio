use crate::db::PlanDb;
use axum::http::StatusCode;
use axum::response::{IntoResponse, Response};
use axum::Json;
use rusqlite::types::ValueRef;
use rusqlite::{Connection, Params, Row};
use serde_json::{json, Map, Value};
use std::path::PathBuf;
use tokio::sync::broadcast;

#[derive(Clone, Debug)]
pub struct ServerState {
    pub db_path: PathBuf,
    pub ws_tx: broadcast::Sender<Value>,
}

impl ServerState {
    pub fn new(db_path: PathBuf) -> Self {
        if let Ok(conn) = Connection::open(&db_path) {
            // Run each migration separately so one failure doesn't block the rest
            let migrations = &[
                "CREATE TABLE IF NOT EXISTS agent_activity (id INTEGER PRIMARY KEY AUTOINCREMENT, agent_id TEXT NOT NULL, task_db_id INTEGER, plan_id INTEGER, agent_type TEXT NOT NULL, model TEXT, description TEXT, status TEXT NOT NULL DEFAULT 'running', tokens_in INTEGER DEFAULT 0, tokens_out INTEGER DEFAULT 0, tokens_total INTEGER DEFAULT 0, cost_usd REAL DEFAULT 0, started_at TEXT NOT NULL DEFAULT (datetime('now')), completed_at TEXT, duration_s REAL, host TEXT, region TEXT, metadata TEXT, parent_session TEXT)",
                "CREATE INDEX IF NOT EXISTS idx_agent_activity_status ON agent_activity(status)",
                "CREATE INDEX IF NOT EXISTS idx_agent_activity_plan ON agent_activity(plan_id)",
                "CREATE INDEX IF NOT EXISTS idx_agent_activity_task ON agent_activity(task_db_id)",
                "CREATE TABLE IF NOT EXISTS agent_runs (id INTEGER PRIMARY KEY AUTOINCREMENT, plan_id INTEGER, wave_id TEXT, task_id TEXT, agent_name TEXT, agent_role TEXT, model TEXT, peer_name TEXT, status TEXT DEFAULT 'running', started_at TEXT DEFAULT (datetime('now')), last_heartbeat TEXT, current_task TEXT)",
                "CREATE TABLE IF NOT EXISTS nightly_jobs (id INTEGER PRIMARY KEY AUTOINCREMENT, run_id TEXT, job_name TEXT DEFAULT 'guardian', started_at DATETIME DEFAULT CURRENT_TIMESTAMP, finished_at DATETIME, host TEXT, status TEXT NOT NULL CHECK(status IN ('running','ok','action_required','failed')), sentry_unresolved INTEGER DEFAULT 0, github_open_issues INTEGER DEFAULT 0, processed_items INTEGER DEFAULT 0, fixed_items INTEGER DEFAULT 0, branch_name TEXT, pr_url TEXT, summary TEXT, report_json TEXT)",
                "CREATE INDEX IF NOT EXISTS idx_nightly_jobs_started ON nightly_jobs(started_at DESC)",
                "CREATE TABLE IF NOT EXISTS nightly_job_definitions (id INTEGER PRIMARY KEY AUTOINCREMENT, name TEXT NOT NULL UNIQUE, description TEXT, schedule TEXT NOT NULL DEFAULT '0 3 * * *', script_path TEXT NOT NULL, target_host TEXT DEFAULT 'local', enabled INTEGER NOT NULL DEFAULT 1, created_at DATETIME DEFAULT CURRENT_TIMESTAMP)",
                "CREATE TABLE IF NOT EXISTS github_events (id INTEGER PRIMARY KEY AUTOINCREMENT, plan_id INTEGER, event_type TEXT, status TEXT, payload TEXT, created_at TEXT DEFAULT (datetime('now')))",
                "CREATE INDEX IF NOT EXISTS idx_github_events_plan ON github_events(plan_id)",
                "ALTER TABLE nightly_jobs ADD COLUMN job_name TEXT DEFAULT 'guardian'",
                "ALTER TABLE agent_activity ADD COLUMN parent_session TEXT",
            ];
            for sql in migrations {
                if let Err(e) = conn.execute_batch(sql) {
                    let preview: String = sql.chars().take(60).collect();
                    eprintln!("[migration] ignored error on '{preview}...': {e}");
                }
            }
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
        (self.status, Json(json!({"ok": false, "error": self.message}))).into_response()
    }
}

pub fn query_rows<P: Params>(conn: &Connection, sql: &str, params: P) -> Result<Vec<Value>, ApiError> {
    let mut stmt = conn
        .prepare(sql)
        .map_err(|err| ApiError::internal(format!("prepare failed: {err}")))?;
    let rows = stmt
        .query_map(params, row_to_json)
        .map_err(|err| ApiError::internal(format!("query failed: {err}")))?;
    rows.collect::<rusqlite::Result<Vec<_>>>()
        .map_err(|err| ApiError::internal(format!("row decode failed: {err}")))
}

pub fn query_one<P: Params>(conn: &Connection, sql: &str, params: P) -> Result<Option<Value>, ApiError> {
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
