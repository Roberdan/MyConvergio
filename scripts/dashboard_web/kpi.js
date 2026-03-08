function _kpiCard(label, value, sub, target, alert) {
  return `<div class="kpi-card${alert ? " alert" : ""}" onclick="scrollToWidget('${target}')"><div class="kpi-label">${label}</div><div class="kpi-value">${value}</div>${sub ? `<div class="kpi-sub">${sub}</div>` : ""}</div>`;
}
const _githubKpi = {
  planId: 0,
  stats: null,
  lastFetchAt: 0,
  inFlight: null,
};

function _activePlanId() {
  const mission = window.DashboardState?.lastMissionData;
  if (!mission) return 0;
  if (Array.isArray(mission.plans) && mission.plans.length) {
    return Number(mission.plans[0]?.plan?.id || 0) || 0;
  }
  return Number(mission.plan?.id || 0) || 0;
}

function _githubMetrics(stats) {
  const commitTotals = stats?.commit_totals || {};
  const linesAdded = Number(commitTotals.lines_added || 0);
  const linesRemoved = Number(commitTotals.lines_removed || 0);
  return {
    lines_changed: Number(stats?.lines_changed ?? linesAdded + linesRemoved),
    commits_today: Number(stats?.commits_today || 0),
    open_prs: Number(stats?.open_prs || 0),
    pr_merge_velocity: Number(stats?.pr_merge_velocity || 0),
  };
}

function _refreshGithubStats(planId) {
  if (!planId) return;
  const now = Date.now();
  const isFresh = _githubKpi.planId === planId && now - _githubKpi.lastFetchAt < 30000;
  if (isFresh || _githubKpi.inFlight) return;
  _githubKpi.planId = planId;
  _githubKpi.inFlight = fetch(`/api/github/stats/${planId}`)
    .then((r) => r.json())
    .then((payload) => {
      _githubKpi.lastFetchAt = Date.now();
      _githubKpi.stats = payload && payload.ok ? payload : null;
      if (window.__kpiOverviewData) renderKpi(window.__kpiOverviewData, true);
    })
    .catch(() => {
      _githubKpi.lastFetchAt = Date.now();
      _githubKpi.stats = null;
    })
    .finally(() => {
      _githubKpi.inFlight = null;
    });
}

window.scrollToWidget = function (id) {
  const el = document.getElementById(id);
  if (!el) return;
  el.scrollIntoView({ behavior: "smooth", block: "start" });
  el.classList.add("widget-flash");
  setTimeout(() => el.classList.remove("widget-flash"), 1200);
};
function renderKpi(d, skipGithubFetch = false) {
  window.__kpiOverviewData = d;
  const planId = _activePlanId();
  if (!skipGithubFetch) _refreshGithubStats(planId);
  const githubStats = _githubKpi.planId === planId ? _githubKpi.stats : null;
  const github = _githubMetrics(githubStats);
  const mergeVelocityLabel =
    github.pr_merge_velocity > 0 ? `${github.pr_merge_velocity.toFixed(1)}/day` : "n/a";
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
    ) +
    _kpiCard(
      "Lines Changed",
      fmt(github.lines_changed),
      "from plan commits",
      "history-widget",
    ) +
    _kpiCard(
      "Commits Today",
      github.commits_today,
      "GitHub activity",
      "mission-panel",
    ) +
    _kpiCard("Open PRs", github.open_prs, "repo backlog", "event-feed-widget") +
    _kpiCard(
      "PR Merge Velocity",
      mergeVelocityLabel,
      "merged PR/day",
      "event-feed-widget",
    );
}

window.renderKpi = renderKpi;
