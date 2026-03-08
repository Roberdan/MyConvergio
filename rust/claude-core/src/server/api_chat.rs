use super::state::{query_rows, ApiError, ServerState};
use axum::extract::State;
use axum::routing::{get, post, put};
use axum::{Json, Router};
use serde::Deserialize;
use serde_json::{json, Value};

pub fn router() -> Router<ServerState> {
    Router::new()
        .route("/api/chat/models", get(handle_chat_models))
        .route("/api/chat/sessions", get(handle_chat_sessions_list))
        .route("/api/chat/session", post(handle_chat_session_create).delete(handle_chat_session_delete))
        .route("/api/chat/message", post(handle_chat_message_create))
        .route("/api/chat/approve", post(handle_chat_approve))
        .route("/api/chat/execute", post(handle_chat_execute))
        .route("/api/chat/requirement", put(handle_chat_requirement_upsert))
}

fn ensure_chat_schema(conn: &rusqlite::Connection) -> Result<(), ApiError> {
    conn.execute_batch(
        "CREATE TABLE IF NOT EXISTS chat_sessions (id TEXT PRIMARY KEY, project_id INTEGER, plan_id INTEGER, task_db_id INTEGER, title TEXT NOT NULL, status TEXT NOT NULL DEFAULT 'active', metadata_json TEXT, created_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP, updated_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP, last_message_at TEXT);\
         CREATE TABLE IF NOT EXISTS chat_messages (id INTEGER PRIMARY KEY AUTOINCREMENT, session_id TEXT NOT NULL, role TEXT NOT NULL, content TEXT NOT NULL, requirement_id INTEGER, model TEXT, tokens_in INTEGER DEFAULT 0, tokens_out INTEGER DEFAULT 0, metadata_json TEXT, created_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP);\
         CREATE TABLE IF NOT EXISTS chat_requirements (id INTEGER PRIMARY KEY AUTOINCREMENT, session_id TEXT NOT NULL, requirement_key TEXT NOT NULL, requirement_text TEXT NOT NULL, source TEXT, is_active INTEGER DEFAULT 1, created_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP, updated_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP, UNIQUE(session_id, requirement_key));",
    )
    .map_err(|err| ApiError::internal(format!("chat schema failed: {err}")))
}

async fn handle_chat_sessions_list(State(state): State<ServerState>) -> Result<Json<Value>, ApiError> {
    let db = state.open_db()?;
    ensure_chat_schema(db.connection())?;
    let sessions = query_rows(
        db.connection(),
        "SELECT id,project_id,plan_id,task_db_id,title,status,metadata_json,created_at,updated_at,last_message_at FROM chat_sessions WHERE status!='deleted' ORDER BY COALESCE(last_message_at,updated_at,created_at) DESC",
        [],
    )?;
    Ok(Json(json!({"ok": true, "sessions": sessions})))
}

async fn handle_chat_models() -> Json<Value> {
    Json(json!({"ok": true, "models": ["claude-sonnet-4.6", "gpt-5.3-codex", "gpt-5.4"]}))
}

#[derive(Deserialize)]
struct SessionCreateBody {
    session_id: Option<String>,
    title: Option<String>,
}

async fn handle_chat_session_create(
    State(state): State<ServerState>,
    axum::Json(payload): axum::Json<SessionCreateBody>,
) -> Result<Json<Value>, ApiError> {
    let db = state.open_db()?;
    ensure_chat_schema(db.connection())?;
    let sid = payload.session_id.unwrap_or_else(|| uuid_like());
    let title = payload.title.unwrap_or_else(|| "New chat session".to_string());
    db.connection()
        .execute(
            "INSERT INTO chat_sessions(id,title,status,last_message_at) VALUES(?1,?2,'active',CURRENT_TIMESTAMP)",
            rusqlite::params![sid, title],
        )
        .map_err(|err| ApiError::internal(format!("chat session create failed: {err}")))?;
    Ok(Json(json!({"ok": true, "session": {"id": sid, "title": title, "status": "active"}})))
}

#[derive(Deserialize)]
struct ChatMessageBody {
    session_id: Option<String>,
    sid: Option<String>,
    content: Option<String>,
    role: Option<String>,
}

async fn handle_chat_message_create(
    State(state): State<ServerState>,
    axum::Json(payload): axum::Json<ChatMessageBody>,
) -> Result<Json<Value>, ApiError> {
    let db = state.open_db()?;
    ensure_chat_schema(db.connection())?;
    let sid = payload
        .session_id
        .or(payload.sid)
        .ok_or_else(|| ApiError::bad_request("missing session_id"))?;
    let content = payload
        .content
        .filter(|v| !v.trim().is_empty())
        .ok_or_else(|| ApiError::bad_request("missing content"))?;
    let role = payload.role.unwrap_or_else(|| "user".to_string());
    db.connection()
        .execute(
            "INSERT INTO chat_messages(session_id,role,content,tokens_in,tokens_out) VALUES(?1,?2,?3,0,0)",
            rusqlite::params![sid, role, content],
        )
        .map_err(|err| ApiError::internal(format!("chat message create failed: {err}")))?;
    Ok(Json(json!({"ok": true, "message_id": db.connection().last_insert_rowid()})))
}

async fn handle_chat_requirement_upsert(
    State(state): State<ServerState>,
    axum::Json(payload): axum::Json<Value>,
) -> Result<Json<Value>, ApiError> {
    let db = state.open_db()?;
    ensure_chat_schema(db.connection())?;
    let sid = payload.get("session_id").and_then(Value::as_str).unwrap_or_default();
    let key = payload.get("requirement_key").and_then(Value::as_str).unwrap_or_default();
    let text = payload.get("requirement_text").and_then(Value::as_str).unwrap_or_default();
    if sid.is_empty() || key.is_empty() || text.is_empty() {
        return Err(ApiError::bad_request("missing session_id, requirement_key, or requirement_text"));
    }
    db.connection()
        .execute(
            "INSERT INTO chat_requirements(session_id,requirement_key,requirement_text,source,is_active) VALUES(?1,?2,?3,'user',1) ON CONFLICT(session_id, requirement_key) DO UPDATE SET requirement_text=excluded.requirement_text,is_active=1,updated_at=CURRENT_TIMESTAMP",
            rusqlite::params![sid, key, text],
        )
        .map_err(|err| ApiError::internal(format!("chat requirement upsert failed: {err}")))?;
    Ok(Json(json!({"ok": true, "requirement_key": key, "action": "upsert"})))
}

async fn handle_chat_approve(axum::Json(_payload): axum::Json<Value>) -> Json<Value> {
    Json(json!({"ok": true}))
}

async fn handle_chat_execute(axum::Json(_payload): axum::Json<Value>) -> Json<Value> {
    Json(json!({"ok": true, "queued": true}))
}

async fn handle_chat_session_delete(
    State(state): State<ServerState>,
    axum::extract::Query(qs): axum::extract::Query<std::collections::HashMap<String, String>>,
) -> Result<Json<Value>, ApiError> {
    let sid = qs.get("sid").or_else(|| qs.get("session_id")).cloned().unwrap_or_default();
    if sid.is_empty() {
        return Err(ApiError::bad_request("missing session_id"));
    }
    let db = state.open_db()?;
    ensure_chat_schema(db.connection())?;
    db.connection()
        .execute(
            "UPDATE chat_sessions SET status='deleted',updated_at=CURRENT_TIMESTAMP WHERE id=?1",
            rusqlite::params![sid],
        )
        .map_err(|err| ApiError::internal(format!("chat session delete failed: {err}")))?;
    Ok(Json(json!({"ok": true, "deleted": true, "session_id": sid})))
}

fn uuid_like() -> String {
    use std::time::{SystemTime, UNIX_EPOCH};
    let nanos = SystemTime::now()
        .duration_since(UNIX_EPOCH)
        .map(|d| d.as_nanos())
        .unwrap_or(0);
    format!("session-{nanos}")
}
