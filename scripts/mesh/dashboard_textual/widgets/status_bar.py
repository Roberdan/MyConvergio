"""Status bar widget for dashboard TUI."""

from __future__ import annotations

from datetime import datetime

from textual.app import ComposeResult
from textual.containers import Horizontal
from textual.widget import Widget
from textual.widgets import Static


SHORTCUTS = "R:Refresh  M:Mesh  T:Theme  C:Completed  A:Analytics  Q:Quit  Tab:Section  0-9:Drill"


class StatusBar(Widget):
    """Bottom status bar with time, theme, and shortcuts."""

    DEFAULT_CSS = """
    StatusBar {
        dock: bottom;
        height: 1;
        background: $surface;
    }
    #sb-time { width: 18; }
    #sb-theme { width: 15; }
    #sb-shortcuts { width: 1fr; }
    #sb-refresh { width: 3; }
    """

    def __init__(self, theme_name: str = "muthur") -> None:
        super().__init__()
        self._theme_name = theme_name
        self._refreshing = False

    def compose(self) -> ComposeResult:
        with Horizontal():
            yield Static("", id="sb-time")
            yield Static(f"[bold]{self._theme_name}[/]", id="sb-theme")
            yield Static(f"[dim]{SHORTCUTS}[/]", id="sb-shortcuts")
            yield Static("", id="sb-refresh")

    def update_time(self) -> None:
        now = datetime.now().strftime("%d %b %Y %H:%M")
        time_w = self.query_one("#sb-time", Static)
        time_w.update(f"[bold]{now}[/]")

    def set_theme_name(self, name: str) -> None:
        self._theme_name = name
        theme_w = self.query_one("#sb-theme", Static)
        theme_w.update(f"[bold]{name}[/]")

    def set_refreshing(self, active: bool) -> None:
        self._refreshing = active
        ref_w = self.query_one("#sb-refresh", Static)
        ref_w.update("[bold yellow]⟳[/]" if active else "")
