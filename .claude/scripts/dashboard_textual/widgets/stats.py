"""Status cards row — KPI metrics at a glance."""

from __future__ import annotations

from textual.app import ComposeResult
from textual.containers import Horizontal
from textual.widgets import Static


class StatCard(Static):
    """Single KPI metric card with cyberpunk styling."""

    DEFAULT_CSS = """
    StatCard {
        width: 1fr;
        height: 5;
        border: solid $primary;
        text-align: center;
        content-align: center middle;
        margin: 0 1;
    }
    StatCard.alert {
        border: solid $error;
    }
    """

    def __init__(
        self, label: str, value: str = "0", color: str = "$accent", card_id: str = ""
    ) -> None:
        super().__init__(id=card_id if card_id else None)
        self._label = label
        self._value = value
        self._color = color

    def on_mount(self) -> None:
        self.set_value(self._value, self._color)

    def set_value(self, value: str, color: str = "$accent") -> None:
        self._value = value
        self._color = color
        self.update(f"[bold {color}]{value}[/]\n[dim]{self._label}[/]")


class StatsRow(Horizontal):
    """Horizontal row of KPI stat cards."""

    DEFAULT_CSS = """
    StatsRow {
        height: 7;
        margin: 1 2;
    }
    """

    def compose(self) -> ComposeResult:
        yield StatCard("PLANS", card_id="stat-plans")
        yield StatCard("ACTIVE", color="$success", card_id="stat-active")
        yield StatCard("AGENTS", color="$warning", card_id="stat-agents")
        yield StatCard("TOKENS", color="$accent", card_id="stat-tokens")
        yield StatCard("COST", color="$warning", card_id="stat-cost")
        yield StatCard("BLOCKED", color="$error", card_id="stat-blocked")

    def update_stats(self, data: dict) -> None:
        cards = {
            "stat-plans": ("PLANS", str(data.get("total_plans", 0)), "$accent"),
            "stat-active": ("ACTIVE", str(data.get("active_plans", 0)), "$success"),
            "stat-agents": ("AGENTS", str(data.get("running_tasks", 0)), "$warning"),
            "stat-tokens": ("TOKENS", data.get("tokens_fmt", "0"), "$primary"),
            "stat-cost": ("COST", data.get("cost_fmt", "$0"), "$warning"),
            "stat-blocked": ("BLOCKED", str(data.get("blocked_tasks", 0)), "$error"),
        }
        for card_id, (label, value, color) in cards.items():
            try:
                card = self.query_one(f"#{card_id}", StatCard)
                card.set_value(value, color)
                if card_id == "stat-blocked" and int(data.get("blocked_tasks", 0)) > 0:
                    card.add_class("alert")
                else:
                    card.remove_class("alert")
            except Exception:
                pass
