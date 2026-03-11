# MESH SYSTEM - COMPLETE FILES INVENTORY

## RUST DAEMON CODE (12 files, 1,765 LOC)

**Root:** `rust/claude-core/src/mesh/`

### Source Files (10 files, 1,485 LOC)
```
daemon.rs                  277 LOC  Main daemon loop, config, peer connections
daemon_sync.rs             291 LOC  Socket handling, frame processing, heartbeats
sync.rs                    341 LOC  CRDT sync engine, change collection/application
handoff.rs                 208 LOC  Lock management, plan merge, sync source detection
handoff_ssh.rs              84 LOC  SSH execution for remote operations
net.rs                     112 LOC  Network optimization, Tailscale integration
ws.rs                      136 LOC  WebSocket protocol, frame encoding
sync_batch.rs               31 LOC  Batch window utilities
mod.rs                       5 LOC  Module declarations
```

### Test Files (3 files, 280 LOC)
```
daemon_tests.rs            155 LOC  Config, IP detection, peer registry tests
handoff_tests.rs            59 LOC  Lock, merge, stale host detection
sync_tests.rs               66 LOC  Change collection, delta frames
```

---

## DASHBOARD/WEB UI (50+ files, 9.2K LOC)

**Root:** `scripts/dashboard_web/`

### Main Application Files
```
index.html                         Main HTML entry point
app.js                      351 LOC Main app initialization, routing
websocket.js                401 LOC WebSocket client, sync protocol
```

### Mesh-Specific UI Modules
```
mesh.js                     116 LOC Mesh topology visualization canvas
mesh-actions.js             190 LOC Peer CRUD operations (create/edit/delete)
mesh-animation.js           213 LOC Mesh animation state machine
mesh-delegate.js            140 LOC Plan delegation workflow UI
mesh-plan-ops.js            354 LOC Plan execution, status tracking, workflow
mesh-preflight.js           240 LOC Preflight checks UI, validation
peer-crud.js                244 LOC Peer form, SSH checks, discovery
```

### Brain/Intelligence UI Modules
```
brain-canvas.js             899 LOC Neural network visualization (largest)
brain-consciousness.js      227 LOC Brain consciousness/awareness logic
brain-effects.js            203 LOC Visual effects, particle systems
brain-interact.js           242 LOC Brain interaction, click handlers
brain-layout.js             134 LOC Brain layout engine
brain-organism.js           246 LOC Brain region metabolism, state
brain-regions.js            228 LOC Brain region definitions
brain-sessions.js           258 LOC Session history, model statistics
```

### Chat & Communication
```
chat-context.js             206 LOC Chat message context management
chat-monitor.js             170 LOC Chat monitoring, metrics
chat-panel.js               250 LOC Main chat interface
chat-tabs.js                166 LOC Multi-tab chat support
```

### Planning & Task Management
```
idea-jar.js                 209 LOC Idea jar widget
idea-jar-canvas.js          247 LOC Canvas rendering for ideas
idea-jar-physics.js         100 LOC Physics simulation for ideas
mission.js                  204 LOC Mission planning interface
mission-details.js          173 LOC Mission detail view
nightly-jobs.js             256 LOC Job scheduler UI
nightly-jobs-detail.js      198 LOC Job detail and execution view
plan-kanban.js              127 LOC Kanban board for planning
task-pipeline.js             99 LOC Task pipeline visualization
```

### Visualization & Analysis
```
charts.js                     8 LOC Chart rendering utilities
github-panel.js             179 LOC GitHub integration UI
github-activity.js          175 LOC GitHub event tracking
```

### UI/UX Utilities
```
activity.js                 121 LOC Activity tracking
terminal.js                 362 LOC Terminal emulator widget
theme-switcher.js            82 LOC Dark/light theme switching
widget-drag.js              203 LOC Drag-and-drop widget management
kpi.js                       52 LOC KPI display
kpi-modals.js               206 LOC KPI modal dialogs
repo-selector.js            168 LOC Repository selection
icons.js                     28 LOC Icon definitions
formatters.js                53 LOC Data formatting utilities
optimize.js                 122 LOC Performance optimization
utils.js                     11 LOC Utility functions
```

### Configuration & Testing
```
package.json                    Playwright E2E test configuration
playwright.config.ts            Playwright configuration
pyrightconfig.json              Python type checking config
style.css                       Main stylesheet
styles-mission.css              Mission-specific styles
kanban-styles.css               Kanban-specific styles
themes.css                       Theme definitions
css/mesh-2.css                  Mesh visualization styles
css/mesh-3.css                  Mesh visualization styles v3
css/mesh-4.css                  Mesh visualization styles v4
fonts/                          Font files directory
lib/                            Utility modules directory
```

### E2E Test Files (17 spec files)
```
tests/e2e/
├── brain.spec.ts           Brain visualization tests
├── charts.spec.ts          Chart rendering tests
├── dashboard.spec.ts       Dashboard navigation tests
├── full-navigation-audit.spec.ts    Comprehensive navigation audit
├── header-nav.spec.ts      Header navigation tests
├── idea-jar.spec.ts        Idea jar interaction tests
├── kanban.spec.ts          Task board tests
├── kpi-bar.spec.ts         KPI display tests
├── mesh.spec.ts            Mesh sync and delegation tests
├── mission.spec.ts         Mission planning tests
├── nightly-jobs.spec.ts    Job scheduler tests (inferred)
├── plan-actions.spec.ts    Plan execution tests
├── plan-states.spec.ts     Plan state transition tests
├── real-server.spec.ts     Real server integration tests
├── start-dialog.spec.ts    Startup dialog tests
├── terminal.spec.ts        Terminal command tests
└── theme-widgets.spec.ts   Theme and widget tests
    widgets.spec.ts         Widget rendering tests
```

---

## SHELL SCRIPTS (9 active mesh scripts)

**Root:** `scripts/`

### Mesh Management
```
mesh-coordinator.sh         Coordinator node management
mesh-delegate.sh (implied)  Plan delegation
mesh-env-setup.sh          Environment variable setup
mesh-exec.sh               Remote execution wrapper
mesh-health.sh             Health check and status
mesh-heartbeat.sh          Single heartbeat
mesh-heartbeat-daemon.sh   Background heartbeat service
mesh-normalize-hosts.sh    Hostname normalization
mesh-provision-node.sh     Peer setup and initialization
mesh-sync.sh               Main daemon sync orchestrator
```

### Demo/Test
```
demo-hyperworker.sh        Hyperworker simulation
demo-record.mjs            Recording utility
```

### Sync Operations
```
sync-claude-config.sh      Configuration synchronization
```

### Dashboard Support Scripts (in dashboard_web/)
```
scripts/dashboard_web/
├── mesh-actions.js        190 LOC Peer CRUD operations
├── mesh-animation.js      213 LOC Animation state control
├── mesh-plan-ops.js       354 LOC Plan workflow execution
├── mesh-preflight.js      240 LOC Validation checks
└── mesh-delegate.js       140 LOC Delegation workflow
```

### Support Libraries
```
scripts/lib/
├── sync-dashboard-db-ops.sh          Database sync operations
└── sync-to-myconvergio-ops.sh        Remote sync operations
```

### Legacy/Archived (in scripts/archive/legacy-sync/)
```
mesh-notify.sh, mesh-migrate-db.sh, mesh-claude-login.sh
mesh-load-query.sh, mesh-migrate.sh, mesh-env-tools.sh
mesh-db-sync-tasks.sh, mesh-dispatcher.sh, mesh-migrate-sync.sh
mesh-discover.sh, mesh-auth-sync.sh, mesh-preflight.sh
sync-dashboard-db.sh, mesh-sync-config.sh, mesh-sync-all.sh
sync-to-myconvergio.sh, mesh-cleanup.sh, sync-dashboard-db-multi.sh
mesh-scoring.sh, sync-dashboard-db-ops.sh
(20+ legacy scripts)
```

---

## CONFIGURATION FILES (10 files)

**Root:** `config/`

### Peer & Network
```
peers.conf                  Peer registry (INI format, Tailscale auto-discovered)
peers.conf.example          Example peer configuration
repos.conf                  Repository registry
```

### Sync & DB
```
sync-db.conf               Database sync configuration
notifications.conf        Notification routing
mirrorbuddy-nightly.conf   Nightly sync configuration
mirrorbuddy-nightly.conf.example   Example config
```

### Workflows & Models
```
orchestrator.yaml          Workflow orchestration (YAML)
agent-profiles.yaml        Agent capability profiles (YAML)
models.yaml                Model registry and routing (YAML)
cross-repo-learnings.yaml  Learning pattern configuration (YAML)
```

### Environment
**Root:** `~/.claude/`
```
.env.example              Environment variables template
  - DASHBOARD_URL (default: http://localhost:31415)
  - DASHBOARD_API (default: http://localhost:31415/api)
  - GRAFANA_URL, GRAFANA_API_KEY
  - GitHub, Vercel, Supabase auto-discovery
```

---

## DATABASE SCHEMA

**Location:** `/Users/roberdan/.claude/data/dashboard.db`
**Type:** SQLite 3 with CRSQLite (CRDT) extension

### Mesh-Specific Tables
```
mesh_sync_stats            Sync statistics per peer (PRIMARY)
  - peer_name (PK)
  - total_sent, total_received, total_applied (counts)
  - last_sent_at, last_sync_at (timestamps)
  - last_latency_ms (round-trip time)
  - last_db_version (remote DB version)
  - last_error (error message)

mesh_events                Mesh topology events (PRIMARY)
  - event_type, node, timestamp
  - payload (JSON)

peer_heartbeats            Peer availability (PRIMARY)
  - peer_name
  - last_seen (timestamp)
```

### CRSQLite Support Tables (for each main table)
```
table_name__crsql_clock    Clock tracking
table_name__crsql_pks      Primary key shadows
```

### Total Count
```
Core Tables:      ~100 (all CRDT-enabled)
CRSQLite Tables:  ~100+ (shadows and metadata)
Views:            ~15 (analytics views)
Total Tables:     200+
```

---

## INVENTORY SUMMARY

| Category | Count | Details |
|----------|-------|---------|
| **Rust Files** | 12 | daemon.rs, sync.rs, handoff.rs, net.rs, ws.rs (core) |
| **Rust Tests** | 3 | daemon_tests.rs, handoff_tests.rs, sync_tests.rs |
| **Dashboard JS/TS** | ~50 | mesh.js, app.js, brain-canvas.js, websocket.js, etc. |
| **E2E Specs** | 17 | mesh.spec.ts, brain.spec.ts, plan-actions.spec.ts, etc. |
| **Active Scripts** | 9 | mesh-*.sh (in scripts/) |
| **Demo Scripts** | 2 | demo-hyperworker.sh, demo-record.mjs |
| **Config Files** | 10 | peers.conf, orchestrator.yaml, .env.example, etc. |
| **DB Tables** | 100+ | All CRDT-enabled (CRSQLite) |
| **Mesh Tables** | 3 | mesh_sync_stats, mesh_events, peer_heartbeats |
| **API Endpoints** | 20+ | REST + WebSocket (/ws/brain) |
| **Peers Connected** | 3 | m3max (coordinator), omarchy, m1mario |

---

## QUICK PATH REFERENCE

### Rust Daemon Entry Point
```
rust/claude-core/src/mesh/daemon.rs:47
pub async fn run_service(config: DaemonConfig) -> Result<(), String>
```

### Sync Engine Core
```
rust/claude-core/src/mesh/sync.rs:44-100
pub fn collect_changes_since()
pub fn apply_delta_frame()
pub fn current_db_version()
```

### Dashboard Entry Point
```
scripts/dashboard_web/index.html
scripts/dashboard_web/app.js:1-50
```

### Mesh UI Components
```
scripts/dashboard_web/mesh.js              (Visualization)
scripts/dashboard_web/peer-crud.js         (Peer management)
scripts/dashboard_web/mesh-plan-ops.js     (Plan workflows)
```

### WebSocket Protocol
```
scripts/dashboard_web/websocket.js         (Client)
rust/claude-core/src/mesh/daemon_sync.rs   (Server)
```

### Peer Registry
```
config/peers.conf                          (3 active peers)
```

### Database
```
data/dashboard.db                          (SQLite + CRSQLite)
```

### Tests
```
Rust: rust/claude-core/src/mesh/*_tests.rs
E2E:  scripts/dashboard_web/tests/e2e/*.spec.ts
```

---

## DEPENDENCIES (Key)

### Rust (Cargo.toml)
```
tokio            - Async runtime
rusqlite         - SQLite wrapper
rmp-serde        - MessagePack serialization
serde_json       - JSON serialization
axum             - Web framework (WS)
socket2          - Socket tuning
ssh2             - SSH operations
base64           - Encoding
```

### JavaScript (package.json)
```
@playwright/test - E2E testing framework
(Vanilla JS, no build step)
```

---

## CRITICAL FILES FOR PLANNING

For 28 requirements across 7 phases:

| Phase | Critical Files |
|-------|-----------------|
| **1-2: Foundation** | daemon.rs, net.rs, peers.conf, daemon_tests.rs |
| **3-4: Sync Engine** | sync.rs, sync_batch.rs, sync_tests.rs, mesh_sync_stats table |
| **5-6: Delegation** | handoff.rs, handoff_ssh.rs, handoff_tests.rs, delegation_log table |
| **7: UI & Monitoring** | mesh.js, mesh-actions.js, websocket.js, E2E specs |
