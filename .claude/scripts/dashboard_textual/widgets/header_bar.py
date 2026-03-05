"""Cyberpunk animated header bar widget."""

from __future__ import annotations

from datetime import datetime

from textual.reactive import reactive
from textual.widgets import Static


class HeaderBar(Static):
    """Animated cyberpunk header with title and clock."""

    DEFAULT_CSS = """
    HeaderBar {
        width: 100%;
        height: 3;
        background: $surface;
        border: solid $secondary;
        content-align: center middle;
        text-style: bold;
    }
    """

    clock: reactive[str] = reactive("")

    def on_mount(self) -> None:
        self._update_clock()
        self.set_interval(1.0, self._update_clock)

    def _update_clock(self) -> None:
        now = datetime.now()
        self.clock = now.strftime("%d.%m.%Y  %H:%M:%S")
        title = "C O N T R O L   C E N T E R"
        self.update(
            f"[bold $secondary]{title}[/]"
            f"    [dim]|[/]    "
            f"[$accent]{self.clock}[/]"
        )
