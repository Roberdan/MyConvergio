# ADR-004: HMAC-SHA256 Challenge-Response Peer Authentication

## Status
Accepted

## Context
Mesh peers must verify each other before accepting sync frames. We need lightweight authentication with low operational overhead and compatibility across all nodes.

## Decision
Use pre-shared secret authentication from `peers.conf` and perform challenge-response with HMAC-SHA256 (`AuthChallenge`, `AuthResponse`, `AuthResult` frames).

## Consequences
- Fast, deterministic authentication with minimal protocol overhead.
- No certificate lifecycle management required for initial deployment.
- Secret rotation must be managed operationally across all nodes.
- Shared-secret model is weaker than full PKI/mTLS if secret handling is poor.
