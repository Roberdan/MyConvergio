/* brain-canvas.js — Global Agent Activity widget (standalone, all plans) */
(() => {
  'use strict';
  const REGIONS = ['prefrontal', 'motor', 'parietalLeft', 'parietalRight', 'corpusCallosum', 'amygdala', 'hippocampus', 'visualCortex', 'cerebellum', 'brainstem'];
  const S = {
    container: null, canvas: null, ctx: null, ro: null, raf: 0, w: 0, h: 0,
    running: false, lastDataTick: 0, lastTs: 0, agents: [], clusters: [],
    particles: [], anim: new Map(), layout: null, sessions: [], _sTick: 0, ws: null, wsRetry: 0, wsT: 0, pollT: 0, wsLive: false,
    peerRegion: new Map(), peerStats: new Map(), activeModels: new Set(), tokenFlow: 0,
  };
  const PAL = { cyan: '#00e5ff', green: '#00ff88', gold: '#ffd700', red: '#ff3366', dim: '#3a4466' };
  const STATUS_COL = {
    agent_running: PAL.green, in_progress: PAL.cyan, waiting_thor: PAL.gold,
    waiting_ci: PAL.dim, waiting_review: PAL.dim, waiting_merge: PAL.dim,
  };
  const PLAN_COL = { doing: PAL.cyan, done: PAL.green, blocked: PAL.red };
  const PI2 = Math.PI * 2;
  function collectAgents() {
    const plans = window._dashboardPlans || [], agents = [], clMap = new Map();
    plans.forEach(p => {
      if (!p?.tasks) return;
      const color = PLAN_COL[p.status] || PAL.dim;
      p.tasks.forEach(t => {
        const act = t.status === 'in_progress' || t.substatus === 'agent_running';
        const show = act || t.substatus === 'waiting_thor' ||
          ['waiting_ci', 'waiting_review', 'waiting_merge'].includes(t.substatus);
        if (!show) return;
        const st = t.substatus || t.status;
        agents.push({ id: `t-${t.id}`, planId: p.id, name: t.title || `Task ${t.id}`,
          host: t.execution_host, status: st, color: STATUS_COL[st] || PAL.dim, isActive: act });
        if (!clMap.has(p.id)) clMap.set(p.id, { id: `p-${p.id}`, planId: p.id,
          name: p.name || `#${p.id}`, color, status: p.status, hasActive: false });
      });
      const cl = clMap.get(p.id);
      if (cl) cl.hasActive = agents.some(a => a.planId === p.id && a.isActive);
    });
    return { agents, clusters: [...clMap.values()] };
  }
  function an(id) {
    if (!S.anim.has(id)) S.anim.set(id, {
      scale: 0, alpha: 0, phase: Math.random() * PI2, state: 'appearing', t: 0, px: 0, py: 0 });
    return S.anim.get(id);
  }
  function tickAnims(dt) {
    for (const [id, a] of S.anim) {
      a.t += dt; a.phase += dt * 0.003;
      if (a.state === 'appearing') {
        a.scale = Math.min(1, a.t / 300); a.alpha = a.scale;
        if (a.scale >= 1) { a.state = 'active'; a.t = 0; }
      } else if (a.state === 'active') { a.scale = 1 + 0.08 * Math.sin(a.phase); a.alpha = 1; }
      else if (a.state === 'idle') {
        a.scale = 0.85 + 0.03 * Math.sin(a.phase * 0.5); a.alpha = 0.35 + 0.1 * Math.sin(a.phase * 0.5);
      } else if (a.state === 'completing') {
        a.scale = Math.max(0, 1 - a.t / 500); a.alpha = a.scale;
      }
      if (a.state === 'completing' && a.scale <= 0) S.anim.delete(id);
    }
  }

  function doLayout() {
    if (!S.layout) S.layout = new BrainLayout(S.w, S.h);
    S.layout.width = S.w; S.layout.height = S.h;
    S.layout.setNodes([
      ...S.clusters.map(c => ({ id: c.id, type: 'plan', parentId: null })),
      ...S.agents.map(a => ({ id: a.id, type: 'agent', parentId: `p-${a.planId}` })),
    ]);
    for (let i = 0; i < 4; i++) S.layout.step();
    for (const [id, p] of Object.entries(S.layout.getPositions())) { const a = an(id); a.px = p.x; a.py = p.y; }
  }

  function tickParticles(dt) {
    S.agents.forEach(a => {
      if (!a.isActive) return;
      const from = S.anim.get(a.id), to = S.anim.get(`p-${a.planId}`);
      if (!from?.px || !to?.px) return;
      if (Math.random() < dt * 0.003) S.particles.push({ sx: from.px, sy: from.py,
        tx: to.px, ty: to.py, t: 0, spd: 0.7 + Math.random() * 0.5, col: a.color, sz: 1.5 + Math.random() * 1.5 });
    });
    for (let i = S.particles.length - 1; i >= 0; i--) {
      const p = S.particles[i]; p.t += dt * p.spd * 0.002;
      if (p.t >= 1) { S.particles.splice(i, 1); continue; }
      const u = 1 - p.t, mx = (p.sx + p.tx) / 2 + (p.sy - p.ty) * 0.18, my = (p.sy + p.ty) / 2 - (p.sx - p.tx) * 0.18;
      p.cx = u * u * p.sx + 2 * u * p.t * mx + p.t * p.t * p.tx;
      p.cy = u * u * p.sy + 2 * u * p.t * my + p.t * p.t * p.ty;
    }
    if (S.particles.length > 200) S.particles.length = 200;
  }
  function drawGrid(c) {
    c.strokeStyle = 'rgba(0,229,255,0.03)'; c.lineWidth = 0.5;
    for (let x = 0; x < S.w; x += 40) { c.beginPath(); c.moveTo(x, 0); c.lineTo(x, S.h); c.stroke(); }
    for (let y = 0; y < S.h; y += 40) { c.beginPath(); c.moveTo(0, y); c.lineTo(S.w, y); c.stroke(); }
  }
  function drawConns(c) {
    S.agents.forEach(a => {
      const fa = S.anim.get(a.id), ta = S.anim.get(`p-${a.planId}`);
      if (!fa?.px || !ta?.px) return;
      const mx = (fa.px + ta.px) / 2 + (fa.py - ta.py) * 0.18, my = (fa.py + ta.py) / 2 - (fa.px - ta.px) * 0.18;
      c.beginPath(); c.moveTo(fa.px, fa.py); c.quadraticCurveTo(mx, my, ta.px, ta.py);
      c.strokeStyle = a.isActive ? a.color + '44' : a.color + '15';
      c.lineWidth = a.isActive ? 1.5 : 0.5; c.stroke();
    });
  }
  function drawParts(c) {
    c.save();
    S.particles.forEach(p => {
      c.globalAlpha = p.t > 0.8 ? (1 - p.t) / 0.2 : 0.9; c.fillStyle = p.col;
      c.beginPath(); c.arc(p.cx, p.cy, p.sz, 0, PI2); c.fill();
    });
    c.restore();
  }
  function drawPlans(c) {
    S.clusters.forEach(cl => {
      const a = S.anim.get(cl.id); if (!a?.px) return;
      const r = 22 * a.scale;
      c.save(); c.shadowBlur = cl.hasActive ? 18 : 6; c.shadowColor = cl.color;
      const g = c.createRadialGradient(a.px - 3, a.py - 3, 4, a.px, a.py, r);
      g.addColorStop(0, cl.color + 'cc'); g.addColorStop(1, cl.color + '33');
      c.fillStyle = g; c.beginPath(); c.arc(a.px, a.py, r, 0, PI2); c.fill();
      c.strokeStyle = cl.color + '66'; c.lineWidth = 1.5;
      const rr = r + 6 + (cl.hasActive ? 3 * Math.sin(a.phase) : 0);
      c.beginPath(); c.arc(a.px, a.py, rr, 0, PI2); c.stroke(); c.shadowBlur = 0; c.restore();
      const lbl = cl.name.length > 22 ? cl.name.slice(0, 20) + '\u2026' : cl.name;
      c.font = '10px "JetBrains Mono",monospace'; c.textAlign = 'center';
      const tw = c.measureText(lbl).width; c.fillStyle = 'rgba(10,16,36,0.6)';
      if (c.roundRect) { c.beginPath(); c.roundRect(a.px - tw / 2 - 5, a.py + rr + 3, tw + 10, 14, 3); c.fill(); }
      c.fillStyle = '#b0c4dd'; c.fillText(lbl, a.px, a.py + rr + 14);
    });
  }
  function drawAgents(c) {
    S.agents.forEach(ag => {
      const a = S.anim.get(ag.id); if (!a || a.alpha < 0.01 || !a.px) return;
      const r = 9 * a.scale;
      c.save(); c.globalAlpha = a.alpha;
      c.shadowBlur = ag.isActive ? 10 : 3; c.shadowColor = ag.color;
      c.fillStyle = ag.color + (ag.isActive ? 'cc' : '55');
      c.beginPath(); c.arc(a.px, a.py, r, 0, PI2); c.fill(); c.shadowBlur = 0;
      c.fillStyle = '#0a1024'; c.font = `bold ${Math.max(7, 9 * a.scale)}px "JetBrains Mono",monospace`;
      c.textAlign = 'center'; c.textBaseline = 'middle';
      c.fillText(ag.status === 'waiting_thor' ? '\u26A1' : ag.isActive ? '\u25C6' : '\u25CF', a.px, a.py + 0.5);
      c.restore();
    });
  }
  function drawSessions(c, dt) {
    const sr = window._sessionClusters;
    if (!sr?.sessions.length) return;
    sr.tickAnims(dt);
    sr.render(c, sr.getSessionPositions(S.w, S.h), S.w, S.h);
  }
  function drawStats(c) {
    const act = S.agents.filter(a => a.isActive).length;
    const ps = (window._dashboardPlans || []).reduce((a, p) => ({ done: a.done + ((p.tasks || []).filter(t => t.status === 'done').length || 0), total: a.total + ((p.tasks || []).length || 0) }), { done: 0, total: 0 });
    const nodes = [...S.peerStats.entries()].slice(0, 3).map(([n, v]) => `${String(n).split(':')[0]}:${v.agents}`).join(', ');
    const txt = `${act} active \xB7 ${S.clusters.length} plan${S.clusters.length !== 1 ? 's' : ''} \xB7 nodes ${nodes || 'n/a'} \xB7 ${S.tokenFlow} tok \xB7 ${S.activeModels.size} model${S.activeModels.size !== 1 ? 's' : ''} \xB7 pipeline ${ps.done}/${ps.total}`;
    const el = document.getElementById('brain-stats'); if (el) el.textContent = txt;
  }
  const wsUrl = () => `${location.protocol === 'https:' ? 'wss' : 'ws'}://${location.host}/ws/brain`;
  const mapPeerRegion = (peer) => { if (S.peerRegion.has(peer)) return S.peerRegion.get(peer); const r = REGIONS[S.peerRegion.size % REGIONS.length]; S.peerRegion.set(peer, r); return r; };
  const regionPos = (k) => { const d = window.BrainRegions?.[k]?.center || { x: 0.5, y: 0.5 }; return { x: d.x * S.w, y: d.y * S.h }; };
  function pulse(from, to, col) { const a = regionPos(from), b = regionPos(to); S.particles.push({ sx: a.x, sy: a.y, tx: b.x, ty: b.y, t: 0, spd: 0.9 + Math.random() * 0.6, col: col || PAL.cyan, sz: 1.4 + Math.random() * 1.2 }); }
  function pollSessions() { fetch('/api/sessions').then(r => r.json()).then(d => { S.sessions = d || []; }).catch(() => {}); }
  function fallbackPolling(on) { if (on && !S.pollT) { pollSessions(); S.pollT = setInterval(pollSessions, 10000); } if (!on && S.pollT) { clearInterval(S.pollT); S.pollT = 0; } }
  function onBrainEvent(m) { if (!m) return; if (Array.isArray(m.sessions)) { S.sessions = m.sessions; if (window._sessionClusters) window._sessionClusters.update(m.sessions || [], m.orphan_agents || []); } if (m.kind !== 'agent_heartbeat') return; const p = m.payload || {}, peer = m.node || p.host || 'local', region = mapPeerRegion(peer), type = p.event_type || 'heartbeat'; const st = S.peerStats.get(peer) || { agents: 0, tokens: 0, models: new Set() }; st.agents = Math.max(1, st.agents + (type === 'start' ? 1 : type === 'complete' ? -1 : 0)); const tok = Number(p.tokens_total ?? ((p.tokens_in || 0) + (p.tokens_out || 0))) || 0; st.tokens = Math.max(0, st.tokens + tok); if (p.model) { st.models.add(p.model); S.activeModels.add(p.model); } S.peerStats.set(peer, st); S.tokenFlow = [...S.peerStats.values()].reduce((n, x) => n + (x.tokens || 0), 0); pulse(region, p.status === 'running' ? 'motor' : type === 'complete' ? 'hippocampus' : 'corpusCallosum', p.status === 'failed' ? PAL.red : p.status === 'completed' ? PAL.green : PAL.cyan); }
  function connectBrainWs() { try { S.ws = new WebSocket(wsUrl()); } catch { S.ws = null; } if (!S.ws) { fallbackPolling(true); return; } S.ws.onopen = () => { S.wsRetry = 0; S.wsLive = true; fallbackPolling(false); }; S.ws.onmessage = (e) => { try { onBrainEvent(JSON.parse(e.data)); } catch {} }; S.ws.onerror = () => S.ws?.close(); S.ws.onclose = () => { S.wsLive = false; fallbackPolling(true); clearTimeout(S.wsT); S.wsT = setTimeout(connectBrainWs, Math.min(30000, 1000 * Math.pow(2, S.wsRetry++))); }; }

  function drawIdle(c, ts) {
    const p = 0.5 + 0.5 * Math.sin(ts * 0.001), cx = S.w / 2, cy = S.h / 2;
    c.save(); c.strokeStyle = `rgba(0,229,255,${0.04 + p * 0.06})`; c.lineWidth = 1;
    c.beginPath(); c.arc(cx, cy, 35 + p * 8, 0, PI2); c.stroke();
    c.fillStyle = `rgba(176,196,221,${0.15 + p * 0.12})`; c.font = '12px "JetBrains Mono",monospace';
    c.textAlign = 'center'; c.fillText('No active agents', cx, cy + 55); c.restore();
  }
  function resize() {
    if (!S.container || !S.canvas) return;
    const r = S.container.getBoundingClientRect(), dpr = window.devicePixelRatio || 1;
    S.w = Math.max(10, r.width); S.h = Math.max(10, r.height);
    S.canvas.width = Math.floor(S.w * dpr); S.canvas.height = Math.floor(S.h * dpr);
    S.canvas.style.width = S.w + 'px'; S.canvas.style.height = S.h + 'px';
    S.ctx.setTransform(dpr, 0, 0, dpr, 0, 0);
  }
  function refreshData(ts) {
    if (ts - S.lastDataTick < 500) return;
    const { agents, clusters } = collectAgents();
    const curIds = new Set([...agents.map(a => a.id), ...clusters.map(c => c.id)]);
    [...S.agents, ...S.clusters].forEach(n => {
      if (!curIds.has(n.id)) { const a = S.anim.get(n.id); if (a && a.state !== 'completing') { a.state = 'completing'; a.t = 0; } }
    });
    S.agents = agents; S.clusters = clusters; S.lastDataTick = ts;
    agents.forEach(a => {
      const na = an(a.id);
      if (a.isActive && na.state !== 'appearing') na.state = 'active';
      else if (!a.isActive && na.state === 'active') na.state = 'idle';
    });
    clusters.forEach(c => an(c.id));
    const sr = window._sessionClusters;
    if (sr && window._dashboardAgentData) {
      const d = window._dashboardAgentData;
      sr.update(d.sessions || [], d.orphan_agents || []);
      sr.detectChanges();
    }
  }
  function render(ts) {
    if (!S.ctx || !S.running) return;
    const dt = Math.min(50, ts - (S.lastTs || ts)); S.lastTs = ts;
    refreshData(ts);
    const c = S.ctx; c.clearRect(0, 0, S.w, S.h); drawGrid(c);
    drawSessions(c, dt);
    if (!S.agents.length && !S.clusters.length && !S.sessions.length) { drawIdle(c, ts); drawStats(c); }
    else if (S.agents.length || S.clusters.length) { doLayout(); tickAnims(dt); tickParticles(dt); drawConns(c); drawParts(c); drawPlans(c); drawAgents(c); drawStats(c); }
    else { drawStats(c); }
    S.raf = requestAnimationFrame(render);
  }
  function onVis() {
    S.running = !document.hidden;
    if (S.running && !S.raf) S.raf = requestAnimationFrame(render);
    if (!S.running && S.raf) { cancelAnimationFrame(S.raf); S.raf = 0; }
  }
  window.initBrainCanvas = function(id) {
    window.destroyBrainCanvas();
    S.container = document.getElementById(id || 'brain-canvas-container'); if (!S.container) return;
    S.canvas = document.createElement('canvas'); S.canvas.className = 'brain-canvas';
    S.canvas.style.cssText = 'width:100%;height:100%;display:block;border-radius:8px;';
    S.container.appendChild(S.canvas); S.ctx = S.canvas.getContext('2d', { alpha: true }); resize();
    S.ro = new ResizeObserver(resize); S.ro.observe(S.container);
    window.addEventListener('resize', resize); document.addEventListener('visibilitychange', onVis);
    connectBrainWs(); fallbackPolling(true);
    S.running = !document.hidden; S.raf = requestAnimationFrame(render);
  };
  window.destroyBrainCanvas = function() {
    if (S.raf) cancelAnimationFrame(S.raf); S.raf = 0;
    if (S.ro) S.ro.disconnect(); S.ro = null;
    if (S.ws) S.ws.close(); S.ws = null; clearTimeout(S.wsT); S.wsT = 0; fallbackPolling(false);
    window.removeEventListener('resize', resize); document.removeEventListener('visibilitychange', onVis);
    if (S.canvas?.parentNode) S.canvas.parentNode.removeChild(S.canvas);
    S.container = S.canvas = S.ctx = null; S.particles = []; S.anim.clear(); S.layout = null; S.running = false; S.peerRegion.clear(); S.peerStats.clear(); S.activeModels.clear(); S.tokenFlow = 0;
  };
  window.updateBrainData = function() {};
  window.toggleBrainFreeze = function() {
    S.running = !S.running;
    const btn = document.getElementById('brain-pause-btn');
    if (btn) btn.textContent = S.running ? '▶' : '❚❚';
    if (S.running && S.container) { S.raf = requestAnimationFrame(render); }
  };
  window.rewindBrain = function() {
    S.particles = []; S.anim.clear();
    if (S.layout) S.layout.nodes.forEach(n => { n.vx = 0; n.vy = 0; });
  };
  const _boot = () => window.initBrainCanvas('brain-canvas-container');
  if (document.readyState === 'loading') document.addEventListener('DOMContentLoaded', _boot);
  else setTimeout(_boot, 100);
})();
