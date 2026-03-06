function _kpiCard(label, value, sub, target, alert) {
  return `<div class="kpi-card${alert ? " alert" : ""}" onclick="scrollToWidget('${target}')"><div class="kpi-label">${label}</div><div class="kpi-value">${value}</div>${sub ? `<div class="kpi-sub">${sub}</div>` : ""}</div>`;
}
window.scrollToWidget = function (id) {
  const el = document.getElementById(id);
  if (!el) return;
  el.scrollIntoView({ behavior: "smooth", block: "start" });
  el.classList.add("widget-flash");
  setTimeout(() => el.classList.remove("widget-flash"), 1200);
};
function renderKpi(d) {
  const online = d.mesh_online || 0,
    total = d.mesh_total || 0;
  $("#kpi-bar").innerHTML =
    _kpiCard("Active", d.plans_active, "plans running", "mission-panel") +
    _kpiCard(
      "Plans",
      d.plans_total,
      `${d.plans_active} active`,
      "history-widget",
    ) +
    _kpiCard("Mesh", `${online}/${total}`, "nodes online", "mesh-panel") +
    _kpiCard(
      "Tokens",
      fmt(d.total_tokens),
      `Today: ${fmt(d.today_tokens)}`,
      "widget-tokens",
    ) +
    _kpiCard(
      d.blocked > 0 ? "STUCK" : "Blocked",
      d.blocked,
      d.blocked > 0 ? "needs attention" : "",
      "task-pipeline-widget",
      d.blocked > 0,
    );
}

window.renderKpi = renderKpi;
