# ADR-003: Tailscale-Only Mesh Binding

## Status
Accepted

## Context
Mesh traffic includes replication frames and operational metadata between trusted nodes. Exposing daemon ports on public interfaces materially increases attack surface and operational risk.

## Decision
Restrict daemon binding to Tailscale IPv4 (`100.x.x.x`) or localhost. Reject `0.0.0.0` and other public binds during startup validation.

## Consequences
- Strong network boundary using private overlay connectivity.
- Reduced exposure to unsolicited internet traffic.
- Requires Tailscale availability and correct peer networking configuration.
- Additional setup dependency for local and remote environments.
