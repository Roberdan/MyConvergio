(function () {
  const runtime = {
    keepStreaming: false,
    stream: null,
    reconnectTimer: null,
    sending: false,
  };
  const esc = (v) =>
    String(v ?? "").replace(/[&<>"']/g, (m) => ({ "&": "&amp;", "<": "&lt;", ">": "&gt;", '"': "&quot;", "'": "&#39;" })[m]);
  const byId = (id) => document.getElementById(id);
  const setStatus = (msg) => { const el = byId("chat-stream-status"); if (el) el.textContent = msg; };
  const jsonFetch = async (url, opts = {}) => {
    const res = await fetch(url, opts);
    if (!res.ok) throw new Error(`HTTP ${res.status}`);
    return res.json();
  };

  function renderShell() {
    const root = byId("chat-panel-root");
    if (!root) return false;
    root.innerHTML = `
      <div class="chat-panel">
        <div id="chat-tabs-root"></div>
        <div class="chat-controls">
          <div id="repo-selector-root"></div>
          <select id="chat-model-select" class="chat-select" aria-label="Model selector"></select>
          <select id="chat-node-select" class="chat-select" aria-label="Node selector"></select>
          <div id="chat-stream-status" class="chat-status">idle</div>
        </div>
        <div id="chat-messages" class="chat-messages"><div class="chat-empty">Start a chat to stream messages.</div></div>
        <form id="chat-form" class="chat-input-row">
          <input id="chat-input" class="chat-input" type="text" placeholder="Type message and press Enter..." autocomplete="off" />
          <button id="chat-send-btn" class="widget-action-btn chat-send" type="submit">Send</button>
        </form>
      </div>`;
    return true;
  }

  const activeTab = () => window.chatTabs?.getActiveTab() || null, activeState = () => window.chatTabs?.getActiveState() || null;

  function renderMessageList(rows) {
    const box = byId("chat-messages");
    if (!box) return;
    if (!rows.length) {
      box.innerHTML = `<div class="chat-empty">No messages yet.</div>`;
      return;
    }
    box.innerHTML = rows
      .map(
        (m) =>
          `<div class="chat-msg ${esc(m.role || "assistant")}" data-id="${m.id || 0}">${esc(
            m.content || "",
          )}</div>`,
      )
      .join("");
    box.scrollTop = box.scrollHeight;
  }

  function upsertRow(msg) {
    const tabState = activeState();
    if (!tabState || !msg || !msg.id) return;
    const existingStateRow = (tabState.messages || []).find((row) => Number(row.id) === Number(msg.id));
    if (existingStateRow) {
      existingStateRow.content = msg.content || "";
      existingStateRow.role = msg.role || existingStateRow.role;
    } else {
      tabState.messages.push({ id: Number(msg.id), role: msg.role || "assistant", content: msg.content || "" });
      tabState.messages.sort((a, b) => a.id - b.id);
    }
    tabState.last_id = Math.max(Number(tabState.last_id || 0), Number(msg.id || 0));
    const box = byId("chat-messages");
    if (!box) return;
    const existing = box.querySelector(`.chat-msg[data-id="${msg.id}"]`);
    if (existing) {
      existing.textContent = msg.content || "";
      return;
    }
    const row = document.createElement("div");
    row.className = `chat-msg ${msg.role || "assistant"}`;
    row.dataset.id = String(msg.id);
    row.textContent = msg.content || "";
    box.appendChild(row);
    box.scrollTop = box.scrollHeight;
  }

  function closeStream() {
    if (runtime.stream) runtime.stream.close();
    if (runtime.reconnectTimer) clearTimeout(runtime.reconnectTimer);
    runtime.stream = null;
    runtime.reconnectTimer = null;
  }

  function scheduleStream() {
    if (!runtime.keepStreaming) return;
    runtime.reconnectTimer = setTimeout(openStream, 800);
  }

  function openStream() {
    closeStream();
    const tabState = activeState();
    if (!tabState || !tabState.session_id || !runtime.keepStreaming) return;
    setStatus("streaming");
    const url = `/api/chat/stream/${encodeURIComponent(tabState.session_id)}?since=${tabState.last_id || 0}&timeout=25`;
    const es = new EventSource(url);
    es.addEventListener("message", (event) => {
      const msg = JSON.parse(event.data || "{}");
      upsertRow(msg);
    });
    es.addEventListener("done", () => {
      setStatus("idle");
      es.close();
      runtime.stream = null;
      scheduleStream();
    });
    es.onerror = () => {
      setStatus("reconnecting");
      es.close();
      runtime.stream = null;
      scheduleStream();
    };
    runtime.stream = es;
  }

  async function ensureSession() {
    const tabState = activeState();
    if (!tabState) throw new Error("chat tabs not initialized");
    if (tabState.session_id) return tabState.session_id;
    const created = await jsonFetch("/api/chat/session", {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({ title: activeTab()?.title || "Dashboard Chat" }),
    });
    if (!created.ok || !created.session || !created.session.id) throw new Error("session create failed");
    window.chatTabs.updateActiveState({ session_id: created.session.id, last_id: 0, phase: "CAPTURE" });
    return created.session.id;
  }

  async function loadSelects() {
    const modelSelect = byId("chat-model-select");
    const nodeSelector = byId("chat-node-select");
    if (!modelSelect || !nodeSelector) return;
    modelSelect.innerHTML = `<option value="">model:auto</option>`;
    nodeSelector.innerHTML = `<option value="">node:auto</option>`;
    try {
      const models = ((await jsonFetch("/api/chat/models")) || {}).models || [];
      (Array.isArray(models) ? models : []).forEach((model) => {
        const value = typeof model === "string" ? model : model?.model;
        if (!value) return;
        modelSelect.insertAdjacentHTML("beforeend", `<option value="${esc(value)}">${esc(value)}</option>`);
      });
    } catch {
      modelSelect.insertAdjacentHTML("beforeend", `<option value="claude-sonnet-4.6">claude-sonnet-4.6</option>`);
    }
    try {
      const peers = ((await jsonFetch("/api/peers")) || {}).peers || [];
      (Array.isArray(peers) ? peers : []).forEach((p) => {
        const node = p.peer_name || p.name;
        if (!node) return;
        nodeSelector.insertAdjacentHTML("beforeend", `<option value="${esc(node)}">${esc(node)}</option>`);
      });
    } catch {
      nodeSelector.insertAdjacentHTML("beforeend", `<option value="local">local</option>`);
    }
  }

  function syncSelectsFromState() {
    const tabState = activeState();
    if (!tabState) return;
    const model = byId("chat-model-select");
    const node = byId("chat-node-select");
    if (model) model.value = tabState.model || "";
    if (node) node.value = tabState.node || "";
  }

  function onTabSwitch() {
    closeStream();
    runtime.keepStreaming = false;
    const tabState = activeState();
    renderMessageList(tabState?.messages || []);
    if (tabState?.phase === "CAPTURE") window.repoSelector?.syncFromState?.(tabState);
    else window.repoSelector?.hide?.();
    syncSelectsFromState();
    if (tabState?.session_id) { runtime.keepStreaming = true; openStream(); } else setStatus("idle");
  }

  async function submitMessage(event) {
    event.preventDefault();
    if (runtime.sending) return;
    const input = byId("chat-input");
    const text = String(input?.value || "").trim();
    if (!text) return;
    runtime.sending = true;
    byId("chat-send-btn").disabled = true;
    try {
      const sessionId = await ensureSession();
      const tabState = activeState();
      if (!tabState) throw new Error("active tab state missing");
      const model = tabState.model || null;
      const node = tabState.node || null;
      const payload = {
        session_id: sessionId,
        role: "user",
        content: text,
        model,
        metadata: { node, phase: tabState.phase || "CAPTURE", ...(window.repoSelector?.captureMetadata?.(tabState) || {}) },
      };
      const created = await jsonFetch("/api/chat/message", {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify(payload),
      });
      if (!created.ok) throw new Error(created.error || "message create failed");
      const messageId = Number(created.message_id || Date.now());
      tabState.last_id = Math.max(Number(tabState.last_id || 0), messageId);
      tabState.messages.push({ id: messageId, role: "user", content: text });
      tabState.messages.sort((a, b) => a.id - b.id);
      renderMessageList(tabState.messages);
      input.value = "";
      runtime.keepStreaming = true;
      openStream();
    } catch (err) {
      setStatus(`error: ${err.message}`);
    } finally {
      runtime.sending = false;
      byId("chat-send-btn").disabled = false;
    }
  }

  async function initChatPanel() {
    if (!renderShell()) return;
    if (!window.chatTabs) throw new Error("chatTabs manager missing");
    window.chatTabs.init();
    window.chatTabs.onChange((evt) => {
      if (evt.type === "switch" || evt.type === "create" || evt.type === "close") onTabSwitch();
    });
    await loadSelects();
    byId("chat-model-select")?.addEventListener("change", (event) => {
      window.chatTabs.updateActiveState({ model: event.target.value });
    });
    byId("chat-node-select")?.addEventListener("change", (event) => {
      window.chatTabs.updateActiveState({ node: event.target.value });
    });
    byId("chat-form")?.addEventListener("submit", submitMessage);
    window.repoSelector?.init?.({ rootId: "repo-selector-root", getActiveState: activeState, updateActiveState: window.chatTabs.updateActiveState.bind(window.chatTabs) });
    onTabSwitch();
  }

  if (document.readyState === "loading") document.addEventListener("DOMContentLoaded", initChatPanel);
  else initChatPanel();
})();
