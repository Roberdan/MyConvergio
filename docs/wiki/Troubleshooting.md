# Troubleshooting

## `crsqlite` extension fails to load

Symptoms:

- daemon startup error: `crsqlite extension not found`
- sync schema initialization failure

Actions:

1. Verify extension path passed via `--crsqlite-path`
2. Check platform extension suffix (`.dylib` on macOS, `.so` on Linux)
3. Confirm file exists and is readable by the daemon process

## macOS `sqlite3` limitations

System `sqlite3` may not support extension loading defaults needed by `crsqlite`.

Actions:

- Prefer daemon-managed database access (`claude-core`)
- Use a compatible SQLite build for local manual inspection if extension loading is required

## Cross-compile issues

Symptoms:

- linker errors or target-specific native dependency failures

Actions:

1. Install target toolchain (`rustup target add ...`)
2. Ensure target-compatible native libraries for SQLite/openssl stack
3. Build natively on the target node when possible

## Node appears offline

Symptoms:

- peer `online=false` in `/api/status`
- stale heartbeat age

Actions:

1. Confirm Tailscale is connected (`tailscale status`)
2. Validate node entry in `peers.conf` (`tailscale_ip` correct)
3. Check daemon process is running on peer
4. Verify TCP port `9420` and API port `9421` reachability over Tailscale
