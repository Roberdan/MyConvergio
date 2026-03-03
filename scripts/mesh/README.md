# Mesh Scripts

Distributed peer mesh for multi-machine Claude/Copilot task execution.
All scripts use `$CLAUDE_HOME` (default: `~/.claude`). No hardcoded user/host/path (C-07).

## Scripts

| Script               | Location                        | Usage                                                            | Description                                             |
| -------------------- | ------------------------------- | ---------------------------------------------------------------- | ------------------------------------------------------- |
| `peers.sh`           | `scripts/lib/peers.sh`          | `source peers.sh && peers_load && peers_list`                    | Peer discovery library (sourced, not executed)          |
| `mesh-dispatcher.sh` | `scripts/mesh-dispatcher.sh`    | `mesh-dispatcher.sh [--plan ID\|--all-plans] [--dry-run]`        | Floating coordinator: scores peers and dispatches tasks |
| `remote-dispatch.sh` | `scripts/remote-dispatch.sh`    | `remote-dispatch.sh <task_id> <peer> [--engine claude\|copilot]` | Execute a plan task on a remote peer via SSH            |
| `bootstrap-peer.sh`  | `scripts/bootstrap-peer.sh`     | `bootstrap-peer.sh <peer-name> [--skip-tools]`                   | Initialize a remote peer for the Claude mesh            |
| `mesh-auth-sync.sh`  | `scripts/mesh-auth-sync.sh`     | `mesh-auth-sync.sh [push\|status] [--peer NAME\|--all]`          | Sync credentials to mesh peers (owned machines only)    |
| `mesh-scoring.sh`    | `scripts/lib/mesh-scoring.sh`   | `source mesh-scoring.sh`                                         | Peer scoring functions (sourced by mesh-dispatcher)     |
| `mesh-env-tools.sh`  | `scripts/lib/mesh-env-tools.sh` | `source mesh-env-tools.sh`                                       | Mesh environment utilities (sourced library)            |
| `peer-sync.sh`       | `scripts/peer-sync.sh`          | `peer-sync.sh [push\|pull\|status]`                              | One-command sync of config + DB across all peers        |
| `mesh-heartbeat.sh`  | `scripts/mesh-heartbeat.sh`     | `mesh-heartbeat.sh [start\|stop\|status]`                        | Liveness daemon: writes heartbeat every 30s             |
| `mesh-load-query.sh` | `scripts/mesh-load-query.sh`    | `mesh-load-query.sh [--json] [--peer NAME]`                      | Query CPU load and task state across online peers       |

## Config Templates

| File                                     | Usage                                                                       |
| ---------------------------------------- | --------------------------------------------------------------------------- |
| `config/peers.conf`                      | Peer registry — copy and populate with your hostnames (see example entries) |
| `config/mesh-heartbeat.plist.template`   | macOS launchd service for mesh-heartbeat daemon                             |
| `config/mesh-heartbeat.service.template` | Linux systemd user service for mesh-heartbeat daemon                        |

## Quick Start

```bash
# 1. Configure peers
cp config/peers.conf ~/.claude/config/peers.conf
# Edit: set real ssh_alias, user, os, tailscale_ip, capabilities, role

# 2. Bootstrap a peer
bootstrap-peer.sh my-linux

# 3. Start heartbeat daemon (macOS)
envsubst < config/mesh-heartbeat.plist.template \
  > ~/Library/LaunchAgents/com.claude.mesh-heartbeat.plist
launchctl load ~/Library/LaunchAgents/com.claude.mesh-heartbeat.plist

# 4. Query mesh state
mesh-load-query.sh --json

# 5. Dispatch a plan task
mesh-dispatcher.sh --plan 42 --dry-run
mesh-dispatcher.sh --plan 42
```

## peers.conf Format

```ini
[my-mac]
ssh_alias=my-mac
user=myuser
os=macos
tailscale_ip=100.100.100.1
capabilities=claude,copilot,ollama
role=hybrid
status=active
mac_address=AA:BB:CC:DD:EE:FF

[my-linux]
ssh_alias=my-linux
user=ubuntu
os=linux
tailscale_ip=100.100.100.2
capabilities=claude,copilot
role=worker
status=active
mac_address=
```

**Roles**: `coordinator` (planner/validator) | `worker` (executor only) | `hybrid` (both)
**Capabilities**: `claude` | `copilot` | `ollama` | `opencode`

## Dashboard Delegation (Convergio Control Room)

Delegate plans to mesh nodes from the web dashboard with preflight validation and live SSE streaming.

**Flow**: Plan card → 🚀 Delegate → Select peer → Preflight (auto-fix) → Sync → Migrate → tmux session

### Preflight Checks (auto-fix)

| Check | Auto-fix |
|---|---|
| Plan status (todo/doing) | — |
| SSH reachable | — |
| Heartbeat stale | Restarts daemon via SSH |
| Config out of sync | Runs `mesh-sync-all.sh --peer` |
| Claude CLI | Searches `~/.local/bin`, `/opt/homebrew/bin` |
| Disk space ≥5GB | — |

### Power Management

- **Wake-on-LAN**: Pure Python magic packet for offline nodes (requires `mac_address` in peers.conf)
- **SSH Reboot**: OS-aware `sudo reboot` for frozen nodes with post-reboot polling

### Auto-Sync Protocol

| Event | Action |
|---|---|
| Plan complete | Push to all online peers |
| Heartbeat start | Pull from coordinator |
| Heartbeat loop (~5min) | Pull from coordinator |
| Delegation | Full sync before migration |

### tmux Integration

Delegated plans run in `tmux plan-{ID}` on target. Dashboard terminals auto-attach.
