function _taskRow(t) {
  const title = t.title || "\u2014",
    truncated = title.length > 40,
    statusCls =
      t.status === "done"
        ? "task-done"
        : t.status === "in_progress"
          ? "task-running"
          : t.status === "submitted"
            ? "task-submitted"
            : t.status === "blocked"
              ? "task-blocked"
              : "task-pending";
  return `<tr class="${statusCls}" onclick="toggleTaskDetail(this)" data-task-id="${esc(t.task_id || "")}"><td style="color:var(--cyan);font-weight:600">${esc(t.task_id || "")}</td><td style="overflow:hidden;text-overflow:ellipsis;white-space:nowrap" ${truncated ? `title="${esc(title)}"` : ""}>${esc(title.substring(0, 40))}${truncated ? "\u2026" : ""}</td><td>${statusDot(t.status)} ${thorIcon(t.validated_at)}</td><td style="color:var(--text-dim);overflow:hidden;text-overflow:ellipsis;white-space:nowrap">${esc((t.executor_agent || "\u2014").substring(0, 12))}</td><td style="color:var(--gold)">${t.tokens ? fmt(t.tokens) : "\u2014"}</td></tr>`;
}

window.filterTasks = (planId) => {
  window.DashboardState.filteredPlanId = planId;
  renderTaskPipeline();
};
function renderTaskPipeline() {
  const st = window.DashboardState,
    tbody = $("#task-table tbody");
  if (!tbody) return;
  const plans = st.filteredPlanId
      ? st.allMissionPlans.filter(
          (m) => m.plan && m.plan.id === st.filteredPlanId,
        )
      : st.allMissionPlans,
    label = $("#task-filter-label"),
    btn = $("#task-filter-clear");
  if (label)
    label.textContent = st.filteredPlanId
      ? `#${st.filteredPlanId}`
      : `${st.allMissionPlans.length} plans`;
  if (btn) btn.style.display = st.filteredPlanId ? "" : "none";
  let rows = "";
  plans.forEach((m) => {
    const p = m.plan,
      waves = m.waves || [],
      tasks = m.tasks || [];
    if (!st.filteredPlanId && st.allMissionPlans.length > 1)
      rows += `<tr class="task-group-header" onclick="filterTasks(${p.id})"><td colspan="5"><span style="color:var(--cyan);font-weight:600">#${p.id}</span> ${esc((p.name || "").substring(0, 30))}</td></tr>`;
    if (waves.length) {
      waves.forEach((w) => {
        const waveTasks = tasks.filter((t) => t.wave_id === w.wave_id);
        if (!waveTasks.length) return;
        const wp =
          w.tasks_total > 0
            ? Math.round((100 * w.tasks_done) / w.tasks_total)
            : 0;
        rows += `<tr class="task-wave-header"><td colspan="5">${statusDot(w.status)} <span style="color:var(--text)">${esc(w.wave_id)}</span> <span style="color:var(--text-dim)">${esc((w.name || "").substring(0, 20))}</span> <span style="color:var(--cyan);font-size:10px">${wp}%</span> ${thorIcon(w.validated_at)}</td></tr>`;
        waveTasks.forEach((t) => (rows += _taskRow(t)));
      });
      tasks
        .filter((t) => !waves.some((w) => w.wave_id === t.wave_id))
        .forEach((t) => (rows += _taskRow(t)));
    } else tasks.forEach((t) => (rows += _taskRow(t)));
  });
  tbody.innerHTML = rows;
}
window.toggleTaskDetail = function (tr) {
  const n = tr.nextElementSibling;
  if (n && n.classList.contains("task-detail-row")) {
    n.remove();
    tr.classList.remove("expanded");
    return;
  }
  document.querySelectorAll(".task-detail-row").forEach((r) => r.remove());
  document
    .querySelectorAll(".expanded")
    .forEach((r) => r.classList.remove("expanded"));
  let t = null;
  for (const m of window.DashboardState.allMissionPlans) {
    t = (m.tasks || []).find((x) => x.task_id === tr.dataset.taskId);
    if (t) break;
  }
  if (!t) return;
  tr.classList.add("expanded");
  const row = document.createElement("tr");
  row.className = "task-detail-row";
  row.innerHTML = `<td colspan="5"><div class="task-detail"><strong style="color:var(--cyan)">${esc(t.task_id)}</strong> \u2014 ${esc(t.title || "")}<br>Status: <span style="color:${statusColor(t.status)}">${t.status}</span> \u00b7 Agent: ${esc(t.executor_agent || "\u2014")} \u00b7 Host: ${esc(t.executor_host || "\u2014")} \u00b7 Tokens: ${fmt(t.tokens)} ${t.validated_at ? ` \u00b7 ${thorIcon(true)} Validated` : ""}</div></td>`;
  tr.after(row);
};

window.renderTaskPipeline = renderTaskPipeline;
