"""Textual TUI App for Claude Control Center Dashboard.

Entry: python3 -m dashboard_textual
Keybindings:
    R        — refresh data
    M        — switch to mesh view
    T        — cycle theme
    Q        — quit
    Tab      — next section
    Shift+Tab — previous section
    0-9      — drill into plan by number
"""

from __future__ import annotations

from textual.app import App, ComposeResult
from textual.binding import Binding
from textual.screen import Screen
from textual.widgets import Footer, Header, Label, Static
from textual.reactive import reactive

from .db import DashboardDB


# ---------------------------------------------------------------------------
# Placeholder screens — filled by W2 tasks
# ---------------------------------------------------------------------------


class OverviewScreen(Screen):
    """Main overview: active plans, counters, recent activity."""

    BINDINGS = [
        Binding("r", "refresh", "Refresh"),
        Binding("tab", "focus_next", "Next section"),
        Binding("shift+tab", "focus_previous", "Prev section"),
    ]

    def compose(self) -> ComposeResult:
        yield Header()
        yield Static(
            "[bold cyan]Control Center[/bold cyan] — Overview\n\n"
            "[dim]Loading data…[/dim]",
            id="overview-content",
        )
        yield Footer()

    def action_refresh(self) -> None:
        self.app.refresh_data()


class MeshScreen(Screen):
    """Mesh networking view: peer status, load, capabilities."""

    BINDINGS = [
        Binding("r", "refresh", "Refresh"),
        Binding("escape", "pop_screen", "Back"),
    ]

    def compose(self) -> ComposeResult:
        yield Header()
        yield Static(
            "[bold cyan]Mesh Peers[/bold cyan]\n\n" "[dim]Loading peers…[/dim]",
            id="mesh-content",
        )
        yield Footer()

    def action_refresh(self) -> None:
        self.app.refresh_data()


class PlanDetailScreen(Screen):
    """Drill-down into a specific plan: waves, tasks, token usage."""

    def __init__(self, plan_id: int) -> None:
        super().__init__()
        self.plan_id = plan_id

    BINDINGS = [
        Binding("r", "refresh", "Refresh"),
        Binding("escape", "pop_screen", "Back"),
        Binding("tab", "focus_next", "Next section"),
    ]

    def compose(self) -> ComposeResult:
        yield Header()
        yield Static(
            f"[bold cyan]Plan #{self.plan_id}[/bold cyan]\n\n"
            "[dim]Loading plan details…[/dim]",
            id="plan-detail-content",
        )
        yield Footer()

    def action_refresh(self) -> None:
        self.app.refresh_data()


class TokenScreen(Screen):
    """Token usage statistics and cost breakdown."""

    BINDINGS = [
        Binding("r", "refresh", "Refresh"),
        Binding("escape", "pop_screen", "Back"),
    ]

    def compose(self) -> ComposeResult:
        yield Header()
        yield Static(
            "[bold cyan]Token Usage[/bold cyan]\n\n" "[dim]Loading token stats…[/dim]",
            id="token-content",
        )
        yield Footer()


# ---------------------------------------------------------------------------
# Main App
# ---------------------------------------------------------------------------


class ControlCenterApp(App):
    """Claude Control Center — Textual TUI."""

    TITLE = "Claude Control Center"
    SUB_TITLE = "dashboard-textual v0.1.0"
    CSS_PATH = None  # W2 will add CSS

    BINDINGS = [
        Binding("r", "refresh", "Refresh", show=True),
        Binding("m", "show_mesh", "Mesh", show=True),
        Binding("t", "cycle_theme", "Theme", show=True),
        Binding("q", "quit", "Quit", show=True),
        Binding("tab", "focus_next", "Next", show=False),
        Binding("shift+tab", "focus_previous", "Prev", show=False),
        Binding("0", "drill_plan_0", "Plan 0", show=False),
        Binding("1", "drill_plan_1", "Plan 1", show=False),
        Binding("2", "drill_plan_2", "Plan 2", show=False),
        Binding("3", "drill_plan_3", "Plan 3", show=False),
        Binding("4", "drill_plan_4", "Plan 4", show=False),
        Binding("5", "drill_plan_5", "Plan 5", show=False),
        Binding("6", "drill_plan_6", "Plan 6", show=False),
        Binding("7", "drill_plan_7", "Plan 7", show=False),
        Binding("8", "drill_plan_8", "Plan 8", show=False),
        Binding("9", "drill_plan_9", "Plan 9", show=False),
    ]

    _theme_names = ["textual-dark", "textual-light", "dracula", "tokyo-night"]
    _theme_index: reactive[int] = reactive(0)
    _active_plan_ids: list[int] = []

    def __init__(self, db_path: str | None = None) -> None:
        super().__init__()
        self.db = DashboardDB(db_path)

    def on_mount(self) -> None:
        self.refresh_data()

    def compose(self) -> ComposeResult:
        yield OverviewScreen()

    def refresh_data(self) -> None:
        """Reload data from DB and update reactive state."""
        plans = self.db.get_active_plans()
        self._active_plan_ids = [p.id for p in plans]

    def action_refresh(self) -> None:
        self.refresh_data()
        self.notify("Data refreshed", timeout=2)

    def action_show_mesh(self) -> None:
        self.push_screen(MeshScreen())

    def action_cycle_theme(self) -> None:
        self._theme_index = (self._theme_index + 1) % len(self._theme_names)
        try:
            self.theme = self._theme_names[self._theme_index]
        except Exception:
            pass
        self.notify(f"Theme: {self._theme_names[self._theme_index]}", timeout=2)

    def _drill_plan(self, index: int) -> None:
        if index < len(self._active_plan_ids):
            plan_id = self._active_plan_ids[index]
            self.push_screen(PlanDetailScreen(plan_id))

    def action_drill_plan_0(self) -> None:
        self._drill_plan(0)

    def action_drill_plan_1(self) -> None:
        self._drill_plan(1)

    def action_drill_plan_2(self) -> None:
        self._drill_plan(2)

    def action_drill_plan_3(self) -> None:
        self._drill_plan(3)

    def action_drill_plan_4(self) -> None:
        self._drill_plan(4)

    def action_drill_plan_5(self) -> None:
        self._drill_plan(5)

    def action_drill_plan_6(self) -> None:
        self._drill_plan(6)

    def action_drill_plan_7(self) -> None:
        self._drill_plan(7)

    def action_drill_plan_8(self) -> None:
        self._drill_plan(8)

    def action_drill_plan_9(self) -> None:
        self._drill_plan(9)
