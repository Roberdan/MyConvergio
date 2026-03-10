(function () {
  const PHASES = ["CAPTURE", "CLARIFY", "RESEARCH", "PLAN", "APPROVE"];
  const byId = (id) => document.getElementById(id);
  const esc = (v) =>
    String(v ?? "").replace(/[&<>"']/g, (m) => ({ "&": "&amp;", "<": "&lt;", ">": "&gt;", '"': "&quot;", "'": "&#39;" })[m]);
  const reqKeyRe = /\b(F-\d{2})\b/g;
  const state = { lastSig: "", sessionId: "", planId: null, plan: null, planAt: 0 };

  const keywords = {
    APPROVE: ["approve", "approved", "go ahead", "ship it", "proceed"],
    PLAN: ["plan", "roadmap", "steps", "task list", "breakdown"],
    RESEARCH: ["research", "investigate", "analyze", "compare", "evaluate", "docs"],
    CLARIFY: ["clarify", "question", "which", "what", "should we", "confirm", "?"],
    CAPTURE: ["add", "create", "build", "implement", "need", "want", "requirement"],
  };
  const priority = ["APPROVE", "PLAN", "RESEARCH", "CLARIFY", "CAPTURE"];

  function activeState() {
    return window.chatTabs?.getActiveState?.() || null;
  }

  function ensureRoot() {
    const panel = document.querySelector("#chat-panel-root .chat-panel");
    if (!panel || byId("chat-context-root")) return;
    panel.insertAdjacentHTML(
      "beforeend",
      `<div id="chat-context-root" class="chat-context">
        <div class="chat-context-grid">
          <section class="chat-context-card">
            <h4>Requirements</h4>
            <div id="chat-req-list" class="chat-context-list"><div class="chat-context-empty">No F-xx items yet.</div></div>
          </section>
          <section class="chat-context-card">
            <h4>Plan Visualization</h4>
            <div id="chat-plan-viz" class="chat-context-list"><div class="chat-context-empty">Plan not generated yet.</div></div>
          </section>
          <section class="chat-context-card">
            <h4>Phase Indicator</h4>
            <div id="chat-phase-indicator" class="chat-phase-indicator">CAPTURE</div>
            <label class="chat-phase-label" for="chat-phase-override">Phase override</label>
            <select id="chat-phase-override" class="chat-select">
              <option value="">auto</option>${PHASES.map((p) => `<option value="${p}">${p}</option>`).join("")}
            </select>
          </section>
          <section class="chat-context-card">
            <h4>GitHub Context</h4>
            <div id="chat-github-panel" class="github-panel"><div class="chat-context-empty">Loading GitHub context...</div></div>
          </section>
          <section class="chat-context-card">
            <h4>Monitor</h4>
            <div id="chat-monitor-root" class="chat-monitor-shell"><div class="chat-context-empty">MONITOR view activates after execution starts.</div></div>
          </section>
        </div>
      </div>`,
    );
    byId("chat-phase-override")?.addEventListener("change", onOverrideChange);
  }

  function detectPhase(messages) {
    if (!Array.isArray(messages) || !messages.length) return "CAPTURE";
    const score = Object.fromEntries(PHASES.map((p) => [p, 0]));
    let userCount = 0;
    messages.forEach((m) => {
      const text = String(m.content || "").toLowerCase();
      if (m.role === "user") userCount += 1;
      Object.entries(keywords).forEach(([phase, words]) => {
        score[phase] += words.reduce((n, w) => n + (text.includes(w) ? 1 : 0), 0);
      });
    });
    if (userCount <= 2) score.CAPTURE += 2;
    if (userCount >= 6) score.PLAN += 1;
    if (userCount >= 8) score.APPROVE += 1;
    const best = Math.max(...Object.values(score));
    return priority.find((p) => score[p] === best) || "CAPTURE";
  }

  function extractRequirements(messages) {
    const found = new Map();
    const all = Array.isArray(messages) ? messages : [];
    all.forEach((m) => {
      const text = String(m.content || "");
      const low = text.toLowerCase();
      const keys = [...text.matchAll(reqKeyRe)].map((x) => x[1]);
      keys.forEach((key) => {
        const prev = found.get(key) || { key, text: "", status: "pending" };
        const item = { ...prev };
        if (!item.text && text) item.text = text;
        if (low.includes(`${key.toLowerCase()} approved`)) item.status = "approved";
        if (low.includes(`${key.toLowerCase()} done`) || low.includes(`${key.toLowerCase()} implemented`)) item.status = "done";
        if (low.includes(`${key.toLowerCase()} delete`) || low.includes(`${key.toLowerCase()} removed`)) item.status = "removed";
        found.set(key, item);
      });
    });
    return [...found.values()].sort((a, b) => a.key.localeCompare(b.key));
  }

  function reqIcon(status) {
    if (status === "approved") return "[~]";
    if (status === "done") return "[ok]";
    if (status === "removed") return "[x]";
    return "[ ]";
  }

  function renderRequirements(messages) {
    const root = byId("chat-req-list");
    if (!root) return;
    const rows = extractRequirements(messages);
    if (!rows.length) {
      root.innerHTML = `<div class="chat-context-empty">No F-xx items yet.</div>`;
      return;
    }
    root.innerHTML = rows
      .map(
        (r) =>
          `<div class="chat-req-row ${esc(r.status)}"><span class="chat-req-key">${esc(r.key)}</span><span class="chat-req-status">${esc(
            reqIcon(r.status),
          )}</span></div><div class="chat-req-text">${esc(r.text)}</div>`,
      )
      .join("");
  }

  async function loadPlan(sid) {
    if (!sid) return null;
    const sessions = await fetch("/api/chat/sessions").then((r) => r.json()).catch(() => ({ sessions: [] }));
    const match = (sessions.sessions || []).find((s) => s.id === sid);
    const pid = Number(match?.plan_id || 0) || null;
    if (!pid) return null;
    if (state.planId === pid && Date.now() - state.planAt < 5000) return state.plan;
    const plan = await fetch(`/api/plan/${pid}`).then((r) => r.json()).catch(() => null);
    state.planId = pid;
    state.plan = plan && plan.plan ? plan : null;
    state.planAt = Date.now();
    return state.plan;
  }

  function renderPlanViz(planData) {
    const root = byId("chat-plan-viz");
    if (!root) return;
    const waves = Array.isArray(planData?.waves) ? planData.waves : [];
    const tasks = Array.isArray(planData?.tasks) ? planData.tasks : [];
    if (!waves.length) {
      root.innerHTML = `<div class="chat-context-empty">Plan not generated yet.</div>`;
      return;
    }
    root.innerHTML = waves
      .map((w) => {
        const waveTasks = tasks.filter((t) => t.wave_id === w.wave_id);
        return `<div class="chat-wave-lane">
          <div class="chat-wave-label">${esc(w.wave_id || "W?")} · ${esc(w.name || "wave")}</div>
          <div class="chat-wave-swim">${waveTasks
            .map((t) => `<span class="chat-task-pill ${esc(t.status || "pending")}">${esc(t.task_id || "T?")}</span>`)
            .join("") || '<span class="chat-context-empty">No tasks</span>'}</div>
        </div>`;
      })
      .join("");
  }

  function updatePhase(messages) {
    const tab = activeState();
    const indicator = byId("chat-phase-indicator");
    const select = byId("chat-phase-override");
    if (!tab || !indicator || !select) return;
    const autoPhase = detectPhase(messages);
    const chosen = tab.phase_override || "";
    const phase = chosen || autoPhase;
    indicator.textContent = phase;
    indicator.className = `chat-phase-indicator phase-${phase.toLowerCase()}`;
    if (select.value !== chosen) select.value = chosen;
    if (!chosen && tab.phase !== autoPhase) window.chatTabs.updateActiveState({ phase: autoPhase });
  }

  function onOverrideChange(event) {
    const value = String(event.target.value || "").toUpperCase();
    if (!window.chatTabs?.updateActiveState) return;
    if (!value) {
      const autoPhase = detectPhase(activeState()?.messages || []);
      window.chatTabs.updateActiveState({ phase_override: "", phase: autoPhase });
      return;
    }
    window.chatTabs.updateActiveState({ phase_override: value, phase: value });
  }

  async function refresh() {
    ensureRoot();
    const tab = activeState();
    if (!tab) return;
    const msgs = Array.isArray(tab.messages) ? tab.messages : [];
    const sig = `${tab.session_id || ""}:${tab.last_id || 0}:${msgs.length}:${tab.phase_override || ""}`;
    if (sig === state.lastSig && tab.session_id === state.sessionId) return;
    state.lastSig = sig;
    state.sessionId = tab.session_id || "";
    renderRequirements(msgs);
    updatePhase(msgs);
    renderPlanViz(await loadPlan(state.sessionId));
  }

  function boot() {
    ensureRoot();
    if (window.PollScheduler) {
      window.PollScheduler.register("chat.context.refresh", refresh, 5000, ["chat"]);
    } else {
      setInterval(refresh, 5000);
    }
    refresh();
    window.chatContext = { renderRequirements, renderPlanViz, refresh };
  }

  if (document.readyState === "loading") document.addEventListener("DOMContentLoaded", boot);
  else boot();
})();
