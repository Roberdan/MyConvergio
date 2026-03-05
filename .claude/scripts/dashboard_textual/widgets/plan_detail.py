"""PlanDetailWidget — full plan detail screen with wave/task tree.

Keybinding: B to go back to overview.
"""

from __future__ import annotations

from textual.app import ComposeResult
from textual.binding import Binding
from textual.containers import ScrollableContainer, Vertical
from textual.widgets import Footer, Header, Label, ProgressBar, Static, Tree
from textual.widgets.tree import TreeNode

from ..db import DashboardDB
from ..models import Plan, Wave, Task


_STATUS_ICON: dict[str, str] = {
    "done": "✓",
    "in_progress": "◉",
    "submitted": "◈",
    "pending": "○",
    "blocked": "✗",
    "skipped": "─",
    "cancelled": "✗",
}

_STATUS_COLOR: dict[str, str] = {
    "done": "green",
    "in_progress": "yellow",
    "submitted": "cyan",
    "pending": "white",
    "blocked": "red",
    "skipped": "dim",
    "cancelled": "red",
}

_WAVE_STATUS_COLOR: dict[str, str] = {
    "done": "green",
    "in_progress": "yellow",
    "merging": "cyan",
    "pending": "dim",
    "blocked": "red",
    "cancelled": "red",
}


def _fmt_tokens(n: int) -> str:
    if n >= 1_000_000:
        return f"{n/1_000_000:.1f}M"
    if n >= 1_000:
        return f"{n/1_000:.0f}K"
    return str(n)


def _task_label(task: Task) -> str:
    icon = _STATUS_ICON.get(task.status, "?")
    color = _STATUS_COLOR.get(task.status, "white")
    thor = " [cyan]T[/cyan]" if task.validated_by else ""
    tokens = f" [{_fmt_tokens(task.tokens)}]" if task.tokens else ""
    title = task.title[:60] + "…" if len(task.title) > 60 else task.title
    return f"[{color}]{icon}[/{color}] {task.task_id}: {title}{tokens}{thor}"


def _wave_label(wave: Wave) -> str:
    color = _WAVE_STATUS_COLOR.get(wave.status, "white")
    pct = wave.progress_pct
    bar = "█" * (pct // 10) + "░" * (10 - pct // 10)
    pr = f" PR#{wave.pr_number}" if wave.pr_number else ""
    return f"[{color}]{wave.wave_id}[/{color}] {wave.name or ''}  [{bar}] {pct}%{pr}"


class PlanDetailWidget(ScrollableContainer):
    """Full plan detail: metadata, progress bar, wave/task tree."""

    BINDINGS = [
        Binding("b", "go_back", "Back", show=True),
        Binding("r", "refresh", "Refresh", show=True),
    ]

    DEFAULT_CSS = """
    PlanDetailWidget {
        padding: 1 2;
    }
    #plan-meta {
        margin-bottom: 1;
        color: $text;
    }
    #plan-summary {
        margin-bottom: 1;
        color: $text-muted;
        text-style: italic;
    }
    #plan-progress {
        margin-bottom: 1;
        width: 100%;
    }
    #plan-tree {
        margin-top: 1;
        height: auto;
    }
    """

    def __init__(self, plan_id: int, db: DashboardDB | None = None) -> None:
        super().__init__(id="plan-detail-widget")
        self.plan_id = plan_id
        self._db = db or DashboardDB()

    def compose(self) -> ComposeResult:
        plan = self._db.get_plan_by_id(self.plan_id)
        if plan is None:
            yield Static(f"[red]Plan #{self.plan_id} not found.[/red]")
            return

        yield from self._compose_meta(plan)
        yield ProgressBar(
            total=max(plan.tasks_total, 1),
            id="plan-progress",
            show_percentage=True,
            show_eta=False,
        )
        yield from self._compose_tree(plan)

    def _compose_meta(self, plan: Plan):
        status_color = {"doing": "yellow", "done": "green", "todo": "blue"}.get(
            plan.status, "white"
        )
        host = plan.execution_host or "local"
        mode = plan.parallel_mode or "standard"
        meta_lines = [
            f"[bold cyan]Plan #{plan.id}[/bold cyan]  [{status_color}]{plan.status.upper()}[/{status_color}]",
            f"[bold]{plan.name}[/bold]",
            f"Tasks: [green]{plan.tasks_done}[/green]/[white]{plan.tasks_total}[/white]   "
            f"Host: [cyan]{host}[/cyan]   Mode: [magenta]{mode}[/magenta]",
        ]
        if plan.project_id:
            meta_lines.append(f"Project: [dim]{plan.project_id}[/dim]")
        yield Static("\n".join(meta_lines), id="plan-meta")
        if plan.human_summary:
            yield Static(plan.human_summary, id="plan-summary")

    def _compose_tree(self, plan: Plan):
        tree: Tree[None] = Tree(f"Plan #{plan.id} — Waves & Tasks", id="plan-tree")
        tree.root.expand()
        waves = self._db.get_plan_waves(plan.id)
        for wave in waves:
            wave_node = tree.root.add(_wave_label(wave), expand=True)
            tasks = self._db.get_wave_tasks(wave.id)
            for task in tasks:
                wave_node.add_leaf(_task_label(task))
        if not waves:
            tree.root.add_leaf("[dim]No waves found.[/dim]")
        yield tree

    def on_mount(self) -> None:
        plan = self._db.get_plan_by_id(self.plan_id)
        if plan:
            bar = self.query_one("#plan-progress", ProgressBar)
            bar.advance(plan.tasks_done)

    def action_go_back(self) -> None:
        self.app.pop_screen()

    def action_refresh(self) -> None:
        self.remove_children()
        self.mount(*list(self._compose_children()))

    def _compose_children(self):
        plan = self._db.get_plan_by_id(self.plan_id)
        if plan is None:
            yield Static(f"[red]Plan #{self.plan_id} not found.[/red]")
            return
        yield from self._compose_meta(plan)
        bar = ProgressBar(
            total=max(plan.tasks_total, 1),
            id="plan-progress",
            show_percentage=True,
            show_eta=False,
        )
        yield bar
        yield from self._compose_tree(plan)
