# Getting Started with MyConvergio v11

Fast path from install to first validated execution.

## Prerequisites

| Tool | Required | Notes |
| --- | --- | --- |
| `git` | Yes | Clone, upgrades, worktree flow |
| `make` | Yes | Install/upgrade targets |
| `bash` | Yes | Runtime scripts |
| `sqlite3` | Yes | Plan and telemetry DB |
| `jq` | Yes | JSON processing in scripts |
| `gh` | Yes | Night agent + issue/PR automation |
| `claude` or `copilot` | Yes | Runtime agent execution |

Authenticate GitHub CLI before install:

```bash
gh auth login
gh auth status
```

## Install Flows

### A) Fresh Install (recommended)

```bash
curl -sSL https://raw.githubusercontent.com/Roberdan/MyConvergio/master/install.sh | bash
```

Installer behavior (v11):
- Verifies required tools, including authenticated `gh`
- Clones to `~/.myconvergio` if no prior installation exists
- Runs `make install` or tier install
- Links `myconvergio` to `~/.local/bin`
- Runs `myconvergio doctor`

### B) Existing v11 Upgrade

If `~/.myconvergio` is already v11, re-running installer triggers safe upgrade:

```bash
~/.myconvergio/install.sh
# or
myconvergio upgrade
```

### C) Migration from v10

v10 is a breaking migration path and includes mandatory backup:

```bash
myconvergio backup
./scripts/migrate-v10-to-v11.sh
myconvergio doctor
```

Reference: [MIGRATION-v10-to-v11.md](./MIGRATION-v10-to-v11.md)

## Profile Selection

```bash
myconvergio install --minimal
myconvergio install --standard
myconvergio install --full
myconvergio install --lean
```

## Post-Install Setup

Apply hardware profile:

```bash
myconvergio settings
```

Optional Copilot wrapper setup:

```bash
cp copilot-agents/*.agent.md ~/.copilot/agents/
```

## First Workflow (v11 Chain)

```bash
@prompt "<goal>"
@planner "<plan request>"
@execute <plan_id>
@validate <plan_id-or-task>
```

Mandatory flow:
`/prompt` → `/research` (optional) → `/planner` → DB approval → `/execute` (TDD) → Thor per-task/per-wave validation → closure.

## Health Check

```bash
myconvergio doctor
dashboard-mini.sh --overview
```

## Next Docs

- [Workflow](./workflow.md)
- [Infrastructure](./infrastructure.md)
- [Context Optimization](./CONTEXT_OPTIMIZATION.md)
