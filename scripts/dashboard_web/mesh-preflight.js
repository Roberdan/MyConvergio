/**
 * Mesh preflight checks and delegation execution.
 * Depends on: mesh-actions.js (ansiToHtml, showOutputModal loaded first)
 */

/**
 * Pre-delegation checks via SSE — shows each check appearing in real-time.
 */
window.runPreflight = function (
  planId,
  targetPeer,
  planName,
  prevOverlay,
  cli,
) {
  if (prevOverlay) prevOverlay.remove();

  const overlay = document.createElement("div");
  overlay.className = "modal-overlay";
  overlay.innerHTML = `<div class="modal-box" style="max-width:600px">
    <div class="modal-title">Pre-flight: #${planId} → ${esc(targetPeer)}<span class="modal-close" onclick="this.closest('.modal-overlay').remove()">✕</span></div>
    <div id="preflight-checks" style="padding:14px;overflow-y:auto;flex:1;min-height:0"></div>
    <div id="preflight-actions" style="padding:10px 14px 14px;text-align:center;display:none;flex-shrink:0"></div>
  </div>`;
  document.body.appendChild(overlay);
  overlay.addEventListener("click", (e) => {
    if (e.target === overlay) overlay.remove();
  });

  const checksEl = document.getElementById("preflight-checks");
  const actionsEl = document.getElementById("preflight-actions");
  let activeRow = null;

  const url = `/api/plan/preflight?plan_id=${planId}&target=${encodeURIComponent(targetPeer)}`;
  const es = new EventSource(url);

  es.addEventListener("checking", (e) => {
    const data = JSON.parse(e.data);
    const name = data.name;
    const isAutofix = name.includes("—");
    if (isAutofix && activeRow) {
      activeRow.querySelector(".preflight-name").textContent = name;
      activeRow.querySelector(".preflight-detail").textContent = "fixing…";
      activeRow.querySelector(".preflight-detail").style.color = "var(--gold)";
    } else {
      const row = document.createElement("div");
      row.className = "preflight-row preflight-active";
      row.innerHTML = `<span class="preflight-icon"><span class="spinner" style="width:14px;height:14px;border-width:2px"></span></span>
        <span class="preflight-name">${esc(name)}</span>
        <span class="preflight-detail" style="color:var(--text-dim)">checking…</span>`;
      checksEl.appendChild(row);
      activeRow = row;
    }
  });

  es.addEventListener("check", (e) => {
    const data = JSON.parse(e.data);
    if (activeRow) {
      activeRow.classList.remove("preflight-active");
      const ok = data.ok;
      const icon = ok ? Icons.check(14) : Icons.x(14);
      const cls = ok ? "delegate-status-ok" : "delegate-status-fail";
      activeRow.classList.add(ok ? "preflight-pass" : "preflight-fail");
      activeRow.querySelector(".preflight-icon").innerHTML =
        `<span class="${cls}" style="font-size:16px;font-weight:700">${ok ? Icons.check(16) : Icons.x(16)}</span>`;
      activeRow.querySelector(".preflight-name").textContent = data.name;
      const detailEl = activeRow.querySelector(".preflight-detail");
      detailEl.textContent = data.detail;
      detailEl.style.color = ok ? "var(--green)" : "var(--red)";
      if (!ok) detailEl.style.fontWeight = "600";
      activeRow = null;
    }
  });

  es.addEventListener("done", (e) => {
    es.close();
    const data = JSON.parse(e.data);
    actionsEl.style.display = "block";
    if (data.ok) {
      actionsEl.innerHTML = `<div class="delegate-done-banner" style="background:rgba(0,229,255,0.08);border-color:rgba(0,229,255,0.3);color:var(--cyan);margin-bottom:12px">
          ${Icons.checkCircle(14)} All checks passed
        </div>
        <button id="preflight-go-btn" style="background:linear-gradient(135deg,var(--cyan),#00ff88);color:#0a0e1a;border:none;padding:10px 32px;border-radius:6px;font-weight:700;font-size:13px;cursor:pointer;letter-spacing:1px">
          DELEGATE NOW
        </button>`;
      document
        .getElementById("preflight-go-btn")
        .addEventListener("click", () => {
          overlay.remove();
          delegatePlan(planId, targetPeer, planName, cli);
        });
    } else {
      const failCount = checksEl.querySelectorAll(".preflight-fail").length;
      actionsEl.innerHTML = `<div class="delegate-status-fail" style="padding:10px;border:1px solid var(--red);border-radius:6px;margin-bottom:12px">
          ${Icons.xCircle(14)} ${failCount} check${failCount > 1 ? "s" : ""} failed — fix before delegating
        </div>
        <div style="display:flex;gap:8px;justify-content:center">
          <button id="preflight-retry-btn" class="preflight-action-btn" style="border-color:var(--cyan);color:var(--cyan)">RETRY CHECKS</button>
          <button id="preflight-sync-btn" class="preflight-action-btn" style="border-color:var(--gold);color:var(--gold)">SYNC &amp; RETRY</button>
        </div>`;
      document
        .getElementById("preflight-retry-btn")
        .addEventListener("click", () => {
          overlay.remove();
          runPreflight(planId, targetPeer, planName, null, cli);
        });
      document
        .getElementById("preflight-sync-btn")
        .addEventListener("click", async () => {
          const btn = document.getElementById("preflight-sync-btn");
          btn.textContent = "Syncing…";
          btn.disabled = true;
          await fetchJson(
            `/api/mesh/action?action=sync&peer=${encodeURIComponent(targetPeer)}`,
          );
          overlay.remove();
          runPreflight(planId, targetPeer, planName, null, cli);
        });
    }
  });

  es.onerror = () => {
    es.close();
    if (activeRow) {
      activeRow.querySelector(".preflight-icon").innerHTML =
        '<span class="delegate-status-fail" style="font-size:16px;font-weight:700">' + Icons.x(16) + '</span>';
      activeRow.querySelector(".preflight-detail").textContent =
        "Connection lost";
    }
    actionsEl.style.display = "block";
    actionsEl.innerHTML = `<button id="preflight-retry-btn" class="preflight-action-btn" style="border-color:var(--cyan);color:var(--cyan)">RETRY</button>`;
    document
      .getElementById("preflight-retry-btn")
      .addEventListener("click", () => {
        overlay.remove();
        runPreflight(planId, targetPeer, planName, null, cli);
      });
  };
};

/**
 * Execute plan delegation via SSE streaming — shows live progress modal.
 */
window.delegatePlan = function (planId, targetPeer, planName, cli) {
  const overlay = document.createElement("div");
  overlay.className = "modal-overlay";
  overlay.innerHTML = `<div class="modal-box" style="max-width:650px">
    <div class="modal-title">Delegating #${planId} → ${esc(targetPeer)}<span class="modal-close" onclick="this.closest('.modal-overlay').remove()">✕</span></div>
    <pre class="modal-output" id="delegate-output" style="max-height:450px;overflow:auto;font-size:12px;min-height:200px"></pre>
  </div>`;
  document.body.appendChild(overlay);
  overlay.addEventListener("click", (e) => {
    if (e.target === overlay) overlay.remove();
  });

  const output = document.getElementById("delegate-output");
  const url = `/api/plan/delegate?plan_id=${planId}&target=${encodeURIComponent(targetPeer)}&cli=${encodeURIComponent(cli || "copilot")}`;
  const es = new EventSource(url);

  es.addEventListener("phase", (e) => {
    const phase = JSON.parse(e.data);
    output.innerHTML += `<div style="margin:4px 0;border-top:1px solid var(--border)"></div>`;
  });

  es.addEventListener("log", (e) => {
    const line = e.data || "";
    const hasAnsi = /\x1b\[/.test(line);
    let html;
    if (hasAnsi) {
      const stripped = line.replace(/\x1b\[[0-9;]*m/g, "");
      if (
        stripped.startsWith("━━━") ||
        stripped.startsWith("--- PHASE") ||
        stripped.startsWith("=== ")
      ) {
        html = `<div class="delegate-phase-header">${ansiToHtml(line)}</div>`;
      } else {
        html = ansiToHtml(line) + "\n";
      }
    } else if (line.startsWith("━━━") || line.startsWith("--- PHASE")) {
      html = `<div class="delegate-phase-header">${esc(line)}</div>`;
    } else if (line.startsWith("▶")) {
      html = `<span style="color:var(--cyan)">${esc(line)}</span>\n`;
    } else if (
      /^(OK|PASS|✓|✓ )/.test(line) ||
      line.includes("started on") ||
      line.includes("Sync completed")
    ) {
      html = `<span class="delegate-status-ok">${esc(line)}</span>\n`;
    } else if (/^(WARN|⚠)/.test(line)) {
      html = `<span class="delegate-status-warn">${esc(line)}</span>\n`;
    } else if (/^(ERROR|FAIL)/.test(line)) {
      html = `<span class="delegate-status-fail">${esc(line)}</span>\n`;
    } else {
      html = esc(line) + "\n";
    }
    output.innerHTML += html;
    output.scrollTop = output.scrollHeight;
  });

  es.addEventListener("done", (e) => {
    es.close();
    const data = JSON.parse(e.data);
    if (data.ok) {
      output.innerHTML += `<div class="delegate-done-banner">${Icons.checkCircle(14)} Plan #${planId} delegated to ${esc(targetPeer)}<br><span style="font-size:11px;font-weight:400">tmux session: Convergio</span></div>`;
    }
    output.scrollTop = output.scrollHeight;
    if (typeof refreshAll === "function") refreshAll();
  });

  es.addEventListener("error", (e) => {
    es.close();
    let msg = "Delegation failed";
    try {
      const data = JSON.parse(e.data);
      msg = data.message || msg;
    } catch (_) {}
    output.innerHTML += `<div class="delegate-status-fail" style="padding:12px;margin-top:8px;border:1px solid var(--red);border-radius:4px">${Icons.xCircle(14)} ${esc(msg)}</div>`;
    output.innerHTML += `<div style="text-align:center;margin-top:12px"><button id="delegate-retry-btn" style="background:transparent;border:1px solid var(--cyan);color:var(--cyan);padding:8px 24px;border-radius:6px;cursor:pointer;font-weight:600;font-size:12px;letter-spacing:0.5px">RETRY DELEGATION</button></div>`;
    const retryBtn = document.getElementById("delegate-retry-btn");
    if (retryBtn)
      retryBtn.addEventListener("click", () => {
        overlay.remove();
        delegatePlan(planId, targetPeer, planName, cli);
      });
    output.scrollTop = output.scrollHeight;
  });

  es.onerror = () => {
    es.close();
    output.innerHTML += `<span class="delegate-status-fail">\n${Icons.x(14)} Connection lost\n</span>`;
    output.innerHTML += `<div style="text-align:center;margin-top:12px"><button id="delegate-retry-btn2" style="background:transparent;border:1px solid var(--cyan);color:var(--cyan);padding:8px 24px;border-radius:6px;cursor:pointer;font-weight:600;font-size:12px;letter-spacing:0.5px">RETRY</button></div>`;
    const retryBtn = document.getElementById("delegate-retry-btn2");
    if (retryBtn)
      retryBtn.addEventListener("click", () => {
        overlay.remove();
        delegatePlan(planId, targetPeer, planName, cli);
      });
  };
};
