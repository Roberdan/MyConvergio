//! Integration tests for the ideas API endpoints.

use axum::body::Body;
use axum::http::{Request, StatusCode};
use serde_json::Value;
use tower::ServiceExt;

fn test_router() -> axum::Router {
    use std::sync::atomic::{AtomicU64, Ordering};
    static COUNTER: AtomicU64 = AtomicU64::new(0);
    let n = COUNTER.fetch_add(1, Ordering::SeqCst);
    let tmp = std::env::temp_dir().join(format!(
        "claude-ideas-test-{}-{n}.db", std::process::id()
    ));
    let conn = rusqlite::Connection::open(&tmp).expect("open");
    conn.execute_batch(CORE_SCHEMA).expect("core schema");
    conn.execute_batch(SEED_DATA).expect("seed data");
    drop(conn);
    super::routes::build_router_with_db(std::path::PathBuf::from("/tmp"), tmp)
}

const CORE_SCHEMA: &str = "
PRAGMA journal_mode=WAL;
CREATE TABLE IF NOT EXISTS projects (
  id TEXT PRIMARY KEY, name TEXT NOT NULL, path TEXT NOT NULL,
  branch TEXT DEFAULT 'main', created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
  updated_at DATETIME DEFAULT CURRENT_TIMESTAMP
);
CREATE TABLE IF NOT EXISTS ideas (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  title TEXT NOT NULL,
  description TEXT,
  tags TEXT,
  priority TEXT DEFAULT 'P2' CHECK(priority IN ('P0','P1','P2','P3')),
  status TEXT DEFAULT 'draft' CHECK(status IN ('draft','elaborating','ready','promoted','archived')),
  project_id TEXT REFERENCES projects(id) ON DELETE SET NULL,
  links TEXT,
  plan_id INTEGER,
  created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
  updated_at DATETIME DEFAULT CURRENT_TIMESTAMP
);
CREATE TABLE IF NOT EXISTS idea_notes (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  idea_id INTEGER NOT NULL REFERENCES ideas(id) ON DELETE CASCADE,
  content TEXT NOT NULL,
  created_at DATETIME DEFAULT CURRENT_TIMESTAMP
);
CREATE INDEX IF NOT EXISTS idx_ideas_status ON ideas(status);
CREATE INDEX IF NOT EXISTS idx_ideas_project ON ideas(project_id);
CREATE INDEX IF NOT EXISTS idx_idea_notes_idea ON idea_notes(idea_id);
";

const SEED_DATA: &str = "
INSERT INTO projects(id,name,path) VALUES('proj1','TestProject','/tmp/test');

INSERT INTO ideas(id,title,description,tags,priority,status,project_id)
  VALUES(1,'Idea Alpha','First idea description','rust,api','P0','draft','proj1');
INSERT INTO ideas(id,title,description,tags,priority,status,project_id)
  VALUES(2,'Idea Beta','Second idea description','ui,ux','P2','ready','proj1');

INSERT INTO idea_notes(id,idea_id,content)
  VALUES(1,1,'Note on idea Alpha');
";

async fn get(router: &axum::Router, uri: &str) -> (StatusCode, Value) {
    let req = Request::builder().uri(uri).body(Body::empty()).unwrap();
    let resp = router.clone().oneshot(req).await.unwrap();
    let status = resp.status();
    let body = axum::body::to_bytes(resp.into_body(), 1_000_000).await.unwrap();
    let json: Value = serde_json::from_slice(&body).unwrap_or(Value::Null);
    (status, json)
}

async fn post(router: &axum::Router, uri: &str, payload: Value) -> (StatusCode, Value) {
    let req = Request::builder()
        .uri(uri)
        .method("POST")
        .header("Content-Type", "application/json")
        .body(Body::from(serde_json::to_string(&payload).unwrap()))
        .unwrap();
    let resp = router.clone().oneshot(req).await.unwrap();
    let status = resp.status();
    let body = axum::body::to_bytes(resp.into_body(), 1_000_000).await.unwrap();
    let json: Value = serde_json::from_slice(&body).unwrap_or(Value::Null);
    (status, json)
}

async fn put(router: &axum::Router, uri: &str, payload: Value) -> (StatusCode, Value) {
    let req = Request::builder()
        .uri(uri)
        .method("PUT")
        .header("Content-Type", "application/json")
        .body(Body::from(serde_json::to_string(&payload).unwrap()))
        .unwrap();
    let resp = router.clone().oneshot(req).await.unwrap();
    let status = resp.status();
    let body = axum::body::to_bytes(resp.into_body(), 1_000_000).await.unwrap();
    let json: Value = serde_json::from_slice(&body).unwrap_or(Value::Null);
    (status, json)
}

async fn delete(router: &axum::Router, uri: &str) -> (StatusCode, Value) {
    let req = Request::builder()
        .uri(uri)
        .method("DELETE")
        .body(Body::empty())
        .unwrap();
    let resp = router.clone().oneshot(req).await.unwrap();
    let status = resp.status();
    let body = axum::body::to_bytes(resp.into_body(), 1_000_000).await.unwrap();
    let json: Value = serde_json::from_slice(&body).unwrap_or(Value::Null);
    (status, json)
}

#[tokio::test]
async fn ideas_crud() {
    let r = test_router();

    // POST /api/ideas
    let (s, j) = post(&r, "/api/ideas",
        serde_json::json!({"title": "New Idea", "priority": "P1", "tags": "test"})).await;
    assert_eq!(s, StatusCode::OK);
    let new_id = j["id"].as_i64().expect("id in response");
    assert_eq!(j["title"], "New Idea");
    assert_eq!(j["status"], "draft");

    // GET /api/ideas
    let (s, j) = get(&r, "/api/ideas").await;
    assert_eq!(s, StatusCode::OK);
    let arr = j.as_array().expect("array");
    assert!(arr.len() >= 3, "should have seed + new idea");

    // GET /api/ideas/:id
    let (s, j) = get(&r, &format!("/api/ideas/{new_id}")).await;
    assert_eq!(s, StatusCode::OK);
    assert_eq!(j["idea"]["title"], "New Idea");
    assert!(j["notes"].is_array());

    // PUT /api/ideas/:id
    let (s, j) = put(&r, &format!("/api/ideas/{new_id}"),
        serde_json::json!({"title": "Updated Idea", "status": "elaborating"})).await;
    assert_eq!(s, StatusCode::OK);
    assert_eq!(j["title"], "Updated Idea");
    assert_eq!(j["status"], "elaborating");

    // DELETE /api/ideas/:id
    let (s, j) = delete(&r, &format!("/api/ideas/{new_id}")).await;
    assert_eq!(s, StatusCode::OK);
    assert_eq!(j["ok"], true);
}

#[tokio::test]
async fn ideas_create_rejects_empty_title() {
    let r = test_router();
    let (s, _) = post(&r, "/api/ideas", serde_json::json!({"title": ""})).await;
    assert_eq!(s, StatusCode::BAD_REQUEST);
}

#[tokio::test]
async fn ideas_get_not_found() {
    let r = test_router();
    let (s, _) = get(&r, "/api/ideas/99999").await;
    assert_eq!(s, StatusCode::BAD_REQUEST);
}

#[tokio::test]
async fn ideas_notes() {
    let r = test_router();

    // GET /api/ideas/1/notes — seed has 1 note on idea 1
    let (s, j) = get(&r, "/api/ideas/1/notes").await;
    assert_eq!(s, StatusCode::OK);
    let arr = j.as_array().expect("array");
    assert_eq!(arr.len(), 1);
    assert_eq!(arr[0]["content"], "Note on idea Alpha");

    // POST /api/ideas/1/notes
    let (s, j) = post(&r, "/api/ideas/1/notes",
        serde_json::json!({"content": "Another note"})).await;
    assert_eq!(s, StatusCode::OK);
    assert_eq!(j["content"], "Another note");
    assert_eq!(j["idea_id"], 1);

    // verify list grew
    let (s, j) = get(&r, "/api/ideas/1/notes").await;
    assert_eq!(s, StatusCode::OK);
    assert_eq!(j.as_array().unwrap().len(), 2);
}

#[tokio::test]
async fn ideas_notes_rejects_empty_content() {
    let r = test_router();
    let (s, _) = post(&r, "/api/ideas/1/notes",
        serde_json::json!({"content": ""})).await;
    assert_eq!(s, StatusCode::BAD_REQUEST);
}

#[tokio::test]
async fn ideas_promote() {
    let r = test_router();
    // idea 1 starts as 'draft'
    let (s, j) = get(&r, "/api/ideas/1").await;
    assert_eq!(s, StatusCode::OK);
    assert_eq!(j["idea"]["status"], "draft");

    // POST /api/ideas/1/promote
    let (s, j) = post(&r, "/api/ideas/1/promote", serde_json::json!({})).await;
    assert_eq!(s, StatusCode::OK);
    assert_eq!(j["status"], "promoted");

    // verify via GET
    let (s, j) = get(&r, "/api/ideas/1").await;
    assert_eq!(s, StatusCode::OK);
    assert_eq!(j["idea"]["status"], "promoted");
}

#[tokio::test]
async fn ideas_filter() {
    let r = test_router();

    // filter by status=draft — idea 1 only
    let (s, j) = get(&r, "/api/ideas?status=draft").await;
    assert_eq!(s, StatusCode::OK);
    let arr = j.as_array().expect("array");
    assert!(arr.iter().all(|i| i["status"] == "draft"));

    // filter by priority=P0 — idea 1 only
    let (s, j) = get(&r, "/api/ideas?priority=P0").await;
    assert_eq!(s, StatusCode::OK);
    let arr = j.as_array().expect("array");
    assert!(!arr.is_empty());
    assert!(arr.iter().all(|i| i["priority"] == "P0"));

    // filter by status=ready — idea 2 only
    let (s, j) = get(&r, "/api/ideas?status=ready").await;
    assert_eq!(s, StatusCode::OK);
    let arr = j.as_array().expect("array");
    assert!(arr.iter().all(|i| i["status"] == "ready"));

    // combined filter — no match for P0+ready
    let (s, j) = get(&r, "/api/ideas?status=ready&priority=P0").await;
    assert_eq!(s, StatusCode::OK);
    assert_eq!(j.as_array().unwrap().len(), 0);
}
