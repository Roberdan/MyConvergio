function _progressRing(pct, size, color) {
  const r = (size - 8) / 2,
    c = 2 * Math.PI * r,
    o = c - (pct / 100) * c;
  return `<div class="mission-ring" style="width:${size}px;height:${size}px"><svg width="${size}" height="${size}" viewBox="0 0 ${size} ${size}"><circle class="mission-ring-bg" cx="${size / 2}" cy="${size / 2}" r="${r}"/><circle class="mission-ring-fill" cx="${size / 2}" cy="${size / 2}" r="${r}" stroke="${color}" stroke-dasharray="${c}" stroke-dashoffset="${o}"/></svg><div class="mission-ring-pct" style="color:${color}">${pct}%</div></div>`;
}
function _shortModel(m) {
  if (!m) return "";
  return m
    .replace("claude-", "")
    .replace("gpt-", "")
    .replace("-codex", "")
    .replace("-fast", "F")
    .replace("opus-4.6", "opus")
    .replace("sonnet-4.6", "sonnet")
    .replace("haiku-4.5", "haiku");
}
function _renderTaskFlow(t) {
  const model = _shortModel(t.model || t.executor_agent || ""),
    agent = t.executor_agent || "",
    isClaud = /claude|opus|sonnet|haiku/i.test(agent + model),
    isCopilot = /copilot|gpt|codex/i.test(agent + model),
    agentLabel = isCopilot ? "Copilot" : isClaud ? "Claude" : agent || "?",
    agentCls = isCopilot ? "agent-copilot" : "agent-claude";
  const steps = [
    { key: "exec", label: "Execute" },
    { key: "submit", label: "Submit" },
    { key: "thor", label: "Thor" },
    { key: "done", label: "Done" },
  ];
  let active = "exec";
  if (t.status === "submitted") active = "thor";
  if (t.validated_at) active = "done";
  return `<div class="task-flow"><div class="task-flow-id">${esc(t.task_id || "")}</div><div class="task-flow-agent ${agentCls}"><span class="task-flow-agent-icon">${isCopilot ? "&#9883;" : "&#9672;"}</span>${esc(agentLabel)}${model ? ` <span class="task-flow-model">${esc(model)}</span>` : ""}</div><div class="task-flow-pipe">${steps
    .map((s, i) => {
      const ai = s.key === active,
        pi = steps.findIndex((x) => x.key === active) > i,
        cls = ai ? "step-active" : pi ? "step-done" : "step-pending";
      return `<div class="flow-step ${cls}"><div class="flow-dot"></div><div class="flow-label">${s.label}</div></div>${i < steps.length - 1 ? `<div class="flow-conn ${pi ? "conn-done" : ai ? "conn-active" : ""}"></div>` : ""}`;
    })
    .join("")}</div></div>`;
}
function _healthIcon(code) {
  const icons = {
    blocked:
      '<svg width="14" height="14" viewBox="0 0 24 24" fill="#ee3344" style="vertical-align:-2px"><path d="M12 2C6.48 2 2 6.48 2 12s4.48 10 10 10 10-4.48 10-10S17.52 2 12 2zm-2 15l-5-5 1.41-1.41L10 14.17l7.59-7.59L19 8l-9 9z"/></svg>',
    stale:
      '<svg width="14" height="14" viewBox="0 0 24 24" fill="#ee3344" style="vertical-align:-2px"><path d="M11.99 2C6.47 2 2 6.48 2 12s4.47 10 9.99 10C17.52 22 22 17.52 22 12S17.52 2 11.99 2zM12 20c-4.42 0-8-3.58-8-8s3.58-8 8-8 8 3.58 8 8-3.58 8-8 8zm.5-13H11v6l5.25 3.15.75-1.23-4.5-2.67z"/></svg>',
    stuck_deploy:
      '<svg width="14" height="14" viewBox="0 0 24 24" fill="#ffb700" style="vertical-align:-2px"><path d="M1 21h22L12 2 1 21zm12-3h-2v-2h2v2zm0-4h-2v-4h2v4z"/></svg>',
    manual_required:
      '<svg width="14" height="14" viewBox="0 0 24 24" fill="#ffb700" style="vertical-align:-2px"><path d="M12 2C6.48 2 2 6.48 2 12s4.48 10 10 10 10-4.48 10-10S17.52 2 12 2zm1 15h-2v-2h2v2zm0-4h-2V7h2v6z"/></svg>',
    thor_stuck:
      '<svg width="14" height="14" viewBox="0 0 24 24" fill="#ffb700" style="vertical-align:-2px"><path d="M12 1L8 5v3H5l-2 4h4l-3 11h2l7-9H9l3-5h5l3-4h-4l1-4h-5z"/></svg>',
    near_complete_stuck:
      '<svg width="14" height="14" viewBox="0 0 24 24" fill="#ffb700" style="vertical-align:-2px"><path d="M18 8h-1V6c0-2.76-2.24-5-5-5S7 3.24 7 6v2H6c-1.1 0-2 .9-2 2v10c0 1.1.9 2 2 2h12c1.1 0 2-.9 2-2V10c0-1.1-.9-2-2-2zM12 17c-1.1 0-2-.9-2-2s.9-2 2-2 2 .9 2 2-.9 2-2 2zm3.1-9H8.9V6c0-1.71 1.39-3.1 3.1-3.1 1.71 0 3.1 1.39 3.1 3.1v2z"/></svg>',
  };
  return icons[code] || icons.blocked;
}
function _renderHealthAlerts(health, planId, peer) {
  if (!health || !health.length) return "";
  const hasCritical = health.some((h) => h.severity === "critical");
  let html = `<div class="plan-health-bar ${hasCritical ? "health-critical" : "health-warning"}" onclick="event.stopPropagation()">`;
  html += `<div class="plan-health-alerts">`;
  health.forEach((h) => {
    html += `<div class="plan-health-item plan-health-${h.severity}">${_healthIcon(h.code)} <span>${esc(h.message)}</span></div>`;
  });
  html += `</div><div class="plan-health-actions">`;
  html += `<button class="plan-health-btn plan-health-btn-term" onclick="event.stopPropagation();openPlanTerminal(${planId},'${esc(peer || "local")}')" title="Open terminal on plan"><svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><polyline points="4 17 10 11 4 5"></polyline><line x1="12" y1="19" x2="20" y2="19"></line></svg> Debug</button>`;
  html += `<button class="plan-health-btn plan-health-btn-resume" onclick="event.stopPropagation();resumePlanExecution(${planId},'${esc(peer || "local")}')" title="Resume/fix plan execution"><svg width="16" height="16" viewBox="0 0 24 24" fill="currentColor"><polygon points="5,3 19,12 5,21"/></svg> Resume</button>`;
  html += `</div></div>`;
  return html;
}
window.openPlanTerminal = function (planId, peer) {
  if (typeof termMgr !== "undefined") {
    const session = "plan-" + planId;
    termMgr.open(
      peer === "local" || peer === "m3max" ? "local" : peer,
      "Plan #" + planId,
      session,
    );
  }
};
window.resumePlanExecution = function (planId, peer) {
  const planData =
    window.DashboardState &&
    window.DashboardState.lastMeshData &&
    window.DashboardState.lastMeshData
      .flatMap((n) => (n.plans || []).map((p) => ({ ...p, node: n.peer_name })))
      .find((p) => p.id === planId);
  const assignedHost = planData ? planData.node : peer || "local";
  const target =
    assignedHost === "local" || assignedHost === "m3max"
      ? "local"
      : assignedHost;

  if (typeof termMgr === "undefined") return;

  const session = "plan-" + planId;
  const tabId = termMgr.open(target, "Resume #" + planId, session);

  const tab = termMgr.tabs.find((t) => t.id === tabId);
  if (!tab) return;

  const sendResume = () => {
    if (tab.ws && tab.ws.readyState === WebSocket.OPEN) {
      const cmd =
        'cd ~/.claude && claude --model sonnet -p "/execute ' + planId + '"\n';
      tab.ws.send(new TextEncoder().encode(cmd));
    }
  };

  let attempts = 0;
  const waitForOpen = setInterval(() => {
    attempts++;
    if (tab.ws && tab.ws.readyState === WebSocket.OPEN) {
      clearInterval(waitForOpen);
      setTimeout(sendResume, 800);
    } else if (attempts > 50) {
      clearInterval(waitForOpen);
    }
  }, 100);
};
function _renderOnePlan(m) {
  const p = m.plan,
    health = m.health || [],
    pct =
      p.tasks_total > 0 ? Math.round((100 * p.tasks_done) / p.tasks_total) : 0,
    ringColor =
      pct >= 100
        ? "var(--green)"
        : pct >= 50
          ? "var(--cyan)"
          : pct >= 25
            ? "var(--gold)"
            : "var(--red)",
    hostName = p.execution_peer || _resolveHost(p.execution_host),
    isRemote = hostName && hostName !== "local" && hostName !== "m3max",
    blocked = (m.tasks || []).filter((t) => t.status === "blocked").length,
    running = (m.tasks || []).filter((t) => t.status === "in_progress").length,
    hasCritical = health.some((h) => h.severity === "critical"),
    nodeLabel = isRemote
      ? `<span class="host-badge-prominent">${esc(hostName)}</span>`
      : hostName && hostName !== "local"
        ? `<span class="host-badge-local">${esc(hostName)}</span>`
        : "";
  let html = `<div class="mission-plan${hasCritical ? " mission-plan-critical" : health.length ? " mission-plan-warning" : ""}" onclick="filterTasks(${p.id})"><div style="margin-bottom:6px"><span class="mission-id">#${p.id}</span><span class="mission-name">&nbsp;${esc(p.name)}</span>${statusDot(p.status === "doing" ? "in_progress" : p.status)}${health.length ? `<span class="health-badge health-badge-${hasCritical ? "critical" : "warning"}" title="${health.map((h) => h.message).join("; ")}">${hasCritical ? "ALERT" : "WARN"}</span>` : ""}${nodeLabel}${p.parallel_mode ? `<span class="badge badge-doing">${p.parallel_mode}</span>` : ""}${p.project_name ? `<span class="badge badge-project">${esc(p.project_name)}</span>` : ""}<button class="mission-delegate-btn" onclick="event.stopPropagation();showDelegatePlanDialog(${p.id},'${esc(p.name)}')" title="Delegate to mesh node"><svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><path d="M22 2L11 13"/><path d="M22 2L15 22L11 13L2 9L22 2Z"/></svg></button>${p.status === "todo" ? `<button class="mission-start-btn" onclick="event.stopPropagation();showStartPlanDialog(${p.id},'${esc(p.name)}')" title="Start plan execution"><svg width="14" height="14" viewBox="0 0 24 24" fill="currentColor"><polygon points="5,3 19,12 5,21"/></svg></button>` : ""}</div>${_renderHealthAlerts(health, p.id, hostName)}${p.human_summary ? `<div class="mission-summary">${esc(p.human_summary)}</div>` : ""}<div class="mission-progress">${_progressRing(pct, 56, ringColor)}<div class="mission-progress-bars"><div class="mission-progress-label"><span>Done ${p.tasks_done || 0}/${p.tasks_total || 0}</span><span style="color:var(--cyan)">${pct}%</span></div><div class="mission-progress-track"><div class="mission-progress-fill" style="width:${pct}%;background:linear-gradient(90deg,${ringColor},var(--cyan))"></div></div><div style="display:flex;gap:12px;font-size:10px;color:var(--text-dim);margin-top:2px"><span>${running > 0 ? `<span style="color:var(--gold)">${running} running</span>` : ""}</span><span>${blocked > 0 ? `<span style="color:var(--red)">${blocked} blocked</span>` : ""}</span></div></div></div>`;
  if (m.waves && m.waves.length) {
    html += '<div style="margin-top:8px">';
    m.waves.forEach((w) => {
      const wp =
          w.tasks_total > 0
            ? Math.round((100 * w.tasks_done) / w.tasks_total)
            : 0,
        cls =
          w.status === "done"
            ? "done"
            : w.status === "in_progress"
              ? "in_progress"
              : "pending";
      html += `<div class="wave-row"><div class="wave-label">${statusDot(w.status)} ${esc(w.wave_id)}</div><div class="wave-bar"><div class="wave-fill ${cls}" style="width:${wp}%"></div></div><div class="wave-pct">${wp}%</div><div style="margin-left:4px">${thorIcon(w.validated_at)}</div></div>`;
    });
    html += "</div>";
  }
  const live = (m.tasks || []).filter(
    (t) => t.status === "in_progress" || t.status === "submitted",
  );
  if (live.length) {
    html += '<div class="live-flow-section">';
    live.forEach((t) => (html += _renderTaskFlow(t)));
    html += "</div>";
  }
  return html + "</div>";
}
function renderMission(data) {
  const st = window.DashboardState;
  st.lastMissionData = data;
  st.allMissionPlans =
    data && data.plans ? data.plans : data && data.plan ? [data] : [];
  if (!st.allMissionPlans.length) {
    $("#mission-content").innerHTML =
      '<span style="color:#5a6080">No active mission</span>';
    $("#task-table tbody").innerHTML = "";
    return;
  }
  $("#mission-content").innerHTML = st.allMissionPlans
    .map(_renderOnePlan)
    .join("");
  renderTaskPipeline();
}

window.renderMission = renderMission;
