"""Active mission panel — wave/task tree with live agent status."""

from __future__ import annotations

from textual.widgets import Static

from ..models import Plan, Wave, Task


class MissionPanel(Static):
    """Displays the active plan with waves, tasks, agent assignments, and progress."""

    DEFAULT_CSS = """
    MissionPanel {
        width: 100%;
        min-height: 10;
        border: solid $secondary;
        padding: 1 2;
        margin: 0 2;
    }
    """

    def render_mission(
        self, plan: Plan | None, waves: list[Wave], tasks: list[Task]
    ) -> None:
        if not plan:
            self.update("[dim]No active mission[/]")
            return

        lines: list[str] = []
        status_color = "green" if plan.status == "doing" else "yellow"
        host = f"  [{plan.execution_host}]" if plan.execution_host else ""
        lines.append(
            f"[bold $secondary]◈[/] [bold]#{plan.id}[/] "
            f"[bold]{plan.name[:50]}[/]"
            f"  [{status_color}]{plan.status.upper()}[/]{host}"
        )
        if plan.human_summary:
            lines.append(f"  [dim]{plan.human_summary[:80]}[/]")
        lines.append("")

        # Overall progress bar
        pct = plan.progress_pct
        bar = self._bar(pct, 30)
        lines.append(f"  {bar} {pct}%  ({plan.tasks_done}/{plan.tasks_total} tasks)")
        lines.append("")

        # Waves with tasks
        wave_tasks: dict[int, list[Task]] = {}
        for t in tasks:
            wfk = t.wave_id_fk or 0
            wave_tasks.setdefault(wfk, []).append(t)

        for w in waves:
            w_icon = self._wave_icon(w.status)
            w_bar = self._bar(w.progress_pct, 16)
            blocked_info = ""
            running = sum(
                1 for t in wave_tasks.get(w.id, []) if t.status == "in_progress"
            )
            blocked = sum(1 for t in wave_tasks.get(w.id, []) if t.status == "blocked")
            if blocked > 0:
                blocked_info = f"  [red]{blocked} blocked[/]"
            elif running > 0:
                blocked_info = f"  [yellow]{running} running[/]"

            lines.append(
                f"  {w_icon} [bold]{w.wave_id}[/] {w.name[:25]:<25}"
                f" {w_bar} {w.progress_pct:3d}%"
                f"  {w.tasks_done}/{w.tasks_total}"
                f"{blocked_info}"
            )

            # Task tree under each wave
            wtasks = wave_tasks.get(w.id, [])
            for i, t in enumerate(wtasks):
                connector = "└─" if i == len(wtasks) - 1 else "├─"
                icon = self._task_icon(t.status)
                model_tag = ""
                if t.executor_agent:
                    m = t.executor_agent
                    if "opus" in m:
                        model_tag = " [$error][opus][/]"
                    elif "sonnet" in m:
                        model_tag = " [$primary][snnt][/]"
                    elif "haiku" in m:
                        model_tag = " [$success][haik][/]"
                    elif "codex" in m or "gpt" in m:
                        model_tag = " [$warning][cdex][/]"
                host_tag = f" @{t.executor_host}" if t.executor_host else ""
                title = t.title[:40] if t.title else t.task_id
                lines.append(
                    f"     {connector} {icon} {t.task_id} {title}"
                    f"{model_tag}[dim]{host_tag}[/]"
                )

        self.update("\n".join(lines))

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
        return f"[{color}]{'▓' * filled}[/{color}][dim]{'░' * empty}[/]"

    @staticmethod
    def _wave_icon(status: str) -> str:
        icons = {
            "done": "[green]●[/]",
            "in_progress": "[yellow]◉[/]",
            "merging": "[$primary]◎[/]",
            "pending": "[dim]○[/]",
            "blocked": "[red]✗[/]",
            "cancelled": "[red]─[/]",
        }
        return icons.get(status, "[dim]○[/]")

    @staticmethod
    def _task_icon(status: str) -> str:
        icons = {
            "done": "[green]✓[/]",
            "in_progress": "[yellow]⚡[/]",
            "submitted": "[$primary]◈[/]",
            "pending": "[dim]○[/]",
            "blocked": "[red]✗[/]",
            "skipped": "[dim]─[/]",
            "cancelled": "[red]✗[/]",
        }
        return icons.get(status, "[dim]?[/]")
