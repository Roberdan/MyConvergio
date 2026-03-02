/**
 * Convergio Control Room — main application logic.
 * Data fetching, rendering, charts, task details, activity feed.
 */

const $ = (s) => document.querySelector(s);
let tokenChart, modelChart, distChart;
let lastMissionData = null;

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
    done: "#00ff88",
    in_progress: "#ffb700",
    submitted: "#00e5ff",
    blocked: "#ff3355",
    pending: "#5a6080",
    cancelled: "#ff3355",
    skipped: "#5a6080",
    doing: "#00e5ff",
    todo: "#5a6080",
  };
  return m[s] || "#5a6080";
}

function statusIcon(s) {
  return (
    {
      done: "✓",
      in_progress: "⚡",
      submitted: "◈",
      blocked: "✗",
      pending: "○",
      cancelled: "✗",
      skipped: "—",
    }[s] || "?"
  );
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
  if (ov) renderKpi(ov);
  renderMission(mission);
  if (daily) renderTokenChart(daily);
  if (models) renderModelChart(models);
  if (mesh) renderMeshStrip(mesh);
  if (history) renderHistory(history);
  if (dist) renderDist(dist);
  renderActivity(mission, mesh);
  $("#last-update").textContent = "Updated: " + new Date().toLocaleTimeString();
}

// --- KPI ---
function renderKpi(d) {
  const items = [
    { label: "Plans", value: d.plans_total, sub: `${d.plans_active} active` },
    { label: "Active", value: d.plans_active },
    { label: "Agents", value: d.agents_running, sub: "running" },
    {
      label: "Tokens",
      value: fmt(d.total_tokens),
      sub: `Today: ${fmt(d.today_tokens)}`,
    },
    {
      label: "Cost",
      value:
        "$" +
        Number(d.total_cost).toLocaleString(undefined, {
          maximumFractionDigits: 0,
        }),
      sub: `Today: $${Number(d.today_cost).toFixed(2)}`,
    },
    { label: "Blocked", value: d.blocked, alert: d.blocked > 0 },
  ];
  $("#kpi-bar").innerHTML = items
    .map(
      (i) =>
        `<div class="kpi-card ${i.alert ? "alert" : ""}">
      <div class="kpi-label">${i.label}</div>
      <div class="kpi-value">${i.value}</div>
      ${i.sub ? `<div class="kpi-sub">${i.sub}</div>` : ""}
    </div>`,
    )
    .join("");
}

// --- MISSION ---
function renderMission(data) {
  lastMissionData = data;
  if (!data || !data.plan) {
    $("#mission-content").innerHTML =
      '<span style="color:#5a6080">No active mission</span>';
    $("#task-table tbody").innerHTML = "";
    return;
  }
  const p = data.plan;
  const pct =
    p.tasks_total > 0 ? Math.round((100 * p.tasks_done) / p.tasks_total) : 0;
  let html = `<div style="margin-bottom:8px">
    <span class="mission-id">#${p.id}</span>
    <span class="mission-name">&nbsp;${esc(p.name)}</span>
    <span class="badge badge-${p.status}">${p.status.toUpperCase()}</span>
    ${p.parallel_mode ? `<span class="badge badge-doing">${p.parallel_mode}</span>` : ""}
  </div>
  <div class="mission-summary">${esc(p.human_summary || "")}</div>
  <div class="mission-meta">${p.tasks_done}/${p.tasks_total} tasks · ${pct}% · <span class="host-badge" title="Execution host">⬡ ${esc(p.execution_host || "local")}</span></div>`;

  if (data.waves && data.waves.length) {
    html += '<div style="margin-top:12px">';
    data.waves.forEach((w) => {
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
        <div class="wave-label">${esc(w.wave_id)} ${esc((w.name || "").substring(0, 16))}</div>
        <div class="wave-bar"><div class="wave-fill ${cls}" style="width:${wp}%"></div></div>
        <div class="wave-pct">${wp}%</div>
      </div>`;
    });
    html += "</div>";
  }
  $("#mission-content").innerHTML = html;

  // Tasks with click-to-expand
  const tbody = $("#task-table tbody");
  tbody.innerHTML = (data.tasks || [])
    .map(
      (t, i) =>
        `<tr onclick="toggleTaskDetail(this,${i})" data-idx="${i}">
      <td style="color:#00e5ff;font-weight:600">${esc(t.task_id)}</td>
      <td>${esc((t.title || "—").substring(0, 35))}</td>
      <td><span style="color:${statusColor(t.status)}">${statusIcon(t.status)}</span> ${t.status}</td>
      <td style="color:#5a6080">${esc((t.executor_agent || "—").substring(0, 10))}</td>
      <td style="color:#5a6080">${esc((t.executor_host || "—").substring(0, 10))}</td>
      <td style="color:#ffb700">${t.tokens ? fmt(t.tokens) : "—"}</td>
    </tr>`,
    )
    .join("");
}

window.toggleTaskDetail = function (tr, idx) {
  const next = tr.nextElementSibling;
  if (next && next.classList.contains("task-detail-row")) {
    next.remove();
    tr.classList.remove("expanded");
    return;
  }
  // Close others
  document.querySelectorAll(".task-detail-row").forEach((r) => r.remove());
  document
    .querySelectorAll(".expanded")
    .forEach((r) => r.classList.remove("expanded"));

  if (!lastMissionData || !lastMissionData.tasks[idx]) return;
  const t = lastMissionData.tasks[idx];
  tr.classList.add("expanded");
  const detailRow = document.createElement("tr");
  detailRow.className = "task-detail-row";
  detailRow.innerHTML = `<td colspan="6"><div class="task-detail">
    <strong style="color:#00e5ff">${esc(t.task_id)}</strong> — ${esc(t.title || "")}
    <br>Status: <span style="color:${statusColor(t.status)}">${t.status}</span>
    · Agent: ${esc(t.executor_agent || "—")} · Host: ${esc(t.executor_host || "—")}
    · Tokens: ${fmt(t.tokens)}
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

// --- MESH STRIP ---
const _SVG = (path) =>
  `<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" width="20" height="20" fill="currentColor">${path}</svg>`;
const OS_ICON = {
  macos: _SVG(
    '<path d="M17 3H7a4 4 0 0 0-4 4v10a4 4 0 0 0 4 4h10a4 4 0 0 0 4-4V7a4 4 0 0 0-4-4zm-5 2c1.1 0 2 .9 2 2 0 .4-.1.7-.3 1H14a1 1 0 0 1 0 2h-1v5a1 1 0 0 1-2 0v-5H9a1 1 0 0 1 0-2h1.3c-.2-.3-.3-.6-.3-1 0-1.1.9-2 2-2z"/>',
  ),
  linux: _SVG(
    '<path d="M5 19h14v2H5v-2zm2-2h10a1 1 0 0 0 .7-1.7l-5-5a1 1 0 0 0-1.4 0l-5 5A1 1 0 0 0 7 17zm5-4.6 2.9 2.9H9.1L12 12.4z"/>',
  ),
  windows: _SVG(
    '<path d="M3 3h8v8H3V3zm10 0h8v8h-8V3zM3 13h8v8H3v-8zm10 0h8v8h-8v-8z"/>',
  ),
  unknown: _SVG(
    '<path d="M21 17H3V5h18v12zM21 3H3a2 2 0 0 0-2 2v12a2 2 0 0 0 2 2h7v2H8v2h8v-2h-2v-2h7a2 2 0 0 0 2-2V5a2 2 0 0 0-2-2z"/>',
  ),
};

let lastMeshData = null;

function renderMeshStrip(peers) {
  const el = $("#mesh-strip");
  if (!el || !peers || !peers.length) {
    if (el) el.innerHTML = "";
    return;
  }
  lastMeshData = peers;
  const online = peers.filter((p) => p.is_online).length;
  const coord = peers.filter((p) => p.role === "coordinator");
  const workers = peers.filter((p) => p.role !== "coordinator");
  const half = Math.ceil(workers.length / 2);
  const ordered = [...workers.slice(0, half), ...coord, ...workers.slice(half)];

  let html = `<div class="mesh-inner"><div class="mesh-header">
    <span class="mesh-title-text">\u25C8 MESH NETWORK</span>
    <span class="mesh-count">${online}/${peers.length} online</span>
  </div><div class="mesh-nodes">`;
  ordered.forEach((p, i) => {
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
      loadPct < 50
        ? "var(--green)"
        : loadPct < 80
          ? "var(--gold)"
          : "var(--red)";
    // Plan/task info for this peer
    const plans = p.plans || [];
    let planHtml = "";
    if (plans.length > 0) {
      plans.forEach((pl) => {
        const pp =
          pl.tasks_total > 0
            ? Math.round((100 * pl.tasks_done) / pl.tasks_total)
            : 0;
        const barColor =
          pl.status === "doing" ? "var(--cyan)" : "var(--text-dim)";
        planHtml += `<div class="mn-plan" onclick="event.stopPropagation();openPlanSidebar(${pl.id})">
          <div class="mn-plan-head"><span class="mn-plan-id">#${pl.id}</span> ${esc((pl.name || "").substring(0, 18))}</div>
          <div class="mn-plan-bar"><div class="mn-plan-fill" style="width:${pp}%;background:${barColor}"></div></div>`;
        if (pl.active_tasks && pl.active_tasks.length) {
          pl.active_tasks.forEach((t) => {
            const tc = statusColor(t.status);
            planHtml += `<div class="mn-task"><span style="color:${tc}">${statusIcon(t.status)}</span> ${esc((t.title || "").substring(0, 22))}</div>`;
          });
        }
        planHtml += "</div>";
      });
    }

    html += `<div class="${cls}" data-peer="${esc(p.peer_name)}" onclick="showPeerActions(this,'${esc(p.peer_name)}')">
      <div class="mn-top">
        <span class="mn-os">${icon}</span>
        <span class="mn-name">${esc(p.peer_name)}</span>
        <span class="mn-dot ${p.is_online ? "on" : "off"}"></span>
      </div>
      <div class="mn-role">${p.role.toUpperCase()}${p.is_local ? " \u00B7 LOCAL" : ""}</div>
      <div class="mn-caps">${caps.map((c) => `<span class="mn-cap${c === "ollama" ? " accent" : ""}">${c}</span>`).join("")}</div>
      ${p.is_online ? `<div class="mn-stats">${p.active_tasks} tasks \u00B7 CPU ${Math.round(p.cpu)}%</div><div class="mn-load-bar"><div class="mn-load-fill" style="width:${loadPct}%;background:${loadColor}"></div></div>` : '<div class="mn-stats offline-text">No heartbeat</div>'}
      ${planHtml}
    </div>`;
    if (i < ordered.length - 1) {
      const bothOn = p.is_online && ordered[i + 1].is_online;
      html += `<div class="mesh-link ${bothOn ? "active" : ""}">
        <div class="mesh-link-line"></div>
        ${bothOn ? '<div class="mesh-flow-dot"></div><div class="mesh-flow-dot" style="animation-delay:-0.9s"></div><div class="mesh-flow-dot-reverse"></div><div class="mesh-flow-dot-reverse" style="animation-delay:-0.9s"></div>' : ""}
      </div>`;
    }
  });
  html += "</div></div>";
  el.innerHTML = html;
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
    <strong>Status:</strong> <span style="color:${sColor}">${statusIcon(p.status)} ${p.status}</span>
    <br><strong>Progress:</strong> ${p.tasks_done}/${p.tasks_total} (${pct}%)
    <br><strong>Host:</strong> ${esc(p.execution_host || "local")}
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
        <span style="color:${tc}">${statusIcon(t.status)} ${t.status}</span>
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

// --- PEER ACTIONS ---
window.showPeerActions = function (el, peerName) {
  document.querySelectorAll(".peer-actions").forEach((e) => e.remove());
  const rect = el.getBoundingClientRect();
  const menu = document.createElement("div");
  menu.className = "peer-actions";
  menu.style.cssText = `position:fixed;top:${rect.bottom + 4}px;left:${rect.left}px;z-index:1000;`;
  menu.innerHTML = `
    <div class="pa-item pa-term" onclick="meshAction('terminal','${peerName}')">\u25B6 Terminal (xterm)</div>
    <div class="pa-item" onclick="meshAction('sync','${peerName}')">\u21C4 Sync Config</div>
    <div class="pa-item" onclick="meshAction('heartbeat','${peerName}')">\u2764 Heartbeat</div>
    <div class="pa-item" onclick="meshAction('auth','${peerName}')">\uD83D\uDD11 Push Auth</div>
    <div class="pa-item" onclick="meshAction('status','${peerName}')">\u2139 Status</div>
    <div class="pa-item pa-move" onclick="meshAction('movehere','${peerName}')">\u21E8 Move Plan Here</div>`;
  document.body.appendChild(menu);
  setTimeout(
    () =>
      document.addEventListener("click", () => menu.remove(), { once: true }),
    50,
  );
};

window.meshAction = async function (action, peer) {
  document.querySelectorAll(".peer-actions").forEach((e) => e.remove());
  if (action === "terminal") {
    if (typeof termMgr !== "undefined") {
      termMgr.open(peer, peer);
    }
    return;
  }
  if (action === "movehere") {
    showMovePlanDialog(peer);
    return;
  }
  const res = await fetchJson(
    `/api/mesh/action?action=${action}&peer=${encodeURIComponent(peer)}`,
  );
  if (res && res.output) {
    showOutputModal(action + " \u2014 " + peer, res.output);
  }
};

window.showMovePlanDialog = async function (targetPeer) {
  const plans = await fetchJson("/api/plans/assignable");
  if (!plans || !plans.length) {
    showOutputModal("Move Plan", "No assignable plans found");
    return;
  }
  const overlay = document.createElement("div");
  overlay.className = "modal-overlay";
  let list = plans
    .map(
      (p) =>
        `<div class="move-plan-row" onclick="movePlan(${p.id},'${esc(targetPeer)}',this.closest('.modal-overlay'))">
      <span style="color:var(--cyan);font-weight:600">#${p.id}</span>
      <span>${esc((p.name || "").substring(0, 30))}</span>
      <span style="color:${statusColor(p.status)}">${p.status}</span>
      <span style="color:var(--text-dim)">${esc(p.execution_host || "unassigned")}</span>
    </div>`,
    )
    .join("");
  overlay.innerHTML = `<div class="modal-box">
    <div class="modal-title">Move Plan \u2192 ${esc(targetPeer)}<span class="modal-close" onclick="this.closest('.modal-overlay').remove()">\u2715</span></div>
    <div style="padding:12px;max-height:400px;overflow:auto">${list}</div>
  </div>`;
  document.body.appendChild(overlay);
  overlay.addEventListener("click", (e) => {
    if (e.target === overlay) overlay.remove();
  });
};

window.movePlan = async function (planId, target, overlay) {
  const res = await fetchJson(
    `/api/plan/move?plan_id=${planId}&target=${encodeURIComponent(target)}`,
  );
  if (overlay) overlay.remove();
  if (res && res.ok) {
    refreshAll();
  } else {
    showOutputModal("Move Error", res ? res.error : "Failed");
  }
};

function showOutputModal(title, text) {
  const overlay = document.createElement("div");
  overlay.className = "modal-overlay";
  overlay.innerHTML = `<div class="modal-box">
    <div class="modal-title">${esc(title)}<span class="modal-close" onclick="this.closest('.modal-overlay').remove()">\u2715</span></div>
    <pre class="modal-output">${esc(text)}</pre>
  </div>`;
  document.body.appendChild(overlay);
  overlay.addEventListener("click", (e) => {
    if (e.target === overlay) overlay.remove();
  });
}

// Old inline terminal removed — replaced by xterm.js TerminalManager in terminal.js

// --- INIT ---
updateClock();
setInterval(updateClock, 1000);
refreshAll();
setInterval(refreshAll, 30000);
