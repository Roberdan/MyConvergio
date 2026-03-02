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
function _kpiCard(label, value, sub, fn, alert) {
  return `<div class="kpi-card${alert ? " alert" : ""}" onclick="${fn}"><div class="kpi-label">${label}</div><div class="kpi-value">${value}</div>${sub ? `<div class="kpi-sub">${sub}</div>` : ""}</div>`;
}
function renderKpi(d) {
  const tc =
    "$" +
    Number(d.total_cost).toLocaleString(undefined, {
      maximumFractionDigits: 0,
    });
  $("#kpi-bar").innerHTML =
    _kpiCard(
      "Plans",
      d.plans_total,
      `${d.plans_active} active`,
      "openPlansModal()",
    ) +
    _kpiCard("Active", d.plans_active, "", "openActiveModal()") +
    _kpiCard("Agents", d.agents_running, "running", "openAgentsModal()") +
    _kpiCard(
      "Tokens",
      fmt(d.total_tokens),
      `Today: ${fmt(d.today_tokens)}`,
      "openTokensModal()",
    ) +
    _kpiCard(
      "Cost",
      tc,
      `Today: $${Number(d.today_cost).toFixed(2)}`,
      "openCostModal()",
    ) +
    _kpiCard("Blocked", d.blocked, "", "openBlockedModal()", d.blocked > 0);
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
        <div style="margin-left:6px">${thorIcon(w.validated_at)}</div>
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
      <td style="text-align:center">${thorIcon(t.validated_at)}</td>
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
  detailRow.innerHTML = `<td colspan="7"><div class="task-detail">
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

    const actionsHtml = p.is_online
      ? `<div class="mn-actions">
      <button class="mn-act-btn" data-peer="${esc(p.peer_name)}" data-action="terminal" title="Terminal">\u25B6</button>
      <button class="mn-act-btn" data-peer="${esc(p.peer_name)}" data-action="sync" title="Sync Config">\u27F3</button>
      <button class="mn-act-btn" data-peer="${esc(p.peer_name)}" data-action="heartbeat" title="Heartbeat">\u2661</button>
      <button class="mn-act-btn" data-peer="${esc(p.peer_name)}" data-action="auth" title="Push Auth">\u26BF</button>
      <button class="mn-act-btn" data-peer="${esc(p.peer_name)}" data-action="status" title="Status">\u24D8</button>
      <button class="mn-act-btn" data-peer="${esc(p.peer_name)}" data-action="movehere" title="Move Plan Here">\u21E8</button>
    </div>`
      : "";
    html += `<div class="${cls}" data-peer="${esc(p.peer_name)}">
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
        <span style="color:${tc}">${statusIcon(t.status)} ${t.status}</span>
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
