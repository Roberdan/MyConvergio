"""Mesh topology — cyberpunk node visualization with load sparklines."""

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

SPARK_CHARS = "▁▂▃▄▅▆▇█"


class MigrateDialog(ModalScreen[str | None]):
    """Input dialog for plan migration target."""

    BINDINGS = [Binding("escape", "cancel", "Cancel")]

    DEFAULT_CSS = """
    MigrateDialog { align: center middle; }
    #migrate-box {
        width: 50; height: auto; padding: 1 2;
        border: solid $secondary; background: $panel;
    }
    """

    def __init__(self, peer_name: str) -> None:
        super().__init__()
        self._peer = peer_name

    def compose(self) -> ComposeResult:
        with Vertical(id="migrate-box"):
            yield Label(f"[bold $secondary]Migrate plan to:[/] {self._peer}")
            yield Input(placeholder="Plan ID (e.g. 302)", id="plan-id-input")
            yield Label("[dim]Enter plan ID then press Enter[/]")

    def on_input_submitted(self, event: Input.Submitted) -> None:
        self.dismiss(event.value.strip() or None)

    def action_cancel(self) -> None:
        self.dismiss(None)


class NodeBox(Static):
    """A single peer node — cyberpunk styled with load bars."""

    DEFAULT_CSS = """
    NodeBox {
        width: 28; height: auto; padding: 1; margin: 0 1;
        border: solid $error;
    }
    NodeBox.online { border: solid $success; }
    NodeBox.coordinator { border: double $secondary; }
    NodeBox.pulse { border: solid $accent; }
    """

    pulse_state: reactive[bool] = reactive(False)

    def __init__(self, peer: Peer, index: int) -> None:
        super().__init__(id=f"node-{index}")
        self._peer = peer

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
        self.toggle_class("pulse", self.pulse_state)

    def render(self) -> str:
        p = self._peer
        caps = p.capability_list
        cap_str = " ".join(f"[dim]{c}[/]" for c in caps[:3]) or "[dim]worker[/]"
        status = "[$success]ONLINE[/]" if p.is_online else "[$error]OFFLINE[/]"

        cpu_str = ""
        task_count = 0
        if p.load_json:
            try:
                data = json.loads(p.load_json)
                cpu = float(data.get("cpu_load", data.get("cpu_load_1", 0)))
                task_count = int(
                    data.get("active_tasks", data.get("tasks_in_progress", 0))
                )
                level = min(int(cpu * 8 / 100), 7) if cpu > 0 else 0
                color = "$success" if cpu < 50 else "$warning" if cpu < 80 else "$error"
                spark = SPARK_CHARS[level] * 8
                cpu_str = f"\n[{color}]{spark}[/] {cpu:.0f}%"
            except (json.JSONDecodeError, TypeError, KeyError):
                pass

        return (
            f"[bold]{p.peer_name}[/]\n"
            f"{status}\n"
            f"Tasks: [$accent]{task_count}[/]{cpu_str}\n"
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
    """Cyberpunk connection line between nodes."""

    DEFAULT_CSS = """
    Connector { width: 5; height: auto; content-align: center middle; padding: 1 0; }
    """

    def render(self) -> str:
        return "[$secondary]━━━━━[/]"


class MeshWidget(ScrollableContainer):
    """Mesh topology view with cyberpunk node boxes."""

    BINDINGS = [
        Binding("b", "go_back", "Back", show=True),
        Binding("r", "refresh_mesh", "Refresh", show=True),
        Binding("g", "migrate", "Migrate", show=True),
    ]

    DEFAULT_CSS = """
    MeshWidget { padding: 1 2; }
    #mesh-header { margin-bottom: 1; }
    #node-row { height: auto; align: left top; margin-bottom: 1; }
    #mesh-legend { margin-top: 1; color: $text-muted; }
    """

    def __init__(self, db: DashboardDB | None = None) -> None:
        super().__init__(id="mesh-widget")
        self._db = db or DashboardDB()
        self._peers: list[Peer] = []

    def compose(self) -> ComposeResult:
        self._peers = self._db.get_peers()
        online = sum(1 for p in self._peers if p.is_online)
        yield Static(
            f"[bold $secondary]◈ MESH TOPOLOGY[/]  "
            f"[$success]{online}[/][dim]/{len(self._peers)} online[/]",
            id="mesh-header",
        )
        yield from self._build_node_row()
        yield Static(
            "[dim]Click node for details  |  "
            "[bold]G[/]=migrate  |  "
            "[$success]●[/]=online  [$error]●[/]=offline  [$secondary]●[/]=coord[/]",
            id="mesh-legend",
        )

    def _build_node_row(self):
        if not self._peers:
            yield Static("[dim]No mesh peers found.[/]")
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
            self.query_one("#node-row").remove()
        except Exception:
            pass
        self.mount(*list(self._build_node_row()))
        self.app.notify("Mesh refreshed", timeout=2)

    def action_migrate(self) -> None:
        online = [p for p in self._peers if p.is_online]
        if not online:
            self.app.notify("[$error]No online peers[/]", timeout=3)
            return

        def _on_dismiss(plan_id: str | None) -> None:
            if plan_id:
                self.app.notify(
                    f"Run: mesh-migrate.sh {plan_id} {online[0].peer_name}", timeout=6
                )

        self.app.push_screen(MigrateDialog(online[0].peer_name), _on_dismiss)
