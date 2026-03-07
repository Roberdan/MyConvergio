/* brain-canvas.js — Interactive force-directed graph renderer */
(() => {
  'use strict';
  const PI2 = Math.PI * 2;
  const PAL = {
    cyan: '#00e5ff',
    green: '#00ff88',
    gold: '#ffd700',
    red: '#ff3366',
    dim: '#3a4466',
  };
  const SCOL = {
    agent_running: PAL.green,
    in_progress: PAL.cyan,
    waiting_thor: PAL.gold,
    done: '#2a3a55',
    pending: '#2a3050',
    submitted: '#4a6a80',
    blocked: PAL.red,
    waiting_ci: '#5a7a90',
    waiting_review: '#5a7a90',
    waiting_merge: '#5a7a90',
  };
  const PCOL = { doing: PAL.cyan, done: PAL.green, blocked: PAL.red, todo: '#4a5a80' };

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

  // --- Data collection ---
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
        _data: {
          name: p.name || `#${p.id}`,
          status: p.status,
          planId: p.id,
        },
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
    return true;
  }

  // --- Drawing ---
  function drawGrid(c) {
    c.strokeStyle = 'rgba(0,229,255,0.03)';
    c.lineWidth = 0.5;
    for (let x = 0; x < S.w; x += 40) {
      c.beginPath();
      c.moveTo(x, 0);
      c.lineTo(x, S.h);
      c.stroke();
    }
    for (let y = 0; y < S.h; y += 40) {
      c.beginPath();
      c.moveTo(0, y);
      c.lineTo(S.w, y);
      c.stroke();
    }
  }

  function drawEdges(c) {
    const L = S.layout;
    if (!L) return;
    L.nodes.forEach((n) => {
      if (n.type !== 'agent' || !n.parentId) return;
      const p = L.nodeMap.get(n.parentId);
      if (!p) return;
      const act = n._data?.isActive;
      c.beginPath();
      const mx = (n.x + p.x) / 2 + (n.y - p.y) * 0.15,
        my = (n.y + p.y) / 2 - (n.x - p.x) * 0.15;
      c.moveTo(n.x, n.y);
      c.quadraticCurveTo(mx, my, p.x, p.y);
      c.strokeStyle = act ? (SCOL[n._data?.status] || PAL.dim) + '55' : 'rgba(60,80,120,0.12)';
      c.lineWidth = act ? 1.5 : 0.6;
      c.stroke();
    });
  }

  function drawPlanNodes(c) {
    const L = S.layout;
    if (!L) return;
    L.nodes.forEach((n) => {
      if (n.type !== 'plan') return;
      const d = n._data || {},
        col = PCOL[d.status] || PAL.dim;
      const r = 20;
      c.save();
      c.shadowBlur = 14;
      c.shadowColor = col;
      const g = c.createRadialGradient(n.x - 2, n.y - 2, 3, n.x, n.y, r);
      g.addColorStop(0, col + 'cc');
      g.addColorStop(1, col + '33');
      c.fillStyle = g;
      c.beginPath();
      c.arc(n.x, n.y, r, 0, PI2);
      c.fill();
      c.shadowBlur = 0;
      c.strokeStyle = col + '55';
      c.lineWidth = 1.2;
      c.beginPath();
      c.arc(n.x, n.y, r + 5, 0, PI2);
      c.stroke();
      // Label
      const lbl = (d.name || '').length > 20 ? (d.name || '').slice(0, 18) + '...' : d.name || '';
      c.font = '10px "JetBrains Mono",monospace';
      c.textAlign = 'center';
      const tw = c.measureText(lbl).width;
      c.fillStyle = 'rgba(10,16,36,0.7)';
      if (c.roundRect) {
        c.beginPath();
        c.roundRect(n.x - tw / 2 - 4, n.y + r + 8, tw + 8, 14, 3);
        c.fill();
      }
      c.fillStyle = '#b0c4dd';
      c.fillText(lbl, n.x, n.y + r + 19);
      c.restore();
    });
  }

  function drawAgentNodes(c) {
    const L = S.layout;
    if (!L) return;
    L.nodes.forEach((n) => {
      if (n.type !== 'agent') return;
      const d = n._data || {},
        act = d.isActive;
      const col = SCOL[d.status] || PAL.dim;
      const r = act ? 8 : 5;
      c.save();
      c.globalAlpha = act ? 1 : d.status === 'done' ? 0.4 : 0.55;
      c.shadowBlur = act ? 10 : 2;
      c.shadowColor = col;
      c.fillStyle = col + (act ? 'dd' : '88');
      c.beginPath();
      c.arc(n.x, n.y, r, 0, PI2);
      c.fill();
      c.shadowBlur = 0;
      // Icon
      c.fillStyle = act ? '#0a1024' : '#0a1024aa';
      c.font = `bold ${act ? 9 : 7}px "JetBrains Mono",monospace`;
      c.textAlign = 'center';
      c.textBaseline = 'middle';
      const icon = d.status === 'waiting_thor' ? '\u26A1' : act ? '\u25C6' : '\u25CF';
      c.fillText(icon, n.x, n.y + 0.5);
      c.restore();
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

  function drawIdle(c, ts) {
    const p = 0.5 + 0.5 * Math.sin(ts * 0.001);
    c.save();
    c.strokeStyle = `rgba(0,229,255,${0.04 + p * 0.06})`;
    c.lineWidth = 1;
    c.beginPath();
    c.arc(S.w / 2, S.h / 2, 35 + p * 8, 0, PI2);
    c.stroke();
    c.fillStyle = `rgba(176,196,221,${0.15 + p * 0.12})`;
    c.font = '12px "JetBrains Mono",monospace';
    c.textAlign = 'center';
    c.fillText('No active tasks', S.w / 2, S.h / 2 + 55);
    c.restore();
  }

  // --- Render loop (on-demand) ---
  function drawFrame(ts) {
    if (!S.ctx) return;
    const c = S.ctx;
    c.clearRect(0, 0, S.w, S.h);
    drawGrid(c);
    const L = S.layout;
    if (!L || !L.nodes.length) {
      drawIdle(c, ts);
      drawStats(c);
      return;
    }
    if (!L.stable) L.step();
    drawEdges(c);
    drawPlanNodes(c);
    drawAgentNodes(c);
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

  // --- Resize (uses clientWidth to avoid CSS zoom issues) ---
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

  // --- Data refresh (called by dashboard refreshAll) ---
  function refreshBrain() {
    if (!S.ctx) return;
    const changed = syncLayout();
    if (changed) requestFrame();
  }

  // --- Lifecycle ---
  window.initBrainCanvas = function (id) {
    window.destroyBrainCanvas();
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
