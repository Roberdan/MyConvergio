/**
 * Mesh action toolbar — moved from app.js.
 * XSS-safe: uses data-peer / data-action attributes with event delegation.
 */

window.meshAction = async function (action, peer) {
  if (action === "terminal") {
    if (typeof termMgr !== "undefined") termMgr.open(peer, peer);
    return;
  }
  if (action === "movehere") {
    showMovePlanDialog(peer);
    return;
  }
  const res = await fetchJson(
    `/api/mesh/action?action=${action}&peer=${encodeURIComponent(peer)}`,
  );
  if (res && res.output)
    showOutputModal(action + " \u2014 " + peer, res.output);
};

window.showMovePlanDialog = async function (targetPeer) {
  const plans = await fetchJson("/api/plans/assignable");
  if (!plans || !plans.length) {
    showOutputModal("Move Plan", "No assignable plans found");
    return;
  }
  const overlay = document.createElement("div");
  overlay.className = "modal-overlay";
  const esc = (s) => {
    const d = document.createElement("div");
    d.textContent = s;
    return d.innerHTML;
  };
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

window.showOutputModal = function (title, text) {
  const esc = (s) => {
    const d = document.createElement("div");
    d.textContent = s;
    return d.innerHTML;
  };
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
};

// Event delegation for .mn-act-btn — uses data-peer / data-action (XSS-safe)
document.addEventListener("click", (e) => {
  const btn = e.target.closest(".mn-act-btn");
  if (btn) {
    e.stopPropagation();
    meshAction(btn.dataset.action, btn.dataset.peer);
  }
});
