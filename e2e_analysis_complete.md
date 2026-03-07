# E2E Tests and Source JS Files Analysis

## 1. ALL .spec.ts FILES IN E2E DIRECTORY

```
1. brain.spec.ts
2. charts.spec.ts
3. dashboard.spec.ts
4. fixtures.ts (not a test, but the fixture file)
5. kanban.spec.ts
6. mesh.spec.ts
7. mission.spec.ts
8. plan-actions.spec.ts
9. plan-states.spec.ts
10. terminal.spec.ts
11. theme-widgets.spec.ts
12. widgets.spec.ts
```

---

## 2. ALL JS FILES IN public/js DIRECTORY

**Location:** `/Users/roberdan/.claude-plan-100024/scripts/dashboard_web/`

```
1. activity.js
2. app.js
3. brain-canvas.js
4. brain-consciousness.js
5. brain-effects.js
6. brain-layout.js
7. brain-organism.js
8. brain-regions.js
9. brain-sessions.js
10. charts.js
11. formatters.js
12. icons.js
13. kpi-modals.js
14. kpi.js
15. live-system.js
16. mesh-actions.js
17. mesh-animation.js
18. mesh-delegate.js
19. mesh-plan-ops.js
20. mesh-preflight.js
21. mesh.js
22. mission-details.js
23. mission.js
24. org-chart.js
25. peer-crud.js
26. plan-kanban.js
27. task-pipeline.js
28. terminal.js
29. theme-switcher.js
30. utils.js
31. websocket.js
32. widget-drag.js
```

---

## 3. FULL CONTENT OF TEST FILES

### brain.spec.ts
[Full test file content - 241 lines - tests for Brain Widget including canvas rendering, regions, neurons, and module loading]

Tests include:
- Widget presence and header ("Agent Activity")
- Canvas rendering with dimensions and animation
- Brain regions visualization with active neurons
- Brain outline drawing with region names
- Module integration (window.BrainRegions, window.BrainOrganism, etc.)
- Stats overlay updates
- Responsive resize

### kanban.spec.ts
[Full test file content - 219 lines - tests for Plan Kanban Board including drag-drop, card rendering, and status transitions]

Tests include:
- Widget presence and 3-column layout (todo/doing/done)
- Column headers with status dots
- Card placement and content (plan IDs, task counts, progress bars)
- Drag-and-drop functionality triggering API
- Empty state messages
- Sorting behavior

### widgets.spec.ts
[Full test file content - 263 lines - tests for sparklines, SVG icons, progress bars, mesh monitoring, fonts, theme, substatus badges]

Tests include:
- Sparkline charts on mesh nodes
- SVG icon usage (no emoji)
- Progress bars with gradient backgrounds
- Mesh monitoring widget (peer names, status dots, CPU/RAM gauges)
- Font loading (JetBrains Mono, Orbitron)
- Theme CSS variables
- Substatus badges (CI, Review, etc.)
- Delegate and start buttons
- Terminal widget

### fixtures.ts
[Full fixture file content - 169 lines - canonical mock data for all API endpoints]

Mock data includes:
- Overview (plans, agents, tokens, cost, mesh status)
- Mission (plans with waves and tasks)
- Token distribution (daily and by model)
- Mesh peer data and sync status
- History and task distribution
- Agent activity (running and recent)
- Peer heartbeats with CPU/RAM metrics

---

## 4. RELEVANT SOURCE JS FILE SECTIONS

### brain-regions.js
**File:** `/Users/roberdan/.claude-plan-100024/scripts/dashboard_web/brain-regions.js`

**Purpose:** Brain anatomy layout mapping AI components to brain regions

**Key Components:**

1. **BrainRegions Object** - Maps 10 brain regions with properties:
   - Region name and shortName
   - Center coordinates and radius
   - HSL color values
   - Associated systems
   - Trigger events
   - Description

2. **Region Definitions:**
   - **Prefrontal Cortex** (Planning): center {0.5, 0.15}, yellow-gold, systems: planner, strategic-planner, prompt
   - **Motor Cortex** (Execution): center {0.5, 0.3}, orange, systems: executor, task-executor, agents
   - **Left Parietal** (Analysis): center {0.25, 0.35}, blue, systems: code-review, debugging, explore
   - **Right Parietal** (Generation): center {0.75, 0.35}, pink, systems: code-gen, refactor, create
   - **Corpus Callosum** (Comms): center {0.5, 0.4}, cyan, band shape, systems: sse, webhook, api
   - **Amygdala** (Security): center {0.35, 0.45}, red, systems: thor, guardian, security-audit
   - **Hippocampus** (Memory): center {0.5, 0.55}, purple, systems: agent-memory, kb-search
   - **Visual Cortex** (Dashboard): center {0.5, 0.7}, yellow, systems: dashboard, sse-stream
   - **Cerebellum** (Coordination): center {0.5, 0.85}, teal, systems: mesh-coordinator, mesh-sync
   - **Brainstem** (Autonomic): center {0.5, 0.95}, orange, systems: heartbeat, dashboard-db

3. **RegionActivity Class:**
   - Maps tasks to regions based on status and substatus
   - Tracks activity level (0-1), neuron count, pulse phase for each region
   - `updateFromTasks(tasks)` - updates region states based on task statuses
   - Maintains minimum activity for brainstem (0.15) and visualCortex (0.2)
   - `tick(dt)` - smooths activity transitions

4. **Task to Region Mapping:**
   - Substatus mapping: waiting_thor→amygdala, waiting_ci→brainstem, waiting_review→parietalLeft, agent_running→motor
   - Title keywords mapping to regions (e.g., "test|validat|audit" → amygdala)

5. **BrainOutline** - Bezier curve path for brain silhouette with fissure and sulcus lines

6. **BrainConnections** - Neural pathways between regions with weights

---

### plan-kanban.js
**File:** `/Users/roberdan/.claude-plan-100024/scripts/dashboard_web/plan-kanban.js`

**Purpose:** Drag-and-drop plan pipeline (todo → doing → done)

**Key Functions:**

1. **renderKanban()**
   - Renders 3 columns: todo, doing, done
   - Filters plans by status
   - Displays "No plans" message for empty columns

2. **_kanbanCard(m, col)** - Renders individual plan card HTML
   - Displays: plan ID (#300), plan name, task count (5/8)
   - Progress bar for "doing" status with gradient (RGB based on completion %)
   - Running task count with zap icon
   - Execution host
   - **Cancel/Trash Button:**
     ```js
     const trashBtn = (col === "todo" || col === "doing")
       ? `<button class="kanban-trash-btn" onclick="cancelPlan(${p.id})" title="Cancel plan">${_trashSvg}</button>`
       : "";
     ```
   - Trash SVG icon: 14x14 trash can outline with stroke

3. **kanbanDragStart(e)** - Initializes drag
   - Sets data transfer with plan ID
   - Sets effectAllowed to "move"

4. **kanbanDrop(e, targetStatus)** - Handles drop
   - Validates status transitions
   - For "doing": calls `showStartPlanDialog()` instead of direct POST
   - For destructive actions: shows confirm dialog
   - POSTs to `/api/plan-status` with {plan_id, status}

**Drag Transitions:**
- todo→doing: Shows start dialog
- doing→todo: Confirm "Stop plan?"
- doing→done: Confirm "Mark complete?"
- done→todo: Allowed

---

### mesh-actions.js
**File:** `/Users/roberdan/.claude-plan-100024/scripts/dashboard_web/mesh-actions.js`

**Purpose:** Mesh action toolbar for peer management

**Key Functions:**

1. **meshAction(action, peer)**
   - Routes actions: edit, delete, terminal, movehere, fullsync
   - Example for "terminal": opens termMgr with peer name and tmux session
   - Streams other actions via SSE

2. **streamMeshAction(action, peer)**
   - Creates modal overlay with live output area
   - Opens EventSource to `/api/mesh/action/stream`
   - Listens for "log" events and renders HTML with color coding:
     - cyan: lines starting with "▶" or "---"
     - green: OK, PASS, ✓, done
     - gold: WARN, SKIP, MISMATCH
     - red: ERROR, FAIL, ✗
   - Listens for "done" event with completion status
   - **ANSI Color Support:** `ansiToHtml()` converts ANSI codes to HTML spans

3. **Actions Bar Implementation:**
   - Event delegation on `.mn-act-btn` elements
   - Uses data-peer and data-action attributes (XSS-safe)
   - Toolbar has buttons for: edit, delete, terminal, sync, fullsync, wake, reboot

---

### brain-organism.js
**File:** `/Users/roberdan/.claude-plan-100024/scripts/dashboard_web/brain-organism.js`

**Purpose:** Neuron state machine and synaptic firing

**Key Classes:**

1. **NeuronStates** - 7 states:
   - DORMANT, SPAWNING, PREPARING, FIRING, TRANSMITTING, COOLING, DEAD

2. **NeuronState Class**
   - Tracks state, stateTime, intensity, pulseSpeed, color
   - Size animates during SPAWNING
   - Trail particles during TRANSMITTING
   - `transition(newState)` - state machine transitions
   - `toHSL(alphaOverride)` - returns color string

3. **Synapse Class**
   - Connects two neurons (fromId, toId)
   - Types: dependency, wave_sequence, thor_validation, context_pass
   - Particles animate along synapse when `fire()`
   - Each type has distinct color (cyan, purple, gold, teal)

4. **OrganismBreath Class**
   - Sine wave oscillation (0.2 Hz = one breath per 5 seconds)
   - Applied to DORMANT neurons for "breathing" effect
   - Modulates intensity: 0.06 + 0.06 * sin(phase)

5. **Task-to-Neuron Mapping (taskToNeuronState)**
   - done + _justCompleted → COOLING
   - done → hidden (null)
   - blocked → DEAD
   - submitted → COOLING
   - waiting_thor (substatus) → TRANSMITTING
   - agent_running (substatus) → FIRING
   - in_progress → FIRING
   - pending → DORMANT

6. **Fire Detection (detectFires)**
   - Detects task state transitions
   - Types: spawn, activation, submit, completion, death

---

### mission-details.js
**File:** `/Users/roberdan/.claude-plan-100024/scripts/dashboard_web/mission-details.js`

**Purpose:** Wave Gantt charts and task flow rendering

**Key Functions:**

1. **_progressRing(pct, size, color)**
   - SVG circular progress ring
   - Linear gradient from red→orange→gold→green based on percentage
   - Displays percentage text in center

2. **_renderOneTask(t)**
   - Renders task flow pipeline with 4 steps:
     1. Execute
     2. Submit
     3. Thor (validation)
     4. Done
   - Shows active step (colored cyan)
   - Shows completed steps (colored green)
   - Shows agent (Claude/Copilot) with model abbreviation
   - SVG flow connectors between steps

3. **renderWaveGantt(waves, p)**
   - Renders wave progression bars
   - Shows task count and percentage for each wave
   - Color gradient based on completion %
   - Collapse/expand pending waves
   - SVG arrow connectors showing wave dependencies
   - Distinction: done (green), in_progress (cyan), pending (dim)

4. **_renderWaveGanttSvg(waves)**
   - Creates SVG with row height 28px, bar height 24px
   - Bezier curve arrows for wave dependencies
   - Stroke colors by dependency status

---

### mission.js (Mission Card Rendering)
**File:** `/Users/roberdan/.claude-plan-100024/scripts/dashboard_web/mission.js`

**Purpose:** Render mission plan cards with all UI elements

**Key Sections:**

1. **_renderOnePlan(m)** - Renders complete mission card
   - **Header**: Plan ID (#300), name, status dot
   - **Badges**: health alerts (ALERT/WARN), project name, parallel mode
   - **Buttons:**
     - Delegate button (SVG arrow icon, calls `showDelegatePlanDialog()`)
     - Start button (SVG play icon, only for todo plans, calls `showStartPlanDialog()`)
     - **Cancel button (for non-done plans):**
       ```js
       const cancelBtn = p.status !== "done"
         ? `<button class="mission-cancel-btn" onclick="event.stopPropagation();cancelPlan(${p.id})" title="Cancel plan"><svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><path d="M3 6h18M19 6v14a2 2 0 01-2 2H7a2 2 0 01-2-2V6m3 0V4a2 2 0 012-2h4a2 2 0 012 2v2"/></svg></button>`
         : "";
       ```
   - **Progress Section:**
     - Progress ring (56px SVG)
     - Progress bar with gradient fill
     - Task completion label (e.g., "Done 5/8", "63%")
     - Substatus badges (waiting_ci, waiting_review, waiting_merge, waiting_thor, agent_running)
   - **Health Alerts:** rendered via `_renderHealthAlerts(health, p.id, hostName)`
   - **Human Summary:** if available
   - **Wave Gantt:** if waves exist
   - **Task Flow:** if running/submitted tasks exist

---

### kpi-modals.js
**File:** `/Users/roberdan/.claude-plan-100024/scripts/dashboard_web/kpi-modals.js`

**Purpose:** KPI card drill-down modals

**Key Functions:**

1. **_kpiModal(title, bodyHtml)**
   - Creates overlay with modal box
   - Title bar with close button (✕)
   - Body HTML content
   - Close on background click or Escape key

2. **Modal Types:**
   - `openPlansModal()` - lists all plans from /api/history + /api/plans/assignable
   - `openActiveModal()` - scrolls to #mission-panel
   - `openAgentsModal()` - lists in_progress tasks with executor agent/host
   - `openTokensModal()` - scrolls to #token-chart
   - `openCostModal()` - shows cost breakdown by model with percentages
   - `openBlockedModal()` - lists blocked tasks with reasons

---

### mesh-plan-ops.js
**File:** `/Users/roberdan/.claude-plan-100024/scripts/dashboard_web/mesh-plan-ops.js`

**Purpose:** Mesh plan operations (start, sync, cancel, reset)

**Key Functions:**

1. **showStartPlanDialog(planId, planName)**
   - **Dialog Elements:**
     - Target Node selector (Local + dynamically loaded peer list)
     - Model dropdown (gpt-5.3-codex, claude-opus-4.6, claude-sonnet-4.6, gpt-5-mini, claude-haiku-4.5)
     - Preflight status check (✓ Sync OK / ✗ Sync issues / ⚠ Could not verify)
     - Cancel and "▶ Start Plan" buttons
   - **Peer Loading:** Fetches `/api/mesh` and populates peer cards with CPU % display
   - **Preflight:** Runs `runPreflight()` which checks `/api/plan/preflight` via SSE
   - **Start Execution:** Calls `startPlanExecution(planId, planName, 'copilot', target, model)`

2. **startPlanExecution(planId, planName, cli, target, model)**
   - Creates output modal with pre element
   - Opens EventSource to `/api/plan/start?plan_id=...&cli=copilot&target=...&model=...`
   - Renders log lines with color coding (cyan, green, red)
   - Shows completion status with checkmark or error icon

3. **cancelPlan(planId)**
   - Confirmation dialog
   - Calls `/api/plan/cancel?plan_id={planId}`
   - Warns: cancels pending/in_progress tasks and waves, preserves completed

4. **resetPlan(planId)**
   - Confirmation dialog
   - Calls `/api/plan/reset?plan_id={planId}`
   - Resets to "todo", tasks to "pending", clears agents and tokens

---

## 5. PLAYWRIGHT CONFIG

**File:** `/Users/roberdan/.claude-plan-100024/scripts/dashboard_web/playwright.config.ts`

```typescript
import { defineConfig } from '@playwright/test';

export default defineConfig({
  testDir: './tests/e2e',
  timeout: 15000,
  retries: 0,
  workers: 1,
  reporter: [['list'], ['html', { open: 'never' }]],
  use: {
    browserName: 'chromium',
    headless: true,
    viewport: { width: 1440, height: 900 },
    baseURL: 'http://localhost:8420',
    screenshot: 'only-on-failure',
    trace: 'retain-on-failure',
  },
  webServer: {
    command: 'python3 server.py --port 8420',
    port: 8420,
    timeout: 10000,
    reuseExistingServer: true,
  },
});
```

**Key Config Points:**
- Test directory: `./tests/e2e`
- Timeout: 15 seconds per test
- 1 worker (no parallelization)
- Viewport: 1440x900
- Base URL: `http://localhost:8420`
- Screenshots and traces only on failure
- Local Python server starts with `python3 server.py --port 8420`

---

## 6. SUMMARY OF KEY ELEMENTS

### Brain Widget (brain.spec.ts)
- **Title:** "Agent Activity" in `#brain-widget .widget-title`
- **Canvas:** `#brain-canvas-container canvas` - renders animated brain visualization
- **Stats Bar:** `#brain-stats` - displays neuron/region counts
- **Regions Rendering:** 10 brain regions with names like "Planning", "Execution", "Security", etc.
- **Module Exports:** BrainRegions, BrainOrganism, BrainEffects, _consciousness all exposed to window

### Kanban Widget (kanban.spec.ts)
- **Widget ID:** `#plan-kanban-widget`
- **Columns:** 3 columns with `data-status="todo|doing|done"`
- **Cards:** `.kanban-card` with plan ID, name, task count, progress bar, running count
- **Cancel Buttons:** `.kanban-trash-btn` with trash SVG icon
  - Only appears on todo and doing cards
  - Calls `cancelPlan(planId)`
- **Drag-Drop:** Sets `data-plan-id` and validates transitions

### Start Dialog (mesh-plan-ops.js)
- **Trigger:** `showStartPlanDialog(planId, planName)` called from:
  - Mission card "Start" button (todo plans)
  - Kanban card drag to "doing"
- **Fields:**
  - Target Node selector with peer list and CPU display
  - Model dropdown with 5 LLM options
  - Preflight sync status check
- **Output:** Shows live progress via SSE with colored log output

### Mission Card Components (mission.js)
- **Cancel Button:** Trash icon, only on non-done plans
  - HTML: `<button class="mission-cancel-btn" onclick="cancelPlan(${p.id})"><svg>trash icon</svg></button>`
- **Start Button:** Play icon, only on todo plans
  - HTML: `<button class="mission-start-btn" onclick="showStartPlanDialog(${p.id},'${name}')">`
- **Delegate Button:** Arrow icon, all plans
  - HTML: `<button class="mission-delegate-btn" onclick="showDelegatePlanDialog(${p.id},'${name}')">`
- **Progress Ring:** SVG circular progress with gradient
- **Wave Gantt:** SVG with bezier arrows for dependencies
- **Task Flow:** Step pipeline showing: Execute → Submit → Thor → Done

### Mesh Widget (mesh-actions.js)
- **Action Buttons:** `.mn-act-btn` with `data-action` and `data-peer` attributes
- **Available Actions:** edit, delete, terminal, movehere, fullsync
- **Output Modal:** Shows live action output with ANSI color conversion
