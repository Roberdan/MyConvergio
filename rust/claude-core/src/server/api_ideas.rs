use super::state::{query_one, query_rows, ApiError, ServerState};
use axum::extract::{Path, Query, State};
use axum::routing::{get, post};
use axum::{Json, Router};
use serde::Deserialize;
use serde_json::{json, Value};
use std::collections::HashMap;

pub fn router() -> Router<ServerState> {
    Router::new()
        .route("/api/ideas", get(list_ideas).post(create_idea))
        .route("/api/ideas/:id", get(get_idea).put(update_idea).delete(delete_idea))
        .route("/api/ideas/:id/notes", get(list_notes).post(add_note))
        .route("/api/ideas/:id/promote", post(promote_idea))
}

async fn list_ideas(
    State(state): State<ServerState>,
    Query(qs): Query<HashMap<String, String>>,
) -> Result<Json<Value>, ApiError> {
    let db = state.open_db()?;
    let mut conditions: Vec<String> = Vec::new();
    let mut params: Vec<String> = Vec::new();
    if let Some(s) = qs.get("status").filter(|v| !v.is_empty()) {
        conditions.push("status=?".to_string());
        params.push(s.clone());
    }
    if let Some(p) = qs.get("priority").filter(|v| !v.is_empty()) {
        conditions.push("priority=?".to_string());
        params.push(p.clone());
    }
    if let Some(proj) = qs.get("project_id").filter(|v| !v.is_empty()) {
        conditions.push("project_id=?".to_string());
        params.push(proj.clone());
    }
    if let Some(tag) = qs.get("tag").filter(|v| !v.is_empty()) {
        conditions.push("tags LIKE ?".to_string());
        params.push(format!("%{}%", tag));
    }
    let where_clause = if conditions.is_empty() {
        String::new()
    } else {
        format!(" WHERE {}", conditions.join(" AND "))
    };
    let sql = format!(
        "SELECT id,title,description,tags,priority,status,project_id,links,plan_id,created_at,updated_at FROM ideas{} ORDER BY id DESC",
        where_clause
    );
    let rows = db.connection().prepare(&sql).and_then(|mut stmt| {
        let idx: Vec<&dyn rusqlite::ToSql> = params.iter().map(|p| p as &dyn rusqlite::ToSql).collect();
        stmt.query_map(idx.as_slice(), |row| {
            Ok(json!({
                "id": row.get::<_,i64>(0)?,
                "title": row.get::<_,Option<String>>(1)?,
                "description": row.get::<_,Option<String>>(2)?,
                "tags": row.get::<_,Option<String>>(3)?,
                "priority": row.get::<_,Option<String>>(4)?,
                "status": row.get::<_,Option<String>>(5)?,
                "project_id": row.get::<_,Option<String>>(6)?,
                "links": row.get::<_,Option<String>>(7)?,
                "plan_id": row.get::<_,Option<i64>>(8)?,
                "created_at": row.get::<_,Option<String>>(9)?,
                "updated_at": row.get::<_,Option<String>>(10)?
            }))
        }).and_then(|mapped| mapped.collect::<Result<Vec<_>, _>>())
    }).map_err(|e| ApiError::internal(format!("list ideas failed: {e}")))?;
    Ok(Json(Value::Array(rows)))
}

async fn get_idea(
    State(state): State<ServerState>,
    Path(id): Path<i64>,
) -> Result<Json<Value>, ApiError> {
    let db = state.open_db()?;
    let idea = query_one(
        db.connection(),
        "SELECT id,title,description,tags,priority,status,project_id,links,plan_id,created_at,updated_at FROM ideas WHERE id=?1",
        rusqlite::params![id],
    )?.ok_or_else(|| ApiError::bad_request(format!("idea {id} not found")))?;
    let notes = query_rows(
        db.connection(),
        "SELECT id,idea_id,content,created_at FROM idea_notes WHERE idea_id=?1 ORDER BY id",
        rusqlite::params![id],
    ).unwrap_or_default();
    Ok(Json(json!({"idea": idea, "notes": notes})))
}

#[derive(Deserialize)]
struct CreateIdeaBody {
    title: String,
    #[serde(default)]
    description: Option<String>,
    #[serde(default)]
    tags: Option<String>,
    #[serde(default)]
    priority: Option<String>,
    #[serde(default)]
    project_id: Option<String>,
    #[serde(default)]
    links: Option<String>,
}

async fn create_idea(
    State(state): State<ServerState>,
    Json(body): Json<CreateIdeaBody>,
) -> Result<Json<Value>, ApiError> {
    let title = body.title.trim().to_string();
    if title.is_empty() {
        return Err(ApiError::bad_request("title is required"));
    }
    let db = state.open_db()?;
    db.connection()
        .execute(
            "INSERT INTO ideas (title,description,tags,priority,project_id,links) VALUES (?1,?2,?3,?4,?5,?6)",
            rusqlite::params![title, body.description, body.tags, body.priority, body.project_id, body.links],
        )
        .map_err(|e| ApiError::internal(format!("create idea failed: {e}")))?;
    let id = db.connection().last_insert_rowid();
    let idea = query_one(
        db.connection(),
        "SELECT id,title,description,tags,priority,status,project_id,links,plan_id,created_at,updated_at FROM ideas WHERE id=?1",
        rusqlite::params![id],
    )?.unwrap_or_else(|| json!({"id": id}));
    Ok(Json(idea))
}

#[derive(Deserialize)]
struct UpdateIdeaBody {
    #[serde(default)]
    title: Option<String>,
    #[serde(default)]
    description: Option<String>,
    #[serde(default)]
    tags: Option<String>,
    #[serde(default)]
    priority: Option<String>,
    #[serde(default)]
    status: Option<String>,
    #[serde(default)]
    project_id: Option<String>,
    #[serde(default)]
    links: Option<String>,
}

async fn update_idea(
    State(state): State<ServerState>,
    Path(id): Path<i64>,
    Json(body): Json<UpdateIdeaBody>,
) -> Result<Json<Value>, ApiError> {
    let db = state.open_db()?;
    let mut sets: Vec<String> = vec!["updated_at=datetime('now')".to_string()];
    let mut vals: Vec<Box<dyn rusqlite::ToSql>> = Vec::new();
    if let Some(v) = body.title { sets.push(format!("title=?{}", vals.len()+1)); vals.push(Box::new(v)); }
    if let Some(v) = body.description { sets.push(format!("description=?{}", vals.len()+1)); vals.push(Box::new(v)); }
    if let Some(v) = body.tags { sets.push(format!("tags=?{}", vals.len()+1)); vals.push(Box::new(v)); }
    if let Some(v) = body.priority { sets.push(format!("priority=?{}", vals.len()+1)); vals.push(Box::new(v)); }
    if let Some(v) = body.status { sets.push(format!("status=?{}", vals.len()+1)); vals.push(Box::new(v)); }
    if let Some(v) = body.project_id { sets.push(format!("project_id=?{}", vals.len()+1)); vals.push(Box::new(v)); }
    if let Some(v) = body.links { sets.push(format!("links=?{}", vals.len()+1)); vals.push(Box::new(v)); }
    vals.push(Box::new(id));
    let sql = format!("UPDATE ideas SET {} WHERE id=?{}", sets.join(","), vals.len());
    let refs: Vec<&dyn rusqlite::ToSql> = vals.iter().map(|v| v.as_ref()).collect();
    db.connection().execute(&sql, refs.as_slice())
        .map_err(|e| ApiError::internal(format!("update idea failed: {e}")))?;
    let idea = query_one(
        db.connection(),
        "SELECT id,title,description,tags,priority,status,project_id,links,plan_id,created_at,updated_at FROM ideas WHERE id=?1",
        rusqlite::params![id],
    )?.ok_or_else(|| ApiError::bad_request(format!("idea {id} not found")))?;
    Ok(Json(idea))
}

async fn delete_idea(
    State(state): State<ServerState>,
    Path(id): Path<i64>,
) -> Result<Json<Value>, ApiError> {
    let db = state.open_db()?;
    db.connection()
        .execute("DELETE FROM ideas WHERE id=?1", rusqlite::params![id])
        .map_err(|e| ApiError::internal(format!("delete idea failed: {e}")))?;
    Ok(Json(json!({"ok": true, "id": id})))
}

async fn list_notes(
    State(state): State<ServerState>,
    Path(id): Path<i64>,
) -> Result<Json<Value>, ApiError> {
    let db = state.open_db()?;
    let notes = query_rows(
        db.connection(),
        "SELECT id,idea_id,content,created_at FROM idea_notes WHERE idea_id=?1 ORDER BY id",
        rusqlite::params![id],
    )?;
    Ok(Json(Value::Array(notes)))
}

#[derive(Deserialize)]
struct AddNoteBody {
    content: String,
}

async fn add_note(
    State(state): State<ServerState>,
    Path(id): Path<i64>,
    Json(body): Json<AddNoteBody>,
) -> Result<Json<Value>, ApiError> {
    let content = body.content.trim().to_string();
    if content.is_empty() {
        return Err(ApiError::bad_request("content is required"));
    }
    let db = state.open_db()?;
    db.connection()
        .execute(
            "INSERT INTO idea_notes (idea_id,content) VALUES (?1,?2)",
            rusqlite::params![id, content],
        )
        .map_err(|e| ApiError::internal(format!("add note failed: {e}")))?;
    let note_id = db.connection().last_insert_rowid();
    let note = query_one(
        db.connection(),
        "SELECT id,idea_id,content,created_at FROM idea_notes WHERE id=?1",
        rusqlite::params![note_id],
    )?.unwrap_or_else(|| json!({"id": note_id}));
    Ok(Json(note))
}

async fn promote_idea(
    State(state): State<ServerState>,
    Path(id): Path<i64>,
) -> Result<Json<Value>, ApiError> {
    let db = state.open_db()?;
    db.connection()
        .execute(
            "UPDATE ideas SET status='promoted', updated_at=datetime('now') WHERE id=?1",
            rusqlite::params![id],
        )
        .map_err(|e| ApiError::internal(format!("promote failed: {e}")))?;
    let idea = query_one(
        db.connection(),
        "SELECT id,title,description,tags,priority,status,project_id,links,plan_id,created_at,updated_at FROM ideas WHERE id=?1",
        rusqlite::params![id],
    )?.ok_or_else(|| ApiError::bad_request(format!("idea {id} not found")))?;
    Ok(Json(idea))
}
