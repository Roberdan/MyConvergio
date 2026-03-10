# Brain Visualization — Augmented Intelligence Dashboard

Force-directed neural graph rendering plans/tasks as neurons, mesh nodes as color-coded clusters.

## Architecture (consolidated v11.29)

| Module | Lines | Purpose |
|--------|-------|---------|
| brain-canvas.js | ~900 | IIFE: force-directed layout, neurons, synapses, mesh colors, scaling |
| websocket.js | ~400 | Mesh panel HTML, flow animation canvas, WebSocket connection |
| mission.js | ~200 | Active missions widget (filters completed plans) |

Previous multi-file arch (brain-regions/organism/consciousness/effects/layout) consolidated into single `brain-canvas.js` IIFE.

## Key Algorithms

### Mesh Color — `meshColor(name)`
Golden-ratio hash: `(Math.abs(hash) * 137.508) % 360` → maximally separated hues.
Exported as `window.brainMeshColor` for cross-file access (websocket.js, mesh.js, mesh-animation.js).
Colors: m3max≈blue(213°), omarchy≈purple(255°), m1mario≈gold(54°).

### Scale Factor — `scaleFactor()`
`sqrt(canvasArea / referenceArea)` where ref = 480×800. Ensures consistent sizing across displays.

### Font Scale — `fontScale()`
`pow(sf, 0.35)` clamped 0.7–1.4. Dampened scaling prevents unreadable text on small/large canvases.

### Gravity — Elliptical
Uses `spreadX`/`spreadY` independently (not circular). Plans placed in orbital ring, tasks orbit parent plan like moons.

## Neuron Rendering

| State | Visual | Trigger |
|-------|--------|---------|
| pending | Faint outline, slow pulse | Task waiting |
| in_progress | Bright glow, warm hue | Agent actively working |
| done | Green flash → dim | Task completed |
| failed | Red halo | Task failed/blocked |

Crisp rendering: `shadowBlur` reduced to 2–4px (was 8–12). No canvas blur filter.

## Synapses

Enhanced particle system: `flowRate`-based continuous spawning, 6-position trail arrays, source-node mesh color with gradient. Active connections pulse, done connections dim to 20% opacity.

## Data Flow

1. `/api/agents` returns plans with `status='doing'` only (no completed)
2. brain-canvas.js reads via `window._dashboardPlans` every 2s
3. Force-directed layout positions neurons with elliptical gravity
4. Canvas renders: neurons → synapses → labels → stats overlay
5. Completed plans auto-removed from brain + active missions widget

## API

| Endpoint | Returns |
|----------|---------|
| `GET /api/agents` | Active plans (`status='doing'`), tasks, agent stats |
| `GET /api/mesh` | Peer array (non-deterministic order — sort client-side) |

## Cache Busting

`style.css` uses `@import url('css/xxx.css?v=N')` — bump ALL imports on CSS changes.
`index.html` uses `?v=TIMESTAMP` on script tags. brain-canvas.js MUST load before websocket.js.
