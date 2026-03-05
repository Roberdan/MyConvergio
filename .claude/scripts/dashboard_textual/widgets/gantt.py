"""Gantt timeline — wave execution timeline with projected schedule."""

from __future__ import annotations

from datetime import datetime, timedelta

from textual.widgets import Static

from ..models import Wave


class GanttTimeline(Static):
    """Gantt chart showing wave execution timeline with now-marker."""

    DEFAULT_CSS = """
    GanttTimeline {
        width: 100%;
        min-height: 8;
        border: solid $primary;
        padding: 1 2;
        margin: 0 2;
    }
    """

    def render_gantt(self, waves: list[Wave], plan_started: str | None = None) -> None:
        if not waves:
            self.update("[dim]No wave data[/]")
            return

        lines: list[str] = []
        lines.append("[bold $secondary]◈ TIMELINE[/]  [dim](wave execution)[/]")
        lines.append("")

        now = datetime.now()
        bar_w = 50

        # Calculate time bounds
        start_time = now - timedelta(days=7)
        if plan_started:
            try:
                start_time = datetime.strptime(plan_started[:19], "%Y-%m-%d %H:%M:%S")
            except ValueError:
                pass
        end_time = now + timedelta(days=7)
        total_span = (end_time - start_time).total_seconds() or 1

        # Now position
        now_pos = int((now - start_time).total_seconds() * bar_w / total_span)
        now_pos = max(0, min(bar_w - 1, now_pos))

        for w in waves:
            w_icon = (
                "[green]●[/]"
                if w.status == "done"
                else "[yellow]◉[/]" if w.status == "in_progress" else "[dim]○[/]"
            )

            # Calculate bar segment
            w_start = start_time
            w_end = end_time
            if w.started_at:
                try:
                    w_start = datetime.strptime(w.started_at[:19], "%Y-%m-%d %H:%M:%S")
                except ValueError:
                    pass
            if w.completed_at:
                try:
                    w_end = datetime.strptime(w.completed_at[:19], "%Y-%m-%d %H:%M:%S")
                except ValueError:
                    pass
            elif w.status == "in_progress":
                w_end = now
            elif w.status == "pending":
                w_start = now
                w_end = now + timedelta(days=2)

            s_pos = int((w_start - start_time).total_seconds() * bar_w / total_span)
            e_pos = int((w_end - start_time).total_seconds() * bar_w / total_span)
            s_pos = max(0, min(bar_w, s_pos))
            e_pos = max(s_pos + 1, min(bar_w, e_pos))

            bar = list("·" * bar_w)
            color = (
                "green"
                if w.status == "done"
                else "yellow" if w.status == "in_progress" else "dim"
            )
            char = (
                "█" if w.status == "done" else "▓" if w.status == "in_progress" else "░"
            )
            for i in range(s_pos, e_pos):
                if i < bar_w:
                    bar[i] = char
            bar_str = f"[{color}]{''.join(bar)}[/{color}]"

            lines.append(f"  {w_icon} {w.wave_id:<4} {bar_str} {w.progress_pct:3d}%")

        # Now marker line
        marker_line = " " * (now_pos + 8) + "[$error]▲[/]"
        lines.append(f"  {'':>4} {marker_line}")
        lines.append(f"  {'':>4} {' ' * (now_pos + 5)}[$error]now[/]")

        self.update("\n".join(lines))
