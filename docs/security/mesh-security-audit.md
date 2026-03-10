# Mesh Protocol Security Audit — Plan 599

## Scope
Convergio Mesh daemon: TCP sync, HTTP API, WebSocket brain, CRDT replication.

## Findings

| ID | Severity | Area | Finding | Status |
|----|----------|------|---------|--------|
| S-01 | ✅ Fixed | Auth | Peer auth via HMAC-SHA256 challenge-response | W1 T1-09 |
| S-02 | ✅ Fixed | CRDT | Table allowlist blocks unknown CRR tables | W1 T1-08 |
| S-03 | ✅ Fixed | Network | Bind only to Tailscale IPs (validate_config) | W1 T1-07 |
| S-04 | ✅ Fixed | Rate Limit | Per-IP sliding window + concurrent connection cap | W3 T3-04 |
| S-05 | ✅ Fixed | Config | Empty/invalid shared_secret handled gracefully | auth.rs |
| S-06 | ⚠️ Medium | HTTP API | No auth on /api/* endpoints (Tailscale-only mitigates) | T2-04 |
| S-07 | ⚠️ Medium | WebSocket | /ws/brain no per-session auth | T2-04 |
| S-08 | ℹ️ Low | CRDT | No payload size limit on incoming DeltaChange | Future |
| S-09 | ℹ️ Low | Gossip | Member list not cryptographically verified | Future |

## Authentication Flow
```
Inbound:  Listener → Generate 32-byte nonce → Send AuthChallenge
          ← Receive AuthResponse (HMAC-SHA256) → Verify → AuthResult
Outbound: Connect → Receive AuthChallenge → Compute HMAC → Send AuthResponse
          ← Receive AuthResult → Proceed or disconnect
```

## CRDT Allowlist
- Queries `sqlite_master` for `%__crsql_clock` tables
- Only those base table names are allowed in incoming `DeltaChange`
- Blocks injection into arbitrary tables (e.g., `users`, `credentials`)

## Rate Limiting
- Per-IP: max 60 connections per 60-second window
- Concurrent: max 5 simultaneous connections per IP
- Applied before auth handshake

## Recommendations
1. Add JWT/token auth to HTTP API endpoints (S-06)
2. Add WebSocket connection auth header (S-07)  
3. Add max payload size check on DeltaChange frames (S-08)
4. Consider TLS over Tailscale for defense-in-depth

## Conclusion
Core mesh protocol is **well-hardened** with defense-in-depth (Tailscale network + HMAC auth + CRDT allowlist + rate limiting). HTTP/WebSocket endpoints rely on Tailscale network isolation — acceptable for current 3-node private mesh.
