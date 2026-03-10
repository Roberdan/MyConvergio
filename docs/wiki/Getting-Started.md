# Getting Started

## Prerequisites

- Rust toolchain (stable) with `cargo`
- Tailscale installed and connected on all mesh nodes
- SQLite with `crsqlite` extension available
- Access to `~/.claude/config/peers.conf`

## Build

```bash
cd ~/.claude/rust/claude-core
cargo build --release
```

## Configure peers

Edit `~/.claude/config/peers.conf`:

- Ensure `[mesh]` has `shared_secret=...`
- Add one section per node (`[m3max]`, `[omarchy]`, `[m1mario]`)
- Set `tailscale_ip` for each node

## Start daemon

```bash
cd ~/.claude/rust/claude-core
cargo run -- daemon start --port 9420
```

The daemon binds to Tailscale IP (or localhost) and automatically starts HTTP API on `9421`.

## Validate startup

```bash
curl http://127.0.0.1:9421/health
curl http://127.0.0.1:9421/api/status
```
