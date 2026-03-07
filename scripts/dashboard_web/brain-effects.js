/* brain-effects.js — Scientific visualization effects (fMRI/PET/EEG style) */
'use strict';

const HEATMAP_COLORS = [
  [0.0, 0, 0, 170], [0.25, 0, 204, 255], [0.5, 0, 255, 102],
  [0.75, 255, 204, 0], [0.9, 255, 51, 0], [1.0, 255, 255, 255],
];
const CONNECTOME = [
  ['prefrontal', 'motor', 0.9], ['prefrontal', 'hippocampus', 0.7],
  ['motor', 'cerebellum', 0.8], ['motor', 'amygdala', 0.6],
  ['amygdala', 'prefrontal', 0.5], ['hippocampus', 'parietalLeft', 0.6],
  ['hippocampus', 'parietalRight', 0.5], ['parietalLeft', 'prefrontal', 0.7],
  ['parietalRight', 'motor', 0.8], ['cerebellum', 'brainstem', 0.7],
  ['visualCortex', 'prefrontal', 0.4], ['visualCortex', 'parietalLeft', 0.5],
  ['corpusCallosum', 'parietalLeft', 0.6], ['corpusCallosum', 'parietalRight', 0.6],
  ['brainstem', 'amygdala', 0.4],
];

let _particles = [], _eegBuf = {}, _eegIdx = 0;
const _eegLen = 200, _startTime = Date.now();

function heatRGBA(t, a) {
  t = Math.max(0, Math.min(1, t));
  for (let i = 1; i < HEATMAP_COLORS.length; i++) {
    if (t <= HEATMAP_COLORS[i][0]) {
      const p = HEATMAP_COLORS[i - 1], n = HEATMAP_COLORS[i];
      const f = (t - p[0]) / (n[0] - p[0]);
      const r = p[1] + (n[1] - p[1]) * f | 0;
      const g = p[2] + (n[2] - p[2]) * f | 0;
      const b = p[3] + (n[3] - p[3]) * f | 0;
      return a !== undefined ? `rgba(${r},${g},${b},${a})` : `rgb(${r},${g},${b})`;
    }
  }
  return a !== undefined ? `rgba(255,255,255,${a})` : 'rgb(255,255,255)';
}

function drawHeatmap(ctx, regions, w, h) {
  if (!regions || !regions.length) return;
  ctx.save(); ctx.globalCompositeOperation = 'screen';
  regions.forEach(r => {
    if ((r.activity || 0) < 0.02) return;
    const act = r.activity, rad = (r.radius || 30) * 1.8;
    const g = ctx.createRadialGradient(r.x, r.y, 0, r.x, r.y, rad);
    g.addColorStop(0, heatRGBA(act, act * 0.55));
    g.addColorStop(0.5, heatRGBA(act * 0.6, act * 0.2));
    g.addColorStop(1, 'rgba(0,0,0,0)');
    ctx.fillStyle = g; ctx.fillRect(r.x - rad, r.y - rad, rad * 2, rad * 2);
  });
  ctx.restore();
}

function drawConnectome(ctx, connections, regions, w, h) {
  if (!connections || !regions) return;
  const rMap = {}; regions.forEach(r => { rMap[r.key] = r; });
  const now = performance.now() / 1000;
  ctx.save();
  connections.forEach(([src, tgt, wt]) => {
    const a = rMap[src], b = rMap[tgt]; if (!a || !b) return;
    const act = Math.max(a.activity || 0, b.activity || 0), on = act > 0.15;
    const dx = b.x - a.x, dy = b.y - a.y, dist = Math.sqrt(dx * dx + dy * dy) || 1;
    const off = dist * 0.22 * wt;
    const cx = (a.x + b.x) / 2 - (dy / dist) * off;
    const cy = (a.y + b.y) / 2 + (dx / dist) * off;
    ctx.beginPath(); ctx.moveTo(a.x, a.y); ctx.quadraticCurveTo(cx, cy, b.x, b.y);
    ctx.strokeStyle = on ? heatRGBA(act, 0.15 + act * 0.55) : 'rgba(80,120,180,0.08)';
    ctx.lineWidth = on ? 0.8 + act * 2.5 : 0.3; ctx.stroke();
    if (on && act > 0.25) {
      for (let i = 0, np = Math.ceil(act * 3); i < np; i++) {
        const t = ((now * (0.25 + wt * 0.35) + i / np) % 1), u = 1 - t;
        const px = u * u * a.x + 2 * u * t * cx + t * t * b.x;
        const py = u * u * a.y + 2 * u * t * cy + t * t * b.y;
        ctx.beginPath(); ctx.arc(px, py, 1.2 + act, 0, Math.PI * 2);
        ctx.fillStyle = heatRGBA(Math.min(1, act + 0.2), 0.6 + act * 0.3); ctx.fill();
      }
    }
  });
  ctx.restore();
}

function initEEGBuffers() {
  _eegBuf = {}; _eegIdx = 0;
  Object.keys(window.BrainRegions || {}).forEach(k => { _eegBuf[k] = new Float32Array(_eegLen); });
  return _eegBuf;
}

function drawEEGTrace(ctx, regionActivity, time, w, h) {
  if (!regionActivity) return;
  const keys = Object.keys(regionActivity); if (!keys.length) return;
  if (!Object.keys(_eegBuf).length) initEEGBuffers();
  const baseY = h - 20;
  _eegIdx = (_eegIdx + 1) % _eegLen;
  keys.forEach(k => {
    if (!_eegBuf[k]) _eegBuf[k] = new Float32Array(_eegLen);
    const act = regionActivity[k]?.activity || 0;
    _eegBuf[k][_eegIdx] = Math.sin(time * (0.5 + act * 3.5) * Math.PI * 2 + k.length * 1.7)
      * (2 + act * 13) + (act > 0.6 ? (Math.random() - 0.5) * 8 : 0);
  });
  ctx.save();
  ctx.strokeStyle = 'rgba(100,140,200,0.05)'; ctx.lineWidth = 0.5;
  for (const g of [5, 10, 15]) {
    ctx.beginPath(); ctx.moveTo(0, baseY - g); ctx.lineTo(w, baseY - g); ctx.stroke();
    ctx.beginPath(); ctx.moveTo(0, baseY + g); ctx.lineTo(w, baseY + g); ctx.stroke();
  }
  ctx.beginPath(); ctx.strokeStyle = 'rgba(255,255,255,0.1)'; ctx.lineWidth = 1;
  for (let x = 0; x < w; x++) {
    const bi = (_eegIdx - (w - 1 - x) + _eegLen * 100) % _eegLen;
    let sum = 0; keys.forEach(k => { sum += (_eegBuf[k]?.[bi] || 0); });
    const py = baseY - sum / keys.length;
    x === 0 ? ctx.moveTo(x, py) : ctx.lineTo(x, py);
  }
  ctx.stroke();
  const BR = window.BrainRegions || {};
  keys.forEach((k, ki) => {
    const def = BR[k]; if (!def) return;
    const { h: hu, s, l } = def.color;
    ctx.beginPath(); ctx.strokeStyle = `hsla(${hu},${s}%,${l}%,0.35)`; ctx.lineWidth = 1;
    for (let x = 0; x < w; x++) {
      const bi = (_eegIdx - (w - 1 - x) + _eegLen * 100) % _eegLen;
      const py = baseY - (_eegBuf[k]?.[bi] || 0);
      x === 0 ? ctx.moveTo(x, py) : ctx.lineTo(x, py);
    }
    ctx.stroke();
    ctx.fillStyle = `hsla(${hu},${s}%,${l}%,0.5)`;
    ctx.beginPath(); ctx.arc(4, baseY - 16 + ki * 4, 1.5, 0, Math.PI * 2); ctx.fill();
  });
  ctx.restore();
}

function initParticles(n) {
  _particles = [];
  for (let i = 0; i < (n || 60); i++) _particles.push({
    x: 0.2 + Math.random() * 0.6, y: 0.1 + Math.random() * 0.8,
    vx: (Math.random() - 0.5) * 0.0004, vy: (Math.random() - 0.5) * 0.0004,
    a: 0.08 + Math.random() * 0.12,
  });
  return _particles;
}

function drawParticleField(ctx, brainOutline, breath, w, h) {
  if (!_particles.length) initParticles();
  ctx.save();
  _particles.forEach(p => {
    p.x += p.vx + Math.sin((breath || 0) * 0.5) * 0.00004;
    p.y += p.vy + Math.cos((breath || 0) * 0.3) * 0.00003;
    const dx = p.x - 0.5, dy = p.y - 0.5;
    if (dx * dx / 0.18 + dy * dy / 0.22 > 1) { p.vx *= -1; p.vy *= -1; p.x += p.vx * 3; p.y += p.vy * 3; }
    ctx.fillStyle = `rgba(180,210,255,${p.a})`; ctx.fillRect(p.x * w, p.y * h, 1, 1);
  });
  ctx.restore();
}

function drawRegionLabels(ctx, regions, regionActivity, w, h) {
  if (!regions || !regions.length) return;
  const cx = w / 2;
  ctx.save(); ctx.font = '9px "JetBrains Mono", monospace';
  regions.forEach(r => {
    const act = r.activity || 0;
    const alpha = act > 0.1 ? 0.35 + act * 0.55 : 0.18;
    const side = r.x < cx ? -1 : 1;
    const lx = r.x + side * ((r.radius || 20) + 22), ly = r.y;
    ctx.beginPath(); ctx.moveTo(r.x + side * (r.radius || 20) * 0.5, r.y); ctx.lineTo(lx, ly);
    ctx.strokeStyle = `rgba(150,180,220,${alpha * 0.4})`; ctx.lineWidth = 0.5; ctx.stroke();
    const text = act > 0.1 ? `${r.shortName || r.key} ${act * 100 | 0}%` : (r.shortName || r.key || '');
    const tw = ctx.measureText(text).width, pw = tw + 8, ph = 14;
    const px = side > 0 ? lx + 2 : lx - tw - 8;
    ctx.fillStyle = `rgba(10,16,36,${alpha * 0.5})`;
    ctx.beginPath(); ctx.roundRect(px, ly - ph / 2, pw, ph, 3); ctx.fill();
    ctx.fillStyle = `rgba(200,220,255,${alpha})`;
    ctx.textAlign = 'left'; ctx.textBaseline = 'middle'; ctx.fillText(text, px + 4, ly);
  });
  ctx.restore();
}

function drawColorScale(ctx, w, h) {
  ctx.save();
  const sx = w - 18, sy = h - 82, sw = 8, sh = 60;
  const g = ctx.createLinearGradient(sx, sy + sh, sx, sy);
  HEATMAP_COLORS.forEach(c => g.addColorStop(c[0], `rgb(${c[1]},${c[2]},${c[3]})`));
  ctx.fillStyle = g; ctx.fillRect(sx, sy, sw, sh);
  ctx.strokeStyle = 'rgba(150,180,220,0.15)'; ctx.lineWidth = 0.5; ctx.strokeRect(sx, sy, sw, sh);
  ctx.font = '8px "JetBrains Mono", monospace'; ctx.fillStyle = 'rgba(200,220,255,0.3)'; ctx.textAlign = 'center';
  ctx.fillText('Activity', sx + sw / 2, sy - 10);
  ctx.fillText('1', sx + sw / 2, sy - 2); ctx.fillText('0', sx + sw / 2, sy + sh + 9);
  ctx.restore();
}

function drawRecordingIndicator(ctx, time, w, h) {
  ctx.save();
  const el = (Date.now() - _startTime) / 1000;
  const hh = el / 3600 | 0, mm = (el % 3600) / 60 | 0, ss = el % 60 | 0;
  const ts = `${String(hh).padStart(2, '0')}:${String(mm).padStart(2, '0')}:${String(ss).padStart(2, '0')}`;
  ctx.fillStyle = `rgba(255,51,51,${0.5 + 0.5 * Math.sin(el * Math.PI * 2) * 0.5})`;
  ctx.beginPath(); ctx.arc(12, 14, 3, 0, Math.PI * 2); ctx.fill();
  ctx.font = '9px "JetBrains Mono", monospace'; ctx.fillStyle = 'rgba(200,220,255,0.4)';
  ctx.textAlign = 'left'; ctx.textBaseline = 'middle'; ctx.fillText(`REC  ${ts}`, 20, 14);
  ctx.restore();
}

window.BrainEffects = {
  drawHeatmap, drawConnectome, drawEEGTrace, drawParticleField,
  drawRegionLabels, drawColorScale, drawRecordingIndicator,
  CONNECTOME, HEATMAP_COLORS, initParticles, initEEGBuffers,
};
