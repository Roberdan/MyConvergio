/* brain-interact.js — Drag, click, hover for brain graph nodes */
(() => {
  'use strict';
  const DRAG_TH = 5;
  let drag = null,
    hover = null,
    tooltip = null,
    canvas = null,
    _debugXY = null;

  function canvasXY(e) {
    const S = window._brainState;
    if (!S || !S.canvas) return { x: 0, y: 0 };
    // Chrome reports offsetX/offsetY in viewport pixels (scaled by body zoom).
    // Canvas draws in CSS pixels. Divide by zoom to convert.
    const zoom = parseFloat(document.body.style.zoom) || 1;
    return { x: e.offsetX / zoom, y: e.offsetY / zoom };
  }

  function hitTest(mx, my) {
    const S = window._brainState;
    if (!S?.layout) return null;
    const nodes = S.layout.nodes;
    for (let i = nodes.length - 1; i >= 0; i--) {
      const n = nodes[i];
      const r = n.type === 'plan' ? 28 : 14;
      if (Math.hypot(mx - n.x, my - n.y) < r) return n;
    }
    return null;
  }

  function onDown(e) {
    if (!canvas) return;
    const p = canvasXY(e);
    const hit = hitTest(p.x, p.y);
    if (!hit) {
      hideTooltip();
      return;
    }
    drag = { node: hit, sx: p.x, sy: p.y, ox: hit.x, oy: hit.y, moved: false };
    const S = window._brainState;
    if (S?.layout) S.layout.pin(hit.id);
    canvas.setPointerCapture(e.pointerId);
    e.preventDefault();
  }

  function onMove(e) {
    if (!canvas) return;
    const p = canvasXY(e);
    _debugXY = p;
    if (drag) {
      const dx = p.x - drag.sx,
        dy = p.y - drag.sy;
      if (!drag.moved && Math.hypot(dx, dy) < DRAG_TH) return;
      drag.moved = true;
      canvas.style.cursor = 'grabbing';
      const S = window._brainState;
      if (S?.layout) {
        S.layout.moveTo(drag.node.id, drag.ox + dx, drag.oy + dy);
        S.layout.kick();
        if (window._brainRequestFrame) window._brainRequestFrame();
      }
      return;
    }
    const hit = hitTest(p.x, p.y);
    const prev = hover;
    hover = hit;
    canvas.style.cursor = hit ? 'pointer' : 'default';
    if (hit !== prev && window._brainRequestFrame) window._brainRequestFrame();
  }

  function onUp(e) {
    if (!drag) return;
    const S = window._brainState;
    if (!drag.moved) {
      showTooltip(drag.node, e);
    }
    if (S?.layout) S.layout.unpin(drag.node.id);
    if (S?.layout) S.layout.kick();
    if (window._brainRequestFrame) window._brainRequestFrame();
    canvas.style.cursor = 'default';
    drag = null;
  }

  // --- Tooltip ---
  function showTooltip(node, evt) {
    hideTooltip();
    const el = document.createElement('div');
    el.className = 'brain-tooltip';
    el.innerHTML = buildHTML(node);
    const box = canvas.parentElement;
    box.style.position = 'relative';
    const zoom = parseFloat(document.body.style.zoom) || 1;
    let tx = evt.offsetX / zoom + 14;
    let ty = evt.offsetY / zoom - 20;
    const bw = box.clientWidth,
      bh = box.clientHeight;
    if (tx + 260 > bw) tx = bw - 270;
    if (ty < 8) ty = 8;
    if (ty + 220 > bh) ty = bh - 220;
    el.style.cssText = `position:absolute;left:${tx}px;top:${ty}px;z-index:100;`;
    box.appendChild(el);
    tooltip = el;
    setTimeout(() => {
      if (tooltip === el) hideTooltip();
    }, 10000);
  }
  function hideTooltip() {
    if (tooltip?.parentNode) tooltip.parentNode.removeChild(tooltip);
    tooltip = null;
  }
  function buildHTML(n) {
    return n.type === 'plan' ? planHTML(n) : agentHTML(n);
  }
  function agentHTML(n) {
    const d = n._data || {};
    const rows = [`<div class="btt-title">${sdot(d.status)} ${esc(d.name || n.id)}</div>`];
    if (d.taskId) rows.push(row('Task', d.taskId));
    rows.push(row('Status', d.status || '?'));
    if (d.host) rows.push(row('Host', d.host));
    rows.push(row('Plan', '#' + (d.planId || '?')));
    if (d.wave) rows.push(row('Wave', d.wave));
    if (d.model) rows.push(row('Model', d.model));
    if (d.filesChanged || d.linesAdded || d.linesRemoved) {
      rows.push(row('Files', (d.filesChanged || 0) + ' changed'));
      rows.push(
        `<div class="btt-row"><span class="btt-label">Lines</span><span class="btt-val"><span style="color:var(--green)">+${d.linesAdded || 0}</span> <span style="color:var(--red)">-${d.linesRemoved || 0}</span></span></div>`,
      );
    }
    if (d.artifacts?.length) {
      rows.push('<div class="btt-tasks">');
      d.artifacts.slice(0, 6).forEach((f) => {
        rows.push(
          `<div class="btt-task" style="color:var(--cyan)">${esc(f.split('/').slice(-2).join('/'))}</div>`,
        );
      });
      if (d.artifacts.length > 6)
        rows.push(
          `<div class="btt-task" style="color:var(--text-dim)">+${d.artifacts.length - 6} more</div>`,
        );
      rows.push('</div>');
    }
    return rows.join('\n');
  }
  function planHTML(n) {
    const d = n._data || {};
    const S = window._brainState;
    const tasks = (S?.layout?.nodes || []).filter((x) => x.parentId === n.id);
    const active = tasks.filter((t) => t._data?.isActive).length;
    const done = tasks.filter((t) => t._data?.status === 'done').length;
    const rows = [`<div class="btt-title">${esc(d.name || n.id)}</div>`];
    rows.push(row('Status', d.status || '?'));
    rows.push(
      `<div class="btt-row"><span class="btt-label">Tasks</span><span class="btt-val">${done} done / ${tasks.length} total</span></div>`,
    );
    if (active)
      rows.push(
        `<div class="btt-row"><span class="btt-label">Active</span><span class="btt-val btt-green">${active}</span></div>`,
      );
    rows.push('<div class="btt-tasks">');
    tasks.slice(0, 10).forEach((t) => {
      const td = t._data || {};
      rows.push(
        `<div class="btt-task">${sdot(td.status)} ${esc(td.taskId || '')} ${esc(td.name || '')}</div>`,
      );
    });
    if (tasks.length > 10)
      rows.push(
        `<div class="btt-task" style="color:var(--text-dim)">+${tasks.length - 10} more</div>`,
      );
    rows.push('</div>');
    return rows.join('\n');
  }
  function row(l, v) {
    return `<div class="btt-row"><span class="btt-label">${l}</span><span class="btt-val">${esc(String(v))}</span></div>`;
  }
  function sdot(s) {
    const v = {
      agent_running: 'var(--green)',
      in_progress: 'var(--cyan)',
      waiting_thor: 'var(--gold)',
      done: 'var(--border)',
      pending: 'var(--bg-panel)',
      submitted: 'var(--text-dim)',
      blocked: 'var(--red)',
    };
    const c = v[s] || 'var(--text-dim)';
    return `<span style="display:inline-block;width:8px;height:8px;border-radius:50%;background:${c};margin-right:4px;vertical-align:middle"></span>`;
  }
  function esc(s) {
    return (s || '').replace(/</g, '&lt;').replace(/>/g, '&gt;');
  }

  // --- Hover ring ---
  window._brainDrawHover = function (ctx) {
    if (!hover || drag) return;
    const r = hover.type === 'plan' ? 30 : 16;
    ctx.save();
    ctx.strokeStyle = 'rgba(255,255,255,0.6)';
    ctx.lineWidth = 2;
    ctx.setLineDash([5, 4]);
    ctx.beginPath();
    ctx.arc(hover.x, hover.y, r, 0, Math.PI * 2);
    ctx.stroke();
    ctx.setLineDash([]);
    ctx.restore();
  };

  window._brainInteract = {
    init(c) {
      canvas = c;
      c.style.touchAction = 'none';
      c.addEventListener('pointerdown', onDown);
      c.addEventListener('pointermove', onMove);
      c.addEventListener('pointerup', onUp);
      c.addEventListener('pointerleave', () => {
        if (drag) {
          const S = window._brainState;
          if (S?.layout) S.layout.unpin(drag.node.id);
          drag = null;
        }
        hover = null;
        _debugXY = null;
        if (canvas) canvas.style.cursor = 'default';
      });
    },
    destroy() {
      if (!canvas) return;
      canvas.removeEventListener('pointerdown', onDown);
      canvas.removeEventListener('pointermove', onMove);
      canvas.removeEventListener('pointerup', onUp);
      hideTooltip();
      canvas = null;
      drag = null;
      hover = null;
      _debugXY = null;
    },
    isDragging() {
      return !!drag;
    },
  };
})();
