/**
 * Convergio Control Room — main application logic.
 * Data fetching, rendering, charts, task details, activity feed.
 */

const $ = (s) => document.querySelector(s);
let tokenChart, modelChart, distChart;
let lastMissionData = null;
let _hostToPeer = {}; // hostname → peer_name mapping

// Build hostname→peer_name map from /api/mesh
async function _refreshHostMap() {
  try {
    const peers = await fetchJson("/api/mesh");
    if (Array.isArray(peers)) {
      _hostToPeer = {};
      const localHost = location.hostname;
      peers.forEach((p) => {
        // Map dns_name, tailscale_ip, and peer_name itself
        _hostToPeer[p.peer_name] = p.peer_name;
        if (p.dns_name) _hostToPeer[p.dns_name] = p.peer_name;
        if (p.is_local) _hostToPeer["local"] = p.peer_name;
      });
    }
  } catch (_) {}
}

function _resolveHost(host) {
  if (!host) return "local";
  // Direct match
  if (_hostToPeer[host]) return _hostToPeer[host];
  // Partial match (hostname contains peer_name or vice versa)
  const h = host.toLowerCase();
  for (const [key, name] of Object.entries(_hostToPeer)) {
    if (h.includes(key.toLowerCase()) || key.toLowerCase().includes(h)) return name;
  }
  // Shorten long hostnames
  return host.length > 20 ? host.substring(0, 16) + "…" : host;
}

function fmt(n) {
  if (!n && n !== 0) return "—";
  if (n >= 1e6) return (n / 1e6).toFixed(1) + "M";
  if (n >= 1e3) return (n / 1e3).toFixed(1) + "K";
  return String(n);
}

function esc(s) {
  const d = document.createElement("div");
  d.textContent = s;
  return d.innerHTML;
}

function statusColor(s) {
  const m = {
    done: "#00cc55",
    in_progress: "#ffb700",
    submitted: "#00b8d4",
    blocked: "#ee3344",
    pending: "#5a6080",
    cancelled: "#ee3344",
    skipped: "#5a6080",
    doing: "#00b8d4",
    todo: "#5a6080",
  };
  return m[s] || "#5a6080";
}

function statusDot(s) {
  const cls =
    {
      done: "dot-done",
      in_progress: "dot-active",
      submitted: "dot-submitted",
      blocked: "dot-blocked",
      pending: "dot-pending",
      cancelled: "dot-cancelled",
      skipped: "dot-skipped",
    }[s] || "dot-pending";
  return `<span class="status-dot ${cls}"></span>`;
}
function thorIcon(validated) {
  const color = validated ? "#00cc55" : "#ee3344";
  return `<svg xmlns="http://www.w3.org/2000/svg" width="14" height="14" viewBox="0 0 24 24" fill="${color}" style="vertical-align:-2px" title="${validated ? "Thor validated" : "Not validated"}"><path d="M12 1L8 5v3H5l-2 4h4l-3 11h2l7-9H9l3-5h5l3-4h-4l1-4h-5z"/></svg>`;
}

async function fetchJson(url) {
  try {
    return await (await fetch(url)).json();
  } catch {
    return null;
  }
}

async function refreshAll() {
  const [ov, mission, daily, models, mesh, history, dist] = await Promise.all([
    fetchJson("/api/overview"),
    fetchJson("/api/mission"),
    fetchJson("/api/tokens/daily"),
    fetchJson("/api/tokens/models"),
    fetchJson("/api/mesh"),
    fetchJson("/api/history"),
    fetchJson("/api/tasks/distribution"),
  ]);
  if (ov) {
    ov.mesh_online = mesh ? mesh.filter((p) => p.is_online).length : 0;
    ov.mesh_total = mesh ? mesh.length : 0;
    renderKpi(ov);
  }
  // Update hostname→peer_name map for plan cards
  if (Array.isArray(mesh)) {
    _hostToPeer = {};
    mesh.forEach((p) => {
      _hostToPeer[p.peer_name] = p.peer_name;
      if (p.is_local) _hostToPeer["local"] = p.peer_name;
    });
  }
  renderMission(mission);
  if (daily) renderTokenChart(daily);
  if (models) renderModelChart(models);
  if (mesh) {
    renderMeshStrip(mesh);
    renderEventFeed();
    fetch("/api/mesh/sync-status")
      .then((r) => r.json())
      .then(applyMeshSyncBadges)
      .catch(() => null);
  }
  if (history) renderHistory(history);
  if (dist) renderDist(dist);
  renderActivity(mission, mesh);
  $("#last-update").textContent = "Updated: " + new Date().toLocaleTimeString();

  // Auto-pull DB from remote nodes with active plans (every refresh, transparent)
  _pullRemoteDb();
}

let _pullInProgress = false;
async function _pullRemoteDb() {
  if (_pullInProgress) return;
  _pullInProgress = true;
  try {
    const r = await fetchJson("/api/mesh/pull-db");
    if (r && r.count > 0) {
      const ok = r.synced.filter((s) => s.ok).length;
      if (ok > 0) {
        const badge = document.getElementById("sync-badge");
        if (badge) {
          badge.textContent = `↓ ${ok} synced`;
          badge.style.display = "inline";
          setTimeout(() => { badge.style.display = "none"; }, 3000);
        }
      }
    }
  } catch (_) {}
  _pullInProgress = false;
}

// --- KPI ---
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
  const online = d.mesh_online || 0;
  const total = d.mesh_total || 0;
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
    _kpiCard("Blocked", d.blocked, "", "task-pipeline-widget", d.blocked > 0);
}

// --- MISSION ---
function _progressRing(pct, size, color) {
  const r = (size - 8) / 2;
  const circ = 2 * Math.PI * r;
  const offset = circ - (pct / 100) * circ;
  return `<div class="mission-ring" style="width:${size}px;height:${size}px">
    <svg width="${size}" height="${size}" viewBox="0 0 ${size} ${size}">
      <circle class="mission-ring-bg" cx="${size / 2}" cy="${size / 2}" r="${r}"/>
      <circle class="mission-ring-fill" cx="${size / 2}" cy="${size / 2}" r="${r}" stroke="${color}" stroke-dasharray="${circ}" stroke-dashoffset="${offset}"/>
    </svg>
    <div class="mission-ring-pct" style="color:${color}">${pct}%</div>
  </div>`;
}
function _renderOnePlan(m) {
  const p = m.plan;
  const pct =
    p.tasks_total > 0 ? Math.round((100 * p.tasks_done) / p.tasks_total) : 0;
  const ringColor =
    pct >= 100
      ? "var(--green)"
      : pct >= 50
        ? "var(--cyan)"
        : pct >= 25
          ? "var(--gold)"
          : "var(--red)";
  const doneTasks = p.tasks_done || 0;
  const totalTasks = p.tasks_total || 0;
  const hostName = p.execution_peer || _resolveHost(p.execution_host);
  const isRemote = hostName && hostName !== "local" && hostName !== "m3max";
  const blockedCount = (m.tasks || []).filter(
    (t) => t.status === "blocked",
  ).length;
  const inProgCount = (m.tasks || []).filter(
    (t) => t.status === "in_progress",
  ).length;
  const nodeLabel = isRemote
    ? `<span class="host-badge-prominent">${esc(hostName)}</span>`
    : hostName && hostName !== "local"
      ? `<span class="host-badge-local">${esc(hostName)}</span>`
      : "";
  let html = `<div class="mission-plan" onclick="filterTasks(${p.id})">
    <div style="margin-bottom:6px">
      <span class="mission-id">#${p.id}</span>
      <span class="mission-name">&nbsp;${esc(p.name)}</span>
      ${statusDot(p.status === "doing" ? "in_progress" : p.status)}
      ${nodeLabel}
      ${p.parallel_mode ? `<span class="badge badge-doing">${p.parallel_mode}</span>` : ""}
      ${p.project_name ? `<span class="badge badge-project">${esc(p.project_name)}</span>` : ""}
      <button class="mission-delegate-btn" onclick="event.stopPropagation();showDelegatePlanDialog(${p.id},'${esc(p.name)}')" title="Delegate to mesh node">
        <svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><path d="M22 2L11 13"/><path d="M22 2L15 22L11 13L2 9L22 2Z"/></svg>
      </button>
      ${p.status === "todo" ? `<button class="mission-start-btn" onclick="event.stopPropagation();showStartPlanDialog(${p.id},'${esc(p.name)}')" title="Start plan execution">
        <svg width="14" height="14" viewBox="0 0 24 24" fill="currentColor"><polygon points="5,3 19,12 5,21"/></svg>
      </button>` : ""}
    </div>`;
  if (p.human_summary) {
    html += `<div class="mission-summary">${esc(p.human_summary)}</div>`;
  }
  html += `<div class="mission-progress">
    ${_progressRing(pct, 56, ringColor)}
    <div class="mission-progress-bars">
      <div class="mission-progress-label"><span>Done ${doneTasks}/${totalTasks}</span><span style="color:var(--cyan)">${pct}%</span></div>
      <div class="mission-progress-track"><div class="mission-progress-fill" style="width:${pct}%;background:linear-gradient(90deg,${ringColor},var(--cyan))"></div></div>
      <div style="display:flex;gap:12px;font-size:10px;color:var(--text-dim);margin-top:2px">
        <span>${inProgCount > 0 ? `<span style="color:var(--gold)">${inProgCount} running</span>` : ""}</span>
        <span>${blockedCount > 0 ? `<span style="color:var(--red)">${blockedCount} blocked</span>` : ""}</span>
      </div>
    </div>
  </div>`;
  if (m.waves && m.waves.length) {
    html += '<div style="margin-top:8px">';
    m.waves.forEach((w) => {
      const wp =
        w.tasks_total > 0
          ? Math.round((100 * w.tasks_done) / w.tasks_total)
          : 0;
      const cls =
        w.status === "done"
          ? "done"
          : w.status === "in_progress"
            ? "in_progress"
            : "pending";
      html += `<div class="wave-row">
        <div class="wave-label">${statusDot(w.status)} ${esc(w.wave_id)}</div>
        <div class="wave-bar"><div class="wave-fill ${cls}" style="width:${wp}%"></div></div>
        <div class="wave-pct">${wp}%</div>
        <div style="margin-left:4px">${thorIcon(w.validated_at)}</div>
      </div>`;
    });
    html += "</div>";
  }
  const liveTasks = (m.tasks || []).filter(
    (t) => t.status === "in_progress" || t.status === "submitted",
  );
  if (liveTasks.length) {
    html += '<div class="live-flow-section">';
    liveTasks.forEach((t) => {
      html += _renderTaskFlow(t);
    });
    html += "</div>";
  }
  html += "</div>";
  return { html, tasks: m.tasks || [] };
}

function _renderTaskFlow(t) {
  const model = _shortModel(t.model || t.executor_agent || "");
  const agent = t.executor_agent || "";
  const isClaud = /claude|opus|sonnet|haiku/i.test(agent + model);
  const isCopilot = /copilot|gpt|codex/i.test(agent + model);
  const agentLabel = isCopilot ? "Copilot" : isClaud ? "Claude" : agent || "?";
  const agentCls = isCopilot ? "agent-copilot" : "agent-claude";
  const steps = [
    { key: "exec", label: "Execute" },
    { key: "submit", label: "Submit" },
    { key: "thor", label: "Thor" },
    { key: "done", label: "Done" },
  ];
  let activeStep = "exec";
  if (t.status === "submitted") activeStep = "thor";
  if (t.validated_at) activeStep = "done";
  return `<div class="task-flow">
    <div class="task-flow-id">${esc(t.task_id || "")}</div>
    <div class="task-flow-agent ${agentCls}">
      <span class="task-flow-agent-icon">${isCopilot ? "&#9883;" : "&#9672;"}</span>
      ${esc(agentLabel)}${model ? ` <span class="task-flow-model">${esc(model)}</span>` : ""}
    </div>
    <div class="task-flow-pipe">
      ${steps
        .map((s, i) => {
          const isActive = s.key === activeStep;
          const isPast = steps.findIndex((x) => x.key === activeStep) > i;
          const cls = isActive
            ? "step-active"
            : isPast
              ? "step-done"
              : "step-pending";
          return `<div class="flow-step ${cls}">
          <div class="flow-dot"></div>
          <div class="flow-label">${s.label}</div>
        </div>${i < steps.length - 1 ? '<div class="flow-conn ' + (isPast ? "conn-done" : isActive ? "conn-active" : "") + '"></div>' : ""}`;
        })
        .join("")}
    </div>
  </div>`;
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

let filteredPlanId = null;
let allMissionPlans = [];

window.filterTasks = function (planId) {
  filteredPlanId = planId;
  renderTaskPipeline();
};

function renderMission(data) {
  lastMissionData = data;
  allMissionPlans =
    data && data.plans ? data.plans : data && data.plan ? [data] : [];
  if (!allMissionPlans.length) {
    $("#mission-content").innerHTML =
      '<span style="color:#5a6080">No active mission</span>';
    $("#task-table tbody").innerHTML = "";
    return;
  }
  let html = "";
  allMissionPlans.forEach((m) => {
    const r = _renderOnePlan(m);
    html += r.html;
  });
  $("#mission-content").innerHTML = html;
  renderTaskPipeline();
}

function renderTaskPipeline() {
  const tbody = $("#task-table tbody");
  if (!tbody) return;
  const filterLabel = $("#task-filter-label");
  const filterBtn = $("#task-filter-clear");
  const plans = filteredPlanId
    ? allMissionPlans.filter((m) => m.plan && m.plan.id === filteredPlanId)
    : allMissionPlans;
  if (filterLabel) {
    filterLabel.textContent = filteredPlanId
      ? `#${filteredPlanId}`
      : `${allMissionPlans.length} plans`;
  }
  if (filterBtn) filterBtn.style.display = filteredPlanId ? "" : "none";
  let rows = "";
  plans.forEach((m) => {
    const p = m.plan;
    if (!filteredPlanId && allMissionPlans.length > 1) {
      rows += `<tr class="task-group-header" onclick="filterTasks(${p.id})"><td colspan="5"><span style="color:var(--cyan);font-weight:600">#${p.id}</span> ${esc((p.name || "").substring(0, 30))}</td></tr>`;
    }
    const waves = m.waves || [];
    const tasks = m.tasks || [];
    if (waves.length > 0) {
      waves.forEach((w) => {
        const waveTasks = tasks.filter((t) => t.wave_id === w.wave_id);
        if (waveTasks.length === 0) return;
        const wp =
          w.tasks_total > 0
            ? Math.round((100 * w.tasks_done) / w.tasks_total)
            : 0;
        rows += `<tr class="task-wave-header"><td colspan="5">${statusDot(w.status)} <span style="color:var(--text)">${esc(w.wave_id)}</span> <span style="color:var(--text-dim)">${esc((w.name || "").substring(0, 20))}</span> <span style="color:var(--cyan);font-size:10px">${wp}%</span> ${thorIcon(w.validated_at)}</td></tr>`;
        waveTasks.forEach((t) => {
          rows += _taskRow(t);
        });
      });
      const orphanTasks = tasks.filter(
        (t) => !waves.some((w) => w.wave_id === t.wave_id),
      );
      orphanTasks.forEach((t) => {
        rows += _taskRow(t);
      });
    } else {
      tasks.forEach((t) => {
        rows += _taskRow(t);
      });
    }
  });
  tbody.innerHTML = rows;
}

function _taskRow(t) {
  return `<tr onclick="toggleTaskDetail(this)" data-task-id="${esc(t.task_id || "")}">
    <td style="color:var(--cyan);font-weight:600">${esc(t.task_id || "")}</td>
    <td style="overflow:hidden;text-overflow:ellipsis;white-space:nowrap">${esc((t.title || "\u2014").substring(0, 40))}</td>
    <td>${statusDot(t.status)} ${thorIcon(t.validated_at)}</td>
    <td style="color:var(--text-dim);overflow:hidden;text-overflow:ellipsis;white-space:nowrap">${esc((t.executor_agent || "\u2014").substring(0, 12))}</td>
    <td style="color:var(--gold)">${t.tokens ? fmt(t.tokens) : "\u2014"}</td>
  </tr>`;
}

window.toggleTaskDetail = function (tr) {
  const next = tr.nextElementSibling;
  if (next && next.classList.contains("task-detail-row")) {
    next.remove();
    tr.classList.remove("expanded");
    return;
  }
  document.querySelectorAll(".task-detail-row").forEach((r) => r.remove());
  document
    .querySelectorAll(".expanded")
    .forEach((r) => r.classList.remove("expanded"));
  const taskId = tr.dataset.taskId;
  let t = null;
  for (const m of allMissionPlans) {
    t = (m.tasks || []).find((tk) => tk.task_id === taskId);
    if (t) break;
  }
  if (!t) return;
  tr.classList.add("expanded");
  const detailRow = document.createElement("tr");
  detailRow.className = "task-detail-row";
  detailRow.innerHTML = `<td colspan="5"><div class="task-detail">
    <strong style="color:var(--cyan)">${esc(t.task_id)}</strong> — ${esc(t.title || "")}
    <br>Status: <span style="color:${statusColor(t.status)}">${t.status}</span>
    · Agent: ${esc(t.executor_agent || "\u2014")} · Host: ${esc(t.executor_host || "\u2014")}
    · Tokens: ${fmt(t.tokens)}
    ${t.validated_at ? ` · ${thorIcon(true)} Validated` : ""}
  </div></td>`;
  tr.after(detailRow);
};

// --- TOKEN CHART ---
function renderTokenChart(daily) {
  const labels = daily.map((d) => d.day.substring(5));
  const input = daily.map((d) => d.input || 0);
  const output = daily.map((d) => d.output || 0);
  if (tokenChart) tokenChart.destroy();
  tokenChart = new Chart($("#token-chart"), {
    type: "line",
    data: {
      labels,
      datasets: [
        {
          label: "Input",
          data: input,
          borderColor: "#00e5ff",
          backgroundColor: "rgba(0,229,255,0.1)",
          fill: true,
          tension: 0.4,
          borderWidth: 2,
          pointRadius: 1,
          pointHoverRadius: 4,
        },
        {
          label: "Output",
          data: output,
          borderColor: "#ff2daa",
          backgroundColor: "rgba(255,45,170,0.08)",
          fill: true,
          tension: 0.4,
          borderWidth: 2,
          pointRadius: 1,
          pointHoverRadius: 4,
        },
      ],
    },
    options: chartOpts(),
  });
}

function renderModelChart(models) {
  const totalCost = models.reduce((s, m) => s + (m.cost || 0), 0);
  const costWidget = document.getElementById("widget-cost");
  if (costWidget) {
    const hdr = costWidget.querySelector(".widget-title");
    if (hdr)
      hdr.innerHTML = `Cost by Model <span style="float:right;color:var(--gold);font-size:11px">Total: $${totalCost.toFixed(2)}</span>`;
  }
  const colors = [
    "#00e5ff",
    "#ff2daa",
    "#ffb700",
    "#00ff88",
    "#ff3355",
    "#8855ff",
    "#44ddff",
    "#ffdd44",
  ];
  if (modelChart) modelChart.destroy();
  modelChart = new Chart($("#model-chart"), {
    type: "doughnut",
    data: {
      labels: models.map((m) => (m.model || "?").replace("claude-", "")),
      datasets: [
        {
          data: models.map((m) => m.cost || 0),
          backgroundColor: colors.slice(0, models.length),
          borderColor: "#0a0e1a",
          borderWidth: 2,
        },
      ],
    },
    options: {
      responsive: true,
      maintainAspectRatio: false,
      plugins: {
        legend: {
          position: "right",
          labels: {
            color: "#c8d0e8",
            font: { family: "JetBrains Mono", size: 10 },
            padding: 8,
            boxWidth: 12,
          },
        },
        tooltip: { callbacks: { label: (ctx) => `$${ctx.raw.toFixed(2)}` } },
      },
      cutout: "65%",
    },
  });
}

function renderDist(dist) {
  const cm = {
    done: "#00ff88",
    in_progress: "#ffb700",
    submitted: "#00e5ff",
    blocked: "#ff3355",
    pending: "#5a6080",
    cancelled: "#ff3355",
    skipped: "#3a3f55",
  };
  if (distChart) distChart.destroy();
  distChart = new Chart($("#dist-chart"), {
    type: "bar",
    data: {
      labels: dist.map((d) => d.status),
      datasets: [
        {
          data: dist.map((d) => d.count),
          backgroundColor: dist.map((d) => cm[d.status] || "#5a6080"),
          borderRadius: 4,
          barPercentage: 0.7,
        },
      ],
    },
    options: {
      responsive: true,
      maintainAspectRatio: false,
      indexAxis: "y",
      plugins: { legend: { display: false } },
      scales: {
        x: {
          grid: { color: "#1a2040" },
          ticks: { color: "#5a6080", font: { size: 10 } },
        },
        y: {
          grid: { display: false },
          ticks: {
            color: "#c8d0e8",
            font: { family: "JetBrains Mono", size: 11 },
          },
        },
      },
    },
  });
}

function chartOpts() {
  return {
    responsive: true,
    maintainAspectRatio: false,
    interaction: { mode: "index", intersect: false },
    plugins: {
      legend: {
        labels: {
          color: "#c8d0e8",
          font: { family: "JetBrains Mono", size: 10 },
          boxWidth: 12,
          padding: 8,
        },
      },
      tooltip: {
        backgroundColor: "#0f1424",
        borderColor: "#1a2040",
        borderWidth: 1,
        titleFont: { family: "JetBrains Mono" },
        bodyFont: { family: "JetBrains Mono" },
        callbacks: { label: (ctx) => `${ctx.dataset.label}: ${fmt(ctx.raw)}` },
      },
      zoom: {
        pan: { enabled: true, mode: "x" },
        zoom: {
          wheel: { enabled: true },
          pinch: { enabled: true },
          mode: "x",
        },
      },
    },
    scales: {
      x: {
        grid: { color: "#1a2040" },
        ticks: { color: "#5a6080", font: { size: 9 }, maxRotation: 0 },
      },
      y: {
        grid: { color: "#1a2040" },
        ticks: {
          color: "#5a6080",
          font: { size: 10 },
          callback: (v) => fmt(v),
        },
      },
    },
  };
}
window.resetTokenZoom = function () {
  if (tokenChart) tokenChart.resetZoom();
};

// --- MESH STRIP ---
const _SVG = (path) =>
  `<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" width="20" height="20" fill="currentColor">${path}</svg>`;
const OS_ICON = {
  macos: _SVG(
    '<path d="M12.152 6.896c-.948 0-2.415-1.078-3.96-1.04-2.04.027-3.91 1.183-4.961 3.014-2.117 3.675-.546 9.103 1.519 12.09 1.013 1.454 2.208 3.09 3.792 3.039 1.52-.065 2.09-.987 3.935-.987 1.831 0 2.35.987 3.96.948 1.637-.026 2.676-1.48 3.676-2.948 1.156-1.688 1.636-3.325 1.662-3.415-.039-.013-3.182-1.221-3.22-4.857-.026-3.04 2.48-4.494 2.597-4.559-1.429-2.09-3.623-2.324-4.39-2.376-2-.156-3.675 1.09-4.61 1.09zM15.53 3.83c.843-1.012 1.4-2.427 1.245-3.83-1.207.052-2.662.805-3.532 1.818-.78.896-1.454 2.338-1.273 3.714 1.338.104 2.715-.688 3.559-1.701"/>',
  ),
  linux: _SVG(
    '<path d="M12.504 0c-.155 0-.315.008-.48.021-4.226.333-3.105 4.807-3.17 6.298-.076 1.092-.3 1.953-1.05 3.02-.885 1.051-2.127 2.75-2.716 4.521-.278.832-.41 1.684-.287 2.489a.424.424 0 0 0-.11.135c-.26.268-.45.6-.663.839-.199.199-.485.267-.797.4-.313.136-.658.269-.864.68-.09.189-.136.394-.132.602 0 .199.027.4.055.536.058.399.116.728.04.97-.249.68-.28 1.145-.106 1.484.174.334.535.47.94.601.81.2 1.91.135 2.774.6.926.466 1.866.67 2.616.47.526-.116.97-.464 1.208-.946.587-.003 1.23-.269 2.26-.334.699-.058 1.574.267 2.577.2a.697.697 0 0 0 .114.333c.391.778 1.113 1.132 1.884 1.071.771-.06 1.592-.536 2.257-1.306.631-.765 1.683-1.084 2.378-1.503.348-.199.629-.469.649-.853.023-.4-.2-.811-.714-1.376v-.097c-.17-.2-.25-.535-.338-.926-.085-.401-.182-.786-.492-1.046-.059-.054-.123-.067-.188-.135a.357.357 0 0 0-.19-.064c.431-1.278.264-2.55-.173-3.694-.533-1.41-1.465-2.638-2.175-3.483-.796-1.005-1.576-1.957-1.56-3.368.026-2.152.236-6.133-3.544-6.139z"/>',
  ),
  windows: _SVG(
    '<path d="M0 3.449L9.75 2.1v9.451H0m10.949-9.602L24 0v11.4H10.949M0 12.6h9.75v9.451L0 20.699M10.949 12.6H24V24l-12.9-1.801"/>',
  ),
  unknown: _SVG(
    '<path d="M4 6h16v10H4V6zm0-2a2 2 0 0 0-2 2v10a2 2 0 0 0 2 2h6v2H8v2h8v-2h-2v-2h6a2 2 0 0 0 2-2V6a2 2 0 0 0-2-2H4z"/>',
  ),
};

let lastMeshData = null;

function _meshNodeHtml(p) {
  const cls = [
    "mesh-node",
    p.is_online ? "online" : "offline",
    p.role === "coordinator" ? "coordinator" : "",
  ]
    .filter(Boolean)
    .join(" ");
  const icon = OS_ICON[p.os] || OS_ICON.unknown;
  const caps = (p.capabilities || "").split(",").filter(Boolean);
  const loadPct = Math.min(p.cpu || 0, 100);
  const loadColor =
    loadPct < 50 ? "var(--green)" : loadPct < 80 ? "var(--gold)" : "var(--red)";
  const plans = p.plans || [];
  let planHtml = "";
  plans.forEach((pl) => {
    const pp =
      pl.tasks_total > 0
        ? Math.round((100 * pl.tasks_done) / pl.tasks_total)
        : 0;
    const barColor = pl.status === "doing" ? "var(--cyan)" : "var(--text-dim)";
    planHtml += `<div class="mn-plan" onclick="event.stopPropagation();openPlanSidebar(${pl.id})">
      <div class="mn-plan-head"><span class="mn-plan-id">#${pl.id}</span> ${esc((pl.name || "").substring(0, 18))}</div>
      <div class="mn-plan-bar"><div class="mn-plan-fill" style="width:${pp}%;background:${barColor}"></div></div>`;
    (pl.active_tasks || []).forEach((t) => {
      planHtml += `<div class="mn-task">${statusDot(t.status)} ${esc((t.title || "").substring(0, 22))}</div>`;
    });
    planHtml += "</div>";
  });
  const _a = (act, ttl, svg) =>
    `<button class="mn-act-btn" data-peer="${esc(p.peer_name)}" data-action="${act}" title="${ttl}"><svg viewBox="0 0 16 16" width="14" height="14">${svg}</svg></button>`;
  const actionsHtml = p.is_online
    ? `<div class="mn-actions">
    ${_a("terminal", "Terminal", '<rect x="2" y="3" width="12" height="10" rx="1.5"/><path d="M4.5 7l2 1.5-2 1.5M8 10.5h3"/>')}
    ${_a("sync", "Sync", '<path d="M1.5 8a6.5 6.5 0 0112.4-2.5M14.5 8a6.5 6.5 0 01-12.4 2.5"/><path d="M13 2.5v3h-3M3 13.5v-3h3"/>')}
    ${_a("heartbeat", "Heartbeat", '<path d="M2 8h2l1.5-3 2 6 2-4.5 1.5 1.5h3"/>')}
    ${_a("auth", "Auth", '<rect x="4" y="7" width="8" height="6" rx="1"/><path d="M6 7V5a2 2 0 014 0v2"/><circle cx="8" cy="10" r="0.5"/>')}
    ${_a("status", "Status", '<circle cx="8" cy="8" r="5.5"/><path d="M8 5v3.5l2.5 1.5"/>')}
    ${_a("movehere", "Move Here", '<path d="M3 8h10M10 5l3 3-3 3"/>')}
    ${_a("reboot", "Reboot", '<path d="M8 2v4M4.5 4.2A5.5 5.5 0 108 2.5"/>')}
  </div>`
    : `<div class="mn-actions">
    ${_a("wake", "Wake (WoL)", '<circle cx="8" cy="8" r="5.5" fill="none"/><path d="M8 5v3M8 10v0.5"/>')}
  </div>`;
  return `<div class="${cls}" data-peer="${esc(p.peer_name)}">
    <div class="mn-top">
      <span class="mn-os">${icon}</span>
      <span class="mn-name">${esc(p.peer_name)}</span>
      <span class="mn-dot ${p.is_online ? "on" : "off"}"></span>
    </div>
    <div class="mn-role">${p.role.toUpperCase()}${p.is_local ? " \u00B7 LOCAL" : ""}</div>
    <div class="mn-caps">${caps.map((c) => `<span class="mn-cap${c === "ollama" ? " accent" : ""}">${c}</span>`).join("")}</div>
    ${p.is_online ? `<div class="mn-stats">${p.active_tasks} tasks \u00B7 CPU ${Math.round(p.cpu)}%</div><div class="mn-load-bar"><div class="mn-load-fill" style="width:${loadPct}%;background:${loadColor}"></div></div>` : '<div class="mn-stats offline-text">No heartbeat</div>'}
    ${planHtml}
    ${actionsHtml}
  </div>`;
}

function renderMeshStrip(peers) {
  const el = $("#mesh-strip");
  if (!el || !peers || !peers.length) {
    if (el) el.innerHTML = "";
    return;
  }
  lastMeshData = peers;
  const online = peers.filter((p) => p.is_online).length;
  const coord = peers.find((p) => p.role === "coordinator");
  const workers = peers.filter((p) => p.role !== "coordinator");
  // Populate widget header actions
  const bar = $("#mesh-actions-bar");
  if (bar) {
    bar.innerHTML = `<span class="mesh-count">${online}/${peers.length} online</span>
      <button class="widget-action-btn" onclick="meshAction('fullsync','__all__')" title="Bidirectional sync all repos + config">
        <svg viewBox="0 0 16 16" width="12" height="12"><path d="M1.5 8a6.5 6.5 0 0112.4-2.5M14.5 8a6.5 6.5 0 01-12.4 2.5"/><path d="M13 2.5v3h-3M3 13.5v-3h3"/></svg> Full Sync
      </button>
      <button class="widget-action-btn" onclick="meshAction('sync','__all__')" title="Push config to all peers">
        <svg viewBox="0 0 16 16" width="12" height="12"><path d="M8 2v12M2 8l6-6 6 6"/></svg> Push
      </button>`;
  }
  let html = "";
  if (coord && workers.length > 0) {
    // Hub-spoke: workers row on top, spoke lines, coordinator below
    html += '<div class="mesh-hub">';
    html += '<div class="mesh-hub-workers">';
    workers.forEach((w) => {
      html += _meshNodeHtml(w);
    });
    html += "</div>";
    html += '<div class="mesh-hub-spokes" id="mesh-spokes"></div>';
    html += '<div class="mesh-hub-coord">' + _meshNodeHtml(coord) + "</div>";
    html += "</div>";
  } else {
    // No coordinator or solo: simple row
    html += '<div class="mesh-nodes">';
    peers.forEach((p) => {
      html += _meshNodeHtml(p);
    });
    html += "</div>";
  }
  el.innerHTML = html;
  // Draw spoke lines from each worker to coordinator
  requestAnimationFrame(() => _drawSpokes());
}

function _drawSpokes() {
  const container = document.getElementById("mesh-spokes");
  if (!container) return;
  const workerRow = container.previousElementSibling;
  const coordRow = container.nextElementSibling;
  if (!workerRow || !coordRow) return;
  const coordNode = coordRow.querySelector(".mesh-node");
  const workerNodes = workerRow.querySelectorAll(".mesh-node");
  if (!coordNode || !workerNodes.length) return;
  const hubRect = container.parentElement.getBoundingClientRect();
  const cRect = coordNode.getBoundingClientRect();
  const cx = cRect.left + cRect.width / 2 - hubRect.left;
  const spokeH = container.offsetHeight || 32;
  let svg = `<svg width="100%" height="${spokeH}" style="position:absolute;top:0;left:0;overflow:visible">`;
  svg +=
    '<defs><filter id="glow"><feGaussianBlur stdDeviation="2" result="blur"/><feMerge><feMergeNode in="blur"/><feMergeNode in="SourceGraphic"/></feMerge></filter></defs>';
  workerNodes.forEach((w, i) => {
    const wRect = w.getBoundingClientRect();
    const wx = wRect.left + wRect.width / 2 - hubRect.left;
    const online = w.classList.contains("online");
    const color = online ? "#00e5ff" : "#1a2040";
    const op = online ? "0.35" : "0.12";
    const pid = `spoke-${i}`;
    svg += `<line x1="${wx}" y1="0" x2="${cx}" y2="${spokeH}" stroke="${color}" stroke-width="1.5" opacity="${op}" stroke-dasharray="${online ? "none" : "3,4"}"/>`;
    if (online) {
      svg += `<path id="${pid}" d="M${wx},0 L${cx},${spokeH}" fill="none"/>`;
      svg += `<circle r="2.5" fill="#00e5ff" filter="url(#glow)" opacity="0.9"><animateMotion dur="${1.5 + i * 0.3}s" repeatCount="indefinite"><mpath href="#${pid}"/></animateMotion></circle>`;
      svg += `<circle r="2" fill="#ff2daa" filter="url(#glow)" opacity="0.7"><animateMotion dur="${2 + i * 0.2}s" repeatCount="indefinite" keyPoints="1;0" keyTimes="0;1" calcMode="linear"><mpath href="#${pid}"/></animateMotion></circle>`;
    }
  });
  svg += "</svg>";
  container.innerHTML = svg;
}

function applyMeshSyncBadges(items) {
  if (!items || !items.length) return;
  items.forEach((s) => {
    const node = document.querySelector(
      `.mesh-node[data-peer="${CSS.escape(s.peer_name)}"]`,
    );
    if (!node) return;
    let cls, title;
    if (!s.reachable) {
      cls = "mn-sync-red";
      title = "Unreachable";
    } else if (s.config_synced) {
      cls = "mn-sync-green";
      title = "In sync";
    } else {
      cls = "mn-sync-yellow";
      title = "Out of sync";
    }
    const badge = document.createElement("span");
    badge.className = `mn-sync-dot ${cls}`;
    badge.title = title;
    node.querySelector(".mn-top").appendChild(badge);
  });
}

// Event Feed Widget
async function renderEventFeed() {
  const el = $('#event-feed-content');
  if (!el) return;
  try {
    const events = await fetchJson('/api/events');
    if (!events || !events.length) {
      el.innerHTML = '<span style="color:var(--text-dim);font-size:11px">No events yet</span>';
      return;
    }
    const icons = {plan_completed:'✓',wave_completed:'◈',human_needed:'⚠',node_offline:'✗',task_status_changed:'◉'};
    const colors = {plan_completed:'var(--green)',wave_completed:'var(--cyan)',human_needed:'var(--gold)',node_offline:'var(--red)',task_status_changed:'var(--text-dim)'};
    el.innerHTML = events.slice(0, 15).map(e => {
      const icon = icons[e.event_type] || '•';
      const color = colors[e.event_type] || 'var(--text-dim)';
      const age = e.created_at ? _timeAgo(e.created_at) : '';
      const click = e.plan_id ? ` onclick="location.hash='#plan/${e.plan_id}'"` : '';
      return `<div class="event-row"${click} style="cursor:${e.plan_id ? 'pointer' : 'default'}">
        <span style="color:${color};font-weight:600;width:16px">${icon}</span>
        <span class="event-type">${esc(e.event_type.replace(/_/g,' '))}</span>
        <span class="event-peer">${esc(e.source_peer || '')}</span>
        ${e.plan_id ? `<span class="event-plan">#${e.plan_id}</span>` : ''}
        <span class="event-age">${age}</span>
      </div>`;
    }).join('');
  } catch(_) { el.innerHTML = '<span style="color:var(--text-dim)">Error loading events</span>'; }
}
function _timeAgo(ts) {
  const now = Math.floor(Date.now()/1000);
  const d = now - ts;
  if (d < 60) return d + 's';
  if (d < 3600) return Math.floor(d/60) + 'm';
  if (d < 86400) return Math.floor(d/3600) + 'h';
  return Math.floor(d/86400) + 'd';
}

// --- HISTORY ---
function renderHistory(plans) {
  $("#history-list").innerHTML = plans
    .map((p) => {
      const icon = p.status === "done" ? "\u2713" : "\u2717";
      const color = p.status === "done" ? "#00ff88" : "#ff3355";
      return `<div class="history-row" onclick="openPlanSidebar(${p.id})">
      <span style="color:#00e5ff;font-weight:600">#${p.id}</span>
      <span>${esc((p.name || "?").substring(0, 28))}</span>
      <span>${p.tasks_done}/${p.tasks_total}</span>
      <span style="color:${color}">${icon} ${p.status}</span>
    </div>`;
    })
    .join("");
}

// --- PLAN SIDEBAR ---
window.openPlanSidebar = async function (planId) {
  const data = await fetchJson(`/api/plan/${planId}`);
  if (!data || !data.plan) return;
  const p = data.plan;
  const overlay = $("#sidebar-overlay");
  const sidebar = $("#sidebar");
  const body = $("#sb-body");
  $("#sb-title").textContent = `#${p.id} ${(p.name || "").substring(0, 30)}`;

  const pct =
    p.tasks_total > 0 ? Math.round((100 * p.tasks_done) / p.tasks_total) : 0;
  const sColor = statusColor(p.status);
  const lines =
    (p.lines_added || 0) + (p.lines_removed || 0) > 0
      ? `<br>Lines: <span style="color:var(--green)">+${p.lines_added || 0}</span> / <span style="color:var(--red)">-${p.lines_removed || 0}</span>`
      : "";
  const cost = data.cost || {};
  const costLine =
    cost.tokens || cost.cost
      ? `<br>Tokens: ${fmt(cost.tokens)} \u00B7 Cost: $${Number(cost.cost || 0).toFixed(2)}`
      : "";

  let html = `<div class="sb-meta">
    <strong>Status:</strong> ${statusDot(p.status)} <span style="color:${sColor}">${p.status.toUpperCase()}</span>
    <br><strong>Progress:</strong> ${p.tasks_done}/${p.tasks_total} (${pct}%)
    <br><strong>Host:</strong> ${esc(_resolveHost(p.execution_host))}
    ${p.parallel_mode ? `<br><strong>Mode:</strong> ${esc(p.parallel_mode)}` : ""}
    ${p.started_at ? `<br><strong>Started:</strong> ${p.started_at}` : ""}
    ${p.completed_at ? `<br><strong>Completed:</strong> ${p.completed_at}` : ""}
    ${lines}${costLine}
  </div>`;

  if (p.human_summary) {
    html += `<div class="sb-summary">${esc(p.human_summary)}</div>`;
  }

  if (data.waves && data.waves.length) {
    html += '<div class="sb-section">Waves</div>';
    data.waves.forEach((w) => {
      const wp =
        w.tasks_total > 0
          ? Math.round((100 * w.tasks_done) / w.tasks_total)
          : 0;
      const wColor =
        w.status === "done"
          ? "var(--green)"
          : w.status === "in_progress"
            ? "var(--gold)"
            : w.status === "cancelled"
              ? "var(--red)"
              : "var(--text-dim)";
      html += `<div class="sb-wave">
        <div>
          <span style="color:var(--cyan)">${esc(w.wave_id)}</span>
          <span style="color:var(--text-dim)">${esc((w.name || "").substring(0, 20))}</span>
          <span style="color:${wColor};font-size:10px">${w.status}</span>
          ${thorIcon(w.validated_at)}
          ${w.pr_number ? `<span style="color:var(--magenta);font-size:10px">PR #${w.pr_number}</span>` : ""}
          <div class="sb-wave-bar"><div class="sb-wave-fill" style="width:${wp}%;background:${wColor}"></div></div>
        </div>
        <div style="text-align:right;color:var(--cyan);font-weight:600;font-size:11px">${wp}%</div>
      </div>`;
    });
  }

  if (data.tasks && data.tasks.length) {
    html += '<div class="sb-section">Tasks</div>';
    data.tasks.forEach((t) => {
      const tc = statusColor(t.status);
      html += `<div class="sb-task">
        <span class="sb-task-id">${esc(t.task_id)}</span>
        <span>${esc((t.title || "\u2014").substring(0, 40))}</span>
        <span style="color:${tc}">${statusDot(t.status)} ${t.status}</span>
        ${thorIcon(t.validated_at)}
      </div>`;
    });
  }

  body.innerHTML = html;
  overlay.classList.add("open");
  sidebar.classList.add("open");
};

window.closeSidebar = function () {
  $("#sidebar-overlay").classList.remove("open");
  $("#sidebar").classList.remove("open");
};

// --- ACTIVITY FEED ---
function renderActivity(mission, mesh) {
  const el = $("#activity-feed");
  if (!el) return;
  const items = [];
  if (mission && mission.tasks) {
    mission.tasks
      .filter((t) => t.status === "in_progress")
      .forEach((t) => {
        items.push({
          icon: "⚡",
          color: "#ffb700",
          text: `${t.executor_agent || "agent"} executing ${t.task_id}`,
          time: "now",
        });
      });
    mission.tasks
      .filter((t) => t.status === "submitted")
      .forEach((t) => {
        items.push({
          icon: "◈",
          color: "#00e5ff",
          text: `${t.task_id} awaiting validation`,
          time: "sub",
        });
      });
    mission.tasks
      .filter((t) => t.status === "blocked")
      .forEach((t) => {
        items.push({
          icon: "✗",
          color: "#ff3355",
          text: `${t.task_id} BLOCKED`,
          time: "blk",
        });
      });
  }
  if (mesh) {
    mesh
      .filter((p) => p.is_online)
      .forEach((p) => {
        items.push({
          icon: "●",
          color: "#00ff88",
          text: `${p.peer_name} online (${p.active_tasks} tasks)`,
          time: "mesh",
        });
      });
  }
  if (items.length === 0) {
    el.innerHTML = '<span style="color:#5a6080">No recent activity</span>';
    return;
  }
  el.innerHTML = items
    .slice(0, 8)
    .map(
      (i) =>
        `<div class="activity-item">
      <span class="activity-time">${i.time}</span>
      <span class="activity-icon" style="color:${i.color}">${i.icon}</span>
      <span>${esc(i.text)}</span>
    </div>`,
    )
    .join("");
}

// --- CLOCK ---
function updateClock() {
  $("#clock").textContent = new Date().toLocaleString("en-GB", {
    day: "2-digit",
    month: "short",
    year: "numeric",
    hour: "2-digit",
    minute: "2-digit",
    second: "2-digit",
  });
}

// Peer actions moved to mesh-actions.js (T2-02)

// Old inline terminal removed — replaced by xterm.js TerminalManager in terminal.js

// --- Open all mesh terminals ---
window.openAllTerminals = function () {
  if (typeof termMgr === "undefined") return;
  const peers = lastMeshData || [];
  const online = peers.filter((p) => p.is_online);
  if (!online.length) {
    if (typeof showOutputModal === "function")
      showOutputModal("Terminals", "No online mesh nodes");
    return;
  }
  online.forEach((p) => {
    // If node has an active plan, attach to its tmux session
    const activePlan = (p.plans || []).find((pl) => pl.status === "doing");
    const tmux = "Convergio";
    termMgr.open(p.peer_name, p.peer_name, tmux);
  });
  if (online.length > 1) termMgr.setMode("grid");
  else termMgr.setMode("dock");
};

// --- ZOOM ---
const ZOOM_STEP = 10;
const ZOOM_MIN = 60;
const ZOOM_MAX = 160;
let currentZoom = parseInt(localStorage.getItem("dashZoom") || "100", 10);
function applyZoom(z) {
  currentZoom = Math.max(ZOOM_MIN, Math.min(ZOOM_MAX, z));
  document.body.style.zoom = currentZoom / 100;
  const label = document.getElementById("zoom-level");
  if (label) label.textContent = currentZoom + "%";
  localStorage.setItem("dashZoom", String(currentZoom));
}
window.dashZoom = function (dir) {
  if (dir === 0) applyZoom(100);
  else applyZoom(currentZoom + dir * ZOOM_STEP);
};
applyZoom(currentZoom);

// --- Refresh stepper ---
const REFRESH_STEPS = [10, 15, 30, 60, 120];
let refreshIdx = REFRESH_STEPS.indexOf(
  parseInt(localStorage.getItem("dashRefresh") || "30", 10),
);
if (refreshIdx === -1) refreshIdx = 2;
let refreshTimer = null;

function applyRefresh() {
  const sec = REFRESH_STEPS[refreshIdx];
  localStorage.setItem("dashRefresh", String(sec));
  const label = document.getElementById("refresh-label");
  if (label) label.textContent = sec < 60 ? sec + "s" : sec / 60 + "m";
  if (refreshTimer) clearInterval(refreshTimer);
  refreshTimer = setInterval(refreshAll, sec * 1000);
}
window.changeRefresh = function (dir) {
  refreshIdx = Math.max(
    0,
    Math.min(REFRESH_STEPS.length - 1, refreshIdx + dir),
  );
  applyRefresh();
};

// Deep link hash router
function handleHashRoute() {
  const hash = location.hash;
  if (!hash) return;
  const planMatch = hash.match(/^#plan\/(\d+)/);
  if (planMatch) {
    const planId = parseInt(planMatch[1]);
    filterTasks(planId);
    const card = document.querySelector(`.mission-plan[onclick*="${planId}"]`);
    if (card) {
      card.scrollIntoView({ behavior: 'smooth', block: 'center' });
      card.classList.add('highlight-pulse');
      setTimeout(() => card.classList.remove('highlight-pulse'), 3000);
    }
  }
}
window.addEventListener('hashchange', handleHashRoute);
setTimeout(handleHashRoute, 1500);

// Notification polling + toasts
let _notifLastId = 0;
async function pollNotifications() {
  try {
    const data = await fetchJson('/api/notifications');
    if (!data || !data.length) return;
    data.forEach(n => {
      if (n.id > _notifLastId) {
        _notifLastId = n.id;
        showToast(n.title, n.message, n.link, n.type);
      }
    });
  } catch (_) {}
}
function showToast(title, msg, link, type) {
  let container = document.getElementById('toast-container');
  if (!container) {
    container = document.createElement('div');
    container.id = 'toast-container';
    document.body.appendChild(container);
  }
  const toast = document.createElement('div');
  toast.className = `toast toast-${type || 'info'}`;
  const esc = s => { const d = document.createElement('div'); d.textContent = s; return d.innerHTML; };
  toast.innerHTML = `<div class="toast-title">${esc(title)}</div><div class="toast-msg">${esc(msg || '')}</div>`;
  if (link) toast.style.cursor = 'pointer';
  toast.addEventListener('click', () => { if (link) location.hash = link.replace(/.*#/, '#'); toast.remove(); });
  container.appendChild(toast);
  setTimeout(() => toast.remove(), 8000);
}
setInterval(pollNotifications, 30000);

// --- INIT ---
updateClock();
setInterval(updateClock, 1000);
refreshAll();
applyRefresh();
