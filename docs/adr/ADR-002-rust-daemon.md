# ADR-002: Rust for Mesh Daemon

## Status
Accepted

## Context
The daemon requires high concurrency, long-lived network connections, low runtime overhead, and safety under constant replication and API traffic.

## Decision
Implement the mesh daemon in Rust using async runtime (`tokio`) and typed protocol handling. Keep the daemon as a single binary (`claude-core`) with embedded HTTP and mesh services.

## Consequences
- Memory safety and strong compile-time guarantees for networking code.
- Predictable performance under concurrent workloads.
- Single deployment artifact per node.
- Higher implementation complexity and steeper learning curve than scripting alternatives.
