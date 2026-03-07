import json
import logging
import sqlite3
import sys
from pathlib import Path

DB_PATH = Path.home() / ".claude" / "data" / "dashboard.db"
PEERS_CONF = Path.home() / ".claude" / "config" / "peers.conf"
PORT = 8420
ALLOWED_ORIGINS = {f"http://localhost:{PORT}", f"http://127.0.0.1:{PORT}"}

_log = logging.getLogger("dashboard.db")
if not _log.handlers:
    _h = logging.StreamHandler(sys.stderr)
    _h.setFormatter(logging.Formatter("\033[31m[SQL ERROR]\033[0m %(message)s"))
    _log.addHandler(_h)
    _log.setLevel(logging.WARNING)


def query(sql: str, params: tuple = ()) -> list[dict]:
    try:
        with sqlite3.connect(str(DB_PATH), timeout=5) as conn:
            conn.row_factory = sqlite3.Row
            rows = conn.execute(sql, params).fetchall()
            return [dict(r) for r in rows]
    except (sqlite3.OperationalError, sqlite3.DatabaseError) as exc:
        _log.error("Query failed: %s | SQL: %.120s", exc, sql.replace("\n", " "))
        return []


def query_one(sql: str, params: tuple = ()) -> dict | None:
    rows = query(sql, params)
    return rows[0] if rows else None


# --- Startup SQL Validation ---
# Runs EXPLAIN on all critical queries at server boot to catch schema mismatches early.

_CRITICAL_QUERIES = [
    # api_dashboard.py
    (
        "overview:plans",
        "SELECT COUNT(*) FILTER (WHERE status IN ('todo','doing')) AS active, COUNT(*) FILTER (WHERE status='done') AS done, COUNT(*) AS total FROM plans",
    ),
    (
        "overview:running",
        "SELECT COUNT(*) AS c FROM tasks t JOIN waves w ON t.wave_id_fk=w.id JOIN plans p ON w.plan_id=p.id WHERE t.status='in_progress' AND p.status='doing'",
    ),
    (
        "overview:blocked",
        "SELECT COUNT(*) AS c FROM tasks t JOIN waves w ON t.wave_id_fk=w.id JOIN plans p ON w.plan_id=p.id WHERE p.status='doing' AND (t.status='blocked' OR (t.status='submitted' AND COALESCE(t.executor_last_activity, t.executor_started_at, t.started_at) < datetime('now', '-5 minutes')))",
    ),
    (
        "overview:tokens",
        "SELECT COALESCE(SUM(input_tokens+output_tokens),0) AS total_tok, COALESCE(SUM(cost_usd),0) AS total_cost FROM token_usage WHERE ((plan_id IS NOT NULL AND CAST(plan_id AS TEXT) != 'NULL') OR (task_id IS NOT NULL AND task_id != ''))",
    ),
    (
        "mission:plans",
        "SELECT p.id,p.name,p.status,p.tasks_done,p.tasks_total,p.human_summary,p.execution_host,p.parallel_mode,p.project_id,p.worktree_path,pr.name AS project_name,pr.path AS project_path FROM plans p LEFT JOIN projects pr ON p.project_id=pr.id WHERE p.status IN ('todo','doing') ORDER BY p.id DESC",
    ),
    (
        "mission:waves",
        "SELECT wave_id,name,status,tasks_done,tasks_total,position FROM waves WHERE plan_id=1 ORDER BY position",
    ),
    (
        "mission:tasks",
        "SELECT id,task_id,title,status,executor_agent,executor_host,tokens,validated_at,model,wave_id FROM tasks WHERE plan_id=1 ORDER BY wave_id_fk,id",
    ),
    (
        "tokens:daily",
        "SELECT date(created_at) AS day, SUM(input_tokens) AS input, SUM(output_tokens) AS output, SUM(cost_usd) AS cost FROM token_usage WHERE ((plan_id IS NOT NULL AND CAST(plan_id AS TEXT) != 'NULL') OR (task_id IS NOT NULL AND task_id != '')) AND date(created_at)>=date('now','-30 days') GROUP BY day ORDER BY day",
    ),
    (
        "tokens:models",
        "SELECT model, SUM(input_tokens+output_tokens) AS tokens, SUM(cost_usd) AS cost FROM token_usage WHERE ((plan_id IS NOT NULL AND CAST(plan_id AS TEXT) != 'NULL') OR (task_id IS NOT NULL AND task_id != '')) AND model IS NOT NULL GROUP BY model ORDER BY tokens DESC LIMIT 8",
    ),
    (
        "history",
        "SELECT id,name,status,tasks_done,tasks_total,project_id,started_at,completed_at,human_summary,lines_added,lines_removed FROM plans WHERE status IN ('done','cancelled') ORDER BY id DESC LIMIT 20",
    ),
    (
        "detail:plan",
        "SELECT id,name,status,tasks_done,tasks_total,project_id,human_summary,started_at,completed_at,parallel_mode,lines_added,lines_removed,execution_host FROM plans WHERE id=1",
    ),
    (
        "detail:waves",
        "SELECT wave_id,name,status,tasks_done,tasks_total,branch_name,pr_number,pr_url,position FROM waves WHERE plan_id=1 ORDER BY position",
    ),
    (
        "detail:tasks",
        "SELECT id,task_id,title,status,executor_agent,executor_host,tokens,started_at,completed_at,validated_at,model,wave_id FROM tasks WHERE plan_id=1 ORDER BY wave_id_fk,id",
    ),
    (
        "tasks:dist",
        "SELECT t.status, COUNT(*) AS count FROM tasks t JOIN waves w ON t.wave_id_fk=w.id JOIN plans p ON w.plan_id=p.id WHERE p.status='doing' GROUP BY t.status ORDER BY count DESC",
    ),
    (
        "tasks:blocked",
        "SELECT t.task_id, t.title, t.status, p.id AS plan_id, p.name AS plan_name FROM tasks t JOIN waves w ON t.wave_id_fk=w.id JOIN plans p ON w.plan_id=p.id WHERE t.status='blocked' AND p.status IN ('doing','todo')",
    ),
    (
        "notifications",
        "SELECT id, type, title, message, link, link_type, is_read, created_at FROM notifications WHERE is_read=0 ORDER BY created_at DESC LIMIT 20",
    ),
    (
        "events",
        "SELECT id, event_type, plan_id, source_peer, payload, status, created_at FROM mesh_events ORDER BY created_at DESC LIMIT 50",
    ),
    ("coordinator", "SELECT COUNT(*) AS c FROM mesh_events WHERE status='pending'"),
    ("heartbeats", "SELECT peer_name, last_seen FROM peer_heartbeats"),
    (
        "mesh:plans",
        "SELECT id,name,status,tasks_done,tasks_total,execution_host FROM plans WHERE status IN ('doing','todo') AND execution_host IS NOT NULL AND execution_host<>''",
    ),
]


def ensure_live_runtime_schema() -> None:
    conn = sqlite3.connect(str(DB_PATH), timeout=5)
    try:
        conn.executescript(
            """
            CREATE TABLE IF NOT EXISTS agent_runs (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                plan_id INTEGER,
                wave_id TEXT,
                task_id TEXT,
                parent_run_id INTEGER,
                agent_name TEXT NOT NULL,
                agent_role TEXT,
                model TEXT,
                peer_name TEXT,
                status TEXT NOT NULL CHECK(status IN ('queued','running','waiting','handoff','validating','blocked','completed','failed','cancelled')),
                current_task TEXT,
                metadata_json TEXT,
                started_at DATETIME DEFAULT CURRENT_TIMESTAMP,
                last_heartbeat DATETIME DEFAULT CURRENT_TIMESTAMP,
                completed_at DATETIME,
                FOREIGN KEY (plan_id) REFERENCES plans(id) ON DELETE CASCADE,
                FOREIGN KEY (parent_run_id) REFERENCES agent_runs(id) ON DELETE SET NULL
            );
            CREATE TABLE IF NOT EXISTS task_events (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                plan_id INTEGER,
                wave_id TEXT,
                task_id TEXT,
                run_id INTEGER,
                event_type TEXT NOT NULL,
                status TEXT,
                severity TEXT DEFAULT 'info',
                source_agent TEXT,
                target_agent TEXT,
                peer_name TEXT,
                message TEXT,
                payload TEXT,
                created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
                FOREIGN KEY (plan_id) REFERENCES plans(id) ON DELETE CASCADE,
                FOREIGN KEY (run_id) REFERENCES agent_runs(id) ON DELETE SET NULL
            );
            CREATE TABLE IF NOT EXISTS agent_handoffs (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                plan_id INTEGER,
                task_id TEXT,
                from_run_id INTEGER,
                to_run_id INTEGER,
                handoff_kind TEXT DEFAULT 'delegate',
                status TEXT NOT NULL CHECK(status IN ('proposed','accepted','completed','rejected','expired')),
                reason TEXT,
                payload TEXT,
                created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
                accepted_at DATETIME,
                completed_at DATETIME,
                FOREIGN KEY (plan_id) REFERENCES plans(id) ON DELETE CASCADE,
                FOREIGN KEY (from_run_id) REFERENCES agent_runs(id) ON DELETE SET NULL,
                FOREIGN KEY (to_run_id) REFERENCES agent_runs(id) ON DELETE SET NULL
            );
            CREATE INDEX IF NOT EXISTS idx_agent_runs_active ON agent_runs(status, peer_name, last_heartbeat);
            CREATE INDEX IF NOT EXISTS idx_agent_runs_plan ON agent_runs(plan_id, task_id);
            CREATE INDEX IF NOT EXISTS idx_task_events_plan ON task_events(plan_id, created_at DESC);
            CREATE INDEX IF NOT EXISTS idx_task_events_run ON task_events(run_id, created_at DESC);
            CREATE INDEX IF NOT EXISTS idx_agent_handoffs_plan ON agent_handoffs(plan_id, created_at DESC);
            """
        )
        conn.commit()
    finally:
        conn.close()


def validate_queries_on_boot() -> tuple[int, int, list[str]]:
    """Validate all critical SQL queries via EXPLAIN at startup.

    Returns (passed, failed, error_messages).
    """
    if not DB_PATH.exists():
        return (0, 0, ["DB not found — skipping validation"])
    conn = sqlite3.connect(str(DB_PATH), timeout=5)
    passed, failed, errors = 0, 0, []
    for label, sql in _CRITICAL_QUERIES:
        try:
            conn.execute(f"EXPLAIN {sql}")
            passed += 1
        except sqlite3.OperationalError as exc:
            failed += 1
            errors.append(f"  {label}: {exc}")
    conn.close()
    return (passed, failed, errors)


class MiddlewareMixin:
    def _allow_origin(self):
        origin = self.headers.get("Origin", "")
        if origin in ALLOWED_ORIGINS:
            self.send_header("Access-Control-Allow-Origin", origin)

    def _json_response(self, data, status=200):
        body = json.dumps(data, default=str).encode()
        self.send_response(status)
        self.send_header("Content-Type", "application/json")
        self._allow_origin()
        self.end_headers()
        self.wfile.write(body)

    def _start_sse(self):
        self.send_response(200)
        self.send_header("Content-Type", "text/event-stream")
        self.send_header("Cache-Control", "no-cache")
        self.send_header("Connection", "keep-alive")
        self._allow_origin()
        self.end_headers()

    def _sse_send(self, event: str, data):
        try:
            payload = data if isinstance(data, str) else json.dumps(data, default=str)
            self.wfile.write(f"event: {event}\ndata: {payload}\n\n".encode())
            self.wfile.flush()
        except (BrokenPipeError, ConnectionResetError):
            pass

    def end_headers(self):
        self.send_header("Cache-Control", "no-cache, no-store, must-revalidate")
        self.send_header("Pragma", "no-cache")
        self.send_header("X-Content-Type-Options", "nosniff")
        self.send_header("X-Frame-Options", "DENY")
        self.send_header(
            "Content-Security-Policy",
            "default-src 'self'; "
            "script-src 'self' 'unsafe-inline' https://cdn.jsdelivr.net; "
            "style-src 'self' 'unsafe-inline' https://cdn.jsdelivr.net https://fonts.googleapis.com; "
            "img-src 'self' data:; "
            "connect-src 'self' ws://localhost:* ws://127.0.0.1:*; "
            "font-src 'self' https://cdn.jsdelivr.net https://fonts.gstatic.com; "
            "frame-ancestors 'none'",
        )
        super().end_headers()
