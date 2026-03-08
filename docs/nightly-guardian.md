# Nightly Guardian — Operations Runbook

Automated nightly triage and remediation for MirrorBuddy via Copilot CLI.

## Architecture

```
Timer (systemd)          Script                        Dashboard DB
02:30 UTC ±20m  ──►  nightly-guardian.sh  ──►  nightly_jobs + notifications
                       │                          │
                       ├─ Sentry digest            ├─ status: ok | action_required | failed
                       ├─ GitHub issues            ├─ report JSON
                       ├─ Copilot auto-fix (opt)   └─ PR link (if fixes applied)
                       └─ Deploy status check
```

| Component | Path |
|---|---|
| Main script | `scripts/mirrorbuddy-nightly-guardian.sh` (v1.2.0) |
| Config template | `config/mirrorbuddy-nightly.conf.example` |
| Config (host-specific, gitignored) | `config/mirrorbuddy-nightly.conf` |
| systemd service | `systemd/mirrorbuddy-nightly-guardian.service` |
| systemd timer | `systemd/mirrorbuddy-nightly-guardian.timer` |
| Installer (Linux) | `scripts/install-mirrorbuddy-nightly-linux.sh` |
| Deployer (remote peer) | `scripts/deploy-mirrorbuddy-nightly-peer.sh` |
| Reports | `data/nightly-jobs/*.json` |
| DB tables | `nightly_jobs`, `notifications` in `data/dashboard.db` |

## Configuration

`config/mirrorbuddy-nightly.conf` — host-specific, **gitignored** (only `.example` tracked).

| Variable | Default | Description |
|---|---|---|
| `MIRRORBUDDY_REPO_PATH` | `$HOME/GitHub/MirrorBuddy` | Local repo clone path |
| `MIRRORBUDDY_DEFAULT_BRANCH` | `main` | Base branch for fix PRs |
| `MIRRORBUDDY_GITHUB_REPO` | — | GitHub slug (e.g. `FightTheStroke/MirrorBuddy`) |
| `MIRRORBUDDY_MODEL` | `gpt-5.3-codex` | Copilot model for auto-fix |
| `MIRRORBUDDY_MAX_ITEMS` | `6` | Max items to process |
| `MIRRORBUDDY_RUN_FIXES` | `true` | **Enable auto-fix** (`false` = triage only) |
| `MIRRORBUDDY_RUN_RELEASE_GATE` | `false` | Run `npm run release:gate` |
| `MIRRORBUDDY_AUTO_MERGE` | `false` | Auto-merge PR via `gh pr merge --squash` |
| `MIRRORBUDDY_FIX_TIMEOUT_SEC` | `5400` | Copilot fix timeout (90 min) |

## Flow

1. **Triage**: query Sentry unresolved + GitHub issues (labels: bug/regression/critical/production/incident)
2. **Decision**: if `PROCESSED_ITEMS > 0` and `RUN_FIXES=true` → run fix flow; else → notify only
3. **Fix flow**: checkout new branch `nightly/guardian-YYYYMMDD-HHMM`, invoke Copilot CLI with prompt, run CI checks, create PR
4. **Deploy check**: verify production deploy status via `service-digest.sh deploy`
5. **Report**: write JSON to `data/nightly-jobs/`, update `nightly_jobs` DB table, insert dashboard notification

### Status outcomes

| Status | Meaning |
|---|---|
| `ok` | No actionable issues found |
| `action_required` | Issues found — PR created for review, or auto-fix disabled, or deploy status not ready |
| `failed` | Script error or fix flow failed |

## Setup on a New Host

### Prerequisites

- `copilot` CLI (GitHub Copilot CLI ≥1.0), `gh`, `jq`, `sqlite3`, `git`, `npm`
- MirrorBuddy repo cloned locally
- GitHub CLI authenticated (`gh auth status`)

### Quick install (Linux with systemd)

```bash
~/.claude/scripts/install-mirrorbuddy-nightly-linux.sh
```

Creates config from `.example` if missing, installs systemd user timer, enables linger.

### Deploy to remote peer (e.g. omarchy)

```bash
~/.claude/scripts/deploy-mirrorbuddy-nightly-peer.sh omarchy-ts
```

Copies scripts + systemd units via SCP, runs installer on remote host.

### Manual run / dry-run

```bash
# Full run
~/.claude/scripts/mirrorbuddy-nightly-guardian.sh

# Triage only (no fixes)
MIRRORBUDDY_RUN_FIXES=false ~/.claude/scripts/mirrorbuddy-nightly-guardian.sh
```

## Troubleshooting

### "Issues detected, but auto-fix is disabled"

**Cause**: `MIRRORBUDDY_RUN_FIXES` is not `true`. Either:
- Config file missing → create from example: `cp config/mirrorbuddy-nightly.conf.example config/mirrorbuddy-nightly.conf`
- Config has `MIRRORBUDDY_RUN_FIXES=false`
- Environment variable override

**Fix**: ensure `config/mirrorbuddy-nightly.conf` exists and contains `MIRRORBUDDY_RUN_FIXES=true`.

### Check timer status (on host running the guardian)

```bash
systemctl --user status mirrorbuddy-nightly-guardian.timer
systemctl --user list-timers mirrorbuddy-nightly-guardian.timer
```

### Check last run results

```bash
# From DB
sqlite3 ~/.claude/data/dashboard.db \
  "SELECT run_id, started_at, status, summary FROM nightly_jobs ORDER BY started_at DESC LIMIT 5;"

# From JSON report
cat ~/.claude/data/nightly-jobs/latest-mirrorbuddy-nightly.json | jq .
```

### Dismiss stale notifications

```bash
sqlite3 ~/.claude/data/dashboard.db \
  "UPDATE notifications SET is_read=1, is_dismissed=1, read_at=datetime('now') WHERE title LIKE '%Nightly Guardian%' AND is_dismissed=0;"
```

### Force re-run

```bash
systemctl --user start mirrorbuddy-nightly-guardian.service
journalctl --user -u mirrorbuddy-nightly-guardian.service -f
```

## Current Deployment

| Host | Role | Timer | Config |
|---|---|---|---|
| **omarchy** | Primary runner | `02:30 UTC ±20m` daily | `~/.claude/config/mirrorbuddy-nightly.conf` |
| Mac (local) | Config repo only | — | gitignored local copy |
