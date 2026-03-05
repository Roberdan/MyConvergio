"""History panel — recently completed/cancelled plans."""

from __future__ import annotations

from textual.widgets import Static

from ..models import Plan


class HistoryPanel(Static):
    """Shows recent completed and cancelled plans with stats."""

    DEFAULT_CSS = """
    HistoryPanel {
        width: 100%;
        min-height: 6;
        border: solid $primary;
        padding: 1 2;
        margin: 0 2;
    }
    """

    def render_history(self, plans: list[Plan]) -> None:
        lines: list[str] = []
        lines.append("[bold $secondary]◈ HISTORY[/]")

        if not plans:
            lines.append("[dim]No completed plans[/]")
            self.update("\n".join(lines))
            return

        lines.append("")
        for p in plans[:8]:
            icon = "[green]✓[/]" if p.status == "done" else "[red]✗[/]"
            name = p.name[:35] if p.name else "?"
            tasks = f"{p.tasks_done}/{p.tasks_total}"
            pct = p.progress_pct
            bar = self._mini_bar(pct, 12)
            proj = f"[$primary]{p.project_id}[/] " if p.project_id else ""
            elapsed = self._elapsed(p.started_at, p.completed_at)

            lines.append(
                f"  {icon} [bold]#{p.id}[/] {proj}{name:<35}"
                f" {bar} {pct:3d}%"
                f"  [dim]{tasks} tasks  {elapsed}[/]"
            )

        self.update("\n".join(lines))

    @staticmethod
    def _mini_bar(pct: int, width: int = 12) -> str:
        filled = pct * width // 100
        empty = width - filled
        if pct >= 80:
            color = "green"
        elif pct >= 40:
            color = "yellow"
        else:
            color = "red"
        return f"[{color}]{'█' * filled}[/{color}][dim]{'░' * empty}[/]"

    @staticmethod
    def _elapsed(start: str | None, end: str | None) -> str:
        if not start:
            return ""
        try:
            from datetime import datetime

            s = datetime.strptime(start[:19], "%Y-%m-%d %H:%M:%S")
            if end:
                e = datetime.strptime(end[:19], "%Y-%m-%d %H:%M:%S")
            else:
                e = datetime.now()
            delta = e - s
            hours = delta.total_seconds() / 3600
            if hours < 1:
                return f"{int(delta.total_seconds() / 60)}m"
            if hours < 24:
                return f"{hours:.1f}h"
            return f"{hours / 24:.1f}d"
        except Exception:
            return ""
