//! Integration tests for all dashboard API endpoints.
//! Uses temp SQLite with seeded data to verify response shapes match frontend JS.

use axum::body::Body;
use axum::http::{Request, StatusCode};
use serde_json::Value;
use tower::ServiceExt;

fn test_router() -> axum::Router {
    use std::sync::atomic::{AtomicU64, Ordering};
    static COUNTER: AtomicU64 = AtomicU64::new(0);
    let n = COUNTER.fetch_add(1, Ordering::SeqCst);
    let tmp = std::env::temp_dir().join(format!(
        "claude-test-{}-{n}.db", std::process::id()
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
CREATE TABLE IF NOT EXISTS plans (
  id INTEGER PRIMARY KEY AUTOINCREMENT, project_id TEXT NOT NULL,
  name TEXT NOT NULL, source_file TEXT, status TEXT NOT NULL DEFAULT 'todo'
    CHECK(status IN ('todo','doing','done','cancelled')),
  tasks_total INTEGER DEFAULT 0, tasks_done INTEGER DEFAULT 0,
  created_at DATETIME DEFAULT CURRENT_TIMESTAMP, started_at DATETIME,
  completed_at DATETIME, execution_host TEXT, human_summary TEXT,
  parallel_mode TEXT DEFAULT 'standard', lines_added INTEGER,
  lines_removed INTEGER, cancelled_at DATETIME,
  FOREIGN KEY (project_id) REFERENCES projects(id)
);
CREATE TABLE IF NOT EXISTS waves (
  id INTEGER PRIMARY KEY AUTOINCREMENT, plan_id INTEGER NOT NULL,
  project_id TEXT, wave_id TEXT NOT NULL, name TEXT NOT NULL,
  status TEXT NOT NULL DEFAULT 'pending'
    CHECK(status IN ('pending','in_progress','done','blocked','merging','cancelled')),
  tasks_done INTEGER DEFAULT 0, tasks_total INTEGER DEFAULT 0,
  position INTEGER DEFAULT 0, started_at DATETIME, completed_at DATETIME,
  cancelled_at DATETIME, pr_number INTEGER, pr_url TEXT,
  FOREIGN KEY (plan_id) REFERENCES plans(id)
);
CREATE TABLE IF NOT EXISTS tasks (
  id INTEGER PRIMARY KEY AUTOINCREMENT, project_id TEXT NOT NULL,
  wave_id TEXT NOT NULL, task_id TEXT NOT NULL, title TEXT NOT NULL,
  status TEXT NOT NULL DEFAULT 'pending'
    CHECK(status IN ('pending','in_progress','submitted','done','blocked','skipped','cancelled')),
  tokens INTEGER DEFAULT 0, validated_at DATETIME, validated_by TEXT,
  notes TEXT, wave_id_fk INTEGER, plan_id INTEGER REFERENCES plans(id),
  model TEXT DEFAULT 'haiku', output_data TEXT, executor_agent TEXT,
  executor_host TEXT, started_at DATETIME, completed_at DATETIME,
  validation_report TEXT,
  FOREIGN KEY (project_id) REFERENCES projects(id)
);
CREATE TABLE IF NOT EXISTS peer_heartbeats (
  peer_name TEXT PRIMARY KEY, last_seen INTEGER NOT NULL,
  load_json TEXT, capabilities TEXT,
  updated_at TEXT DEFAULT (datetime('now'))
);
CREATE TABLE IF NOT EXISTS token_usage (
  id INTEGER PRIMARY KEY AUTOINCREMENT, project_id TEXT, plan_id INTEGER,
  wave_id TEXT, task_id TEXT, agent TEXT, model TEXT,
  input_tokens INTEGER DEFAULT 0, output_tokens INTEGER DEFAULT 0,
  cost_usd REAL DEFAULT 0, created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
  execution_host TEXT
);
CREATE TABLE IF NOT EXISTS notifications (
  id INTEGER PRIMARY KEY AUTOINCREMENT, project_id TEXT,
  type TEXT NOT NULL, title TEXT NOT NULL, message TEXT NOT NULL,
  source TEXT, link TEXT, link_type TEXT, is_read INTEGER DEFAULT 0,
  created_at DATETIME DEFAULT CURRENT_TIMESTAMP, read_at DATETIME
);
CREATE TABLE IF NOT EXISTS mesh_events (
  id INTEGER PRIMARY KEY AUTOINCREMENT, event_type TEXT NOT NULL,
  plan_id INTEGER, source_peer TEXT NOT NULL, payload TEXT,
  status TEXT DEFAULT 'pending', created_at INTEGER DEFAULT (unixepoch()),
  delivered_at INTEGER
);
";

const SEED_DATA: &str = "
INSERT INTO projects(id,name,path) VALUES('proj1','TestProject','/tmp/test');
INSERT INTO projects(id,name,path) VALUES('proj2','AnotherProject','/tmp/other');

-- Active plan (doing) with waves and tasks
INSERT INTO plans(id,project_id,name,status,tasks_done,tasks_total,human_summary,execution_host)
  VALUES(1,'proj1','Active Plan Alpha','doing',2,5,'Test plan summary','m3max');
INSERT INTO waves(id,plan_id,project_id,wave_id,name,status,tasks_done,tasks_total,position,completed_at)
  VALUES(10,1,'proj1','W0','Foundation','done',2,2,1,'2026-03-01 12:00:00');
INSERT INTO waves(id,plan_id,project_id,wave_id,name,status,tasks_done,tasks_total,position)
  VALUES(11,1,'proj1','W1','Core Logic','in_progress',0,3,2);
INSERT INTO tasks(id,project_id,plan_id,wave_id_fk,wave_id,task_id,title,status,executor_agent,model,validated_at)
  VALUES(100,'proj1',1,10,'W0','T0-01','Setup monorepo','done','claude','opus','2026-03-01 12:00:00');
INSERT INTO tasks(id,project_id,plan_id,wave_id_fk,wave_id,task_id,title,status,executor_agent,model,validated_at)
  VALUES(101,'proj1',1,10,'W0','T0-02','Add CI pipeline','done','copilot','gpt-5.3','2026-03-01 12:30:00');
INSERT INTO tasks(id,project_id,plan_id,wave_id_fk,wave_id,task_id,title,status,model)
  VALUES(102,'proj1',1,11,'W1','T1-01','Implement auth','pending','haiku');
INSERT INTO tasks(id,project_id,plan_id,wave_id_fk,wave_id,task_id,title,status,model)
  VALUES(103,'proj1',1,11,'W1','T1-02','Implement API','in_progress','opus');
INSERT INTO tasks(id,project_id,plan_id,wave_id_fk,wave_id,task_id,title,status,model)
  VALUES(104,'proj1',1,11,'W1','T1-03','Add tests','blocked','haiku');

-- Done plan
INSERT INTO plans(id,project_id,name,status,tasks_done,tasks_total,completed_at,lines_added,lines_removed)
  VALUES(2,'proj2','Completed Plan Beta','done',10,10,'2026-02-28 18:00:00',500,120);
INSERT INTO waves(id,plan_id,project_id,wave_id,name,status,tasks_done,tasks_total,position,completed_at)
  VALUES(20,2,'proj2','W0','All work','done',10,10,1,'2026-02-28 18:00:00');

-- Cancelled plan (parking lot)
INSERT INTO plans(id,project_id,name,status,tasks_done,tasks_total,cancelled_at)
  VALUES(3,'proj1','Cancelled Plan Gamma','cancelled',0,8,'2026-03-02 10:00:00');
INSERT INTO waves(id,plan_id,project_id,wave_id,name,status,tasks_done,tasks_total,position)
  VALUES(30,3,'proj1','W0','Never started','cancelled',0,4,1);
INSERT INTO tasks(id,project_id,plan_id,wave_id_fk,wave_id,task_id,title,status)
  VALUES(300,'proj1',3,30,'W0','T0-01','Task A','cancelled');

-- Todo plan
INSERT INTO plans(id,project_id,name,status,tasks_done,tasks_total)
  VALUES(4,'proj1','Pipeline Plan Delta','todo',0,12);

-- Submitted task (for Thor validate test)
INSERT INTO plans(id,project_id,name,status,tasks_done,tasks_total)
  VALUES(5,'proj1','Thor Test Plan','doing',0,1);
INSERT INTO waves(id,plan_id,project_id,wave_id,name,status,tasks_done,tasks_total,position)
  VALUES(50,5,'proj1','W0','Wave','in_progress',0,1,1);
INSERT INTO tasks(id,project_id,plan_id,wave_id_fk,wave_id,task_id,title,status)
  VALUES(500,'proj1',5,50,'W0','T0-01','Submitted task','submitted');

-- Peers
INSERT INTO peer_heartbeats(peer_name,last_seen,load_json,capabilities)
  VALUES('m3max',strftime('%s','now'),'{\"cpu\":15.2,\"mem_total_gb\":36,\"mem_used_gb\":22}','claude,copilot');
INSERT INTO peer_heartbeats(peer_name,last_seen,load_json,capabilities)
  VALUES('omarchy',strftime('%s','now')-600,'{\"cpu\":5.0,\"mem_total_gb\":16,\"mem_used_gb\":8}','claude,ollama');

-- Tokens
INSERT INTO token_usage(project_id,plan_id,agent,model,input_tokens,output_tokens,cost_usd)
  VALUES('proj1',1,'claude','opus',50000,10000,1.25);
INSERT INTO token_usage(project_id,plan_id,agent,model,input_tokens,output_tokens,cost_usd)
  VALUES('proj1',2,'copilot','gpt-5.3',30000,8000,0.50);

-- Notifications
INSERT INTO notifications(type,title,message,is_read)
  VALUES('info','Test notification','Hello world',0);
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

#[tokio::test]
async fn health_returns_ok_with_version() {
    let r = test_router();
    let (s, j) = get(&r, "/api/health").await;
    assert_eq!(s, StatusCode::OK);
    assert_eq!(j["ok"], true);
    assert_eq!(j["db"], true);
    assert!(j["version"].is_string());
    assert!(j["tables"].as_i64().unwrap() > 0);
}

#[tokio::test]
async fn overview_returns_plan_counts() {
    let r = test_router();
    let (s, j) = get(&r, "/api/overview").await;
    assert_eq!(s, StatusCode::OK);
    assert!(j["plans_total"].as_i64().unwrap() >= 4);
    assert!(j["plans_active"].as_i64().unwrap() >= 1);
    assert!(j["plans_done"].as_i64().unwrap() >= 1);
}

#[tokio::test]
async fn mission_returns_plans_with_waves_and_project_name() {
    let r = test_router();
    let (s, j) = get(&r, "/api/mission").await;
    assert_eq!(s, StatusCode::OK);
    let plans = j["plans"].as_array().expect("plans array");
    assert!(!plans.is_empty());
    let active = plans.iter()
        .find(|m| m["plan"]["id"].as_i64() == Some(1))
        .expect("active plan #1");
    assert_eq!(active["plan"]["name"], "Active Plan Alpha");
    assert_eq!(active["plan"]["project_name"], "TestProject");
    assert_eq!(active["plan"]["status"], "doing");
    let waves = active["waves"].as_array().expect("waves array");
    assert_eq!(waves.len(), 2);
    assert!(waves[0].get("validated_at").is_some());
    let tasks = active["tasks"].as_array().expect("tasks array");
    assert_eq!(tasks.len(), 5);
}

#[tokio::test]
async fn mission_includes_cancelled_in_parking_lot() {
    let r = test_router();
    let (s, j) = get(&r, "/api/mission").await;
    assert_eq!(s, StatusCode::OK);
    let plans = j["plans"].as_array().unwrap();
    assert!(plans.iter().any(|m| m["plan"]["status"] == "cancelled"),
        "cancelled plans must appear for parking lot");
}

#[tokio::test]
async fn plan_detail_returns_nested_shape() {
    let r = test_router();
    let (s, j) = get(&r, "/api/plan/1").await;
    assert_eq!(s, StatusCode::OK);
    assert!(j.get("plan").is_some(), "must have .plan");
    assert!(j.get("waves").is_some(), "must have .waves");
    assert!(j.get("tasks").is_some(), "must have .tasks");
    assert!(j.get("cost").is_some(), "must have .cost");
    assert_eq!(j["plan"]["id"], 1);
    assert_eq!(j["plan"]["project_name"], "TestProject");
    assert!(j["plan"]["human_summary"].is_string());
    let waves = j["waves"].as_array().unwrap();
    assert_eq!(waves.len(), 2);
    assert!(waves[0].get("validated_at").is_some());
    assert!(waves[0].get("pr_number").is_some());
    assert!(j["cost"]["tokens"].is_number());
    assert!(j["cost"]["cost"].is_number());
}

#[tokio::test]
async fn plan_detail_400_for_missing() {
    let r = test_router();
    let (s, _) = get(&r, "/api/plan/99999").await;
    assert_eq!(s, StatusCode::BAD_REQUEST);
}

#[tokio::test]
async fn history_returns_done_plans() {
    let r = test_router();
    let (s, j) = get(&r, "/api/history").await;
    assert_eq!(s, StatusCode::OK);
    let arr = j.as_array().unwrap();
    assert!(!arr.is_empty());
    assert!(arr[0].get("project_name").is_some());
    assert!(arr[0].get("lines_added").is_some());
}

#[tokio::test]
async fn plan_status_changes_state() {
    let r = test_router();
    let (s, j) = post(&r, "/api/plan-status",
        serde_json::json!({"plan_id": 4, "status": "doing"})).await;
    assert_eq!(s, StatusCode::OK);
    assert_eq!(j["ok"], true);
}

#[tokio::test]
async fn plan_status_rejects_invalid() {
    let r = test_router();
    let (s, _) = post(&r, "/api/plan-status",
        serde_json::json!({"plan_id": 4, "status": "invalid"})).await;
    assert_eq!(s, StatusCode::BAD_REQUEST);
}

#[tokio::test]
async fn cancel_plan_cascades() {
    let r = test_router();
    let (s, j) = get(&r, "/api/plan/cancel?plan_id=1").await;
    assert_eq!(s, StatusCode::OK);
    assert_eq!(j["ok"], true);
    assert_eq!(j["action"], "cancelled");
    let (_, detail) = get(&r, "/api/plan/1").await;
    assert_eq!(detail["plan"]["status"], "cancelled");
}

#[tokio::test]
async fn reset_plan_resets_waves() {
    let r = test_router();
    let (s, j) = get(&r, "/api/plan/reset?plan_id=1").await;
    assert_eq!(s, StatusCode::OK);
    assert_eq!(j["ok"], true);
    let (_, detail) = get(&r, "/api/plan/1").await;
    assert_eq!(detail["plan"]["status"], "todo");
}

#[tokio::test]
async fn validate_plan_sets_done() {
    let r = test_router();
    let (s, j) = post(&r, "/api/plans/5/validate", serde_json::json!({})).await;
    assert_eq!(s, StatusCode::OK);
    assert_eq!(j["ok"], true);
    assert!(j["validated"].as_i64().unwrap() >= 1);
}

#[tokio::test]
async fn tokens_daily_returns_array() {
    let r = test_router();
    let (s, j) = get(&r, "/api/tokens/daily").await;
    assert_eq!(s, StatusCode::OK);
    assert!(j.is_array());
}

#[tokio::test]
async fn tokens_models_returns_array() {
    let r = test_router();
    let (s, j) = get(&r, "/api/tokens/models").await;
    assert_eq!(s, StatusCode::OK);
    assert!(j.is_array());
}

#[tokio::test]
async fn organization_returns_structure() {
    let r = test_router();
    let (s, j) = get(&r, "/api/organization").await;
    assert_eq!(s, StatusCode::OK);
    assert!(j["units"].is_array());
    assert!(j["summary"]["nodes_total"].is_number());
}

#[tokio::test]
async fn tasks_distribution_returns_counts() {
    let r = test_router();
    let (s, j) = get(&r, "/api/tasks/distribution").await;
    assert_eq!(s, StatusCode::OK);
    let arr = j.as_array().unwrap();
    assert!(!arr.is_empty());
    assert!(arr[0].get("status").is_some());
    assert!(arr[0].get("count").is_some());
}

#[tokio::test]
async fn tasks_blocked_returns_blocked() {
    let r = test_router();
    let (s, j) = get(&r, "/api/tasks/blocked").await;
    assert_eq!(s, StatusCode::OK);
    let arr = j.as_array().unwrap();
    assert!(arr.iter().any(|t| t["status"] == "blocked"));
}

#[tokio::test]
async fn projects_returns_all() {
    let r = test_router();
    let (s, j) = get(&r, "/api/projects").await;
    assert_eq!(s, StatusCode::OK);
    assert!(j.as_array().unwrap().len() >= 2);
}

#[tokio::test]
async fn notifications_returns_unread() {
    let r = test_router();
    let (s, j) = get(&r, "/api/notifications").await;
    assert_eq!(s, StatusCode::OK);
    let arr = j.as_array().unwrap();
    assert!(!arr.is_empty());
    assert_eq!(arr[0]["is_read"], 0);
}

#[tokio::test]
async fn peers_returns_list() {
    let r = test_router();
    let (s, j) = get(&r, "/api/peers").await;
    assert_eq!(s, StatusCode::OK);
    assert!(j["peers"].is_array());
}

#[tokio::test]
async fn plans_assignable_returns_active() {
    let r = test_router();
    let (s, j) = get(&r, "/api/plans/assignable").await;
    assert_eq!(s, StatusCode::OK);
    let arr = j.as_array().unwrap();
    assert!(arr.iter().any(|p| p["status"] == "doing" || p["status"] == "todo"));
}
