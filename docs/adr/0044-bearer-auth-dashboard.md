# ADR 0044: Bearer Token Auth on Dashboard Server

Status: Accepted | Date: 10 Mar 2026 | Plan: 601

## Context

Dashboard server had zero authentication — any host on the network could call all APIs including PTY terminal (full RCE), plan mutations, and GitHub repo creation.

## Decision

Add Bearer token auth via CONVERGIO_AUTH_TOKEN env var. Applied selectively: all POST/PUT/DELETE + /ws/pty + plan SSE endpoints require auth. GET read routes remain open for dashboard UI. Auth disabled when env var unset (dev mode).

## Consequences

- Positive: PTY/mutations protected, CORS restricted, rate-limited
- Negative: Requires token distribution to mesh nodes; dev mode still open

## Enforcement

- Rule: `grep -q "require_auth" rust/claude-core/src/server/routes.rs`
- Check: `curl -s -o /dev/null -w '%{http_code}' -X POST http://localhost:8420/api/plan-status` → 401
