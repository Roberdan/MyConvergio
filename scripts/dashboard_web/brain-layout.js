/* brain-layout.js — Force-directed graph layout engine */
'use strict';
class BrainLayout {
  constructor(w, h) {
    this.width = w;
    this.height = h;
    this.nodes = [];
    this.nodeMap = new Map();
    this.damping = 0.85;
    this.stable = false;
    this._steps = 0;
  }
  setNodes(nodes) {
    const prev = this.nodeMap,
      cx = this.width / 2,
      cy = this.height / 2;
    const out = nodes.map((n) => {
      const old = prev.get(n.id);
      if (old) return { ...n, x: old.x, y: old.y, vx: old.vx, vy: old.vy, pinned: old.pinned };
      const par = prev.get(n.parentId);
      const bx = par ? par.x : cx,
        by = par ? par.y : cy;
      return {
        ...n,
        x: bx + (Math.random() - 0.5) * 160,
        y: by + (Math.random() - 0.5) * 160,
        vx: 0,
        vy: 0,
        pinned: false,
      };
    });
    this.nodes = out;
    this.nodeMap = new Map(out.map((n) => [n.id, n]));
    this.stable = false;
    this._steps = 0;
  }
  step() {
    const N = this.nodes,
      len = N.length;
    if (!len || this.stable) return;
    this._steps++;
    const fx = new Float64Array(len),
      fy = new Float64Array(len);
    // Repulsion (all pairs) — strong to spread nodes apart
    for (let i = 0; i < len; i++)
      for (let j = i + 1; j < len; j++) {
        const a = N[i],
          b = N[j];
        let dx = b.x - a.x,
          dy = b.y - a.y;
        const d2 = dx * dx + dy * dy + 1,
          d = Math.sqrt(d2);
        const bothPlan = a.type === 'plan' && b.type === 'plan';
        const k = bothPlan ? 8000 : 2000;
        const f = k / d2;
        dx /= d;
        dy /= d;
        fx[i] -= f * dx;
        fy[i] -= f * dy;
        fx[j] += f * dx;
        fy[j] += f * dy;
      }
    // Attraction (child -> parent)
    for (let i = 0; i < len; i++) {
      const n = N[i];
      if (n.type !== 'agent' || !n.parentId) continue;
      const p = this.nodeMap.get(n.parentId);
      if (!p) continue;
      const j = N.indexOf(p);
      if (j < 0) continue;
      const dx = p.x - n.x,
        dy = p.y - n.y;
      const d = Math.hypot(dx, dy) || 1;
      const rest = 90,
        f = 0.05 * (d - rest);
      const ux = dx / d,
        uy = dy / d;
      fx[i] += f * ux;
      fy[i] += f * uy;
      fx[j] -= f * ux * 0.12;
      fy[j] -= f * uy * 0.12;
    }
    // Gravity toward center
    const cx = this.width / 2,
      cy = this.height / 2;
    for (let i = 0; i < len; i++) {
      fx[i] += (cx - N[i].x) * 0.006;
      fy[i] += (cy - N[i].y) * 0.006;
    }
    // Integrate
    let maxV = 0;
    const pad = 40;
    for (let i = 0; i < len; i++) {
      const n = N[i];
      if (n.pinned) {
        n.vx = 0;
        n.vy = 0;
        continue;
      }
      const mass = n.type === 'plan' ? 5 : 1;
      n.vx = (n.vx + fx[i] / mass) * this.damping;
      n.vy = (n.vy + fy[i] / mass) * this.damping;
      n.x = Math.max(pad, Math.min(this.width - pad, n.x + n.vx));
      n.y = Math.max(pad, Math.min(this.height - pad, n.y + n.vy));
      maxV = Math.max(maxV, Math.abs(n.vx), Math.abs(n.vy));
    }
    if (this._steps > 80 && maxV < 0.25) this.stable = true;
  }
  pin(id) {
    const n = this.nodeMap.get(id);
    if (n) n.pinned = true;
  }
  unpin(id) {
    const n = this.nodeMap.get(id);
    if (n) n.pinned = false;
  }
  moveTo(id, x, y) {
    const n = this.nodeMap.get(id);
    if (n) {
      n.x = x;
      n.y = y;
      n.vx = 0;
      n.vy = 0;
    }
  }
  settle() {
    for (let i = 0; i < 120 && !this.stable; i++) this.step();
  }
  kick() {
    this.stable = false;
    this._steps = Math.max(this._steps, 50);
  }
}
window.BrainLayout = BrainLayout;
