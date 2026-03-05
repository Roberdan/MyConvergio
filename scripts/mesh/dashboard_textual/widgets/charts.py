"""Charts + analytics widgets for dashboard TUI."""

from __future__ import annotations

from textual.app import ComposeResult
from textual.containers import Horizontal, Vertical
from textual.widget import Widget
from textual.widgets import Static, Sparkline, ProgressBar

from ..db import DashboardDB

MODEL_RATES = {
    "claude-opus-4.6": 15.0,
    "claude-opus-4.5": 15.0,
    "claude-sonnet-4.6": 3.0,
    "claude-sonnet-4.5": 3.0,
    "claude-haiku-4.5": 0.25,
    "gpt-5.3-codex": 0.0,
    "gpt-5.1-codex-mini": 0.0,
}


class TokenSparkline(Widget):
    """Sparkline showing tokens per day (last 14 days)."""

    DEFAULT_CSS = """
    TokenSparkline { height: 5; margin: 0 1; }
    #spark-label { height: 1; }
    """

    def compose(self) -> ComposeResult:
        yield Static("[bold]TOKEN USAGE (14 days)[/]", id="spark-label")
        yield Sparkline([], id="token-spark")

    def refresh_data(self, db: DashboardDB) -> None:
        stats = db.get_token_stats()
        daily = stats.get("daily_tokens", [])
        if daily:
            spark = self.query_one("#token-spark", Sparkline)
            spark.data = [float(d) for d in daily[-14:]]


class CostGauge(Widget):
    """Total cost display with colored bar."""

    DEFAULT_CSS = """
    CostGauge { height: 4; margin: 0 1; }
    #cost-label { height: 1; }
    #cost-bar { height: 1; }
    """

    def compose(self) -> ComposeResult:
        yield Static("[bold]TOTAL COST[/]", id="cost-label")
        yield ProgressBar(total=100, show_eta=False, id="cost-bar")
        yield Static("", id="cost-value")

    def refresh_data(self, db: DashboardDB) -> None:
        stats = db.get_token_stats()
        by_model = stats.get("by_model", {})
        total_cost = 0.0
        for model, tokens in by_model.items():
            rate = MODEL_RATES.get(model, 3.0)
            total_cost += (tokens / 1_000_000) * rate
        value_widget = self.query_one("#cost-value", Static)
        value_widget.update(f"[bold]${total_cost:.2f}[/]")


class ModelBreakdown(Widget):
    """Horizontal bar chart — token distribution by model."""

    DEFAULT_CSS = """
    ModelBreakdown { height: auto; min-height: 4; margin: 0 1; }
    #model-header { height: 1; }
    """

    def compose(self) -> ComposeResult:
        yield Static("[bold]MODEL BREAKDOWN[/]", id="model-header")
        yield Static("", id="model-bars")

    def refresh_data(self, db: DashboardDB) -> None:
        stats = db.get_token_stats()
        by_model = stats.get("by_model", {})
        total = sum(by_model.values()) or 1
        lines = []
        colors = {
            "opus": "magenta",
            "sonnet": "cyan",
            "haiku": "green",
            "codex": "yellow",
        }
        for model, tokens in sorted(by_model.items(), key=lambda x: -x[1]):
            pct = int(tokens / total * 100)
            short = model.split("-")[-1] if "-" in model else model
            color = colors.get(short[:5].lower(), "white")
            bar_w = max(1, pct // 5)
            lines.append(f"  [{color}]{'█' * bar_w}[/] {short[:12]:12} {pct}%")
        bars = self.query_one("#model-bars", Static)
        bars.update("\n".join(lines) if lines else "[dim]No data[/]")


class TaskCompletionChart(Widget):
    """Tasks done per day (last 7 days)."""

    DEFAULT_CSS = """
    TaskCompletionChart { height: 5; margin: 0 1; }
    #task-chart-label { height: 1; }
    """

    def compose(self) -> ComposeResult:
        yield Static("[bold]TASKS COMPLETED (7 days)[/]", id="task-chart-label")
        yield Sparkline([], id="task-spark")

    def refresh_data(self, db: DashboardDB) -> None:
        sql = """
            SELECT DATE(completed_at) AS day, COUNT(*) AS cnt
            FROM tasks
            WHERE status = 'done' AND completed_at >= DATE('now', '-7 days')
            GROUP BY day ORDER BY day
        """
        rows = db._query(sql)
        data = [float(r["cnt"]) for r in rows] if rows else [0.0]
        spark = self.query_one("#task-spark", Sparkline)
        spark.data = data
