# MESH SYSTEM CODEBASE - COMPLETE MAP & REFERENCE

**Generated:** 2026-03-02  
**Location:** ~/.claude/  
**Total Coverage:** 100+ source files, 11,245+ LOC, 100+ database tables, 20+ API endpoints

---

## 📚 REFERENCE DOCUMENTS

This directory now contains three comprehensive reference documents for planning your 28-requirement mesh system upgrade across 7 phases:

### 1. **MESH_CODEBASE_MAP.md** (15 KB)
**Complete technical reference for architecture and implementation**

Contains:
- ✅ All 12 Rust files (1,765 LOC) with line counts and purposes
- ✅ Complete Rust struct definitions (DaemonConfig, MeshSyncFrame, DeltaChange, etc.)
- ✅ All public functions across 6 modules (daemon, sync, handoff, network, ws)
- ✅ Dashboard UI structure (50+ files, 9.2K LOC)
- ✅ Complete mesh script inventory (9 active scripts)
- ✅ Configuration files (10 config files)
- ✅ Test coverage (3 Rust tests + 17 E2E specs)
- ✅ Database schema details (mesh_sync_stats, mesh_events, peer_heartbeats)
- ✅ API endpoints (20+ REST + WebSocket)
- ✅ Architecture diagrams (daemon loops, sync protocol flow)

**Use for:** Understanding system design, identifying implementation dependencies, API contracts

---

### 2. **MESH_QUICK_REFERENCE.md** (8.1 KB)
**Developer quick-lookup guide for coding and debugging**

Contains:
- ✅ All file locations by category
- ✅ Key structs (DaemonConfig, MeshSyncFrame, DeltaChange)
- ✅ Core functions by module (Daemon, Sync, Handoff, Network)
- ✅ API endpoints summary
- ✅ Complete sync protocol explanation
- ✅ All 3 peer configurations (m3max, omarchy, m1mario)
- ✅ Database schema (mesh_sync_stats details)
- ✅ Technology stack summary
- ✅ Build/run commands
- ✅ Key constants
- ✅ Sync flow diagram
- ✅ Debugging commands
- ✅ Phase planning reference

**Use for:** Quick lookup during implementation, debugging, testing

---

### 3. **MESH_FILES_INVENTORY.md** (13 KB)
**Complete file-by-file inventory with paths and LOC counts**

Contains:
- ✅ All 12 Rust files (categorized: source, tests, locations)
- ✅ All ~50 dashboard JS/TS files (categorized: app, mesh, brain, chat, planning, etc.)
- ✅ All 9 active shell scripts
- ✅ All 10 configuration files
- ✅ All E2E test specs (17 files)
- ✅ Database table listing
- ✅ Inventory summary (101+ files)
- ✅ Quick path reference
- ✅ Dependencies (Rust + JavaScript)
- ✅ Critical files by phase

**Use for:** Navigation, finding specific files, dependency mapping

---

## 🎯 MESH SYSTEM OVERVIEW

### What's Being Mapped

A complete **distributed mesh synchronization system** for Claude ecosystem:

```
3 Peers (Tailscale Network)
  ├─ m3max (macOS Coordinator) - 100.98.147.10
  ├─ omarchy (Linux Worker) - 100.127.138.62
  └─ m1mario (macOS Worker) - 100.106.173.118
       ↓
Rust Daemon (Async Tokio)
  ├─ Socket management (TCP)
  ├─ CRDT sync engine (MessagePack frames)
  ├─ Heartbeat & health monitoring
  ├─ Lock-based plan delegation
  └─ SSH remote execution
       ↓
SQLite + CRSQLite (CRDT Database)
  ├─ mesh_sync_stats (sent/received/applied counts)
  ├─ peer_heartbeats (availability tracking)
  ├─ mesh_events (event log)
  └─ 100+ other tables (all CRDT-enabled)
       ↓
JavaScript Dashboard
  ├─ WebSocket client (/ws/brain)
  ├─ Mesh visualization (D3/Canvas)
  ├─ Peer management (CRUD)
  ├─ Plan delegation workflow
  └─ Real-time sync monitoring
```

### Key Statistics

| Category | Count | Details |
|----------|-------|---------|
| **Rust Modules** | 12 | 1,765 LOC (core + tests) |
| **Dashboard Files** | 50+ | 9.2K LOC JS/TS |
| **Test Files** | 20 | Rust + Playwright E2E |
| **Config Files** | 10 | YAML, INI, Config formats |
| **API Endpoints** | 20+ | REST + WebSocket |
| **Database Tables** | 100+ | SQLite + CRSQLite |
| **Mesh-Specific Tables** | 3 | mesh_sync_stats, mesh_events, peer_heartbeats |
| **Active Peers** | 3 | Via Tailscale private network |
| **Scripts** | 9 | Active mesh management scripts |

---

## 🚀 HOW TO USE THESE DOCUMENTS

### For Architecture Review
→ **Read:** MESH_CODEBASE_MAP.md (Sections 1-3, Architecture Overview)
- Understand daemon architecture
- Learn sync protocol
- Review database schema

### For Implementation Planning
→ **Read:** MESH_QUICK_REFERENCE.md (Phase Planning Reference section)
- Map requirements to modules
- Identify dependencies
- Plan phase rollout

### For Code Navigation
→ **Read:** MESH_FILES_INVENTORY.md (Quick Path Reference section)
- Find specific files
- Check line counts
- Understand directory structure

### For Debugging
→ **Read:** MESH_QUICK_REFERENCE.md (Debugging section)
- Commands to check status
- Database queries
- Tailscale diagnostics

---

## 📋 PLANNING YOUR 28 REQUIREMENTS ACROSS 7 PHASES

### Phase 1-2: Foundation & Peer Discovery
**Files:** daemon.rs, net.rs, peers.conf, daemon_tests.rs  
**Key Functions:**
- `run_service()` - daemon startup
- `detect_tailscale_ip()` - IP detection
- `load_tailscale_peer_ips()` - peer discovery
- `read_peers_conf()` - peer registry parsing

### Phase 3-4: CRDT Sync Engine  
**Files:** sync.rs, sync_batch.rs, sync_tests.rs, mesh_sync_stats table  
**Key Functions:**
- `collect_changes_since()` - change collection
- `apply_delta_frame()` - change application
- `current_db_version()` - version tracking
- `record_sent_stats()` - statistics

### Phase 5-6: Lock Management & Plan Delegation
**Files:** handoff.rs, handoff_ssh.rs, handoff_tests.rs, delegation_log table  
**Key Functions:**
- `acquire_lock()` - lock plan for delegation
- `release_lock()` - release plan
- `detect_sync_source()` - find sync source
- `merge_plan_status()` - merge remote status

### Phase 7: Dashboard & Monitoring
**Files:** mesh.js, mesh-actions.js, mesh-plan-ops.js, websocket.js, E2E specs  
**Key Components:**
- Mesh visualization canvas
- Peer CRUD UI forms
- Plan delegation workflow
- Real-time sync monitoring
- 17 E2E test specs

---

## �� CRITICAL IMPLEMENTATION DETAILS

### Protocol
- **Binary:** MessagePack (rmp-serde) for efficient serialization
- **Frames:** Heartbeat, Delta, Ack (bidirectional)
- **Transport:** TCP + WebSocket
- **Network:** Tailscale (private mesh, IP preference for 100.x.x.x)

### Database
- **Engine:** SQLite with CRSQLite CRDT extension
- **Sync:** Version-based delta application
- **Replication:** Conflict-free via CRDT metadata
- **Tracking:** per-peer stats in mesh_sync_stats

### Async Architecture
- **Runtime:** Tokio multi-threaded executor
- **Concurrency:** One task per peer connection
- **Broadcast:** Message fan-out via broadcast channel
- **Timeouts:** Heartbeat pruning (5-minute stale detection)

---

## 📞 GETTING STARTED

1. **Read MESH_QUICK_REFERENCE.md** (10 minutes)
   - Get familiar with file locations
   - Understand key structs
   - Review sync protocol

2. **Read MESH_CODEBASE_MAP.md** (20 minutes)
   - Deep dive into architecture
   - Review all modules
   - Understand dependencies

3. **Review MESH_FILES_INVENTORY.md** (5 minutes)
   - Locate specific files
   - Check test coverage
   - Verify configuration

4. **Plan your 28 requirements**
   - Map to phase groups (1-2, 3-4, 5-6, 7)
   - Identify file dependencies
   - Use line counts for estimation

5. **Start implementation**
   - Follow phase order
   - Reference specific file:line numbers
   - Use existing tests as templates

---

## 📁 FILE LOCATIONS QUICK INDEX

```
Rust Daemon:     rust/claude-core/src/mesh/
Dashboard:       scripts/dashboard_web/
Scripts:         scripts/
Config:          config/
Database:        data/dashboard.db
Peers:           config/peers.conf
Environment:     .env.example
```

---

## ✅ DELIVERABLES COMPLETED

- [x] All 12 Rust files (daemon, sync, handoff, net, ws) - 1,765 LOC
- [x] All ~50 dashboard JS files - 9.2K LOC
- [x] All 9 active mesh scripts
- [x] All 10 configuration files
- [x] All 20 test files (Rust + E2E)
- [x] Database schema (mesh_sync_stats, peer_heartbeats, mesh_events)
- [x] 20+ API endpoints mapped
- [x] 3 comprehensive reference documents created

**Total Codebase:** 100+ files, 11,245+ LOC, fully documented

---

Generated: 2026-03-02  
Reference Documents: 3 files (36+ KB)  
Status: ✅ COMPLETE

For detailed information, see:
- **MESH_CODEBASE_MAP.md** - Architecture & technical deep dive
- **MESH_QUICK_REFERENCE.md** - Developer quick lookup
- **MESH_FILES_INVENTORY.md** - File-by-file reference

