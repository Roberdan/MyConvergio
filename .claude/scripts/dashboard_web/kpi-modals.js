/**
 * KPI card drill-down modals — keep app.js under control (C-05).
 * openPlansModal, openActiveModal, openAgentsModal,
 * openTokensModal, openCostModal, openBlockedModal
 */

function _kpiModal(title, bodyHtml) {
  const existing = document.querySelector(".kpi-modal-overlay");
  if (existing) existing.remove();
  const overlay = document.createElement("div");
  overlay.className = "kpi-modal-overlay";
  overlay.innerHTML = `<div class="modal-box">
    <div class="modal-title">${title}<span class="modal-close" id="_kpi-close">\u2715</span></div>
    <div class="kpi-modal-body">${bodyHtml}</div>
  </div>`;
  document.body.appendChild(overlay);
  const close = () => overlay.remove();
  overlay.querySelector("#_kpi-close").addEventListener("click", close);
  overlay.addEventListener("click", (e) => {
    if (e.target === overlay) close();
  });
  document.addEventListener("keydown", function esc(e) {
    if (e.key === "Escape") {
      close();
      document.removeEventListener("keydown", esc);
    }
  });
}

function _kpiLoading(title) {
  _kpiModal(
    title,
    '<div style="padding:20px;color:var(--text-dim)">Loading\u2026</div>',
  );
}

function _kpiError(title, msg) {
  _kpiModal(
    title,
    `<div style="padding:20px;color:var(--red)">${msg || "Failed to load data"}</div>`,
  );
}

// --- Plans modal: list all plans from /api/history + /api/plans/assignable ---
window.openPlansModal = async function () {
  _kpiLoading("ALL PLANS");
  const [history, assignable] = await Promise.all([
    fetch("/api/history")
      .then((r) => r.json())
      .catch(() => []),
    fetch("/api/plans/assignable")
      .then((r) => r.json())
      .catch(() => []),
  ]);
  const seen = new Set();
  const plans = [];
  (assignable || []).forEach((p) => {
    seen.add(p.id);
    plans.push(p);
  });
  (history || []).forEach((p) => {
    if (!seen.has(p.id)) plans.push(p);
  });
  if (!plans.length) {
    _kpiError("ALL PLANS", "No plans found");
    return;
  }
  const sc = (s) =>
    ({
      done: "var(--green)",
      doing: "var(--cyan)",
      todo: "var(--text-dim)",
      archived: "var(--text-dim)",
      cancelled: "var(--red)",
    })[s] || "var(--text-dim)";
  const rows = plans
    .map(
      (p) =>
        `<div class="kpi-modal-row" onclick="closeSidebar && openPlanSidebar(${p.id}); document.querySelector('.kpi-modal-overlay')?.remove();" style="cursor:pointer">
      <span style="color:var(--cyan);font-weight:600">#${p.id}</span>
      <span>${(p.name || "?").substring(0, 32)}</span>
      <span style="color:${sc(p.status)}">${p.status}</span>
      <span style="color:var(--text-dim)">${p.tasks_done || 0}/${p.tasks_total || 0}</span>
    </div>`,
    )
    .join("");
  _kpiModal("ALL PLANS", `<div class="kpi-modal-list">${rows}</div>`);
};

// --- Active: scroll to #mission-panel ---
window.openActiveModal = function () {
  document.querySelector(".kpi-modal-overlay")?.remove();
  const el = document.getElementById("mission-panel");
  if (el) el.scrollIntoView({ behavior: "smooth", block: "start" });
};

// --- Agents: list in_progress tasks from lastMissionData ---
window.openAgentsModal = function () {
  if (
    typeof lastMissionData === "undefined" ||
    !lastMissionData ||
    !lastMissionData.tasks
  ) {
    _kpiModal(
      "RUNNING AGENTS",
      '<div style="padding:20px;color:var(--text-dim)">No active mission data</div>',
    );
    return;
  }
  const running = (lastMissionData.tasks || []).filter(
    (t) => t.status === "in_progress",
  );
  if (!running.length) {
    _kpiModal(
      "RUNNING AGENTS",
      '<div style="padding:20px;color:var(--text-dim)">No agents currently running</div>',
    );
    return;
  }
  const rows = running
    .map(
      (t) =>
        `<div class="kpi-modal-row">
      <span style="color:var(--gold)">&#9889;</span>
      <span style="color:var(--cyan)">${t.task_id || "—"}</span>
      <span>${(t.title || "—").substring(0, 30)}</span>
      <span style="color:var(--text-dim)">${t.executor_agent || "—"}</span>
      <span style="color:var(--text-dim)">${t.executor_host || "—"}</span>
    </div>`,
    )
    .join("");
  _kpiModal("RUNNING AGENTS", `<div class="kpi-modal-list">${rows}</div>`);
};

// --- Tokens: scroll to #token-chart ---
window.openTokensModal = function () {
  document.querySelector(".kpi-modal-overlay")?.remove();
  const el = document.getElementById("token-chart");
  if (el) el.scrollIntoView({ behavior: "smooth", block: "center" });
};

// --- Cost: breakdown by model from /api/tokens/models ---
window.openCostModal = async function () {
  _kpiLoading("COST BREAKDOWN");
  const models = await fetch("/api/tokens/models")
    .then((r) => r.json())
    .catch(() => null);
  if (!models || !models.length) {
    _kpiError("COST BREAKDOWN", "No cost data available");
    return;
  }
  const total = models.reduce((s, m) => s + (m.cost || 0), 0);
  const fmt = (n) =>
    n >= 1e6
      ? (n / 1e6).toFixed(1) + "M"
      : n >= 1e3
        ? (n / 1e3).toFixed(1) + "K"
        : String(Math.round(n));
  const rows = models
    .map((m) => {
      const pct = total > 0 ? Math.round((100 * (m.cost || 0)) / total) : 0;
      return `<div class="kpi-modal-row">
      <span style="color:var(--cyan)">${(m.model || "?").replace("claude-", "")}</span>
      <span style="color:var(--gold)">$${Number(m.cost || 0).toFixed(2)}</span>
      <span style="color:var(--text-dim)">${fmt(m.tokens || 0)} tok</span>
      <span style="color:var(--text-dim)">${pct}%</span>
    </div>`;
    })
    .join("");
  const totalRow = `<div class="kpi-modal-row" style="border-top:1px solid var(--border);margin-top:4px;padding-top:4px">
    <span style="color:var(--text)">TOTAL</span>
    <span style="color:var(--gold);font-weight:600">$${Number(total).toFixed(2)}</span>
    <span></span><span></span>
  </div>`;
  _kpiModal(
    "COST BREAKDOWN",
    `<div class="kpi-modal-list">${rows}${totalRow}</div>`,
  );
};

// --- Blocked: fetch /api/tasks/blocked ---
window.openBlockedModal = async function () {
  _kpiLoading("BLOCKED TASKS");
  const tasks = await fetch("/api/tasks/blocked")
    .then((r) => r.json())
    .catch(() => null);
  if (!tasks || !tasks.length) {
    _kpiModal(
      "BLOCKED TASKS",
      '<div style="padding:20px;color:var(--green)">No blocked tasks \u2713</div>',
    );
    return;
  }
  const rows = tasks
    .map(
      (t) =>
        `<div class="kpi-modal-row">
      <span style="color:var(--red)">&#10007;</span>
      <span style="color:var(--cyan)">${t.task_id || t.id || "—"}</span>
      <span>${(t.title || "—").substring(0, 32)}</span>
      <span style="color:var(--text-dim)">${(t.reason || "—").substring(0, 28)}</span>
    </div>`,
    )
    .join("");
  _kpiModal("BLOCKED TASKS", `<div class="kpi-modal-list">${rows}</div>`);
};
