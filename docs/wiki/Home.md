# Convergio Mesh Wiki

Convergio Mesh is a distributed AI system implemented by `claude-core` in Rust.  
It runs as a three-node mesh over Tailscale:

- **m3max** (coordinator)
- **omarchy** (worker)
- **m1mario** (worker)

The mesh daemon uses CRDT replication (via `crsqlite`) to synchronize state without a central leader. It also exposes a real-time HTTP/WebSocket surface for health checks, metrics, logs, and brain-style event visualization.

## What this wiki covers

- [Architecture](Architecture.md)
- [Getting Started](Getting-Started.md)
- [Configuration](Configuration.md)
- [API Reference](API-Reference.md)
- [Security](Security.md)
- [Observability](Observability.md)
- [Troubleshooting](Troubleshooting.md)

## Core capabilities

- Peer-to-peer TCP mesh communication on port `9420`
- CRDT anti-entropy synchronization
- HMAC-SHA256 peer authentication
- HTTP API on port `9421`
- WebSocket brain stream (`/ws/brain`)
- In-memory metrics and log aggregation for dashboard integration
