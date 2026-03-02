"""MeshWidget — mesh topology: node boxes, pulse animation, migrate dialog.

Online=green border, offline=red. Animation via set_interval() + CSS class toggle.
"""

from __future__ import annotations

import json

from textual.app import ComposeResult
from textual.binding import Binding
from textual.containers import Horizontal, ScrollableContainer, Vertical
from textual.reactive import reactive
from textual.screen import ModalScreen
from textual.widgets import Input, Label, Static

from ..db import DashboardDB
from ..models import Peer


class MigrateDialog(ModalScreen[str | None]):
    """Input dialog for plan migration target."""

    BINDINGS = [Binding("escape", "cancel", "Cancel")]

    DEFAULT_CSS = """
    MigrateDialog {
        align: center middle;
    }
    #migrate-box {
        width: 50;
        height: auto;
        padding: 1 2;
        border: solid cyan;
        background: $panel;
    }
    """

    def __init__(self, peer_name: str) -> None:
        super().__init__()
        self._peer = peer_name

    def compose(self) -> ComposeResult:
        with Vertical(id="migrate-box"):
            yield Label(f"[bold cyan]Migrate plan to:[/bold cyan] {self._peer}")
            yield Input(placeholder="Plan ID (e.g. 302)", id="plan-id-input")
            yield Label("[dim]Enter plan ID then press Enter[/dim]")

    def on_input_submitted(self, event: Input.Submitted) -> None:
        self.dismiss(event.value.strip() or None)

    def action_cancel(self) -> None:
        self.dismiss(None)


class NodeBox(Static):
    """A single peer node box — bordered, clickable."""

    DEFAULT_CSS = """
    NodeBox {
        width: 24;
        height: auto;
        padding: 1;
        margin: 0 1;
        border: solid red;
    }
    NodeBox.online {
        border: solid green;
    }
    NodeBox.coordinator {
        border: double cyan;
    }
    NodeBox.pulse {
        border: solid $accent;
        opacity: 0.6;
    }
    """

    pulse_state: reactive[bool] = reactive(False)

    def __init__(self, peer: Peer, index: int) -> None:
        super().__init__(id=f"node-{index}")
        self._peer = peer
        self._index = index

    def on_mount(self) -> None:
        if self._peer.is_online:
            self.add_class("online")
        caps = self._peer.capability_list
        is_coord = "coordinator" in caps or self._peer.peer_name in ("m3max", "local")
        if is_coord and self._peer.is_online:
            self.add_class("coordinator")
            self.set_interval(1.0, self._toggle_pulse)

    def _toggle_pulse(self) -> None:
        self.pulse_state = not self.pulse_state
        if self.pulse_state:
            self.add_class("pulse")
        else:
            self.remove_class("pulse")

    def render(self) -> str:
        p = self._peer
        caps = p.capability_list
        cap_str = " ".join(f"[dim]{c}[/dim]" for c in caps[:3]) or "[dim]—[/dim]"
        online_label = "[green]ONLINE[/green]" if p.is_online else "[red]OFFLINE[/red]"

        cpu_str = ""
        task_count = 0
        if p.load_json:
            try:
                data = json.loads(p.load_json)
                cpu = data.get("cpu_load_1", data.get("load_1", 0))
                task_count = data.get("active_tasks", 0)
                bar_len = min(int(cpu * 10), 10)
                cpu_bar = "█" * bar_len + "░" * (10 - bar_len)
                cpu_str = f"\nCPU [{cpu_bar}] {cpu:.1f}"
            except (json.JSONDecodeError, TypeError, KeyError):
                pass

        return (
            f"[bold]{p.peer_name}[/bold]\n"
            f"{online_label}\n"
            f"Tasks: [cyan]{task_count}[/cyan]{cpu_str}\n"
            f"{cap_str}"
        )

    def on_click(self) -> None:
        self.app.notify(
            f"Node: {self._peer.peer_name} | "
            f"{'Online' if self._peer.is_online else 'Offline'} | "
            f"Caps: {self._peer.capabilities or 'none'}",
            timeout=4,
        )


class Connector(Static):
    """Unicode connection line between nodes."""

    DEFAULT_CSS = """
    Connector { width: 5; height: auto; content-align: center middle; padding: 1 0; color: $text-muted; }
    """

    def render(self) -> str:
        return "─────"


class MeshWidget(ScrollableContainer):
    """Mesh topology view: node boxes in Horizontal layout with connectors."""

    BINDINGS = [
        Binding("b", "go_back", "Back", show=True),
        Binding("r", "refresh_mesh", "Refresh", show=True),
        Binding("g", "migrate", "Migrate", show=True),
    ]

    DEFAULT_CSS = """
    MeshWidget {
        padding: 1 2;
    }
    #mesh-header {
        margin-bottom: 1;
        color: $text;
    }
    #node-row {
        height: auto;
        align: left top;
        margin-bottom: 1;
    }
    #mesh-legend {
        margin-top: 1;
        color: $text-muted;
    }
    """

    def __init__(self, db: DashboardDB | None = None) -> None:
        super().__init__(id="mesh-widget")
        self._db = db or DashboardDB()
        self._peers: list[Peer] = []

    def compose(self) -> ComposeResult:
        self._peers = self._db.get_peers()
        yield Static(
            "[bold cyan]Mesh Topology[/bold cyan]  "
            f"[dim]{len(self._peers)} peer(s) registered[/dim]",
            id="mesh-header",
        )
        yield from self._build_node_row()
        yield Static(
            "[dim]Click node for details  |  [bold]G[/bold]=migrate  |  "
            "[green]■[/green]=online  [red]■[/red]=offline  [cyan]■[/cyan]=coordinator[/dim]",
            id="mesh-legend",
        )

    def _build_node_row(self):
        if not self._peers:
            yield Static("[dim]No mesh peers found. Configure peers.conf.[/dim]")
            return
        with Horizontal(id="node-row"):
            for i, peer in enumerate(self._peers):
                if i > 0:
                    yield Connector()
                yield NodeBox(peer, i)

    def action_go_back(self) -> None:
        self.app.pop_screen()

    def action_refresh_mesh(self) -> None:
        self._peers = self._db.get_peers()
        try:
            row = self.query_one("#node-row")
            row.remove()
        except Exception:
            pass
        try:
            hdr = self.query_one("#mesh-header", Static)
            hdr.update(
                f"[bold cyan]Mesh Topology[/bold cyan]  "
                f"[dim]{len(self._peers)} peer(s) registered[/dim]"
            )
        except Exception:
            pass
        self.mount(*list(self._build_node_row()))
        self.app.notify("Mesh refreshed", timeout=2)

    def action_migrate(self) -> None:
        online = [p for p in self._peers if p.is_online]
        if not online:
            self.app.notify("[red]No online peers for migration.[/red]", timeout=3)
            return
        target = online[0].peer_name

        def _on_dismiss(plan_id: str | None) -> None:
            if plan_id:
                self.app.notify(
                    f"mesh-migrate.sh {plan_id} {target} —  run in terminal",
                    timeout=6,
                )

        self.app.push_screen(MigrateDialog(target), _on_dismiss)
