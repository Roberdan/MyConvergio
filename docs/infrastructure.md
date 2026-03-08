# Infrastructure (v11)

MyConvergio infrastructure is script-first: runtime automation, guardrails, and SQLite-backed operational state.

## Core Runtime Surface

| Layer | Assets | Purpose |
| --- | --- | --- |
| Scripts | `scripts/`, `.claude/scripts/` | Install, orchestration, quality, sync, maintenance |
| Hooks | `hooks/` | Enforce workflow and quality constraints |
| State | `~/.claude/data/dashboard.db` | Plans, tasks, tokens, nightly jobs |
| Automation | `.github/agents/`, `systemd/` | Nightly maintenance and repository operations |

## Nightly Guardian Infrastructure (night-agent)

Night operations are implemented by the `night-maintenance` project automation agent and `scripts/myconvergio-nightly-guardian.sh`.

### systemd Units

| File | Role |
| --- | --- |
| `systemd/myconvergio-nightly-guardian.service` | Runs nightly guardian as `Type=oneshot` |
| `systemd/myconvergio-nightly-guardian.timer` | Schedules run at 03:00 with randomized delay |

### Nightly Config

Config template: `config/myconvergio-nightly.conf.example`

Key values:
- `MYCONVERGIO_REPO_PATH`
- `MYCONVERGIO_GITHUB_REPO`
- `MYCONVERGIO_MODEL`
- `MYCONVERGIO_MAX_CHANGES_PER_RUN`
- `MYCONVERGIO_PROJECT_AGENT_REL_PATH=.github/agents/night-maintenance.agent.md`

### Deploy / Enable

```bash
mkdir -p ~/.config/systemd/user
cp systemd/myconvergio-nightly-guardian.service ~/.config/systemd/user/
cp systemd/myconvergio-nightly-guardian.timer ~/.config/systemd/user/
cp config/myconvergio-nightly.conf.example ~/.myconvergio/config/myconvergio-nightly.conf
systemctl --user daemon-reload
systemctl --user enable --now myconvergio-nightly-guardian.timer
systemctl --user status myconvergio-nightly-guardian.timer
```

Operational outputs:
- JSON reports in `~/.claude/data/nightly-jobs/`
- `nightly_jobs` records in `~/.claude/data/dashboard.db`

## Sync Agent Infrastructure (sync-agent)

The sync path is exposed operationally as `claude-sync`, implemented through `ecosystem-sync` and mesh sync scripts.

### Sync Components

| Component | Role |
| --- | --- |
| `scripts/myconvergio-claude-sync-agent.sh` | Snapshot diff, bounded copy, sync PR automation |
| `scripts/mesh-sync-all.sh` | Cross-node ecosystem alignment |
| `.claude/scripts/plan-db-autosync.sh` | Plan DB autosync support in mesh workflows |
| `.claude-snapshot-baseline.json` | Baseline state for sync diffing |

### Sync Execution

```bash
./scripts/myconvergio-claude-sync-agent.sh --dry-run
./scripts/myconvergio-claude-sync-agent.sh
```

Expected behavior:
- Computes deltas for rules/hooks/commands/skills
- Applies approved alignment
- Opens sync PR branch (`sync/claude-alignment-*`) when changes exist

## SQLite State Model

Primary tables for operations:
- `plans`, `waves`, `tasks`, `tokens`
- `nightly_jobs` (night-agent telemetry)

Quick check:

```bash
sqlite3 ~/.claude/data/dashboard.db "SELECT status, COUNT(*) FROM nightly_jobs GROUP BY status;"
```

## Quality and Constraints

- Max file size policy: 250 lines
- Thor validation before completion
- CI batch-fix discipline for PR iterations

## References

- [Getting Started](./getting-started.md)
- [Workflow](./workflow.md)
- [Agent Orchestration Architecture](./AGENT_ORCHESTRATION_ARCHITECTURE.md)
