use super::state::{query_one, query_rows, ApiError, ServerState};
use axum::extract::{Path, Query, State};
use axum::routing::{get, post};
use axum::{Json, Router};
use serde::Deserialize;
use serde_json::{json, Value};
use std::collections::HashMap;
use std::env;
use std::path::Path as FsPath;
use std::process::Command;

pub fn router() -> Router<ServerState> {
    Router::new()
        .route("/api/overview", get(api_overview))
        .route("/api/mission", get(api_mission))
        .route("/api/tokens/daily", get(api_tokens_daily))
        .route("/api/tokens/models", get(api_tokens_models))
        .route("/api/history", get(api_history))
        .route("/api/missions/recent", get(api_recent_missions))
        .route("/api/tasks/distribution", get(api_tasks_distribution))
        .route("/api/tasks/blocked", get(api_tasks_blocked))
        .route("/api/plans/assignable", get(api_plans_assignable))
        .route("/api/notifications", get(api_notifications))
        .route("/api/nightly/jobs/trigger", post(api_nightly_job_trigger))
        .route(
            "/api/nightly/jobs/definitions/:id/toggle",
            post(api_nightly_def_toggle),
        )
        .route("/api/nightly/jobs", get(api_nightly_jobs))
        .route("/api/nightly/jobs/create", post(api_nightly_job_create))
        .route("/api/nightly/jobs/:id/retry", post(api_nightly_job_retry))
        .route("/api/nightly/jobs/:id", get(api_nightly_job_detail))
        .route(
            "/api/nightly/config/:project_id",
            get(api_nightly_config_get).put(api_nightly_config_update),
        )
        .route("/api/projects", get(api_projects).post(api_project_create))
        .route("/api/events", get(api_events))
        .route("/api/coordinator/status", get(api_coordinator_status))
        .route("/api/coordinator/toggle", get(api_coordinator_toggle))
        .route("/api/plan/:plan_id", get(api_plan_detail))
        .route("/api/plan-status", post(api_plan_status))
        .route("/api/optimize/signals", get(api_optimize_signals))
        .route("/api/optimize/clear", post(api_optimize_clear))
}

async fn api_overview(State(state): State<ServerState>) -> Result<Json<Value>, ApiError> {
    let db = state.open_db()?;
    let row = query_one(
        db.connection(),
        "WITH plan_stats AS (
           SELECT COUNT(*) AS total,
                  SUM(CASE WHEN status IN ('todo','doing') THEN 1 ELSE 0 END) AS active,
                  SUM(CASE WHEN status='done' THEN 1 ELSE 0 END) AS done
           FROM plans
         ), task_stats AS (
           SELECT SUM(CASE WHEN status='in_progress' THEN 1 ELSE 0 END) AS running,
                  SUM(CASE WHEN status='blocked' THEN 1 ELSE 0 END) AS blocked
           FROM tasks WHERE status IN ('in_progress','blocked')
         ), token_stats AS (
           SELECT COALESCE(SUM(input_tokens + output_tokens),0) AS total_tokens,
                  COALESCE(SUM(cost_usd),0) AS total_cost,
                  COALESCE(SUM(CASE WHEN date(created_at)=date('now') THEN input_tokens + output_tokens ELSE 0 END),0) AS today_tokens,
                  COALESCE(SUM(CASE WHEN date(created_at)=date('now') THEN cost_usd ELSE 0 END),0) AS today_cost
           FROM token_usage
         ), mesh_stats AS (
           SELECT COUNT(*) AS mesh_total,
                  SUM(CASE WHEN (strftime('%s','now') - COALESCE(last_seen,0)) < 300 THEN 1 ELSE 0 END) AS mesh_online
           FROM peer_heartbeats
         )
         SELECT p.total AS plans_total, p.active AS plans_active, p.done AS plans_done,
                COALESCE(t.running,0) AS agents_running, COALESCE(t.blocked,0) AS blocked,
                tk.total_tokens, tk.total_cost, tk.today_tokens, tk.today_cost,
                m.mesh_total, m.mesh_online
         FROM plan_stats p, task_stats t, token_stats tk, mesh_stats m",
        [],
    )?
    .unwrap_or_else(|| json!({}));

    let (today_lines, week_lines, yesterday_lines, prev_week_lines) = today_lines_changed();
    let agents_today = agents_today_count();

    let mut result = row;
    if let Some(obj) = result.as_object_mut() {
        obj.insert("today_lines_changed".to_string(), json!(today_lines));
        obj.insert("week_lines_changed".to_string(), json!(week_lines));
        obj.insert("yesterday_lines_changed".to_string(), json!(yesterday_lines));
        obj.insert("prev_week_lines_changed".to_string(), json!(prev_week_lines));
        obj.insert("agents_today".to_string(), json!(agents_today));
    }
    Ok(Json(result))
}

fn today_lines_changed() -> (i64, i64, i64, i64) {
    let home = env::var("HOME").unwrap_or_else(|_| "/tmp".into());
    let mut repos = vec![format!("{home}/.claude")];
    if let Ok(conn) = rusqlite::Connection::open(format!("{home}/.claude/data/dashboard.db")) {
        if let Ok(mut stmt) = conn.prepare("SELECT DISTINCT project_path FROM projects WHERE project_path IS NOT NULL AND project_path != ''") {
            if let Ok(rows) = stmt.query_map([], |r| r.get::<_, String>(0)) {
                for path in rows.flatten() {
                    if !path.is_empty() && std::path::Path::new(&path).join(".git").exists() {
                        repos.push(path);
                    }
                }
            }
        }
    }
    let mut today: i64 = 0;
    let mut week: i64 = 0;
    let mut yesterday: i64 = 0;
    let mut prev_week: i64 = 0;
    for repo in &repos {
        let periods: &[(&str, Option<&str>, usize)] = &[
            ("midnight", None, 0),          // today
            ("1 week ago", None, 1),         // this week
            ("1 day ago", Some("midnight"), 2), // yesterday only
            ("2 weeks ago", Some("1 week ago"), 3), // prev week
        ];
        for &(since, until, idx) in periods {
            let since_flag = format!("--since={since}");
            let until_flag = format!("--until={}", until.unwrap_or(""));
            let mut args = vec!["-C", repo, "log", "--all", &since_flag, "--shortstat", "--format="];
            if until.is_some() {
                args.push(&until_flag);
            }
            let out = Command::new("git").args(&args).output();
            if let Ok(o) = out {
                if o.status.success() {
                    let text = String::from_utf8_lossy(&o.stdout);
                    let mut sub: i64 = 0;
                    for line in text.lines() {
                        for part in line.split(',') {
                            let part = part.trim();
                            if part.contains("insertion") || part.contains("deletion") {
                                if let Some(n) = part.split_whitespace().next().and_then(|s| s.parse::<i64>().ok()) {
                                    sub += n;
                                }
                            }
                        }
                    }
                    match idx {
                        0 => today += sub,
                        1 => week += sub,
                        2 => yesterday += sub,
                        3 => prev_week += sub,
                        _ => {}
                    }
                }
            }
        }
    }
    (today, week, yesterday, prev_week)
}

fn agents_today_count() -> i64 {
    let home = env::var("HOME").unwrap_or_else(|_| "/tmp".into());
    if let Ok(conn) = rusqlite::Connection::open(format!("{home}/.claude/data/dashboard.db")) {
        if let Ok(mut stmt) = conn.prepare("SELECT COUNT(*) FROM agent_runs WHERE date(started_at)=date('now')") {
            if let Ok(count) = stmt.query_row([], |r| r.get::<_, i64>(0)) {
                return count;
            }
        }
    }
    0
}

async fn api_mission(State(state): State<ServerState>) -> Result<Json<Value>, ApiError> {
    let db = state.open_db()?;
    let plans = query_rows(
        db.connection(),
        "SELECT p.id,p.name,p.status,p.tasks_done,p.tasks_total,p.project_id,p.execution_host,p.human_summary,p.started_at,p.created_at,p.lines_added,p.lines_removed,p.description,pr.name AS project_name FROM plans p LEFT JOIN projects pr ON p.project_id=pr.id WHERE p.status IN ('todo','doing') UNION ALL SELECT * FROM (SELECT p.id,p.name,p.status,p.tasks_done,p.tasks_total,p.project_id,p.execution_host,p.human_summary,p.started_at,p.created_at,p.lines_added,p.lines_removed,p.description,pr.name AS project_name FROM plans p LEFT JOIN projects pr ON p.project_id=pr.id WHERE p.status='cancelled' ORDER BY p.id DESC LIMIT 10)",
        [],
    )?;
    let mut result = Vec::new();
    for plan in plans {
        let plan_id = plan.get("id").and_then(Value::as_i64).unwrap_or(0);
        let waves = query_rows(
            db.connection(),
            "SELECT wave_id,name,status,tasks_done,tasks_total,position,completed_at AS validated_at,pr_number,pr_url,started_at,completed_at,theme,depends_on FROM waves WHERE plan_id=?1 ORDER BY position",
            rusqlite::params![plan_id],
        ).unwrap_or_default();
        let tasks = query_rows(
            db.connection(),
            "SELECT task_id,title,status,executor_agent,executor_host,tokens,validated_at,model,wave_id,started_at,completed_at,duration_minutes FROM tasks WHERE plan_id=?1 ORDER BY id",
            rusqlite::params![plan_id],
        ).unwrap_or_default();
        result.push(json!({"plan": plan, "waves": waves, "tasks": tasks}));
    }
    Ok(Json(json!({"plans": result})))
}

async fn api_tokens_daily(State(state): State<ServerState>) -> Result<Json<Value>, ApiError> {
    let db = state.open_db()?;
    Ok(Json(Value::Array(query_rows(
        db.connection(),
        "SELECT date(created_at) AS day, SUM(input_tokens) AS input, SUM(output_tokens) AS output, SUM(cost_usd) AS cost FROM token_usage GROUP BY day ORDER BY day",
        [],
    )?)))
}

async fn api_tokens_models(State(state): State<ServerState>) -> Result<Json<Value>, ApiError> {
    let db = state.open_db()?;
    Ok(Json(Value::Array(query_rows(
        db.connection(),
        "SELECT model, SUM(input_tokens + output_tokens) AS tokens, SUM(cost_usd) AS cost FROM token_usage WHERE model IS NOT NULL GROUP BY model ORDER BY tokens DESC LIMIT 8",
        [],
    )?)))
}

async fn api_history(State(state): State<ServerState>) -> Result<Json<Value>, ApiError> {
    let db = state.open_db()?;
    Ok(Json(Value::Array(query_rows(
        db.connection(),
        "SELECT p.id,p.name,p.status,p.tasks_done,p.tasks_total,p.project_id,p.started_at,p.completed_at,p.human_summary,p.lines_added,p.lines_removed,pr.name AS project_name FROM plans p LEFT JOIN projects pr ON p.project_id=pr.id WHERE p.status IN ('done','cancelled') ORDER BY p.id DESC LIMIT 20",
        [],
    )?)))
}

async fn api_recent_missions(State(state): State<ServerState>) -> Result<Json<Value>, ApiError> {
    let db = state.open_db()?;
    let plans = query_rows(
        db.connection(),
        "SELECT p.id,p.name,p.status,p.tasks_done,p.tasks_total,p.project_id,p.execution_host,p.human_summary,p.completed_at,p.cancelled_at,COALESCE(p.completed_at,p.cancelled_at) AS finished_at,pr.name AS project_name
         FROM plans p
         LEFT JOIN projects pr ON p.project_id=pr.id
         WHERE p.status = 'done'
           AND datetime(p.completed_at) >= datetime('now','-1 day')
           AND LOWER(COALESCE(p.name,'')) NOT LIKE '%test%'
           AND LOWER(COALESCE(pr.name,'')) NOT LIKE '%test%'
           AND LOWER(COALESCE(p.name,'')) NOT LIKE '%hyperdemo%'
           AND LOWER(COALESCE(pr.name,'')) NOT LIKE '%hyperdemo%'
         ORDER BY datetime(p.completed_at) DESC, p.id DESC",
        [],
    )?;
    let mut result = Vec::new();
    for plan in plans {
        let plan_id = plan.get("id").and_then(Value::as_i64).unwrap_or(0);
        let waves = query_rows(
            db.connection(),
            "SELECT wave_id,name,status,tasks_done,tasks_total,position,completed_at AS validated_at,pr_number,pr_url,started_at,completed_at,theme,depends_on FROM waves WHERE plan_id=?1 ORDER BY position",
            rusqlite::params![plan_id],
        )
        .unwrap_or_default();
        let tasks = query_rows(
            db.connection(),
            "SELECT task_id,title,status,executor_agent,executor_host,tokens,validated_at,model,wave_id,started_at,completed_at,duration_minutes FROM tasks WHERE plan_id=?1 ORDER BY id",
            rusqlite::params![plan_id],
        )
        .unwrap_or_default();
        result.push(json!({"plan": plan, "waves": waves, "tasks": tasks}));
    }
    Ok(Json(json!({"plans": result})))
}

async fn api_plan_detail(
    State(state): State<ServerState>,
    Path(plan_id): Path<i64>,
) -> Result<Json<Value>, ApiError> {
    let db = state.open_db()?;
    let plan = query_one(
        db.connection(),
        "SELECT p.id,p.name,p.status,p.tasks_done,p.tasks_total,p.project_id,p.execution_host,p.human_summary,p.started_at,p.completed_at,p.parallel_mode,p.lines_added,p.lines_removed,pr.name AS project_name FROM plans p LEFT JOIN projects pr ON p.project_id=pr.id WHERE p.id=?1",
        rusqlite::params![plan_id],
    )?.ok_or_else(|| ApiError::bad_request(format!("plan {plan_id} not found")))?;
    let waves = query_rows(
        db.connection(),
        "SELECT wave_id,name,status,tasks_done,tasks_total,position,completed_at AS validated_at,pr_number,pr_url FROM waves WHERE plan_id=?1 ORDER BY position",
        rusqlite::params![plan_id],
    ).unwrap_or_default();
    let tasks = query_rows(
        db.connection(),
        "SELECT task_id,title,status,executor_agent,executor_host,tokens,validated_at,model,wave_id FROM tasks WHERE plan_id=?1 ORDER BY id",
        rusqlite::params![plan_id],
    ).unwrap_or_default();
    let cost = query_one(
        db.connection(),
        "SELECT COALESCE(SUM(input_tokens+output_tokens),0) AS tokens, COALESCE(SUM(cost_usd),0) AS cost FROM token_usage WHERE plan_id=?1",
        rusqlite::params![plan_id],
    )?.unwrap_or_else(|| json!({"tokens":0,"cost":0}));
    Ok(Json(json!({"plan": plan, "waves": waves, "tasks": tasks, "cost": cost})))
}

async fn api_tasks_distribution(State(state): State<ServerState>) -> Result<Json<Value>, ApiError> {
    let db = state.open_db()?;
    Ok(Json(Value::Array(query_rows(
        db.connection(),
        "SELECT status, COUNT(*) AS count FROM tasks GROUP BY status ORDER BY count DESC",
        [],
    )?)))
}

async fn api_tasks_blocked(State(state): State<ServerState>) -> Result<Json<Value>, ApiError> {
    let db = state.open_db()?;
    Ok(Json(Value::Array(query_rows(
        db.connection(),
        "SELECT task_id,title,status,plan_id FROM tasks WHERE status='blocked'",
        [],
    )?)))
}

async fn api_plans_assignable(State(state): State<ServerState>) -> Result<Json<Value>, ApiError> {
    let db = state.open_db()?;
    Ok(Json(Value::Array(query_rows(
        db.connection(),
        "SELECT id,name,status,tasks_done,tasks_total,execution_host,human_summary FROM plans WHERE status IN ('todo','doing') ORDER BY id",
        [],
    )?)))
}

async fn api_notifications(State(state): State<ServerState>) -> Result<Json<Value>, ApiError> {
    let db = state.open_db()?;
    Ok(Json(Value::Array(query_rows(
        db.connection(),
        "SELECT id,type,title,message,link,link_type,is_read,created_at FROM notifications WHERE is_read=0 ORDER BY created_at DESC LIMIT 20",
        [],
    )?)))
}

async fn api_projects(State(state): State<ServerState>) -> Result<Json<Value>, ApiError> {
    let db = state.open_db()?;
    Ok(Json(Value::Array(query_rows(
        db.connection(),
        "SELECT id,name,path FROM projects ORDER BY name COLLATE NOCASE",
        [],
    )?)))
}

#[derive(Deserialize)]
struct ProjectCreateBody {
    name: String,
    description: Option<String>,
    repo: Option<String>,
    path: Option<String>,
}

async fn api_project_create(
    State(state): State<ServerState>,
    Json(body): Json<ProjectCreateBody>,
) -> Result<Json<Value>, ApiError> {
    let name = body.name.trim();
    if name.is_empty() {
        return Err(ApiError::bad_request("name is required"));
    }
    let path = body
        .path
        .as_deref()
        .map(str::trim)
        .filter(|value| !value.is_empty())
        .map(str::to_string)
        .or_else(|| {
            body.repo
                .as_deref()
                .map(str::trim)
                .filter(|value| !value.is_empty())
                .map(str::to_string)
        });
    let ts = std::time::SystemTime::now()
        .duration_since(std::time::UNIX_EPOCH)
        .map(|duration| duration.as_secs())
        .unwrap_or(0);
    let project_id = format!(
        "{}-{ts}",
        name.to_lowercase()
            .chars()
            .map(|ch| if ch.is_ascii_alphanumeric() { ch } else { '-' })
            .collect::<String>()
            .trim_matches('-')
    );

    let db = state.open_db()?;
    db.connection()
        .execute(
            "INSERT INTO projects(id,name,path) VALUES(?1,?2,?3)",
            rusqlite::params![project_id, name, path],
        )
        .map_err(|err| ApiError::internal(format!("create project failed: {err}")))?;

    Ok(Json(json!({
        "ok": true,
        "project": {
            "id": project_id,
            "name": name,
            "path": path,
            "description": body.description.unwrap_or_default(),
            "repo": body.repo.unwrap_or_default()
        }
    })))
}

fn parse_positive_i64(qs: &HashMap<String, String>, key: &str, default_value: i64) -> Result<i64, ApiError> {
    let value = qs
        .get(key)
        .map(|raw| raw.parse::<i64>().map_err(|_| ApiError::bad_request(format!("invalid {key}"))))
        .transpose()?
        .unwrap_or(default_value);
    if value < 1 {
        return Err(ApiError::bad_request(format!("{key} must be >= 1")));
    }
    Ok(value)
}

fn parse_json_text_field(row: &mut Value, field: &str) -> Result<(), ApiError> {
    let raw = row
        .get(field)
        .and_then(Value::as_str)
        .map(str::trim)
        .filter(|value| !value.is_empty())
        .map(str::to_owned);
    if let Some(raw) = raw {
        let parsed = serde_json::from_str::<Value>(&raw)
            .map_err(|err| ApiError::internal(format!("invalid {field}: {err}")))?;
        if let Some(object) = row.as_object_mut() {
            object.insert(field.to_string(), parsed);
        }
    }
    Ok(())
}

fn spawn_nightly_guardian(project_id: &str, trigger_source: &str, parent_run_id: Option<&str>) {
    #[cfg(test)]
    {
        let _ = (project_id, trigger_source, parent_run_id);
        return;
    }

    #[cfg(not(test))]
    {
    let claude_home = env::var("CLAUDE_HOME")
        .map(std::path::PathBuf::from)
        .unwrap_or_else(|_| {
            env::var("HOME")
                .map(std::path::PathBuf::from)
                .unwrap_or_else(|_| std::path::PathBuf::from("."))
                .join(".claude")
        });
    let script_name = format!("{project_id}-nightly-guardian.sh");
    let script_path = claude_home.join(format!("scripts/{script_name}"));
    if !script_path.exists() {
        eprintln!(
            "[api_dashboard] nightly guardian script not found: {} (project: {})",
            script_path.display(), project_id
        );
        return;
    }

    let mut command = Command::new(script_path);
    command
        .arg(format!("--trigger={trigger_source}"))
        .stdin(std::process::Stdio::null())
        .stdout(std::process::Stdio::null())
        .stderr(std::process::Stdio::null());
    if let Some(parent_run_id) = parent_run_id.filter(|value| !value.is_empty()) {
        command.arg(format!("--parent-run-id={parent_run_id}"));
    }
    if let Err(err) = command.spawn() {
        eprintln!("[api_dashboard] failed to spawn nightly guardian for {project_id}: {err}");
    }
    }
}

async fn api_nightly_jobs(
    State(state): State<ServerState>,
    Query(qs): Query<HashMap<String, String>>,
) -> Result<Json<Value>, ApiError> {
    let db = state.open_db()?;
    let page = parse_positive_i64(&qs, "page", 1)?;
    let per_page = parse_positive_i64(&qs, "per_page", 50)?.min(100);
    let offset = (page - 1) * per_page;
    let list_sql = "SELECT id, run_id, job_name, started_at, finished_at, host, status,
            sentry_unresolved, github_open_issues, processed_items, fixed_items,
            branch_name, pr_url, summary, report_json,
            duration_sec, trigger_source, exit_code, error_detail, log_file_path, parent_run_id
        FROM nightly_jobs ORDER BY started_at DESC LIMIT ?1 OFFSET ?2";
    let fallback_list_sql = "SELECT id, run_id, 'guardian' AS job_name, started_at, finished_at, host, status,
            sentry_unresolved, github_open_issues, processed_items, fixed_items,
            branch_name, pr_url, summary, report_json,
            NULL AS duration_sec, 'scheduled' AS trigger_source, NULL AS exit_code, NULL AS error_detail,
            NULL AS log_file_path, NULL AS parent_run_id
        FROM nightly_jobs ORDER BY started_at DESC LIMIT ?1 OFFSET ?2";
    let rows = query_rows(
        db.connection(),
        list_sql,
        rusqlite::params![per_page, offset],
    )
    .or_else(|_| {
        query_rows(
            db.connection(),
            fallback_list_sql,
            rusqlite::params![per_page, offset],
        )
    })?;
    let latest = query_one(
        db.connection(),
        "SELECT id, run_id, job_name, started_at, finished_at, host, status,
            sentry_unresolved, github_open_issues, processed_items, fixed_items,
            branch_name, pr_url, summary, report_json,
            duration_sec, trigger_source, exit_code, error_detail, log_file_path, parent_run_id
        FROM nightly_jobs ORDER BY started_at DESC LIMIT 1",
        [],
    )
    .or_else(|_| {
        query_one(
            db.connection(),
            "SELECT id, run_id, 'guardian' AS job_name, started_at, finished_at, host, status,
                sentry_unresolved, github_open_issues, processed_items, fixed_items,
                branch_name, pr_url, summary, report_json,
                NULL AS duration_sec, 'scheduled' AS trigger_source, NULL AS exit_code, NULL AS error_detail,
                NULL AS log_file_path, NULL AS parent_run_id
            FROM nightly_jobs ORDER BY started_at DESC LIMIT 1",
            [],
        )
    })?;
    let total = query_one(db.connection(), "SELECT COUNT(*) AS total FROM nightly_jobs", [])?
        .and_then(|row| row.get("total").and_then(Value::as_i64))
        .unwrap_or(0);
    let definitions = query_rows(
        db.connection(),
        "SELECT id,name,description,schedule,script_path,target_host,enabled,created_at,project_id,run_fixes,timeout_sec FROM nightly_job_definitions ORDER BY name",
        [],
    ).unwrap_or_default();
    Ok(Json(json!({
        "ok": true,
        "latest": latest,
        "history": rows,
        "definitions": definitions,
        "page": page,
        "per_page": per_page,
        "total": total
    })))
}

async fn api_nightly_job_detail(
    State(state): State<ServerState>,
    Path(id): Path<i64>,
) -> Result<Json<Value>, ApiError> {
    let db = state.open_db()?;
    let mut row = query_one(
        db.connection(),
        "SELECT id, run_id, job_name, started_at, finished_at, host, status,
            sentry_unresolved, github_open_issues, processed_items, fixed_items,
            branch_name, pr_url, summary, report_json,
            duration_sec, trigger_source, exit_code, error_detail, log_file_path, parent_run_id,
            log_stdout, log_stderr, config_snapshot
        FROM nightly_jobs WHERE id = ?1",
        rusqlite::params![id],
    )
    .or_else(|_| {
        query_one(
            db.connection(),
            "SELECT id, run_id, 'guardian' AS job_name, started_at, finished_at, host, status,
                sentry_unresolved, github_open_issues, processed_items, fixed_items,
                branch_name, pr_url, summary, report_json,
                NULL AS duration_sec, 'scheduled' AS trigger_source, NULL AS exit_code, NULL AS error_detail,
                NULL AS log_file_path, NULL AS parent_run_id,
                NULL AS log_stdout, NULL AS log_stderr, NULL AS config_snapshot
            FROM nightly_jobs WHERE id = ?1",
            rusqlite::params![id],
        )
    })?
    .ok_or_else(|| ApiError::bad_request(format!("nightly job {id} not found")))?;
    parse_json_text_field(&mut row, "report_json")?;
    parse_json_text_field(&mut row, "config_snapshot")?;
    let log_available = row
        .get("log_file_path")
        .and_then(Value::as_str)
        .map(|path| !path.is_empty() && FsPath::new(path).exists())
        .unwrap_or(false);
    if let Some(object) = row.as_object_mut() {
        object.insert("log_available".to_string(), Value::Bool(log_available));
    }
    Ok(Json(row))
}

#[derive(Deserialize)]
struct TriggerPayload {
    project_id: Option<String>,
}

#[derive(Deserialize)]
struct ConfigUpdate {
    run_fixes: Option<i32>,
    schedule: Option<String>,
    timeout_sec: Option<i32>,
}

#[derive(Deserialize)]
struct NightlyJobCreatePayload {
    name: String,
    script_path: String,
    #[serde(default = "default_schedule")]
    schedule: String,
    #[serde(default)]
    description: String,
    #[serde(default = "default_host")]
    target_host: String,
    #[serde(default = "default_project")]
    project_id: String,
}
fn default_schedule() -> String { "0 3 * * *".to_string() }
fn default_host() -> String { "local".to_string() }
fn default_project() -> String { "mirrorbuddy".to_string() }

async fn api_nightly_job_retry(
    State(state): State<ServerState>,
    Path(id): Path<i64>,
) -> Result<Json<Value>, ApiError> {
    let db = state.open_db()?;
    let original = query_one(
        db.connection(),
        "SELECT run_id, job_name FROM nightly_jobs WHERE id=?1",
        rusqlite::params![id],
    )?
    .ok_or_else(|| ApiError::bad_request(format!("nightly job {id} not found")))?;
    let parent_run_id = original
        .get("run_id")
        .and_then(Value::as_str)
        .filter(|value| !value.is_empty())
        .map(str::to_owned);
    let project_id = original.get("job_name").and_then(Value::as_str)
        .and_then(|name| name.split('-').next())
        .unwrap_or("mirrorbuddy");
    spawn_nightly_guardian(project_id, "retry", parent_run_id.as_deref());
    Ok(Json(json!({"ok": true, "triggered": true, "parent_run_id": parent_run_id, "project_id": project_id})))
}

async fn api_nightly_job_trigger(
    axum::Json(payload): axum::Json<TriggerPayload>,
) -> Result<Json<Value>, ApiError> {
    let project_id = payload
        .project_id
        .map(|value| value.trim().to_string())
        .filter(|value| !value.is_empty())
        .unwrap_or_else(|| "mirrorbuddy".to_string());
    spawn_nightly_guardian(&project_id, "manual", None);
    Ok(Json(json!({"ok": true, "triggered": true, "project_id": project_id})))
}

async fn api_nightly_config_get(
    State(state): State<ServerState>,
    Path(project_id): Path<String>,
) -> Result<Json<Value>, ApiError> {
    let db = state.open_db()?;
    let rows = query_rows(
        db.connection(),
        "SELECT id, name, description, schedule, script_path, target_host, enabled, run_fixes, timeout_sec FROM nightly_job_definitions WHERE project_id=?1 ORDER BY name",
        rusqlite::params![&project_id],
    )?;
    Ok(Json(json!({"ok": true, "project_id": project_id, "definitions": rows})))
}

async fn api_nightly_config_update(
    State(state): State<ServerState>,
    Path(project_id): Path<String>,
    axum::Json(payload): axum::Json<ConfigUpdate>,
) -> Result<Json<Value>, ApiError> {
    let db = state.open_db()?;
    let mut updated_fields = 0usize;

    if let Some(run_fixes) = payload.run_fixes {
        updated_fields += db
            .connection()
            .execute(
                "UPDATE nightly_job_definitions SET run_fixes=?1 WHERE project_id=?2",
                rusqlite::params![run_fixes, &project_id],
            )
            .map_err(|err| ApiError::internal(format!("config update failed: {err}")))?;
    }
    if let Some(schedule) = payload.schedule {
        let schedule = schedule.trim().to_string();
        if schedule.is_empty() {
            return Err(ApiError::bad_request("schedule must not be empty"));
        }
        updated_fields += db
            .connection()
            .execute(
                "UPDATE nightly_job_definitions SET schedule=?1 WHERE project_id=?2",
                rusqlite::params![schedule, &project_id],
            )
            .map_err(|err| ApiError::internal(format!("config update failed: {err}")))?;
    }
    if let Some(timeout_sec) = payload.timeout_sec {
        updated_fields += db
            .connection()
            .execute(
                "UPDATE nightly_job_definitions SET timeout_sec=?1 WHERE project_id=?2",
                rusqlite::params![timeout_sec, &project_id],
            )
            .map_err(|err| ApiError::internal(format!("config update failed: {err}")))?;
    }

    Ok(Json(json!({"ok": true, "updated": project_id, "rows_affected": updated_fields})))
}

async fn api_nightly_def_toggle(
    State(state): State<ServerState>,
    Path(id): Path<i64>,
) -> Result<Json<Value>, ApiError> {
    let db = state.open_db()?;
    let updated = db
        .connection()
        .execute(
            "UPDATE nightly_job_definitions SET enabled = CASE WHEN enabled=1 THEN 0 ELSE 1 END WHERE id=?1",
            rusqlite::params![id],
        )
        .map_err(|err| ApiError::internal(format!("toggle failed: {err}")))?;
    if updated == 0 {
        return Err(ApiError::bad_request(format!(
            "nightly job definition {id} not found"
        )));
    }
    let enabled: i64 = db
        .connection()
        .query_row(
            "SELECT enabled FROM nightly_job_definitions WHERE id=?1",
            rusqlite::params![id],
            |row| row.get(0),
        )
        .map_err(|err| ApiError::internal(format!("toggle readback failed: {err}")))?;
    Ok(Json(json!({"ok": true, "id": id, "enabled": enabled == 1})))
}

async fn api_nightly_job_create(
    State(state): State<ServerState>,
    axum::Json(payload): axum::Json<NightlyJobCreatePayload>,
) -> Result<Json<Value>, ApiError> {
    let name = payload.name.trim().to_string();
    let script = payload.script_path.trim().to_string();
    if name.is_empty() || script.is_empty() {
        return Err(ApiError::bad_request("name and script_path are required"));
    }
    let db = state.open_db()?;
    db.connection()
        .execute(
            "INSERT INTO nightly_job_definitions (name,description,schedule,script_path,target_host,project_id) VALUES (?1,?2,?3,?4,?5,?6)",
            rusqlite::params![name, payload.description, payload.schedule, script, payload.target_host, payload.project_id],
        )
        .map_err(|err| ApiError::internal(format!("create job failed: {err}")))?;
    Ok(Json(json!({"ok": true, "name": name})))
}

async fn api_events(State(state): State<ServerState>) -> Result<Json<Value>, ApiError> {
    let db = state.open_db()?;
    Ok(Json(Value::Array(query_rows(
        db.connection(),
        "SELECT id,event_type,plan_id,source_peer,payload,status,created_at FROM mesh_events ORDER BY created_at DESC LIMIT 50",
        [],
    )?)))
}

async fn api_coordinator_status(State(state): State<ServerState>) -> Result<Json<Value>, ApiError> {
    let db = state.open_db()?;
    let pending = query_one(
        db.connection(),
        "SELECT COUNT(*) AS pending_events FROM mesh_events WHERE status='pending'",
        [],
    )?
    .unwrap_or_else(|| json!({"pending_events": 0}));
    Ok(Json(json!({"running": false, "pid": "", "pending_events": pending["pending_events"]})))
}

async fn api_coordinator_toggle() -> Json<Value> {
    Json(json!({"ok": true, "action": "noop"}))
}

#[derive(Deserialize)]
struct PlanStatusPayload {
    plan_id: i64,
    status: String,
}

async fn api_plan_status(
    State(state): State<ServerState>,
    axum::Json(payload): axum::Json<PlanStatusPayload>,
) -> Result<Json<Value>, ApiError> {
    if !matches!(payload.status.as_str(), "todo" | "doing" | "done" | "cancelled") {
        return Err(ApiError::bad_request("Invalid status"));
    }
    let db = state.open_db()?;
    db.connection()
        .execute(
            "UPDATE plans SET status=?1 WHERE id=?2",
            rusqlite::params![payload.status, payload.plan_id],
        )
        .map_err(|err| ApiError::internal(format!("status update failed: {err}")))?;
    Ok(Json(json!({"ok": true, "plan_id": payload.plan_id, "status": payload.status})))
}

async fn api_optimize_signals() -> Json<Value> {
    let home = std::env::var("HOME").unwrap_or_else(|_| "/tmp".to_string());
    let path = format!("{home}/.claude/data/session-learnings.jsonl");
    let content = std::fs::read_to_string(&path).unwrap_or_default();
    if content.trim().is_empty() {
        return Json(json!({"count": 0, "signals": [], "by_type": []}));
    }
    let entries: Vec<Value> = content
        .lines()
        .filter_map(|l| serde_json::from_str(l).ok())
        .collect();
    let count = entries.len();
    let mut type_counts: HashMap<String, (i64, Vec<Value>)> = HashMap::new();
    for entry in &entries {
        if let Some(signals) = entry.get("signals").and_then(Value::as_array) {
            for sig in signals {
                let sig_type = sig
                    .get("type")
                    .and_then(Value::as_str)
                    .unwrap_or("unknown")
                    .to_string();
                let e = type_counts.entry(sig_type).or_insert((0, Vec::new()));
                e.0 += 1;
                if e.1.len() < 3 {
                    e.1.push(sig.get("data").cloned().unwrap_or(Value::Null));
                }
            }
        }
    }
    let by_type: Vec<Value> = type_counts
        .into_iter()
        .map(|(t, (c, samples))| json!({"type": t, "count": c, "samples": samples}))
        .collect();
    let projects: Vec<String> = entries
        .iter()
        .filter_map(|e| e.get("project").and_then(Value::as_str).map(String::from))
        .collect::<std::collections::HashSet<_>>()
        .into_iter()
        .collect();
    Json(json!({
        "count": count,
        "signals": entries,
        "by_type": by_type,
        "projects": projects,
    }))
}

async fn api_optimize_clear() -> Json<Value> {
    let home = std::env::var("HOME").unwrap_or_else(|_| "/tmp".to_string());
    let src = format!("{home}/.claude/data/session-learnings.jsonl");
    let archive = format!("{home}/.claude/data/session-learnings-archive.jsonl");
    let content = std::fs::read_to_string(&src).unwrap_or_default();
    if !content.is_empty() {
        use std::io::Write;
        if let Ok(mut f) = std::fs::OpenOptions::new().create(true).append(true).open(&archive) {
            let _ = f.write_all(content.as_bytes());
        }
        let _ = std::fs::write(&src, "");
    }
    Json(json!({"ok": true, "archived": !content.is_empty()}))
}
