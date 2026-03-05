/**
 * Mesh Network Canvas — animation and drawing logic.
 */

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

  let coordIdx = meshPeers.findIndex((p) => p.is_online);
  if (coordIdx === -1) coordIdx = 0;

  meshPeers.forEach((p, i) => {
    if (i === coordIdx) return;
    const a = nodePositions[coordIdx],
      b = nodePositions[i];
    if (!a || !b) return;
    ctx.beginPath();
    ctx.moveTo(a.x, a.y);
    ctx.lineTo(b.x, b.y);
    ctx.strokeStyle = p.is_online ? "rgba(0,229,255,0.15)" : "rgba(90,96,128,0.08)";
    ctx.lineWidth = p.is_online ? 1.5 : 0.5;
    ctx.stroke();

    if (p.is_online) {
      ctx.setLineDash([4, 8]);
      ctx.strokeStyle = "rgba(0,229,255,0.08)";
      ctx.stroke();
      ctx.setLineDash([]);
    }
  });

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

    ctx.beginPath();
    ctx.arc(x, y, pt.size * 3, 0, Math.PI * 2);
    const glow = ctx.createRadialGradient(x, y, 0, x, y, pt.size * 3);
    glow.addColorStop(0, pt.color + "40");
    glow.addColorStop(1, "transparent");
    ctx.fillStyle = glow;
    ctx.fill();
  });

  meshPeers.forEach((p, i) => {
    const pos = nodePositions[i];
    if (!pos) return;
    const isHover = hoveredNode === i;
    const r = pos.r + (isHover ? 4 : 0);

    ctx.beginPath();
    ctx.roundRect(pos.x - r, pos.y - r, r * 2, r * 2, 8);
    ctx.fillStyle = COLORS.nodeBg;
    ctx.fill();
    ctx.strokeStyle = p.is_online ? (pos.isCoord ? COLORS.magenta : COLORS.green) : COLORS.dim;
    ctx.lineWidth = pos.isCoord ? 2 : 1;
    ctx.stroke();

    if (p.is_online) {
      ctx.shadowColor = pos.isCoord ? COLORS.magenta : COLORS.green;
      ctx.shadowBlur = isHover ? 20 : 8;
      ctx.stroke();
      ctx.shadowBlur = 0;
    }

    if (p.is_online && p.cpu > 0) {
      const cpuPct = Math.min(p.cpu / 100, 1);
      const startAngle = -Math.PI / 2;
      const endAngle = startAngle + cpuPct * Math.PI * 2;
      ctx.beginPath();
      ctx.arc(pos.x, pos.y, r + 5, startAngle, endAngle);
      ctx.strokeStyle = p.cpu < 50 ? COLORS.green : p.cpu < 80 ? COLORS.gold : COLORS.red;
      ctx.lineWidth = 3;
      ctx.lineCap = "round";
      ctx.stroke();
      ctx.lineCap = "butt";
    }

    const iconY = pos.y - 10;
    ctx.fillStyle = p.is_online ? COLORS.cyan : COLORS.dim;
    ctx.fillRect(pos.x - 10, iconY - 6, 20, 14);
    ctx.strokeStyle = COLORS.nodeBg;
    ctx.lineWidth = 1;
    ctx.strokeRect(pos.x - 10, iconY - 6, 20, 14);
    ctx.fillStyle = COLORS.nodeBg;
    ctx.fillRect(pos.x - 4, iconY + 8, 8, 3);
    ctx.fillRect(pos.x - 7, iconY + 11, 14, 2);
    ctx.fillStyle = p.is_online ? COLORS.bg : "#1a1a2a";
    ctx.fillRect(pos.x - 8, iconY - 4, 16, 10);

    ctx.fillStyle = p.is_online ? COLORS.text : COLORS.dim;
    ctx.font = `${pos.isCoord ? "bold " : ""}11px "JetBrains Mono"`;
    ctx.textAlign = "center";
    ctx.fillText(p.peer_name, pos.x, pos.y + r - 8);

    if (p.is_online) {
      ctx.fillStyle = COLORS.gold;
      ctx.font = '9px "JetBrains Mono"';
      ctx.fillText(`${p.active_tasks} tasks`, pos.x, pos.y + r - 0);
    } else {
      ctx.fillStyle = COLORS.red;
      ctx.font = '9px "JetBrains Mono"';
      ctx.fillText("OFFLINE", pos.x, pos.y + r - 0);
    }

    if (pos.isCoord) {
      ctx.fillStyle = COLORS.magenta;
      ctx.font = 'bold 8px "Orbitron"';
      ctx.fillText("COORDINATOR", pos.x, pos.y - r + 8);
    }
  });

  if (hoveredNode >= 0 && hoveredNode < meshPeers.length) {
    const p = meshPeers[hoveredNode];
    const pos = nodePositions[hoveredNode];
    if (pos) {
      const caps = (p.capabilities || "worker").split(",").join(", ");
      const lines = [p.peer_name, p.is_online ? "ONLINE" : "OFFLINE", `CPU: ${p.cpu || 0}%`, `Tasks: ${p.active_tasks || 0}`, `Caps: ${caps}`];
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
        ctx.fillStyle = li === 0 ? COLORS.cyan : li === 1 ? (p.is_online ? COLORS.green : COLORS.red) : COLORS.text;
        ctx.font = li === 0 ? 'bold 11px "JetBrains Mono"' : '10px "JetBrains Mono"';
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
