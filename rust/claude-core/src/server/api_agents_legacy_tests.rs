use axum::body::Body;
use axum::http::{Request, StatusCode};
use rusqlite::Connection;
use serde_json::Value;
use std::path::PathBuf;
use std::sync::atomic::{AtomicU64, Ordering};
use tower::ServiceExt;

const LEGACY_AGENT_ACTIVITY_SCHEMA: &str = "
CREATE TABLE agent_activity (
  id INTEGER PRIMARY KEY NOT NULL,
  agent_id TEXT NOT NULL DEFAULT '',
  task_db_id INTEGER,
  plan_id INTEGER,
  action TEXT NOT NULL DEFAULT '',
  details TEXT,
  created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
  parent_session TEXT
);
";

fn legacy_db_path() -> PathBuf {
    static COUNTER: AtomicU64 = AtomicU64::new(0);
    let n = COUNTER.fetch_add(1, Ordering::SeqCst);
    let tmp =
        std::env::temp_dir().join(format!("claude-legacy-agent-{}-{n}.db", std::process::id()));
    let conn = Connection::open(&tmp).expect("open legacy db");
    conn.execute_batch(LEGACY_AGENT_ACTIVITY_SCHEMA)
        .expect("legacy schema");
    drop(conn);
    tmp
}

fn legacy_router(db_path: &PathBuf) -> axum::Router {
    super::routes::build_router_with_db(PathBuf::from("/tmp"), db_path.clone())
}

async fn get(router: &axum::Router, uri: &str) -> (StatusCode, Value) {
    let req = Request::builder().uri(uri).body(Body::empty()).unwrap();
    let resp = router.clone().oneshot(req).await.unwrap();
    let status = resp.status();
    let body = axum::body::to_bytes(resp.into_body(), 1_000_000)
        .await
        .unwrap();
    let json: Value = serde_json::from_slice(&body).unwrap_or(Value::Null);
    (status, json)
}

#[tokio::test]
async fn legacy_agent_activity_schema_is_upgraded_for_brain_routes() {
    let db_path = legacy_db_path();
    let router = legacy_router(&db_path);
    let conn = Connection::open(&db_path).expect("open migrated db");

    let columns: Vec<String> = {
        let mut stmt = conn.prepare("PRAGMA table_info(agent_activity)").unwrap();
        stmt.query_map([], |row| row.get::<_, String>(1))
            .unwrap()
            .collect::<rusqlite::Result<Vec<_>>>()
            .unwrap()
    };
    for required in [
        "agent_type",
        "description",
        "status",
        "started_at",
        "model",
        "metadata",
    ] {
        assert!(
            columns.iter().any(|name| name == required),
            "missing column {required}"
        );
    }

    conn.execute(
        "INSERT INTO agent_activity(agent_id, agent_type, description, status, started_at, model, host, region, metadata)
         VALUES(?1, ?2, ?3, 'running', datetime('now'), ?4, 'local', 'prefrontal', '{\"tty\":\"s001\"}')
         ON CONFLICT(agent_id) DO UPDATE SET description=excluded.description",
        rusqlite::params![
            "session-copilot-cli-101",
            "copilot-cli",
            "Copilot primary shell",
            "copilot-cli"
        ],
    )
    .unwrap();
    conn.execute(
        "INSERT INTO agent_activity(agent_id, agent_type, description, status, started_at, model, parent_session)
         VALUES(?1, 'task', 'Sub-agent worker', 'running', datetime('now'), 'gpt-5.4', ?2)",
        rusqlite::params!["worker-1", "session-copilot-cli-101"],
    )
    .unwrap();

    let unique_indexes: Vec<String> = {
        let mut stmt = conn.prepare("PRAGMA index_list(agent_activity)").unwrap();
        stmt.query_map([], |row| {
            let is_unique: i64 = row.get(2)?;
            let name: String = row.get(1)?;
            Ok((is_unique, name))
        })
        .unwrap()
        .collect::<rusqlite::Result<Vec<_>>>()
        .unwrap()
        .into_iter()
        .filter_map(|(is_unique, name)| (is_unique == 1).then_some(name))
        .collect()
    };
    assert!(
        unique_indexes
            .iter()
            .any(|name| name == "uq_agent_activity_agent_id"),
        "missing unique agent_activity index"
    );
    drop(conn);

    let (sessions_status, sessions_json) = get(&router, "/api/sessions").await;
    assert_eq!(sessions_status, StatusCode::OK);
    let sessions = sessions_json.as_array().expect("sessions array");
    assert_eq!(sessions.len(), 1);
    assert_eq!(sessions[0]["agent_id"], "session-copilot-cli-101");
    assert_eq!(sessions[0]["type"], "copilot-cli");

    let (brain_status, brain_json) = get(&router, "/api/brain").await;
    assert_eq!(brain_status, StatusCode::OK);
    assert_eq!(brain_json["sessions"].as_array().unwrap().len(), 1);
    assert_eq!(brain_json["agents"].as_array().unwrap().len(), 1);
    assert_eq!(
        brain_json["agents"][0]["parent_session"],
        "session-copilot-cli-101"
    );
}

#[tokio::test]
async fn legacy_agent_activity_rows_are_backfilled_safely() {
    let db_path = legacy_db_path();
    let conn = Connection::open(&db_path).expect("open legacy db");
    conn.execute(
        "INSERT INTO agent_activity(agent_id, action, details, created_at, parent_session)
         VALUES(?1, ?2, ?3, ?4, ?5)",
        rusqlite::params![
            "session-legacy-42",
            "copilot-cli",
            "Legacy details",
            "2026-03-10 10:11:12",
            "session-parent-1"
        ],
    )
    .unwrap();
    drop(conn);

    let _router = legacy_router(&db_path);
    let conn = Connection::open(&db_path).expect("open migrated db");
    let row = conn
        .query_row(
            "SELECT agent_type, description, status, started_at, parent_session
             FROM agent_activity WHERE agent_id = ?1",
            rusqlite::params!["session-legacy-42"],
            |row| {
                Ok((
                    row.get::<_, String>(0)?,
                    row.get::<_, String>(1)?,
                    row.get::<_, String>(2)?,
                    row.get::<_, String>(3)?,
                    row.get::<_, String>(4)?,
                ))
            },
        )
        .unwrap();

    assert_eq!(row.0, "copilot-cli");
    assert_eq!(row.1, "Legacy details");
    assert_eq!(row.2, "completed");
    assert_eq!(row.3, "2026-03-10 10:11:12");
    assert_eq!(row.4, "session-parent-1");
}
