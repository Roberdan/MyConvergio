# Convergio Mesh AI — ROADMAP

> Living document. Items move to plans when scheduled. Updated: 10 March 2026.

## Legend

| Symbol | Meaning |
|--------|---------|
| ✅ | Done |
| 🔨 | In prompt-011 plan (28 requirements) |
| 🔮 | Future — not in current plan |
| ⚡ | Quick win (<1 day) |
| 🏗️ | Major effort (1+ week) |

---

## Phase 0: Foundation (DONE)

| # | Item | Status |
|---|------|--------|
| 0.1 | 3-node Tailscale mesh (m3max, omarchy, m1mario) | ✅ |
| 0.2 | Rust mesh daemon with WebSocket peer connections | ✅ |
| 0.3 | crsqlite CRR migration — 42 tables | ✅ |
| 0.4 | CRDT row-level replication (serde_bytes fix) | ✅ |
| 0.5 | Bidirectional sync verified (50/50 stress test) | ✅ |
| 0.6 | Dashboard with brain visualization | ✅ |
| 0.7 | Daemon launchd/systemd auto-start | ✅ |
| 0.8 | macOS fd limit fix (8192/65536) | ✅ |

## Phase 1: Stability & Resilience (prompt-011 P0/P1)

| # | Item | Req | Status |
|---|------|-----|--------|
| 1.1 | Anti-entropy / catch-up protocol | F-02 | 🔨 |
| 1.2 | Per-peer version tracking (crsql_tracked_peers) | F-02 | 🔨 |
| 1.3 | Version exchange on reconnect | F-02 | 🔨 |
| 1.4 | Pull-based catch-up for missed changes | F-02 | 🔨 |
| 1.5 | Node failure handling (1/2/3 down) | F-14 | 🔨 |
| 1.6 | Persistent apply connection pool | F-04 | 🔨 |
| 1.7 | Fix m1mario task discrepancy (5127→5130) | F-25 | 🔨 |
| 1.8 | Replication latency <2s guaranteed | F-15 | 🔨 |
| 1.9 | DB index optimization on CRR tables | F-15 | 🔨 |
| 1.10 | Fix total_sent stat (RecordSent count:0) | F-26 | 🔨 |

## Phase 2: File Sync & Daemon Control Plane (prompt-011 P1)

| # | Item | Req | Status |
|---|------|-----|--------|
| 2.1 | rsync-based file sync (replace git mesh-sync.sh) | F-05 | 🔨 |
| 2.2 | Sync .env, configs, scripts, non-git assets | F-05 | 🔨 |
| 2.3 | Delta-only transfers (rsync --checksum) | F-05 | 🔨 |
| 2.4 | Daemon as single control plane | F-24 | 🔨 |
| 2.5 | Daemon orchestrates: replication + file sync + monitoring + scheduling | F-24 | 🔨 |

## Phase 3: Observability Stack (prompt-011 P1)

| # | Item | Req | Status |
|---|------|-----|--------|
| 3.1 | OpenTelemetry integration in Rust daemon | F-10 | 🔨 |
| 3.2 | Structured logging with levels + rotation | F-07 | 🔨 |
| 3.3 | Log aggregation from all nodes | F-07 | 🔨 |
| 3.4 | Real-time monitoring: CPU/mem/disk/net/replication | F-08 | 🔨 |
| 3.5 | Distributed tracing for replication events | F-09 | 🔨 |
| 3.6 | Telemetry spans for sync/task/peer operations | F-10 | 🔨 |
| 3.7 | Metrics export API (daemon → dashboard) | F-08 | 🔨 |

## Phase 4: Admin Console (prompt-011 P1)

| # | Item | Req | Status |
|---|------|-----|--------|
| 4.1 | /admin route in Vanilla JS dashboard dashboard | F-06,F-27 | 🔨 |
| 4.2 | Node management (list, status, restart daemon) | F-06 | 🔨 |
| 4.3 | Plan overview (all plans, progress, cross-node) | F-06 | 🔨 |
| 4.4 | Log viewer (aggregated, filterable) | F-07 | 🔨 |
| 4.5 | Monitoring dashboard (metrics, graphs, alerts) | F-08 | 🔨 |
| 4.6 | Tracing view (distributed request flow) | F-09 | 🔨 |
| 4.7 | Consistent UI with existing dashboard | F-11 | 🔨 |
| 4.8 | Every API has corresponding UI component | F-11 | 🔨 |

## Phase 5: Distributed Intelligence (prompt-011 P2)

| # | Item | Req | Status |
|---|------|-----|--------|
| 5.1 | Gossip protocol (SWIM-based, O(log n)) | F-16 | 🔨 |
| 5.2 | Auto-switch: full-mesh ≤5 nodes, gossip >5 | F-16 | 🔨 |
| 5.3 | Native distributed LLM: capability discovery per node | F-17 | 🔨 |
| 5.4 | Model registry (claude/copilot/ollama per node) | F-17 | 🔨 |
| 5.5 | Capability-aware task routing | F-17,F-19 | 🔨 |
| 5.6 | Dynamic task scheduler (round-robin + load-balance) | F-19 | 🔨 |
| 5.7 | Docker sandbox for guest nodes | F-18 | 🔨 |
| 5.8 | Tailscale auto-join for sandbox containers | F-18 | 🔨 |
| 5.9 | Automatic failover when specialized node offline | F-28 | 🔨 |
| 5.10 | Per-node budget/cost tracking | F-20 | 🔨 |
| 5.11 | Night-mode idle scheduler | F-21 | 🔨 |

## Phase 6: Testing & Quality (prompt-011 P0)

| # | Item | Req | Status |
|---|------|-----|--------|
| 6.1 | Unit tests for all new Rust code | F-12 | 🔨 |
| 6.2 | Integration tests (multi-node simulation) | F-12 | 🔨 |
| 6.3 | Mesh resilience tests (kill/restart scenarios) | F-14 | 🔨 |
| 6.4 | Stress tests (1000+ rapid inserts) | F-12 | 🔨 |
| 6.5 | UI component tests | F-12 | 🔨 |
| 6.6 | Continuous dashboard monitoring during dev | F-13 | 🔨 |

## Phase 7: Documentation & Demo (prompt-011 P1)

| # | Item | Req | Status |
|---|------|-----|--------|
| 7.1 | Architecture documentation (mesh protocol spec) | F-22 | 🔨 |
| 7.2 | Admin guide | F-22 | 🔨 |
| 7.3 | Deployment guide (new node onboarding) | F-22 | 🔨 |
| 7.4 | API documentation | F-22 | 🔨 |
| 7.5 | Playwright automated demo | F-23 | 🔨 |
| 7.6 | Live demo script | F-23 | 🔨 |
| 7.7 | Demo saved to ~/Downloads/ConvergioDemo/ | F-23 | 🔨 |

---

## FUTURE (not in prompt-011)

### Compute Scaling
| # | Item | Notes |
|---|------|-------|
| F.1 | VM provisioning on demand | User said "un domani". Spin up cloud VMs when mesh needs more compute |
| F.2 | Heterogeneous GPU support | Route inference to nodes with GPU (CUDA/Metal/ROCm) |
| F.3 | Model sharding across nodes | Split large models (70B+) across multiple nodes' RAM |
| F.4 | Prefill/decode disaggregation | Separate prompt processing from token generation (like llm-d) |
| F.5 | KV-cache sharing across nodes | Avoid redundant prompt processing for similar requests |

### Network & Protocol
| # | Item | Notes |
|---|------|-------|
| F.6 | QUIC transport (replace TCP WebSocket) | Lower latency, better multiplexing, built-in encryption |
| F.7 | mTLS between peers | End-to-end encryption beyond Tailscale's WireGuard |
| F.8 | Merkle tree anti-entropy | Efficient set reconciliation for large divergence |
| F.9 | Causal consistency guarantees | Vector clocks for happens-before ordering |
| F.10 | Conflict-free merge policies per table | Configurable: LWW, counter, set union, custom |

### Platform
| # | Item | Notes |
|---|------|-------|
| F.11 | Windows node support | WSL2 or native Windows daemon |
| F.12 | ARM64 Linux (Raspberry Pi cluster) | Cheap compute nodes for the mesh |
| F.13 | Mobile node (iPad as viewer) | Read-only dashboard access from mobile |
| F.14 | Web-based terminal to any node | SSH-over-WebSocket in admin console |
| F.15 | Plugin system for custom schedulers | User-defined scheduling policies |

### Intelligence
| # | Item | Notes |
|---|------|-------|
| F.16 | Auto-tuning: learn optimal task→node routing | ML-based routing from historical performance data |
| F.17 | Predictive scaling | Anticipate load spikes, pre-warm nodes |
| F.18 | Code review mesh | Distribute code reviews across specialized nodes |
| F.19 | Multi-model consensus | Run same task on 2+ models, merge results |
| F.20 | Fine-tuned local models per domain | Train specialized LoRA adapters per project |

### Operations
| # | Item | Notes |
|---|------|-------|
| F.21 | Automated backup to S3/B2 | Offsite backup of dashboard.db + configs |
| F.22 | Canary deployments | Roll new daemon version to 1 node first |
| F.23 | Configuration drift detection | Alert when node configs diverge |
| F.24 | SLA monitoring & alerting | Page when replication lag exceeds threshold |
| F.25 | Audit trail | Immutable log of all admin actions |

---

## Architecture Principles

1. **Daemon is the control plane** — all mesh operations through one binary
2. **CRDT-first** — no coordination needed, eventual consistency by default
3. **Gossip for scale** — O(log n) propagation, not O(n²) connections
4. **Capability-aware** — route tasks to the right node, failover to any capable node
5. **Budget-conscious** — track costs per model/node, respect limits
6. **Observable** — OpenTelemetry from daemon to dashboard, full distributed tracing
7. **Resilient** — any node can go down, system continues, catch-up on rejoin
8. **Secure** — Tailscale WireGuard + Docker isolation for guest nodes

## Technology Stack

| Layer | Current | Target |
|-------|---------|--------|
| Transport | TCP WebSocket | TCP WS + gossip (SWIM) |
| Replication | crsqlite CRDT push | CRDT push + anti-entropy pull |
| File sync | git (broken for .env) | rsync delta |
| Monitoring | Basic heartbeat | OpenTelemetry + structured logs |
| Dashboard | Vanilla JS dashboard + brain viz | + admin console + tracing UI |
| Sandbox | None | Docker + Tailscale |
| Scheduling | Manual (coordinator only) | Dynamic capability-aware |
| Inference | Per-node manual | Distributed mesh-native |

## References

- [Exo](https://github.com/exo-explore/exo) — P2P distributed LLM inference
- [Corrosion](https://github.com/superfly/corrosion) — Gossip CRDT for SQLite (Fly.io, 800+ nodes)
- [llm-d](https://github.com/llm-d/llm-d) — Kubernetes-native distributed inference
- [SWIM protocol](https://www.cs.cornell.edu/projects/Quicksilver/public_pdfs/SWIM.pdf) — Scalable membership
- [crsqlite](https://github.com/vlcn-io/cr-sqlite) — CRDT extension for SQLite
