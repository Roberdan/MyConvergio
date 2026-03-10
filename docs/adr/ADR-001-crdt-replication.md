# ADR-001: CRDT Replication for Mesh Sync

## Status
Accepted

## Context
The mesh runs across three independent nodes with intermittent latency and temporary disconnections. We need multi-writer synchronization without central leader dependency and with safe conflict convergence.

## Decision
Adopt CRDT-based replication using `crsqlite` change sets for mesh state synchronization. Use anti-entropy cursor recovery and periodic delta batching instead of a consensus-leader log.

## Consequences
- Strong eventual consistency and conflict-tolerant multi-node writes.
- Better resilience during partitions and reconnection scenarios.
- More complex schema and operational requirements around CRDT-compatible tables.
- Not a strict linearizable model like consensus systems.
