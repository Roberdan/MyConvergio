# COMPREHENSIVE MESH SYSTEM CODEBASE MAP
Generated: 2026-03-02
Location: ~/.claude

---

## 1. RUST DAEMON CODE: `rust/claude-core/src/mesh/`

**Total Lines: 1,765 LOC** across 12 Rust modules

### Core Modules (by size):

| File | Lines | Purpose |
|------|-------|---------|
| **sync.rs** | 341 | Delta-based CRDT sync engine (core change collection/application) |
| **daemon_sync.rs** | 291 | Socket handling, frame processing, peer heartbeats |
| **daemon.rs** | 277 | Main daemon loop, config, peer connection management |
| **handoff.rs** | 208 | Lock acquisition, plan status merge, sync source detection |
| **net.rs** | 112 | Tailscale IP lookup, socket tuning, network preferences |
| **ws.rs** | 136 | WebSocket handshake, frame encoding |
| **handoff_ssh.rs** | 84 | SSH command execution for remote sync |
| **sync_batch.rs** | 31 | Batch window utilities for throttled sync |
| **mod.rs** | 5 | Module declarations |

### Test Files:
- **daemon_tests.rs** (155 LOC) - daemon config, peer detection tests
- **handoff_tests.rs** (59 LOC) - lock, merge, stale host detection tests
- **sync_tests.rs** (66 LOC) - change collection and delta frame tests

### Key Structs:

```rust
// Daemon
pub struct DaemonConfig {
    pub bind_ip: String,
    pub port: u16,
    pub peers_conf_path: PathBuf,
    pub db_path: PathBuf,
    pub crsqlite_path: Option<String>,
}

pub struct DaemonState {
    pub node_id: String,
    pub tx: broadcast::Sender<MeshEvent>,
    pub heartbeats: Arc<RwLock<HashMap<String, u64>>>,
}

// Sync Protocol
pub enum MeshSyncFrame {
    Heartbeat { node: String, ts: u64 },
    Delta { node: String, sent_at_ms: u64, last_db_version: i64, changes: Vec<DeltaChange> },
    Ack { node: String, applied: usize, latency_ms: u64, last_db_version: i64 },
}

pub struct DeltaChange {
    pub table_name: String,
    pub pk: Vec<u8>,
    pub cid: String,
    pub val: Option<String>,
    pub col_version: i64,
    pub db_version: i64,
    pub site_id: Vec<u8>,
    pub cl: i64,
    pub seq: i64,
}

// Handoff/Lock Management
pub struct PeerConfig {
    pub peer_name: String,
    pub ssh_alias: Option<String>,
    pub dns_name: Option<String>,
}

pub struct SyncSourceInfo {
    pub source: String,
    pub ssh_source: Option<String>,
    pub ssh_target: String,
    pub worktree: String,
    pub needs_stop: bool,
    pub needs_stash: bool,
}

pub struct StaleHostStatus {
    pub stale: bool,
    pub reason: String,
    pub can_recover: bool,
}
```

### Key Public Functions:

**Daemon:**
- `pub async fn run_service(config)` - Main daemon entry point
- `pub fn detect_tailscale_ip() -> Option<String>` - Auto-detect local IP
- `fn read_peers_conf(path) -> Vec<String>` - Parse peers.conf

**Sync (CRDT):**
- `pub fn collect_changes_since()` - Collect local changes
- `pub fn current_db_version()` - Get current DB version
- `pub fn apply_delta_frame()` - Apply remote changes
- `pub fn record_sent_stats()` - Track sent changes
- `pub fn record_sync_error()` - Log sync errors
- `pub fn open_persistent_sync_conn()` - Create sync connection
- `pub fn ensure_sync_schema_pub()` - Initialize CRDT tables

**Handoff (Lock Management):**
- `pub fn parse_peers_conf()` - Parse peer registry
- `pub fn detect_sync_source()` - Determine sync source
- `pub fn check_stale_host()` - Check host staleness
- `pub fn acquire_lock()` - Acquire delegation lock
- `pub fn release_lock()` - Release delegation lock
- `pub fn merge_plan_status()` - Merge plan from remote

**Network:**
- `pub fn mesh_socket_tuning()` - Get TCP tuning parameters
- `pub fn apply_socket_tuning()` - Apply tuning to socket
- `pub fn load_tailscale_peer_ips()` - Load Tailscale IPs
- `pub fn prefer_tailscale_peer_addr()` - Prefer Tailscale IP

**WebSocket:**
- `pub fn websocket_accept()` - Generate accept header
- `pub fn text_frame()` - Encode WebSocket text frame

---

## 2. DASHBOARD/UI CODE: `scripts/dashboard_web/`

**Total Files:** ~50 JS/TS files (~9.2K LOC, excluding node_modules)
**Test Framework:** Playwright E2E (17 spec files)
**Type:** Vanilla JavaScript + HTML5 Canvas (NOT Next.js app router)

### Directory Structure:
```
scripts/dashboard_web/
├── index.html                          # Main entry point
├── app.js                              # App init (351 LOC)
├── Mesh-related:
│   ├── mesh.js                         # Visualization (116 LOC)
│   ├── mesh-actions.js                 # Operations (190 LOC)
│   ├── mesh-animation.js               # State mgmt (213 LOC)
│   ├── mesh-delegate.js                # Delegation (140 LOC)
│   ├── mesh-plan-ops.js                # Workflows (354 LOC)
│   ├── mesh-preflight.js               # Validation (240 LOC)
│   └── peer-crud.js                    # Peer mgmt (244 LOC)
├── Brain-related:
│   ├── brain-canvas.js                 # Topology (899 LOC)
│   ├── brain-*.js                      # (8 files, ~1.8K LOC)
│   └── brain-organism.js, brain-effects.js, etc.
├── Chat & Communication:
│   ├── chat-panel.js, chat-tabs.js, chat-monitor.js
│   ├── chat-context.js, websocket.js
├── Planning & Tasks:
│   ├── mission.js, mission-details.js
│   ├── plan-kanban.js, nightly-jobs.js
│   ├── task-pipeline.js
├── Ideas & Creativity:
│   ├── idea-jar.js, idea-jar-canvas.js, idea-jar-physics.js
├── Visualization:
│   ├── org-chart.js, charts.js
│   ├── github-panel.js, github-activity.js
├── UI/UX:
│   ├── theme-switcher.js, widget-drag.js
│   ├── terminal.js, activity.js
│   ├── kpi.js, kpi-modals.js
├── tests/e2e/
│   ├── mesh.spec.ts
│   ├── dashboard.spec.ts, brain.spec.ts
│   ├── plan-actions.spec.ts, plan-states.spec.ts
│   └── 12 more spec files
├── css/
│   ├── mesh-*.css (visualization styles)
│   └── kanban-styles.css, themes.css, style.css
├── lib/
├── fonts/
└── package.json                        # Playwright test config
```

### Main Dashboard Files (>100 LOC):

| File | Lines | Purpose |
|------|-------|---------|
| brain-canvas.js | 899 | Neural network visualization |
| websocket.js | 401 | WebSocket sync client |
| mesh-plan-ops.js | 354 | Plan execution workflows |
| app.js | 351 | App initialization |
| terminal.js | 362 | Terminal emulator |
| nightly-jobs.js | 256 | Job scheduler UI |
| brain-sessions.js | 258 | Session history |
| chat-panel.js | 250 | Chat interface |
| peer-crud.js | 244 | Peer CRUD forms |
| mesh-preflight.js | 240 | Preflight checks |
| brain-interact.js | 242 | Brain interactions |
| brain-organism.js | 246 | Brain metabolism |
| idea-jar-canvas.js | 247 | Physics simulation |
| brain-regions.js | 228 | Brain regions |
| brain-consciousness.js | 227 | Brain consciousness |
| mesh-animation.js | 213 | Animation state |
| brain-effects.js | 203 | Visual effects |
| widget-drag.js | 203 | Drag-and-drop |
| mission.js | 204 | Mission planning |
| mesh-actions.js | 190 | Peer operations |

### E2E Test Coverage (17 specs):
- mesh.spec.ts - Peer CRUD, sync, delegation
- plan-actions.spec.ts - Plan execution
- brain.spec.ts - Brain visualization
- dashboard.spec.ts - Navigation
- terminal.spec.ts - Commands
- (13 additional specs for comprehensive coverage)

---

## 3. SCRIPTS: Mesh-Related Shell Scripts

### Active Mesh Scripts in `scripts/`:

| Script | Purpose |
|--------|---------|
| **mesh-sync.sh** | Main daemon sync orchestrator |
| **mesh-coordinator.sh** | Coordinator node management |
| **mesh-health.sh** | Health check and status reporting |
| **mesh-exec.sh** | Remote execution wrapper |
| **mesh-provision-node.sh** | Peer setup and initialization |
| **mesh-heartbeat-daemon.sh** | Background heartbeat service |
| **mesh-heartbeat.sh** | Single heartbeat send |
| **mesh-env-setup.sh** | Environment configuration |
| **mesh-normalize-hosts.sh** | Hostname normalization |

### Demo/Test Scripts:
- **demo-hyperworker.sh** - Hyperworker simulation
- **demo-record.mjs** - Recording utility

### Dashboard Support Scripts:
- **scripts/dashboard_web/mesh-actions.js** (190 LOC)
- **scripts/dashboard_web/mesh-animation.js** (213 LOC)
- **scripts/dashboard_web/mesh-plan-ops.js** (354 LOC)
- **scripts/dashboard_web/mesh-preflight.js** (240 LOC)
- **scripts/dashboard_web/mesh-delegate.js** (140 LOC)

---

## 4. CONFIGURATION FILES

### Mesh Config in `config/`:

| File | Format | Purpose |
|------|--------|---------|
| **peers.conf** | INI | Peer registry (Tailscale auto-discovered) |
| **orchestrator.yaml** | YAML | Workflow orchestration |
| **sync-db.conf** | Config | Database sync config |
| **notifications.conf** | Config | Notification routing |
| **agent-profiles.yaml** | YAML | Agent capabilities |
| **models.yaml** | YAML | Model registry |
| **cross-repo-learnings.yaml** | YAML | Learning patterns |
| **repos.conf** | Config | Repository registry |

### Environment Files:

**~/.claude/.env.example:**
- DASHBOARD_URL (default: http://localhost:31415)
- DASHBOARD_API (default: http://localhost:31415/api)
- GRAFANA_URL, GRAFANA_API_KEY
- GitHub, Vercel, Supabase auto-discovery

### peers.conf Structure:
```ini
[peer_name]
ssh_alias=hostname.tailscale.net       # Required
user=username                          # Required
os=macos|linux|windows                 # Required
tailscale_ip=100.x.x.x                # Optional
dns_name=hostname.tail.ts.net         # Optional
capabilities=claude,copilot,ollama    # Optional
role=coordinator|worker|hybrid        # Required
status=active|inactive                # Default: active
mac_address=AA:BB:CC:DD:EE:FF        # Optional
gh_account=github_username            # Optional
runners=N                             # Optional
runner_paths=/path/to/runner          # Optional
```

### Current Peers:
1. **m3max** - macOS (coordinator, 100.98.147.10)
2. **omarchy** - Linux (worker, 100.127.138.62)
3. **m1mario** - macOS (worker, 100.106.173.118)

---

## 5. TESTS: Mesh/Daemon/Sync Related

### Rust Unit Tests:

| Test File | LOC | Coverage |
|-----------|-----|----------|
| **daemon_tests.rs** | 155 | Config, IP detection, peer parsing |
| **handoff_tests.rs** | 59 | Lock, merge, stale host |
| **sync_tests.rs** | 66 | Change collection, delta frames |

### E2E/Integration Tests (Playwright):

**In `scripts/dashboard_web/tests/e2e/`:**

| Spec | Focus |
|------|-------|
| mesh.spec.ts | Peer CRUD, sync, delegation |
| plan-actions.spec.ts | Plan execution |
| plan-states.spec.ts | Plan state transitions |
| brain.spec.ts | Brain visualization |
| dashboard.spec.ts | Navigation |
| terminal.spec.ts | Commands |
| kanban.spec.ts | Task board |
| idea-jar.spec.ts | Idea management |
| mission.spec.ts | Mission planning |
| kpi-bar.spec.ts | KPI display |
| widgets.spec.ts | Widget rendering |
| theme-widgets.spec.ts | Theme switching |
| charts.spec.ts | Chart rendering |
| header-nav.spec.ts | Header navigation |
| start-dialog.spec.ts | Startup dialogs |
| real-server.spec.ts | Server integration |
| full-navigation-audit.spec.ts | Full audit |

**Test Runner:** Playwright (npm: @playwright/test ^1.58.2)

---

## 6. DASHBOARD DATABASE SCHEMA

**Location:** `/Users/roberdan/.claude/data/dashboard.db`
**Type:** SQLite + CRSQLite (CRDT extension)

### Mesh-Related Tables:

#### **mesh_sync_stats** (PRIMARY)
```sql
CREATE TABLE "mesh_sync_stats" (
    "peer_name" TEXT PRIMARY KEY NOT NULL,
    "total_sent" INTEGER NOT NULL DEFAULT 0,
    "total_received" INTEGER NOT NULL DEFAULT 0,
    "total_applied" INTEGER NOT NULL DEFAULT 0,
    "last_sent_at" INTEGER,
    "last_sync_at" INTEGER,
    "last_latency_ms" INTEGER,
    "last_db_version" INTEGER NOT NULL DEFAULT 0,
    "last_error" TEXT
);
```

With CRSQLite triggers:
- `__crsql_itrig` (after insert)
- `__crsql_utrig` (after update)
- `__crsql_dtrig` (after delete)
- `__crsql_clock` (timestamp tracking)
- `__crsql_pks` (primary key tracking)

#### **mesh_events**
Mesh event tracking with CRDT replication

#### **peer_heartbeats**
Peer heartbeat history with CRDT replication

### Complete Table Count: 100+ tables
Including: agent_activity, chat_messages, plans, tasks, missions, notifications, and more (all CRDT-enabled)

### Views: 15+ analytics views
Including: v_kanban, v_learning_metrics, v_plan_roi, v_token_stats, v_metrics_latest

---

## 7. API ENDPOINTS: Mesh/Node/Brain/Admin Data

### Dashboard Backend Routes (inferred from code):

**Peer Management:**
- GET /api/peers - List all peers
- POST /api/peers - Create peer
- PUT /api/peers/{name} - Update peer
- DELETE /api/peers/{name} - Delete peer
- POST /api/peers/{name}/check - SSH check
- POST /api/peers/discover - Discover from Tailscale

**Plan Operations:**
- GET /api/plans - List plans
- POST /api/plans/{id}/delegate - Delegate
- GET /api/plans/{id}/status - Get status
- POST /api/plans/{id}/execute - Execute
- PUT /api/plans/{id}/status - Update status

**Mesh Sync:**
- WS /ws/brain - Real-time sync channel
- GET /api/mesh/health - Health status
- GET /api/mesh/peers - Topology
- GET /api/mesh/sync-stats - Statistics
- POST /api/mesh/heartbeat - Heartbeat

**Execution/Terminal:**
- POST /api/exec - Execute command
- WS /ws/terminal - Terminal streaming

**Preflight:**
- POST /api/preflight/check - Run checks
- GET /api/preflight/status - Status

### WebSocket Protocol:
- Heartbeat frames (peer health)
- Delta frames (database changes)
- Ack frames (confirmation)
- Status updates (plan, execution)
- Event messages (topology changes)

---

## ARCHITECTURE OVERVIEW

### Daemon Architecture (Rust):
```
run_service()
  ├─ TcpListener (bind_ip:port)
  ├─ DaemonState (broadcast channel)
  ├─ Peer connection loop (spawned tasks)
  │  └─ connect_peer_loop()
  ├─ Heartbeat prune loop (300s)
  └─ Socket accept loop
     └─ handle_socket()
        ├─ MeshSyncFrame read/write
        ├─ delta_loop (outbound only)
        ├─ heartbeat_loop
        └─ process_frame()
           ├─ Heartbeat → DB record
           ├─ Delta → apply_delta_frame()
           └─ Ack → latency tracking
```

### Sync Protocol:
```
Outbound Loop:
  collect_changes_since(last_db_version)
    → read CRSQLite changelog
    → write_frame(Delta)
    → wait Ack
    → record_sent_stats()

Inbound Loop:
  read_frame()
    → process_frame()
    → Heartbeat: update peer_heartbeats
    → Delta: apply_delta_frame()
    → Ack: record mesh_sync_stats
```

### Dashboard Architecture:
```
index.html + app.js
  ├─ mesh-canvas (visualization)
  ├─ peer-crud (operations)
  ├─ mesh-plan-ops (workflows)
  └─ websocket.js (real-time)
       ↓ (WebSocket /ws/brain)
Daemon (Rust)
       ↓ (sync)
SQLite + CRSQLite Database
```

---

## SUMMARY STATISTICS

| Category | Count | Details |
|----------|-------|---------|
| **Rust Files** | 12 | 1,765 LOC |
| **Rust Tests** | 3 | 280 LOC |
| **Dashboard JS/TS Files** | ~50 | 9.2K LOC |
| **E2E Test Specs** | 17 | Playwright suite |
| **Active Mesh Scripts** | 9 | Shell/JS scripts |
| **Config Files** | 10 | YAML/INI/Config |
| **Database Tables** | 100+ | SQLite + CRSQLite |
| **Mesh-Specific Tables** | 3 | mesh_sync_stats, mesh_events, peer_heartbeats |
| **API Endpoints (implied)** | 20+ | REST + WebSocket |
| **Connected Peers** | 3 | m3max, omarchy, m1mario |

---

## KEY TECHNOLOGIES

**Backend:** Rust (Tokio async, MessagePack, rusqlite, CRSQLite)
**Frontend:** JavaScript/HTML5 Canvas (Playwright E2E, WebSocket)
**Database:** SQLite + CRSQLite CRDT extension
**Network:** Tailscale private mesh, TCP sockets, WebSocket
**Serialization:** MessagePack (binary), JSON (config)
**Testing:** Playwright, Rust #[test]

