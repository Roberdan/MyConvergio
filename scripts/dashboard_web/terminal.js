/**
 * Convergio Control Room — Real Terminal Manager.
 * xterm.js + WebSocket + PTY. Dock / Float / Fullscreen modes.
 */

/* global Terminal, FitAddon */

// PTY served by Rust claude-core on same host (/ws/pty)

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

  open(peer, label, tmuxSession) {
    if (!this.container || !document.body.contains(this.container)) {
      this._build();
    }
    if (!this.visible) this.show();
    return this.addTab(peer || "local", label || peer || "local", tmuxSession);
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

  addTab(peer, label, tmuxSession) {
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
    if (typeof WebLinksAddon !== "undefined") {
      term.loadAddon(new WebLinksAddon.WebLinksAddon());
    }

    const wsParams = `peer=${encodeURIComponent(peer)}${tmuxSession ? `&tmux_session=${encodeURIComponent(tmuxSession)}` : ""}`;
    const wsProt = location.protocol === "https:" ? "wss" : "ws";
    const wsUrl = `${wsProt}://${location.host}/ws/pty?${wsParams}`;
    const ws = new WebSocket(wsUrl);
    ws.binaryType = "arraybuffer";

    const tabLabel = tmuxSession ? `${label} [${tmuxSession}]` : label;
    let opened = false;
    const tab = { id, label: tabLabel, peer, term, ws, fitAddon, el };

    ws.onopen = () => {
      opened = true;
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
      if (!opened) {
        term.open(el);
        fitAddon.fit();
      }
      term.write(
        "\x1b[1;31m[X] WebSocket error — is claude-core serve running?\x1b[0m\r\n",
      );
    };

    ws.onclose = () => {
      if (!opened) {
        // Connection never succeeded — keep tab open so user sees the error
        term.write(
          "\r\n\x1b[33m[!] Could not connect. Ensure claude-core serve is running.\x1b[0m\r\n",
        );
        term.write(
          "\x1b[2m  claude-core serve  # PTY endpoint: /ws/pty\x1b[0m\r\n",
        );
        return;
      }
      term.write("\r\n\x1b[2m[session ended]\x1b[0m\r\n");
      this.removeTab(id);
    };

    term.onData((data) => {
      if (ws.readyState === WebSocket.OPEN) {
        const enc = new TextEncoder();
        ws.send(enc.encode(data));
      }
    });

    // Forward mouse events (scroll, click) to remote tmux
    term.onBinary((data) => {
      if (ws.readyState === WebSocket.OPEN) {
        const buf = new Uint8Array(data.length);
        for (let i = 0; i < data.length; i++) buf[i] = data.charCodeAt(i);
        ws.send(buf);
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
          <button class="term-ctrl-btn" onclick="termMgr.open()" title="New local terminal"><svg viewBox="0 0 16 16" width="13" height="13"><path d="M8 3v10M3 8h10"/></svg></button>
          <button class="term-ctrl-btn" onclick="termMgr.setMode('dock')" title="Dock bottom"><svg viewBox="0 0 16 16" width="13" height="13"><rect x="2" y="2" width="12" height="12" rx="1.5"/><path d="M2 10h12"/></svg></button>
          <button class="term-ctrl-btn" onclick="termMgr.setMode('float')" title="Floating window"><svg viewBox="0 0 16 16" width="13" height="13"><rect x="1" y="3" width="10" height="10" rx="1.5"/><path d="M5 3V2.5A1.5 1.5 0 016.5 1H13.5A1.5 1.5 0 0115 2.5v7a1.5 1.5 0 01-1.5 1.5H13"/></svg></button>
          <button class="term-ctrl-btn" onclick="termMgr.setMode('grid')" title="Grid view"><svg viewBox="0 0 16 16" width="13" height="13"><rect x="2" y="2" width="5" height="5" rx="1"/><rect x="9" y="2" width="5" height="5" rx="1"/><rect x="2" y="9" width="5" height="5" rx="1"/><rect x="9" y="9" width="5" height="5" rx="1"/></svg></button>
          <button class="term-ctrl-btn" onclick="termMgr.setMode('full')" title="Fullscreen"><svg viewBox="0 0 16 16" width="13" height="13"><path d="M2 6V2h4M10 2h4v4M14 10v4h-4M6 14H2v-4"/></svg></button>
          <button class="term-ctrl-btn term-ctrl-close" onclick="termMgr.close()" title="Close all"><svg viewBox="0 0 16 16" width="13" height="13"><path d="M4 4l8 8M12 4l-8 8"/></svg></button>
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
