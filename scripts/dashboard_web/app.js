const $ = (s) => document.querySelector(s);
const state = (window.DashboardState = window.DashboardState || {
  hostToPeer: {},
  localPeerName: "local",
  lastMissionData: null,
  lastMeshData: null,
  lastOrganizationData: null,
  lastLiveSystemData: null,
  allMissionPlans: [],
  filteredPlanId: null,
  pullInProgress: false,
  notifLastId: 0,
  refreshTimer: null,
  refreshIdx: 2,
  currentZoom: parseInt(localStorage.getItem("dashZoom") || "100", 10),
});

Object.defineProperty(window, "lastMissionData", {
  get: () => state.lastMissionData,
  set: (v) => (state.lastMissionData = v),
  configurable: true,
});
Object.defineProperty(window, "lastMeshData", {
  get: () => state.lastMeshData,
  set: (v) => (state.lastMeshData = v),
  configurable: true,
});

async function fetchJson(url) {
  try {
    return await (await fetch(url)).json();
  } catch {
    return null;
  }
}

function _resolveHost(host) {
  if (!host) return "unknown";
  if (state.hostToPeer[host]) return state.hostToPeer[host];
  // Fuzzy: strip suffixes and special chars
  const clean = host.toLowerCase().replace(/[-_]/g, "").replace(/\.(lan|local|tailnet)$/i, "");
  for (const [k, n] of Object.entries(state.hostToPeer)) {
    const cleanKey = k.toLowerCase().replace(/[-_]/g, "").replace(/\.(lan|local|tailnet)$/i, "");
    if (cleanKey === clean) return n;
  }
  return host;
}

async function _pullRemoteDb() {
  if (state.pullInProgress) return;
  state.pullInProgress = true;
  try {
    const r = await fetchJson("/api/mesh/pull-db");
    if (r && r.count > 0) {
      const ok = r.synced.filter((s) => s.ok).length;
      const badge = document.getElementById("sync-badge");
      if (ok > 0 && badge) {
        badge.textContent = `↓ ${ok} synced`;
        badge.style.display = "inline";
        setTimeout(() => (badge.style.display = "none"), 3000);
      }
    }
  } finally {
    state.pullInProgress = false;
  }
}

async function refreshAll() {
  const [ov, mission, organization, liveSystem, daily, models, mesh, history, dist] = await Promise.all([
    fetchJson("/api/overview"),
    fetchJson("/api/mission"),
    fetchJson("/api/organization"),
    fetchJson("/api/live-system"),
    fetchJson("/api/tokens/daily"),
    fetchJson("/api/tokens/models"),
    fetchJson("/api/mesh"),
    fetchJson("/api/history"),
    fetchJson("/api/tasks/distribution"),
  ]);
  if (ov) {
    ov.mesh_online = mesh ? mesh.filter((p) => p.is_online).length : 0;
    ov.mesh_total = mesh ? mesh.length : 0;
    if (typeof renderKpi === "function") renderKpi(ov);
  }
  if (Array.isArray(mesh)) {
    state.localPeerName = mesh.find((p) => p.is_local)?.peer_name || "local";
    state.hostToPeer = {};
    mesh.forEach((p) => {
      const name = p.peer_name || p.name;
      if (name) {
        state.hostToPeer[name] = name;
        if (p.dns_name) state.hostToPeer[p.dns_name] = name;
        if (p.ssh_alias) state.hostToPeer[p.ssh_alias] = name;
        if (p.tailscale_ip) state.hostToPeer[p.tailscale_ip] = name;
        if (p.is_local) state.hostToPeer.local = name;
        // Register hostname variants for local peer
        if (p.is_local && Array.isArray(p.hostname_aliases)) {
          p.hostname_aliases.forEach((alias) => {
            if (alias) state.hostToPeer[alias] = name;
          });
        }
      }
    });
  }
  if (typeof renderMission === "function") renderMission(mission);
  if (typeof renderKanban === "function") renderKanban();
  if (daily && typeof renderTokenChart === "function") renderTokenChart(daily);
  if (models && typeof renderModelChart === "function") renderModelChart(models);
  if (mesh && typeof renderMeshStrip === "function") {
    renderMeshStrip(mesh);
    if (typeof renderEventFeed === "function") renderEventFeed();
    fetch("/api/mesh/sync-status")
      .then((r) => r.json())
      .then((items) => typeof applyMeshSyncBadges === "function" && applyMeshSyncBadges(items))
      .catch(() => null);
  }
  if (organization) state.lastOrganizationData = organization;
  if (typeof renderAgentOrganization === "function") renderAgentOrganization(organization);
  if (liveSystem) state.lastLiveSystemData = liveSystem;
  if (typeof renderLiveSystem === "function") renderLiveSystem(liveSystem);
  if (window._brainActive && window.updateBrainData && liveSystem) {
    window.updateBrainData(liveSystem);
  }
  if (history && typeof renderHistory === "function") renderHistory(history);
  if (dist && typeof renderDist === "function") renderDist(dist);
  const lu = $("#last-update");
  if (lu) lu.textContent = `Updated: ${new Date().toLocaleTimeString()}`;
  _pullRemoteDb();
}

window.toggleBrainCanvas = function () {
  const container = document.getElementById("brain-activity");
  if (!container) return;
  if (window._brainActive) {
    if (window.destroyBrainCanvas) window.destroyBrainCanvas();
    container.style.display = "none";
    window._brainActive = false;
  } else {
    container.style.display = "block";
    if (window.initBrainCanvas) window.initBrainCanvas("brain-canvas-container");
    window._brainActive = true;
    if (typeof refreshAll === "function") refreshAll();
  }
};

function updateClock() {
  const el = $("#clock");
  if (!el) return;
  el.textContent = new Date().toLocaleString("en-GB", {
    day: "2-digit",
    month: "short",
    year: "numeric",
    hour: "2-digit",
    minute: "2-digit",
    second: "2-digit",
  });
}

const ZOOM_STEP = 10;
const ZOOM_MIN = 60;
const ZOOM_MAX = 160;
function applyZoom(z) {
  state.currentZoom = Math.max(ZOOM_MIN, Math.min(ZOOM_MAX, z));
  document.body.style.zoom = state.currentZoom / 100;
  const label = document.getElementById("zoom-level");
  if (label) label.textContent = `${state.currentZoom}%`;
  localStorage.setItem("dashZoom", String(state.currentZoom));
}
window.dashZoom = (dir) => (dir === 0 ? applyZoom(100) : applyZoom(state.currentZoom + dir * ZOOM_STEP));

const REFRESH_STEPS = [10, 15, 30, 60, 120];
state.refreshIdx = REFRESH_STEPS.indexOf(parseInt(localStorage.getItem("dashRefresh") || "30", 10));
if (state.refreshIdx === -1) state.refreshIdx = 2;
function applyRefresh() {
  const sec = REFRESH_STEPS[state.refreshIdx];
  localStorage.setItem("dashRefresh", String(sec));
  const label = document.getElementById("refresh-label");
  if (label) label.textContent = sec < 60 ? `${sec}s` : `${sec / 60}m`;
  if (state.refreshTimer) clearInterval(state.refreshTimer);
  state.refreshTimer = setInterval(refreshAll, sec * 1000);
}
window.changeRefresh = (dir) => {
  state.refreshIdx = Math.max(0, Math.min(REFRESH_STEPS.length - 1, state.refreshIdx + dir));
  applyRefresh();
};

window.openAllTerminals = function () {
  if (typeof termMgr === "undefined") return;
  const online = (state.lastMeshData || []).filter((p) => p.is_online);
  if (!online.length) return typeof showOutputModal === "function" && showOutputModal("Terminals", "No online mesh nodes");
  online.forEach((p) => termMgr.open(p.peer_name, p.peer_name, "Convergio"));
  termMgr.setMode(online.length > 1 ? "grid" : "dock");
};

function handleHashRoute() {
  const m = location.hash.match(/^#plan\/(\d+)/);
  if (!m) return;
  const id = parseInt(m[1], 10);
  if (typeof filterTasks === "function") filterTasks(id);
  const card = document.querySelector(`.mission-plan[onclick*="${id}"]`);
  if (!card) return;
  card.scrollIntoView({ behavior: "smooth", block: "center" });
  card.classList.add("highlight-pulse");
  setTimeout(() => card.classList.remove("highlight-pulse"), 3000);
}

window.$ = $;
window.fetchJson = fetchJson;
window.refreshAll = refreshAll;
window._resolveHost = _resolveHost;

window.addEventListener("hashchange", handleHashRoute);

document.addEventListener("DOMContentLoaded", () => {
  applyZoom(state.currentZoom);
  updateClock();
  setInterval(updateClock, 1000);
  // First-load only — NOT in periodic refreshAll
  fetch("/api/mesh/init", { method: "POST" })
    .then((r) => r.json())
    .then((data) => {
      if (data.daemons_restarted && data.daemons_restarted.length > 0) {
        showToast(`Restarted: ${data.daemons_restarted.join(", ")}`, "info");
      }
      if (data.hosts_needing_normalization > 0) {
        showToast(`${data.hosts_needing_normalization} plans need host normalization`, "warn");
      }
    })
    .catch(() => {});
  refreshAll();
  applyRefresh();
  setTimeout(handleHashRoute, 1200);
  if (typeof initDashboardWebSocket === "function") initDashboardWebSocket();
});
