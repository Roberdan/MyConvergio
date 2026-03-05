"""Agent activity panel — live visualization of task distribution and agent workload."""

from __future__ import annotations

from textual.widgets import Static


class AgentActivity(Static):
    """Shows real-time agent workload distribution as a colored segment bar + details."""

    DEFAULT_CSS = """
    AgentActivity {
        width: 100%;
        height: auto;
        min-height: 6;
        border: solid $accent;
        padding: 1 2;
        margin: 0 2;
    }
    """

    def render_activity(self, data: dict) -> None:
        total = data.get("total_tasks", 0)
        done = data.get("done_tasks", 0)
        running = data.get("running_tasks", 0)
        blocked = data.get("blocked_tasks", 0)
        submitted = data.get("submitted_tasks", 0)
        pending = max(0, total - done - running - blocked - submitted)

        lines: list[str] = []
        lines.append("[bold $secondary]◈ AGENT ACTIVITY[/]")

        if total == 0:
            lines.append("[dim]No active tasks[/]")
            self.update("\n".join(lines))
            return

        # Segment bar
        bar_w = 60
        segments = [
            (done, "green", "█"),
            (running, "yellow", "▓"),
            (submitted, "$primary", "▒"),
            (blocked, "red", "░"),
            (pending, "dim", "·"),
        ]
        bar = ""
        for count, color, char in segments:
            seg_w = count * bar_w // total if total > 0 else 0
            if count > 0 and seg_w == 0:
                seg_w = 1
            bar += f"[{color}]{char * seg_w}[/{color}]"
        lines.append(f"  {bar}")

        # Legend
        legend = (
            f"  [green]█[/][dim]done:{done}[/]"
            f"  [yellow]▓[/][dim]run:{running}[/]"
            f"  [$primary]▒[/][dim]submit:{submitted}[/]"
            f"  [red]░[/][dim]block:{blocked}[/]"
            f"  [dim]·pend:{pending}[/]"
            f"  [dim]│[/]  [$accent]{total}[/] [dim]total[/]"
        )
        lines.append(legend)

        # Active agents list
        agents = data.get("active_agents", [])
        if agents:
            lines.append("")
            lines.append("  [dim]active agents:[/]")
            for a in agents[:6]:
                host = a.get("host", "local")
                task_id = a.get("task_id", "?")
                model = a.get("model", "?")
                status = a.get("status", "running")
                elapsed = a.get("elapsed", "")
                m_color = (
                    "$error"
                    if "opus" in model
                    else "$primary" if "sonnet" in model else "$success"
                )
                s_icon = (
                    "[yellow]⚡[/]" if status == "in_progress" else "[$primary]◈[/]"
                )
                lines.append(
                    f"    {s_icon} {task_id:<8} [{m_color}]{model:<10}[/]"
                    f" @{host:<12} [dim]{elapsed}[/]"
                )

        self.update("\n".join(lines))
