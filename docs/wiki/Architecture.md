# Architecture

## High-level design

Convergio Mesh is a distributed daemon architecture built around `claude-core`:

1. **TCP Mesh Daemon (`:9420`)**  
   Handles peer-to-peer transport, heartbeat exchange, delta replication, and authentication.
2. **CRDT Replication Layer (`crsqlite`)**  
   Uses CRDT change sets (`crsql_changes`) for conflict-tolerant multi-node synchronization.
3. **HTTP API (`:9421`)**  
   Exposes health, status, metrics, sync stats, and logs.
4. **WebSocket Brain Visualization (`/ws/brain`)**  
   Streams mesh events for real-time dashboard visualization.

## Replication model

- **Gossip/SWIM-lite membership** tracks alive/suspect/dead nodes.
- **Anti-entropy startup cursor** resumes replication from peer-known `last_db_version`.
- **Delta frame batching** sends CRDT changes in windows to reduce overhead.
- **Allowlist-based apply** only accepts updates for CRDT-tracked tables.

## Node topology

- **m3max**: coordinator and primary operations node
- **omarchy**: Linux worker peer
- **m1mario**: macOS worker peer

All traffic is intended for the Tailscale private network.
