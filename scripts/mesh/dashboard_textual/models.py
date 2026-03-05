"""Dataclass models for dashboard-textual TUI.

Maps to dashboard.db schema: plans, waves, tasks, peer_heartbeats, token_usage.
"""

from __future__ import annotations

from dataclasses import dataclass, field
from typing import Optional


@dataclass
class Plan:
    """Represents a row in the plans table."""

    id: int
    name: str
    status: str
    tasks_done: int
    tasks_total: int
    created_at: str
    worktree_path: Optional[str] = None
    started_at: Optional[str] = None
    completed_at: Optional[str] = None
    project_id: Optional[str] = None
    human_summary: Optional[str] = None
    execution_host: Optional[str] = None
    parallel_mode: str = "standard"

    @property
    def progress_pct(self) -> int:
        if self.tasks_total == 0:
            return 0
        return int(100 * self.tasks_done / self.tasks_total)

    @property
    def is_active(self) -> bool:
        return self.status in ("doing", "todo")

    @property
    def is_done(self) -> bool:
        return self.status in ("done", "archived")


@dataclass
class Wave:
    """Represents a row in the waves table."""

    id: int
    wave_id: str
    name: str
    status: str
    tasks_done: int
    tasks_total: int
    plan_id: Optional[int] = None
    position: int = 0
    started_at: Optional[str] = None
    completed_at: Optional[str] = None
    branch_name: Optional[str] = None
    pr_number: Optional[int] = None
    pr_url: Optional[str] = None
    worktree_path: Optional[str] = None
    theme: Optional[str] = None

    @property
    def progress_pct(self) -> int:
        if self.tasks_total == 0:
            return 0
        return int(100 * self.tasks_done / self.tasks_total)


@dataclass
class Task:
    """Represents a row in the tasks table."""

    id: int
    task_id: str
    wave_id: str
    title: str
    status: str
    plan_id: Optional[int] = None
    wave_id_fk: Optional[int] = None
    priority: Optional[str] = None
    assignee: Optional[str] = None
    tokens: int = 0
    started_at: Optional[str] = None
    completed_at: Optional[str] = None
    validated_at: Optional[str] = None
    validated_by: Optional[str] = None
    executor_agent: Optional[str] = None
    executor_host: Optional[str] = None
    notes: Optional[str] = None
    description: Optional[str] = None

    @property
    def is_done(self) -> bool:
        return self.status in ("done", "skipped", "cancelled")

    @property
    def status_icon(self) -> str:
        icons = {
            "done": "[green]✓[/green]",
            "in_progress": "[yellow]◉[/yellow]",
            "submitted": "[cyan]◈[/cyan]",
            "pending": "[white]○[/white]",
            "blocked": "[red]✗[/red]",
            "skipped": "[dim]─[/dim]",
            "cancelled": "[red]✗[/red]",
        }
        return icons.get(self.status, "?")


@dataclass
class Peer:
    """Represents a row in the peer_heartbeats table."""

    peer_name: str
    last_seen: int
    capabilities: Optional[str] = None
    load_json: Optional[str] = None
    updated_at: Optional[str] = None

    @property
    def is_online(self) -> bool:
        import time

        return (time.time() - self.last_seen) < 300

    @property
    def capability_list(self) -> list[str]:
        if not self.capabilities:
            return []
        return [c.strip() for c in self.capabilities.split(",")]


@dataclass
class TokenStats:
    """Aggregated token usage statistics."""

    total_input: int = 0
    total_output: int = 0
    total_cost_usd: float = 0.0
    today_input: int = 0
    today_output: int = 0
    today_cost_usd: float = 0.0
    top_models: list[dict] = field(default_factory=list)

    @property
    def total_tokens(self) -> int:
        return self.total_input + self.total_output

    @property
    def today_tokens(self) -> int:
        return self.today_input + self.today_output
