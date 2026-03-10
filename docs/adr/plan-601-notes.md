# Plan 601 Running Notes

## W0: Review & Setup
- All 25 target files verified in ~/.claude (dotclaude repo)
- Baseline: Rust 135 passed/2 failed, Clippy 18 errors, Playwright 18 failures
- Challenger review caught critical issue: worktree pointed at wrong repo (convergio vs dotclaude)
- Plan 600 cancelled, Plan 601 created on correct project (claude-infra)

## W1: Security Hardening
- Auth middleware: Bearer token via CONVERGIO_AUTH_TOKEN env, selective on mutable routes
- CORS: allowlist from CONVERGIO_CORS_ORIGINS, defaults localhost:8420
- PTY: libc::fork removed, tokio::process::Command, 10 session limit, 5min idle timeout
- Mutating GETs: cancel/reset → POST, admin add/remove → POST, SSE idempotency guard
- TimeoutLayer 30s + DefaultBodyLimit 1MB + rate limiting middleware
- XSS: esc() in peer-crud/brain-canvas, confirm() on reboot/fullsync/clear/trigger
- Issue: 6 parallel agents edited overlapping files — integration build passed first try

## W2: Stability
- CRDT tests: assertions updated from 4→42 tables
- Missing routes: proxy handlers to daemon:9421 for logs/metrics/sync-stats + POST /api/projects
- pull-db: EventSource replaces plain fetch for SSE
- Clippy: 18→0 warnings (unused imports, dead fields, useless conversions, FromStr impl)
- Playwright: 18→0 failures (mesh badge assertions, WS error filtering)
- Route contract tests: updated counts (36 GET, 36 non-GET)
- Issue: cancel/reset test used GET after W1 changed to POST — fixed

## W3: Performance
- PollScheduler: central scheduler.js with visibility guard, section-aware polling
- Cache headers: Cache-Control middleware (private, max-age=10)
- Brain: SpatialHash grid replaces O(n²) force loop, 8ms frame budget
- Debounce: inflight guards on mesh sync, reboot, nightly trigger

## W4: Documentation
- .env.example: port 31415→8420
- ROADMAP: Next.js→Vanilla JS dashboard
- README: Thor 9→10 gates
- Security audit: remediation status table added

## WF: Closure
- Rust: 238 passed, 0 failed
- Clippy: 0 warnings
- Playwright: 199 passed, 0 failed
