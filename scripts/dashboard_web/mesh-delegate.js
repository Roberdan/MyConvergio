/**
 * Mesh delegation UI — move plan and delegate plan dialogs.
 * Depends on: mesh-actions.js (showOutputModal loaded first)
 */

window.showMovePlanDialog = async function (targetPeer) {
  const plans = await fetchJson("/api/plans/assignable");
  if (!plans || !plans.length) {
    showOutputModal("Move Plan", "No assignable plans found");
    return;
  }
  const overlay = document.createElement("div");
  overlay.className = "modal-overlay";
  const statusColor = (s) =>
    ({
      done: "#00cc55",
      in_progress: "#ffb700",
      blocked: "#ee3344",
      pending: "#5a6080",
    })[s] || "#5a6080";
  let list = plans
    .map(
      (p) =>
        `<div class="move-plan-row" data-plan-id="${p.id}" data-target="${esc(targetPeer)}">
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
    const row = e.target.closest(".move-plan-row");
    if (row) {
      movePlan(Number(row.dataset.planId), row.dataset.target, overlay);
      return;
    }
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

/**
 * Delegate Plan Dialog — select a mesh peer to delegate plan execution.
 * Triggered from the rocket icon on active mission cards.
 */
window.showDelegatePlanDialog = async function (planId, planName) {
  const peers = await fetchJson("/api/mesh");
  if (!peers || !peers.length) {
    showOutputModal("Delegate Plan", "No mesh nodes configured");
    return;
  }
  const rows = peers
    .map((p) => {
      const off = !p.is_online ? " offline" : "";
      const cpu = p.cpu ? p.cpu.toFixed(0) + "%" : "—";
      const osIcon = p.os === "macos" ? "🍎" : p.os === "linux" ? "🐧" : "💻";
      return `<div class="delegate-peer-row${off}" data-peer="${esc(p.peer_name)}">
        <span><span style="margin-right:6px">${osIcon}</span><strong>${esc(p.peer_name)}</strong>
        ${p.role === "coordinator" ? '<span style="color:var(--gold);font-size:9px;margin-left:4px">COORD</span>' : ""}
        ${!p.is_online ? '<span style="color:var(--red);font-size:9px;margin-left:4px">OFFLINE</span>' : ""}</span>
        <span style="color:var(--text-dim);font-size:11px">CPU ${cpu}</span>
        <span style="color:var(--text-dim);font-size:11px">${p.active_tasks || 0} tasks</span>
        <span style="color:var(--cyan);font-size:11px">${p.plans ? p.plans.length : 0} plans</span>
      </div>`;
    })
    .join("");

  const overlay = document.createElement("div");
  overlay.className = "modal-overlay";
  overlay.innerHTML = `<div class="modal-box" style="max-width:520px">
    <div class="modal-title">Delegate #${planId} ${esc((planName || "").substring(0, 25))} → Mesh Node<span class="modal-close" onclick="this.closest('.modal-overlay').remove()">✕</span></div>
    <div style="padding:8px 0">${rows}</div>
  </div>`;
  document.body.appendChild(overlay);
  overlay.addEventListener("click", (e) => {
    const row = e.target.closest(".delegate-peer-row");
    if (row && !row.classList.contains("offline")) {
      const peer = row.dataset.peer;
      row.style.opacity = "0.5";
      row.style.pointerEvents = "none";
      _showCliSelector(planId, peer, planName, overlay);
      return;
    }
    if (e.target === overlay) overlay.remove();
  });
};

window._showCliSelector = function (planId, peer, planName, prevOverlay) {
  if (prevOverlay) prevOverlay.remove();
  const peers = (typeof lastMeshData !== "undefined" && lastMeshData) || [];
  const peerData = peers.find((p) => p.peer_name === peer);
  const defaultEngine = (peerData && peerData.default_engine) || "copilot";
  const overlay = document.createElement("div");
  overlay.className = "modal-overlay";
  overlay.innerHTML = `<div class="modal-box" style="max-width:420px">
    <div class="modal-title">Execute with → ${esc(peer)}<span class="modal-close" onclick="this.closest('.modal-overlay').remove()">✕</span></div>
    <div style="padding:14px;display:flex;flex-direction:column;gap:8px">
      <button class="cli-choice-btn${defaultEngine === "copilot" ? " cli-default" : ""}" data-cli="copilot" style="display:flex;align-items:center;gap:10px;padding:12px 16px;background:rgba(0,229,255,0.06);border:1px solid rgba(0,229,255,0.25);border-radius:8px;color:var(--cyan);cursor:pointer;font-size:13px;font-weight:600;text-align:left">
        <span style="font-size:20px">🤖</span>
        <span><div>GitHub Copilot${defaultEngine === "copilot" ? " ★" : ""}</div><div style="font-size:10px;font-weight:400;color:var(--text-dim);margin-top:2px">copilot -p '/execute ${planId}'</div></span>
      </button>
      <button class="cli-choice-btn${defaultEngine === "claude" ? " cli-default" : ""}" data-cli="claude" style="display:flex;align-items:center;gap:10px;padding:12px 16px;background:rgba(255,160,0,0.06);border:1px solid rgba(255,160,0,0.25);border-radius:8px;color:var(--gold);cursor:pointer;font-size:13px;font-weight:600;text-align:left">
        <span style="font-size:20px">🧠</span>
        <span><div>Claude Code${defaultEngine === "claude" ? " ★" : ""}</div><div style="font-size:10px;font-weight:400;color:var(--text-dim);margin-top:2px">claude --model sonnet -p '/execute ${planId}'</div></span>
      </button>
      <button class="cli-choice-btn${defaultEngine === "opencode" ? " cli-default" : ""}" data-cli="opencode" style="display:flex;align-items:center;gap:10px;padding:12px 16px;background:rgba(140,140,140,0.06);border:1px solid rgba(140,140,140,0.25);border-radius:8px;color:var(--text-dim);cursor:pointer;font-size:13px;font-weight:600;text-align:left">
        <span style="font-size:20px">⚡</span>
        <span><div>OpenCode / Other${defaultEngine === "opencode" ? " ★" : ""}</div><div style="font-size:10px;font-weight:400;color:var(--text-dim);margin-top:2px">opencode -p '/execute ${planId}'</div></span>
      </button>
    </div>
  </div>`;
  document.body.appendChild(overlay);
  overlay.addEventListener("click", (e) => {
    const btn = e.target.closest(".cli-choice-btn");
    if (btn) {
      const cli = btn.dataset.cli;
      overlay.remove();
      runPreflight(planId, peer, planName, null, cli);
      return;
    }
    if (e.target === overlay) overlay.remove();
  });
};
