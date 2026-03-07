/**
 * Mesh plan operations — start, full sync, cancel, reset.
 * Depends on: mesh-actions.js (ansiToHtml, showOutputModal loaded first)
 */

/**
 * Start Plan Dialog — choose CLI and execute locally or delegate.
 */
window.showStartPlanDialog = function (planId, planName) {
  const overlay = document.createElement("div");
  overlay.className = "modal-overlay";
  overlay.innerHTML = `<div class="modal-box" style="max-width:420px">
    <div class="modal-title">Start #${planId} ${esc((planName || "").substring(0, 25))}<span class="modal-close" onclick="this.closest('.modal-overlay').remove()">✕</span></div>
    <div style="padding:14px;display:flex;flex-direction:column;gap:8px">
      <button class="cli-choice-btn" data-cli="copilot" data-target="local" style="display:flex;align-items:center;gap:10px;padding:12px 16px;background:rgba(0,229,255,0.06);border:1px solid rgba(0,229,255,0.25);border-radius:8px;color:var(--cyan);cursor:pointer;font-size:13px;font-weight:600;text-align:left">
        <span style="font-size:20px">${Icons.cpu(20)}</span>
        <span><div>GitHub Copilot (local)</div><div style="font-size:10px;font-weight:400;color:var(--text-dim);margin-top:2px">copilot -p '/execute ${planId}'</div></span>
      </button>
      <button class="cli-choice-btn" data-cli="claude" data-target="local" style="display:flex;align-items:center;gap:10px;padding:12px 16px;background:rgba(255,160,0,0.06);border:1px solid rgba(255,160,0,0.25);border-radius:8px;color:var(--gold);cursor:pointer;font-size:13px;font-weight:600;text-align:left">
        <span style="font-size:20px">${Icons.brain(20)}</span>
        <span><div>Claude Code (local)</div><div style="font-size:10px;font-weight:400;color:var(--text-dim);margin-top:2px">claude --model sonnet -p '/execute ${planId}'</div></span>
      </button>
      <div style="border-top:1px solid var(--border);margin:4px 0;padding-top:8px">
        <div style="font-size:10px;color:var(--text-dim);margin-bottom:6px;text-transform:uppercase;letter-spacing:1px">Or delegate to mesh node →</div>
        <button class="cli-choice-btn" data-cli="delegate" style="display:flex;align-items:center;gap:10px;padding:10px 16px;background:rgba(140,140,140,0.06);border:1px solid rgba(140,140,140,0.25);border-radius:8px;color:var(--text-dim);cursor:pointer;font-size:12px;font-weight:600;text-align:left">
          <span style="font-size:18px">${Icons.globe(18)}</span>
          <span>Choose mesh node…</span>
        </button>
      </div>
    </div>
  </div>`;
  document.body.appendChild(overlay);
  overlay.addEventListener("click", (e) => {
    const btn = e.target.closest(".cli-choice-btn");
    if (btn) {
      const cli = btn.dataset.cli;
      overlay.remove();
      if (cli === "delegate") {
        showDelegatePlanDialog(planId, planName);
      } else {
        startPlanExecution(planId, planName, cli, "local");
      }
      return;
    }
    if (e.target === overlay) overlay.remove();
  });
};

/**
 * Execute plan start via SSE — shows live progress.
 */
window.startPlanExecution = function (planId, planName, cli, target) {
  const overlay = document.createElement("div");
  overlay.className = "modal-overlay";
  overlay.innerHTML = `<div class="modal-box" style="max-width:650px">
    <div class="modal-title">Starting #${planId} ${esc((planName || "").substring(0, 25))}<span class="modal-close" onclick="this.closest('.modal-overlay').remove()">✕</span></div>
    <pre class="modal-output" id="start-plan-output" style="max-height:450px;overflow:auto;font-size:12px;min-height:200px"></pre>
  </div>`;
  document.body.appendChild(overlay);
  overlay.addEventListener("click", (e) => {
    if (e.target === overlay) overlay.remove();
  });

  const output = document.getElementById("start-plan-output");
  const url = `/api/plan/start?plan_id=${planId}&cli=${encodeURIComponent(cli)}&target=${encodeURIComponent(target)}`;
  const es = new EventSource(url);

  es.addEventListener("log", (e) => {
    const line = e.data || "";
    const hasAnsi = /\x1b\[/.test(line);
    let html;
    if (hasAnsi) {
      html = ansiToHtml(line);
    } else if (line.startsWith("▶")) {
      html = `<span style="color:var(--cyan)">${esc(line)}</span>`;
    } else if (/^(OK|✓|PASS|done)/i.test(line)) {
      html = `<span style="color:var(--green)">${esc(line)}</span>`;
    } else if (/^(ERROR|FAIL|✗)/i.test(line)) {
      html = `<span style="color:var(--red)">${esc(line)}</span>`;
    } else {
      html = esc(line);
    }
    output.innerHTML += html + "\n";
    output.scrollTop = output.scrollHeight;
  });

  es.addEventListener("done", (e) => {
    es.close();
    const data = JSON.parse(e.data);
    if (data.ok) {
      output.innerHTML += `\n<span style="color:var(--green);font-weight:600">${Icons.checkCircle(14)} Plan started successfully</span>\n`;
    } else {
      const msg = data.message || `Exit code ${data.exit_code || "?"}`;
      output.innerHTML += `\n<span style="color:var(--red);font-weight:600">${Icons.xCircle(14)} ${esc(msg)}</span>\n`;
    }
    output.scrollTop = output.scrollHeight;
    if (typeof refreshAll === "function") refreshAll();
  });

  es.onerror = () => {
    es.close();
    output.innerHTML += `\n<span style="color:var(--red)">${Icons.x(14)} Connection lost</span>\n`;
  };
};

/**
 * Full Sync action — bidirectional mesh sync via SSE.
 */
window.runFullSync = function (peer) {
  const target = peer || "all nodes";
  const overlay = document.createElement("div");
  overlay.className = "modal-overlay";
  overlay.innerHTML = `<div class="modal-box" style="max-width:650px">
    <div class="modal-title">Full Sync — ${esc(target)}<span class="modal-close" onclick="this.closest('.modal-overlay').remove()">✕</span></div>
    <pre class="modal-output" id="fullsync-output" style="min-height:200px;max-height:500px;overflow:auto"></pre>
  </div>`;
  document.body.appendChild(overlay);
  overlay.addEventListener("click", (e) => {
    if (e.target === overlay) overlay.remove();
  });

  const output = document.getElementById("fullsync-output");
  let url = `/api/mesh/fullsync?`;
  if (peer) url += `peer=${encodeURIComponent(peer)}&`;
  const es = new EventSource(url);

  es.addEventListener("log", (e) => {
    const line = e.data || "";
    const hasAnsi = /\x1b\[/.test(line);
    let html;
    if (hasAnsi) {
      html = ansiToHtml(line);
    } else if (line.startsWith("▶") || line.startsWith("===")) {
      html = `<span style="color:var(--cyan);font-weight:600">${esc(line)}</span>`;
    } else if (/^(OK|✓|SYNC_OK|→.*OK|local is newest)/i.test(line.trim())) {
      html = `<span style="color:var(--green)">${esc(line)}</span>`;
    } else if (/PULL from|⟵/.test(line)) {
      html = `<span style="color:var(--gold);font-weight:600">${esc(line)}</span>`;
    } else if (/^(ERROR|FAIL|✗)/i.test(line.trim())) {
      html = `<span style="color:var(--red)">${esc(line)}</span>`;
    } else {
      html = esc(line);
    }
    output.innerHTML += html + "\n";
    output.scrollTop = output.scrollHeight;
  });

  es.addEventListener("done", (e) => {
    es.close();
    const data = JSON.parse(e.data);
    if (data.ok) {
      output.innerHTML += `\n<span style="color:var(--green);font-weight:600">${Icons.checkCircle(14)} Full sync completed</span>\n`;
    } else {
      output.innerHTML += `\n<span style="color:var(--red);font-weight:600">${Icons.xCircle(14)} Sync failed</span>\n`;
    }
    output.scrollTop = output.scrollHeight;
    if (typeof refreshAll === "function") refreshAll();
  });

  es.onerror = () => {
    es.close();
    output.innerHTML += `\n<span style="color:var(--red)">${Icons.x(14)} Connection lost</span>\n`;
  };
};

/**
 * Cancel a plan — sets plan + waves + tasks to cancelled.
 */
window.cancelPlan = async function (planId) {
  const overlay = document.createElement("div");
  overlay.className = "modal-overlay";
  overlay.innerHTML = `<div class="modal-box" style="max-width:400px">
    <div class="modal-title">Cancel Plan #${planId}<span class="modal-close" onclick="this.closest('.modal-overlay').remove()">&#x2715;</span></div>
    <div style="padding:14px">
      <p style="color:var(--text);margin-bottom:12px">This will cancel all pending/in-progress tasks and waves for plan #${planId}. Already completed tasks will be preserved.</p>
      <div style="display:flex;gap:8px;justify-content:flex-end">
        <button class="preflight-action-btn" style="border-color:var(--text-dim);color:var(--text-dim)" onclick="this.closest('.modal-overlay').remove()">Abort</button>
        <button id="confirm-cancel-btn" class="preflight-action-btn" style="border-color:var(--red);color:var(--red)">Confirm Cancel</button>
      </div>
    </div>
  </div>`;
  document.body.appendChild(overlay);
  overlay.addEventListener("click", (e) => {
    if (e.target === overlay) overlay.remove();
  });
  document
    .getElementById("confirm-cancel-btn")
    .addEventListener("click", async () => {
      const res = await fetchJson(`/api/plan/cancel?plan_id=${planId}`);
      overlay.remove();
      if (res && res.ok) {
        closeSidebar();
        refreshAll();
      } else {
        showOutputModal("Cancel Error", res ? res.error : "Failed");
      }
    });
};

/**
 * Reset a plan — resets to todo, all non-done tasks back to pending.
 */
window.resetPlan = async function (planId) {
  const overlay = document.createElement("div");
  overlay.className = "modal-overlay";
  overlay.innerHTML = `<div class="modal-box" style="max-width:400px">
    <div class="modal-title">Reset Plan #${planId}<span class="modal-close" onclick="this.closest('.modal-overlay').remove()">&#x2715;</span></div>
    <div style="padding:14px">
      <p style="color:var(--text);margin-bottom:12px">This will reset plan #${planId} back to "todo". All non-completed tasks will be set to pending. Agent assignments and token counts will be cleared.</p>
      <div style="display:flex;gap:8px;justify-content:flex-end">
        <button class="preflight-action-btn" style="border-color:var(--text-dim);color:var(--text-dim)" onclick="this.closest('.modal-overlay').remove()">Abort</button>
        <button id="confirm-reset-btn" class="preflight-action-btn" style="border-color:var(--gold);color:var(--gold)">Confirm Reset</button>
      </div>
    </div>
  </div>`;
  document.body.appendChild(overlay);
  overlay.addEventListener("click", (e) => {
    if (e.target === overlay) overlay.remove();
  });
  document
    .getElementById("confirm-reset-btn")
    .addEventListener("click", async () => {
      const res = await fetchJson(`/api/plan/reset?plan_id=${planId}`);
      overlay.remove();
      if (res && res.ok) {
        closeSidebar();
        refreshAll();
      } else {
        showOutputModal("Reset Error", res ? res.error : "Failed");
      }
    });
};
