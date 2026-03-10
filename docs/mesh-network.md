# Mesh Network Panel — Dashboard Visualization

Horizontal hub-spoke layout showing all mesh nodes with real-time flow animations.

## Architecture

| File | Lines | Purpose |
|------|-------|---------|
| websocket.js | ~400 | Node HTML rendering, flow canvas, WebSocket events |
| css/mesh.css | ~250 | Hub layout, coordinator sizing, flow canvas overlay |
| css/mesh-4.css | ~280 | Gauges, sparklines, action buttons, node details |
| mesh-animation.js | — | Per-peer brainMeshColor for borders/icons/labels |
| mesh.js | — | Particle colors using brainMeshColor |

## Layout

Horizontal flex row: coordinator centered, workers split left/right alphabetically.
Coordinator has `border-width: 10px`, workers `4px`. All nodes `flex: 1 1 0` for equal width.

### Node Ordering (deterministic)
API returns peers in non-deterministic order. Client sorts: coordinator first, then alphabetical by `peer_name`. Workers always same position.

## Flow Animations

Canvas overlay (`mesh-flow-canvas`) on top of `mesh-hub` div.
Particles travel bezier curves **below** nodes (not through them).
Each particle: 6-position trail, glow head, colored by source node's `brainMeshColor`.
Connection lines: dashed bezier curves with glow layer. Spawn every 60ms.

## Node Cards

Each node card shows:
- OS icon + hostname (large, colored by meshColor)
- Role badge (COORDINATOR/WORKER)
- Capabilities (ollama, git, docker, etc.)
- Active tasks count + CPU% + RAM usage
- CPU/RAM sparkline gauges (full-width, auto-resize from `getBoundingClientRect`)
- Current plan assignment
- Action buttons (34px): restart, logs, terminal, ping

## Gauges

Sparkline canvases use `style="width:100%"` (not hardcoded `width="120"`).
`_drawSparklines()` sets canvas pixel width from CSS rendered width on each frame.
Color coding: green <50%, yellow 50-80%, red >80%.

## Colors

All node colors derived from `window.brainMeshColor(peerName)` — same golden-ratio hash as brain visualization. Ensures visual consistency between brain and mesh panels.

## API

| Endpoint | Returns |
|----------|---------|
| `GET /api/mesh` | Array of peer objects (sort client-side!) |

Peer object: `{ peer_name, role, is_online, is_local, os, cpu, mem_used_gb, mem_total_gb, active_tasks, capabilities[] }`

## Sync

`mesh-sync.sh` — pushes main branch to all nodes via `myconvergio` remote + fetch/reset.
Verifies all nodes on same commit SHA.
