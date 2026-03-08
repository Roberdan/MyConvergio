(function () {
  const esc = (v) =>
    String(v ?? "").replace(/[&<>"']/g, (m) => ({ "&": "&amp;", "<": "&lt;", ">": "&gt;", '"': "&quot;", "'": "&#39;" })[m]);

  class ChatTabsManager {
    constructor(rootId = "chat-tabs-root") {
      this.rootId = rootId;
      this.tabs = [];
      this.activeId = null;
      this.nextId = 1;
      this.listeners = new Set();
      this.boundRoot = null;
    }

    init() {
      this._build();
      if (!this.tabs.length) this.createTab();
      return this;
    }

    createTab(seed = {}) {
      const id = this.nextId++;
      const tab = {
        id,
        title: seed.title || `Chat ${id}`,
        state: {
          session_id: seed.session_id || "",
          phase: seed.phase || "CAPTURE",
          model: seed.model || "",
          node: seed.node || "",
          messages: Array.isArray(seed.messages) ? seed.messages : [],
          last_id: Number(seed.last_id || 0),
        },
      };
      this.tabs.push(tab);
      this.switchTab(id);
      this._emit("create", tab);
      return tab;
    }

    closeTab(id) {
      const idx = this.tabs.findIndex((t) => t.id === id);
      if (idx === -1) return null;
      const [removed] = this.tabs.splice(idx, 1);
      if (!this.tabs.length) {
        this.createTab();
      } else if (this.activeId === id) {
        this.switchTab(this.tabs[Math.min(idx, this.tabs.length - 1)].id);
      } else {
        this._render();
      }
      this._emit("close", removed);
      return removed;
    }

    switchTab(id) {
      const tab = this.tabs.find((t) => t.id === id);
      if (!tab) return null;
      this.activeId = id;
      this._render();
      this._emit("switch", tab);
      return tab;
    }

    renameTab(id, title) {
      const tab = this.tabs.find((t) => t.id === id);
      const nextTitle = String(title || "").trim();
      if (!tab || !nextTitle) return null;
      tab.title = nextTitle;
      this._render();
      this._emit("rename", tab);
      return tab;
    }

    getTab(id) {
      return this.tabs.find((t) => t.id === id) || null;
    }

    getActiveTab() {
      return this.getTab(this.activeId);
    }

    getActiveState() {
      return this.getActiveTab()?.state || null;
    }

    updateActiveState(patch = {}) {
      const state = this.getActiveState();
      if (!state) return null;
      Object.assign(state, patch);
      this._emit("state", this.getActiveTab());
      return state;
    }

    onChange(cb) {
      this.listeners.add(cb);
      return () => this.listeners.delete(cb);
    }

    _emit(type, tab) {
      this.listeners.forEach((cb) => cb({ type, tab, manager: this }));
    }

    _build() {
      const root = document.getElementById(this.rootId);
      if (!root) return;
      if (this.boundRoot !== root) {
        root.addEventListener("click", (event) => {
          const tabEl = event.target.closest(".chat-tab");
          const id = Number(tabEl?.dataset.tabId || 0);
          if (event.target.closest(".chat-tab-close")) {
            event.stopPropagation();
            this.closeTab(id);
            return;
          }
          if (event.target.closest(".chat-tab-rename")) {
            event.stopPropagation();
            const current = this.getTab(id);
            if (!current) return;
            const next = window.prompt("Rename chat tab", current.title);
            if (next) this.renameTab(id, next);
            return;
          }
          if (event.target.closest(".chat-tab-add")) {
            this.createTab();
            return;
          }
          if (id) this.switchTab(id);
        });
        root.addEventListener("dblclick", (event) => {
          const tabEl = event.target.closest(".chat-tab");
          const id = Number(tabEl?.dataset.tabId || 0);
          const current = this.getTab(id);
          if (!current) return;
          const next = window.prompt("Rename chat tab", current.title);
          if (next) this.renameTab(id, next);
        });
        this.boundRoot = root;
      }
      this._render();
    }

    _render() {
      const root = document.getElementById(this.rootId);
      if (!root) return;
      root.innerHTML = `
        <div class="chat-tabbar">
          <div class="chat-tabs">
            ${this.tabs
              .map(
                (t) => `<button class="chat-tab ${t.id === this.activeId ? "active" : ""}" data-tab-id="${t.id}" type="button">
                  <span class="chat-tab-title">${esc(t.title)}</span>
                  <span class="chat-tab-rename" title="Rename tab">&#9998;</span>
                  <span class="chat-tab-close" title="Close tab">&times;</span>
                </button>`,
              )
              .join("")}
          </div>
          <button class="chat-tab-add widget-action-btn" type="button" aria-label="New tab">+ New</button>
        </div>`;
    }
  }

  const manager = new ChatTabsManager().init();
  window.chatTabs = manager;
})();
