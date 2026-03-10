# Security

## Peer authentication

Mesh peers authenticate with **HMAC-SHA256 challenge-response**:

- Initiator receives `AuthChallenge` nonce
- Responds with `HMAC(secret, nonce)`
- Receiver verifies HMAC and returns `AuthResult`

The shared secret is loaded from `[mesh].shared_secret` in `peers.conf`.

## CRDT apply hardening

Incoming replication changes are filtered through a **CRDT table allowlist**.  
Only known CRR-tracked tables are accepted; unknown table deltas are discarded.

## Connection protection

The observability module includes a **per-IP rate limiter**:

- sliding window limit (requests/minute)
- max concurrent connections per IP

## Network boundary

Daemon bind policy enforces:

- Tailscale `100.x.x.x` address, or
- localhost (`127.0.0.1` / `::1`)

Binding to public `0.0.0.0` is blocked to keep mesh traffic private.
