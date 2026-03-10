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
  const [ov, mission, organization, liveSystem, daily, models, mesh, history, dist, nightly] = await Promise.all([
    fetchJson("/api/overview"),
    fetchJson("/api/mission"),
    fetchJson("/api/organization"),
    fetchJson("/api/live-system"),
    fetchJson("/api/tokens/daily"),
    fetchJson("/api/tokens/models"),
    fetchJson("/api/mesh"),
    fetchJson("/api/history"),
    fetchJson("/api/tasks/distribution"),
    fetchJson("/api/nightly/jobs"),
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
  const _safe = (label, fn) => { try { fn(); } catch (e) { console.error(`[Dashboard] ${label} render error:`, e); } };
  _safe("mission", () => { if (typeof renderMission === "function") renderMission(mission); });
  if (ov && typeof renderKpi === "function") renderKpi(ov);
  _safe("kanban", () => { if (typeof renderKanban === "function") renderKanban(); });
  _safe("tokenChart", () => { if (daily && typeof renderTokenChart === "function") renderTokenChart(daily); });
  _safe("modelChart", () => { if (models && typeof renderModelChart === "function") renderModelChart(models); });
  if (mesh && typeof renderMeshStrip === "function") {
    _safe("meshStrip", () => {
      renderMeshStrip(mesh);
      if (typeof renderGitHubActivity === "function") renderGitHubActivity();
      else if (typeof renderEventFeed === "function") renderEventFeed();
    });
    fetch("/api/mesh/sync-status")
      .then((r) => r.json())
      .then((items) => typeof applyMeshSyncBadges === "function" && applyMeshSyncBadges(items))
      .catch(() => null);
  }
  if (organization) state.lastOrganizationData = organization;
  _safe("organization", () => { if (typeof renderAgentOrganization === "function") renderAgentOrganization(organization); });
  if (liveSystem) state.lastLiveSystemData = liveSystem;
  _safe("liveSystem", () => { if (typeof renderLiveSystem === "function") renderLiveSystem(liveSystem); });
  _safe("history", () => { if (history && typeof renderHistory === "function") renderHistory(history); });
  _safe("dist", () => { if (dist && typeof renderDist === "function") renderDist(dist); });
  _safe("nightlyJobs", () => { if (typeof renderNightlyJobs === "function") renderNightlyJobs(nightly); });
  if (nightly && nightly.latest && nightly.latest.status === "running" && !window._njPollTimer) {
    window._njPollTimer = setInterval(async () => {
      try {
        const fresh = await fetchJson("/api/nightly/jobs");
        _safe("nightlyJobs", () => { if (typeof renderNightlyJobs === "function") renderNightlyJobs(fresh); });
        if (!fresh || !fresh.latest || fresh.latest.status !== "running") { clearInterval(window._njPollTimer); window._njPollTimer = null; }
      } catch (e) { clearInterval(window._njPollTimer); window._njPollTimer = null; }
    }, 30000);
  }
  _safe("ideaJarWidget", () => { if (typeof renderIdeaJarWidget === "function") renderIdeaJarWidget(); });
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

const REFRESH_STEPS = [0, 1, 2, 5, 10, 15, 30, 60, 120]; // 0 = manual
state.refreshIdx = REFRESH_STEPS.indexOf(parseInt(localStorage.getItem("dashRefresh") || "0", 10));
if (state.refreshIdx === -1) state.refreshIdx = 0; // default to manual
function applyRefresh() {
  const sec = REFRESH_STEPS[state.refreshIdx];
  localStorage.setItem("dashRefresh", String(sec));
  const label = document.getElementById("refresh-label");
  if (state.refreshTimer) { clearInterval(state.refreshTimer); state.refreshTimer = null; }
  if (sec === 0) {
    if (label) { label.textContent = "Manual"; label.className = "refresh-label-manual"; }
  } else {
    if (label) { label.textContent = sec < 60 ? `${sec}s` : `${sec / 60}m`; label.className = "refresh-label-auto"; }
    state.refreshTimer = setInterval(refreshAll, sec * 1000);
  }
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

const DASH_SECTIONS = ["dashboard-main-section", "dashboard-chat-section", "dashboard-brain-section", "dashboard-ideajar-section"];
function showDashboardSection(sectionId) {
  const prev = DASH_SECTIONS.find(id => { const s = document.getElementById(id); return s && !s.hidden && s.style.display !== 'none'; });
  if (prev === 'dashboard-ideajar-section' && sectionId !== 'dashboard-ideajar-section') {
    if (window.JarCanvas) JarCanvas.destroyJarCanvas('idea-jar-canvas');
  }
  const target = DASH_SECTIONS.includes(sectionId) ? sectionId : "dashboard-main-section";
  DASH_SECTIONS.forEach((id) => {
    const section = document.getElementById(id);
    if (section) { section.hidden = id !== target; section.style.display = id !== target ? 'none' : ''; }
  });
  if (target === 'dashboard-brain-section') {
    const src = document.getElementById('brain-canvas-container');
    const dst = document.getElementById('brain-canvas-fullscreen');
    if (src && dst && !dst.hasChildNodes()) {
      dst.appendChild(src);
      src.style.height = '100%';
      if (typeof window.resizeBrainCanvas === 'function') window.resizeBrainCanvas();
    }
  }
  if (prev === 'dashboard-brain-section' && target !== 'dashboard-brain-section') {
    const src = document.getElementById('brain-canvas-container');
    const widget = document.getElementById('brain-widget');
    if (src && widget) {
      const body = widget.querySelector('.widget-body') || widget;
      body.appendChild(src);
      src.style.height = '480px';
      if (typeof window.resizeBrainCanvas === 'function') window.resizeBrainCanvas();
    }
  }
  if (target === 'dashboard-ideajar-section' && typeof renderIdeaJarTab === 'function') {
    renderIdeaJarTab();
  }
  if (target === 'dashboard-chat-section') {
    renderProjectList();
  }
  document.querySelectorAll("#dashboard-nav [data-section]").forEach((btn) => {
    btn.classList.toggle("active", btn.dataset.section === target);
  });
  localStorage.setItem("dashboardSection", target);
}

async function renderProjectList() {
  const el = document.getElementById('project-list-content');
  if (!el) return;
  const data = await fetchJson('/api/projects');
  const projects = Array.isArray(data) ? data : (data?.projects || []);
  if (!projects.length) {
    el.innerHTML = '<div style="color:var(--text-dim);font-size:12px;padding:8px">No projects yet.</div>';
    return;
  }
  el.innerHTML = projects.map(p => `<div class="project-list-item" onclick="selectProject('${esc(p.id || p.name)}')" title="${esc(p.description || '')}">
    <div style="font-weight:600;font-size:12px;color:var(--text)">${esc(p.name)}</div>
    ${p.description ? `<div style="font-size:10px;color:var(--text-dim);margin-top:2px;overflow:hidden;text-overflow:ellipsis;white-space:nowrap">${esc(p.description.slice(0, 60))}</div>` : ''}
  </div>`).join('');
}

function selectProject(projectId) {
  document.querySelectorAll('.project-list-item').forEach(el => el.classList.remove('selected'));
  const clicked = event?.target?.closest('.project-list-item');
  if (clicked) clicked.classList.add('selected');
}

async function openNewProjectModal() {
  const existing = document.getElementById('new-project-overlay');
  if (existing) existing.remove();
  const overlay = document.createElement('div');
  overlay.id = 'new-project-overlay';
  overlay.className = 'modal-overlay';
  const _f = (label, content) => `<label class="modal-field"><span class="modal-field-label">${label}</span>${content}</label>`;
  overlay.innerHTML = `<div class="widget" style="width:420px;max-width:95vw;box-shadow:0 0 60px rgba(0,229,255,0.1)">
    <div class="widget-header"><span class="widget-title">New Project</span><span style="cursor:pointer;color:var(--red);font-size:16px" onclick="document.getElementById('new-project-overlay').remove()">✕</span></div>
    <div class="widget-body">
    <form id="new-project-form" style="display:flex;flex-direction:column;gap:10px">
      ${_f('Name *', '<input name="name" required class="modal-input">')}
      ${_f('Description', '<textarea name="description" rows="3" class="modal-input"></textarea>')}
      ${_f('Repository', '<input name="repo" placeholder="owner/repo" class="modal-input">')}
      <div style="display:flex;justify-content:flex-end;gap:6px;padding-top:8px;border-top:1px solid var(--border)">
        <button type="button" class="widget-action-btn" onclick="document.getElementById('new-project-overlay').remove()">Cancel</button>
        <button type="submit" class="widget-action-btn" style="background:rgba(0,229,255,0.15)">Create</button>
      </div>
    </form></div></div>`;
  document.body.appendChild(overlay);
  overlay.addEventListener('click', e => { if (e.target === overlay) overlay.remove(); });
  overlay.querySelector('#new-project-form').addEventListener('submit', async e => {
    e.preventDefault();
    const fd = new FormData(e.target);
    const body = Object.fromEntries(fd.entries());
    try {
      await fetch('/api/projects', { method: 'POST', headers: { 'Content-Type': 'application/json' }, body: JSON.stringify(body) });
      overlay.remove();
      renderProjectList();
      if (typeof showToast === 'function') showToast('Project created', '', document.body, 'success');
    } catch (err) {
      if (typeof showToast === 'function') showToast('Error', err.message, document.body, 'error');
    }
  });
}

function initDashboardNavigation() {
  const nav = document.getElementById("dashboard-nav");
  if (!nav) return;
  nav.querySelectorAll("[data-section]").forEach((button) => {
    button.addEventListener("click", () => showDashboardSection(button.dataset.section));
  });
  const saved = localStorage.getItem("dashboardSection");
  showDashboardSection(saved || "dashboard-main-section");
}

window.$ = $;
window.fetchJson = fetchJson;
window.refreshAll = refreshAll;
window._resolveHost = _resolveHost;
window.showDashboardSection = showDashboardSection;
window.renderProjectList = renderProjectList;
window.openNewProjectModal = openNewProjectModal;
window.selectProject = selectProject;

window.addEventListener("hashchange", handleHashRoute);

document.addEventListener("DOMContentLoaded", () => {
  initDashboardNavigation();
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
