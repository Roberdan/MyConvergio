const $ = (s) => document.querySelector(s);
const state = (window.DashboardState = window.DashboardState || {
  hostToPeer: {},
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
  if (!host) return "local";
  if (state.hostToPeer[host]) return state.hostToPeer[host];
  const h = host.toLowerCase();
  for (const [k, n] of Object.entries(state.hostToPeer)) {
    if (h.includes(k.toLowerCase()) || k.toLowerCase().includes(h)) return n;
  }
  return host.length > 20 ? host.substring(0, 16) + "…" : host;
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
    state.hostToPeer = {};
    mesh.forEach((p) => {
      state.hostToPeer[p.peer_name] = p.peer_name;
      if (p.dns_name) state.hostToPeer[p.dns_name] = p.peer_name;
      if (p.is_local) state.hostToPeer.local = p.peer_name;
    });
  }
  if (typeof renderMission === "function") renderMission(mission);
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
  if (history && typeof renderHistory === "function") renderHistory(history);
  if (dist && typeof renderDist === "function") renderDist(dist);
  const lu = $("#last-update");
  if (lu) lu.textContent = `Updated: ${new Date().toLocaleTimeString()}`;
  _pullRemoteDb();
}

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
  refreshAll();
  applyRefresh();
  setTimeout(handleHashRoute, 1200);
  if (typeof initDashboardWebSocket === "function") initDashboardWebSocket();
});
