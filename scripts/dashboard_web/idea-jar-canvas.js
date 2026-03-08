/* idea-jar-canvas.js — Animated glass mason jar with floating paper slips
 * Requires: idea-jar-physics.js (window.JarPhysics) — v1.0.0 */
(function () {
  'use strict';
  var instances = {}; // keyed by containerId

  var PRIORITY_COLORS = {
    0: '#ee3344',
    1: '#ff9500',
    2: '#00d4ff',
    3: '#5a6080',
  };

  /** Compute jar geometry from canvas size. */
  function computeJarBounds(w, h, compact) {
    var scale = compact ? 0.8 : 1;
    var cx = w / 2;
    var jarW = Math.min(w * 0.65, 160) * scale;
    var jarH = Math.min(h * 0.72, 200) * scale;
    var bodyTop = h * 0.15;
    var bodyH = jarH * 0.82;
    var neckH = jarH * 0.12;
    var lidH = jarH * 0.08;
    return {
      cx,
      bodyLeft: cx - jarW / 2,
      bodyRight: cx + jarW / 2,
      bodyTop: bodyTop + neckH,
      bodyBottom: bodyTop + neckH + bodyH,
      neckLeft: cx - jarW * 0.32,
      neckRight: cx + jarW * 0.32,
      neckTop: bodyTop,
      lidTop: bodyTop - lidH,
      lidH,
      jarW,
      jarH,
      neckH,
      // Interior bounds for physics
      interior: {
        x: cx - jarW / 2 + 8,
        y: bodyTop + neckH + 6,
        width: jarW - 16,
        height: bodyH - 12,
      },
    };
  }

  /** Draw the glass mason jar. */
  function drawJar(ctx, jb, w, h) {
    // --- Jar body ---
    ctx.beginPath();
    ctx.moveTo(jb.neckLeft, jb.bodyTop);
    ctx.bezierCurveTo(
      jb.bodyLeft, jb.bodyTop,
      jb.bodyLeft, jb.bodyTop + 20,
      jb.bodyLeft, jb.bodyTop + 40
    );
    ctx.lineTo(jb.bodyLeft, jb.bodyBottom - 20);
    ctx.bezierCurveTo(
      jb.bodyLeft, jb.bodyBottom,
      jb.bodyLeft + 12, jb.bodyBottom,
      jb.cx, jb.bodyBottom
    );
    ctx.bezierCurveTo(
      jb.bodyRight - 12, jb.bodyBottom,
      jb.bodyRight, jb.bodyBottom,
      jb.bodyRight, jb.bodyBottom - 20
    );
    ctx.lineTo(jb.bodyRight, jb.bodyTop + 40);
    ctx.bezierCurveTo(
      jb.bodyRight, jb.bodyTop + 20,
      jb.bodyRight, jb.bodyTop,
      jb.neckRight, jb.bodyTop
    );
    ctx.closePath();

    // Glass fill
    ctx.fillStyle = 'rgba(26, 42, 74, 0.30)';
    ctx.fill();
    ctx.strokeStyle = 'rgba(160, 200, 255, 0.55)';
    ctx.lineWidth = 1.5;
    ctx.stroke();

    // Glass highlight (white arc on left side)
    ctx.beginPath();
    ctx.moveTo(jb.bodyLeft + 8, jb.bodyTop + 50);
    ctx.bezierCurveTo(
      jb.bodyLeft + 5, jb.bodyTop + 90,
      jb.bodyLeft + 7, jb.bodyBottom - 60,
      jb.bodyLeft + 12, jb.bodyBottom - 30
    );
    ctx.strokeStyle = 'rgba(255,255,255,0.22)';
    ctx.lineWidth = 4;
    ctx.stroke();

    // --- Neck ---
    ctx.beginPath();
    ctx.rect(jb.neckLeft, jb.neckTop, jb.neckRight - jb.neckLeft, jb.bodyTop - jb.neckTop);
    ctx.fillStyle = 'rgba(26, 42, 74, 0.28)';
    ctx.fill();
    ctx.strokeStyle = 'rgba(160, 200, 255, 0.45)';
    ctx.lineWidth = 1.2;
    ctx.stroke();

    // --- Lid ---
    var lidX = jb.neckLeft - 4;
    var lidW = (jb.neckRight - jb.neckLeft) + 8;
    var grad = ctx.createLinearGradient(lidX, jb.lidTop, lidX, jb.lidTop + jb.lidH);
    grad.addColorStop(0, 'rgba(190,210,240,0.70)');
    grad.addColorStop(0.4, 'rgba(120,160,200,0.55)');
    grad.addColorStop(1, 'rgba(60,90,130,0.50)');
    ctx.beginPath();
    ctx.rect(lidX, jb.lidTop, lidW, jb.lidH);
    ctx.fillStyle = grad;
    ctx.fill();
    ctx.strokeStyle = 'rgba(180,210,255,0.50)';
    ctx.lineWidth = 1;
    ctx.stroke();
    // Lid shadow line
    ctx.beginPath();
    ctx.moveTo(lidX, jb.lidTop + jb.lidH);
    ctx.lineTo(lidX + lidW, jb.lidTop + jb.lidH);
    ctx.strokeStyle = 'rgba(0,0,0,0.25)';
    ctx.lineWidth = 2;
    ctx.stroke();
  }

  /** Draw a single paper slip. */
  function drawSlip(ctx, slip, compact) {
    var color = PRIORITY_COLORS[slip.idea.priority] || PRIORITY_COLORS[3];
    ctx.save();
    ctx.translate(slip.x + slip.w / 2, slip.y + slip.h / 2);
    ctx.rotate(slip.rotation);
    // Paper rect
    var rx = -slip.w / 2, ry = -slip.h / 2, r = 3;
    ctx.beginPath();
    ctx.moveTo(rx + r, ry);
    ctx.lineTo(rx + slip.w - r, ry);
    ctx.arcTo(rx + slip.w, ry, rx + slip.w, ry + r, r);
    ctx.lineTo(rx + slip.w, ry + slip.h - r);
    ctx.arcTo(rx + slip.w, ry + slip.h, rx + slip.w - r, ry + slip.h, r);
    ctx.lineTo(rx + r, ry + slip.h);
    ctx.arcTo(rx, ry + slip.h, rx, ry + slip.h - r, r);
    ctx.lineTo(rx, ry + r);
    ctx.arcTo(rx, ry, rx + r, ry, r);
    ctx.closePath();
    ctx.fillStyle = 'rgba(255,255,255,0.10)';
    ctx.fill();
    ctx.strokeStyle = color;
    ctx.lineWidth = 1.5;
    ctx.stroke();
    // Priority color dot
    ctx.beginPath();
    ctx.arc(rx + 7, 0, 3, 0, Math.PI * 2);
    ctx.fillStyle = color;
    ctx.fill();
    // Title text (skip in compact mode)
    if (!compact) {
      ctx.fillStyle = 'rgba(220,235,255,0.88)';
      ctx.font = '8px system-ui, sans-serif';
      ctx.textBaseline = 'middle';
      var title = (slip.idea.title || '').slice(0, 12);
      ctx.fillText(title, rx + 14, 0);
    }
    ctx.restore();
  }

  /** Animation loop for one instance. */
  function animLoop(inst) {
    var now = performance.now();
    var ctx = inst.ctx;
    var canvas = inst.canvas;
    ctx.clearRect(0, 0, canvas.width, canvas.height);
    drawJar(ctx, inst.jb, canvas.width, canvas.height);
    window.JarPhysics.updateSlipPositions(inst.slips, now, inst.jb.interior);
    inst.slips.forEach(function (s) { drawSlip(ctx, s, inst.compact); });
    inst.rafId = requestAnimationFrame(function () { animLoop(inst); });
  }

  /** Hit-test click against slips (top slip wins). */
  function hitTest(inst, ex, ey) {
    for (var i = inst.slips.length - 1; i >= 0; i--) {
      var s = inst.slips[i];
      if (ex >= s.x && ex <= s.x + s.w && ey >= s.y && ey <= s.y + s.h) {
        return s.idea;
      }
    }
    return null;
  }

  function buildSlips(ideas, jb) {
    return ideas.map(function (idea, i) {
      return window.JarPhysics.createSlipState(idea, i, jb.interior);
    });
  }

  /** initJarCanvas(containerId, ideas, {onSlipClick, compact}) */
  function initJarCanvas(containerId, ideas, opts) {
    destroyJarCanvas(containerId);
    opts = opts || {};
    var container = document.getElementById(containerId);
    if (!container) return;

    var canvas = document.createElement('canvas');
    canvas.width = container.clientWidth || 180;
    canvas.height = container.clientHeight || 240;
    canvas.style.display = 'block';
    container.appendChild(canvas);

    var ctx = canvas.getContext('2d');
    var compact = !!opts.compact;
    var jb = computeJarBounds(canvas.width, canvas.height, compact);
    var slips = buildSlips(ideas || [], jb);

    function onClick(e) {
      if (!opts.onSlipClick) return;
      var rect = canvas.getBoundingClientRect();
      var idea = hitTest(inst, e.clientX - rect.left, e.clientY - rect.top);
      if (idea) opts.onSlipClick(idea);
    }
    canvas.addEventListener('click', onClick);

    var inst = { canvas, ctx, jb, slips, compact, rafId: null, onClick };
    instances[containerId] = inst;
    animLoop(inst);
  }

  /** Refresh slips without reinitializing the canvas. */
  function updateJarIdeas(containerId, ideas) {
    var inst = instances[containerId];
    if (!inst) return;
    inst.slips = buildSlips(ideas || [], inst.jb);
  }

  /** Stop animation and remove canvas. */
  function destroyJarCanvas(containerId) {
    var inst = instances[containerId];
    if (!inst) return;
    cancelAnimationFrame(inst.rafId);
    inst.canvas.removeEventListener('click', inst.onClick);
    if (inst.canvas.parentNode) inst.canvas.parentNode.removeChild(inst.canvas);
    delete instances[containerId];
  }

  window.JarCanvas = { initJarCanvas, updateJarIdeas, destroyJarCanvas };
})();
