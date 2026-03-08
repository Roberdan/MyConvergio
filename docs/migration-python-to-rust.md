# Migration Complete: Rust-Only Architecture

The Rust `claude-core` binary is now the **sole** runtime for DB, hooks, mesh, API, and dashboard serving. Python server files have been removed.

## What changed

- `claude-core` handles: plan-db, hooks, digest, lock, mesh daemon, Axum HTTP/WS/SSE server, TUI
- `package.json` build/test/lint now use `cargo check`, `cargo test`, `cargo clippy`
- Dashboard frontend (JS/CSS/HTML) is served by the Axum static file handler
- Shell scripts (`scripts/c`, `plan-db.sh`, etc.) remain as CLI entrypoints

## Installing

1. Build: `cd rust/claude-core && cargo build --release`
2. Or use `scripts/build-claude-core.sh` for cross-platform artifacts
3. Set `CLAUDE_CORE_BIN` or ensure `claude-core` is in `PATH`

## Removed files

All Python server/API modules (`server.py`, `api_*.py`, `middleware.py`, `mesh_handoff*.py`, `lib/`) and their pytest suite were removed in favor of Rust equivalents with `cargo test` coverage.
