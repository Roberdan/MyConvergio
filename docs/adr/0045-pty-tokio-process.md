# ADR 0045: PTY Refactor — fork to tokio::process

Status: Accepted | Date: 10 Mar 2026 | Plan: 601

## Context

ws_pty.rs used `libc::fork()` inside Tokio async runtime. Forking a multithreaded process risks deadlocks on inherited mutexes. Each PTY connection forked the entire server process. No connection limits or idle timeouts.

## Decision

Replace libc::fork+openpty+execvp with tokio::process::Command. Add MAX_PTY_SESSIONS=10 with AtomicUsize counter + RAII SessionGuard. Add 5min idle timeout via tokio::select!. SSH uses -tt flag for forced PTY allocation.

## Consequences

- Positive: No unsafe code, no fork-in-async risk, bounded resources, auto-cleanup
- Negative: Slightly different PTY behavior (piped vs native PTY); SSH -tt may behave differently than -t

## Enforcement

- Rule: `! grep -q "libc::fork" rust/claude-core/src/server/ws_pty.rs`
- Check: `grep -q "MAX_PTY_SESSIONS" rust/claude-core/src/server/ws_pty.rs`
