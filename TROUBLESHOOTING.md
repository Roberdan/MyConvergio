# Troubleshooting

## Dashboard web task execution

- Ensure `PATH` includes `~/.claude/scripts` before running plan-db and guard scripts.
- Verify worktree guard passes before edits: `worktree-guard.sh <repo>`.
- Re-run preflight if readiness warnings appear: `execution-preflight.sh --plan-id 100025 <repo>`.

## Mesh daemon: peers show offline

**Symptom**: Dashboard shows peers as offline, `peer_heartbeats` table has stale timestamps.

**Cause 1**: Daemon not running. Only `claude-core serve` (port 8420) was started, not `claude-core daemon start` (port 9420).
**Fix**: `nohup claude-core daemon start </dev/null >/tmp/mesh-daemon.log 2>&1 & disown`

**Cause 2**: `--peers-conf` defaults to relative `peers.conf` (cwd), not `~/.claude/config/peers.conf`.
**Fix**: Fixed in v11.5.0. Or pass explicitly: `claude-core daemon start --peers-conf ~/.claude/config/peers.conf`

**Cause 3**: Peer heartbeats stored as IP:port (`100.x.x.x:9420`) instead of peer name.
**Fix**: Fixed in v11.5.0 with `resolve_peer_name()` that maps IP→section name from peers.conf.

## Mesh daemon: peer sends node_id `0.0.0.0:9420`

**Symptom**: Heartbeat records with `0.0.0.0:9420` as peer_name.
**Cause**: `detect_tailscale_ip()` fails because `tailscale` binary not in PATH. On macOS with Tailscale app, binary is at `/Applications/Tailscale.app/Contents/MacOS/Tailscale`.
**Fix**: Fixed in v11.5.0 — searches 4 candidate paths. Or set `TAILSCALE_IP` env var before starting daemon.

## Mesh daemon: peers.conf parser fails

**Symptom**: Daemon connects to garbage addresses or doesn't connect at all.
**Cause**: Before v11.5.0, parser read flat lines. peers.conf is INI-format with `[section]` headers and `key=value` pairs.
**Fix**: Fixed in v11.5.0 — parser extracts `tailscale_ip` from each `[peer]` section.

## Brain visualization empty canvas

**Symptom**: Brain tab shows blank canvas, no regions or neurons.
**Cause**: Script includes missing from `index.html`. Required scripts (in order): `brain-regions.js`, `brain-organism.js`, `brain-sessions.js`, `brain-consciousness.js`, `brain-effects.js`, `brain-layout.js`, `brain-interact.js`, `brain-canvas.js`.
**Fix**: Verify all 8 scripts are included in `index.html` before the closing `</body>` tag.

## Deploying to remote peers

**Symptom**: Remote peers have stale binary, can't parse peers.conf or detect tailscale.
**Fix (omarchy)**: `ssh omarchy "cd ~/.claude && git pull --ff-only github main && cd rust/claude-core && cargo build --release"`
**Fix (m1mario)**: Create git bundle locally, SCP to peer, fetch+merge, then build. m1mario uses `dotclaude` remote (not `github`) and needs bundle for auth.
