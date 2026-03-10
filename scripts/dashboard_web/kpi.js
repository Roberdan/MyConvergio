function _kpiCard(label, value, sub, target, alert) {
  return `<div class="kpi-card${alert ? " alert" : ""}" onclick="scrollToWidget('${target}')"><div class="kpi-label">${label}</div><div class="kpi-value">${value}</div>${sub ? `<div class="kpi-sub">${sub}</div>` : ""}</div>`;
}

function _delta(current, previous, label) {
  if (previous == null) return label;
  const diff = current - previous;
  if (diff === 0) return `<span style="color:var(--text-dim)">= ${label}</span>`;
  const arrow = diff > 0 ? "▲" : "▼";
  const color = diff > 0 ? "var(--green)" : "var(--red)";
  return `<span style="color:${color}">${arrow} ${diff > 0 ? "+" : ""}${fmt(Math.abs(diff))}</span> ${label}`;
}

window.scrollToWidget = function (id) {
  const el = document.getElementById(id);
  if (!el) return;
  el.scrollIntoView({ behavior: "smooth", block: "start" });
  el.classList.add("widget-flash");
  setTimeout(() => el.classList.remove("widget-flash"), 1200);
};

function renderKpi(d) {
  window.__kpiOverviewData = d;
  const online = d.mesh_online || 0, total = d.mesh_total || 0;
  const linesToday = Number(d.today_lines_changed || 0);
  const linesYesterday = d.yesterday_lines_changed != null ? Number(d.yesterday_lines_changed) : null;
  const linesWeek = Number(d.week_lines_changed || 0);
  const linesPrevWeek = d.prev_week_lines_changed != null ? Number(d.prev_week_lines_changed) : null;
  const costToday = Number(d.today_cost || 0);
  const agentsToday = Number(d.agents_today || 0);

  const html =
    _kpiCard("Active", d.plans_active, "plans running", "mission-panel") +
    _kpiCard("Plans", d.plans_total, `${d.plans_done || 0} done`, "history-widget") +
    _kpiCard("Mesh", `${online}/${total}`, "nodes online", "mesh-panel") +
    _kpiCard("Tokens", fmt(d.total_tokens), `Today: ${fmt(d.today_tokens)}`, "widget-tokens") +
    _kpiCard(
      d.blocked > 0 ? "STUCK" : "Blocked",
      d.blocked || "0",
      d.blocked > 0 ? "needs attention" : "",
      "task-pipeline-widget",
      d.blocked > 0,
    ) +
    _kpiCard("Lines Today", fmt(linesToday), _delta(linesToday, linesYesterday, "vs yesterday"), "history-widget") +
    _kpiCard("Lines / Week", fmt(linesWeek), _delta(linesWeek, linesPrevWeek, "vs last week"), "history-widget") +
    _kpiCard("Cost Today", `$${costToday.toFixed(0)}`, "token spend", "widget-cost") +
    _kpiCard("Agents Today", agentsToday, "runs today", "mission-panel");

  $("#kpi-bar").innerHTML = html;
}

window.renderKpi = renderKpi;
