const _SVG = (p) =>
  `<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" width="100%" height="100%" fill="currentColor">${p}</svg>`;
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
  // Get brain-aligned color for this node
  const mc = (typeof brainMeshColor === 'function') ? brainMeshColor(p.peer_name) : null;
  const nodeCol = mc ? mc.core : null;
  const nodeGlow = mc ? mc.glow : null;
  const borderStyle = (p.is_online && nodeCol)
    ? `border-color:${nodeCol};box-shadow:0 0 14px ${nodeGlow}0.15);`
    : '';
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
  return `<div class="${cls}" data-peer="${esc(p.peer_name)}" style="${borderStyle}"><div class="mn-top"><span class="mn-os">${OS_ICON[p.os] || OS_ICON.unknown}</span><span class="mn-name"${nodeCol ? ` style="color:${nodeCol}"` : ''}>${esc(p.peer_name)}</span><span class="mn-dot ${p.is_online ? "on" : "off"}"${nodeCol ? ` style="background:${nodeCol};box-shadow:0 0 6px ${nodeCol}"` : ''}></span></div><div class="mn-role"${nodeCol ? ` style="color:${nodeCol}"` : ''}>${p.role.toUpperCase()}${p.is_local ? " · LOCAL" : ""}</div><div class="mn-caps">${caps.map((c) => `<span class="mn-cap${c === "ollama" ? " accent" : ""}">${c}</span>`).join("")}</div>${p.is_online ? `<div class="mn-stats">${p.active_tasks} tasks · CPU ${Math.round(p.cpu)}%${memTotal > 0 ? ` · RAM ${memUsed.toFixed(1)}/${memTotal.toFixed(0)}GB` : ""}</div><div class="mn-gauges"><div class="mn-gauge-group"><span class="mn-gauge-label">CPU</span><canvas id="spark-cpu-${peerKey}" class="mn-sparkline" height="28" style="width:100%" data-history="${hist.cpu.join(",")}" data-color="${loadColor}" data-pct="${loadPct}"></canvas><span class="mn-gauge-val" style="color:${loadColor}">${Math.round(loadPct)}%</span></div>${memTotal > 0 ? `<div class="mn-gauge-group"><span class="mn-gauge-label">RAM</span><canvas id="spark-mem-${peerKey}" class="mn-sparkline" height="28" style="width:100%" data-history="${hist.mem.join(",")}" data-color="${memColor}" data-pct="${memPct}"></canvas><span class="mn-gauge-val" style="color:${memColor}">${memPct}%</span></div>` : ""}</div>` : '<div class="mn-stats offline-text">No heartbeat</div>'}${planHtml}${actions}</div>`;
}
function _drawSparklines() {
  document.querySelectorAll(".mn-sparkline").forEach((c) => {
    const ctx = c.getContext("2d");
    if (!ctx) return;
    // Set canvas pixel width from CSS rendered width
    const rect = c.getBoundingClientRect();
    if (rect.width > 0) c.width = Math.round(rect.width);
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
  // Sort peers deterministically: coordinator first, then alphabetical
  peers.sort((a, b) => {
    if (a.role === 'coordinator' && b.role !== 'coordinator') return -1;
    if (b.role === 'coordinator' && a.role !== 'coordinator') return 1;
    return a.peer_name.localeCompare(b.peer_name);
  });
  window.DashboardState.lastMeshData = peers;
  const online = peers.filter((p) => p.is_online).length;
  const coord = peers.find((p) => p.role === "coordinator");
  const workers = peers.filter((p) => p.role !== "coordinator");
  // Update count in header
  const countEl = document.getElementById('mesh-online-count');
  if (countEl) countEl.textContent = `${online}/${peers.length} online`;
  const bar = $("#mesh-actions-bar");
  if (bar) bar.innerHTML = "";
  if (coord && workers.length) {
    const left = workers.slice(0, Math.ceil(workers.length / 2));
    const right = workers.slice(Math.ceil(workers.length / 2));
    el.innerHTML = `<div class="mesh-hub">${left.map(_meshNodeHtml).join("")}<div class="mesh-hub-coord">${_meshNodeHtml(coord)}</div>${right.map(_meshNodeHtml).join("")}<canvas class="mesh-flow-canvas" id="mesh-flow-cvs"></canvas></div>`;
  } else
    el.innerHTML = `<div class="mesh-nodes">${peers.map(_meshNodeHtml).join("")}</div>`;
  requestAnimationFrame(() => { _drawSpokes(); _drawSparklines(); _initMeshFlow(); });
}
// Mesh flow animation — real-time via daemon WebSocket + network byte counters
let _meshFlowRAF = 0;
const _meshFlowParticles = [];
let _meshDaemonWs = null;
let _meshPrevNetBytes = {};  // {peer: {rx, tx}} for delta calculation
function _initMeshFlow() {
  const cvs = document.getElementById('mesh-flow-cvs');
  if (!cvs) { console.warn('[mesh-flow] no canvas'); return; }
  const hub = cvs.parentElement;
  if (!hub) return;
  cvs.width = hub.offsetWidth; cvs.height = hub.offsetHeight;
  console.log('[mesh-flow] canvas', cvs.width, 'x', cvs.height);
  const ctx = cvs.getContext('2d');
  const nodes = hub.querySelectorAll('.mesh-node');
  console.log('[mesh-flow] nodes found:', nodes.length);
  if (nodes.length < 2) return;
  function nodeCenter(el) {
    const r = el.getBoundingClientRect(), hr = hub.getBoundingClientRect();
    return {
      x: r.left - hr.left + r.width / 2,
      left: r.left - hr.left,
      right: r.left - hr.left + r.width,
      cy: r.top - hr.top + r.height * 0.5,
      top: r.top - hr.top,
      bottom: r.top - hr.top + r.height,
      name: el.dataset.peer
    };
  }
  let centers = Array.from(nodes).map(nodeCenter);
  console.log('[mesh-flow] centers:', JSON.stringify(centers.map(c => ({name:c.name, x:Math.round(c.x), cy:Math.round(c.cy)}))));
  const nodeMap = {};
  centers.forEach(c => { nodeMap[c.name] = c; });
  const pairs = [];
  for (let i = 0; i < centers.length; i++)
    for (let j = i + 1; j < centers.length; j++)
      pairs.push([centers[i], centers[j]]);
  console.log('[mesh-flow] pairs:', pairs.length);
  _meshFlowParticles.length = 0;

  // Particle colors by event type
  const eventColors = {
    heartbeat:  { core: 'rgba(0,229,255,0.7)',  glow: 'rgba(0,229,255,0.3)' },
    sync_delta: { core: 'rgba(0,255,128,0.8)',   glow: 'rgba(0,255,128,0.3)' },
    sync_ack:   { core: 'rgba(255,200,0,0.8)',   glow: 'rgba(255,200,0,0.3)' },
    auth_ok:    { core: 'rgba(180,100,255,0.8)',  glow: 'rgba(180,100,255,0.3)' },
    net_burst:  { core: 'rgba(255,80,80,0.7)',    glow: 'rgba(255,80,80,0.3)' },
  };

  function spawnBetween(fromName, toName, count, eventType) {
    const from = nodeMap[fromName], to = nodeMap[toName];
    if (!from || !to) return;
    const mc = (typeof brainMeshColor === 'function') ? brainMeshColor(fromName) : null;
    const ec = eventColors[eventType] || eventColors.heartbeat;
    const n = Math.min(count, 12);
    // Two lanes: TX flows on upper path, RX on lower path
    const goingRight = from.x < to.x;
    const laneOffset = 12; // px offset from center line
    for (let k = 0; k < n; k++) {
      const fromEdge = goingRight ? from.right : from.left;
      const toEdge = goingRight ? to.left : to.right;
      const fy = from.cy - laneOffset;
      const ty = to.cy - laneOffset;
      const midX = (fromEdge + toEdge) / 2;
      const midY = (fy + ty) / 2 + (Math.random() - 0.5) * 6;
      const dataScale = eventType === 'sync_delta' ? 1.5 : 0.8;
      _meshFlowParticles.push({
        sx: fromEdge, sy: fy + (Math.random() - 0.5) * 4,
        tx: toEdge, ty: ty + (Math.random() - 0.5) * 4,
        cx: midX, cy: midY,
        progress: -k * 0.04,
        speed: 0.010 + Math.random() * 0.012,
        color: mc ? mc.core : ec.core,
        size: (3 + Math.random() * 3) * dataScale,
        trail: []
      });
    }
  }

  // Resolve node name from daemon event (may be IP or hostname)
  function resolveNode(raw) {
    if (nodeMap[raw]) return raw;
    // Try hostToPeer mapping from app state
    if (typeof state !== 'undefined' && state.hostToPeer) {
      const mapped = state.hostToPeer[raw] || state.hostToPeer[raw.replace(':9420','')];
      if (mapped && nodeMap[mapped]) return mapped;
    }
    // Fuzzy match
    for (const name of Object.keys(nodeMap)) {
      if (raw.includes(name) || name.includes(raw.replace(':9420',''))) return name;
    }
    return null;
  }

  // Connect to daemon WebSocket for real-time mesh events
  function connectDaemonWs() {
    const wsUrl = (typeof state !== 'undefined' && state.daemonWsUrl) || null;
    if (!wsUrl) {
      // Fallback: poll /api/mesh/traffic every 5s
      _startTrafficPolling();
      return;
    }
    _stopTrafficPolling();
    if (_meshDaemonWs) { _meshDaemonWs.onclose = null; _meshDaemonWs.close(); }
    try {
      _meshDaemonWs = new WebSocket(wsUrl);
    } catch { _startTrafficPolling(); return; }
    const localNode = (typeof state !== 'undefined' && state.localPeerName) || '';
    _meshDaemonWs.onmessage = (e) => {
      let msg;
      try { msg = JSON.parse(e.data); } catch { return; }
      const kind = msg.kind || '';
      const sourceNode = resolveNode(msg.node || '');
      if (!sourceNode) return;
      // Refresh node positions on each event (cheap)
      const fresh = hub.querySelectorAll('.mesh-node');
      if (fresh.length >= 2) {
        Array.from(fresh).forEach(el => { nodeMap[el.dataset.peer] = nodeCenter(el); });
      }
      if (kind === 'heartbeat' && localNode && sourceNode !== localNode) {
        spawnBetween(sourceNode, localNode, 1, 'heartbeat');
      } else if (kind === 'sync_delta') {
        const count = Math.ceil(Math.min((msg.payload?.received || 1), 50) / 5);
        if (localNode) spawnBetween(sourceNode, localNode, count, 'sync_delta');
      } else if (kind === 'sync_ack') {
        if (localNode) spawnBetween(localNode, sourceNode, 1, 'sync_ack');
      } else if (kind === 'auth_ok') {
        if (localNode) spawnBetween(sourceNode, localNode, 1, 'auth_ok');
      } else if (kind === 'agent_heartbeat') {
        if (localNode && sourceNode !== localNode)
          spawnBetween(sourceNode, localNode, 1, 'heartbeat');
      }
    };
    _meshDaemonWs.onclose = () => { setTimeout(connectDaemonWs, 5000); };
    _meshDaemonWs.onerror = () => { _meshDaemonWs.close(); };
  }

  // Fallback: poll /api/mesh/traffic for sync counters
  let _trafficPollTimer = null;
  let _trafficPrev = {};
  function _startTrafficPolling() {
    const localNode = (typeof state !== 'undefined' && state.localPeerName) || '';
    async function poll() {
      if (!document.getElementById('mesh-flow-cvs')) return;
      try {
        const r = await fetch('/api/mesh/traffic');
        const d = await r.json();
        if (!d.ok) return;
        const ln = d.local_node || localNode;
        const fresh = hub.querySelectorAll('.mesh-node');
        if (fresh.length >= 2) {
          Array.from(fresh).forEach(el => { nodeMap[el.dataset.peer] = nodeCenter(el); });
        }
        (d.sync_peers || []).forEach(p => {
          const prev = _trafficPrev[p.peer] || { sent: 0, recv: 0 };
          const dS = Math.max(0, p.total_sent - prev.sent);
          const dR = Math.max(0, p.total_received - prev.recv);
          _trafficPrev[p.peer] = { sent: p.total_sent, recv: p.total_received };
          if (prev.sent === 0) return;
          if (dS > 0 && ln) spawnBetween(ln, p.peer, Math.ceil(Math.min(dS,200)/25), 'sync_delta');
          if (dR > 0 && ln) spawnBetween(p.peer, ln, Math.ceil(Math.min(dR,200)/25), 'sync_delta');
        });
      } catch { /* silent */ }
    }
    poll();
    if (window.PollScheduler) {
      window.PollScheduler.register('websocket.meshTraffic', poll, 5000, ['overview', 'brain']);
    } else if (!_trafficPollTimer) {
      _trafficPollTimer = setInterval(poll, 5000);
    }
  }

  function _stopTrafficPolling() {
    if (window.PollScheduler) {
      window.PollScheduler.unregister('websocket.meshTraffic');
      return;
    }
    if (_trafficPollTimer) {
      clearInterval(_trafficPollTimer);
      _trafficPollTimer = null;
    }
  }

  // Delayed connect: wait for state.daemonWsUrl to be populated from /api/mesh
  setTimeout(connectDaemonWs, 2000);

  if (_meshFlowRAF) cancelAnimationFrame(_meshFlowRAF);
  function animate(ts) {
    if (!document.getElementById('mesh-flow-cvs')) {
      _stopTrafficPolling();
      if (_meshDaemonWs) { _meshDaemonWs.onclose = null; _meshDaemonWs.close(); }
      return;
    }
    if (document.hidden) { _meshFlowRAF = requestAnimationFrame(animate); return; }
    if (cvs.width !== hub.offsetWidth || cvs.height !== hub.offsetHeight) {
      cvs.width = hub.offsetWidth; cvs.height = hub.offsetHeight;
    }
    ctx.clearRect(0, 0, cvs.width, cvs.height);
    const laneOff = 12;
    // Draw two-lane connection lines between adjacent pairs
    pairs.forEach(([a, b]) => {
      const mc = (typeof brainMeshColor === 'function') ? brainMeshColor(a.name) : null;
      const col = mc ? mc.core : 'rgba(0,229,255,0.25)';
      const leftNode = a.x < b.x ? a : b;
      const rightNode = a.x < b.x ? b : a;
      const x1 = leftNode.right, x2 = rightNode.left;
      // Upper lane (TX)
      ctx.globalAlpha = 1;
      ctx.strokeStyle = col;
      ctx.lineWidth = 1;
      ctx.setLineDash([3, 5]);
      ctx.beginPath();
      ctx.moveTo(x1, leftNode.cy - laneOff);
      ctx.lineTo(x2, rightNode.cy - laneOff);
      ctx.stroke();
      // Lower lane (RX)
      ctx.beginPath();
      ctx.moveTo(x1, leftNode.cy + laneOff);
      ctx.lineTo(x2, rightNode.cy + laneOff);
      ctx.stroke();
    });
    ctx.setLineDash([]);

    // Draw particles with direction-showing comet tails + arrowheads
    while (_meshFlowParticles.length > 120) _meshFlowParticles.shift();
    for (let i = _meshFlowParticles.length - 1; i >= 0; i--) {
      const p = _meshFlowParticles[i];
      p.progress += p.speed;
      if (p.progress < 0) continue;
      const t2 = Math.min(p.progress, 1), it = 1 - t2;
      p.x = it * it * p.sx + 2 * it * t2 * p.cx + t2 * t2 * p.tx;
      p.y = it * it * p.sy + 2 * it * t2 * p.cy + t2 * t2 * p.ty;
      p.trail.push({ x: p.x, y: p.y });
      if (p.trail.length > 16) p.trail.shift();

      // Comet tail — long fading trail showing direction
      if (p.trail.length > 1) {
        ctx.lineCap = 'round';
        for (let t = 1; t < p.trail.length; t++) {
          const frac = t / p.trail.length;
          ctx.globalAlpha = frac * 0.7;
          ctx.strokeStyle = p.color;
          ctx.lineWidth = p.size * frac * 1.8;
          ctx.beginPath();
          ctx.moveTo(p.trail[t - 1].x, p.trail[t - 1].y);
          ctx.lineTo(p.trail[t].x, p.trail[t].y);
          ctx.stroke();
        }
      }

      // Outer glow halo
      ctx.globalAlpha = 0.5;
      ctx.fillStyle = p.color;
      ctx.beginPath(); ctx.arc(p.x, p.y, p.size * 3.5, 0, Math.PI * 2); ctx.fill();

      // Bright core
      ctx.globalAlpha = 1;
      ctx.fillStyle = '#fff';
      ctx.beginPath(); ctx.arc(p.x, p.y, p.size * 0.8, 0, Math.PI * 2); ctx.fill();

      // Colored ring
      ctx.fillStyle = p.color;
      ctx.beginPath(); ctx.arc(p.x, p.y, p.size * 1.2, 0, Math.PI * 2); ctx.fill();

      // Direction arrowhead at particle head
      if (p.trail.length > 2) {
        const prev = p.trail[p.trail.length - 2];
        const angle = Math.atan2(p.y - prev.y, p.x - prev.x);
        const arrLen = p.size * 3;
        ctx.globalAlpha = 0.9;
        ctx.fillStyle = p.color;
        ctx.beginPath();
        ctx.moveTo(p.x + Math.cos(angle) * arrLen, p.y + Math.sin(angle) * arrLen);
        ctx.lineTo(p.x + Math.cos(angle + 2.5) * arrLen * 0.6, p.y + Math.sin(angle + 2.5) * arrLen * 0.6);
        ctx.lineTo(p.x + Math.cos(angle - 2.5) * arrLen * 0.6, p.y + Math.sin(angle - 2.5) * arrLen * 0.6);
        ctx.closePath();
        ctx.fill();
      }

      ctx.globalAlpha = 1;
      if (p.progress >= 1) _meshFlowParticles.splice(i, 1);
    }
    _meshFlowRAF = requestAnimationFrame(animate);
  }
  _meshFlowRAF = requestAnimationFrame(animate);
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
  if (!st.notifLastId) {
    st.notifLastId = Math.max(...data.map(n => n.id));
    return;
  }
  data.forEach((n) => {
    if (n.id > st.notifLastId && !n.is_read) {
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
  if (ws) { ws.onclose = null; ws.onerror = null; ws.close(); ws = null; }
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
  if (window.PollScheduler) {
    window.PollScheduler.register('websocket.notifications', pollNotifications, 30000, ['all']);
  } else {
    setInterval(pollNotifications, 30000);
  }
}
window.renderMeshStrip = renderMeshStrip;
window.applyMeshSyncBadges = applyMeshSyncBadges;
window.showToast = showToast;
window.initDashboardWebSocket = initDashboardWebSocket;
