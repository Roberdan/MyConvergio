"""Textual TUI App for Claude Control Center Dashboard."""

from __future__ import annotations

from textual.app import App, ComposeResult
from textual.binding import Binding
from textual.containers import ScrollableContainer, Horizontal
from textual.widgets import Footer, Header, Static, Rule
from textual.reactive import reactive

from .db import DashboardDB


class StatusCard(Static):
    """Single metric card."""

    DEFAULT_CSS = """
    StatusCard {
        width: 1fr;
        height: 5;
        border: solid $accent;
        text-align: center;
        content-align: center middle;
        margin: 0 1;
    }
    """


class ControlCenterApp(App):
    """Claude Control Center — Textual TUI."""

    TITLE = "Claude Control Center"
    SUB_TITLE = "v3.0"

    CSS = """
    Screen {
        background: $surface;
    }
    #cards {
        height: 7;
        margin: 1 2;
    }
    #content {
        margin: 0 2;
    }
    .section-title {
        text-style: bold;
        color: $accent;
        margin: 1 0 0 0;
    }
    .plan-row {
        margin: 0 0;
    }
    .dim {
        color: $text-muted;
    }
    """

    BINDINGS = [
        Binding("r", "refresh", "Refresh", show=True),
        Binding("t", "cycle_theme", "Theme", show=True),
        Binding("q", "quit", "Quit", show=True),
    ]

    _theme_names = ["textual-dark", "textual-light", "dracula", "tokyo-night"]
    _theme_index: reactive[int] = reactive(0)

    def __init__(self, db_path: str | None = None) -> None:
        super().__init__()
        self.db = DashboardDB(db_path)

    def compose(self) -> ComposeResult:
        yield Header()
        with Horizontal(id="cards"):
            yield StatusCard("...", id="card-total")
            yield StatusCard("...", id="card-active")
            yield StatusCard("...", id="card-done")
            yield StatusCard("...", id="card-pipeline")
        with ScrollableContainer(id="content"):
            yield Static("", id="active-plans")
            yield Rule()
            yield Static("", id="completed-plans")
            yield Rule()
            yield Static("", id="token-stats")
            yield Rule()
            yield Static("", id="mesh-peers")
        yield Footer()

    def on_mount(self) -> None:
        self.action_refresh()

    def action_refresh(self) -> None:
        self._update_overview()
        self._update_active_plans()
        self._update_completed_plans()
        self._update_tokens()
        self._update_mesh()
        self.notify("Data refreshed", timeout=2)

    def action_cycle_theme(self) -> None:
        self._theme_index = (self._theme_index + 1) % len(self._theme_names)
        try:
            self.theme = self._theme_names[self._theme_index]
        except Exception:
            pass
        self.notify(f"Theme: {self._theme_names[self._theme_index]}", timeout=2)

    def _update_overview(self) -> None:
        data = self.db.get_overview()
        total = data.get("total_plans", 0)
        active = data.get("active_plans", 0)
        done = data.get("done_plans", 0)
        cancelled = data.get("cancelled_plans", 0)
        pipeline = total - active - done - cancelled

        self.query_one("#card-total", StatusCard).update(f"[bold]{total}[/bold]\nPLANS")
        self.query_one("#card-active", StatusCard).update(
            f"[bold green]{active}[/bold green]\nACTIVE"
        )
        self.query_one("#card-done", StatusCard).update(
            f"[bold cyan]{done}[/bold cyan]\nDONE"
        )
        self.query_one("#card-pipeline", StatusCard).update(
            f"[bold yellow]{pipeline}[/bold yellow]\nPIPELINE"
        )

    def _update_active_plans(self) -> None:
        plans = self.db.get_active_plans()
        if not plans:
            self.query_one("#active-plans", Static).update(
                "[bold cyan]ACTIVE MISSIONS[/bold cyan]\n[dim]No active plans[/dim]"
            )
            return

        lines = ["[bold cyan]ACTIVE MISSIONS[/bold cyan]\n"]
        for p in plans:
            pct = p.progress_pct
            bar = self._bar(pct, 20)
            status_color = "green" if p.status == "doing" else "yellow"
            host = f" [{p.execution_host}]" if p.execution_host else ""
            summary = ""
            if p.human_summary:
                summary = f"\n    [dim]{p.human_summary[:80]}[/dim]"
            lines.append(
                f"  [bold {status_color}]#{p.id}[/bold {status_color}] "
                f"[bold]{p.name[:40]}[/bold]"
                f" [{status_color}]{p.status}[/{status_color}]{host}\n"
                f"    {bar} {pct}%  "
                f"({p.tasks_done}/{p.tasks_total} tasks)"
                f"{summary}\n"
            )
        self.query_one("#active-plans", Static).update("\n".join(lines))

    def _update_completed_plans(self) -> None:
        plans = self.db.get_completed_plans(10)
        if not plans:
            self.query_one("#completed-plans", Static).update(
                "[bold cyan]COMPLETED[/bold cyan]\n[dim]No completed plans[/dim]"
            )
            return

        lines = ["[bold cyan]COMPLETED (recent)[/bold cyan]\n"]
        for p in plans:
            icon = "[green]✓[/green]" if p.status == "done" else "[red]✗[/red]"
            proj = f"[cyan]{p.project_id}[/cyan] " if p.project_id else ""
            lines.append(
                f"  {icon} [bold]#{p.id}[/bold] {proj}{p.name[:45]}"
                f"  [dim]{p.tasks_done}/{p.tasks_total} tasks[/dim]"
            )
        self.query_one("#completed-plans", Static).update("\n".join(lines))

    def _update_tokens(self) -> None:
        stats = self.db.get_token_stats()
        total_fmt = self._fmt_tokens(stats.total_tokens)
        today_fmt = self._fmt_tokens(stats.today_tokens)
        cost_fmt = f"${stats.total_cost_usd:.2f}"

        lines = [
            "[bold cyan]TOKEN USAGE[/bold cyan]\n",
            f"  Total: [bold]{total_fmt}[/bold]  "
            f"Today: [bold green]{today_fmt}[/bold green]  "
            f"Cost: [bold yellow]{cost_fmt}[/bold yellow]\n",
        ]
        if stats.top_models:
            lines.append("  [dim]Top models:[/dim]")
            for m in stats.top_models[:5]:
                model_name = m.get("model", "?")
                tokens = self._fmt_tokens(m.get("total_tokens", 0))
                cost = m.get("cost_usd", 0)
                lines.append(f"    {model_name}: {tokens} (${cost:.2f})")
        self.query_one("#token-stats", Static).update("\n".join(lines))

    def _update_mesh(self) -> None:
        peers = self.db.get_peers()
        if not peers:
            self.query_one("#mesh-peers", Static).update(
                "[bold cyan]MESH PEERS[/bold cyan]\n[dim]No peers configured[/dim]"
            )
            return

        lines = ["[bold cyan]MESH PEERS[/bold cyan]\n"]
        for peer in peers:
            if peer.is_online:
                status = "[green]ONLINE[/green]"
            else:
                status = "[red]OFFLINE[/red]"
            caps = ", ".join(peer.capability_list) if peer.capability_list else "none"
            lines.append(f"  {status} [bold]{peer.peer_name}[/bold]  [dim]{caps}[/dim]")
        self.query_one("#mesh-peers", Static).update("\n".join(lines))

    @staticmethod
    def _bar(pct: int, width: int = 20) -> str:
        filled = pct * width // 100
        empty = width - filled
        if pct >= 80:
            color = "green"
        elif pct >= 40:
            color = "yellow"
        else:
            color = "red"
        return f"[{color}]{'█' * filled}[/{color}][dim]{'░' * empty}[/dim]"

    @staticmethod
    def _fmt_tokens(n: int) -> str:
        if n >= 1_000_000:
            return f"{n / 1_000_000:.1f}M"
        if n >= 1_000:
            return f"{n / 1_000:.1f}K"
        return str(n)
