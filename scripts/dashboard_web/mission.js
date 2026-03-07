function _progressGradient(pct) {
  // Red→Orange→Gold→Green as completion approaches 100%
  if (pct >= 100) return { color: "#00cc6a", gradient: "linear-gradient(90deg, #00cc6a, #00ff88)" };
  if (pct >= 75) return { color: "#4dd64d", gradient: "linear-gradient(90deg, #e6a117, #4dd64d)" };
  if (pct >= 50) return { color: "#e6a117", gradient: "linear-gradient(90deg, #ff6633, #e6a117)" };
  if (pct >= 25) return { color: "#ff6633", gradient: "linear-gradient(90deg, #ee3344, #ff6633)" };
  return { color: "#ee3344", gradient: "linear-gradient(90deg, #cc1133, #ee3344)" };
}
function _progressRing(pct, size, color) {
  const r = (size - 8) / 2,
    c = 2 * Math.PI * r,
    o = c - (pct / 100) * c;
  return `<div class="mission-ring" style="width:${size}px;height:${size}px"><svg width="${size}" height="${size}" viewBox="0 0 ${size} ${size}"><defs><linearGradient id="ring-grad-${pct}" x1="0" y1="0" x2="1" y2="1"><stop offset="0%" stop-color="${pct < 50 ? '#ee3344' : '#e6a117'}"/><stop offset="100%" stop-color="${color}"/></linearGradient></defs><circle class="mission-ring-bg" cx="${size / 2}" cy="${size / 2}" r="${r}"/><circle class="mission-ring-fill" cx="${size / 2}" cy="${size / 2}" r="${r}" stroke="url(#ring-grad-${pct})" stroke-dasharray="${c}" stroke-dashoffset="${o}"/></svg><div class="mission-ring-pct" style="color:${color}">${pct}%</div></div>`;
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
function _substatusBadge(substatus) {
  const badges = {
    waiting_ci: { icon: Icons.clock(11), label: "CI", color: "#00d4ff" },
    waiting_review: { icon: Icons.eye(11), label: "Review", color: "#e6a117" },
    waiting_merge: { icon: Icons.gitMerge(11), label: "Merge", color: "#a855f7" },
    waiting_thor: { icon: Icons.shield(11), label: "Thor", color: "#ff9500" },
    agent_running: { icon: Icons.cpu(11), label: "Agent", color: "#0066ff" },
  };
  const badge = badges[substatus];
  return badge ? `<span class="substatus-badge" style="color:${badge.color}" title="${esc(substatus)}">${badge.icon} ${badge.label}</span>` : "";
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
function _renderWaveGantt(waves) {
  if (!waves || !waves.length) return "";
  const rowHeight = 28,
    barHeight = 24,
    totalHeight = waves.length * rowHeight,
    byWaveId = Object.fromEntries(waves.map((w, i) => [w.wave_id, { w, i }]));
  const rows = waves
    .map((w) => {
      const total = Number(w.tasks_total || 0),
        done = Number(w.tasks_done || 0),
        pct =
          total > 0
            ? Math.round((100 * done) / total)
            : w.status === "done" || w.status === "merging"
              ? 100
              : 0,
        width = Math.max(4, Math.min(100, pct)),
        statusCls = w.status === "merging" ? "done" : (w.status || "pending"),
        name = w.name ? ` — ${w.name}` : "";
      return `<div class="wave-gantt-row" style="height:${rowHeight}px"><div class="wave-gantt-bar wave-gantt-${esc(statusCls)}" style="height:${barHeight}px;width:${width}%"><span><strong>${esc(w.wave_id)}</strong>${esc(name)}</span></div></div>`;
    })
    .join("");
  const arrows = waves
    .map((w, i) => {
      const rawDeps = Array.isArray(w.depends_on)
          ? w.depends_on
          : typeof w.depends_on === "string"
            ? w.depends_on
                .split(",")
                .map((s) => s.trim())
                .filter(Boolean)
            : w.depends_on
              ? [String(w.depends_on)]
              : [],
        dy = i * rowHeight + barHeight / 2;
      return rawDeps
        .map((depId) => {
          const src = byWaveId[depId];
          if (!src) return "";
          const swTotal = Number(src.w.tasks_total || 0),
            swDone = Number(src.w.tasks_done || 0),
            swPct =
              swTotal > 0
                ? Math.round((100 * swDone) / swTotal)
                : src.w.status === "done" || src.w.status === "merging"
                  ? 100
                  : 0,
            sx = Math.max(4, Math.min(100, swPct)),
            sy = src.i * rowHeight + barHeight / 2,
            dx = 0,
            c1x = Math.min(100, sx + 8),
            c2x = Math.max(0, dx - 8),
            stroke =
              src.w.status === "done" || src.w.status === "merging"
                ? "var(--green)"
                : src.w.status === "pending"
                  ? "var(--text-dim)"
                  : "var(--cyan)";
          return `<path class="wave-gantt-arrow" d="M ${sx} ${sy} C ${c1x} ${sy}, ${c2x} ${dy}, ${dx} ${dy}" style="stroke:${stroke}"></path>`;
        })
        .join("");
    })
    .join("");
  return `<div class="wave-gantt">${rows}<svg class="wave-gantt-svg" viewBox="0 0 100 ${totalHeight}" preserveAspectRatio="none"><defs><marker id="arrow" markerWidth="8" markerHeight="6" refX="7" refY="3" orient="auto"><path d="M0,0 L8,3 L0,6 Z" fill="var(--cyan)"></path></marker></defs>${arrows}</svg></div>`;
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
    preflight_missing:
      '<svg width="14" height="14" viewBox="0 0 24 24" fill="#ffb700" style="vertical-align:-2px"><path d="M19 3H5c-1.1 0-2 .9-2 2v14l4-4h12c1.1 0 2-.9 2-2V5c0-1.1-.9-2-2-2zm-6 9h-2V6h2v6zm0 4h-2v-2h2v2z"/></svg>',
    preflight_stale:
      '<svg width="14" height="14" viewBox="0 0 24 24" fill="#ffb700" style="vertical-align:-2px"><path d="M13 3a9 9 0 1 0 8.95 10h-2.02A7 7 0 1 1 13 5v4l5-5-5-5v4z"/></svg>',
    preflight_context:
      '<svg width="14" height="14" viewBox="0 0 24 24" fill="#ffb700" style="vertical-align:-2px"><path d="M12 3L1 9l11 6 9-4.91V17h2V9L12 3zm0 13L3.74 11.5 12 7l8.26 4.5L12 16z"/></svg>',
    preflight_blocked:
      '<svg width="14" height="14" viewBox="0 0 24 24" fill="#ee3344" style="vertical-align:-2px"><path d="M12 2a10 10 0 1 0 10 10A10 10 0 0 0 12 2zm5 11H7v-2h10z"/></svg>',
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
  const hasThor = health.some((h) => h.code === "thor_stuck");
  if (hasThor) {
    html += `<button class="plan-health-btn plan-health-btn-thor" onclick="event.stopPropagation();runThorValidation(${planId})" title="Run Thor validation on submitted tasks"><svg width="16" height="16" viewBox="0 0 24 24" fill="var(--gold)"><path d="M12 1L8 5v3H5l-2 4h4l-3 11h2l7-9H9l3-5h5l3-4h-4l1-4h-5z"/></svg> Run Thor</button>`;
  }
  html += `<button class="plan-health-btn plan-health-btn-resume" onclick="event.stopPropagation();resumePlanExecution(${planId},'${esc(peer || "local")}')" title="Resume/fix plan execution"><svg width="16" height="16" viewBox="0 0 24 24" fill="currentColor"><polygon points="5,3 19,12 5,21"/></svg> Resume</button>`;
  html += `<button class="plan-health-btn plan-health-btn-term" onclick="event.stopPropagation();openPlanTerminal(${planId},'${esc(peer || "local")}')" title="Open terminal on plan"><svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><polyline points="4 17 10 11 4 5"></polyline><line x1="12" y1="19" x2="20" y2="19"></line></svg> Debug</button>`;
  html += `</div></div>`;
  return html;
}
window.openPlanTerminal = function (planId, peer) {
  if (typeof termMgr !== "undefined") {
    const session = "plan-" + planId;
    termMgr.open(
      peer === "local" ||
        peer ===
          ((window.DashboardState && window.DashboardState.localPeerName) ||
            "local")
        ? "local"
        : peer,
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
    assignedHost === "local" ||
    assignedHost ===
      ((window.DashboardState && window.DashboardState.localPeerName) || "local")
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
    rawPct = p.tasks_total > 0 ? Math.round((100 * p.tasks_done) / p.tasks_total) : 0,
    allValidated = m.waves && m.waves.length && m.waves.every(w => w.validated_at || w.status === "pending"),
    pct = rawPct >= 100 && !allValidated ? 95 : rawPct,
    pg = _progressGradient(pct),
    ringColor = pg.color,
    hostName = p.execution_peer || _resolveHost(p.execution_host),
    isRemote =
      hostName &&
      hostName !== "local" &&
      hostName !==
        ((window.DashboardState && window.DashboardState.localPeerName) ||
          "local"),
    blocked = (m.tasks || []).filter((t) => t.status === "blocked").length,
    running = (m.tasks || []).filter((t) => t.status === "in_progress").length,
    waitingCi = (m.tasks || []).filter((t) => t.substatus === "waiting_ci").length,
    waitingReview = (m.tasks || []).filter((t) => t.substatus === "waiting_review").length,
    waitingMerge = (m.tasks || []).filter((t) => t.substatus === "waiting_merge").length,
    waitingThor = (m.tasks || []).filter((t) => t.substatus === "waiting_thor").length,
    agentRunning = (m.tasks || []).filter((t) => t.substatus === "agent_running").length,
    hasCritical = health.some((h) => h.severity === "critical"),
    nodeLabel = isRemote
      ? `<span class="host-badge-prominent">${esc(hostName)}</span>`
      : hostName && hostName !== "local"
        ? `<span class="host-badge-local">${esc(hostName)}</span>`
        : "";
  let html = `<div class="mission-plan${hasCritical ? " mission-plan-critical" : health.length ? " mission-plan-warning" : ""}" onclick="filterTasks(${p.id})"><div style="margin-bottom:6px"><span class="mission-id">#${p.id}</span><span class="mission-name">&nbsp;${esc(p.name)}</span>${statusDot(p.status === "doing" ? "in_progress" : p.status)}${health.length ? `<span class="health-badge health-badge-${hasCritical ? "critical" : "warning"}" title="${health.map((h) => h.message).join("; ")}">${hasCritical ? "ALERT" : "WARN"}</span>` : ""}${nodeLabel}${p.parallel_mode ? `<span class="badge badge-doing">${p.parallel_mode}</span>` : ""}${p.project_name ? `<span class="badge badge-project">${esc(p.project_name)}</span>` : ""}<button class="mission-delegate-btn" onclick="event.stopPropagation();showDelegatePlanDialog(${p.id},'${esc(p.name)}')" title="Delegate to mesh node"><svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><path d="M22 2L11 13"/><path d="M22 2L15 22L11 13L2 9L22 2Z"/></svg></button>${p.status === "todo" ? `<button class="mission-start-btn" onclick="event.stopPropagation();showStartPlanDialog(${p.id},'${esc(p.name)}')" title="Start plan execution"><svg width="14" height="14" viewBox="0 0 24 24" fill="currentColor"><polygon points="5,3 19,12 5,21"/></svg></button>` : ""}</div>${_renderHealthAlerts(health, p.id, hostName)}${p.human_summary ? `<div class="mission-summary">${esc(p.human_summary)}</div>` : ""}<div class="mission-progress">${_progressRing(pct, 56, ringColor)}<div class="mission-progress-bars"><div class="mission-progress-label"><span>Done ${p.tasks_done || 0}/${p.tasks_total || 0}</span><span style="color:var(--cyan)">${pct}%</span></div><div class="mission-progress-track"><div class="mission-progress-fill" style="width:${pct}%;background:${pg.gradient}"></div></div><div style="display:flex;gap:6px;font-size:9px;color:var(--text-dim);margin-top:4px;flex-wrap:wrap"><span>${running > 0 ? `<span style="color:var(--gold)">${running} running</span>` : ""}</span><span>${blocked > 0 ? `<span style="color:var(--red)">${blocked} blocked</span>` : ""}</span>${waitingCi > 0 ? _substatusBadge("waiting_ci") : ""}${waitingReview > 0 ? _substatusBadge("waiting_review") : ""}${waitingMerge > 0 ? _substatusBadge("waiting_merge") : ""}${waitingThor > 0 ? _substatusBadge("waiting_thor") : ""}${agentRunning > 0 ? _substatusBadge("agent_running") : ""}</div></div></div>`;
  if (m.waves && m.waves.length) {
    html += '<div style="margin-top:8px">';
    const activeWaves = m.waves.filter(
      (w) => w.status !== "pending" || (w.tasks_done && w.tasks_done > 0),
    );
    const pendingWaves = m.waves.filter(
      (w) => w.status === "pending" && (!w.tasks_done || w.tasks_done === 0),
    );
    activeWaves.forEach((w) => {
      const wp =
          w.tasks_total > 0
            ? Math.round((100 * w.tasks_done) / w.tasks_total)
            : 0,
        wValidated = !!w.validated_at,
        wPct = wp >= 100 && !wValidated ? 95 : wp,
        wg = _progressGradient(wPct),
        wName = w.name ? ` — ${(w.name || "").substring(0, 35)}` : "",
        cls =
          w.status === "done" || w.status === "merging"
            ? "done"
            : w.status === "in_progress"
              ? "in_progress"
              : "pending";
      html += `<div class="wave-row"><div class="wave-label">${statusDot(w.status)} <strong>${esc(w.wave_id)}</strong><span class="wave-name">${esc(wName)}</span></div><div class="wave-bar"><div class="wave-fill ${cls}" style="width:${wPct}%;background:${wg.gradient}"></div></div><div class="wave-pct" style="color:${wg.color}">${wPct}%</div><div style="margin-left:4px">${thorIcon(w.validated_at)}</div></div>`;
    });
    if (pendingWaves.length > 0) {
      const cid = `pending-waves-${p.id}`;
      html += `<div class="wave-row wave-pending-summary" onclick="event.stopPropagation();document.getElementById('${cid}').classList.toggle('expanded')"><div class="wave-label">${statusDot("pending")} ${pendingWaves.length} waves pending</div><div class="wave-expand-icon">&#9662;</div></div>`;
      html += `<div id="${cid}" class="wave-pending-collapse">`;
      pendingWaves.forEach((w) => {
        const wName = w.name ? ` — ${(w.name || "").substring(0, 35)}` : "";
        html += `<div class="wave-row wave-row-dim"><div class="wave-label">${statusDot("pending")} <strong>${esc(w.wave_id)}</strong><span class="wave-name">${esc(wName)}</span></div><div class="wave-bar"><div class="wave-fill pending" style="width:0%"></div></div><div class="wave-pct">0%</div></div>`;
      });
      html += "</div>";
    }
    // Check for dependencies
    const hasDeps = m.waves && m.waves.some((w) => w.depends_on);
    if (hasDeps) {
      html += '<div class="wave-gantt-container">';
      html += _renderWaveGantt(m.waves);
      html += "</div>";
    }
    html += "</div>";
  }
  const running_tasks = (m.tasks || []).filter(
    (t) => t.status === "in_progress",
  );
  const submitted_count = (m.tasks || []).filter(
    (t) => t.status === "submitted",
  ).length;
  if (running_tasks.length || submitted_count) {
    html += '<div class="live-flow-section">';
    running_tasks.slice(0, 4).forEach((t) => (html += _renderTaskFlow(t)));
    if (running_tasks.length > 4)
      html += `<div style="font-size:10px;color:var(--text-dim);padding:2px 0">+ ${running_tasks.length - 4} more running</div>`;
    if (submitted_count)
      html += `<div style="font-size:10px;color:var(--gold);padding:2px 0">${submitted_count} task awaiting Thor validation</div>`;
    html += "</div>";
  }
  return html + "</div>";
}
function renderMission(data) {
  const st = window.DashboardState;
  st.lastMissionData = data;
  st.allMissionPlans =
    data && data.plans ? data.plans : data && data.plan ? [data] : [];
  window._dashboardPlans = st.allMissionPlans;
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

window.runThorValidation = async function (planId) {
  try {
    const r = await fetch(`/api/plans/${planId}/validate`, { method: "POST" });
    const d = await r.json();
    if (d.ok) {
      showToast("Thor", `Validated ${d.validated || 0} tasks`, null, "info");
    } else {
      showToast("Thor", d.error || "Validation failed", null, "error");
    }
    if (typeof refreshAll === "function") refreshAll();
  } catch (e) {
    showToast("Thor", "Request failed: " + e.message, null, "error");
  }
};

window.renderMission = renderMission;
