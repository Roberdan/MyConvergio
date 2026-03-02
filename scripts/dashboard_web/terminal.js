/**
 * Convergio Control Room — Real Terminal Manager.
 * xterm.js + WebSocket + PTY. Dock / Float / Fullscreen modes.
 */

/* global Terminal, FitAddon */

const TERM_WS_PORT = 8421;

class TerminalManager {
  constructor() {
    this.tabs = [];
    this.activeId = null;
    this.mode = "dock";
    this.visible = false;
    this.nextId = 0;
    this.container = null;
    this.dragState = null;
  }

  init() {
    this._build();
    window.addEventListener("resize", () => this._fitActive());
  }

  open(peer, label) {
    if (!this.container || !document.body.contains(this.container)) {
      this._build();
    }
    if (!this.visible) this.show();
    this.addTab(peer || "local", label || peer || "local");
  }

  show() {
    this.visible = true;
    this.container.style.display = ""; // show: display before .open to prevent transition race
    this.container.classList.add("open");
    document.body.classList.add("term-open");
    setTimeout(() => this._fitActive(), 100);
  }

  hide() {
    this.visible = false;
    this.container.classList.remove("open");
    document.body.classList.remove("term-open");
    setTimeout(() => {
      if (!this.visible) this.container.style.display = "none";
    }, 300);
  }

  close() {
    this.tabs.forEach((t) => this._destroyTab(t));
    this.tabs = [];
    this.hide();
    this.activeId = null; // close: reset to prevent stale reference on reopen
    this._renderTabs();
  }

  addTab(peer, label) {
    const id = this.nextId++;
    const el = document.createElement("div");
    el.className = "term-pane";
    el.id = `term-pane-${id}`;
    el.style.display = "none";
    document.getElementById("term-body").appendChild(el);

    const term = new Terminal({
      theme: {
        background: "#04060e",
        foreground: "#c8d0e8",
        cursor: "#00e5ff",
        cursorAccent: "#04060e",
        selectionBackground: "rgba(0,229,255,0.25)",
        black: "#0a0e1a",
        red: "#ff3355",
        green: "#00ff88",
        yellow: "#ffb700",
        blue: "#00e5ff",
        magenta: "#ff2daa",
        cyan: "#00e5ff",
        white: "#c8d0e8",
        brightBlack: "#5a6080",
        brightRed: "#ff5577",
        brightGreen: "#33ff99",
        brightYellow: "#ffd044",
        brightBlue: "#44eeff",
        brightMagenta: "#ff55cc",
        brightCyan: "#44eeff",
        brightWhite: "#e0e4f0",
      },
      fontFamily: '"JetBrainsMono Nerd Font", "JetBrains Mono", monospace',
      fontSize: 13,
      cursorBlink: true,
      allowProposedApi: true,
      scrollback: 10000,
    });

    const fitAddon = new FitAddon.FitAddon();
    term.loadAddon(fitAddon);

    const wsUrl = `ws://localhost:${TERM_WS_PORT}/ws?peer=${encodeURIComponent(peer)}`;
    const ws = new WebSocket(wsUrl);
    ws.binaryType = "arraybuffer";

    const tab = { id, label, peer, term, ws, fitAddon, el };

    ws.onopen = () => {
      term.open(el);
      fitAddon.fit();
      ws.send(
        JSON.stringify({ type: "resize", cols: term.cols, rows: term.rows }),
      );
      term.write(`\x1b[1;36m◈ Connected to ${peer}\x1b[0m\r\n`);
    };

    ws.onmessage = (evt) => {
      if (evt.data instanceof ArrayBuffer) {
        term.write(new Uint8Array(evt.data));
      } else {
        term.write(evt.data);
      }
    };

    ws.onerror = () => {
      term.write(
        "\x1b[1;31m✗ WebSocket error — is terminal_server.py running?\x1b[0m\r\n",
      );
    };

    ws.onclose = () => {
      term.write("\r\n\x1b[2m[session ended]\x1b[0m\r\n");
      this.removeTab(id); // ws.onclose: F-08 auto-clean dead tab
    };

    term.onData((data) => {
      if (ws.readyState === WebSocket.OPEN) {
        const enc = new TextEncoder();
        ws.send(enc.encode(data));
      }
    });

    term.onResize(({ cols, rows }) => {
      if (ws.readyState === WebSocket.OPEN) {
        ws.send(JSON.stringify({ type: "resize", cols, rows }));
      }
    });

    this.tabs.push(tab);
    this._renderTabs();
    this.switchTab(id);
    return id;
  }

  removeTab(id) {
    const idx = this.tabs.findIndex((t) => t.id === id);
    if (idx === -1) return;
    this._destroyTab(this.tabs[idx]);
    this.tabs.splice(idx, 1);
    if (this.tabs.length === 0) {
      this.close();
      return;
    }
    if (this.activeId === id) {
      this.switchTab(this.tabs[Math.min(idx, this.tabs.length - 1)].id);
    }
    this._renderTabs();
  }

  switchTab(id) {
    this.activeId = id;
    if (this.mode !== "grid") {
      this.tabs.forEach((t) => {
        t.el.style.display = t.id === id ? "" : "none";
      });
    }
    this._renderTabs();
    setTimeout(() => this._fitActive(), 50);
    const tab = this.tabs.find((t) => t.id === id);
    if (tab) tab.term.focus();
  }

  setMode(mode) {
    this.mode = mode;
    this.container.className = `term-container term-${mode} open`;
    if (mode === "float") {
      this.container.style.left = Math.round(window.innerWidth * 0.1) + "px";
      this.container.style.top = Math.round(window.innerHeight * 0.1) + "px";
      this.container.style.width = Math.round(window.innerWidth * 0.8) + "px";
      this.container.style.height = Math.round(window.innerHeight * 0.6) + "px";
    } else {
      this.container.style.left = "";
      this.container.style.top = "";
      this.container.style.width = "";
      this.container.style.height = "";
    }
    if (mode === "grid") {
      // Show all panes simultaneously with grid layout
      const n = this.tabs.length;
      const cols = n <= 1 ? 1 : n === 2 ? 2 : n <= 4 ? 2 : 3;
      const body = document.getElementById("term-body");
      body.style.gridTemplateColumns = `repeat(${cols}, 1fr)`;
      this.tabs.forEach((t) => {
        t.el.style.display = "block";
      });
      requestAnimationFrame(() => this._fitAll());
    } else {
      const body = document.getElementById("term-body");
      if (body) body.style.gridTemplateColumns = "";
      // Restore single-pane visibility
      this.tabs.forEach((t) => {
        t.el.style.display = t.id === this.activeId ? "" : "none";
      });
      setTimeout(() => this._fitActive(), 100);
    }
  }

  _fitActive() {
    const tab = this.tabs.find((t) => t.id === this.activeId);
    if (tab && tab.fitAddon) {
      try {
        tab.fitAddon.fit();
      } catch {
        /* ignore fit errors */
      }
    }
  }

  _fitAll() {
    this.tabs.forEach((t) => {
      if (t.fitAddon) {
        try {
          t.fitAddon.fit();
        } catch {
          /* ignore fit errors */
        }
      }
    });
  }

  _destroyTab(tab) {
    tab.ws.onclose = null;
    if (tab.ws.readyState <= 1) tab.ws.close();
    tab.term.dispose();
    tab.el.remove();
  }

  _renderTabs() {
    const bar = document.getElementById("term-tabs");
    if (!bar) return;
    bar.innerHTML = this.tabs
      .map(
        (t) =>
          `<div class="term-tab ${t.id === this.activeId ? "active" : ""}" onclick="termMgr.switchTab(${t.id})">
        <span>${esc(t.label)}</span>
        <span class="term-tab-close" onclick="event.stopPropagation();termMgr.removeTab(${t.id})">&times;</span>
      </div>`,
      )
      .join("");
  }

  _build() {
    const c = document.createElement("div");
    c.className = "term-container term-dock";
    c.id = "term-main";
    c.style.display = "none";
    c.innerHTML = `
      <div class="term-header" id="term-drag-handle">
        <div class="term-tabs" id="term-tabs"></div>
        <div class="term-controls">
          <button class="term-ctrl-btn" onclick="termMgr.open()" title="New local terminal">+</button>
          <button class="term-ctrl-btn" onclick="termMgr.setMode('dock')" title="Dock bottom">\u25C1</button>
          <button class="term-ctrl-btn" onclick="termMgr.setMode('float')" title="Floating window">\u25A1</button>
          <button class="term-ctrl-btn" onclick="termMgr.setMode('grid')" title="Grid view">\u229E</button>
          <button class="term-ctrl-btn" onclick="termMgr.setMode('full')" title="Fullscreen">\u2B1C</button>
          <button class="term-ctrl-btn term-ctrl-close" onclick="termMgr.close()" title="Close all">\u2715</button>
        </div>
      </div>
      <div class="term-body" id="term-body"></div>
      <div class="term-resize" id="term-resize-handle"></div>`;
    document.body.appendChild(c);
    this.container = c;

    // Drag (float mode)
    const handle = document.getElementById("term-drag-handle");
    handle.addEventListener("mousedown", (e) => {
      if (this.mode !== "float") return;
      if (e.target.closest(".term-controls") || e.target.closest(".term-tab"))
        return;
      this.dragState = {
        x: e.clientX - c.offsetLeft,
        y: e.clientY - c.offsetTop,
      };
      e.preventDefault();
    });
    document.addEventListener("mousemove", (e) => {
      if (!this.dragState) return;
      c.style.left = e.clientX - this.dragState.x + "px";
      c.style.top = e.clientY - this.dragState.y + "px";
    });
    document.addEventListener("mouseup", () => {
      this.dragState = null;
    });

    // Resize (dock mode — vertical)
    const rh = document.getElementById("term-resize-handle");
    let resizing = false;
    rh.addEventListener("mousedown", (e) => {
      resizing = true;
      e.preventDefault();
    });
    document.addEventListener("mousemove", (e) => {
      if (!resizing) return;
      if (this.mode === "dock") {
        const h = window.innerHeight - e.clientY;
        c.style.height =
          Math.max(150, Math.min(h, window.innerHeight - 60)) + "px";
      } else if (this.mode === "float") {
        c.style.width = Math.max(400, e.clientX - c.offsetLeft) + "px";
        c.style.height = Math.max(200, e.clientY - c.offsetTop) + "px";
      }
      this._fitActive();
    });
    document.addEventListener("mouseup", () => {
      resizing = false;
    });
  }
}

// Expose globally
const termMgr = new TerminalManager();
document.addEventListener("DOMContentLoaded", () => termMgr.init());
