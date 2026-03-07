/* brain-sessions.js — Session cluster rendering for brain visualization.
   Each CLI session (Claude/Copilot) renders as a parent node with orbiting child neurons. */
(() => {
  'use strict';
  const PI2 = Math.PI * 2;
  const SESSION_COL = { claude: { h: 40, base: '#ffb020' }, copilot: { h: 210, base: '#20a0ff' } };

  function toolFromId(sid) {
    if (sid.includes('claude')) return 'claude';
    if (sid.includes('copilot')) return 'copilot';
    return 'claude';
  }

  function hsl(h, s, l, a) {
    return `hsla(${h},${s}%,${l}%,${a})`;
  }

  function sessionLabel(sid) {
    const tool = toolFromId(sid);
    const name = tool === 'claude' ? 'Claude' : 'Copilot';
    const parts = sid.split('-');
    const tty = parts.find((p) => /^s\d{3}$/.test(p));
    if (tty) return `${name} ${tty}`;
    // Short hash: first 4 hex chars found in the ID
    const hex = parts.find((p) => /^[0-9a-f]{4,}$/i.test(p));
    return hex ? `${name} #${hex.slice(0, 4)}` : name;
  }

  class SessionClusterRenderer {
    constructor() {
      this.sessions = [];
      this.orphans = [];
      this.anims = new Map();
      this._prevChildCounts = new Map();
    }

    update(sessions, orphans) {
      this.sessions = sessions || [];
      this.orphans = orphans || [];
    }

    _an(id) {
      if (!this.anims.has(id)) {
        this.anims.set(id, {
          scale: 0,
          alpha: 0,
          phase: Math.random() * PI2,
          state: 'appearing',
          t: 0,
        });
      }
      return this.anims.get(id);
    }

    tickAnims(dt) {
      for (const [, a] of this.anims) {
        a.t += dt;
        a.phase += dt * 0.003;
        if (a.state === 'appearing') {
          a.scale = Math.min(1, a.t / 350);
          a.alpha = a.scale;
          if (a.scale >= 1) {
            a.state = 'active';
            a.t = 0;
          }
        } else if (a.state === 'active') {
          a.scale = 1 + 0.06 * Math.sin(a.phase);
          a.alpha = 1;
        } else if (a.state === 'cooling') {
          a.scale = 0.7 + 0.02 * Math.sin(a.phase * 0.4);
          a.alpha = Math.max(0.15, a.alpha - dt * 0.0003);
        } else if (a.state === 'completing') {
          a.scale = Math.max(0, 1 - a.t / 600);
          a.alpha = a.scale;
        }
        if (a.state === 'completing' && a.scale <= 0) this.anims.delete(a);
      }
    }

    detectChanges() {
      const events = [];
      for (const sess of this.sessions) {
        const sid = sess.session_id;
        const activeCount = (sess.children || []).filter((c) => c.status === 'running').length;
        const prev = this._prevChildCounts.get(sid) || 0;
        if (activeCount > prev) events.push({ type: 'child_spawn', session: sid });
        else if (activeCount < prev) events.push({ type: 'child_complete', session: sid });
        this._prevChildCounts.set(sid, activeCount);
        for (const ch of sess.children || []) {
          const ca = this._an(ch.agent_id);
          if (ch.status === 'running' && ca.state !== 'appearing') ca.state = 'active';
          else if (ch.status !== 'running' && ca.state === 'active') {
            ca.state = 'cooling';
            ca.t = 0;
          }
        }
        this._an(sid).state = 'active';
      }
      return events;
    }

    render(ctx, positions, w, h) {
      if (!this.sessions.length && !this.orphans.length) return;
      this.sessions.forEach((sess) => {
        const x = positions[sess.session_id]?.x ?? w * 0.5;
        const y = positions[sess.session_id]?.y ?? h * 0.5;
        this._renderCluster(ctx, sess, x, y);
      });
      this._renderOrphans(ctx, w, h * 0.88);
    }

    _renderCluster(ctx, sess, x, y) {
      const tool = toolFromId(sess.session_id);
      const col = SESSION_COL[tool] || SESSION_COL.claude;
      const children = sess.children || [];
      const activeCount = children.filter((c) => c.status === 'running').length;
      const sa = this._an(sess.session_id);
      const gR = (14 + Math.min(activeCount * 3, 12)) * sa.scale;
      ctx.save();
      ctx.globalAlpha = sa.alpha;
      // Region glow
      ctx.shadowBlur = activeCount > 0 ? 24 : 10;
      ctx.shadowColor = hsl(col.h, 80, 55, 0.7);
      const g = ctx.createRadialGradient(x, y, 0, x, y, gR);
      g.addColorStop(0, hsl(col.h, 90, 70, 0.55));
      g.addColorStop(1, hsl(col.h, 70, 45, 0));
      ctx.fillStyle = g;
      ctx.beginPath();
      ctx.arc(x, y, gR, 0, PI2);
      ctx.fill();
      // Pulse ring
      ctx.shadowBlur = 0;
      const rR = gR + 4 + (activeCount > 0 ? 2 * Math.sin(sa.phase * 2) : 0);
      ctx.strokeStyle = hsl(col.h, 70, 60, 0.3);
      ctx.lineWidth = 1;
      ctx.beginPath();
      ctx.arc(x, y, rR, 0, PI2);
      ctx.stroke();
      // Children orbit within region
      const orbitR = rR + 10 + children.length * 2;
      children.forEach((ch, i) => {
        const a = (children.length > 0 ? i / children.length : 0) * PI2 - Math.PI / 2;
        this._renderChild(ctx, ch, x + Math.cos(a) * orbitR, y + Math.sin(a) * orbitR, x, y, col);
      });
      // Label with subtle connecting line
      const lbl = sessionLabel(sess.session_id);
      const lY = y + rR + 15;
      ctx.shadowBlur = 0;
      ctx.globalAlpha = sa.alpha * 0.85;
      ctx.strokeStyle = hsl(col.h, 50, 65, 0.3);
      ctx.lineWidth = 0.8;
      ctx.beginPath();
      ctx.moveTo(x, y + rR + 2);
      ctx.lineTo(x, lY - 3);
      ctx.stroke();
      ctx.font = '9px "JetBrains Mono",monospace';
      ctx.textAlign = 'center';
      const tw = ctx.measureText(lbl).width;
      ctx.fillStyle = 'rgba(10,16,36,0.6)';
      if (ctx.roundRect) {
        ctx.beginPath();
        ctx.roundRect(x - tw / 2 - 3, lY - 10, tw + 6, 12, 2);
        ctx.fill();
      }
      ctx.fillStyle = hsl(col.h, 60, 75, 0.9);
      ctx.fillText(lbl, x, lY);
      ctx.restore();
    }

    _renderChild(ctx, child, cx, cy, px, py, col) {
      const ca = this._an(child.agent_id);
      const isActive = child.status === 'running';
      const r = (isActive ? 6 : 4) * ca.scale;

      // Connection to parent
      ctx.strokeStyle = hsl(col.h, 50, 55, isActive ? 0.3 : 0.1);
      ctx.lineWidth = isActive ? 1 : 0.5;
      ctx.beginPath();
      ctx.moveTo(px, py);
      ctx.lineTo(cx, cy);
      ctx.stroke();

      // Child neuron
      ctx.save();
      ctx.globalAlpha = ca.alpha;
      ctx.shadowBlur = isActive ? 8 : 2;
      ctx.shadowColor = isActive ? hsl(col.h, 90, 60, 0.8) : hsl(col.h, 40, 40, 0.3);
      ctx.fillStyle = isActive ? hsl(col.h, 85, 60, 0.85) : hsl(col.h, 30, 45, 0.35);
      ctx.beginPath();
      ctx.arc(cx, cy, r, 0, PI2);
      ctx.fill();

      // Status indicator
      ctx.shadowBlur = 0;
      ctx.fillStyle = isActive ? '#fff' : hsl(col.h, 20, 65, 0.5);
      ctx.font = `bold ${Math.max(6, 8 * ca.scale)}px "JetBrains Mono",monospace`;
      ctx.textAlign = 'center';
      ctx.textBaseline = 'middle';
      ctx.fillText(isActive ? '\u25C6' : '\u25CF', cx, cy + 0.5);
      ctx.restore();
    }

    _renderOrphans(ctx, w, y) {
      if (!this.orphans.length) return;
      const spacing = Math.min(60, (w - 40) / this.orphans.length);
      const startX = (w - spacing * (this.orphans.length - 1)) / 2;
      ctx.save();
      ctx.globalAlpha = 0.4;
      this.orphans.forEach((o, i) => {
        const ox = startX + i * spacing;
        ctx.fillStyle = '#888';
        ctx.beginPath();
        ctx.arc(ox, y, 3, 0, PI2);
        ctx.fill();
      });
      ctx.restore();
    }

    getSessionPositions(w, h) {
      const pos = {};
      const byRegion = new Map();
      for (const sess of this.sessions) {
        const r = this._sessionRegion(sess);
        if (!byRegion.has(r)) byRegion.set(r, []);
        byRegion.get(r).push(sess.session_id);
      }
      const BR = window.BrainRegions;
      for (const [region, ids] of byRegion) {
        const def = BR?.[region];
        if (!def) continue;
        const cx = def.center.x * w,
          cy = def.center.y * h;
        const spread = (def.radius || 0.08) * Math.min(w, h) * 0.35;
        ids.forEach((sid, i) => {
          const a = ids.length > 1 ? (i / ids.length) * PI2 - Math.PI / 2 : 0;
          pos[sid] = { x: cx + Math.cos(a) * spread, y: cy + Math.sin(a) * spread };
        });
      }
      return pos;
    }

    _sessionRegion(sess) {
      const type = (sess.type || '').toLowerCase();
      const meta =
        typeof sess.metadata === 'string' ? JSON.parse(sess.metadata || '{}') : sess.metadata || {};
      const act = (meta.activity || meta.status || type).toLowerCase();
      if (/plan|strateg|design|architect/.test(act)) return 'prefrontal';
      if (/execut|run|deploy|build|task/.test(act)) return 'motor';
      if (/valid|test|thor|review|audit/.test(act)) return 'amygdala';
      if (/mesh|sync|coord|dispatch|network/.test(act)) return 'cerebellum';
      if (/memory|kb|learn|checkpoint|store/.test(act)) return 'hippocampus';
      return 'prefrontal';
    }
  }

  window.SessionClusterRenderer = SessionClusterRenderer;
  window._sessionClusters = new SessionClusterRenderer();
})();
