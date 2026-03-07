/* brain-canvas.js — Network graph renderer (force-directed) */
(() => {
  'use strict';
  const PI2 = Math.PI * 2;

  // Read CSS theme variables at init, fallback to hardcoded
  function css(name, fb) {
    return getComputedStyle(document.documentElement).getPropertyValue(name).trim() || fb;
  }
  let TH = {}; // theme cache
  function loadTheme() {
    const cyan = css('--cyan', '#00e5ff');
    const green = css('--green', '#00ff88');
    const gold = css('--gold', '#ffb700');
    const red = css('--red', '#ff3355');
    const dim = css('--text-dim', '#5a6080');
    const border = css('--border', '#1a2040');
    const bgDeep = css('--bg-deep', '#04060e');
    const bgPanel = css('--bg-panel', '#0a0e1a');
    const text = css('--text', '#c8d0e8');
    TH = { cyan, green, gold, red, dim, border, bgDeep, bgPanel, text };
  }

  function statusColor(s) {
    const map = {
      agent_running: TH.green,
      in_progress: TH.cyan,
      waiting_thor: TH.gold,
      done: TH.border,
      pending: TH.bgPanel,
      submitted: TH.dim,
      blocked: TH.red,
      waiting_ci: TH.cyan,
      waiting_review: TH.cyan,
      waiting_merge: TH.cyan,
    };
    return map[s] || TH.border;
  }
  function planColor(s) {
    const map = {
      doing: TH.cyan,
      done: TH.green,
      blocked: TH.red,
      todo: TH.dim,
    };
    return map[s] || TH.dim;
  }

  const S = {
    container: null,
    canvas: null,
    ctx: null,
    ro: null,
    w: 0,
    h: 0,
    layout: null,
    _dataHash: '',
  };
  let _raf = 0;

  // --- Data ---
  function collectNodes() {
    const plans = window._dashboardPlans || [],
      nodes = [];
    plans.forEach((m) => {
      const p = m.plan || m,
        tasks = m.tasks || p.tasks;
      if (!tasks) return;
      const pid = `p-${p.id}`;
      nodes.push({
        id: pid,
        type: 'plan',
        parentId: null,
        _data: { name: p.name || `#${p.id}`, status: p.status, planId: p.id },
      });
      tasks.forEach((t) => {
        const act = t.status === 'in_progress' || t.substatus === 'agent_running';
        const st = t.substatus || t.status;
        let artifacts = [];
        try {
          const od =
            typeof t.output_data === 'string'
              ? JSON.parse(t.output_data || '{}')
              : t.output_data || {};
          artifacts = od.artifacts || [];
        } catch (_) {}
        nodes.push({
          id: `t-${t.id}`,
          type: 'agent',
          parentId: pid,
          _data: {
            name: t.title || `Task ${t.id}`,
            status: st,
            isActive: act,
            taskId: t.task_id,
            host: t.executor_host,
            model: t.model,
            wave: t.wave_id,
            planId: p.id,
            artifacts,
            linesAdded: t.lines_added || 0,
            linesRemoved: t.lines_removed || 0,
            filesChanged: t.files_changed || 0,
          },
        });
      });
    });
    return nodes;
  }

  function dataHash(nodes) {
    return nodes.map((n) => n.id + (n._data?.status || '')).join(',');
  }

  function syncLayout() {
    const nodes = collectNodes();
    const hash = dataHash(nodes);
    if (hash === S._dataHash) return false;
    S._dataHash = hash;
    if (!S.layout) S.layout = new BrainLayout(S.w, S.h);
    S.layout.width = S.w;
    S.layout.height = S.h;
    S.layout.setNodes(nodes);
    S.layout.settle();
    return true;
  }

  // --- Drawing ---
  function drawBg(c) {
    const g = c.createRadialGradient(S.w / 2, S.h / 2, 0, S.w / 2, S.h / 2, S.w * 0.7);
    g.addColorStop(0, TH.bgPanel);
    g.addColorStop(1, TH.bgDeep);
    c.fillStyle = g;
    c.fillRect(0, 0, S.w, S.h);
  }

  function drawEdges(c) {
    const L = S.layout;
    if (!L) return;
    L.nodes.forEach((n) => {
      if (n.type !== 'agent' || !n.parentId) return;
      const p = L.nodeMap.get(n.parentId);
      if (!p) return;
      const act = n._data?.isActive;
      const col = statusColor(n._data?.status);
      c.beginPath();
      c.moveTo(n.x, n.y);
      c.lineTo(p.x, p.y);
      c.strokeStyle = act ? col + '88' : TH.border;
      c.lineWidth = act ? 1.8 : 0.7;
      c.stroke();
    });
  }

  function drawPlanNode(c, n) {
    const d = n._data || {};
    const col = planColor(d.status);
    const r = 22;
    // Glow
    c.save();
    c.shadowBlur = 20;
    c.shadowColor = col;
    // Filled circle
    c.fillStyle = col + 'cc';
    c.beginPath();
    c.arc(n.x, n.y, r, 0, PI2);
    c.fill();
    c.shadowBlur = 0;
    // Ring
    c.strokeStyle = col;
    c.lineWidth = 2;
    c.beginPath();
    c.arc(n.x, n.y, r + 3, 0, PI2);
    c.stroke();
    // Label inside
    c.fillStyle = TH.text;
    c.font = 'bold 10px "JetBrains Mono",monospace';
    c.textAlign = 'center';
    c.textBaseline = 'middle';
    c.fillText('#' + (d.planId || ''), n.x, n.y);
    // Name below
    const lbl = (d.name || '').length > 22 ? (d.name || '').slice(0, 20) + '..' : d.name || '';
    c.font = '9px "JetBrains Mono",monospace';
    c.fillStyle = TH.dim;
    c.fillText(lbl, n.x, n.y + r + 14);
    c.restore();
  }

  function drawAgentNode(c, n) {
    const d = n._data || {};
    const act = d.isActive;
    const col = statusColor(d.status);
    const r = act ? 9 : 6;
    c.save();
    c.globalAlpha = act ? 1 : d.status === 'done' ? 0.35 : 0.6;
    // Glow for active
    if (act) {
      c.shadowBlur = 12;
      c.shadowColor = col;
    }
    // Circle
    c.fillStyle = col;
    c.beginPath();
    c.arc(n.x, n.y, r, 0, PI2);
    c.fill();
    c.shadowBlur = 0;
    // Thin ring
    c.strokeStyle = col + '66';
    c.lineWidth = 0.8;
    c.beginPath();
    c.arc(n.x, n.y, r + 2, 0, PI2);
    c.stroke();
    // Short label below
    if (act || d.status !== 'done') {
      const tid = d.taskId || '';
      const short = tid.length > 8 ? tid.slice(0, 7) + '..' : tid;
      c.font = '8px "JetBrains Mono",monospace';
      c.textAlign = 'center';
      c.fillStyle = TH.dim;
      c.fillText(short, n.x, n.y + r + 10);
    }
    c.restore();
  }

  function drawNodes(c) {
    const L = S.layout;
    if (!L) return;
    // Draw agents first, plans on top
    L.nodes.forEach((n) => {
      if (n.type === 'agent') drawAgentNode(c, n);
    });
    L.nodes.forEach((n) => {
      if (n.type === 'plan') drawPlanNode(c, n);
    });
  }

  function drawStats(c) {
    const L = S.layout;
    if (!L) return;
    const agents = L.nodes.filter((n) => n.type === 'agent');
    const active = agents.filter((n) => n._data?.isActive).length;
    const plans = L.nodes.filter((n) => n.type === 'plan').length;
    const el = document.getElementById('brain-stats');
    if (el) el.textContent = `${active} active \xB7 ${agents.length} tasks \xB7 ${plans} plans`;
  }

  function drawIdle(c) {
    c.save();
    c.fillStyle = TH.dim + '44';
    c.font = '13px "JetBrains Mono",monospace';
    c.textAlign = 'center';
    c.fillText('No active plans', S.w / 2, S.h / 2);
    c.restore();
  }

  // --- Render loop (on-demand) ---
  function drawFrame(ts) {
    if (!S.ctx) return;
    const c = S.ctx;
    c.clearRect(0, 0, S.w, S.h);
    drawBg(c);
    const L = S.layout;
    if (!L || !L.nodes.length) {
      drawIdle(c);
      drawStats(c);
      return;
    }
    if (!L.stable) L.step();
    drawEdges(c);
    drawNodes(c);
    if (window._brainDrawHover) window._brainDrawHover(c);
    drawStats(c);
  }

  function frame(ts) {
    _raf = 0;
    drawFrame(ts);
    if (S.layout && !S.layout.stable) {
      _raf = requestAnimationFrame(frame);
    }
  }

  function requestFrame() {
    if (_raf) return;
    _raf = requestAnimationFrame(frame);
  }
  window._brainRequestFrame = requestFrame;

  // --- Resize ---
  function resize() {
    if (!S.container || !S.canvas) return;
    const nw = Math.max(10, S.container.clientWidth);
    const nh = Math.max(10, S.container.clientHeight);
    if (nw === S.w && nh === S.h) return;
    S.w = nw;
    S.h = nh;
    const dpr = window.devicePixelRatio || 1;
    S.canvas.width = nw * dpr;
    S.canvas.height = nh * dpr;
    S.canvas.style.width = nw + 'px';
    S.canvas.style.height = nh + 'px';
    S.ctx.setTransform(dpr, 0, 0, dpr, 0, 0);
    requestFrame();
  }

  function refreshBrain() {
    if (!S.ctx) return;
    if (syncLayout()) requestFrame();
  }

  // --- Lifecycle ---
  window.initBrainCanvas = function (id) {
    window.destroyBrainCanvas();
    loadTheme();
    S.container = document.getElementById(id || 'brain-canvas-container');
    if (!S.container) return;
    S.canvas = document.createElement('canvas');
    S.canvas.className = 'brain-canvas';
    S.canvas.style.cssText = 'display:block;border-radius:8px;';
    S.container.appendChild(S.canvas);
    S.ctx = S.canvas.getContext('2d', { alpha: true });
    window._brainState = S;
    if (window._brainInteract) window._brainInteract.init(S.canvas);
    resize();
    S.ro = new ResizeObserver(() => resize());
    S.ro.observe(S.container);
    document.addEventListener('visibilitychange', onVis);
    syncLayout();
    requestFrame();
  };

  window.destroyBrainCanvas = function () {
    if (window._brainInteract) window._brainInteract.destroy();
    window._brainState = null;
    if (_raf) {
      cancelAnimationFrame(_raf);
      _raf = 0;
    }
    if (S.ro) S.ro.disconnect();
    S.ro = null;
    document.removeEventListener('visibilitychange', onVis);
    if (S.canvas?.parentNode) S.canvas.parentNode.removeChild(S.canvas);
    S.container = S.canvas = S.ctx = S.layout = null;
    S.w = S.h = 0;
    S._dataHash = '';
  };

  window.updateBrainData = refreshBrain;

  function onVis() {
    if (!document.hidden) refreshBrain();
  }

  const _boot = () => window.initBrainCanvas('brain-canvas-container');
  if (document.readyState === 'loading') document.addEventListener('DOMContentLoaded', _boot);
  else setTimeout(_boot, 100);
})();
