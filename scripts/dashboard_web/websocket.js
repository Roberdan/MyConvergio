const _SVG = (p) =>
  `<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" width="20" height="20" fill="currentColor">${p}</svg>`;
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
function _meshNodeHtml(p) {
  const cls = [
      "mesh-node",
      p.is_online ? "online" : "offline",
      p.role === "coordinator" ? "coordinator" : "",
    ]
      .filter(Boolean)
      .join(" "),
    caps = (p.capabilities || "").split(",").filter(Boolean),
    loadPct = Math.min(p.cpu || 0, 100),
    loadColor =
      loadPct < 50
        ? "var(--green)"
        : loadPct < 80
          ? "var(--gold)"
          : "var(--red)",
    memUsed = p.mem_used_gb || 0,
    memTotal = p.mem_total_gb || 0,
    memPct =
      memTotal > 0 ? Math.min(Math.round((100 * memUsed) / memTotal), 100) : 0,
    memColor =
      memPct < 60 ? "var(--green)" : memPct < 85 ? "var(--gold)" : "var(--red)",
    peerKey = (p.peer_name || "unknown").replace(/[^a-zA-Z0-9]/g, "_");
  // Track history for sparklines (last 30 samples)
  if (!window._meshHistory) window._meshHistory = {};
  if (!window._meshHistory[peerKey]) window._meshHistory[peerKey] = { cpu: [], mem: [] };
  const hist = window._meshHistory[peerKey];
  if (p.is_online) {
    hist.cpu.push(loadPct);
    hist.mem.push(memPct);
    if (hist.cpu.length > 30) hist.cpu.shift();
    if (hist.mem.length > 30) hist.mem.shift();
  }
  let planHtml = "";
  (p.plans || []).forEach((pl) => {
    const pp =
        pl.tasks_total > 0
          ? Math.round((100 * pl.tasks_done) / pl.tasks_total)
          : 0,
      bar = pl.status === "doing" ? "var(--cyan)" : "var(--text-dim)";
    const tasks = pl.active_tasks || [],
      shown = tasks.slice(0, 3),
      extra = tasks.length - 3;
    planHtml += `<div class="mn-plan" onclick="event.stopPropagation();openPlanSidebar(${pl.id})"><div class="mn-plan-head"><span class="mn-plan-id">#${pl.id}</span> ${esc((pl.name || "").substring(0, 18))}</div><div class="mn-plan-bar"><div class="mn-plan-fill" style="width:${pp}%;background:${bar}"></div></div>${shown.map((t) => `<div class="mn-task">${statusDot(t.status)} ${esc((t.title || "").substring(0, 22))}</div>`).join("")}${extra > 0 ? `<div class="mn-task" style="color:var(--text-dim);font-style:italic">+ ${extra} more tasks</div>` : ""}</div>`;
  });
  const a = (act, ttl, svg) =>
    `<button class="mn-act-btn" data-peer="${esc(p.peer_name)}" data-action="${act}" title="${ttl}"><svg viewBox="0 0 16 16" width="14" height="14">${svg}</svg></button>`;
  const actions = p.is_online
    ? `<div class="mn-actions">${a("terminal", "Terminal", '<rect x="2" y="3" width="12" height="10" rx="1.5"/><path d="M4.5 7l2 1.5-2 1.5M8 10.5h3"/>')}${a("sync", "Sync", '<path d="M1.5 8a6.5 6.5 0 0112.4-2.5M14.5 8a6.5 6.5 0 01-12.4 2.5"/><path d="M13 2.5v3h-3M3 13.5v-3h3"/>')}${a("heartbeat", "Heartbeat", '<path d="M2 8h2l1.5-3 2 6 2-4.5 1.5 1.5h3"/>')}${a("auth", "Auth", '<rect x="4" y="7" width="8" height="6" rx="1"/><path d="M6 7V5a2 2 0 014 0v2"/><circle cx="8" cy="10" r="0.5"/>')}${a("status", "Status", '<circle cx="8" cy="8" r="5.5"/><path d="M8 5v3.5l2.5 1.5"/>')}${a("movehere", "Move Here", '<path d="M3 8h10M10 5l3 3-3 3"/>')}${a("reboot", "Reboot", '<path d="M8 2v4M4.5 4.2A5.5 5.5 0 108 2.5"/>')}</div>`
    : `<div class="mn-actions">${a("wake", "Wake (WoL)", '<circle cx="8" cy="8" r="5.5" fill="none"/><path d="M8 5v3M8 10v0.5"/>')}</div>`;
  return `<div class="${cls}" data-peer="${esc(p.peer_name)}"><div class="mn-top"><span class="mn-os">${OS_ICON[p.os] || OS_ICON.unknown}</span><span class="mn-name">${esc(p.peer_name)}</span><span class="mn-dot ${p.is_online ? "on" : "off"}"></span></div><div class="mn-role">${p.role.toUpperCase()}${p.is_local ? " · LOCAL" : ""}</div><div class="mn-caps">${caps.map((c) => `<span class="mn-cap${c === "ollama" ? " accent" : ""}">${c}</span>`).join("")}</div>${p.is_online ? `<div class="mn-stats">${p.active_tasks} tasks · CPU ${Math.round(p.cpu)}%${memTotal > 0 ? ` · RAM ${memUsed.toFixed(1)}/${memTotal.toFixed(0)}GB` : ""}</div><div class="mn-gauges"><div class="mn-gauge-group"><span class="mn-gauge-label">CPU</span><canvas id="spark-cpu-${peerKey}" class="mn-sparkline" width="120" height="28" data-history="${hist.cpu.join(",")}" data-color="${loadColor}" data-pct="${loadPct}"></canvas><span class="mn-gauge-val" style="color:${loadColor}">${Math.round(loadPct)}%</span></div>${memTotal > 0 ? `<div class="mn-gauge-group"><span class="mn-gauge-label">RAM</span><canvas id="spark-mem-${peerKey}" class="mn-sparkline" width="120" height="28" data-history="${hist.mem.join(",")}" data-color="${memColor}" data-pct="${memPct}"></canvas><span class="mn-gauge-val" style="color:${memColor}">${memPct}%</span></div>` : ""}</div>` : '<div class="mn-stats offline-text">No heartbeat</div>'}${planHtml}${actions}</div>`;
}
function _drawSparklines() {
  document.querySelectorAll(".mn-sparkline").forEach((c) => {
    const ctx = c.getContext("2d");
    if (!ctx) return;
    const w = c.width, h = c.height,
      data = (c.dataset.history || "").split(",").map(Number).filter((v) => !isNaN(v)),
      color = c.dataset.color || "var(--cyan)",
      pct = parseFloat(c.dataset.pct) || 0;
    ctx.clearRect(0, 0, w, h);
    if (data.length < 2) {
      // Single bar fallback
      const rgb = pct < 50 ? "0,204,106" : pct < 80 ? "230,161,23" : "238,51,68";
      ctx.fillStyle = `rgba(${rgb},0.3)`;
      ctx.fillRect(0, h - (pct / 100) * h, w, (pct / 100) * h);
      ctx.fillStyle = `rgba(${rgb},0.8)`;
      ctx.fillRect(w - 3, h - (pct / 100) * h, 3, (pct / 100) * h);
      return;
    }
    const max = 100, step = w / (data.length - 1);
    // Fill gradient under the line
    const grad = ctx.createLinearGradient(0, 0, 0, h);
    const rgb = pct < 50 ? "0,204,106" : pct < 80 ? "230,161,23" : "238,51,68";
    grad.addColorStop(0, `rgba(${rgb},0.25)`);
    grad.addColorStop(1, `rgba(${rgb},0.02)`);
    ctx.beginPath();
    ctx.moveTo(0, h);
    data.forEach((v, i) => ctx.lineTo(i * step, h - (v / max) * h));
    ctx.lineTo((data.length - 1) * step, h);
    ctx.closePath();
    ctx.fillStyle = grad;
    ctx.fill();
    // Line
    ctx.beginPath();
    data.forEach((v, i) => {
      const x = i * step, y = h - (v / max) * h;
      i === 0 ? ctx.moveTo(x, y) : ctx.lineTo(x, y);
    });
    ctx.strokeStyle = `rgba(${rgb},0.9)`;
    ctx.lineWidth = 1.5;
    ctx.stroke();
    // Current value dot
    const lastX = (data.length - 1) * step, lastY = h - (data[data.length - 1] / max) * h;
    ctx.beginPath();
    ctx.arc(lastX, lastY, 2.5, 0, Math.PI * 2);
    ctx.fillStyle = `rgba(${rgb},1)`;
    ctx.fill();
  });
}
function _drawSpokes() {
  const c = document.getElementById("mesh-spokes");
  if (!c) return;
  const wr = c.previousElementSibling,
    cr = c.nextElementSibling,
    cn = cr && cr.querySelector(".mesh-node"),
    wn = wr && wr.querySelectorAll(".mesh-node");
  if (!cn || !wn || !wn.length) return;
  const hub = c.parentElement.getBoundingClientRect(),
    r = cn.getBoundingClientRect(),
    cx = r.left + r.width / 2 - hub.left,
    h = c.offsetHeight || 32;
  let svg = `<svg width="100%" height="${h}" style="position:absolute;top:0;left:0;overflow:visible"><defs><filter id="glow"><feGaussianBlur stdDeviation="2" result="blur"/><feMerge><feMergeNode in="blur"/><feMergeNode in="SourceGraphic"/></feMerge></filter></defs>`;
  wn.forEach((w, i) => {
    const wr = w.getBoundingClientRect(),
      wx = wr.left + wr.width / 2 - hub.left,
      on = w.classList.contains("online"),
      color = on ? "#00e5ff" : "#1a2040",
      op = on ? "0.35" : "0.12",
      pid = `spoke-${i}`;
    svg += `<line x1="${wx}" y1="0" x2="${cx}" y2="${h}" stroke="${color}" stroke-width="1.5" opacity="${op}" stroke-dasharray="${on ? "none" : "3,4"}"/>`;
    if (on) {
      svg += `<path id="${pid}" d="M${wx},0 L${cx},${h}" fill="none"/><circle r="2.5" fill="#00e5ff" filter="url(#glow)" opacity="0.9"><animateMotion dur="${1.5 + i * 0.3}s" repeatCount="indefinite"><mpath href="#${pid}"/></animateMotion></circle><circle r="2" fill="#ff2daa" filter="url(#glow)" opacity="0.7"><animateMotion dur="${2 + i * 0.2}s" repeatCount="indefinite" keyPoints="1;0" keyTimes="0;1" calcMode="linear"><mpath href="#${pid}"/></animateMotion></circle>`;
    }
  });
  c.innerHTML = svg + "</svg>";
}
function renderMeshStrip(peers) {
  const el = $("#mesh-strip");
  if (!el || !peers || !peers.length) {
    if (el) el.innerHTML = "";
    return;
  }
  window.DashboardState.lastMeshData = peers;
  const online = peers.filter((p) => p.is_online).length,
    coord = peers.find((p) => p.role === "coordinator"),
    workers = peers.filter((p) => p.role !== "coordinator"),
    actionsBar = `<div class="mesh-actions-inline"><span class="mesh-count">${online}/${peers.length} online</span><button class="widget-action-btn" data-action="fullsync" data-peer="__all__" onclick="meshAction('fullsync','__all__')" title="Bidirectional sync all repos + config"><svg viewBox="0 0 16 16" width="12" height="12"><path d="M1.5 8a6.5 6.5 0 0112.4-2.5M14.5 8a6.5 6.5 0 01-12.4 2.5"/><path d="M13 2.5v3h-3M3 13.5v-3h3"/></svg> Full Sync</button><button class="widget-action-btn" data-action="sync" data-peer="__all__" onclick="meshAction('sync','__all__')" title="Push config to all peers"><svg viewBox="0 0 16 16" width="12" height="12"><path d="M8 2v12M2 8l6-6 6 6"/></svg> Push</button></div>`;
  const bar = $("#mesh-actions-bar");
  if (bar) bar.innerHTML = "";
  if (coord && workers.length) {
    el.innerHTML = `<div class="mesh-hub"><div class="mesh-hub-workers">${workers.map(_meshNodeHtml).join("")}</div><div class="mesh-hub-spokes" id="mesh-spokes"></div><div class="mesh-hub-coord">${_meshNodeHtml(coord)}</div></div>${actionsBar}`;
  } else
    el.innerHTML = `<div class="mesh-nodes">${peers.map(_meshNodeHtml).join("")}</div>${actionsBar}`;
  requestAnimationFrame(() => { _drawSpokes(); _drawSparklines(); });
}
function applyMeshSyncBadges(items) {
  if (!items || !items.length) return;
  items.forEach((s) => {
    const n = document.querySelector(`.mesh-node[data-peer="${CSS.escape(s.peer_name)}"]`);
    if (!n) return;
    const [cls, title] = !s.reachable
        ? ["mn-sync-red", "Unreachable"]
        : s.config_synced
          ? ["mn-sync-green", "In sync"]
          : ["mn-sync-yellow", "Out of sync"],
      b = document.createElement("span");
    b.className = `mn-sync-dot ${cls}`;
    b.title = title;
    n.querySelector(".mn-top").appendChild(b);
  });
}
function showToast(title, msg, link, type) {
  let c = document.getElementById("toast-container");
  if (!c) { c = document.createElement("div"); c.id = "toast-container"; document.body.appendChild(c); }
  const t = document.createElement("div");
  t.className = `toast toast-${type || "info"}`;
  t.innerHTML = `<div class="toast-title">${esc(title)}</div><div class="toast-msg">${esc(msg || "")}</div>`;
  if (link) t.style.cursor = "pointer";
  t.addEventListener("click", () => { if (link) location.hash = link.replace(/.*#/, "#"); t.remove(); });
  c.appendChild(t);
  setTimeout(() => t.remove(), 8000);
}
async function pollNotifications() {
  const data = await fetchJson("/api/notifications").catch(() => null);
  if (!data || !data.length) return;
  const st = window.DashboardState;
  data.forEach((n) => {
    if (n.id > st.notifLastId) {
      st.notifLastId = n.id;
      showToast(n.title, n.message, n.link, n.type);
    }
  });
}
let ws = null,
  wsRetry = 0,
  wsT = null;
function wsUrl() {
  if (window.DASHBOARD_WS_URL) return window.DASHBOARD_WS_URL;
  const p = location.protocol === "https:" ? "wss" : "ws";
  return `${p}://${location.host}/ws/dashboard`;
}
function scheduleReconnect() {
  clearTimeout(wsT);
  wsT = setTimeout(
    connectDashboardWs,
    Math.min(30000, 1000 * Math.pow(2, wsRetry++)),
  );
}
function connectDashboardWs() {
  try {
    ws = new WebSocket(wsUrl());
  } catch {
    return scheduleReconnect();
  }
  ws.onopen = () => {
    wsRetry = 0;
  };
  ws.onmessage = (e) => {
    let m = null;
    try {
      m = JSON.parse(e.data);
    } catch {}
    if (!m) return;
    if (m.type === "notification")
      showToast(m.title, m.message, m.link, m.level || m.type);
    if (m.type === "refresh" && typeof refreshAll === "function") refreshAll();
    if (m.type === "mesh_sync" && typeof applyMeshSyncBadges === "function")
      applyMeshSyncBadges(m.items || []);
  };
  ws.onclose = scheduleReconnect;
  ws.onerror = () => ws && ws.close();
}
function initDashboardWebSocket() {
  connectDashboardWs();
  setInterval(pollNotifications, 30000);
}
window.renderMeshStrip = renderMeshStrip;
window.applyMeshSyncBadges = applyMeshSyncBadges;
window.showToast = showToast;
window.initDashboardWebSocket = initDashboardWebSocket;
