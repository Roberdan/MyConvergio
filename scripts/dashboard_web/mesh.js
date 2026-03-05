/**
 * Mesh Network Canvas — state, topology, and bootstrap logic.
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

  let coordIdx = meshPeers.findIndex((p) => p.is_online);
  if (coordIdx === -1) coordIdx = 0;
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
  particles = [];
  let coordIdx = meshPeers.findIndex((p) => p.is_online);
  if (coordIdx === -1) coordIdx = 0;
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

window.initMeshCanvas = initMeshCanvas;
window.updateMeshPeers = updateMeshPeers;
