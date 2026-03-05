"""Overview widget — status cards for dashboard TUI."""

from __future__ import annotations

from textual.app import ComposeResult
from textual.containers import Horizontal
from textual.reactive import reactive
from textual.widget import Widget
from textual.widgets import Static

from ..db import DashboardDB


class StatusCard(Static):
    """Single status card with value and label."""

    DEFAULT_CSS = """
    StatusCard {
        width: 1fr;
        height: 5;
        content-align: center middle;
        border: solid $primary;
        margin: 0 1;
        padding: 0 1;
    }
    """

    def __init__(self, label: str, value: int = 0, color: str = "white") -> None:
        self.label = label
        self.color = color
        super().__init__()
        self.update_content(value)

    def update_content(self, value: int) -> None:
        self.update(f"[bold {self.color}]{value}[/]\n{self.label}")


class OverviewWidget(Widget):
    """Top overview section with 4 status cards and task summary."""

    DEFAULT_CSS = """
    OverviewWidget {
        height: auto;
        max-height: 12;
    }
    #overview-cards {
        height: 5;
    }
    #overview-tasks {
        height: 1;
        content-align: center middle;
        margin: 0 1;
    }
    """

    total = reactive(0)
    active = reactive(0)
    done = reactive(0)
    pipeline = reactive(0)

    def compose(self) -> ComposeResult:
        with Horizontal(id="overview-cards"):
            yield StatusCard("PLANS", color="white")
            yield StatusCard("ACTIVE", color="yellow")
            yield StatusCard("DONE", color="green")
            yield StatusCard("PIPELINE", color="cyan")
        yield Static("", id="overview-tasks")

    def refresh_data(self, db: DashboardDB) -> None:
        overview = db.get_overview()
        self.total = overview.get("total_plans", 0)
        self.active = overview.get("active_plans", 0)
        self.done = overview.get("done_plans", 0)
        self.pipeline = self.total - self.active - self.done

        cards = self.query(StatusCard)
        if len(cards) >= 4:
            cards[0].update_content(self.total)
            cards[1].update_content(self.active)
            cards[2].update_content(self.done)
            cards[3].update_content(self.pipeline)

        # Task summary line
        task_sql = """
            SELECT
                COUNT(*) FILTER (WHERE status = 'done') AS done,
                COUNT(*) FILTER (WHERE status = 'in_progress') AS wip,
                COUNT(*) AS total
            FROM tasks WHERE plan_id IN (
                SELECT id FROM plans WHERE status IN ('todo','doing')
            )
        """
        row = db._query_one(task_sql)
        if row:
            td, tw, tt = row["done"] or 0, row["wip"] or 0, row["total"] or 0
            task_line = (
                f"[green]{td}[/] done  "
                f"[yellow]{tw}[/] in_progress  "
                f"[dim]{tt} total[/]"
            )
        else:
            task_line = "[dim]No active tasks[/]"
        tasks_widget = self.query_one("#overview-tasks", Static)
        tasks_widget.update(task_line)
