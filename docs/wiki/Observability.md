# Observability

Convergio Mesh includes built-in observability primitives for runtime operations and dashboarding.

## Metrics

`MeshMetrics` exposes atomic counters for:

- `frames_received`, `frames_sent`
- `bytes_received`, `bytes_sent`
- `auth_failures`
- `connections_accepted`, `connections_rejected`
- `changes_applied`, `changes_blocked`
- `uptime_secs`

These are available via `GET /api/metrics`.

## Log buffer

`LogBuffer` stores recent in-memory log entries with bounded capacity and eviction of oldest records.  
Recent entries are exposed via `GET /api/logs`.

## Rate limiter telemetry relevance

The rate limiter guards inbound abuse and influences:

- rejected connection counts
- security monitoring signals
- operational diagnosis of peer churn and connection bursts

## Dashboard integration

The dashboard consumes HTTP metrics/log endpoints and WebSocket brain events to render:

- node health and peer status
- replication activity
- event timeline
- operational anomalies
