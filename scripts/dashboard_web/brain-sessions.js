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

  function hsl(h, s, l, a) { return `hsla(${h},${s}%,${l}%,${a})`; }

  function sessionLabel(sid) {
    const tool = toolFromId(sid);
    const parts = sid.split('-');
    const tty = parts.find(p => /^s\d{3}$/.test(p));
    const pid = parts[parts.length - 1];
    const name = tool === 'claude' ? 'Claude' : 'Copilot';
    return tty ? `${name} ${tty}` : `${name} ${pid}`;
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
          scale: 0, alpha: 0, phase: Math.random() * PI2,
          state: 'appearing', t: 0,
        });
      }
      return this.anims.get(id);
    }

    tickAnims(dt) {
      for (const [, a] of this.anims) {
        a.t += dt; a.phase += dt * 0.003;
        if (a.state === 'appearing') {
          a.scale = Math.min(1, a.t / 350); a.alpha = a.scale;
          if (a.scale >= 1) { a.state = 'active'; a.t = 0; }
        } else if (a.state === 'active') {
          a.scale = 1 + 0.06 * Math.sin(a.phase); a.alpha = 1;
        } else if (a.state === 'cooling') {
          a.scale = 0.7 + 0.02 * Math.sin(a.phase * 0.4);
          a.alpha = Math.max(0.15, a.alpha - dt * 0.0003);
        } else if (a.state === 'completing') {
          a.scale = Math.max(0, 1 - a.t / 600); a.alpha = a.scale;
        }
        if (a.state === 'completing' && a.scale <= 0) this.anims.delete(a);
      }
    }

    detectChanges() {
      const events = [];
      for (const sess of this.sessions) {
        const sid = sess.session_id;
        const activeCount = (sess.children || []).filter(c => c.status === 'running').length;
        const prev = this._prevChildCounts.get(sid) || 0;
        if (activeCount > prev) events.push({ type: 'child_spawn', session: sid });
        else if (activeCount < prev) events.push({ type: 'child_complete', session: sid });
        this._prevChildCounts.set(sid, activeCount);
        for (const ch of sess.children || []) {
          const ca = this._an(ch.agent_id);
          if (ch.status === 'running' && ca.state !== 'appearing') ca.state = 'active';
          else if (ch.status !== 'running' && ca.state === 'active') {
            ca.state = 'cooling'; ca.t = 0;
          }
        }
        this._an(sid).state = 'active';
      }
      return events;
    }

    render(ctx, positions, w, h) {
      if (!this.sessions.length && !this.orphans.length) return;
      const count = this.sessions.length;
      const spacing = Math.min(180, (w - 80) / Math.max(1, count));
      const startX = (w - spacing * (count - 1)) / 2;
      const baseY = h - 90;

      this.sessions.forEach((sess, si) => {
        const x = positions[sess.session_id]?.x ?? (startX + si * spacing);
        const y = positions[sess.session_id]?.y ?? baseY;
        this._renderCluster(ctx, sess, x, y);
      });
      this._renderOrphans(ctx, w, baseY - 70);
    }

    _renderCluster(ctx, sess, x, y) {
      const tool = toolFromId(sess.session_id);
      const col = SESSION_COL[tool] || SESSION_COL.claude;
      const children = sess.children || [];
      const activeCount = children.filter(c => c.status === 'running').length;
      const total = children.length;
      const sa = this._an(sess.session_id);

      const pR = (15 + Math.min(activeCount * 3, 15)) * sa.scale;
      const intensity = 0.3 + activeCount * 0.15;

      ctx.save();
      ctx.globalAlpha = sa.alpha;

      // Glow
      ctx.shadowBlur = activeCount > 0 ? 20 : 8;
      ctx.shadowColor = hsl(col.h, 80, 55, intensity);

      // Parent circle
      const g = ctx.createRadialGradient(x - 2, y - 2, 3, x, y, pR);
      g.addColorStop(0, hsl(col.h, 85, 65, 0.9));
      g.addColorStop(1, hsl(col.h, 70, 45, 0.3));
      ctx.fillStyle = g;
      ctx.beginPath(); ctx.arc(x, y, pR, 0, PI2); ctx.fill();

      // Outer ring (activity indicator)
      ctx.shadowBlur = 0;
      const ringR = pR + 5 + (activeCount > 0 ? 2 * Math.sin(sa.phase * 2) : 0);
      ctx.strokeStyle = hsl(col.h, 70, 55, 0.3 + intensity * 0.3);
      ctx.lineWidth = 1.2;
      ctx.beginPath(); ctx.arc(x, y, ringR, 0, PI2); ctx.stroke();

      // Children orbit
      const orbitR = pR + 25 + total * 2;
      children.forEach((child, i) => {
        const angle = (total > 0 ? i / total : 0) * PI2 - Math.PI / 2;
        const cx = x + Math.cos(angle) * orbitR;
        const cy = y + Math.sin(angle) * orbitR;
        this._renderChild(ctx, child, cx, cy, x, y, col);
      });

      // Label
      ctx.shadowBlur = 0;
      const lbl = sessionLabel(sess.session_id);
      ctx.font = '10px "JetBrains Mono",monospace';
      ctx.textAlign = 'center';
      const tw = ctx.measureText(lbl).width;
      ctx.fillStyle = 'rgba(10,16,36,0.65)';
      if (ctx.roundRect) {
        ctx.beginPath();
        ctx.roundRect(x - tw / 2 - 4, y + pR + 10, tw + 8, 14, 3);
        ctx.fill();
      }
      ctx.fillStyle = hsl(col.h, 60, 75, 0.9);
      ctx.fillText(lbl, x, y + pR + 21);
      ctx.restore();
    }

    _renderChild(ctx, child, cx, cy, px, py, col) {
      const ca = this._an(child.agent_id);
      const isActive = child.status === 'running';
      const r = (isActive ? 6 : 4) * ca.scale;

      // Connection to parent
      ctx.strokeStyle = hsl(col.h, 50, 55, isActive ? 0.3 : 0.1);
      ctx.lineWidth = isActive ? 1 : 0.5;
      ctx.beginPath(); ctx.moveTo(px, py); ctx.lineTo(cx, cy); ctx.stroke();

      // Child neuron
      ctx.save();
      ctx.globalAlpha = ca.alpha;
      ctx.shadowBlur = isActive ? 8 : 2;
      ctx.shadowColor = isActive ? hsl(col.h, 90, 60, 0.8) : hsl(col.h, 40, 40, 0.3);
      ctx.fillStyle = isActive
        ? hsl(col.h, 85, 60, 0.85)
        : hsl(col.h, 30, 45, 0.35);
      ctx.beginPath(); ctx.arc(cx, cy, r, 0, PI2); ctx.fill();

      // Status indicator
      ctx.shadowBlur = 0;
      ctx.fillStyle = isActive ? '#fff' : hsl(col.h, 20, 65, 0.5);
      ctx.font = `bold ${Math.max(6, 8 * ca.scale)}px "JetBrains Mono",monospace`;
      ctx.textAlign = 'center'; ctx.textBaseline = 'middle';
      ctx.fillText(isActive ? '\u25C6' : '\u25CF', cx, cy + 0.5);
      ctx.restore();
    }

    _renderOrphans(ctx, w, y) {
      if (!this.orphans.length) return;
      const spacing = Math.min(60, (w - 40) / this.orphans.length);
      const startX = (w - spacing * (this.orphans.length - 1)) / 2;
      ctx.save(); ctx.globalAlpha = 0.4;
      this.orphans.forEach((o, i) => {
        const ox = startX + i * spacing;
        ctx.fillStyle = '#888'; ctx.beginPath();
        ctx.arc(ox, y, 3, 0, PI2); ctx.fill();
      });
      ctx.restore();
    }

    getSessionPositions(w, h) {
      const pos = {};
      const count = this.sessions.length;
      if (!count) return pos;
      const spacing = Math.min(180, (w - 80) / Math.max(1, count));
      const startX = (w - spacing * (count - 1)) / 2;
      const baseY = h - 90;
      this.sessions.forEach((s, i) => {
        pos[s.session_id] = { x: startX + i * spacing, y: baseY };
      });
      return pos;
    }
  }

  window.SessionClusterRenderer = SessionClusterRenderer;
  window._sessionClusters = new SessionClusterRenderer();
})();
