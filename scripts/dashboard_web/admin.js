const adminState = {
  timer: null,
  active: false,
  refreshMs: 5000,
  logLevel: "ALL",
};

function escAdmin(value) {
  return String(value ?? "")
    .replaceAll("&", "&amp;")
    .replaceAll("<", "&lt;")
    .replaceAll(">", "&gt;")
    .replaceAll('"', "&quot;");
}

function statusBadge(online) {
  return `<span class="admin-status ${online ? "online" : "offline"}">${online ? "●" : "○"} ${online ? "online" : "offline"}</span>`;
}

function normalizeLogs(logPayload) {
  const logs = Array.isArray(logPayload) ? logPayload : (logPayload?.logs || logPayload?.items || []);
  return logs.map((entry) => ({
    timestamp: entry.timestamp || entry.ts || entry.time || "-",
    level: String(entry.level || "INFO").toUpperCase(),
    target: entry.target || entry.module || "-",
    message: entry.message || entry.msg || "",
    node: entry.node || entry.peer || "-",
  }));
}

async function refreshAdminNodes() {
  const raw = await fetchJson("/api/mesh");
  const peers = Array.isArray(raw) ? raw : (raw && raw.peers) || [];
  const container = document.getElementById("admin-node-content");
  const summary = document.getElementById("admin-node-summary");
  if (!peers.length || !container) return;

  const onlineCount = peers.filter((p) => p.is_online).length;
  if (summary) summary.textContent = `${onlineCount}/${peers.length} nodes in mesh`;

  const rows = peers.map((p) => {
    const name = p.peer_name || "unknown";
    const ip = p.tailscale_ip || "n/a";
    const caps = typeof p.capabilities === "string" ? p.capabilities : (Array.isArray(p.capabilities) ? p.capabilities.join(", ") : "");
    const cpu = typeof p.cpu === "number" ? `${Math.round(p.cpu)}%` : "-";
    const memUsed = p.mem_used_gb || 0;
    const memTotal = p.mem_total_gb || 0;
    const mem = memTotal > 0 ? `${memUsed.toFixed(1)}/${memTotal.toFixed(0)} GB` : "-";
    return `<tr>
      <td><strong>${escAdmin(name)}</strong>${p.is_local ? ' <span class="admin-local-badge">LOCAL</span>' : ""}</td>
      <td>${escAdmin(ip)}</td>
      <td>${escAdmin(p.os || "unknown")}</td>
      <td>${escAdmin(p.role || "worker")}</td>
      <td>${escAdmin(caps)}</td>
      <td>${cpu}</td>
      <td>${mem}</td>
      <td>${statusBadge(p.is_online)}</td>
      <td><button class="admin-btn-sm admin-btn-danger" onclick="removeNode('${escAdmin(name)}')" title="Remove from mesh">✕</button></td>
    </tr>`;
  });

  container.innerHTML = `<table class="admin-table">
    <thead><tr><th>Name</th><th>Tailscale IP</th><th>OS</th><th>Role</th><th>Capabilities</th><th>CPU</th><th>RAM</th><th>Status</th><th></th></tr></thead>
    <tbody>${rows.join("")}</tbody>
  </table>
  <div class="admin-node-actions">
    <button class="admin-btn" onclick="showAddNodeForm()">+ Add Node</button>
  </div>
  <div id="add-node-form" style="display:none" class="admin-add-form">
    <h4>Add Node to Mesh</h4>
    <p class="admin-hint">The node must be on Tailscale and have the Convergio daemon installed.</p>
    <label>Node name <input id="add-node-name" placeholder="e.g. gpu-server" /></label>
    <label>Tailscale IP <input id="add-node-ip" placeholder="100.x.x.x" /></label>
    <label>OS <select id="add-node-os"><option>linux</option><option>macos</option></select></label>
    <label>Role <select id="add-node-role"><option>worker</option><option>coordinator</option></select></label>
    <label>Capabilities <input id="add-node-caps" placeholder="claude,copilot" value="claude,copilot" /></label>
    <label>SSH alias <input id="add-node-ssh" placeholder="e.g. gpu-server-ts" /></label>
    <div class="admin-form-actions">
      <button class="admin-btn" onclick="addNode()">Add to Mesh</button>
      <button class="admin-btn-secondary" onclick="hideAddNodeForm()">Cancel</button>
    </div>
  </div>`;
}

function showAddNodeForm() {
  const form = document.getElementById("add-node-form");
  if (form) form.style.display = "block";
}
function hideAddNodeForm() {
  const form = document.getElementById("add-node-form");
  if (form) form.style.display = "none";
}

async function addNode() {
  const name = document.getElementById("add-node-name")?.value?.trim();
  const ip = document.getElementById("add-node-ip")?.value?.trim();
  const os = document.getElementById("add-node-os")?.value;
  const role = document.getElementById("add-node-role")?.value;
  const caps = document.getElementById("add-node-caps")?.value?.trim();
  const ssh = document.getElementById("add-node-ssh")?.value?.trim();
  if (!name || !ip) { alert("Name and Tailscale IP are required"); return; }
  const resp = await fetch("/api/mesh/action?action=add-node&peer=" + encodeURIComponent(name) +
    "&ip=" + encodeURIComponent(ip) + "&os=" + encodeURIComponent(os) +
    "&role=" + encodeURIComponent(role) + "&caps=" + encodeURIComponent(caps) +
    "&ssh=" + encodeURIComponent(ssh));
  const result = await resp.json();
  if (result.error) alert("Error: " + result.error);
  else { hideAddNodeForm(); refreshAdminNodes(); }
}

async function removeNode(name) {
  if (!confirm(`Remove "${name}" from the mesh? This will stop syncing with this node.`)) return;
  const resp = await fetch("/api/mesh/action?action=remove-node&peer=" + encodeURIComponent(name));
  const result = await resp.json();
  if (result.error) alert("Error: " + result.error);
  else refreshAdminNodes();
}

async function refreshAdminLogs() {
  const payload = await fetchJson("/api/mesh/logs");
  const logs = normalizeLogs(payload).filter((e) => adminState.logLevel === "ALL" || e.level === adminState.logLevel);
  const container = document.getElementById("admin-logs-content");
  if (!container) return;
  container.innerHTML = logs.length
    ? logs.map((e) => `<div class="admin-log-row level-${e.level}">
        <span class="log-ts">${escAdmin(e.timestamp)}</span>
        <span class="log-level">${escAdmin(e.level)}</span>
        <span class="log-target">${escAdmin(e.target)}</span>
        <span class="log-node">${escAdmin(e.node)}</span>
        <span class="log-msg">${escAdmin(e.message)}</span>
      </div>`).join("")
    : `<div class="admin-empty">No logs for selected level.</div>`;
}

async function refreshAdminMetrics() {
  const payload = await fetchJson("/api/mesh/metrics");
  const source = payload || {};
  const metrics = [
    { label: "Frames sent", value: source.frames_sent ?? 0 },
    { label: "Frames received", value: source.frames_received ?? 0 },
    { label: "Connections accepted", value: source.connections_accepted ?? 0 },
    { label: "Auth failures", value: source.auth_failures ?? 0 },
    { label: "Changes applied", value: source.changes_applied ?? 0 },
    { label: "Changes blocked", value: source.changes_blocked ?? 0 },
    { label: "Bytes sent", value: source.bytes_sent ?? 0 },
    { label: "Bytes received", value: source.bytes_received ?? 0 },
  ];
  const container = document.getElementById("admin-metrics-grid");
  if (!container) return;
  container.innerHTML = metrics
    .map((m) => `<div class="admin-metric-card">
      <div class="metric-label">${escAdmin(m.label)}</div>
      <div class="metric-value">${typeof m.value === "number" ? m.value.toLocaleString() : m.value}</div>
    </div>`)
    .join("");
}

async function refreshAdminTracing() {
  const payload = await fetchJson("/api/mesh/sync-stats");
  const container = document.getElementById("admin-tracing-content");
  if (!container) return;
  if (payload && payload.latency) {
    container.innerHTML = `<table class="admin-table">
      <thead><tr><th>Metric</th><th>Value</th><th>Target</th></tr></thead>
      <tbody>
        <tr><td>DB sync p50</td><td>${payload.latency.db_sync_p50_ms ?? 0} ms</td><td>&lt; 10 ms</td></tr>
        <tr><td>DB sync p99</td><td>${payload.latency.db_sync_p99_ms ?? 0} ms</td><td>&lt; 100 ms</td></tr>
      </tbody>
    </table>`;
  } else {
    container.innerHTML = `<div class="admin-empty">No sync stats available.</div>`;
  }
}

async function refreshAdminPanel() {
  if (!adminState.active) return;
  await Promise.allSettled([refreshAdminNodes(), refreshAdminLogs(), refreshAdminMetrics(), refreshAdminTracing()]);
}

function setAdminActive(isActive) {
  adminState.active = !!isActive;
  if (adminState.active) {
    refreshAdminPanel();
    if (!adminState.timer) adminState.timer = setInterval(refreshAdminPanel, adminState.refreshMs);
  } else if (adminState.timer) {
    clearInterval(adminState.timer);
    adminState.timer = null;
  }
}

function initAdminPanel() {
  const filter = document.getElementById("admin-log-level");
  if (filter) filter.addEventListener("change", () => {
    adminState.logLevel = filter.value || "ALL";
    refreshAdminLogs();
  });
}

window.initAdminPanel = initAdminPanel;
window.setAdminActive = setAdminActive;
