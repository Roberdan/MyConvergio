<!-- v1.3.0 | 06 Mar 2026 | Remote auth via setup-token, credential sync phase -->

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

# 3. Full environment setup (includes persistent tmux session)
mesh-env-setup.sh --full   # run ON the peer or via SSH

# 4. Push credentials (Copilot, OpenCode, Ollama)
mesh-auth-sync.sh push --peer my-vm

# 5. Deploy Claude OAuth token (requires setup-token first)
mesh-claude-login.sh my-vm --token sk-ant-oat01-YOUR_TOKEN
```

### Persistent Sessions (auto-configured by step 3)

Every SSH connection to a mesh peer auto-attaches to a persistent `convergio` tmux session. This is configured in each node's `.zshrc` by `mesh-env-setup.sh --full` (step 7). With Warp's "Warpify SSH + Tmux Warpification" enabled, tmux is invisible — you get full Warp features with session persistence.

| Shortcut | What it does |
|----------|-------------|
| `ssh <peer>` | Auto-attaches to `convergio` session |
| `tlm` | SSH to m1mario (alias) |
| `tlx` | SSH to omarchy (alias) |
| `tl` | Local `convergio` session |

Guard: only triggers for interactive SSH (`$SSH_CONNECTION` + `$- == *i*` + no `$TMUX`). Non-interactive commands (`ssh -n`) and mesh scripts are unaffected.

## peers.conf Format

Location: `~/.claude/config/peers.conf` (override: `PEERS_CONF` env var)

| Field            | Required | Valid Values                                    | Notes                                |
| ---------------- | -------- | ----------------------------------------------- | ------------------------------------ |
| `ssh_alias`      | yes      | SSH config alias or hostname                    | Used as primary SSH target           |
| `user`           | yes      | any SSH username                                | Remote user for all SSH ops          |
| `os`             | yes      | `macos` \| `linux`                              | Used for platform detection          |
| `tailscale_ip`   | no       | `100.x.x.x`                                     | Fallback if ssh_alias fails          |
| `capabilities`   | no       | `claude,copilot,ollama,opencode`                | Comma-separated, no spaces           |
| `role`           | yes      | `coordinator` \| `worker` \| `hybrid`           | Affects dispatcher scoring           |
| `status`         | no       | `active` \| `inactive` (default: `active`)      | Inactive peers are ignored           |
| `mac_address`    | no       | `AA:BB:CC:DD:EE:FF`                             | Wake-on-LAN magic packet             |
| `gh_account`     | no       | GitHub username                                  | Used by mesh-sync/exec for `gh auth switch` |
| `default_engine` | no       | `claude` \| `copilot` \| `opencode` \| `ollama` | Preferred engine for mesh delegation |
| `default_model`  | no       | any model string                                | Pre-filled in delegation UI          |
| `runners`        | no       | integer                                          | Number of CI runners on this peer    |
| `runner_paths`   | no       | comma-separated paths                            | Paths to runner directories          |

**Capabilities reference**: `claude` = Claude Code MCP | `copilot` = Copilot CLI | `ollama` = local LLM | `opencode` = OpenCode agent

**CI Runner docs**: See `reference/operational/ci-runners.md` for runner setup, npm cache isolation, and troubleshooting.

## Peer Management UI

Dashboard CRUD: GET/POST/PUT/DELETE `/api/peers[/<name>]`, POST `/api/peers/ssh-check`, GET `/api/peers/discover` (Tailscale auto-discovery). Delegation engine reads `default_engine` from peers.conf (fallback: `copilot` → first capability). Preflight detects OAuth vs API key (warning).

## Quick Operations

| Need | Command |
|---|---|
| Sync all nodes to master | `mesh-sync.sh` |
| Sync one node | `mesh-sync.sh --peer omarchy` |
| Run task on remote peer | `mesh-exec.sh m1mario prompt.md --model gpt-5.4` |
| Run with Claude instead | `mesh-exec.sh m1mario prompt.md --tool claude` |
| Health check all nodes | `mesh-health.sh` |
| Health check one node | `mesh-health.sh --peer omarchy` |
| Apply DB migrations locally | `apply-migrations.sh` |
| Dry-run sync (preview) | `mesh-sync.sh --dry-run` |
| Force sync (reset hard) | `mesh-sync.sh --force` |

All scripts use `lib/peers.sh` for peer discovery. All handle `gh auth switch` automatically via `gh_account` field in peers.conf.

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

| Phase          | What                          | How                                                                    |
| -------------- | ----------------------------- | ---------------------------------------------------------------------- |
| 1. Config + DB | dotclaude repo + dashboard.db | `peer-sync.sh push` (git bundle) + `mesh-sync-config.sh` (SCP non-git) |
| 2. Repo Sync   | Project repos + non-git files | `git pull --ff-only` per repo + SCP `sync_files` (.env)                |
| 3. Verify      | Alignment table               | SSH per peer → `git log --oneline -1` per repo, color-coded            |

### repos.conf

Location: `~/.claude/config/repos.conf`. Fields: `path` (required), `branch` (default: main), `gh_account` (`gh auth switch` before pull), `sync_files` (comma-separated non-git files to SCP).

### SSH PATH & Git Bundles

All mesh scripts auto-prepend Homebrew/local PATH for remote commands. Full dotclaude bundle ~85MB; incremental via `git bundle create <sha>..main`. If bundle fails (`unresolved deltas`), fallback: `rsync -az --delete ~/.claude/.git/`.

## Commands Reference

| Script                 | Usage                                                          | Purpose                                          |
| ---------------------- | -------------------------------------------------------------- | ------------------------------------------------ |
| `mesh-sync-all.sh`     | `[--dry-run] [--peer NAME] [--phase P] [--force]`              | Unified sync: config + repos + verify            |
| `mesh-sync-config.sh`  | `[--dry-run] [--peer NAME]`                                    | SCP key config files to peers (non-git fallback) |
| `mesh-dispatcher.sh`   | `--plan ID \| --all-plans [--dry-run] [--force-provider PEER]` | Score peers and dispatch pending tasks           |
| `mesh-load-query.sh`   | `[--json] [--peer NAME]`                                       | Query CPU load + task state across online peers  |
| `mesh-heartbeat.sh`    | `start \| stop \| status`                                      | Liveness daemon writing heartbeats every 30s     |
| `mesh-auth-sync.sh`    | `push \| status [--peer NAME \| --all]`                        | Sync credentials from master to peers            |
| `mesh-claude-login.sh` | `<peer\|--all> --token TOKEN \| --status`                      | Deploy Claude OAuth token to remote peers        |
| `mesh-migrate.sh`      | `<plan_id> <peer> [--dry-run] [--no-launch]`                   | Migrate running plan to another peer (rsync+DB)  |
| `mesh-discover.sh`     | `[--deep]`                                                     | Discover Tailscale peers, tool versions, repos   |
| `lib/peers.sh`         | sourced library                                                | Peer discovery, routing, connectivity checks     |
| `lib/mesh-scoring.sh`  | sourced library                                                | Peer scoring functions (cost/load/privacy)       |

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

**Privacy routing**: `privacy_required=true` tasks → only `privacy_safe=true` peers (Ollama, local). Cloud = never privacy-safe. `--force-provider` overrides all routing.

## mesh-heartbeat

`mesh-heartbeat.sh start|stop|status` — liveness daemon (30s interval). Log: `~/.claude/data/mesh-heartbeat.log`.

Auto-start: macOS → `launchctl load` with `mesh-heartbeat.plist.template`, Linux → `systemctl --user enable --now` with `mesh-heartbeat.service.template`. Templates in `~/.claude/config/`.

## Ollama / Cloud VM Setup

**Ollama**: Install → `ollama pull model` → add `capabilities=ollama` in peers.conf → verify with `mesh-load-query.sh`. Privacy-safe peers: set `privacy_safe=true` in `peer_heartbeats`.

**Cloud VM (Tailscale)**: Install Tailscale → `sudo tailscale up` → install Claude CLI → add to peers.conf with `tailscale_ip` → `mesh-auth-sync.sh push` + `mesh-claude-login.sh` from coordinator.

## Claude Remote Auth (NON-NEGOTIABLE: OAuth Only)

**NEVER use ANTHROPIC_API_KEY for Claude Code.** Authentication MUST use Max subscription OAuth only. API keys are reserved exclusively for `batch-dispatcher.sh` (Batch API).

### Remote Login via setup-token

Claude Code uses PKCE OAuth — the browser callback goes to `platform.claude.com`, not localhost. This means `claude auth login` cannot complete over SSH. Use `setup-token` instead:

```bash
# Step 1: Generate token LOCALLY (one-time, in a NEW terminal outside Claude Code)
claude setup-token
# Complete browser auth → copy token (sk-ant-oat01-...)

# Step 2: Deploy to all peers
mesh-claude-login.sh --all --token sk-ant-oat01-YOUR_TOKEN

# Or single peer
mesh-claude-login.sh omarchy --token sk-ant-oat01-YOUR_TOKEN

# Check status
mesh-claude-login.sh --status
```

Token validity: **1 year**. Regenerate with `claude setup-token` before expiration.

`mesh-claude-login.sh` automatically: removes any `ANTHROPIC_API_KEY` from remote shell configs, deploys token to `~/.claude/config/oauth-token.env` (chmod 600), sources it from `~/.zshenv`, deploys minimal `~/.claude.json` for onboarding bypass.

### mesh-auth-sync (Credential Sync)

```bash
mesh-auth-sync.sh push --all     # Push all credentials to all peers
mesh-auth-sync.sh push --peer VM # Single peer
mesh-auth-sync.sh status         # Check credential presence table
```

Runs automatically as Phase 1b of `mesh-sync-all.sh`.

| Credential | Sync Method                                            | Notes                                         |
| ---------- | ------------------------------------------------------ | --------------------------------------------- |
| Claude     | Status check only                                      | OAuth via `setup-token`, never syncs API keys |
| Copilot    | `gh auth token` → `gh auth login --with-token` via SSH | Embedded in remote command (no stdin pipe)    |
| OpenCode   | SCP `~/.config/opencode/config.json`                   | Direct file copy                              |
| Ollama     | `OLLAMA_API_KEY` → `~/.claude/config/ollama.env`       | chmod 600                                     |

**SSH pitfalls solved**: all SSH calls use `-n` flag (prevents stdin consumption in loops), PATH prepended for Homebrew tools on macOS.

**Security**: Only sync to machines you own. Tokens grant full API access.

## Troubleshooting

| Symptom                                         | Cause                                           | Fix                                                                                            |
| ----------------------------------------------- | ----------------------------------------------- | ---------------------------------------------------------------------------------------------- |
| `peers.conf not found`                          | Missing config                                  | Create `~/.claude/config/peers.conf` from template                                             |
| Peer shows offline in `mesh-load-query.sh`      | SSH unreachable                                 | `ssh my-peer true` — check SSH config and Tailscale                                            |
| `No route for peer`                             | No `ssh_alias` or `tailscale_ip`                | Add at least one to peers.conf entry                                                           |
| Dispatcher skips privacy tasks                  | No privacy-safe peer online                     | Start Ollama peer or check `peer_heartbeats` table                                             |
| `DB write failed (will retry)` in heartbeat log | DB lock contention                              | Transient — daemon retries. If persistent, check disk                                          |
| Credentials not found on remote                 | Auth sync not run                               | Run `mesh-auth-sync.sh push --peer NAME`                                                       |
| Heartbeat daemon PID stale                      | Crash without cleanup                           | `rm ~/.claude/data/mesh-heartbeat.pid && mesh-heartbeat.sh start`                              |
| `cost_tier` not set                             | orchestrator.yaml missing `mesh.cost_tiers`     | Add tier config or peer scores 0 (still dispatched)                                            |
| `gh: command not found` via SSH                 | Non-login shell missing Homebrew PATH           | `mesh-sync-all.sh` auto-prepends PATH; for manual SSH: `export PATH="/opt/homebrew/bin:$PATH"` |
| VirtualBPM pull fails on peer                   | `gh auth` wrong account or expired              | SSH into peer: `export PATH=...; gh auth status; gh auth switch --user roberdan_microsoft`     |
| Git bundle merge fails (local changes)          | SCP'd files diverge from git state              | `ssh peer "cd ~/.claude && git checkout -- <file>"` then retry bundle merge                    |
| Git bundle `unresolved deltas`                  | Delta resolution fails on large repos           | Use `rsync -az --delete ~/.claude/.git/` instead of git bundle                                 |
| `ANTHROPIC_API_KEY` on peer                     | Stale key in `.zshenv`/systemd/launchd          | `mesh-claude-login.sh` auto-removes; check `.zshenv`, `launchctl`, `systemctl --user`          |
| SSH loop processes only 1 peer                  | SSH consumes stdin of while-read loop           | All SSH calls MUST use `-n` flag                                                               |
| Copilot token pipe fails with `ssh -n`          | `-n` redirects stdin from /dev/null             | Embed token in remote command: `ssh -n "$dest" "echo 'T' \| gh auth login --with-token"`       |
| `claude auth login` hangs over SSH              | OAuth PKCE callback goes to platform.claude.com | Use `setup-token` + `mesh-claude-login.sh` instead                                             |

## Live Plan Migration

Migrate a running plan to another mesh peer in one command:

```bash
mesh-migrate.sh <plan_id> <peer_name> [--dry-run] [--no-launch]
```

**5 phases** (automatic, with rollback on failure):

| Phase          | What                                                                  | Rollback        |
| -------------- | --------------------------------------------------------------------- | --------------- |
| 1. Pre-flight  | Target online, tool versions, disk, plan valid                        | Abort           |
| 2. rsync       | Full-folder sync (~/.claude + repos from repos.conf)                  | Idempotent      |
| 3. DB migrate  | WAL checkpoint → copy → integrity check → path remap → claim transfer | Restore backup  |
| 4. Auto-launch | tmux session on target runs `claude -p "/execute <id>"`               | Manual /execute |
| 5. Report      | Summary table                                                         | —               |

**Prerequisites**: SSH access, Claude CLI + auth (`setup-token`), tmux, no-sleep (macOS: `sudo pmset -a sleep 0`).

**First-time setup**: `mesh-env-setup.sh --full` (on peer — includes persistent tmux) → `mesh-auth-sync.sh push --peer NAME` → `mesh-claude-login.sh NAME --token TOKEN` → `mesh-sync-all.sh --peer NAME`.

**Migration task status**: `done` stays done, `in_progress` → `pending`, `pending` unchanged.

## Dashboard Delegation

**Flow**: Plan card → Delegate → Select peer → Preflight (SSE) → Sync → Migrate → tmux session

Preflight checks (auto-fix where possible): plan status, SSH, heartbeat, config sync, Claude CLI, disk ≥5GB. Phase 0 auto-runs `mesh-sync-all.sh --peer`. SSE streaming to dashboard modal.

## Power Management

**Wake**: WoL magic packet (`mac_address` in peers.conf), 3 packets + 15s SSH poll. **Reboot**: `sudo reboot` via SSH, 40s poll. Dashboard buttons on mesh cards.

## Auto-Sync & tmux

Sync triggers: plan complete (push all), heartbeat start/loop (pull every ~5min), delegation (Phase 0 full sync). Conflict resolution: auto-stash, force-reset, rsync fallback.

Delegated plans run in `tmux plan-{ID}` inside the persistent `convergio` session. SSH to any node lands in the `convergio` session automatically (configured by `mesh-env-setup.sh --full`). Aliases: `tlm` (m1mario), `tlx` (omarchy), `tl` (local).
