"""SQLite data layer for dashboard-textual TUI.

Reads dashboard.db; catches OperationalError — returns empty, never raises.
"""

from __future__ import annotations

import sqlite3
from pathlib import Path
from typing import Any, Optional

from .models import Plan, Wave, Task, Peer, TokenStats

_DEFAULT_DB = Path.home() / ".claude" / "data" / "dashboard.db"
_PLAN_COLS = "id,name,status,tasks_done,tasks_total,created_at,worktree_path,started_at,completed_at,project_id,human_summary,execution_host,parallel_mode"
_TASK_COLS = "id,task_id,wave_id,title,status,plan_id,wave_id_fk,priority,assignee,tokens,started_at,completed_at,validated_at,validated_by,executor_agent,executor_host,notes,description"


class DashboardDB:
    """Read-only interface to dashboard.db."""

    def __init__(self, db_path: Optional[str] = None) -> None:
        self.db_path = str(db_path) if db_path else str(_DEFAULT_DB)

    def _connect(self) -> sqlite3.Connection:
        conn = sqlite3.connect(self.db_path, timeout=5.0)
        conn.row_factory = sqlite3.Row
        return conn

    def _query(self, sql: str, params: tuple = ()) -> list[sqlite3.Row]:
        """Execute query; return empty list on any error."""
        try:
            with self._connect() as conn:
                cur = conn.execute(sql, params)
                return cur.fetchall()
        except (sqlite3.OperationalError, sqlite3.DatabaseError):
            return []

    def _query_one(self, sql: str, params: tuple = ()) -> Optional[sqlite3.Row]:
        """Execute query; return None on error."""
        rows = self._query(sql, params)
        return rows[0] if rows else None

    def get_overview(self) -> dict[str, Any]:
        """Counts for overview panel."""
        sql = """
            SELECT
                COUNT(*) FILTER (WHERE status IN ('todo','doing')) AS active_plans,
                COUNT(*) FILTER (WHERE status = 'done') AS done_plans,
                COUNT(*) FILTER (WHERE status = 'cancelled') AS cancelled_plans,
                COUNT(*) AS total_plans
            FROM plans
        """
        row = self._query_one(sql)
        if row is None:
            return {
                "active_plans": 0,
                "done_plans": 0,
                "cancelled_plans": 0,
                "total_plans": 0,
            }
        return dict(row)

    def get_active_plans(self) -> list[Plan]:
        """Plans with status todo or doing, ordered by id desc.
        Computes tasks_done/tasks_total live from tasks table (Thor-validated only)."""
        sql = f"""SELECT p.*,
            (SELECT COUNT(*) FROM tasks t WHERE t.plan_id=p.id AND t.status='done' AND t.validated_at IS NOT NULL) AS live_done,
            (SELECT COUNT(*) FROM tasks t WHERE t.plan_id=p.id AND t.status NOT IN ('cancelled','skipped')) AS live_total
            FROM plans p WHERE p.status IN ('todo','doing') ORDER BY p.id DESC"""
        rows = self._query(sql)
        plans = []
        for r in rows:
            plan = self._row_to_plan(r)
            plan.tasks_done = r["live_done"] or 0
            plan.tasks_total = r["live_total"] or 0
            plans.append(plan)
        return plans

    def get_completed_plans(self, limit: int = 20) -> list[Plan]:
        """Recently completed plans."""
        sql = f"SELECT {_PLAN_COLS} FROM plans WHERE status IN ('done','archived','cancelled') ORDER BY completed_at DESC NULLS LAST LIMIT ?"
        return [self._row_to_plan(r) for r in self._query(sql, (limit,))]

    def get_peers(self) -> list[Peer]:
        """All peers from peer_heartbeats table."""
        sql = """
            SELECT peer_name, last_seen, capabilities, load_json, updated_at
            FROM peer_heartbeats
            ORDER BY last_seen DESC
        """
        rows = self._query(sql)
        peers = []
        for r in rows:
            peers.append(
                Peer(
                    peer_name=r["peer_name"],
                    last_seen=r["last_seen"] or 0,
                    capabilities=r["capabilities"],
                    load_json=r["load_json"],
                    updated_at=r["updated_at"],
                )
            )
        return peers

    def get_token_stats(self) -> TokenStats:
        """Aggregate token usage from token_usage table."""
        all_sql = """
            SELECT
                COALESCE(SUM(input_tokens), 0) AS total_input,
                COALESCE(SUM(output_tokens), 0) AS total_output,
                COALESCE(SUM(cost_usd), 0.0) AS total_cost_usd
            FROM token_usage
        """
        today_sql = """
            SELECT
                COALESCE(SUM(input_tokens), 0) AS today_input,
                COALESCE(SUM(output_tokens), 0) AS today_output,
                COALESCE(SUM(cost_usd), 0.0) AS today_cost_usd
            FROM token_usage
            WHERE date(created_at) = date('now')
        """
        models_sql = """
            SELECT model,
                   SUM(input_tokens + output_tokens) AS total_tokens,
                   SUM(cost_usd) AS cost_usd
            FROM token_usage
            WHERE model IS NOT NULL
            GROUP BY model
            ORDER BY total_tokens DESC
            LIMIT 5
        """
        all_row = self._query_one(all_sql)
        today_row = self._query_one(today_sql)
        model_rows = self._query(models_sql)

        return TokenStats(
            total_input=all_row["total_input"] if all_row else 0,
            total_output=all_row["total_output"] if all_row else 0,
            total_cost_usd=all_row["total_cost_usd"] if all_row else 0.0,
            today_input=today_row["today_input"] if today_row else 0,
            today_output=today_row["today_output"] if today_row else 0,
            today_cost_usd=today_row["today_cost_usd"] if today_row else 0.0,
            top_models=[dict(r) for r in model_rows],
        )

    def get_plan_waves(self, plan_id: int) -> list[Wave]:
        """Waves for a specific plan."""
        sql = """
            SELECT id, wave_id, name, status, tasks_done, tasks_total,
                   plan_id, position, started_at, completed_at,
                   branch_name, pr_number, pr_url, worktree_path, theme
            FROM waves
            WHERE plan_id = ?
            ORDER BY position ASC
        """
        return [self._row_to_wave(r) for r in self._query(sql, (plan_id,))]

    def get_wave_tasks(self, wave_id_fk: int) -> list[Task]:
        """Tasks for a specific wave (by wave FK id)."""
        sql = f"SELECT {_TASK_COLS} FROM tasks WHERE wave_id_fk = ? ORDER BY id ASC"
        return [self._row_to_task(r) for r in self._query(sql, (wave_id_fk,))]

    def get_plan_tasks(self, plan_id: int) -> list[Task]:
        """All tasks for a plan."""
        sql = f"SELECT {_TASK_COLS} FROM tasks WHERE plan_id = ? ORDER BY wave_id_fk ASC, id ASC"
        return [self._row_to_task(r) for r in self._query(sql, (plan_id,))]

    def get_plan_by_id(self, plan_id: int) -> Optional[Plan]:
        """Single plan by id."""
        sql = f"SELECT {_PLAN_COLS} FROM plans WHERE id = ?"
        row = self._query_one(sql, (plan_id,))
        return self._row_to_plan(row) if row else None

    # --- Private helpers ---

    @staticmethod
    def _row_to_plan(row: sqlite3.Row) -> Plan:
        return Plan(
            id=row["id"],
            name=row["name"],
            status=row["status"],
            tasks_done=row["tasks_done"] or 0,
            tasks_total=row["tasks_total"] or 0,
            created_at=row["created_at"] or "",
            worktree_path=row["worktree_path"],
            started_at=row["started_at"],
            completed_at=row["completed_at"],
            project_id=row["project_id"],
            human_summary=row["human_summary"],
            execution_host=row["execution_host"],
            parallel_mode=row["parallel_mode"] or "standard",
        )

    @staticmethod
    def _row_to_wave(row: sqlite3.Row) -> Wave:
        return Wave(
            id=row["id"],
            wave_id=row["wave_id"],
            name=row["name"],
            status=row["status"],
            tasks_done=row["tasks_done"] or 0,
            tasks_total=row["tasks_total"] or 0,
            plan_id=row["plan_id"],
            position=row["position"] or 0,
            started_at=row["started_at"],
            completed_at=row["completed_at"],
            branch_name=row["branch_name"],
            pr_number=row["pr_number"],
            pr_url=row["pr_url"],
            worktree_path=row["worktree_path"],
            theme=row["theme"],
        )

    @staticmethod
    def _row_to_task(row: sqlite3.Row) -> Task:
        return Task(
            id=row["id"],
            task_id=row["task_id"],
            wave_id=row["wave_id"],
            title=row["title"],
            status=row["status"],
            plan_id=row["plan_id"],
            wave_id_fk=row["wave_id_fk"],
            priority=row["priority"],
            assignee=row["assignee"],
            tokens=row["tokens"] or 0,
            started_at=row["started_at"],
            completed_at=row["completed_at"],
            validated_at=row["validated_at"],
            validated_by=row["validated_by"],
            executor_agent=row["executor_agent"],
            executor_host=row["executor_host"],
            notes=row["notes"],
            description=row["description"],
        )
