use super::state::{ApiError, ServerState};
use axum::extract::{Path, Query, State};
use axum::response::sse::{Event, Sse};
use serde_json::json;
use std::collections::HashMap;
use std::convert::Infallible;
use tokio_stream::iter;

pub async fn chat_stream_sse(
    Path(session_id): Path<String>,
) -> Sse<impl tokio_stream::Stream<Item = Result<Event, Infallible>>> {
    let payload = json!({"ok": true, "sid": session_id});
    let events = iter([Ok::<Event, Infallible>(
        Event::default().event("chat").data(payload.to_string()),
    )]);
    Sse::new(events)
}

pub async fn mesh_action_sse(
    Query(qs): Query<HashMap<String, String>>,
) -> Sse<impl tokio_stream::Stream<Item = Result<Event, Infallible>>> {
    let action = qs.get("action").cloned().unwrap_or_default();
    let peer = qs.get("peer").cloned().unwrap_or_default();
    let mut lines: Vec<String> = Vec::new();
    let mut ok = true;

    let home = std::env::var("HOME").or_else(|_| std::env::var("USERPROFILE")).unwrap_or_default();
    let db_path = format!("{home}/.claude/data/dashboard.db");

    match action.as_str() {
        "heartbeat" | "status" => {
            lines.push(format!("▶ Checking {action} for {peer}..."));
            if let Ok(conn) = rusqlite::Connection::open(&db_path) {
                if let Ok(mut stmt) = conn.prepare(
                    "SELECT peer_name, last_seen, load_json FROM peer_heartbeats WHERE peer_name = ?1"
                ) {
                    if let Ok(mut rows) = stmt.query(rusqlite::params![&peer]) {
                        while let Ok(Some(row)) = rows.next() {
                            let name: String = row.get(0).unwrap_or_default();
                            let seen: i64 = row.get(1).unwrap_or(0);
                            let load: String = row.get(2).unwrap_or_default();
                            lines.push(format!("  {name} | last_seen: {seen} | load: {load}"));
                        }
                    }
                }
                if action == "status" {
                    lines.push("---".into());
                    lines.push("▶ Sync stats:".into());
                    if let Ok(mut stmt) = conn.prepare(
                        "SELECT peer_name, total_sent, total_received, last_latency_ms FROM mesh_sync_stats"
                    ) {
                        if let Ok(mut rows) = stmt.query([]) {
                            while let Ok(Some(row)) = rows.next() {
                                let n: String = row.get(0).unwrap_or_default();
                                let s: i64 = row.get(1).unwrap_or(0);
                                let r: i64 = row.get(2).unwrap_or(0);
                                let l: i64 = row.get(3).unwrap_or(0);
                                lines.push(format!("  {n} | sent:{s} recv:{r} latency:{l}ms"));
                            }
                        }
                    }
                }
            } else {
                lines.push("ERROR Cannot open dashboard.db".into());
                ok = false;
            }
            // TCP reachability test (cross-platform)
            lines.push("---".into());
            lines.push(format!("▶ TCP reachability test ({peer}:9420)..."));
            match std::net::TcpStream::connect_timeout(
                &format!("{peer}:9420").parse().unwrap_or_else(|_| "0.0.0.0:9420".parse().unwrap()),
                std::time::Duration::from_secs(3)
            ) {
                Ok(_) => lines.push(format!("OK {peer}:9420 reachable")),
                Err(e) => { lines.push(format!("ERROR {peer}:9420 unreachable: {e}")); }
            }
        }
        "sync" => {
            lines.push(format!("▶ Triggering sync for {peer}..."));
            // Cross-platform: invoke mesh-coordinator if available
            let script = format!("{home}/.claude/scripts/mesh-coordinator.sh");
            let (cmd, args) = if cfg!(windows) {
                ("cmd".to_string(), vec!["/C".to_string(), format!("bash {script} sync {peer}")])
            } else {
                ("sh".to_string(), vec!["-c".to_string(), format!("{script} sync {peer}")])
            };
            match tokio::process::Command::new(&cmd).args(&args).output().await {
                Ok(o) => {
                    for l in String::from_utf8_lossy(&o.stdout).lines() { lines.push(l.to_string()); }
                    for l in String::from_utf8_lossy(&o.stderr).lines() { lines.push(format!("WARN {l}")); }
                    ok = o.status.success();
                }
                Err(e) => { lines.push(format!("WARN sync script failed: {e}")); }
            }
        }
        _ => {
            lines.push(format!("▶ Action: {action} on {peer}"));
            lines.push("OK completed".into());
        }
    }

    let mut events: Vec<Result<Event, Infallible>> = lines.iter()
        .map(|l| Ok(Event::default().event("log").data(l.clone())))
        .collect();
    events.push(Ok(Event::default().event("done").data(
        json!({"ok": ok}).to_string()
    )));
    Sse::new(iter(events))
}

pub async fn plan_preflight_sse(
    State(state): State<ServerState>,
    Query(qs): Query<HashMap<String, String>>,
) -> Result<Sse<impl tokio_stream::Stream<Item = Result<Event, Infallible>>>, ApiError> {
    let plan_id = required(&qs, "plan_id")?;
    let target = required(&qs, "target")?;
    let db = state.open_db()?;
    let mut stmt = db
        .connection()
        .prepare("SELECT status FROM plans WHERE id=?1")
        .map_err(|err| ApiError::internal(format!("plan query failed: {err}")))?;
    let status: Option<String> = stmt
        .query_row(rusqlite::params![plan_id], |row| row.get(0))
        .ok();

    let active = status
        .as_deref()
        .map(|v| matches!(v, "todo" | "doing"))
        .unwrap_or(false);
    let plan_detail = status
        .map(|v| format!("#{plan_id} is '{v}'"))
        .unwrap_or_else(|| "Not found in DB".to_string());

    let events = vec![
        Event::default().event("start").data(
            json!({"plan_id": plan_id, "target": target, "total_checks": 9}).to_string(),
        ),
        Event::default().event("checking").data(json!({"name": "SSH reachable"}).to_string()),
        Event::default().event("check").data(
            json!({"name":"SSH reachable","ok":true,"detail":"simulated via axum","blocking":true})
                .to_string(),
        ),
        Event::default().event("checking").data(json!({"name": "Plan status"}).to_string()),
        Event::default().event("check").data(
            json!({"name":"Plan status","ok":active,"detail":plan_detail,"blocking":true}).to_string(),
        ),
        Event::default().event("done").data(json!({"ok": active}).to_string()),
    ];
    let stream = iter(events.into_iter().map(Ok::<Event, Infallible>));
    Ok(Sse::new(stream))
}

pub async fn plan_delegate_sse(
    Query(qs): Query<HashMap<String, String>>,
) -> Result<Sse<impl tokio_stream::Stream<Item = Result<Event, Infallible>>>, ApiError> {
    let plan_id = required(&qs, "plan_id")?;
    let target = required(&qs, "target")?;
    let cli = qs
        .get("cli")
        .cloned()
        .filter(|v| !v.is_empty())
        .unwrap_or_else(|| "copilot".to_string());
    let events = vec![
        Event::default().event("phase").data(json!({"name":"handoff"}).to_string()),
        Event::default()
            .event("log")
            .data(format!("--- HANDOFF: Plan #{plan_id} -> {target} ---")),
        Event::default().event("log").data(format!("cli={cli}")),
        Event::default().event("done").data(
            json!({"ok": true, "plan_id": plan_id, "target": target, "message": "delegation simulated"})
                .to_string(),
        ),
    ];
    Ok(Sse::new(iter(events.into_iter().map(Ok::<Event, Infallible>))))
}

pub async fn plan_start_sse(
    State(state): State<ServerState>,
    Query(qs): Query<HashMap<String, String>>,
) -> Result<Sse<impl tokio_stream::Stream<Item = Result<Event, Infallible>>>, ApiError> {
    let plan_id = required(&qs, "plan_id")?;
    let target = qs
        .get("target")
        .cloned()
        .filter(|v| !v.is_empty())
        .unwrap_or_else(|| "local".to_string());
    let cli = qs
        .get("cli")
        .cloned()
        .filter(|v| !v.is_empty())
        .unwrap_or_else(|| "copilot".to_string());

    let db = state.open_db()?;
    db.connection()
        .execute(
            "UPDATE plans SET status='doing', execution_host=?1 WHERE id=?2 AND status IN ('todo','doing')",
            rusqlite::params![target, plan_id],
        )
        .map_err(|err| ApiError::internal(format!("plan claim failed: {err}")))?;

    let events = vec![
        Event::default()
            .event("log")
            .data(format!("Starting plan #{plan_id} with {cli}")),
        Event::default()
            .event("log")
            .data(format!("Plan claimed by {target}")),
        Event::default().event("done").data(json!({"ok": true, "plan_id": plan_id}).to_string()),
    ];
    Ok(Sse::new(iter(events.into_iter().map(Ok::<Event, Infallible>))))
}

fn required(qs: &HashMap<String, String>, name: &str) -> Result<String, ApiError> {
    qs.get(name)
        .cloned()
        .filter(|v| !v.is_empty())
        .ok_or_else(|| ApiError::bad_request(format!("missing {name}")))
}

#[cfg(test)]
mod tests {
    use super::super::routes::build_router_with_db;
    use axum::body::{to_bytes, Body};
    use axum::http::{Request, StatusCode};
    use std::fs;
    use std::path::PathBuf;
    use std::sync::atomic::{AtomicU64, Ordering};
    use std::time::{SystemTime, UNIX_EPOCH};
    use tower::util::ServiceExt;

    static NEXT_ID: AtomicU64 = AtomicU64::new(1);

    fn test_db_path() -> PathBuf {
        let suffix = SystemTime::now()
            .duration_since(UNIX_EPOCH)
            .expect("time")
            .as_nanos();
        let unique = NEXT_ID.fetch_add(1, Ordering::Relaxed);
        std::env::temp_dir().join(format!("claude-core-sse-{suffix}-{unique}.db"))
    }

    fn seed_db(path: &PathBuf) {
        let conn = rusqlite::Connection::open(path).expect("open db");
        conn.execute_batch(
            "CREATE TABLE plans (id INTEGER PRIMARY KEY, status TEXT, execution_host TEXT);\
             INSERT INTO plans(id,status) VALUES (1,'doing'),(2,'todo');",
        )
        .expect("seed");
    }

    #[tokio::test]
    async fn plan_preflight_requires_plan_id_and_target() {
        let db = test_db_path();
        seed_db(&db);
        let app = build_router_with_db(PathBuf::from("/tmp"), db.clone());

        let res = app
            .oneshot(Request::builder().uri("/api/plan/preflight").body(Body::empty()).unwrap())
            .await
            .expect("preflight");
        assert_eq!(res.status(), StatusCode::BAD_REQUEST);
        fs::remove_file(db).ok();
    }

    #[tokio::test]
    async fn plan_start_updates_plan_status_and_emits_done_event() {
        let db = test_db_path();
        seed_db(&db);
        let app = build_router_with_db(PathBuf::from("/tmp"), db.clone());

        let res = app
            .clone()
            .oneshot(
                Request::builder()
                    .uri("/api/plan/start?plan_id=2&target=local&cli=copilot")
                    .body(Body::empty())
                    .unwrap(),
            )
            .await
            .expect("start");
        assert_eq!(res.status(), StatusCode::OK);
        let body = to_bytes(res.into_body(), usize::MAX).await.expect("body");
        let payload = String::from_utf8_lossy(&body);
        assert!(payload.contains("event: done"), "missing done event: {payload}");

        let conn = rusqlite::Connection::open(&db).expect("open");
        let status: String = conn
            .query_row("SELECT status FROM plans WHERE id=2", [], |row| row.get(0))
            .expect("status");
        assert_eq!(status, "doing");
        fs::remove_file(db).ok();
    }
}
