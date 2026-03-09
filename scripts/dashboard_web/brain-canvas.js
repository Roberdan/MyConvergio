/* brain-canvas.js — Neural network force-directed graph visualization */
(() => {
  'use strict';
  const PI2 = Math.PI * 2;
  const PAL = {
    claude: { h: 35, core: '#ffb020', glow: 'rgba(255,176,32,', ring: '#ffd06088' },
    copilot: { h: 210, core: '#20a0ff', glow: 'rgba(32,160,255,', ring: '#60c0ff88' },
    sub: { core: '#00e5ff', glow: 'rgba(0,229,255,' },
    plan: { core: '#00ff88', glow: 'rgba(0,255,136,' },
    task: { core: '#ffd700', glow: 'rgba(255,215,0,' },
    synapse: 'rgba(0,229,255,', green: '#00ff88', dim: '#2a3456'
  };

  /* ─── Node / Edge state ─── */
  class Neuron {
    constructor(id, type, label, meta) {
      this.id = id; this.type = type; this.label = label; this.meta = meta || {};
      this.x = 0; this.y = 0; this.vx = 0; this.vy = 0;
      this.radius = type === 'session' ? 18 : 8;
      this.phase = Math.random() * PI2;
      this.birth = performance.now();
      this.scale = 0; this.targetScale = 1;
      this.active = true; this.dying = false; this.deathT = 0;
      this.tool = 'claude';
      this.fireT = 0;
    }
    get pal() {
      if (this.type === 'plan') return PAL.plan;
      if (this.type === 'task') return PAL.task;
      return PAL[this.tool] || PAL.claude;
    }
    fire() { this.fireT = performance.now(); }
  }
  class Synapse {
    constructor(from, to) {
      this.from = from; this.to = to;
      this.particles = []; this.lastFire = 0; this.strength = 0.3;
    }
    fire() {
      this.lastFire = performance.now();
      for (let i = 0; i < 2 + Math.floor(Math.random() * 3); i++) {
        this.particles.push({ t: 0, speed: 0.3 + Math.random() * 0.6, size: 1 + Math.random() * 2 });
      }
    }
  }

  const S = {
    container: null, canvas: null, ctx: null, w: 0, h: 0, dpr: 1,
    raf: 0, running: true, lastTs: 0,
    neurons: new Map(), synapses: [], coreNeuron: null,
    pollT: 0, ws: null, wsRetry: 0, wsT: 0,
    sessions: [], agents: [], brainData: null,
    hover: null, mouse: { x: -1, y: -1 }
  };

  /* ─── Force-directed layout ─── */
  function applyForces() {
    const nodes = [...S.neurons.values()].filter(n => !n.dying);
    const cx = S.w / 2, cy = S.h / 2;
    const k = 90;

    for (const n of nodes) {
      // Strong gravity toward center (proportional to distance)
      const dx = cx - n.x, dy = cy - n.y;
      const dist = Math.sqrt(dx * dx + dy * dy) || 1;
      const grav = 0.003 + (dist > S.w * 0.35 ? 0.008 : 0);
      n.vx += dx * grav;
      n.vy += dy * grav;

      // Repulsion — only between nearby nodes, softer force
      for (const m of nodes) {
        if (m === n) continue;
        const rx = n.x - m.x, ry = n.y - m.y;
        const d = Math.sqrt(rx * rx + ry * ry) || 1;
        if (d < k * 2) {
          const f = (k * k) / (d * d) * 0.25;
          n.vx += (rx / d) * f;
          n.vy += (ry / d) * f;
        }
      }
    }
    // Spring force along synapses
    for (const syn of S.synapses) {
      const a = S.neurons.get(syn.from), b = S.neurons.get(syn.to);
      if (!a || !b) continue;
      const dx = b.x - a.x, dy = b.y - a.y;
      const d = Math.sqrt(dx * dx + dy * dy) || 1;
      const ideal = (a.type === 'session' && b.type === 'session') ? k * 1.8 : k * 0.9;
      const f = (d - ideal) * 0.003;
      const fx = (dx / d) * f, fy = (dy / d) * f;
      a.vx += fx; a.vy += fy;
      b.vx -= fx; b.vy -= fy;
    }
    // Integrate with damping + soft bounds
    for (const n of nodes) {
      n.vx *= 0.85; n.vy *= 0.85;
      n.x += n.vx; n.y += n.vy;
      // Soft boundary — push back if near edges
      const pad = 60;
      if (n.x < pad) n.vx += (pad - n.x) * 0.05;
      if (n.x > S.w - pad) n.vx -= (n.x - (S.w - pad)) * 0.05;
      if (n.y < pad) n.vy += (pad - n.y) * 0.05;
      if (n.y > S.h - pad) n.vy -= (n.y - (S.h - pad)) * 0.05;
      n.x = Math.max(20, Math.min(S.w - 20, n.x));
      n.y = Math.max(20, Math.min(S.h - 20, n.y));
    }
  }

  /* ─── Rendering ─── */
  function drawGrid(c) {
    c.strokeStyle = 'rgba(0,229,255,0.02)'; c.lineWidth = 0.5;
    for (let x = 0; x < S.w; x += 50) { c.beginPath(); c.moveTo(x, 0); c.lineTo(x, S.h); c.stroke(); }
    for (let y = 0; y < S.h; y += 50) { c.beginPath(); c.moveTo(0, y); c.lineTo(S.w, y); c.stroke(); }
  }

  function drawSynapses(c, ts) {
    for (const syn of S.synapses) {
      const a = S.neurons.get(syn.from), b = S.neurons.get(syn.to);
      if (!a || !b) continue;
      const age = ts - syn.lastFire;
      const glow = age < 800 ? 1 - age / 800 : 0;
      const baseAlpha = 0.06 + syn.strength * 0.1 + glow * 0.3;

      // Curved synapse
      const mx = (a.x + b.x) / 2 + (a.y - b.y) * 0.12;
      const my = (a.y + b.y) / 2 - (a.x - b.x) * 0.12;

      c.beginPath(); c.moveTo(a.x, a.y); c.quadraticCurveTo(mx, my, b.x, b.y);
      c.strokeStyle = `${PAL.synapse}${baseAlpha.toFixed(3)})`;
      c.lineWidth = 0.8 + glow * 2;
      if (glow > 0) { c.shadowBlur = 8; c.shadowColor = `${PAL.synapse}${(glow * 0.5).toFixed(2)})`; }
      c.stroke(); c.shadowBlur = 0;

      // Particles along synapse
      for (let i = syn.particles.length - 1; i >= 0; i--) {
        const p = syn.particles[i];
        p.t += p.speed * 0.016;
        if (p.t >= 1) { syn.particles.splice(i, 1); continue; }
        const u = 1 - p.t;
        const px = u * u * a.x + 2 * u * p.t * mx + p.t * p.t * b.x;
        const py = u * u * a.y + 2 * u * p.t * my + p.t * p.t * b.y;
        const alpha = p.t > 0.8 ? (1 - p.t) / 0.2 : 0.9;
        c.save(); c.globalAlpha = alpha;
        c.fillStyle = a.pal.core; c.shadowBlur = 6; c.shadowColor = a.pal.core;
        c.beginPath(); c.arc(px, py, p.size, 0, PI2); c.fill();
        c.restore();
      }
    }
  }

  function drawNeurons(c, ts) {
    for (const [, n] of S.neurons) {
      // Animate scale
      if (n.dying) {
        n.scale = Math.max(0, n.scale - 0.03);
        if (n.scale <= 0) continue;
      } else {
        n.scale += (n.targetScale - n.scale) * 0.08;
      }
      n.phase += 0.003;
      const pulse = 1 + 0.06 * Math.sin(n.phase * 3);
      const r = n.radius * n.scale * pulse;
      if (r < 0.5) continue;

      const fireAge = ts - n.fireT;
      const fireGlow = fireAge < 600 ? 1 - fireAge / 600 : 0;
      const pal = n.pal;

      c.save();
      // Outer glow
      c.shadowBlur = 12 + fireGlow * 20;
      c.shadowColor = `${pal.glow}${(0.3 + fireGlow * 0.5).toFixed(2)})`;
      // Core gradient
      const g = c.createRadialGradient(n.x - r * 0.2, n.y - r * 0.2, r * 0.1, n.x, n.y, r);
      g.addColorStop(0, `${pal.glow}${(0.9 + fireGlow * 0.1).toFixed(2)})`);
      g.addColorStop(0.7, `${pal.glow}0.4)`);
      g.addColorStop(1, `${pal.glow}0.05)`);
      c.fillStyle = g;
      c.beginPath(); c.arc(n.x, n.y, r, 0, PI2); c.fill();
      // Ring
      c.shadowBlur = 0;
      c.strokeStyle = `${pal.glow}${(0.15 + fireGlow * 0.4 + 0.08 * Math.sin(n.phase * 2)).toFixed(3)})`;
      c.lineWidth = n.type === 'session' ? 1.5 : 0.8;
      c.beginPath(); c.arc(n.x, n.y, r + 4 + 2 * Math.sin(n.phase), 0, PI2); c.stroke();
      c.restore();

      // Label
      if (n.type === 'session') {
        const isHover = S.hover === n.id;
        c.font = `${isHover ? 'bold ' : ''}11px "JetBrains Mono",monospace`;
        c.textAlign = 'center';
        const ly = n.y + r + 16;
        const lbl = n.label;
        const tw = c.measureText(lbl).width;
        // Background pill
        c.fillStyle = `rgba(10,16,36,${isHover ? 0.85 : 0.65})`;
        c.beginPath();
        if (c.roundRect) c.roundRect(n.x - tw / 2 - 6, ly - 9, tw + 12, 16, 4);
        else { c.rect(n.x - tw / 2 - 6, ly - 9, tw + 12, 16); }
        c.fill();
        c.fillStyle = isHover ? '#fff' : '#b0c4dd';
        c.fillText(lbl, n.x, ly + 3);
        // Meta info on hover
        if (isHover && n.meta.tty) {
          const info = [n.meta.tty, `PID ${n.meta.pid || '?'}`,
            n.meta.cpu != null ? `CPU ${n.meta.cpu}%` : '',
            n.meta.mem != null ? `MEM ${n.meta.mem}%` : ''].filter(Boolean).join(' · ');
          c.font = '9px "JetBrains Mono",monospace';
          c.fillStyle = PAL.sub.core;
          c.fillText(info, n.x, ly + 16);
        }
      }
    }
  }

  function render(ts) {
    if (!S.ctx || !S.running) return;
    S.lastTs = ts;
    applyForces();
    const c = S.ctx;
    c.clearRect(0, 0, S.w, S.h);
    drawGrid(c);
    drawSynapses(c, ts);
    drawNeurons(c, ts);
    drawTooltip(c);
    S.raf = requestAnimationFrame(render);
  }

  /* ─── Data → Graph sync ─── */
  function parseMeta(s) { try { return typeof s === 'string' ? JSON.parse(s) : (s || {}); } catch { return {}; } }
  function toolOf(id, type) { return (type?.includes('copilot') || id?.includes('copilot')) ? 'copilot' : 'claude'; }
  function fmtDur(s) { if (!s || s < 0) return ''; if (s < 60) return `${Math.round(s)}s`; if (s < 3600) return `${Math.round(s/60)}m`; return `${(s/3600).toFixed(1)}h`; }
  function fmtTok(n) { if (!n) return '0'; if (n > 1000000) return `${(n/1000000).toFixed(1)}M`; if (n > 1000) return `${(n/1000).toFixed(1)}k`; return String(n); }

  function syncGraph() {
    const now = performance.now();
    const active = S.sessions.filter(s => s.status === 'running');
    const activeIds = new Set();

    // Session neurons (radial layout around center)
    for (let i = 0; i < active.length; i++) {
      const sess = active[i];
      const meta = parseMeta(sess.metadata);
      const tool = toolOf(sess.session_id, sess.type);
      const tty = meta.tty || '';
      const label = `${tool === 'copilot' ? 'Copilot' : 'Claude'}${tty ? ' ' + tty : ''}`;
      activeIds.add(sess.session_id);

      // Enrich meta with API data
      meta.duration_s = sess.duration_s; meta.tokens_total = sess.tokens_total;
      meta.tokens_in = sess.tokens_in; meta.tokens_out = sess.tokens_out;
      meta.cost_usd = sess.cost_usd; meta.model = sess.model;
      meta.description = sess.description; meta.started_at = sess.started_at;

      if (!S.neurons.has(sess.session_id)) {
        const n = new Neuron(sess.session_id, 'session', label, meta);
        n.tool = tool;
        // Radial initial position
        const angle = (i / Math.max(active.length, 1)) * PI2 - Math.PI / 2;
        const radius = Math.min(S.w, S.h) * 0.28;
        n.x = S.w / 2 + Math.cos(angle) * radius;
        n.y = S.h / 2 + Math.sin(angle) * radius;
        n.targetRadius = radius; n.targetAngle = angle;
        S.neurons.set(sess.session_id, n);
        // Connect to same-tool sessions only (Claude↔Claude, Copilot↔Copilot) — not all-to-all
        for (const [oid, other] of S.neurons) {
          if (oid !== sess.session_id && other.type === 'session' && !other.dying && other.tool === tool) {
            S.synapses.push(new Synapse(sess.session_id, oid));
          }
        }
        setTimeout(() => { const nn = S.neurons.get(sess.session_id); if (nn) { nn.fire(); fireSynapsesFor(sess.session_id); } }, 300);
      } else {
        const n = S.neurons.get(sess.session_id);
        n.label = label; n.meta = meta; n.active = true;
      }

      // Sub-agent neurons
      for (const child of (sess.children || [])) {
        if (child.status !== 'running') continue;
        activeIds.add(child.agent_id);
        if (!S.neurons.has(child.agent_id)) {
          const cn = new Neuron(child.agent_id, 'sub', child.model || child.type || 'agent', {
            model: child.model, description: child.description, duration_s: child.duration_s,
            tokens_total: child.tokens_total, cost_usd: child.cost_usd
          });
          cn.tool = tool;
          const parent = S.neurons.get(sess.session_id);
          cn.x = (parent?.x || S.w / 2) + (Math.random() - 0.5) * 50;
          cn.y = (parent?.y || S.h / 2) + (Math.random() - 0.5) * 50;
          S.neurons.set(child.agent_id, cn);
          S.synapses.push(new Synapse(sess.session_id, child.agent_id));
          setTimeout(() => fireSynapsesFor(child.agent_id), 200);
        } else {
          S.neurons.get(child.agent_id).meta = { model: child.model, description: child.description, duration_s: child.duration_s, tokens_total: child.tokens_total };
        }
      }
    }

    // Plan neurons
    for (const plan of (S.brainData?.plans || [])) {
      const pid = `plan-${plan.id}`;
      activeIds.add(pid);
      if (!S.neurons.has(pid)) {
        const pn = new Neuron(pid, 'plan', `#${plan.id} ${(plan.name || '').substring(0, 20)}`, {
          name: plan.name, status: plan.status, progress: plan.progress_pct,
          tasks_done: plan.tasks_done, tasks_total: plan.tasks_total, host: plan.execution_host
        });
        pn.tool = 'claude'; pn.radius = 14;
        pn.x = S.w / 2 + (Math.random() - 0.5) * 60;
        pn.y = S.h / 2 + (Math.random() - 0.5) * 60;
        S.neurons.set(pid, pn);
      } else {
        S.neurons.get(pid).meta = { name: plan.name, progress: plan.progress_pct, tasks_done: plan.tasks_done, tasks_total: plan.tasks_total };
      }
    }

    // Task neurons linked to plans
    for (const task of (S.brainData?.tasks || [])) {
      const tid = `task-${task.id}`;
      activeIds.add(tid);
      const planNid = `plan-${task.plan_id}`;
      if (!S.neurons.has(tid)) {
        const tn = new Neuron(tid, 'task', (task.title || '').substring(0, 25), {
          title: task.title, status: task.status, priority: task.priority,
          type: task.task_type, plan_name: task.plan_name, wave_name: task.wave_name
        });
        tn.tool = 'claude'; tn.radius = 6;
        const planN = S.neurons.get(planNid);
        tn.x = (planN?.x || S.w / 2) + (Math.random() - 0.5) * 40;
        tn.y = (planN?.y || S.h / 2) + (Math.random() - 0.5) * 40;
        S.neurons.set(tid, tn);
        if (S.neurons.has(planNid)) S.synapses.push(new Synapse(planNid, tid));
        // Link task to executor session if known
        if (task.executor_session_id && S.neurons.has(task.executor_session_id)) {
          S.synapses.push(new Synapse(task.executor_session_id, tid));
        }
      }
    }

    // Mark dead + cleanup
    for (const [id, n] of S.neurons) {
      if (!activeIds.has(id) && !n.dying) { n.dying = true; n.deathT = now; }
    }
    for (const [id, n] of S.neurons) {
      if (n.dying && n.scale <= 0) { S.neurons.delete(id); S.synapses = S.synapses.filter(s => s.from !== id && s.to !== id); }
    }

    // Ambient synapse firing
    if (S.synapses.length && Math.random() < 0.15) {
      const syn = S.synapses[Math.floor(Math.random() * S.synapses.length)];
      syn.fire(); const t = S.neurons.get(syn.to); if (t) t.fire();
    }
    updateStats();
  }

  function fireSynapsesFor(id) {
    for (const syn of S.synapses) {
      if (syn.from === id || syn.to === id) syn.fire();
    }
  }

  function updateStats() {
    const el = document.getElementById('brain-stats');
    if (!el) return;
    const running = S.sessions.filter(s => s.status === 'running');
    const claude = running.filter(s => toolOf(s.session_id, s.type) === 'claude').length;
    const copilot = running.filter(s => toolOf(s.session_id, s.type) === 'copilot').length;
    const plans = (S.brainData?.plans || []).length;
    const tasks = (S.brainData?.tasks || []).length;
    const syns = S.synapses.length;
    el.textContent = `${running.length} sessions · ${claude}C/${copilot}P · ${plans} plans · ${tasks} tasks · ${syns} synapses`;
  }

  /* ─── Hover tooltip (summary) ─── */
  function drawTooltip(c) {
    if (!S.hover) return;
    const n = S.neurons.get(S.hover);
    if (!n) return;
    const m = n.meta || {};
    const lines = [];
    if (n.type === 'session') {
      lines.push(n.label);
      if (m.tty) lines.push(`TTY ${m.tty} · PID ${m.pid || '?'}`);
      if (m.cpu != null) lines.push(`CPU ${m.cpu}% · MEM ${m.mem || 0}%`);
      if (m.duration_s) lines.push(`Duration: ${fmtDur(m.duration_s)}`);
      if (m.tokens_total) lines.push(`Tokens: ${fmtTok(m.tokens_total)}`);
      if (m.model && m.model !== 'claude-cli' && m.model !== 'copilot-cli') lines.push(`Model: ${m.model}`);
      if (m.description && m.description.trim().length > 2) lines.push(`Cmd: ${m.description.trim().substring(0, 40)}`);
    } else if (n.type === 'plan') {
      lines.push(m.name || n.label);
      lines.push(`Progress: ${m.tasks_done || 0}/${m.tasks_total || 0} (${m.progress || 0}%)`);
      if (m.host) lines.push(`Host: ${m.host}`);
    } else if (n.type === 'task') {
      lines.push(m.title || n.label);
      lines.push(`Status: ${m.status || '?'}${m.priority ? ' · ' + m.priority : ''}`);
      if (m.wave_name) lines.push(`Wave: ${m.wave_name}`);
      if (m.plan_name) lines.push(`Plan: ${m.plan_name.substring(0, 30)}`);
    } else {
      lines.push(n.label);
      if (m.model) lines.push(`Model: ${m.model}`);
      if (m.duration_s) lines.push(`Duration: ${fmtDur(m.duration_s)}`);
      if (m.tokens_total) lines.push(`Tokens: ${fmtTok(m.tokens_total)}`);
      if (m.description) lines.push(m.description.substring(0, 40));
    }

    const lh = 14, pad = 10;
    const maxW = Math.max(...lines.map(l => c.measureText ? 8 * l.length : 100));
    const tw = Math.min(280, maxW + pad * 2);
    const th = lines.length * lh + pad * 2;
    let tx = n.x + n.radius + 15, ty = n.y - th / 2;
    if (tx + tw > S.w - 10) tx = n.x - n.radius - tw - 15;
    if (ty < 10) ty = 10; if (ty + th > S.h - 10) ty = S.h - th - 10;

    c.save();
    c.fillStyle = 'rgba(8,12,32,0.92)';
    c.strokeStyle = `${n.pal.glow}0.3)`;
    c.lineWidth = 1; c.shadowBlur = 12; c.shadowColor = `${n.pal.glow}0.2)`;
    c.beginPath();
    if (c.roundRect) c.roundRect(tx, ty, tw, th, 6);
    else c.rect(tx, ty, tw, th);
    c.fill(); c.stroke(); c.shadowBlur = 0;
    c.font = '10px "JetBrains Mono",monospace'; c.textAlign = 'left';
    lines.forEach((line, i) => {
      c.fillStyle = i === 0 ? '#fff' : (line.startsWith('Cmd:') ? PAL.sub.core : '#8899bb');
      c.fillText(line, tx + pad, ty + pad + (i + 1) * lh - 3);
    });
    c.restore();
  }

  /* ─── Click detail panel ─── */
  function showDetailPanel(id) {
    const n = S.neurons.get(id);
    if (!n) return;
    let panel = document.getElementById('brain-detail');
    if (!panel) {
      panel = document.createElement('div'); panel.id = 'brain-detail';
      panel.style.cssText = 'position:absolute;right:12px;top:12px;width:280px;max-height:440px;overflow-y:auto;background:rgba(8,12,32,0.95);border:1px solid rgba(0,229,255,0.2);border-radius:8px;padding:14px;z-index:10;font:10px "JetBrains Mono",monospace;color:#b0c4dd;backdrop-filter:blur(12px);';
      S.container.appendChild(panel);
    }
    const m = n.meta || {};
    let html = `<div style="display:flex;justify-content:space-between;align-items:center;margin-bottom:10px"><span style="font:bold 12px 'JetBrains Mono',monospace;color:${n.pal.core}">${n.label}</span><span style="cursor:pointer;color:#5a6080;font-size:14px" onclick="this.parentElement.parentElement.remove()">✕</span></div>`;
    const row = (k, v) => v ? `<div style="display:flex;justify-content:space-between;padding:2px 0"><span style="color:#5a6080">${k}</span><span style="color:#e0e4f0">${v}</span></div>` : '';
    if (n.type === 'session') {
      html += row('PID', m.pid); html += row('TTY', m.tty);
      html += row('CPU', m.cpu != null ? m.cpu + '%' : ''); html += row('MEM', m.mem != null ? m.mem + '%' : '');
      html += row('Duration', fmtDur(m.duration_s)); html += row('Model', m.model);
      html += row('Tokens In', fmtTok(m.tokens_in)); html += row('Tokens Out', fmtTok(m.tokens_out));
      html += row('Total Tok', fmtTok(m.tokens_total)); html += row('Cost', m.cost_usd ? '$' + Number(m.cost_usd).toFixed(4) : '');
      html += row('Started', m.started_at || '');
      if (m.description && m.description.trim().length > 2) {
        html += `<div style="margin-top:8px;padding-top:8px;border-top:1px solid #1a2040"><span style="color:#5a6080">Last command</span><div style="color:#00e5ff;margin-top:4px;word-break:break-all">${m.description.trim().substring(0, 120)}</div></div>`;
      }
      // Show related recent agents
      const children = (S.sessions.find(s => s.session_id === id)?.children || []);
      if (children.length) {
        html += `<div style="margin-top:8px;padding-top:8px;border-top:1px solid #1a2040"><span style="color:#5a6080">Sub-agents (${children.length})</span>`;
        children.forEach(ch => {
          const st = ch.status === 'running' ? '🟢' : '⚪';
          html += `<div style="padding:2px 0">${st} ${(ch.model || ch.type || '').substring(0, 20)} ${fmtDur(ch.duration_s)} ${fmtTok(ch.tokens_total)}tok</div>`;
        });
        html += '</div>';
      }
      // Show recent completed agents for this session
      const recent = (S.brainData?.recent || []).filter(r => r.parent_session === id).slice(0, 5);
      if (recent.length) {
        html += `<div style="margin-top:8px;padding-top:8px;border-top:1px solid #1a2040"><span style="color:#5a6080">Recent completed</span>`;
        recent.forEach(r => {
          const ok = r.status === 'completed' ? '✓' : '✗';
          html += `<div style="padding:2px 0;color:${r.status === 'completed' ? '#00ff88' : '#ff3366'}">${ok} ${(r.model || '').substring(0, 15)} ${fmtDur(r.duration_s)} ${fmtTok(r.tokens_total)}tok</div>`;
        });
        html += '</div>';
      }
    } else if (n.type === 'plan') {
      html += row('Status', m.status); html += row('Host', m.host);
      html += row('Progress', `${m.tasks_done || 0}/${m.tasks_total || 0}`);
      html += `<div style="margin:6px 0;height:4px;background:#1a2040;border-radius:2px"><div style="height:100%;width:${m.progress || 0}%;background:linear-gradient(90deg,#00e5ff,#00ff88);border-radius:2px"></div></div>`;
      const planTasks = (S.brainData?.tasks || []).filter(t => t.plan_id === m.id || t.plan_id == n.id.replace('plan-',''));
      if (planTasks.length) {
        html += `<div style="margin-top:8px;border-top:1px solid #1a2040;padding-top:8px"><span style="color:#5a6080">Tasks</span>`;
        planTasks.forEach(t => {
          const dot = t.status === 'in_progress' ? '🔵' : '⚪';
          html += `<div style="padding:2px 0">${dot} ${(t.title || '').substring(0, 35)} <span style="color:#5a6080">${t.priority || ''}</span></div>`;
        });
        html += '</div>';
      }
    } else if (n.type === 'task') {
      html += row('Status', m.status); html += row('Priority', m.priority); html += row('Type', m.type);
      html += row('Wave', m.wave_name); html += row('Plan', m.plan_name);
      if (m.title) html += `<div style="margin-top:6px;color:#e0e4f0">${m.title}</div>`;
    } else {
      html += row('Model', m.model); html += row('Duration', fmtDur(m.duration_s));
      html += row('Tokens', fmtTok(m.tokens_total));
      if (m.description) html += `<div style="margin-top:6px;color:#00e5ff;word-break:break-all">${m.description.substring(0, 120)}</div>`;
    }
    panel.innerHTML = html;
  }

  /* ─── Polling ─── */
  function pollData() {
    fetch('/api/brain').then(r => r.json()).then(data => {
      S.brainData = data;
      const sessions = data.sessions || [];
      const agents = data.agents || [];
      const childMap = new Map();
      agents.forEach(a => {
        if (a.parent_session) {
          if (!childMap.has(a.parent_session)) childMap.set(a.parent_session, []);
          childMap.get(a.parent_session).push(a);
        }
      });
      S.sessions = sessions.map(s => ({
        session_id: s.agent_id, type: s.type || 'claude-cli', status: s.status,
        metadata: s.metadata, description: s.description, started_at: s.started_at,
        duration_s: s.duration_s, tokens_total: s.tokens_total, tokens_in: s.tokens_in,
        tokens_out: s.tokens_out, cost_usd: s.cost_usd, model: s.model,
        children: (childMap.get(s.agent_id) || []).map(c => ({
          agent_id: c.agent_id, type: c.type, model: c.model, description: c.description,
          status: 'running', duration_s: c.duration_s, tokens_total: c.tokens_total, cost_usd: c.cost_usd
        }))
      }));
      S.agents = agents;
      window._dashboardAgentData = { sessions: S.sessions, orphan_agents: [] };
      syncGraph();
    }).catch(() => {
      // Fallback to old endpoints
      Promise.all([
        fetch('/api/sessions').then(r => r.json()).catch(() => []),
        fetch('/api/agents').then(r => r.json()).catch(() => ({ running: [] }))
      ]).then(([rawSessions, agentData]) => {
        const running = agentData.running || [];
        const childMap = new Map();
        running.forEach(a => { if (a.parent_session) { if (!childMap.has(a.parent_session)) childMap.set(a.parent_session, []); childMap.get(a.parent_session).push(a); } });
        S.sessions = (rawSessions || []).map(s => ({
          session_id: s.agent_id, type: s.type, status: s.status, metadata: s.metadata,
          description: s.description, duration_s: s.duration_s, tokens_total: s.tokens_total, model: s.model,
          children: (childMap.get(s.agent_id) || []).map(c => ({ agent_id: c.agent_id, type: c.type, model: c.model, description: c.description, status: 'running', duration_s: c.duration_s }))
        }));
        syncGraph();
      });
    });
  }

  /* ─── Mouse interaction ─── */
  function hitTest(x, y) {
    for (const [id, n] of S.neurons) {
      const dx = x - n.x, dy = y - n.y;
      if (dx * dx + dy * dy < (n.radius + 12) * (n.radius + 12)) return id;
    }
    return null;
  }
  function onMouseMove(e) {
    const r = S.canvas.getBoundingClientRect();
    S.mouse.x = e.clientX - r.left; S.mouse.y = e.clientY - r.top;
    S.hover = hitTest(S.mouse.x, S.mouse.y);
    S.canvas.style.cursor = S.hover ? 'pointer' : 'default';
  }
  function onMouseLeave() { S.hover = null; S.mouse.x = -1; S.mouse.y = -1; }
  function onClick(e) {
    const r = S.canvas.getBoundingClientRect();
    const x = e.clientX - r.left, y = e.clientY - r.top;
    const hit = hitTest(x, y);
    if (hit) {
      showDetailPanel(hit);
      // Fire synapses from clicked neuron
      fireSynapsesFor(hit);
      const n = S.neurons.get(hit); if (n) n.fire();
    } else {
      const panel = document.getElementById('brain-detail');
      if (panel) panel.remove();
    }
  }

  /* ─── Resize ─── */
  function resize() {
    if (!S.container || !S.canvas) return;
    const r = S.container.getBoundingClientRect();
    S.dpr = window.devicePixelRatio || 1;
    S.w = Math.max(10, r.width); S.h = Math.max(10, r.height);
    S.canvas.width = Math.floor(S.w * S.dpr); S.canvas.height = Math.floor(S.h * S.dpr);
    S.canvas.style.width = S.w + 'px'; S.canvas.style.height = S.h + 'px';
    S.ctx.setTransform(S.dpr, 0, 0, S.dpr, 0, 0);
  }

  /* ─── WebSocket ─── */
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
  function onVis() {
    S.running = !document.hidden;
    if (S.running && !S.raf) S.raf = requestAnimationFrame(render);
    if (!S.running && S.raf) { cancelAnimationFrame(S.raf); S.raf = 0; }
  }
  window.initBrainCanvas = function(id) {
    window.destroyBrainCanvas();
    S.container = document.getElementById(id || 'brain-canvas-container');
    if (!S.container) return;
    S.canvas = document.createElement('canvas');
    S.canvas.style.cssText = 'display:block;width:100%;height:100%;border-radius:8px;';
    S.container.appendChild(S.canvas);
    S.ctx = S.canvas.getContext('2d', { alpha: true }); resize();
    S.ro = new ResizeObserver(resize); S.ro.observe(S.container);
    S.canvas.addEventListener('mousemove', onMouseMove);
    S.canvas.addEventListener('mouseleave', onMouseLeave);
    S.canvas.addEventListener('click', onClick);
    document.addEventListener('visibilitychange', onVis);
    pollData(); S.pollT = setInterval(pollData, 8000);
    connectWs();
    S.running = true; S.raf = requestAnimationFrame(render);
  };
  window.destroyBrainCanvas = function() {
    if (S.raf) cancelAnimationFrame(S.raf); S.raf = 0;
    if (S.ro) S.ro.disconnect(); S.ro = null;
    if (S.ws) S.ws.close(); S.ws = null; clearTimeout(S.wsT); S.wsT = 0;
    if (S.pollT) clearInterval(S.pollT); S.pollT = 0;
    if (S.canvas) { S.canvas.removeEventListener('mousemove', onMouseMove); S.canvas.removeEventListener('mouseleave', onMouseLeave); S.canvas.removeEventListener('click', onClick); }
    document.removeEventListener('visibilitychange', onVis);
    if (S.container) S.container.innerHTML = '';
    S.container = S.canvas = S.ctx = null;
    S.neurons.clear(); S.synapses = []; S.sessions = []; S.agents = [];
  };
  window.updateBrainData = function() { pollData(); };
  window.toggleBrainFreeze = function() {
    S.running = !S.running;
    const btn = document.getElementById('brain-pause-btn');
    if (btn) btn.textContent = S.running ? '❚❚' : '▶';
    if (S.running) { S.raf = requestAnimationFrame(render); }
  };
  window.rewindBrain = function() { S.neurons.clear(); S.synapses = []; pollData(); };

  const _boot = () => window.initBrainCanvas('brain-canvas-container');
  if (document.readyState === 'loading') document.addEventListener('DOMContentLoaded', _boot);
  else setTimeout(_boot, 100);
})();