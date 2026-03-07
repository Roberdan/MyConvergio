/* brain-layout.js — Clustering force-directed layout for global agent activity */
'use strict';

class BrainLayout {
  constructor(width, height) {
    this.width = width; this.height = height;
    this.nodes = []; this.nodeMap = new Map();
    this.damping = 0.86;
  }

  setNodes(nodes) {
    const prev = this.nodeMap;
    const cx = this.width * 0.5, cy = this.height * 0.5;
    const incoming = nodes.map(n => ({ ...n }));

    for (const n of incoming) {
      const old = prev.get(n.id);
      if (old) { n.x = old.x; n.y = old.y; n.vx = old.vx; n.vy = old.vy; continue; }
      const parent = prev.get(n.parentId) || incoming.find(o => o.id === n.parentId);
      if (parent && typeof parent.x === 'number') {
        n.x = parent.x + (Math.random() - 0.5) * 50;
        n.y = parent.y + (Math.random() - 0.5) * 50;
      } else {
        n.x = cx + (Math.random() - 0.5) * 120;
        n.y = cy + (Math.random() - 0.5) * 120;
      }
      n.vx = 0; n.vy = 0;
      n.mass = n.type === 'plan' ? 5 : 1;
    }

    this.nodes = incoming;
    this.nodeMap = new Map(incoming.map(n => [n.id, n]));
  }

  step() {
    const N = this.nodes.length;
    if (!N) return;
    const cx = this.width * 0.5, cy = this.height * 0.5;
    const fx = new Float64Array(N), fy = new Float64Array(N);

    // Repulsion between all nodes
    for (let i = 0; i < N; i++) {
      for (let j = i + 1; j < N; j++) {
        const a = this.nodes[i], b = this.nodes[j];
        const dx = b.x - a.x, dy = b.y - a.y;
        const d2 = dx * dx + dy * dy + 1;
        const d = Math.sqrt(d2);
        // Stronger repulsion between plans
        const k = (a.type === 'plan' && b.type === 'plan') ? 1200 : 500;
        const f = k / d2;
        const ux = dx / d, uy = dy / d;
        fx[i] -= f * ux; fy[i] -= f * uy;
        fx[j] += f * ux; fy[j] += f * uy;
      }
    }

    // Attraction: agents toward their parent plan
    for (let i = 0; i < N; i++) {
      const n = this.nodes[i];
      if (n.type !== 'agent' || !n.parentId) continue;
      const parent = this.nodeMap.get(n.parentId);
      if (!parent) continue;
      const j = this.nodes.indexOf(parent);
      if (j < 0) continue;
      const dx = parent.x - n.x, dy = parent.y - n.y;
      const d = Math.hypot(dx, dy) || 1;
      const rest = 65;
      const f = 0.07 * (d - rest);
      const ux = dx / d, uy = dy / d;
      fx[i] += f * ux; fy[i] += f * uy;
      fx[j] -= f * ux * 0.2; fy[j] -= f * uy * 0.2;
    }

    // Gravity toward center
    for (let i = 0; i < N; i++) {
      fx[i] += (cx - this.nodes[i].x) * 0.01;
      fy[i] += (cy - this.nodes[i].y) * 0.01;
    }

    // Integrate with boundary clamping
    const pad = 35;
    for (let i = 0; i < N; i++) {
      const n = this.nodes[i];
      n.vx = (n.vx + fx[i] / (n.mass || 1)) * this.damping;
      n.vy = (n.vy + fy[i] / (n.mass || 1)) * this.damping;
      n.x = Math.max(pad, Math.min(this.width - pad, n.x + n.vx));
      n.y = Math.max(pad, Math.min(this.height - pad, n.y + n.vy));
    }
  }

  getPositions() {
    const out = {};
    for (const n of this.nodes) out[n.id] = { x: n.x, y: n.y };
    return out;
  }
}

window.BrainLayout = BrainLayout;
