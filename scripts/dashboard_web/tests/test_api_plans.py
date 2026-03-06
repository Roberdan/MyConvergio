"""Tests for api_plans.py: cancel, reset, move plan handlers."""

import sqlite3
import sys
from pathlib import Path
from unittest.mock import patch

import pytest

sys.path.insert(0, str(Path(__file__).parent.parent))


@pytest.fixture
def test_db(tmp_path):
    """Create a temporary SQLite DB with plans/waves/tasks tables."""
    db = tmp_path / "dashboard.db"
    conn = sqlite3.connect(str(db))
    conn.executescript(
        """
        CREATE TABLE plans (
            id INTEGER PRIMARY KEY, name TEXT, status TEXT,
            tasks_done INTEGER DEFAULT 0, execution_host TEXT
        );
        CREATE TABLE waves (
            id INTEGER PRIMARY KEY, plan_id INTEGER,
            wave_id TEXT, status TEXT, tasks_done INTEGER DEFAULT 0
        );
        CREATE TABLE tasks (
            id INTEGER PRIMARY KEY, plan_id INTEGER,
            task_id TEXT, title TEXT, status TEXT,
            executor_agent TEXT, executor_host TEXT,
            tokens INTEGER, validated_at TEXT,
            started_at TEXT, completed_at TEXT
        );
    """
    )
    # Seed data: plan 100 with 2 waves, 4 tasks
    conn.execute("INSERT INTO plans VALUES (100,'Test Plan','doing',2,'m3max')")
    conn.execute("INSERT INTO waves VALUES (1,100,'W1','done',2)")
    conn.execute("INSERT INTO waves VALUES (2,100,'W2','in_progress',0)")
    conn.execute(
        "INSERT INTO tasks VALUES (1,100,'T1','Task 1','done','sonnet','m3max',1000,'2026-01-01','2026-01-01','2026-01-01')"
    )
    conn.execute(
        "INSERT INTO tasks VALUES (2,100,'T2','Task 2','done','sonnet','m3max',2000,'2026-01-01','2026-01-01','2026-01-01')"
    )
    conn.execute(
        "INSERT INTO tasks VALUES (3,100,'T3','Task 3','in_progress','haiku','m3max',500,NULL,'2026-01-02',NULL)"
    )
    conn.execute(
        "INSERT INTO tasks VALUES (4,100,'T4','Task 4','pending',NULL,NULL,NULL,NULL,NULL,NULL)"
    )
    conn.commit()
    conn.close()
    return db


@pytest.fixture(autouse=True)
def patch_db(test_db):
    """Patch DB_PATH in api_plans to use temp DB."""
    with patch("api_plans.DB_PATH", test_db):
        yield test_db


# --- handle_plan_cancel ---


class TestPlanCancel:
    def test_cancel_sets_plan_status(self, test_db):
        from api_plans import handle_plan_cancel

        result = handle_plan_cancel({"plan_id": ["100"]})
        assert result["ok"] is True
        assert result["action"] == "cancelled"

        conn = sqlite3.connect(str(test_db))
        plan = conn.execute("SELECT status FROM plans WHERE id=100").fetchone()
        assert plan[0] == "cancelled"
        conn.close()

    def test_cancel_cascades_to_waves(self, test_db):
        from api_plans import handle_plan_cancel

        handle_plan_cancel({"plan_id": ["100"]})

        conn = sqlite3.connect(str(test_db))
        waves = conn.execute(
            "SELECT wave_id, status FROM waves WHERE plan_id=100 ORDER BY id"
        ).fetchall()
        # W1 was done — should stay done
        assert waves[0] == ("W1", "done")
        # W2 was in_progress — should be cancelled
        assert waves[1] == ("W2", "cancelled")
        conn.close()

    def test_cancel_cascades_to_tasks(self, test_db):
        from api_plans import handle_plan_cancel

        handle_plan_cancel({"plan_id": ["100"]})

        conn = sqlite3.connect(str(test_db))
        tasks = conn.execute(
            "SELECT task_id, status FROM tasks WHERE plan_id=100 ORDER BY id"
        ).fetchall()
        # T1, T2 done — preserved
        assert tasks[0] == ("T1", "done")
        assert tasks[1] == ("T2", "done")
        # T3 in_progress, T4 pending — cancelled
        assert tasks[2] == ("T3", "cancelled")
        assert tasks[3] == ("T4", "cancelled")
        conn.close()

    def test_cancel_missing_plan_id(self):
        from api_plans import handle_plan_cancel

        result = handle_plan_cancel({})
        assert "error" in result
        assert "missing" in result["error"]

    def test_cancel_invalid_plan_id(self):
        from api_plans import handle_plan_cancel

        result = handle_plan_cancel({"plan_id": ["abc"]})
        assert "error" in result

    def test_cancel_nonexistent_plan(self):
        from api_plans import handle_plan_cancel

        result = handle_plan_cancel({"plan_id": ["999"]})
        assert "error" in result
        assert "not found" in result["error"]

    def test_cancel_already_cancelled_plan(self, test_db):
        """Cancelling already-cancelled plan should succeed (idempotent)."""
        from api_plans import handle_plan_cancel

        conn = sqlite3.connect(str(test_db))
        conn.execute("UPDATE plans SET status='cancelled' WHERE id=100")
        conn.commit()
        conn.close()

        result = handle_plan_cancel({"plan_id": ["100"]})
        assert result["ok"] is True


# --- handle_plan_reset ---


class TestPlanReset:
    def test_reset_sets_plan_to_todo(self, test_db):
        from api_plans import handle_plan_reset

        result = handle_plan_reset({"plan_id": ["100"]})
        assert result["ok"] is True
        assert result["action"] == "reset"

        conn = sqlite3.connect(str(test_db))
        plan = conn.execute(
            "SELECT status, tasks_done, execution_host FROM plans WHERE id=100"
        ).fetchone()
        assert plan[0] == "todo"
        assert plan[1] == 0
        assert plan[2] is None
        conn.close()

    def test_reset_resets_waves(self, test_db):
        from api_plans import handle_plan_reset

        handle_plan_reset({"plan_id": ["100"]})

        conn = sqlite3.connect(str(test_db))
        waves = conn.execute(
            "SELECT wave_id, status, tasks_done FROM waves WHERE plan_id=100 ORDER BY id"
        ).fetchall()
        assert waves[0] == ("W1", "pending", 0)
        assert waves[1] == ("W2", "pending", 0)
        conn.close()

    def test_reset_resets_non_done_tasks(self, test_db):
        from api_plans import handle_plan_reset

        handle_plan_reset({"plan_id": ["100"]})

        conn = sqlite3.connect(str(test_db))
        tasks = conn.execute(
            "SELECT task_id, status, executor_agent, executor_host, tokens, validated_at, started_at, completed_at FROM tasks WHERE plan_id=100 ORDER BY id"
        ).fetchall()
        # T1, T2 are done — preserved
        assert tasks[0][1] == "done"
        assert tasks[1][1] == "done"
        # T3 was in_progress — reset to pending
        assert tasks[2][1] == "pending"
        assert tasks[2][2] is None  # executor_agent cleared
        assert tasks[2][3] is None  # executor_host cleared
        assert tasks[2][4] is None  # tokens cleared
        # T4 was pending — stays pending
        assert tasks[3][1] == "pending"
        conn.close()

    def test_reset_missing_plan_id(self):
        from api_plans import handle_plan_reset

        result = handle_plan_reset({})
        assert "error" in result

    def test_reset_nonexistent_plan(self):
        from api_plans import handle_plan_reset

        result = handle_plan_reset({"plan_id": ["999"]})
        assert "error" in result
        assert "not found" in result["error"]


# --- handle_plan_move ---


class TestPlanMove:
    def test_move_updates_execution_host(self, test_db):
        from api_plans import handle_plan_move

        result = handle_plan_move({"plan_id": ["100"], "target": ["omarchy"]})
        assert result["ok"] is True
        assert result["target"] == "omarchy"

        conn = sqlite3.connect(str(test_db))
        plan = conn.execute("SELECT execution_host FROM plans WHERE id=100").fetchone()
        assert plan[0] == "omarchy"
        conn.close()

    def test_move_updates_pending_tasks(self, test_db):
        from api_plans import handle_plan_move

        handle_plan_move({"plan_id": ["100"], "target": ["omarchy"]})

        conn = sqlite3.connect(str(test_db))
        tasks = conn.execute(
            "SELECT task_id, executor_host FROM tasks WHERE plan_id=100 ORDER BY id"
        ).fetchall()
        # T1, T2 done — not updated
        assert tasks[0][1] == "m3max"
        assert tasks[1][1] == "m3max"
        # T3 in_progress — updated
        assert tasks[2][1] == "omarchy"
        # T4 pending — updated
        assert tasks[3][1] == "omarchy"
        conn.close()

    def test_move_missing_target(self):
        from api_plans import handle_plan_move

        result = handle_plan_move({"plan_id": ["100"]})
        assert "error" in result

    def test_move_missing_plan_id(self):
        from api_plans import handle_plan_move

        result = handle_plan_move({"target": ["omarchy"]})
        assert "error" in result


# --- Routes registration ---


class TestRoutesRegistration:
    def test_cancel_route_registered(self):
        import server

        # Verify the handler checks path == "/api/plan/cancel"
        src = Path(server.__file__).read_text()
        assert '"/api/plan/cancel"' in src

    def test_reset_route_registered(self):
        import server

        src = Path(server.__file__).read_text()
        assert '"/api/plan/reset"' in src

    def test_move_route_registered(self):
        import server

        src = Path(server.__file__).read_text()
        assert '"/api/plan/move"' in src
