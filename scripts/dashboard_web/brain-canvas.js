/* brain-canvas.js — Agent Activity widget: brain canvas ambient + DOM session cards */
(() => {
  'use strict';
  const S = {
    container: null, canvas: null, ctx: null, w: 0, h: 0, raf: 0, running: true,
    pollT: 0, ws: null, wsRetry: 0, wsT: 0, sessions: [], agents: [], particles: [],
    lastTs: 0, pulsePhase: 0
  };
  const PAL = { cyan: '#00e5ff', green: '#00ff88', gold: '#ffb020', blue: '#20a0ff', red: '#ff3366', dim: '#3a4466' };
  const PI2 = Math.PI * 2;
  const esc = (s) => { const d = document.createElement('div'); d.textContent = s; return d.innerHTML; };

  /* ─── Canvas ambient layer (background glow, grid, particles) ─── */
  function drawGrid(c) {
    c.strokeStyle = 'rgba(0,229,255,0.025)'; c.lineWidth = 0.5;
    for (let x = 0; x < S.w; x += 40) { c.beginPath(); c.moveTo(x, 0); c.lineTo(x, S.h); c.stroke(); }
    for (let y = 0; y < S.h; y += 40) { c.beginPath(); c.moveTo(0, y); c.lineTo(S.w, y); c.stroke(); }
  }
  function drawCoreGlow(c, ts) {
    const cx = S.w / 2, cy = S.h * 0.38;
    const p = 0.5 + 0.5 * Math.sin(ts * 0.0008);
    const nSess = S.sessions.filter(s => s.status === 'running').length;
    const intensity = Math.min(0.35, 0.08 + nSess * 0.04);
    // Outer halo
    const g1 = c.createRadialGradient(cx, cy, 10, cx, cy, 120 + p * 30);
    g1.addColorStop(0, `rgba(0,229,255,${intensity})`);
    g1.addColorStop(0.5, `rgba(0,229,255,${intensity * 0.3})`);
    g1.addColorStop(1, 'transparent');
    c.fillStyle = g1; c.beginPath(); c.arc(cx, cy, 150 + p * 30, 0, PI2); c.fill();
    // Inner warm core
    const g2 = c.createRadialGradient(cx - 10, cy - 10, 5, cx, cy, 50 + p * 10);
    g2.addColorStop(0, `rgba(255,176,32,${intensity * 0.8})`);
    g2.addColorStop(1, 'transparent');
    c.fillStyle = g2; c.beginPath(); c.arc(cx, cy, 60 + p * 10, 0, PI2); c.fill();
  }
  function drawSynapses(c, ts) {
    const cx = S.w / 2, cy = S.h * 0.38;
    const cards = S.container?.querySelectorAll('.an-node') || [];
    cards.forEach(card => {
      const r = card.getBoundingClientRect();
      const pr = S.container.getBoundingClientRect();
      const tx = r.left - pr.left + r.width / 2, ty = r.top - pr.top + r.height / 2;
      const p = 0.3 + 0.3 * Math.sin(ts * 0.001 + tx * 0.01);
      c.strokeStyle = `rgba(0,229,255,${0.06 + p * 0.06})`;
      c.lineWidth = 0.8;
      const mx = (cx + tx) / 2 + (cy - ty) * 0.15, my = (cy + ty) / 2 - (cx - tx) * 0.15;
      c.beginPath(); c.moveTo(cx, cy); c.quadraticCurveTo(mx, my, tx, ty); c.stroke();
    });
  }
  function tickParticles(dt) {
    // Spawn from core toward cards
    const cards = S.container?.querySelectorAll('.an-node.online') || [];
    if (cards.length && Math.random() < dt * 0.008) {
      const card = cards[Math.floor(Math.random() * cards.length)];
      const r = card.getBoundingClientRect();
      const pr = S.container.getBoundingClientRect();
      S.particles.push({
        sx: S.w / 2, sy: S.h * 0.38,
        tx: r.left - pr.left + r.width / 2, ty: r.top - pr.top + r.height / 2,
        t: 0, spd: 0.5 + Math.random() * 0.5,
        col: card.classList.contains('claude') ? PAL.gold : PAL.blue,
        sz: 1.2 + Math.random() * 1.5
      });
    }
    for (let i = S.particles.length - 1; i >= 0; i--) {
      const p = S.particles[i]; p.t += dt * p.spd * 0.0015;
      if (p.t >= 1) { S.particles.splice(i, 1); continue; }
      const u = 1 - p.t;
      const mx = (p.sx + p.tx) / 2 + (p.sy - p.ty) * 0.2, my = (p.sy + p.ty) / 2 - (p.sx - p.tx) * 0.2;
      p.cx = u * u * p.sx + 2 * u * p.t * mx + p.t * p.t * p.tx;
      p.cy = u * u * p.sy + 2 * u * p.t * my + p.t * p.t * p.ty;
    }
    if (S.particles.length > 80) S.particles.length = 80;
  }
  function drawParticles(c) {
    c.save();
    S.particles.forEach(p => {
      c.globalAlpha = p.t > 0.8 ? (1 - p.t) / 0.2 : 0.8;
      c.fillStyle = p.col; c.shadowBlur = 4; c.shadowColor = p.col;
      c.beginPath(); c.arc(p.cx, p.cy, p.sz, 0, PI2); c.fill();
    });
    c.restore();
  }
  function renderCanvas(ts) {
    if (!S.ctx || !S.running) return;
    const dt = Math.min(50, ts - (S.lastTs || ts)); S.lastTs = ts;
    const c = S.ctx; c.clearRect(0, 0, S.w, S.h);
    drawGrid(c); drawCoreGlow(c, ts); drawSynapses(c, ts);
    tickParticles(dt); drawParticles(c);
    S.raf = requestAnimationFrame(renderCanvas);
  }
  function resize() {
    if (!S.container || !S.canvas) return;
    const r = S.container.getBoundingClientRect(), dpr = window.devicePixelRatio || 1;
    S.w = Math.max(10, r.width); S.h = Math.max(10, r.height);
    S.canvas.width = Math.floor(S.w * dpr); S.canvas.height = Math.floor(S.h * dpr);
    S.canvas.style.width = S.w + 'px'; S.canvas.style.height = S.h + 'px';
    S.ctx.setTransform(dpr, 0, 0, dpr, 0, 0);
  }

  /* ─── DOM card layer (readable agent nodes) ─── */
  function parseMeta(s) {
    try { return typeof s === 'string' ? JSON.parse(s) : (s || {}); } catch { return {}; }
  }
  function toolType(id, type) {
    return (type?.includes('copilot') || id?.includes('copilot')) ? 'copilot' : 'claude';
  }
  function sessionCardHtml(sess) {
    const meta = parseMeta(sess.metadata);
    const tool = toolType(sess.session_id, sess.type);
    const pid = meta.pid || sess.session_id.split('-').pop();
    const tty = meta.tty || '';
    const cpu = meta.cpu != null ? `CPU ${meta.cpu}%` : '';
    const mem = meta.mem != null ? `MEM ${meta.mem}%` : '';
    const children = sess.children || [];
    const activeKids = children.filter(c => c.status === 'running');
    const isRunning = sess.status === 'running';
    const cls = ['an-node', isRunning ? 'online' : 'offline', tool].filter(Boolean).join(' ');
    const stats = [cpu, mem].filter(Boolean).join(' · ');
    const kidsBadge = activeKids.length
      ? `<span class="an-badge">${activeKids.length} agent${activeKids.length > 1 ? 's' : ''}</span>`
      : '';

    return `<div class="${cls}">
      <div class="an-head"><span class="an-label">${tool === 'copilot' ? 'Copilot' : 'Claude'}</span><span class="an-dot ${isRunning ? 'on' : 'off'}"></span></div>
      <div class="an-info">${tty ? `${esc(tty)} · ` : ''}PID ${esc(String(pid))}</div>
      ${stats ? `<div class="an-info bright">${stats}</div>` : ''}
      ${kidsBadge}
    </div>`;
  }

  function renderCards() {
    if (!S.container) return;
    let overlay = S.container.querySelector('.brain-overlay');
    if (!overlay) {
      overlay = document.createElement('div'); overlay.className = 'brain-overlay';
      S.container.appendChild(overlay);
    }
    const sessions = S.sessions.filter(s => s.status === 'running');
    if (!sessions.length) {
      overlay.innerHTML = '';
      return;
    }
    overlay.innerHTML = `<div class="an-grid">${sessions.map(sessionCardHtml).join('')}</div>`;
  }

  function updateStats() {
    const el = document.getElementById('brain-stats');
    if (!el) return;
    const running = S.sessions.filter(s => s.status === 'running');
    const totalKids = running.reduce((n, s) => n + (s.children || []).filter(c => c.status === 'running').length, 0);
    const models = new Set();
    running.forEach(s => (s.children || []).forEach(c => { if (c.model) models.add(c.model); }));
    const plans = (window._dashboardPlans || []).filter(p => p.status === 'doing').length;
    el.textContent = `${running.length} session${running.length !== 1 ? 's' : ''} · ${totalKids} agent${totalKids !== 1 ? 's' : ''} · ${plans} plan${plans !== 1 ? 's' : ''} · ${models.size} model${models.size !== 1 ? 's' : ''}`;
  }

  /* ─── Data polling ─── */
  function pollData() {
    Promise.all([
      fetch('/api/sessions').then(r => r.json()).catch(() => []),
      fetch('/api/agents').then(r => r.json()).catch(() => ({ running: [], recent: [] }))
    ]).then(([rawSessions, agentData]) => {
      const running = agentData.running || [];
      const childMap = new Map();
      running.forEach(a => {
        if (a.parent_session) {
          if (!childMap.has(a.parent_session)) childMap.set(a.parent_session, []);
          childMap.get(a.parent_session).push(a);
        }
      });
      S.sessions = (rawSessions || []).map(s => ({
        session_id: s.agent_id, type: s.type || 'claude-cli',
        status: s.status, metadata: s.metadata,
        children: (childMap.get(s.agent_id) || []).map(c => ({
          agent_id: c.agent_id, type: c.type, model: c.model,
          description: c.description, status: c.status || 'running', duration_s: c.duration_s
        }))
      }));
      S.agents = agentData.recent || [];
      window._dashboardAgentData = { sessions: S.sessions, orphan_agents: [] };
      renderCards(); updateStats(); resize();
    }).catch(() => {});
  }

  const wsUrl = () => `${location.protocol === 'https:' ? 'wss' : 'ws'}://${location.host}/ws/brain`;
  function connectWs() {
    try { S.ws = new WebSocket(wsUrl()); } catch { S.ws = null; }
    if (!S.ws) return;
    S.ws.onopen = () => { S.wsRetry = 0; };
    S.ws.onmessage = () => pollData();
    S.ws.onerror = () => S.ws?.close();
    S.ws.onclose = () => { clearTimeout(S.wsT); S.wsT = setTimeout(connectWs, Math.min(30000, 1000 * Math.pow(2, S.wsRetry++))); };
  }

  /* ─── Lifecycle ─── */
  window.initBrainCanvas = function(id) {
    window.destroyBrainCanvas();
    S.container = document.getElementById(id || 'brain-canvas-container');
    if (!S.container) return;
    // Canvas background layer
    S.canvas = document.createElement('canvas');
    S.canvas.style.cssText = 'position:absolute;top:0;left:0;width:100%;height:100%;pointer-events:none;z-index:0;';
    S.container.appendChild(S.canvas);
    S.ctx = S.canvas.getContext('2d', { alpha: true }); resize();
    S.ro = new ResizeObserver(resize); S.ro.observe(S.container);
    // Data + render
    pollData(); S.pollT = setInterval(pollData, 10000);
    connectWs();
    S.running = !document.hidden;
    S.raf = requestAnimationFrame(renderCanvas);
    document.addEventListener('visibilitychange', onVis);
  };
  function onVis() {
    S.running = !document.hidden;
    if (S.running && !S.raf) S.raf = requestAnimationFrame(renderCanvas);
    if (!S.running && S.raf) { cancelAnimationFrame(S.raf); S.raf = 0; }
  }
  window.destroyBrainCanvas = function() {
    if (S.raf) cancelAnimationFrame(S.raf); S.raf = 0;
    if (S.ro) S.ro.disconnect(); S.ro = null;
    if (S.ws) S.ws.close(); S.ws = null; clearTimeout(S.wsT); S.wsT = 0;
    if (S.pollT) clearInterval(S.pollT); S.pollT = 0;
    document.removeEventListener('visibilitychange', onVis);
    if (S.container) S.container.innerHTML = '';
    S.container = S.canvas = S.ctx = null; S.particles = []; S.sessions = []; S.agents = [];
  };
  window.updateBrainData = function() { pollData(); };
  window.toggleBrainFreeze = function() {
    S.running = !S.running;
    const btn = document.getElementById('brain-pause-btn');
    if (btn) btn.textContent = S.running ? '❚❚' : '▶';
    if (S.running) { S.raf = requestAnimationFrame(renderCanvas); pollData(); }
  };
  window.rewindBrain = function() { S.particles = []; pollData(); };

  const _boot = () => window.initBrainCanvas('brain-canvas-container');
  if (document.readyState === 'loading') document.addEventListener('DOMContentLoaded', _boot);
  else setTimeout(_boot, 100);
})();