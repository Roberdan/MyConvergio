# MESH SYSTEM - QUICK REFERENCE

## File Locations

### Rust Daemon (1,765 LOC)
- **Source:** `rust/claude-core/src/mesh/`
- **Files:** 12 modules (.rs files)
- **Key:** daemon.rs (277 LOC), sync.rs (341 LOC), handoff.rs (208 LOC)
- **Tests:** daemon_tests.rs, handoff_tests.rs, sync_tests.rs

### Dashboard Web (9.2K LOC)
- **Location:** `scripts/dashboard_web/`
- **Files:** ~50 JS files, 17 E2E test specs
- **Entry:** index.html + app.js (351 LOC)
- **Mesh UI:** mesh.js, mesh-actions.js, mesh-plan-ops.js, peer-crud.js

### Scripts (9 active)
- **Location:** `scripts/`
- **Main:** mesh-sync.sh, mesh-coordinator.sh, mesh-health.sh, mesh-exec.sh
- **Others:** mesh-provision-node.sh, mesh-heartbeat-daemon.sh, mesh-env-setup.sh

### Configuration
- **Peers:** `config/peers.conf` (3 active peers)
- **Env:** `.env.example` (dashboard, grafana URLs)
- **Other:** orchestrator.yaml, sync-db.conf, notifications.conf

### Database
- **Location:** `data/dashboard.db` (SQLite + CRSQLite)
- **Mesh Tables:** mesh_sync_stats, mesh_events, peer_heartbeats
- **Total Tables:** 100+ (all CRDT-enabled)

## Key Structs & Types

### DaemonConfig
```rust
bind_ip: String
port: u16
peers_conf_path: PathBuf
db_path: PathBuf
crsqlite_path: Option<String>
```

### MeshSyncFrame (Protocol)
```rust
Heartbeat { node: String, ts: u64 }
Delta { node: String, sent_at_ms: u64, last_db_version: i64, changes: Vec<DeltaChange> }
Ack { node: String, applied: usize, latency_ms: u64, last_db_version: i64 }
```

### DeltaChange (CRDT)
```rust
table_name: String
pk: Vec<u8>              // Primary key bytes
cid: String              // Column ID
val: Option<String>      // Value
col_version: i64         // Column version
db_version: i64          // DB version clock
site_id: Vec<u8>         // Origin site/peer
cl: i64                  // Causality
seq: i64                 // Sequence number
```

## Core Functions

### Daemon (`daemon.rs`)
- `run_service(config)` - Main entry point
- `detect_tailscale_ip()` - Auto-detect local IP
- `read_peers_conf(path)` - Parse peer registry

### Sync (`sync.rs`)
- `collect_changes_since(db_path, last_version, ext)` - Get local changes
- `apply_delta_frame(db_path, ext, node, sent_at, changes)` - Apply remote changes
- `current_db_version(db_path, ext)` - Get DB version
- `record_sent_stats(db_path, ext, peer, count, version)` - Track sent

### Handoff (`handoff.rs`)
- `acquire_lock(lock_dir, plan_id, peer, ttl)` - Lock plan for delegation
- `release_lock(lock_dir, plan_id)` - Release plan lock
- `detect_sync_source(target, ssh_target, hostname, exec_host, worktree, ...)` - Find sync source
- `merge_plan_status(plan_id, local_db, remote_db)` - Merge plan status

### Network (`net.rs`)
- `load_tailscale_peer_ips()` - Get all Tailscale IPs
- `prefer_tailscale_peer_addr(peer, lookup)` - Use Tailscale IP if available
- `apply_socket_tuning(stream)` - Apply TCP tuning

## API Endpoints

### WebSocket
- `WS /ws/brain` - Real-time mesh sync

### REST (implied from dashboard)
- `GET /api/peers` - List peers
- `POST /api/peers` - Create peer
- `PUT /api/peers/{name}` - Update peer
- `DELETE /api/peers/{name}` - Delete peer
- `POST /api/peers/{name}/check` - Check SSH reachability
- `GET /api/mesh/health` - Mesh health status
- `GET /api/mesh/sync-stats` - Sync statistics per peer
- `POST /api/plans/{id}/delegate` - Delegate plan to peer

## Sync Protocol

### Heartbeat Loop (both directions)
- Sent every N seconds
- Updates peer_heartbeats table
- Contains node ID and timestamp

### Delta Loop (outbound only)
- Triggered by database changes
- Reads CRSQLite changelog
- Sends MeshSyncFrame::Delta with changes
- Waits for Ack response
- Updates mesh_sync_stats

### Ack Loop (both directions)
- Confirms delta receipt
- Records latency and applied count
- Updates last_sync_at timestamp

## Peer Registry (peers.conf)

### m3max (Coordinator)
```
ssh_alias: robertos-macbook-pro-m3-max.tail01f12c.ts.net
user: roberdan
os: macos
tailscale_ip: 100.98.147.10
role: coordinator
capabilities: claude, copilot, ollama
```

### omarchy (Worker)
```
ssh_alias: omarchy-ts
user: roberdan
os: linux
tailscale_ip: 100.127.138.62
role: worker
capabilities: claude, copilot
mac_address: 9c:b6:d0:e9:68:07
```

### m1mario (Worker)
```
ssh_alias: mac-dev-ts
user: mariodan
os: macos
tailscale_ip: 100.106.173.118
role: worker
capabilities: claude, copilot
mac_address: 5e:01:96:63:23:b6
runners: 3
```

## Database Schema

### mesh_sync_stats
Tracks sync statistics per peer:
- peer_name (PRIMARY KEY)
- total_sent, total_received, total_applied (change counts)
- last_sent_at, last_sync_at (timestamps)
- last_latency_ms (round trip latency)
- last_db_version (version of remote DB)
- last_error (error message if failed)

### mesh_events
Event log for mesh topology changes:
- event_type, node, timestamp
- payload (JSON)

### peer_heartbeats
Peer availability tracking:
- peer_name
- last_seen (timestamp)

## Technology Stack

| Component | Tech |
|-----------|------|
| Backend | Rust + Tokio |
| Protocol | MessagePack (binary), JSON (config) |
| Database | SQLite + CRSQLite (CRDT) |
| Network | Tailscale + TCP sockets |
| Frontend | Vanilla JavaScript + Canvas |
| Testing | Playwright (E2E), Rust #[test] |
| Serialization | rmp-serde, serde_json |

## Build & Run

### Compile Daemon
```bash
cd rust/claude-core
cargo build --release --features crsqlite
```

### Run Tests
```bash
# Rust tests
cargo test --lib mesh

# E2E tests
cd scripts/dashboard_web
npm test
```

## Key Constants

- **WS_BRAIN_ROUTE:** "/ws/brain" (WebSocket endpoint)
- **MAX_FRAME_BYTES:** 16 MB (frame size limit)
- **HEARTBEAT_INTERVAL:** ~10 seconds
- **HEARTBEAT_PRUNE:** 300 seconds (5 minutes)
- **HEARTBEAT_CHECK:** 60 seconds (cleanup interval)
- **DEFAULT_PORT:** (from DaemonConfig)
- **DEFAULT_BIND_IP:** (from DaemonConfig)

## Sync Flow Diagram

```
Peer A (Outbound)         Network              Peer B (Inbound)
┌─────────────────┐                          ┌─────────────────┐
│ Collect changes │                          │ Listen for      │
│ from CRSQLite   │                          │ frames          │
└────────┬────────┘                          └────────┬────────┘
         │                                            │
         │  Heartbeat { ts: now }                     │
         ├───────────────────────────────────────────>│
         │                                    Record in
         │                                    peer_heartbeats
         │
         │  Delta { changes: [...] }                  │
         ├───────────────────────────────────────────>│
         │                                    Apply changes
         │                                    to local DB
         │                          Ack { applied: N }│
         │<───────────────────────────────────────────┤
         │
      Record stats in
      mesh_sync_stats
      (sent_at, latency_ms,
       last_db_version)
```

## Debugging

### Check Peer Connectivity
```bash
./scripts/mesh-health.sh
```

### View Sync Stats
```bash
sqlite3 data/dashboard.db "SELECT * FROM mesh_sync_stats;"
```

### Check Tailscale Network
```bash
tailscale status
```

### View Mesh Events
```bash
sqlite3 data/dashboard.db "SELECT * FROM mesh_events ORDER BY timestamp DESC LIMIT 10;"
```

---

## Phase Planning Reference

For your 28-requirement 7-phase plan, these are the critical component groups:

**Phase 1-2:** Foundation (Daemon setup, peer discovery, heartbeat)
- Uses: daemon.rs, net.rs, peers.conf

**Phase 3-4:** Sync Engine (CRDT, delta collection/application)
- Uses: sync.rs, sync_batch.rs, mesh_sync_stats table

**Phase 5-6:** Lock Management & Handoff (Plan delegation)
- Uses: handoff.rs, handoff_ssh.rs, delegation_log table

**Phase 7:** Dashboard & Monitoring
- Uses: mesh.js, mesh-actions.js, websocket.js, E2E tests

