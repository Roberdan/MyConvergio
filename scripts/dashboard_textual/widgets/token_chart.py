"""Token burn chart — 7-day ASCII visualization with model breakdown."""

from __future__ import annotations

from textual.widgets import Static

from ..models import TokenStats


class TokenChart(Static):
    """7-day token usage chart with sparklines and model breakdown."""

    DEFAULT_CSS = """
    TokenChart {
        width: 100%;
        min-height: 12;
        border: solid $primary;
        padding: 1 2;
        margin: 0 2;
    }
    """

    def render_chart(self, stats: TokenStats, daily: list[dict]) -> None:
        lines: list[str] = []
        lines.append("[bold $secondary]◈ TOKEN BURN[/]  [dim](7-day)[/]")
        lines.append("")

        if not daily:
            lines.append("[dim]No token data available[/]")
            self.update("\n".join(lines))
            return

        # Build sparkline from daily values
        values = [d.get("tokens", 0) for d in daily[-7:]]
        max_val = max(values) if values else 1
        if max_val == 0:
            max_val = 1

        # ASCII bar chart (5 rows)
        chart_h = 5
        for row in range(chart_h, 0, -1):
            y_label = ""
            if row == chart_h:
                y_label = self._fmt(max_val)
            elif row == 1:
                y_label = "0"
            line = f"  [dim]{y_label:>5}[/] [dim]│[/]"
            for val in values:
                col_h = val * chart_h // max_val if max_val > 0 else 0
                if col_h >= row:
                    if row >= chart_h * 3 // 4:
                        line += "[$error]▓▓▓▓[/]"
                    elif row >= chart_h // 2:
                        line += "[$warning]▓▓▓▓[/]"
                    else:
                        line += "[$success]▓▓▓▓[/]"
                else:
                    line += "    "
            lines.append(line)

        # X-axis
        x_axis = "  [dim]      └" + "─" * (len(values) * 4) + "[/]"
        lines.append(x_axis)
        day_labels = "  [dim]       "
        for d in daily[-7:]:
            day_labels += f"{d.get('day_label', '???'):<4}"
        day_labels += "[/]"
        lines.append(day_labels)

        # Summary
        lines.append("")
        total_fmt = self._fmt(stats.total_tokens)
        today_fmt = self._fmt(stats.today_tokens)
        cost_fmt = f"${stats.total_cost_usd:.2f}"
        today_cost = f"${stats.today_cost_usd:.2f}"

        # Sparkline
        spark = self._sparkline(values)
        lines.append(
            f"  [$primary]total[/] [bold $accent]{total_fmt}[/]"
            f"  [dim]│[/]  [$primary]today[/] [bold $success]{today_fmt}[/] ({today_cost})"
            f"  [dim]│[/]  [$primary]cost[/] [bold $warning]{cost_fmt}[/]"
            f"  [dim]│[/]  {spark}"
        )

        # Model breakdown
        if stats.top_models:
            lines.append("")
            lines.append("  [dim]models:[/]")
            for m in stats.top_models[:4]:
                model = m.get("model", "?").replace("claude-", "")[:16]
                tok = self._fmt(m.get("total_tokens", 0))
                cost = m.get("cost_usd", 0)
                color = (
                    "$error"
                    if "opus" in model
                    else "$primary" if "sonnet" in model else "$success"
                )
                lines.append(
                    f"    [{color}]{model:<16}[/] {tok:>6}  [dim]${cost:.2f}[/]"
                )

        self.update("\n".join(lines))

    @staticmethod
    def _fmt(n: int) -> str:
        if n >= 1_000_000:
            return f"{n / 1_000_000:.1f}M"
        if n >= 1_000:
            return f"{n / 1_000:.1f}K"
        return str(n)

    @staticmethod
    def _sparkline(values: list[int]) -> str:
        chars = "▁▂▃▄▅▆▇█"
        if not values:
            return ""
        mx = max(values) or 1
        return (
            "[$secondary]" + "".join(chars[min(v * 7 // mx, 7)] for v in values) + "[/]"
        )
