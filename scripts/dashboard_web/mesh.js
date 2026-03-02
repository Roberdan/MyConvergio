/**
 * Mesh Network Canvas — animated node topology with data flow particles.
 * Renders peer nodes in radial layout with CPU gauges, connection lines,
 * and flowing data particles.
 */

const COLORS = {
  bg: "#04060e",
  grid: "#0a1020",
  cyan: "#00e5ff",
  magenta: "#ff2daa",
  gold: "#ffb700",
  green: "#00ff88",
  red: "#ff3355",
  text: "#c8d0e8",
  dim: "#5a6080",
  nodeBg: "#0f1424",
  nodeBorder: "#1a2040",
};

let meshPeers = [];
let particles = [];
let nodePositions = [];
let meshCanvas, meshCtx;
let animFrame = null;
let hoveredNode = -1;

function initMeshCanvas() {
  meshCanvas = document.getElementById("mesh-canvas");
  if (!meshCanvas) return;
  meshCtx = meshCanvas.getContext("2d");
  meshCanvas.addEventListener("mousemove", onMeshMouse);
  meshCanvas.addEventListener("mouseleave", () => {
    hoveredNode = -1;
  });
  resizeMeshCanvas();
  window.addEventListener("resize", resizeMeshCanvas);
  animateMesh();
}

function resizeMeshCanvas() {
  if (!meshCanvas) return;
  const rect = meshCanvas.parentElement.getBoundingClientRect();
  meshCanvas.width = rect.width * window.devicePixelRatio;
  meshCanvas.height = 320 * window.devicePixelRatio;
  meshCanvas.style.height = "320px";
  meshCtx.scale(window.devicePixelRatio, window.devicePixelRatio);
  computeNodePositions();
}

function computeNodePositions() {
  if (!meshCanvas) return;
  const w = meshCanvas.clientWidth;
  const h = meshCanvas.clientHeight;
  const cx = w / 2,
    cy = h / 2;
  nodePositions = [];
  if (meshPeers.length === 0) return;

  // Center node = coordinator (first online or first peer)
  const coordIdx = meshPeers.findIndex((p) => p.is_online) ?? 0;
  const radius = Math.min(w, h) * 0.34;

  meshPeers.forEach((p, i) => {
    if (i === coordIdx) {
      nodePositions.push({ x: cx, y: cy, r: 40, isCoord: true });
    } else {
      const count = meshPeers.length - 1;
      const idx = i > coordIdx ? i - 1 : i;
      const angle = (idx / count) * Math.PI * 2 - Math.PI / 2;
      nodePositions.push({
        x: cx + Math.cos(angle) * radius,
        y: cy + Math.sin(angle) * radius,
        r: 32,
        isCoord: false,
      });
    }
  });
}

function updateMeshPeers(peers) {
  meshPeers = peers || [];
  computeNodePositions();
  // Seed particles for online connections
  particles = [];
  const coordIdx = meshPeers.findIndex((p) => p.is_online) ?? 0;
  meshPeers.forEach((p, i) => {
    if (i !== coordIdx && p.is_online) {
      for (let j = 0; j < 3; j++) {
        particles.push({
          from: coordIdx,
          to: i,
          t: Math.random(),
          speed: 0.003 + Math.random() * 0.004,
          color: j % 2 === 0 ? COLORS.cyan : COLORS.magenta,
          size: 2 + Math.random() * 2,
        });
      }
      // Return particles
      for (let j = 0; j < 2; j++) {
        particles.push({
          from: i,
          to: coordIdx,
          t: Math.random(),
          speed: 0.002 + Math.random() * 0.003,
          color: COLORS.gold,
          size: 1.5 + Math.random() * 1.5,
        });
      }
    }
  });
}

function animateMesh() {
  drawMesh();
  animFrame = requestAnimationFrame(animateMesh);
}

function drawMesh() {
  if (!meshCtx || !meshCanvas) return;
  const w = meshCanvas.clientWidth;
  const h = meshCanvas.clientHeight;
  const ctx = meshCtx;

  ctx.clearRect(0, 0, w, h);

  // Grid background
  ctx.strokeStyle = COLORS.grid;
  ctx.lineWidth = 0.5;
  for (let x = 0; x < w; x += 40) {
    ctx.beginPath();
    ctx.moveTo(x, 0);
    ctx.lineTo(x, h);
    ctx.stroke();
  }
  for (let y = 0; y < h; y += 40) {
    ctx.beginPath();
    ctx.moveTo(0, y);
    ctx.lineTo(w, y);
    ctx.stroke();
  }

  if (meshPeers.length === 0 || nodePositions.length === 0) {
    ctx.fillStyle = COLORS.dim;
    ctx.font = '13px "JetBrains Mono"';
    ctx.textAlign = "center";
    ctx.fillText("No mesh peers configured", w / 2, h / 2);
    return;
  }

  const coordIdx = meshPeers.findIndex((p) => p.is_online) ?? 0;

  // Draw connection lines
  meshPeers.forEach((p, i) => {
    if (i === coordIdx) return;
    const a = nodePositions[coordIdx],
      b = nodePositions[i];
    if (!a || !b) return;
    ctx.beginPath();
    ctx.moveTo(a.x, a.y);
    ctx.lineTo(b.x, b.y);
    ctx.strokeStyle = p.is_online
      ? "rgba(0,229,255,0.15)"
      : "rgba(90,96,128,0.08)";
    ctx.lineWidth = p.is_online ? 1.5 : 0.5;
    ctx.stroke();

    // Dashed overlay for online connections
    if (p.is_online) {
      ctx.setLineDash([4, 8]);
      ctx.strokeStyle = "rgba(0,229,255,0.08)";
      ctx.stroke();
      ctx.setLineDash([]);
    }
  });

  // Update and draw particles
  particles.forEach((pt) => {
    pt.t += pt.speed;
    if (pt.t > 1) pt.t -= 1;
    const a = nodePositions[pt.from],
      b = nodePositions[pt.to];
    if (!a || !b) return;
    const x = a.x + (b.x - a.x) * pt.t;
    const y = a.y + (b.y - a.y) * pt.t;

    ctx.beginPath();
    ctx.arc(x, y, pt.size, 0, Math.PI * 2);
    ctx.fillStyle = pt.color;
    ctx.fill();

    // Glow
    ctx.beginPath();
    ctx.arc(x, y, pt.size * 3, 0, Math.PI * 2);
    const glow = ctx.createRadialGradient(x, y, 0, x, y, pt.size * 3);
    glow.addColorStop(0, pt.color + "40");
    glow.addColorStop(1, "transparent");
    ctx.fillStyle = glow;
    ctx.fill();
  });

  // Draw nodes
  meshPeers.forEach((p, i) => {
    const pos = nodePositions[i];
    if (!pos) return;
    const isHover = hoveredNode === i;
    const r = pos.r + (isHover ? 4 : 0);

    // Node background
    ctx.beginPath();
    ctx.roundRect(pos.x - r, pos.y - r, r * 2, r * 2, 8);
    ctx.fillStyle = COLORS.nodeBg;
    ctx.fill();
    ctx.strokeStyle = p.is_online
      ? pos.isCoord
        ? COLORS.magenta
        : COLORS.green
      : COLORS.dim;
    ctx.lineWidth = pos.isCoord ? 2 : 1;
    ctx.stroke();

    // Online glow
    if (p.is_online) {
      ctx.shadowColor = pos.isCoord ? COLORS.magenta : COLORS.green;
      ctx.shadowBlur = isHover ? 20 : 8;
      ctx.stroke();
      ctx.shadowBlur = 0;
    }

    // CPU gauge ring
    if (p.is_online && p.cpu > 0) {
      const cpuPct = Math.min(p.cpu / 100, 1);
      const startAngle = -Math.PI / 2;
      const endAngle = startAngle + cpuPct * Math.PI * 2;
      ctx.beginPath();
      ctx.arc(pos.x, pos.y, r + 5, startAngle, endAngle);
      ctx.strokeStyle =
        p.cpu < 50 ? COLORS.green : p.cpu < 80 ? COLORS.gold : COLORS.red;
      ctx.lineWidth = 3;
      ctx.lineCap = "round";
      ctx.stroke();
      ctx.lineCap = "butt";
    }

    // Computer icon
    const iconY = pos.y - 10;
    ctx.fillStyle = p.is_online ? COLORS.cyan : COLORS.dim;
    ctx.fillRect(pos.x - 10, iconY - 6, 20, 14);
    ctx.strokeStyle = COLORS.nodeBg;
    ctx.lineWidth = 1;
    ctx.strokeRect(pos.x - 10, iconY - 6, 20, 14);
    ctx.fillStyle = COLORS.nodeBg;
    ctx.fillRect(pos.x - 4, iconY + 8, 8, 3);
    ctx.fillRect(pos.x - 7, iconY + 11, 14, 2);
    // Screen content
    ctx.fillStyle = p.is_online ? COLORS.bg : "#1a1a2a";
    ctx.fillRect(pos.x - 8, iconY - 4, 16, 10);

    // Node name
    ctx.fillStyle = p.is_online ? COLORS.text : COLORS.dim;
    ctx.font = `${pos.isCoord ? "bold " : ""}11px "JetBrains Mono"`;
    ctx.textAlign = "center";
    ctx.fillText(p.peer_name, pos.x, pos.y + r - 8);

    // Status + tasks
    if (p.is_online) {
      ctx.fillStyle = COLORS.gold;
      ctx.font = '9px "JetBrains Mono"';
      ctx.fillText(`${p.active_tasks} tasks`, pos.x, pos.y + r - 0);
    } else {
      ctx.fillStyle = COLORS.red;
      ctx.font = '9px "JetBrains Mono"';
      ctx.fillText("OFFLINE", pos.x, pos.y + r - 0);
    }

    // Coordinator label
    if (pos.isCoord) {
      ctx.fillStyle = COLORS.magenta;
      ctx.font = 'bold 8px "Orbitron"';
      ctx.fillText("COORDINATOR", pos.x, pos.y - r + 8);
    }
  });

  // Hover tooltip
  if (hoveredNode >= 0 && hoveredNode < meshPeers.length) {
    const p = meshPeers[hoveredNode];
    const pos = nodePositions[hoveredNode];
    if (pos) {
      const caps = (p.capabilities || "worker").split(",").join(", ");
      const lines = [
        p.peer_name,
        p.is_online ? "ONLINE" : "OFFLINE",
        `CPU: ${p.cpu || 0}%`,
        `Tasks: ${p.active_tasks || 0}`,
        `Caps: ${caps}`,
      ];
      const tw = 160,
        th = lines.length * 16 + 12;
      let tx = pos.x + pos.r + 12,
        ty = pos.y - th / 2;
      if (tx + tw > w) tx = pos.x - pos.r - tw - 12;
      if (ty < 0) ty = 4;
      if (ty + th > h) ty = h - th - 4;

      ctx.fillStyle = "rgba(10,14,26,0.95)";
      ctx.beginPath();
      ctx.roundRect(tx, ty, tw, th, 6);
      ctx.fill();
      ctx.strokeStyle = COLORS.cyan;
      ctx.lineWidth = 1;
      ctx.stroke();

      ctx.fillStyle = COLORS.text;
      ctx.font = '11px "JetBrains Mono"';
      ctx.textAlign = "left";
      lines.forEach((line, li) => {
        ctx.fillStyle =
          li === 0
            ? COLORS.cyan
            : li === 1
              ? p.is_online
                ? COLORS.green
                : COLORS.red
              : COLORS.text;
        ctx.font =
          li === 0 ? 'bold 11px "JetBrains Mono"' : '10px "JetBrains Mono"';
        ctx.fillText(line, tx + 8, ty + 16 + li * 16);
      });
    }
  }
}

function onMeshMouse(e) {
  const rect = meshCanvas.getBoundingClientRect();
  const mx = e.clientX - rect.left;
  const my = e.clientY - rect.top;
  hoveredNode = -1;
  nodePositions.forEach((pos, i) => {
    const dx = mx - pos.x,
      dy = my - pos.y;
    if (Math.abs(dx) < pos.r + 4 && Math.abs(dy) < pos.r + 4) {
      hoveredNode = i;
    }
  });
  meshCanvas.style.cursor = hoveredNode >= 0 ? "pointer" : "default";
}
