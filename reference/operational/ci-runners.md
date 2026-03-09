<!-- v1.0.0 | 09 Mar 2026 | Initial runner setup documentation -->

# Self-Hosted CI Runners

## Current Inventory

| Runner | Host | Status | Path | Labels |
|---|---|---|---|---|
| m1mario-runner | m1mario (mariodan) | online | ~/actions-runner | self-hosted, macOS, ARM64 |
| m1mario-runner-2 | m1mario (mariodan) | online | ~/actions-runner-2 | self-hosted, macOS, ARM64 |
| m1mario-runner-3 | m1mario (mariodan) | online | ~/actions-runner-3 | self-hosted, macOS, ARM64 |
| linux-runner-1 | omarchy (roberdan) | online | ~/actions-runner | self-hosted, Linux, X64 |
| mac-runner-1 | m3max (roberdan) | offline | ~/actions-runner | self-hosted, macOS, ARM64 |

## Adding a New Runner (Checklist)

```bash
# 1. Download FRESH tarball (never copy bin/ from existing runner)
RUNNER_DIR=~/actions-runner-N
mkdir -p "$RUNNER_DIR" && cd "$RUNNER_DIR"
curl -o actions-runner.tar.gz -L https://github.com/actions/runner/releases/download/v2.XXX.X/actions-runner-osx-arm64-2.XXX.X.tar.gz
tar xzf actions-runner.tar.gz && rm actions-runner.tar.gz

# 2. Configure (get token from GitHub Settings > Actions > Runners > New)
./config.sh --url https://github.com/OWNER/REPO --token TOKEN --name "hostname-runner-N" --labels self-hosted,macOS,ARM64

# 3. Copy .path from working runner (includes /opt/homebrew/bin, node, python3.11)
cp ~/actions-runner/.path "$RUNNER_DIR/.path"

# 4. Set isolated npm cache (CRITICAL — prevents EEXIST race conditions)
echo "NPM_CONFIG_CACHE=$RUNNER_DIR/.npm-cache" >> "$RUNNER_DIR/.env"
mkdir -p "$RUNNER_DIR/.npm-cache"

# 5. Install and start as LaunchAgent
cd "$RUNNER_DIR"
./svc.sh install
./svc.sh start
./svc.sh status
```

## npm Cache Isolation (NON-NEGOTIABLE)

Multiple runners sharing `~/.npm/` causes `EEXIST` errors during concurrent `npm ci`. Each runner MUST have its own cache:

```bash
# In each runner's .env file:
NPM_CONFIG_CACHE=/path/to/runner-N/.npm-cache
```

_Why: Plan 387 — 3 runners on m1mario all hit `EEXIST` during concurrent `npm ci` until npm caches were isolated._

## PATH Requirements

Runner `.path` file MUST include:
- `/opt/homebrew/bin` (node, npm, python3.11, gh)
- `/usr/local/bin`
- Standard system paths

If `.path` is missing these, copy from a working runner: `cp ~/actions-runner/.path ~/actions-runner-N/.path`

## Troubleshooting

| Symptom | Cause | Fix |
|---|---|---|
| `config.sh` says "already configured" | Copied `bin/` from existing runner | Download fresh tarball |
| `svc.sh remove` needs sudo | LaunchAgent removal requires auth | `sudo ./svc.sh stop && sudo ./svc.sh uninstall` or nuke dir + fresh setup |
| `node: command not found` in CI | `.path` missing homebrew | Copy `.path` from working runner |
| `EEXIST` during `npm ci` | Shared npm cache | Set `NPM_CONFIG_CACHE` per runner in `.env` |
| Runner offline after reboot | LaunchAgent not loaded | `cd runner-dir && ./svc.sh start` |
