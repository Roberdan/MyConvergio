# API Reference

Mesh daemon HTTP API runs on **port `9421`** (when daemon port is `9420`).

Base URL examples:

- `http://127.0.0.1:9421`
- `http://<tailscale-ip>:9421`

## GET /health

Returns daemon liveness and uptime.

## GET /api/status

Returns node identity, peer list with online status, peer count, and uptime.

## GET /api/peers

Returns simplified peer list (`name`, `last_seen`, `online`).

## GET /api/metrics

Returns mesh metrics snapshot, including:

- frames/bytes sent and received
- auth failures
- accepted/rejected connections
- applied/blocked changes

## GET /api/sync-stats

Returns CRDT replication stats from `mesh_sync_stats`, including:

- `total_sent`, `total_received`, `total_applied`
- `last_sync_at`, `last_latency_ms`
- `last_db_version`, `last_error`

## GET /api/logs

Returns recent buffered log entries (`logs`, `count`).
