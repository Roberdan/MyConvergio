"""Regression tests for canonical execution_host assignment."""

import sqlite3
import sys
from pathlib import Path
from unittest.mock import patch

sys.path.insert(0, str(Path(__file__).parent.parent))


class DummySseHandler:
    def __init__(self):
        self.events: list[tuple[str, object]] = []

    def _json_response(self, payload, _status=200):
        self.events.append(("json", payload))

    def _start_sse(self):
        self.events.append(("start", None))

    def _sse_send(self, event, payload):
        self.events.append((event, payload))


def test_plan_start_sse_claims_local_with_canonical_peer(tmp_path):
    from api_plans_sse import handle_plan_start_sse

    db = tmp_path / "dashboard.db"
    conn = sqlite3.connect(str(db))
    conn.execute(
        "CREATE TABLE plans (id INTEGER PRIMARY KEY, status TEXT, execution_host TEXT)"
    )
    conn.execute("INSERT INTO plans(id,status,execution_host) VALUES (42,'todo',NULL)")
    conn.commit()
    conn.close()

    handler = DummySseHandler()
    with (
        patch("api_plans_sse.DB_PATH", db),
        patch("api_plans_sse.local_peer_name", return_value="m3max"),
        patch("api_plans_sse.resolve_host_to_peer", side_effect=lambda h: h),
        patch("api_plans_sse.run_command_sse", return_value=None),
    ):
        handle_plan_start_sse(
            handler,
            {
                "plan_id": ["42"],
                "cli": ["copilot"],
                "target": ["local"],
                "model": ["gpt-5.3-codex"],
            },
        )

    conn = sqlite3.connect(str(db))
    row = conn.execute("SELECT status, execution_host FROM plans WHERE id=42").fetchone()
    conn.close()
    assert row == ("doing", "m3max")
    assert ("log", "✓ Plan claimed by m3max") in handler.events


def test_reverse_sync_restores_canonical_local_peer_name():
    from mesh_handoff_sync import reverse_sync

    sql_calls: list[str] = []

    def fake_sql(statement: str) -> str:
        sql_calls.append(statement)
        if "SELECT COALESCE(worktree_path" in statement:
            return ""
        return ""

    logs: list[str] = []
    with (
        patch("mesh_handoff_sync._sql", side_effect=fake_sql),
        patch("mesh_handoff_sync.pull_db_from_peer", return_value=(True, "ok")),
        patch("mesh_handoff_sync.local_peer_name", return_value="m3max"),
        patch("mesh_handoff_sync.resolve_host_to_peer", return_value="m3max"),
    ):
        ok, _ = reverse_sync("omarchy", 99, logs.append)

    assert ok is True
    assert any(
        "UPDATE plans SET execution_host='m3max' WHERE id=99;" in stmt
        for stmt in sql_calls
    )
