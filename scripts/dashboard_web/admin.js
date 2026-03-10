const adminState = {
  timer: null,
  active: false,
  refreshMs: 5000,
  logLevel: "ALL",
};

function asArray(payload, key = "") {
  if (Array.isArray(payload)) return payload;
  if (payload && key && Array.isArray(payload[key])) return payload[key];
  if (payload && Array.isArray(payload.items)) return payload.items;
  return [];
}

function escAdmin(value) {
  return String(value ?? "")
    .replaceAll("&", "&amp;")
    .replaceAll("<", "&lt;")
    .replaceAll(">", "&gt;")
    .replaceAll('"', "&quot;");
}

function statusBadge(online) {
  return `<span class="admin-status ${online ? "online" : "offline"}">${online ? "online" : "offline"}</span>`;
}

function extractPeerName(peer) {
  return peer.name || peer.peer_name || peer.id || peer.node || "unknown";
}

function extractPeerIp(peer) {
  return peer.ip || peer.tailscale_ip || peer.address || peer.addr || "n/a";
}

function peerOnline(peer, statusMap) {
  if (typeof peer.is_online === "boolean") return peer.is_online;
  if (typeof peer.online === "boolean") return peer.online;
  const mapped = statusMap[extractPeerName(peer)];
  if (typeof mapped?.is_online === "boolean") return mapped.is_online;
  if (typeof mapped?.online === "boolean") return mapped.online;
  if (typeof mapped?.status === "string") return mapped.status.toLowerCase() === "online";
  return false;
}

function normalizeLogs(logPayload) {
  const logs = asArray(logPayload, "logs");
  return logs.map((entry) => ({
    timestamp: entry.timestamp || entry.ts || entry.time || "-",
    level: String(entry.level || "INFO").toUpperCase(),
    target: entry.target || entry.module || entry.component || "-",
    message: entry.message || entry.msg || "",
    node: entry.node || entry.peer || entry.host || "-",
  }));
}

function normalizeMetrics(metricsPayload) {
  const source = metricsPayload || {};
  return [
    { label: "Frames sent", value: source.frames_sent ?? source.sent_frames ?? 0 },
    { label: "Frames received", value: source.frames_received ?? source.received_frames ?? 0 },
    { label: "Connections", value: source.connections ?? source.active_connections ?? 0 },
    { label: "Auth failures", value: source.auth_failures ?? source.failed_auth ?? 0 },
    { label: "Changes applied", value: source.changes_applied ?? source.applied ?? 0 },
    { label: "Changes blocked", value: source.changes_blocked ?? source.blocked ?? 0 },
  ];
}

function normalizeSyncStats(syncPayload) {
  const peers = asArray(syncPayload, "peers");
  return peers.map((entry) => ({
    peer: entry.peer || entry.name || entry.node || "unknown",
    total_sent: entry.total_sent ?? 0,
    total_received: entry.total_received ?? 0,
    total_applied: entry.total_applied ?? 0,
    latency: entry.latency ?? entry.latency_ms ?? "n/a",
    last_error: entry.last_error || "",
  }));
}

async function refreshAdminNodes() {
  const [peersPayload, statusPayload] = await Promise.all([
    fetchJson("/api/mesh/peers"),
    fetchJson("/api/mesh/status"),
  ]);
  const peers = asArray(peersPayload, "peers");
  const statusItems = asArray(statusPayload, "peers").concat(asArray(statusPayload, "nodes"));
  const statusMap = {};
  statusItems.forEach((item) => {
    statusMap[extractPeerName(item)] = item;
  });

  const rows = peers.map((peer) => {
    const online = peerOnline(peer, statusMap);
    return `
      <tr>
        <td>${escAdmin(extractPeerName(peer))}</td>
        <td>${escAdmin(extractPeerIp(peer))}</td>
        <td>${escAdmin(peer.os || peer.platform || "n/a")}</td>
        <td>${escAdmin(Array.isArray(peer.capabilities) ? peer.capabilities.join(", ") : (peer.capabilities || "n/a"))}</td>
        <td>${escAdmin(peer.role || peer.node_role || "worker")}</td>
        <td>${statusBadge(online)}</td>
      </tr>
    `;
  });

  const container = document.getElementById("admin-node-content");
  const summary = document.getElementById("admin-node-summary");
  if (summary) {
    const onlineCount = peers.filter((peer) => peerOnline(peer, statusMap)).length;
    summary.textContent = `${onlineCount}/${peers.length} online`;
  }
  if (!container) return;
  container.innerHTML = peers.length
    ? `<table class="admin-table"><thead><tr><th>Name</th><th>IP</th><th>OS</th><th>Capabilities</th><th>Role</th><th>Status</th></tr></thead><tbody>${rows.join("")}</tbody></table>`
    : `<div class="admin-empty">No peers returned by daemon.</div>`;
}

async function refreshAdminLogs() {
  const payload = await fetchJson("/api/mesh/logs");
  const logs = normalizeLogs(payload).filter((entry) => adminState.logLevel === "ALL" || entry.level === adminState.logLevel);
  const container = document.getElementById("admin-logs-content");
  if (!container) return;
  container.innerHTML = logs.length
    ? logs.map((entry) => `<div class="admin-log-row level-${entry.level}">
        <span class="log-ts">${escAdmin(entry.timestamp)}</span>
        <span class="log-level">${escAdmin(entry.level)}</span>
        <span class="log-target">${escAdmin(entry.target)}</span>
        <span class="log-node">${escAdmin(entry.node)}</span>
        <span class="log-msg">${escAdmin(entry.message)}</span>
      </div>`).join("")
    : `<div class="admin-empty">No logs for selected level.</div>`;
}

async function refreshAdminMetrics() {
  const payload = await fetchJson("/api/mesh/metrics");
  const metrics = normalizeMetrics(payload);
  const container = document.getElementById("admin-metrics-grid");
  if (!container) return;
  container.innerHTML = metrics
    .map((item) => `<div class="admin-metric-card">
      <div class="metric-label">${escAdmin(item.label)}</div>
      <div class="metric-value">${escAdmin(item.value)}</div>
    </div>`)
    .join("");
}

async function refreshAdminTracing() {
  const payload = await fetchJson("/api/mesh/sync-stats");
  const rows = normalizeSyncStats(payload);
  const container = document.getElementById("admin-tracing-content");
  if (!container) return;
  container.innerHTML = rows.length
    ? `<table class="admin-table"><thead><tr><th>Peer</th><th>Sent</th><th>Received</th><th>Applied</th><th>Latency</th><th>Last Error</th></tr></thead><tbody>
      ${rows
        .map((entry) => `<tr class="${entry.last_error ? "trace-error" : "trace-ok"}">
          <td>${escAdmin(entry.peer)}</td>
          <td>${escAdmin(entry.total_sent)}</td>
          <td>${escAdmin(entry.total_received)}</td>
          <td>${escAdmin(entry.total_applied)}</td>
          <td>${escAdmin(entry.latency)}</td>
          <td>${escAdmin(entry.last_error || "healthy")}</td>
        </tr>`)
        .join("")}
    </tbody></table>`
    : `<div class="admin-empty">No sync stats available.</div>`;
}

async function refreshAdminPanel() {
  if (!adminState.active) return;
  await Promise.allSettled([
    refreshAdminNodes(),
    refreshAdminLogs(),
    refreshAdminMetrics(),
    refreshAdminTracing(),
  ]);
}

function setAdminActive(isActive) {
  adminState.active = !!isActive;
  if (adminState.active) {
    refreshAdminPanel();
    if (!adminState.timer) {
      adminState.timer = setInterval(refreshAdminPanel, adminState.refreshMs);
    }
  } else if (adminState.timer) {
    clearInterval(adminState.timer);
    adminState.timer = null;
  }
}

function initAdminPanel() {
  const filter = document.getElementById("admin-log-level");
  if (filter) {
    filter.addEventListener("change", () => {
      adminState.logLevel = filter.value || "ALL";
      refreshAdminLogs();
    });
  }
}

window.initAdminPanel = initAdminPanel;
window.setAdminActive = setAdminActive;
