# Configuration

The mesh daemon reads peers from:

`~/.claude/config/peers.conf`

## File format

INI-style sections with `key=value` entries.

```ini
[mesh]
shared_secret=replace-with-strong-random-secret

[m3max]
tailscale_ip=100.x.x.x
role=coordinator

[omarchy]
tailscale_ip=100.x.x.x
role=worker

[m1mario]
tailscale_ip=100.x.x.x
role=worker
```

## Required keys

- `[mesh]`
  - `shared_secret`: pre-shared key for HMAC challenge-response auth
- Per node section
  - `tailscale_ip`: private network IP used for mesh TCP connections

## Port configuration

- Mesh TCP daemon: `--port 9420` (default)
- HTTP API: `port + 1` → `9421`

## Binding rules

- `bind_ip` must be Tailscale (`100.x.x.x`) or localhost
- Binding to `0.0.0.0` is rejected by daemon validation
