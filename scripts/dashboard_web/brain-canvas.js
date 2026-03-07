(() => {
  const S = {
    container: null, canvas: null, ctx: null, ro: null, raf: 0,
    snapshot: { peer_nodes: [], run_nodes: [], synapses: [] },
    w: 0, h: 0, id: null, running: true, positions: { plans: {}, tasks: {}, peers: {} },
    particles: new Map(),
  };

  const C = { cyan: '#00e5ff', red: '#ff3366', green: '#00ff88', gold: '#ffd700', dim: '#3a4466', off: '#1a2040' };
  const clamp = (v, a, b) => Math.max(a, Math.min(b, v));
  const lerp = (a, b, t) => a + (b - a) * t;

  function planKey(id) { return `plan:${id ?? 'unknown'}`; }
  function taskKey(r) { return r.id || `task:${r.task_id || Math.random()}`; }
  function runState(s) {
    if (s === 'running' || s === 'doing' || s === 'waiting') return 'in_progress';
    if (s === 'validating' || s === 'submitted') return 'submitted';
    if (s === 'blocked') return 'blocked';
    return 'pending';
  }
  function planState(tasks) {
    if (tasks.some((t) => runState(t.status) === 'blocked')) return 'blocked';
    if (tasks.some((t) => ['in_progress', 'submitted'].includes(runState(t.status)))) return 'doing';
    return 'todo';
  }

  function size() {
    if (!S.container || !S.canvas) return;
    const r = S.container.getBoundingClientRect();
    S.w = Math.max(10, r.width); S.h = Math.max(10, r.height);
    const dpr = window.devicePixelRatio || 1;
    S.canvas.width = Math.floor(S.w * dpr); S.canvas.height = Math.floor(S.h * dpr);
    S.canvas.style.width = `${S.w}px`; S.canvas.style.height = `${S.h}px`;
    S.ctx.setTransform(dpr, 0, 0, dpr, 0, 0);
  }

  function fallbackLayout(plans, tasks, peers, t) {
    const cx = S.w / 2, cy = S.h / 2;
    const pr = Math.min(S.w, S.h) * 0.26;
    plans.forEach((p, i) => {
      const a = (i / Math.max(1, plans.length)) * Math.PI * 2 - Math.PI / 2;
      S.positions.plans[p.id] = { x: cx + Math.cos(a) * pr, y: cy + Math.sin(a) * pr };
    });
    peers.forEach((p, i) => {
      const a = (i / Math.max(1, peers.length)) * Math.PI * 2 + t * 0.05;
      const rr = Math.min(S.w, S.h) * 0.45;
      S.positions.peers[p.id] = { x: cx + Math.cos(a) * rr, y: cy + Math.sin(a) * rr };
    });
    const grouped = tasks.reduce((m, r) => ((m[r.plan_id] ||= []).push(r), m), {});
    Object.keys(grouped).forEach((pid) => grouped[pid].forEach((r, i) => {
      const p = S.positions.plans[planKey(pid)] || { x: cx, y: cy };
      const a = (i / Math.max(1, grouped[pid].length)) * Math.PI * 2 + t * 0.001 * (0.8 + i * 0.05);
      const d = 60 + (i % 4) * 6;
      S.positions.tasks[taskKey(r)] = { x: p.x + Math.cos(a) * d, y: p.y + Math.sin(a) * d };
    }));
  }

  function layout(now) {
    const runs = S.snapshot.run_nodes || [], peers = S.snapshot.peer_nodes || [];
    const byPlan = runs.reduce((m, r) => ((m[r.plan_id ?? 'unknown'] ||= []).push(r), m), {});
    const plans = Object.keys(byPlan).map((id) => ({ id: planKey(id), raw: id, tasks: byPlan[id], status: planState(byPlan[id]) }));
    const bl = window.BrainLayout;
    if (bl) {
      const payload = { plans, tasks: runs, peers, width: S.w, height: S.h, prev: S.positions, now };
      let pos = null;
      if (typeof bl.compute === 'function') pos = bl.compute(payload);
      else if (typeof bl.layout === 'function') pos = bl.layout(payload);
      else if (typeof bl.getPositions === 'function') pos = bl.getPositions(payload);
      if (pos?.plans && pos?.tasks && pos?.peers) S.positions = pos; else fallbackLayout(plans, runs, peers, now);
    } else fallbackLayout(plans, runs, peers, now);
    return { plans, runs, peers };
  }

  function drawHex(x, y, r, stroke, fill, level) {
    const c = S.ctx; c.save(); c.translate(x, y);
    c.beginPath();
    for (let i = 0; i < 6; i++) {
      const a = Math.PI / 6 + (i * Math.PI) / 3;
      const px = Math.cos(a) * r, py = Math.sin(a) * r;
      if (!i) c.moveTo(px, py); else c.lineTo(px, py);
    }
    c.closePath(); c.strokeStyle = stroke; c.lineWidth = 2; c.stroke();
    c.save(); c.clip(); c.fillStyle = fill;
    c.fillRect(-r, r - 2 * r * clamp(level, 0, 1), 2 * r, 2 * r);
    c.restore(); c.restore();
  }

  function bezierPoint(p0, p1, p2, p3, t) {
    const u = 1 - t;
    const x = u * u * u * p0.x + 3 * u * u * t * p1.x + 3 * u * t * t * p2.x + t * t * t * p3.x;
    const y = u * u * u * p0.y + 3 * u * u * t * p1.y + 3 * u * t * t * p2.y + t * t * t * p3.y;
    return { x, y };
  }

  function render(ts) {
    if (!S.ctx || !S.running) return;
    const c = S.ctx; c.clearRect(0, 0, S.w, S.h);
    const { plans, runs, peers } = layout(ts);
    const active = runs.filter((r) => runState(r.status) === 'in_progress').length;
    const intensity = active === 0 ? { p: 2000, g: 0.25, e: 0 } : active < 3 ? { p: 1000, g: 0.55, e: 0.4 } : { p: 500, g: 0.95, e: 0.9 };
    const pulse = 0.5 + 0.5 * Math.sin((ts / intensity.p) * Math.PI * 2);

    (S.snapshot.synapses || []).forEach((s, i) => {
      if (!String(s.source).startsWith('peer:')) return;
      const a = S.positions.peers[s.source], b = S.positions.tasks[s.target]; if (!a || !b) return;
      const dy = (b.y - a.y) * 0.15, bend = ((i % 2) ? 1 : -1) * (25 + 18 * intensity.e);
      const p1 = { x: lerp(a.x, b.x, 0.35), y: a.y + dy + bend }, p2 = { x: lerp(a.x, b.x, 0.65), y: b.y - dy - bend };
      c.beginPath(); c.moveTo(a.x, a.y); c.bezierCurveTo(p1.x, p1.y, p2.x, p2.y, b.x, b.y);
      c.strokeStyle = `rgba(0,229,255,${0.15 + 0.4 * intensity.g})`; c.lineWidth = 1.2 + intensity.e * 1.3; c.stroke();
      const rs = runState((runs.find((r) => taskKey(r) === s.target) || {}).status);
      const targetN = rs === 'in_progress' ? 3 : rs === 'submitted' ? 1 : 0;
      const key = `${s.source}->${s.target}`; let arr = S.particles.get(key) || [];
      while (arr.length < targetN) arr.push({ t: Math.random(), v: 0.002 + Math.random() * 0.002 });
      arr = arr.slice(0, targetN); arr.forEach((p) => { p.t = (p.t + p.v * (1 + intensity.e * 1.5)) % 1; });
      S.particles.set(key, arr);
      arr.forEach((p) => {
        for (let k = 0; k < 3; k++) {
          const tt = (p.t - k * 0.03 + 1) % 1, q = bezierPoint(a, p1, p2, b, tt);
          c.fillStyle = `rgba(0,229,255,${0.9 - k * 0.28})`; c.beginPath(); c.arc(q.x, q.y, 3 - k * 0.5, 0, Math.PI * 2); c.fill();
        }
      });
    });

    plans.forEach((p) => {
      const pos = S.positions.plans[p.id]; if (!pos) return;
      const col = p.status === 'doing' ? C.cyan : p.status === 'blocked' ? C.red : C.dim;
      const amp = clamp((p.tasks.length || 0) / 5, 0.2, 1.4);
      const ring = 36 + (2 + 8 * amp) * pulse;
      c.shadowBlur = 18 * intensity.g + 10 * pulse; c.shadowColor = col;
      c.beginPath(); c.arc(pos.x, pos.y, ring, 0, Math.PI * 2); c.strokeStyle = `${col}99`; c.lineWidth = 2 + intensity.e; c.stroke();
      const g = c.createRadialGradient(pos.x - 8, pos.y - 8, 8, pos.x, pos.y, 30);
      g.addColorStop(0, `${col}cc`); g.addColorStop(1, `${col}33`);
      c.fillStyle = g; c.beginPath(); c.arc(pos.x, pos.y, 30, 0, Math.PI * 2); c.fill();
      c.shadowBlur = 0; c.fillStyle = '#d7e7ff'; c.font = '12px Inter, system-ui, sans-serif'; c.textAlign = 'center';
      const raw = String(p.raw); c.fillText(`#${raw} Plan`, pos.x, pos.y + 48);
    });

    runs.forEach((r) => {
      const p = S.positions.tasks[taskKey(r)]; if (!p) return;
      const st = runState(r.status); const col = st === 'in_progress' ? C.green : st === 'submitted' ? C.gold : st === 'blocked' ? C.red : C.dim;
      const age = Math.max(0, ((S.snapshot.generated_at || Date.now() / 1000) - (r.last_seen || S.snapshot.generated_at || 0)));
      const hot = clamp(1 - age / 20, 0, 1); c.shadowBlur = 8 + hot * 14; c.shadowColor = col;
      c.fillStyle = `${col}${st === 'pending' ? '66' : 'cc'}`; c.beginPath(); c.arc(p.x, p.y, 16, 0, Math.PI * 2); c.fill(); c.shadowBlur = 0;
      c.fillStyle = '#0a1024'; c.font = 'bold 12px JetBrains Mono, monospace'; c.textAlign = 'center'; c.textBaseline = 'middle';
      const a = String(r.agent_name || '').toLowerCase(); c.fillText(a.includes('claude') ? '◆' : a.includes('copilot') ? '⬡' : '●', p.x, p.y + 0.5);
    });

    peers.forEach((peer) => {
      const p = S.positions.peers[peer.id]; if (!p) return;
      drawHex(p.x, p.y, 20, peer.is_online ? C.cyan : C.off, 'rgba(0,229,255,0.25)', (peer.cpu || 0) / 100);
      c.fillStyle = '#aac4ff'; c.font = '11px Inter, system-ui, sans-serif'; c.textAlign = 'center'; c.fillText(peer.peer_name || 'peer', p.x, p.y + 32);
    });

    if (intensity.e > 0.8) {
      c.strokeStyle = 'rgba(0,229,255,0.25)'; c.lineWidth = 3; c.strokeRect(1.5, 1.5, S.w - 3, S.h - 3);
    }
    S.raf = requestAnimationFrame(render);
  }

  function onVis() {
    S.running = !document.hidden;
    if (S.running && !S.raf) S.raf = requestAnimationFrame(render);
    if (!S.running && S.raf) { cancelAnimationFrame(S.raf); S.raf = 0; }
  }

  window.initBrainCanvas = function initBrainCanvas(containerId) {
    window.destroyBrainCanvas();
    S.id = containerId; S.container = document.getElementById(containerId); if (!S.container) return;
    S.canvas = document.createElement('canvas'); S.canvas.className = 'brain-canvas'; S.container.appendChild(S.canvas);
    S.ctx = S.canvas.getContext('2d', { alpha: true }); size();
    S.ro = new ResizeObserver(size); S.ro.observe(S.container); window.addEventListener('resize', size);
    document.addEventListener('visibilitychange', onVis); S.running = !document.hidden; S.raf = requestAnimationFrame(render);
  };

  window.updateBrainData = function updateBrainData(snapshot) {
    if (!snapshot) return;
    S.snapshot = { ...snapshot, peer_nodes: snapshot.peer_nodes || [], run_nodes: snapshot.run_nodes || [], synapses: snapshot.synapses || [] };
  };

  window.destroyBrainCanvas = function destroyBrainCanvas() {
    if (S.raf) cancelAnimationFrame(S.raf); S.raf = 0;
    if (S.ro) S.ro.disconnect(); S.ro = null;
    window.removeEventListener('resize', size); document.removeEventListener('visibilitychange', onVis);
    if (S.canvas?.parentNode) S.canvas.parentNode.removeChild(S.canvas);
    S.container = S.canvas = S.ctx = null; S.particles.clear();
  };
})();
