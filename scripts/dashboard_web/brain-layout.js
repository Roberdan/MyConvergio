class BrainLayout {
  constructor(width, height) {
    this.width = width; this.height = height;
    this.repulsionK = 500; this.springK = 0.05; this.restLength = 100;
    this.centerK = 0.01; this.damping = 0.92;
    this.nodes = []; this.nodeMap = new Map(); this.synapses = [];
  }

  setNodes(nodes) {
    const prev = this.nodeMap;
    const incoming = nodes.map(n => ({ ...n }));
    const byId = new Map(incoming.map(n => [n.id, n]));
    const cx = this.width * 0.5, cy = this.height * 0.5;
    const massByType = { plan: 3, task: 1, peer: 2 };

    for (const n of incoming) {
      const old = prev.get(n.id);
      n.mass = n.mass || massByType[n.type] || 1;
      if (old) {
        n.x = old.x; n.y = old.y; n.vx = old.vx; n.vy = old.vy;
        continue;
      }
      if (typeof n.x !== 'number' || typeof n.y !== 'number') {
        const p = prev.get(n.parentId) || byId.get(n.parentId);
        if (p && typeof p.x === 'number' && typeof p.y === 'number') {
          n.x = p.x + (Math.random() - 0.5) * 40;
          n.y = p.y + (Math.random() - 0.5) * 40;
        } else {
          n.x = cx + (Math.random() - 0.5) * 80;
          n.y = cy + (Math.random() - 0.5) * 80;
        }
      }
      n.vx = n.vx || 0; n.vy = n.vy || 0;
    }

    this.nodes = incoming;
    this.nodeMap = new Map(incoming.map(n => [n.id, n]));
    this.synapses = this.synapses.filter(s => this.nodeMap.has(s.source) && this.nodeMap.has(s.target));
  }

  setSynapses(synapses) {
    this.synapses = synapses.filter(s => this.nodeMap.has(s.source) && this.nodeMap.has(s.target));
  }

  step() {
    const n = this.nodes.length;
    if (!n) return;
    const fx = new Array(n).fill(0), fy = new Array(n).fill(0);
    const cx = this.width * 0.5, cy = this.height * 0.5;
    const ringR = 0.4 * Math.min(this.width, this.height);

    for (let i = 0; i < n; i++) {
      for (let j = i + 1; j < n; j++) {
        const a = this.nodes[i], b = this.nodes[j];
        const dx = b.x - a.x, dy = b.y - a.y;
        const d2 = dx * dx + dy * dy + 0.01;
        const d = Math.sqrt(d2);
        const f = this.repulsionK / d2;
        const ux = dx / d, uy = dy / d;
        fx[i] -= f * ux; fy[i] -= f * uy;
        fx[j] += f * ux; fy[j] += f * uy;
      }
    }

    for (const s of this.synapses) {
      const a = this.nodeMap.get(s.source), b = this.nodeMap.get(s.target);
      if (!a || !b) continue;
      const i = this.nodes.indexOf(a), j = this.nodes.indexOf(b);
      const dx = b.x - a.x, dy = b.y - a.y;
      const d = Math.hypot(dx, dy) || 1;
      const ux = dx / d, uy = dy / d;
      const f = this.springK * (d - this.restLength);
      fx[i] += f * ux; fy[i] += f * uy;
      fx[j] -= f * ux; fy[j] -= f * uy;
    }

    for (let i = 0; i < n; i++) {
      const node = this.nodes[i];
      fx[i] += (cx - node.x) * this.centerK;
      fy[i] += (cy - node.y) * this.centerK;
      node.vx = (node.vx + fx[i] / node.mass) * this.damping;
      node.vy = (node.vy + fy[i] / node.mass) * this.damping;
      node.x += node.vx; node.y += node.vy;

      if (node.type === 'peer') {
        let ang = Math.atan2(node.y - cy, node.x - cx);
        if (!Number.isFinite(ang)) ang = Math.random() * Math.PI * 2;
        node.x = cx + Math.cos(ang) * ringR;
        node.y = cy + Math.sin(ang) * ringR;
        node.vx *= 0.5; node.vy *= 0.5;
      }
    }
  }

  getPositions() {
    const out = {};
    for (const n of this.nodes) out[n.id] = { x: n.x, y: n.y };
    return out;
  }
}

class ParticleSystem {
  constructor(maxParticles = 200) {
    this.maxParticles = maxParticles;
    this.active = []; this.pool = [];
  }

  spawn(synapse, color = '#7cf', speed = 0.02) {
    if (this.active.length >= this.maxParticles) return;
    const s = this._pt(synapse.source || synapse.s || { x: synapse.x1, y: synapse.y1 });
    const t = this._pt(synapse.target || synapse.t || { x: synapse.x2, y: synapse.y2 });
    if (!s || !t) return;
    const p = this.pool.pop() || {};
    const dx = t.x - s.x, dy = t.y - s.y, len = Math.hypot(dx, dy) || 1;
    const nx = -dy / len, ny = dx / len;
    const curve = Math.min(40, len * 0.25) * (0.7 + Math.random() * 0.6);
    p.x1 = s.x; p.y1 = s.y; p.x2 = t.x; p.y2 = t.y;
    p.cx = (s.x + t.x) * 0.5 + nx * curve; p.cy = (s.y + t.y) * 0.5 + ny * curve;
    p.t = 0; p.speed = speed; p.size = 1 + Math.random() * 1.8;
    p.color = color; p.opacity = 1; p.lifetime = 1; p.trail = p.trail || []; p.trail.length = 0;
    this.active.push(p);
  }

  update() {
    for (let i = this.active.length - 1; i >= 0; i--) {
      const p = this.active[i];
      p.t += p.speed;
      if (p.t >= p.lifetime) {
        this.pool.push(this.active.splice(i, 1)[0]);
        continue;
      }
      const t = p.t / p.lifetime, u = 1 - t;
      p.x = u * u * p.x1 + 2 * u * t * p.cx + t * t * p.x2;
      p.y = u * u * p.y1 + 2 * u * t * p.cy + t * t * p.y2;
      p.trail.push({ x: p.x, y: p.y });
      if (p.trail.length > 3) p.trail.shift();
      p.opacity = t > 0.8 ? (1 - t) / 0.2 : 1;
    }
  }

  render(ctx) {
    const trailAlpha = [0.2, 0.5, 1.0];
    ctx.save();
    for (const p of this.active) {
      for (let i = 0; i < p.trail.length; i++) {
        const tr = p.trail[i];
        ctx.globalAlpha = p.opacity * trailAlpha[Math.max(0, 3 - p.trail.length + i)];
        ctx.fillStyle = p.color;
        ctx.beginPath(); ctx.arc(tr.x, tr.y, p.size * (0.5 + i * 0.25), 0, Math.PI * 2); ctx.fill();
      }
      ctx.globalAlpha = p.opacity;
      ctx.fillStyle = p.color;
      ctx.beginPath(); ctx.arc(p.x, p.y, p.size, 0, Math.PI * 2); ctx.fill();
    }
    ctx.restore();
  }

  _pt(v) {
    if (!v || typeof v.x !== 'number' || typeof v.y !== 'number') return null;
    return { x: v.x, y: v.y };
  }
}

class GlowSystem {
  constructor() { this.pulses = new Map(); this.baseRadius = 12; }

  setPulse(nodeId, frequency, amplitude) {
    this.pulses.set(nodeId, { frequency: frequency || 1, amplitude: amplitude || 0 });
  }

  getGlow(nodeId, time) {
    const p = this.pulses.get(nodeId) || { frequency: 1, amplitude: 0 };
    const wave = Math.sin(time * p.frequency * Math.PI * 2);
    const radius = this.baseRadius + p.amplitude * wave;
    const opacity = 0.2 + Math.abs(wave) * 0.4;
    return { radius, opacity };
  }

  renderEdgeGlow(ctx, width, height, intensity) {
    const a = Math.max(0, intensity) * 0.1;
    if (!a) return;
    ctx.save();
    const gTop = ctx.createLinearGradient(0, 0, 0, height * 0.35);
    gTop.addColorStop(0, `rgba(120,180,255,${a})`); gTop.addColorStop(1, 'rgba(120,180,255,0)');
    const gBot = ctx.createLinearGradient(0, height, 0, height * 0.65);
    gBot.addColorStop(0, `rgba(120,180,255,${a})`); gBot.addColorStop(1, 'rgba(120,180,255,0)');
    const gLeft = ctx.createLinearGradient(0, 0, width * 0.35, 0);
    gLeft.addColorStop(0, `rgba(120,180,255,${a})`); gLeft.addColorStop(1, 'rgba(120,180,255,0)');
    const gRight = ctx.createLinearGradient(width, 0, width * 0.65, 0);
    gRight.addColorStop(0, `rgba(120,180,255,${a})`); gRight.addColorStop(1, 'rgba(120,180,255,0)');
    ctx.fillStyle = gTop; ctx.fillRect(0, 0, width, height * 0.35);
    ctx.fillStyle = gBot; ctx.fillRect(0, height * 0.65, width, height * 0.35);
    ctx.fillStyle = gLeft; ctx.fillRect(0, 0, width * 0.35, height);
    ctx.fillStyle = gRight; ctx.fillRect(width * 0.65, 0, width * 0.35, height);
    ctx.restore();
  }
}

window.BrainLayout = BrainLayout;
window.ParticleSystem = ParticleSystem;
window.GlowSystem = GlowSystem;
