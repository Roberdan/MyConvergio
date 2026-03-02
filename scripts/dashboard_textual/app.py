"""Cyberpunk Control Center v4 — neon-grid agentic dashboard."""

from __future__ import annotations

import json
from datetime import datetime
from typing import Any

from textual.app import App, ComposeResult
from textual.binding import Binding
from textual.containers import Grid, Horizontal, Vertical, ScrollableContainer
from textual.reactive import reactive
from textual.widgets import (
    DataTable,
    Footer,
    Header,
    Label,
    ProgressBar,
    Sparkline,
    Static,
)

from .db import DashboardDB

SPARK = "▁▂▃▄▅▆▇█"


class KpiCard(Vertical):
    DEFAULT_CSS = """
    KpiCard {
        width: 1fr; height: 7;
        border: solid #00ffff;
        padding: 0 1;
        background: #0d0d2b;
    }
    KpiCard.alert { border: solid #ff3366; background: #1a0011; }
    KpiCard .kpi-value {
        width: 100%; text-align: center;
        text-style: bold; color: #ffd700;
    }
    KpiCard .kpi-label {
        width: 100%; text-align: center; color: #888899;
    }
    """

    def __init__(self, label: str, value: str = "—", **kw: Any) -> None:
        super().__init__(**kw)
        self._label = label
        self._val = value

    def compose(self) -> ComposeResult:
        yield Label(self._val, classes="kpi-value")
        yield Label(self._label, classes="kpi-label")

    def set_value(self, v: str) -> None:
        try:
            self.query_one(".kpi-value", Label).update(v)
        except Exception:
            pass


class WaveRow(Horizontal):
    DEFAULT_CSS = """
    WaveRow { width: 100%; height: 3; padding: 0 1; }
    WaveRow .wv-lbl { width: 22; content-align: left middle; }
    WaveRow ProgressBar { width: 1fr; }
    WaveRow .wv-pct { width: 8; content-align: right middle; color: #00ffff; }
    """

    def __init__(self, wid: str, name: str, pct: float, status: str, **kw: Any) -> None:
        super().__init__(**kw)
        self._wid = wid
        self._name = name
        self._pct = pct
        self._status = status

    def compose(self) -> ComposeResult:
        icon = {
            "done": "[#00ff88]●[/]",
            "in_progress": "[#ffd700]◉[/]",
            "pending": "[#555577]○[/]",
        }.get(self._status, "[#555577]○[/]")
        yield Label(f"{icon} {self._wid} {self._name[:14]}", classes="wv-lbl")
        pb = ProgressBar(total=100, show_eta=False, show_percentage=False)
        yield pb
        yield Label(f"{self._pct:.0f}%", classes="wv-pct")

    def on_mount(self) -> None:
        self.call_after_refresh(self._set_progress)

    def _set_progress(self) -> None:
        try:
            self.query_one(ProgressBar).advance(self._pct)
        except Exception:
            pass


class ControlCenterApp(App):
    TITLE = "◈ CONVERGIO CONTROL ROOM ◈"

    CSS = """
    Screen { background: #080818; }

    #top-bar { height: 7; margin: 0 1; }

    #main-grid {
        margin: 0 1;
        grid-size: 3 1;
        grid-columns: 5fr 3fr 3fr;
        grid-gutter: 1;
        height: 1fr;
    }

    #col-left, #col-mid, #col-right { height: 100%; }

    .sect-box {
        border: solid #1a1a3a;
        padding: 0 1;
        height: auto;
        background: #0a0a20;
    }
    .sect-title {
        text-style: bold;
        color: #ff00ff;
        padding: 0 0 1 0;
    }

    #mission-box { border: solid #ff00ff; max-height: 22; }
    #mission-summary { color: #ccccdd; }
    #waves-box { height: auto; }

    #task-table {
        height: auto; max-height: 20;
        border: solid #00ffff;
        margin-top: 1;
    }

    #token-box { border: solid #00ffff; height: 14; }
    #token-spark { height: 4; margin: 1 0; }
    #token-stats { color: #aaaacc; }

    #agents-box { border: solid #ffd700; height: auto; max-height: 16; margin-top: 1; }
    #agents-content { color: #ccccdd; }

    #mesh-box { border: solid #ff00ff; height: auto; max-height: 18; }
    #mesh-content { color: #ccccdd; }

    #history-box { border: solid #1a1a3a; height: auto; max-height: 14; margin-top: 1; }

    DataTable { background: #0a0a20; }
    DataTable > .datatable--header { background: #151530; color: #00ffff; text-style: bold; }
    DataTable > .datatable--cursor { background: #1a1a4a; }
    """

    BINDINGS = [
        Binding("r", "refresh", "Refresh", show=True),
        Binding("t", "cycle_theme", "Theme", show=True),
        Binding("q", "quit", "Quit", show=True),
    ]

    _theme_idx: reactive[int] = reactive(0)
    _themes = ["textual-dark", "tokyo-night", "dracula", "catppuccin-mocha", "gruvbox"]

    def __init__(self, db_path: str | None = None) -> None:
        super().__init__()
        self.db = DashboardDB(db_path)

    def compose(self) -> ComposeResult:
        yield Header()
        with Horizontal(id="top-bar"):
            yield KpiCard("PLANS", id="kpi-plans")
            yield KpiCard("ACTIVE", id="kpi-active")
            yield KpiCard("AGENTS", id="kpi-agents")
            yield KpiCard("TOKENS", id="kpi-tokens")
            yield KpiCard("COST $", id="kpi-cost")
            yield KpiCard("BLOCKED", id="kpi-blocked")

        with Grid(id="main-grid"):
            with ScrollableContainer(id="col-left"):
                with Vertical(id="mission-box", classes="sect-box"):
                    yield Label("◈ ACTIVE MISSION", classes="sect-title")
                    yield Label("Scanning...", id="mission-summary")
                    yield Vertical(id="waves-box")
                yield DataTable(id="task-table")

            with ScrollableContainer(id="col-mid"):
                with Vertical(id="token-box", classes="sect-box"):
                    yield Label("◈ TOKEN BURN (14d)", classes="sect-title")
                    yield Sparkline([], id="token-spark")
                    yield Label("", id="token-stats")
                with Vertical(id="agents-box", classes="sect-box"):
                    yield Label("◈ AGENT ACTIVITY", classes="sect-title")
                    yield Static("", id="agents-content")

            with ScrollableContainer(id="col-right"):
                with Vertical(id="mesh-box", classes="sect-box"):
                    yield Label("◈ MESH NETWORK", classes="sect-title")
                    yield Static("", id="mesh-content")
                with Vertical(id="history-box", classes="sect-box"):
                    yield Label("◈ HISTORY", classes="sect-title")
                    yield DataTable(id="history-table")
        yield Footer()

    def on_mount(self) -> None:
        self._setup_tables()
        self.action_refresh()
        self.set_interval(30.0, self.action_refresh)

    def _setup_tables(self) -> None:
        tt = self.query_one("#task-table", DataTable)
        tt.add_columns("ID", "Task", "Status", "Agent", "Host", "Tok")
        tt.cursor_type = "row"
        tt.zebra_stripes = True

        ht = self.query_one("#history-table", DataTable)
        ht.add_columns("Plan", "Name", "Done", "Status")
        ht.cursor_type = "row"
        ht.zebra_stripes = True

    def action_refresh(self) -> None:
        self._refresh_kpi()
        self._refresh_mission()
        self._refresh_tasks()
        self._refresh_tokens()
        self._refresh_agents()
        self._refresh_mesh()
        self._refresh_history()

    def action_cycle_theme(self) -> None:
        self._theme_idx = (self._theme_idx + 1) % len(self._themes)
        try:
            self.theme = self._themes[self._theme_idx]
        except Exception:
            pass
        self.notify(f"Theme: {self._themes[self._theme_idx]}", timeout=2)

    def _refresh_kpi(self) -> None:
        ov = self.db.get_overview()
        ts = self.db.get_token_stats()
        running = self._count_status("in_progress")
        blocked = self._count_status("blocked")
        self._kpi("kpi-plans", str(ov.get("total_plans", 0)))
        self._kpi("kpi-active", str(ov.get("active_plans", 0)))
        self._kpi("kpi-agents", str(running))
        self._kpi("kpi-tokens", _fmt(ts.total_tokens))
        self._kpi("kpi-cost", f"${ts.total_cost_usd:,.0f}")
        self._kpi("kpi-blocked", str(blocked))
        try:
            c = self.query_one("#kpi-blocked", KpiCard)
            c.add_class("alert") if blocked > 0 else c.remove_class("alert")
        except Exception:
            pass

    def _refresh_mission(self) -> None:
        plans = self.db.get_active_plans()
        plan = plans[0] if plans else None
        if not plan:
            self._lbl("mission-summary", "[#555577]No active mission[/]")
            return
        host = f"  [#888899]@{plan.execution_host}[/]" if plan.execution_host else ""
        mode = f"  [#ffd700]{plan.parallel_mode}[/]" if plan.parallel_mode else ""
        self._lbl(
            "mission-summary",
            f"[bold #00ffff]#{plan.id}[/] [bold]{plan.name}[/]"
            f"  [#00ff88]{plan.status.upper()}[/]{host}{mode}"
            f"\n[#888899]{plan.human_summary or ''}[/]"
            f"\n[#00ffff]{plan.tasks_done}[/]/{plan.tasks_total} tasks  "
            f"[#ffd700]{plan.progress_pct}%[/]",
        )
        waves = self.db.get_plan_waves(plan.id)
        try:
            box = self.query_one("#waves-box", Vertical)
            box.remove_children()
            for w in waves:
                box.mount(WaveRow(w.wave_id, w.name or "", w.progress_pct, w.status))
        except Exception:
            pass

    def _refresh_tasks(self) -> None:
        plans = self.db.get_active_plans()
        if not plans:
            return
        tasks = self.db.get_plan_tasks(plans[0].id)
        try:
            tt = self.query_one("#task-table", DataTable)
            tt.clear()
            for t in tasks:
                icon = {
                    "done": "[#00ff88]✓[/]",
                    "in_progress": "[#ffd700]⚡[/]",
                    "submitted": "[#00ffff]◈[/]",
                    "blocked": "[#ff3366]✗[/]",
                    "pending": "[#555577]○[/]",
                }.get(t.status, "?")
                agent = (t.executor_agent or "—")[:8]
                host = (t.executor_host or "—")[:10]
                tok = _fmt(t.tokens) if t.tokens else "—"
                tt.add_row(
                    t.task_id,
                    (t.title or "—")[:28],
                    f"{icon} {t.status}",
                    agent,
                    host,
                    tok,
                )
        except Exception:
            pass

    def _refresh_tokens(self) -> None:
        daily = self._daily_tokens()
        vals = [d["tokens"] for d in daily] if daily else [0]
        try:
            self.query_one("#token-spark", Sparkline).data = vals
        except Exception:
            pass
        ts = self.db.get_token_stats()
        lines = (
            f"[#00ffff]Total[/]: {_fmt(ts.total_tokens)}  "
            f"[#ff00ff]Today[/]: {_fmt(ts.today_tokens)}\n"
            f"[#ffd700]Cost[/]: ${ts.total_cost_usd:,.2f}  "
            f"Today: ${ts.today_cost_usd:,.2f}"
        )
        if ts.top_models:
            for m in ts.top_models[:3]:
                nm = m.get("model", "?").replace("claude-", "")[:14]
                lines += f"\n  [#888899]{nm}[/]: {_fmt(m.get('total_tokens', 0))}  ${m.get('cost_usd', 0):,.2f}"
        self._lbl("token-stats", lines)

    def _refresh_agents(self) -> None:
        rows = self.db._query(
            "SELECT t.task_id, t.title, t.status, t.executor_agent, t.executor_host "
            "FROM tasks t JOIN waves w ON t.wave_id_fk = w.id "
            "JOIN plans p ON w.plan_id = p.id "
            "WHERE p.status = 'doing' AND t.status IN ('in_progress','submitted') "
            "ORDER BY t.started_at DESC LIMIT 8"
        )
        if not rows:
            self._static("agents-content", "[#555577]No active agents[/]")
            return
        lines = []
        for r in rows:
            st = r["status"]
            icon = "[#ffd700]⚡[/]" if st == "in_progress" else "[#00ffff]◈[/]"
            agent = (r["executor_agent"] or "?")[:10]
            host = (r["executor_host"] or "?")[:8]
            title = (r["title"] or "?")[:20]
            lines.append(f"{icon} [bold]{agent}[/]@{host}  {title}")
        self._static("agents-content", "\n".join(lines))

    def _refresh_mesh(self) -> None:
        peers = self.db.get_peers()
        if not peers:
            self._static("mesh-content", "[#555577]No peers[/]")
            return
        online = sum(1 for p in peers if p.is_online)
        lines = [f"[bold #00ffff]{online}[/]/{len(peers)} online\n"]
        for p in peers:
            icon = "[#00ff88]●[/]" if p.is_online else "[#ff3366]○[/]"
            cpu_str = ""
            tasks_n = 0
            if p.load_json and p.load_json != "null":
                try:
                    data = json.loads(p.load_json)
                    if not isinstance(data, dict):
                        raise ValueError
                    cpu = float(data.get("cpu_load", data.get("cpu_load_1", 0)))
                    tasks_n = int(
                        data.get("active_tasks", data.get("tasks_in_progress", 0))
                    )
                    lvl = min(int(cpu * 8 / 100), 7) if cpu > 0 else 0
                    color = (
                        "#00ff88" if cpu < 50 else "#ffd700" if cpu < 80 else "#ff3366"
                    )
                    cpu_str = f" [{color}]{SPARK[lvl] * 6}[/] {cpu:.0f}%"
                except (json.JSONDecodeError, TypeError, KeyError):
                    pass
            caps = ", ".join(p.capability_list[:3]) if p.capability_list else "worker"
            lines.append(
                f"{icon} [bold]{p.peer_name}[/]  "
                f"[#ffd700]{tasks_n}[/] tasks{cpu_str}  "
                f"[#555577]{caps}[/]"
            )
        self._static("mesh-content", "\n".join(lines))

    def _refresh_history(self) -> None:
        plans = self.db.get_completed_plans(6)
        try:
            ht = self.query_one("#history-table", DataTable)
            ht.clear()
            for p in plans:
                icon = "[#00ff88]✓[/]" if p.status == "done" else "[#ff3366]✗[/]"
                ht.add_row(
                    f"#{p.id}",
                    (p.name or "?")[:22],
                    f"{p.tasks_done}/{p.tasks_total}",
                    f"{icon} {p.status}",
                )
        except Exception:
            pass

    def _kpi(self, cid: str, v: str) -> None:
        try:
            self.query_one(f"#{cid}", KpiCard).set_value(v)
        except Exception:
            pass

    def _lbl(self, wid: str, txt: str) -> None:
        try:
            self.query_one(f"#{wid}", Label).update(txt)
        except Exception:
            pass

    def _static(self, wid: str, txt: str) -> None:
        try:
            self.query_one(f"#{wid}", Static).update(txt)
        except Exception:
            pass

    def _count_status(self, status: str) -> int:
        rows = self.db._query(
            "SELECT COUNT(*) AS c FROM tasks t "
            "JOIN waves w ON t.wave_id_fk = w.id "
            "JOIN plans p ON w.plan_id = p.id "
            "WHERE t.status = ? AND p.status = 'doing'",
            (status,),
        )
        return rows[0]["c"] if rows else 0

    def _daily_tokens(self) -> list[dict]:
        rows = self.db._query(
            "SELECT date(created_at) AS day, "
            "SUM(input_tokens + output_tokens) AS tokens "
            "FROM token_usage "
            "WHERE date(created_at) >= date('now', '-13 days') "
            "GROUP BY day ORDER BY day ASC"
        )
        return [{"day": r["day"], "tokens": r["tokens"] or 0} for r in rows]


def _fmt(n: int) -> str:
    if n >= 1_000_000:
        return f"{n / 1_000_000:.1f}M"
    if n >= 1_000:
        return f"{n / 1_000:.1f}K"
    return str(n)
