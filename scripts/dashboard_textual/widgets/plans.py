"""Plans widgets — active, completed, pipeline tables for dashboard TUI."""

from __future__ import annotations

from textual.app import ComposeResult
from textual.widget import Widget
from textual.widgets import DataTable, Static

from ..db import DashboardDB
from ..models import Plan


def _progress_bar(pct: int, width: int = 10) -> str:
    filled = int(pct / 100 * width)
    empty = width - filled
    if pct >= 80:
        color = "green"
    elif pct >= 40:
        color = "yellow"
    else:
        color = "red"
    bar = f"[{color}]{'█' * filled}[/][dim]{'░' * empty}[/]"
    return f"{bar} {pct}%"


class ActivePlansWidget(Widget):
    """DataTable showing active (todo/doing) plans."""

    DEFAULT_CSS = """
    ActivePlansWidget { height: auto; max-height: 20; }
    #active-header { height: 1; margin: 0 1; }
    """

    def compose(self) -> ComposeResult:
        yield Static("[bold]ACTIVE MISSIONS[/]", id="active-header")
        table = DataTable(id="active-table")
        table.cursor_type = "row"
        table.add_columns("ID", "Project", "Name", "Progress", "Host", "Tasks", "Wave")
        yield table

    def refresh_data(self, db: DashboardDB) -> None:
        table = self.query_one("#active-table", DataTable)
        table.clear()
        plans = db.get_active_plans()
        for p in plans:
            pct = p.progress
            host = (p.execution_host or "local")[:12]
            tasks = f"{p.tasks_done}/{p.tasks_total}"
            table.add_row(
                str(p.id),
                (p.project_id or "")[:15],
                p.name[:25],
                _progress_bar(pct),
                host,
                tasks,
                "",
                key=str(p.id),
            )

    def on_data_table_row_selected(self, event: DataTable.RowSelected) -> None:
        if event.row_key and event.row_key.value:
            plan_id = int(event.row_key.value)
            self.app.action_show_detail(plan_id)


class CompletedPlansWidget(Widget):
    """Table of recently completed plans."""

    DEFAULT_CSS = """
    CompletedPlansWidget { height: auto; max-height: 15; }
    #completed-header { height: 1; margin: 0 1; }
    """

    def compose(self) -> ComposeResult:
        yield Static("[bold]COMPLETED (24h)[/]", id="completed-header")
        table = DataTable(id="completed-table")
        table.cursor_type = "row"
        table.add_columns("ID", "Name", "Tasks", "Status", "Completed")
        yield table

    def refresh_data(self, db: DashboardDB) -> None:
        table = self.query_one("#completed-table", DataTable)
        table.clear()
        plans = db.get_completed_plans(limit=10)
        for p in plans:
            icon = "[green]✓[/]" if p.status == "done" else "[red]✗[/]"
            table.add_row(
                str(p.id),
                p.name[:30],
                f"{p.tasks_done}/{p.tasks_total}",
                icon,
                (p.completed_at or "")[:16],
            )


class PipelinePlansWidget(Widget):
    """Table of pipeline (todo) plans."""

    DEFAULT_CSS = """
    PipelinePlansWidget { height: auto; max-height: 10; }
    #pipeline-header { height: 1; margin: 0 1; }
    """

    def compose(self) -> ComposeResult:
        yield Static("[bold]PIPELINE[/]", id="pipeline-header")
        table = DataTable(id="pipeline-table")
        table.cursor_type = "row"
        table.add_columns("ID", "Name", "Project", "Tasks", "Summary")
        yield table

    def refresh_data(self, db: DashboardDB) -> None:
        table = self.query_one("#pipeline-table", DataTable)
        table.clear()
        sql = "SELECT id,name,project_id,tasks_total,human_summary FROM plans WHERE status='todo' ORDER BY id DESC"
        for r in db._query(sql):
            table.add_row(
                str(r["id"]),
                (r["name"] or "")[:25],
                (r["project_id"] or "")[:15],
                str(r["tasks_total"] or 0),
                (r["human_summary"] or "")[:40],
            )
