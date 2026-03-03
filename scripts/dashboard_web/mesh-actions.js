/**
 * Mesh action toolbar — moved from app.js.
 * XSS-safe: uses data-peer / data-action attributes with event delegation.
 */

window.meshAction = async function (action, peer) {
  if (action === "terminal") {
    if (typeof termMgr !== "undefined") {
      const peers = (typeof lastMeshData !== "undefined" && lastMeshData) || [];
      const peerData = peers.find((p) => p.peer_name === peer);
      const activePlan = peerData
        ? (peerData.plans || []).find(
            (pl) => pl.status === "doing" || pl.status === "todo",
          )
        : null;
      const tmuxSession = "Convergio";
      termMgr.open(peer, peer, tmuxSession);
    }
    return;
  }
  if (action === "movehere") {
    showMovePlanDialog(peer);
    return;
  }
  // Stream all other actions via SSE
  streamMeshAction(action, peer);
};

/**
 * Stream a mesh action via SSE with live output modal.
 */
window.streamMeshAction = function (action, peer) {
  const esc = (s) => {
    const d = document.createElement("div");
    d.textContent = s;
    return d.innerHTML;
  };
  const actionLabels = {
    sync: "Sync Config",
    heartbeat: "Heartbeat Status",
    auth: "Auth Sync",
    status: "Load Status",
    wake: "Wake-on-LAN",
    reboot: "SSH Reboot",
  };
  const target = peer === "__all__" ? "All Peers" : peer;
  const title = `${actionLabels[action] || action} — ${target}`;

  const overlay = document.createElement("div");
  overlay.className = "modal-overlay";
  overlay.innerHTML = `<div class="modal-box" style="max-width:650px">
    <div class="modal-title">${esc(title)}<span class="modal-close" onclick="this.closest('.modal-overlay').remove()">✕</span></div>
    <pre class="modal-output" id="mesh-action-output" style="min-height:150px"></pre>
  </div>`;
  document.body.appendChild(overlay);
  overlay.addEventListener("click", (e) => {
    if (e.target === overlay) overlay.remove();
  });

  const output = document.getElementById("mesh-action-output");
  const url = `/api/mesh/action/stream?action=${encodeURIComponent(action)}&peer=${encodeURIComponent(peer)}`;
  const es = new EventSource(url);

  es.addEventListener("log", (e) => {
    const line = e.data || "";
    const hasAnsi = /\x1b\[/.test(line);
    let html;
    if (hasAnsi) {
      html = ansiToHtml(line);
    } else if (line.startsWith("▶")) {
      html = `<span style="color:var(--cyan)">${esc(line)}</span>`;
    } else if (/^(OK|PASS|✓|MATCH|synced|pushed|done)/i.test(line)) {
      html = `<span style="color:var(--green)">${esc(line)}</span>`;
    } else if (/^(WARN|SKIP|MISMATCH)/i.test(line)) {
      html = `<span style="color:var(--gold)">${esc(line)}</span>`;
    } else if (/^(ERROR|FAIL|✗)/i.test(line)) {
      html = `<span style="color:var(--red)">${esc(line)}</span>`;
    } else if (line.startsWith("---") || line.startsWith("===")) {
      html = `<span style="color:var(--cyan);font-weight:600">${esc(line)}</span>`;
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
      output.innerHTML += `\n<span style="color:var(--green);font-weight:600">✓ Completed successfully</span>\n`;
    } else {
      const msg = data.message || `Exit code ${data.exit_code || "?"}`;
      output.innerHTML += `\n<span style="color:var(--red);font-weight:600">✗ ${esc(msg)}</span>\n`;
    }
    output.scrollTop = output.scrollHeight;
    if (typeof refreshAll === "function") refreshAll();
  });

  es.onerror = () => {
    es.close();
    output.innerHTML += `\n<span style="color:var(--red)">✗ Connection lost</span>\n`;
  };
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

function ansiToHtml(raw) {
  if (!raw) return "";
  const colorMap = {
    30: "#0a0e1a",
    31: "#ff3355",
    32: "#00ff88",
    33: "#ffb700",
    34: "#00e5ff",
    35: "#ff2daa",
    36: "#00e5ff",
    37: "#c8d0e8",
    90: "#5a6080",
    91: "#ff5577",
    92: "#33ff99",
    93: "#ffd044",
    94: "#44eeff",
    95: "#ff55cc",
    96: "#44eeff",
    97: "#e0e4f0",
  };
  const esc = (s) => {
    const d = document.createElement("div");
    d.textContent = s;
    return d.innerHTML;
  };
  let html = "";
  let open = false;
  const parts = raw.split(/(\x1b\[[0-9;]*m)/);
  for (const part of parts) {
    const m = part.match(/^\x1b\[([0-9;]*)m$/);
    if (m) {
      const codes = m[1].split(";");
      if (codes.includes("0") || m[1] === "") {
        if (open) html += "</span>";
        open = false;
      } else {
        if (open) html += "</span>";
        let color = null;
        let bold = false;
        for (const c of codes) {
          if (c === "1") bold = true;
          if (colorMap[c]) color = colorMap[c];
        }
        if (color) {
          html += `<span style="color:${color}${bold ? ";font-weight:600" : ""}">`;
          open = true;
        }
      }
    } else {
      html += esc(part);
    }
  }
  if (open) html += "</span>";
  return html;
}
window.showOutputModal = function (title, text) {
  const esc = (s) => {
    const d = document.createElement("div");
    d.textContent = s;
    return d.innerHTML;
  };
  const overlay = document.createElement("div");
  overlay.className = "modal-overlay";
  const hasAnsi = /\x1b\[/.test(text);
  const body = hasAnsi ? ansiToHtml(text) : esc(text);
  overlay.innerHTML = `<div class="modal-box">
    <div class="modal-title">${esc(title)}<span class="modal-close" onclick="this.closest('.modal-overlay').remove()">\u2715</span></div>
    <pre class="modal-output">${body}</pre>
  </div>`;
  document.body.appendChild(overlay);
  overlay.addEventListener("click", (e) => {
    if (e.target === overlay) overlay.remove();
  });
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
  const esc = (s) => {
    const d = document.createElement("div");
    d.textContent = s;
    return d.innerHTML;
  };
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
      // Show CLI selector before preflight
      _showCliSelector(planId, peer, planName, overlay);
      return;
    }
    if (e.target === overlay) overlay.remove();
  });
};

function _showCliSelector(planId, peer, planName, prevOverlay) {
  const esc = (s) => { const d = document.createElement("div"); d.textContent = s; return d.innerHTML; };
  if (prevOverlay) prevOverlay.remove();
  const overlay = document.createElement("div");
  overlay.className = "modal-overlay";
  overlay.innerHTML = `<div class="modal-box" style="max-width:420px">
    <div class="modal-title">Execute with → ${esc(peer)}<span class="modal-close" onclick="this.closest('.modal-overlay').remove()">✕</span></div>
    <div style="padding:14px;display:flex;flex-direction:column;gap:8px">
      <button class="cli-choice-btn" data-cli="copilot" style="display:flex;align-items:center;gap:10px;padding:12px 16px;background:rgba(0,229,255,0.06);border:1px solid rgba(0,229,255,0.25);border-radius:8px;color:var(--cyan);cursor:pointer;font-size:13px;font-weight:600;text-align:left">
        <span style="font-size:20px">🤖</span>
        <span><div>GitHub Copilot</div><div style="font-size:10px;font-weight:400;color:var(--text-dim);margin-top:2px">copilot -p '/execute ${planId}'</div></span>
      </button>
      <button class="cli-choice-btn" data-cli="claude" style="display:flex;align-items:center;gap:10px;padding:12px 16px;background:rgba(255,160,0,0.06);border:1px solid rgba(255,160,0,0.25);border-radius:8px;color:var(--gold);cursor:pointer;font-size:13px;font-weight:600;text-align:left">
        <span style="font-size:20px">🧠</span>
        <span><div>Claude Code</div><div style="font-size:10px;font-weight:400;color:var(--text-dim);margin-top:2px">claude --model sonnet -p '/execute ${planId}'</div></span>
      </button>
      <button class="cli-choice-btn" data-cli="opencode" style="display:flex;align-items:center;gap:10px;padding:12px 16px;background:rgba(140,140,140,0.06);border:1px solid rgba(140,140,140,0.25);border-radius:8px;color:var(--text-dim);cursor:pointer;font-size:13px;font-weight:600;text-align:left">
        <span style="font-size:20px">⚡</span>
        <span><div>OpenCode / Other</div><div style="font-size:10px;font-weight:400;color:var(--text-dim);margin-top:2px">opencode -p '/execute ${planId}'</div></span>
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
}

/**
 * Pre-delegation checks via SSE — shows each check appearing in real-time.
 */
window.runPreflight = function (planId, targetPeer, planName, prevOverlay, cli) {
  const esc = (s) => {
    const d = document.createElement("div");
    d.textContent = s;
    return d.innerHTML;
  };
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
      // Update existing row to show auto-fix in progress
      activeRow.querySelector(".preflight-name").textContent = name;
      activeRow.querySelector(".preflight-detail").textContent = "fixing…";
      activeRow.querySelector(".preflight-detail").style.color = "var(--gold)";
    } else {
      // New check row
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
      const icon = ok ? "✓" : "✗";
      const cls = ok ? "delegate-status-ok" : "delegate-status-fail";
      activeRow.classList.add(ok ? "preflight-pass" : "preflight-fail");
      activeRow.querySelector(".preflight-icon").innerHTML = `<span class="${cls}" style="font-size:16px;font-weight:700">${icon}</span>`;
      activeRow.querySelector(".preflight-name").textContent = data.name;
      const detailEl = activeRow.querySelector(".preflight-detail");
      detailEl.textContent = data.detail;
      detailEl.style.color = ok ? "var(--green)" : "var(--red)";
      if (!ok) {
        detailEl.style.fontWeight = "600";
      }
      activeRow = null;
    }
  });

  es.addEventListener("done", (e) => {
    es.close();
    const data = JSON.parse(e.data);
    actionsEl.style.display = "block";
    if (data.ok) {
      actionsEl.innerHTML = `<div class="delegate-done-banner" style="background:rgba(0,229,255,0.08);border-color:rgba(0,229,255,0.3);color:var(--cyan);margin-bottom:12px">
          ✓ All checks passed
        </div>
        <button id="preflight-go-btn" style="background:linear-gradient(135deg,var(--cyan),#00ff88);color:#0a0e1a;border:none;padding:10px 32px;border-radius:6px;font-weight:700;font-size:13px;cursor:pointer;letter-spacing:1px">
          DELEGATE NOW
        </button>`;
      document.getElementById("preflight-go-btn").addEventListener("click", () => {
        overlay.remove();
        delegatePlan(planId, targetPeer, planName, cli);
      });
    } else {
      // Count failures
      const failCount = checksEl.querySelectorAll(".preflight-fail").length;
      actionsEl.innerHTML = `<div class="delegate-status-fail" style="padding:10px;border:1px solid var(--red);border-radius:6px;margin-bottom:12px">
          ✗ ${failCount} check${failCount > 1 ? "s" : ""} failed — fix before delegating
        </div>
        <div style="display:flex;gap:8px;justify-content:center">
          <button id="preflight-retry-btn" class="preflight-action-btn" style="border-color:var(--cyan);color:var(--cyan)">RETRY CHECKS</button>
          <button id="preflight-sync-btn" class="preflight-action-btn" style="border-color:var(--gold);color:var(--gold)">SYNC &amp; RETRY</button>
        </div>`;
      document.getElementById("preflight-retry-btn").addEventListener("click", () => {
        overlay.remove();
        runPreflight(planId, targetPeer, planName, null, cli);
      });
      document.getElementById("preflight-sync-btn").addEventListener("click", async () => {
        const btn = document.getElementById("preflight-sync-btn");
        btn.textContent = "Syncing…";
        btn.disabled = true;
        await fetchJson(`/api/mesh/action?action=sync&peer=${encodeURIComponent(targetPeer)}`);
        overlay.remove();
        runPreflight(planId, targetPeer, planName, null, cli);
      });
    }
  });

  es.onerror = () => {
    es.close();
    if (activeRow) {
      activeRow.querySelector(".preflight-icon").innerHTML = '<span class="delegate-status-fail" style="font-size:16px;font-weight:700">✗</span>';
      activeRow.querySelector(".preflight-detail").textContent = "Connection lost";
    }
    actionsEl.style.display = "block";
    actionsEl.innerHTML = `<button id="preflight-retry-btn" class="preflight-action-btn" style="border-color:var(--cyan);color:var(--cyan)">RETRY</button>`;
    document.getElementById("preflight-retry-btn").addEventListener("click", () => {
      overlay.remove();
      runPreflight(planId, targetPeer, planName, null, cli);
    });
  };
};

/**
 * Execute plan delegation via SSE streaming — shows live progress modal.
 */
window.delegatePlan = function (planId, targetPeer, planName, cli) {
  const esc = (s) => {
    const d = document.createElement("div");
    d.textContent = s;
    return d.innerHTML;
  };
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
    // Visual separator between major phases
    output.innerHTML += `<div style="margin:4px 0;border-top:1px solid var(--border)"></div>`;
  });

  es.addEventListener("log", (e) => {
    const line = e.data || "";
    const hasAnsi = /\x1b\[/.test(line);
    let html;
    if (hasAnsi) {
      // Strip ANSI first to test patterns, then render with colors
      const stripped = line.replace(/\x1b\[[0-9;]*m/g, "");
      if (stripped.startsWith("━━━") || stripped.startsWith("--- PHASE") || stripped.startsWith("=== ")) {
        html = `<div class="delegate-phase-header">${ansiToHtml(line)}</div>`;
      } else {
        html = ansiToHtml(line) + "\n";
      }
    } else if (line.startsWith("━━━")) {
      html = `<div class="delegate-phase-header">${esc(line)}</div>`;
    } else if (line.startsWith("--- PHASE")) {
      html = `<div class="delegate-phase-header">${esc(line)}</div>`;
    } else if (line.startsWith("▶")) {
      html = `<span style="color:var(--cyan)">${esc(line)}</span>\n`;
    } else if (/^(OK|PASS|✓|✓ )/.test(line) || line.includes("started on") || line.includes("Sync completed")) {
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
      output.innerHTML += `<div class="delegate-done-banner">✓ Plan #${planId} delegated to ${esc(targetPeer)}<br><span style="font-size:11px;font-weight:400">tmux session: Convergio</span></div>`;
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
    output.innerHTML += `<div class="delegate-status-fail" style="padding:12px;margin-top:8px;border:1px solid var(--red);border-radius:4px">✗ ${esc(msg)}</div>`;
    // Add retry button on failure
    output.innerHTML += `<div style="text-align:center;margin-top:12px">
      <button id="delegate-retry-btn" style="background:transparent;border:1px solid var(--cyan);color:var(--cyan);padding:8px 24px;border-radius:6px;cursor:pointer;font-weight:600;font-size:12px;letter-spacing:0.5px">RETRY DELEGATION</button>
    </div>`;
    const retryBtn = document.getElementById("delegate-retry-btn");
    if (retryBtn) {
      retryBtn.addEventListener("click", () => {
        overlay.remove();
        delegatePlan(planId, targetPeer, planName, cli);
      });
    }
    output.scrollTop = output.scrollHeight;
  });

  es.onerror = () => {
    es.close();
    output.innerHTML += `<span class="delegate-status-fail">\n✗ Connection lost\n</span>`;
    output.innerHTML += `<div style="text-align:center;margin-top:12px">
      <button id="delegate-retry-btn2" style="background:transparent;border:1px solid var(--cyan);color:var(--cyan);padding:8px 24px;border-radius:6px;cursor:pointer;font-weight:600;font-size:12px;letter-spacing:0.5px">RETRY</button>
    </div>`;
    const retryBtn = document.getElementById("delegate-retry-btn2");
    if (retryBtn) {
      retryBtn.addEventListener("click", () => {
        overlay.remove();
        delegatePlan(planId, targetPeer, planName, cli);
      });
    }
  };
};

// Event delegation for .mn-act-btn — uses data-peer / data-action (XSS-safe)
document.addEventListener("click", (e) => {
  const btn = e.target.closest(".mn-act-btn");
  if (btn) {
    e.stopPropagation();
    meshAction(btn.dataset.action, btn.dataset.peer);
  }
});
