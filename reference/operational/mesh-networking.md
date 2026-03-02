<!-- v1.1.0 | 02 Mar 2026 | Added mesh-sync-all, repos.conf, SSH PATH fix -->

# Mesh Networking

Distributed execution layer that routes Claude tasks across peers (local machines, VMs,
cloud instances) via SSH/Tailscale. The floating coordinator scores peers by cost, load,
and privacy constraints, then dispatches tasks to the best available node.

## Quick Start: Add New Peer

```bash
# 1. Add peer block to ~/.claude/config/peers.conf
[my-vm]
ssh_alias=my-vm
user=ubuntu
os=linux
tailscale_ip=100.x.x.x
capabilities=claude,copilot
role=worker
status=active

# 2. Verify connectivity
mesh-load-query.sh --peer my-vm --json

# 3. Push credentials to new peer
mesh-auth-sync.sh push --peer my-vm
```

## peers.conf Format

Location: `~/.claude/config/peers.conf` (override: `PEERS_CONF` env var)

| Field          | Required | Valid Values                               | Notes                       |
| -------------- | -------- | ------------------------------------------ | --------------------------- |
| `ssh_alias`    | yes      | SSH config alias or hostname               | Used as primary SSH target  |
| `user`         | yes      | any SSH username                           | Remote user for all SSH ops |
| `os`           | yes      | `macos` \| `linux`                         | Used for platform detection |
| `tailscale_ip` | no       | `100.x.x.x`                                | Fallback if ssh_alias fails |
| `capabilities` | no       | `claude,copilot,ollama,opencode`           | Comma-separated, no spaces  |
| `role`         | yes      | `coordinator` \| `worker` \| `hybrid`      | Affects dispatcher scoring  |
| `status`       | no       | `active` \| `inactive` (default: `active`) | Inactive peers are ignored  |

**Capabilities reference**: `claude` = Claude Code MCP | `copilot` = Copilot CLI | `ollama` = local LLM | `opencode` = OpenCode agent

## Unified Sync (mesh-sync-all.sh)

One-command sync: dotclaude config + dashboard DB + project repos + non-git files (.env).

```bash
c mesh sync                        # Full 3-phase sync to all peers
c mesh sync --dry-run              # Preview without changes
c mesh sync --peer omarchy         # Single peer
c mesh sync --phase repos          # Only phase 2 (git pull + SCP)
c mesh sync --force                # git reset --hard (destructive)
c mesh status                      # Verification table only
```

### 3 Phases

| Phase | What | How |
|---|---|---|
| 1. Config + DB | dotclaude repo + dashboard.db | `peer-sync.sh push` (git bundle) + `mesh-sync-config.sh` (SCP non-git) |
| 2. Repo Sync | Project repos + non-git files | `git pull --ff-only` per repo + SCP `sync_files` (.env) |
| 3. Verify | Alignment table | SSH per peer → `git log --oneline -1` per repo, color-coded |

### repos.conf

Location: `~/.claude/config/repos.conf`

```ini
[VirtualBPM]
path=~/GitHub/VirtualBPM
branch=main
gh_account=roberdan_microsoft
sync_files=.env

[MyConvergio]
path=~/GitHub/MyConvergio
branch=master
gh_account=Roberdan
```

| Field | Required | Purpose |
|---|---|---|
| `path` | yes | Repo path on peer (~ expanded remotely) |
| `branch` | no | Default branch to pull (default: main) |
| `gh_account` | no | `gh auth switch` before pull (HTTPS auth) |
| `sync_files` | no | Comma-separated non-git files to SCP after pull |

### SSH PATH Fix (macOS peers)

Non-login SSH shells don't load `/opt/homebrew/bin`. `mesh-sync-all.sh` prepends Homebrew paths to all remote commands automatically:

```bash
export PATH="/opt/homebrew/bin:/usr/local/bin:$PATH"
```

This ensures `gh`, `claude`, and other Homebrew tools are available in SSH sessions. No manual PATH configuration needed on peers.

### Incremental Git Bundles

Full dotclaude bundle = ~85MB. Use incremental bundles for fast sync:

```bash
# Coordinator: create small bundle (only missing commits)
git -C ~/.claude bundle create /tmp/incr.bundle <last_synced_sha>..main
# SCP + apply on peer
scp /tmp/incr.bundle peer:/tmp/
ssh peer "cd ~/.claude && git fetch /tmp/incr.bundle main:refs/remotes/bundle/main && git merge --ff-only refs/remotes/bundle/main"
```

`mesh-sync-all.sh` Phase 1 uses `peer-sync.sh` (which uses `sync-claude-config.sh` full bundle). For manual fixes, incremental bundles are faster.

## Commands Reference

| Script                | Usage                                                          | Purpose                                         |
| --------------------- | -------------------------------------------------------------- | ----------------------------------------------- |
| `mesh-sync-all.sh`    | `[--dry-run] [--peer NAME] [--phase P] [--force]`             | Unified sync: config + repos + verify           |
| `mesh-sync-config.sh` | `[--dry-run] [--peer NAME]`                                    | SCP key config files to peers (non-git fallback)|
| `mesh-dispatcher.sh`  | `--plan ID \| --all-plans [--dry-run] [--force-provider PEER]` | Score peers and dispatch pending tasks          |
| `mesh-load-query.sh`  | `[--json] [--peer NAME]`                                       | Query CPU load + task state across online peers |
| `mesh-heartbeat.sh`   | `start \| stop \| status`                                      | Liveness daemon writing heartbeats every 30s    |
| `mesh-auth-sync.sh`   | `push \| status [--peer NAME \| --all]`                        | Sync credentials from master to peers           |
| `mesh-discover.sh`    | `[--deep]`                                                     | Discover Tailscale peers, tool versions, repos  |
| `lib/peers.sh`        | sourced library                                                | Peer discovery, routing, connectivity checks    |
| `lib/mesh-scoring.sh` | sourced library                                                | Peer scoring functions (cost/load/privacy)      |

**Env vars for dispatcher**:

| Var                       | Default                       | Purpose                        |
| ------------------------- | ----------------------------- | ------------------------------ |
| `MESH_MAX_TASKS_PER_PEER` | `3`                           | Max concurrent tasks per peer  |
| `MESH_DISPATCH_TIMEOUT`   | `600`                         | SSH dispatch timeout (seconds) |
| `PEERS_CONF`              | `~/.claude/config/peers.conf` | Peer registry path             |
| `DB_PATH`                 | `~/.claude/data/dashboard.db` | SQLite database                |

## Cost Routing Table

Peers are scored; highest score wins. Dispatcher picks best available for each task.

| cost_tier | Score Bonus | Typical Peer Type          |
| --------- | ----------- | -------------------------- |
| `free`    | +2          | Ollama (local LLM)         |
| `zero`    | +1          | Self-hosted VM (sunk cost) |
| `premium` | +0          | Cloud API (pay-per-token)  |

Additional scoring factors: capability match (+3), privacy safe match (+3), CPU load ≤0 (+2), CPU ≤1 (+1), tasks < max (+1). Offline or null-load peers score -99 (disqualified).

**Decision matrix**:

| Task has `privacy_required`? | Ollama peer online? | Route to           |
| ---------------------------- | ------------------- | ------------------ |
| yes                          | yes                 | Ollama peer (free) |
| yes                          | no                  | BLOCKED (no cloud) |
| no                           | yes                 | Ollama (free wins) |
| no                           | no, zero-cost peer  | Zero-cost peer     |
| no                           | no zero/free peers  | Premium (cloud)    |

## Privacy Routing

Tasks with `privacy_required=true` are restricted to peers with `privacy_safe=true` in heartbeat data. Cloud API peers are never privacy-safe by default.

| Scenario                          | Allowed Peers          | Blocked Peers |
| --------------------------------- | ---------------------- | ------------- |
| Task with `privacy_required=true` | Ollama, local machines | Cloud VMs     |
| Task with no privacy constraint   | All online peers       | Offline only  |
| Task with `--force-provider PEER` | Named peer only        | All others    |

Configure privacy on the peer side: heartbeat `capabilities` field and `privacy_safe` flag in `peer_heartbeats` table.

## mesh-heartbeat: Daemon Management

```bash
mesh-heartbeat.sh start    # Start daemon (writes PID to ~/.claude/data/mesh-heartbeat.pid)
mesh-heartbeat.sh stop     # Stop daemon
mesh-heartbeat.sh status   # Show daemon state + last heartbeat for all peers
```

Log: `~/.claude/data/mesh-heartbeat.log`

### launchd (macOS) — auto-start on login

```bash
export CLAUDE_HOME="${CLAUDE_HOME:-$HOME/.claude}"
envsubst < "$CLAUDE_HOME/config/mesh-heartbeat.plist.template" \
  > ~/Library/LaunchAgents/com.claude.mesh-heartbeat.plist
launchctl load ~/Library/LaunchAgents/com.claude.mesh-heartbeat.plist
```

### systemd (Linux) — auto-start as user service

```bash
export CLAUDE_HOME="${CLAUDE_HOME:-$HOME/.claude}"
mkdir -p ~/.config/systemd/user
envsubst < "$CLAUDE_HOME/config/mesh-heartbeat.service.template" \
  > ~/.config/systemd/user/mesh-heartbeat.service
systemctl --user daemon-reload
systemctl --user enable --now mesh-heartbeat.service
```

## Ollama Integration

```bash
# 1. Install Ollama (Linux)
curl -fsSL https://ollama.ai/install.sh | sh

# 2. Pull a model
ollama pull qwen2.5-coder:7b

# 3. Configure peer with ollama capability
# In peers.conf: capabilities=claude,ollama

# 4. Verify from coordinator
mesh-load-query.sh --peer my-ollama-peer --json
# Expect: "capabilities":"...ollama..." and online:true
```

Privacy-safe Ollama peers: ensure `privacy_safe=true` is configured in the orchestrator YAML `cost_tiers` section or set manually in `peer_heartbeats` table.

## Cloud VM Guide (Tailscale)

```bash
# On the cloud VM (Ubuntu):

# 1. Install Tailscale
curl -fsSL https://tailscale.com/install.sh | sh
sudo tailscale up

# 2. Install Claude dependencies
curl -fsSL https://claude.ai/install.sh | sh    # Claude Code CLI
# OR: npm install -g @anthropic-ai/claude-code

# 3. Bootstrap with credentials from coordinator
mesh-auth-sync.sh push --peer my-cloud          # Run on coordinator

# 4. Verify peer is visible
mesh-load-query.sh --peer my-cloud --json
```

Ensure Tailscale IP matches `tailscale_ip` in peers.conf.

## mesh-auth-sync

```bash
# Push all credentials to all active peers
mesh-auth-sync.sh push --all

# Push to a specific peer
mesh-auth-sync.sh push --peer my-vm

# Check sync status (connectivity check only)
mesh-auth-sync.sh status
```

Credentials synced (via SSH/SCP, no plaintext temp files):

| Credential     | Source                           | Destination                   |
| -------------- | -------------------------------- | ----------------------------- |
| Claude         | `~/.claude/.credentials.json`    | `~/.claude/.credentials.json` |
| Copilot        | `gh auth token`                  | `gh auth login --with-token`  |
| OpenCode       | `~/.config/opencode/config.json` | same on remote                |
| Ollama API key | `OLLAMA_API_KEY` env var         | `~/.claude/config/ollama.env` |

**Security**: Only sync to machines you own. Tokens grant full API access.

## Troubleshooting

| Symptom                                         | Cause                                       | Fix                                                               |
| ----------------------------------------------- | ------------------------------------------- | ----------------------------------------------------------------- |
| `peers.conf not found`                          | Missing config                              | Create `~/.claude/config/peers.conf` from template                |
| Peer shows offline in `mesh-load-query.sh`      | SSH unreachable                             | `ssh my-peer true` — check SSH config and Tailscale               |
| `No route for peer`                             | No `ssh_alias` or `tailscale_ip`            | Add at least one to peers.conf entry                              |
| Dispatcher skips privacy tasks                  | No privacy-safe peer online                 | Start Ollama peer or check `peer_heartbeats` table                |
| `DB write failed (will retry)` in heartbeat log | DB lock contention                          | Transient — daemon retries. If persistent, check disk             |
| Credentials not found on remote                 | Auth sync not run                           | Run `mesh-auth-sync.sh push --peer NAME`                          |
| Heartbeat daemon PID stale                      | Crash without cleanup                       | `rm ~/.claude/data/mesh-heartbeat.pid && mesh-heartbeat.sh start` |
| `cost_tier` not set                             | orchestrator.yaml missing `mesh.cost_tiers` | Add tier config or peer scores 0 (still dispatched)               |
| `gh: command not found` via SSH                 | Non-login shell missing Homebrew PATH       | `mesh-sync-all.sh` auto-prepends PATH; for manual SSH: `export PATH="/opt/homebrew/bin:$PATH"` |
| VirtualBPM pull fails on peer                   | `gh auth` wrong account or expired          | SSH into peer: `export PATH=...; gh auth status; gh auth switch --user roberdan_microsoft` |
| Git bundle merge fails (local changes)          | SCP'd files diverge from git state          | `ssh peer "cd ~/.claude && git checkout -- <file>"` then retry bundle merge |
