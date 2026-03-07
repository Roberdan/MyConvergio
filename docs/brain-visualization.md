# Brain Visualization — Augmented Intelligence Dashboard

The brain widget visualizes the entire AI system as a living organism. Human operator = consciousness (prefrontal cortex). AI agents = neurons. Plans = brain regions. Mesh nodes = organs.

## Architecture

| Module | Lines | Purpose |
|--------|-------|---------|
| brain-regions.js | ~230 | Brain anatomy: 10 regions with positions, colors, system mappings |
| brain-organism.js | ~246 | Neuron state machine (7 states), synapse firing, organism breathing |
| brain-consciousness.js | ~190 | Human interaction tracking, cortical impulses, event stream |
| brain-effects.js | ~203 | Scientific rendering: heatmap, EEG trace, connectome, particles |
| brain-canvas.js | ~250 | Main Canvas 2D renderer, 60fps animation loop |
| brain-layout.js | ~201 | Force-directed layout engine |
| icons.js | ~28 | SVG icon library (Lucide-style, monoline stroke) |

## Brain Region Mapping

| Region | System Component | Activates When |
|--------|-----------------|----------------|
| Prefrontal Cortex | Planner, strategy, decisions | Plan created/started, human commands |
| Motor Cortex | Executor, agents, code generation | Tasks running, agents active |
| Hippocampus | agent-memory, KB, session-store | Memory written, skills earned |
| Amygdala | Thor, guardian, security | Validation, gate checks, rejections |
| Cerebellum | Mesh coordinator, sync | Peer sync, dispatch, load balance |
| Corpus Callosum | SSE, API, mesh-sync | Inter-region communication |
| Brainstem | Heartbeat, DB, cron | Background processes, autonomic |
| Visual Cortex | Dashboard, monitoring | Page load, widget refresh |
| Left Parietal | Code review, debugging, research | Analysis tasks |
| Right Parietal | Code generation, refactoring | Creation tasks |

## Neuron States

| State | Visual | Trigger |
|-------|--------|---------|
| DORMANT | Faint outline, slow breathe | Task pending |
| SPAWNING | Grows from nothing (0.3s) | Task just created |
| PREPARING | Dim pulse, cold blue | Agent starting up |
| FIRING | Bright glow, fast pulse, warm | Agent actively working |
| TRANSMITTING | Trail along synapse | Passing context to next agent |
| COOLING | Green flash → fadeout | Task just completed |
| DEAD | Red halo, dark | Task failed/blocked |

## Synapse Types

| Type | Fires When | Visual |
|------|-----------|--------|
| dependency | Task B completes → Task A starts | Particles flow B→A |
| wave_sequence | Last task in wave N → first in N+1 | Bright cascade |
| thor_validation | Task → Thor → back | Orange arc |
| context_pass | Agent output → next agent input | White trail |

## Human Interaction (Consciousness Layer)

Human commands create **cortical impulses** — expanding shockwaves from prefrontal cortex that cascade through all brain regions. Human events = warm/gold. AI events = cool/blue.

| Event | Color | Source Region |
|-------|-------|---------------|
| Human command | Gold | Prefrontal |
| Human decision | Orange | Prefrontal |
| Human override | Red | Prefrontal |
| AI response | Blue | Motor |
| Agent spawn | Teal | Motor |
| Agent complete | Green | Motor |
| Thor judgment | Amber | Amygdala |
| Memory write | Purple | Hippocampus |

## Scientific Visualization Effects

- **Heatmap overlay**: fMRI-style BOLD signal (blue→cyan→green→yellow→red)
- **Connectome lines**: 15 pre-defined connections matching neuroanatomy
- **EEG trace**: Real-time brainwave at bottom, one wave per region
- **Particle field**: 50-80 ambient particles (cerebrospinal fluid effect)
- **Recording indicator**: "● REC" with elapsed time
- **Color scale bar**: Scientific heatmap legend

## Agent Tracking

| Command | Purpose |
|---------|---------|
| `agent-track.sh start <id> <type> <desc>` | Register new agent |
| `agent-track.sh complete <id> --tokens-in N` | Mark complete with tokens |
| `agent-track.sh list --running` | List active agents |
| `agent-track.sh stats --plan ID` | Token/cost aggregation |

API: `GET /api/agents` returns running agents, recent completions, and aggregate stats.

DB table: `agent_activity` (id, agent_id, task_db_id, plan_id, agent_type, model, status, tokens_*, cost_usd, duration_s, host, region)

## Data Flow

1. Executor launches agent → `agent-track.sh start` → DB insert
2. SSE emits `agent_update` event → brain-consciousness.js receives
3. brain-canvas.js reads agent data every 2s from window._dashboardPlans + /api/agents
4. RegionActivity maps tasks to brain regions, calculates activity levels
5. Canvas renders: outline → heatmap → regions → connectome → neurons → EEG → stats
6. Agent completes → `agent-track.sh complete` → DB update → SSE → neuron cooling animation
7. Human types command → consciousnessTrackHumanCommand → cortical impulse → cascade

## Theme Compatibility

All rendering uses CSS variables and currentColor. SVG icons adapt automatically.
Canvas colors use HSL with dynamic lightness based on theme detection.
