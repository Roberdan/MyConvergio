<!-- v11.1.0 -->

# CLAUDE.md

Repository-level guidance for the **MyConvergio v11.0.0 distributable product**.
Use this file for product conventions; use `.claude/CLAUDE.md` for tool-runtime routing and Thor details.

## Product Identity

MyConvergio is a multi-tool agent platform distributed via install scripts, Make targets, and sync workflows.
This repository is the source package shipped to users, not a local-only personal configuration.

### Framework Priority

| Priority | Source | Purpose |
| --- | --- | --- |
| 1 | `.claude/agents/core_utility/CONSTITUTION.md` | Security, ethics, identity |
| 2 | `.claude/agents/core_utility/EXECUTION_DISCIPLINE.md` | Execution behavior |
| 3 | `.claude/agents/core_utility/CommonValuesAndPrinciples.md` | Organizational values |
| 4 | `AGENTS.md` + agent files | Agent catalog and specialization |
| 5 | User task context | Task-specific objectives |

## Repository Layout (v11)

```text
MyConvergio/
├── .claude/                 # Claude runtime config, agents, rules, scripts
├── copilot-agents/          # Copilot CLI agent wrappers
├── .github/agents/          # Project automation agents (night ops)
├── hooks/                   # Repo enforcement hooks
├── scripts/                 # Install, mesh, release, maintenance
├── docs/                    # Product docs, migrations, ADRs
├── AGENTS.md                # Cross-tool index and categories
├── CLAUDE.md                # This product-level guide
└── VERSION                  # Product version marker
```

## Workflow (aligned with global patterns)

Mandatory execution chain:

`/prompt` → F-xx extraction → `/research` (optional) → `/planner` → DB approval → `/execute {id}` (TDD) → Thor per-task → Thor per-wave → closure (all F-xx verified) → learning loop

### Command Mapping

| Step | Claude Code | Copilot CLI |
| --- | --- | --- |
| Capture goal | `/prompt "<goal>"` | `@prompt "<goal>"` |
| Create plan | `/planner` | `@planner` or `cplanner "<goal>"` |
| Execute tasks | `/execute {id}` | `@execute {id}` |
| Validate | Thor validator | `@validate {id}` |
| Close | PR + CI + merge, or validated deliverable | PR + CI + merge, or validated deliverable |

### Anti-Bypass (Hook Enforced)

Hooks block violations automatically — not just documentation:

| Hook | Event | Blocks |
|---|---|---|
| `workflow-enforcer.sh` | PreToolUse | EnterPlanMode, direct `plan-db.sh create`, edit outside worktree |
| `post-task-enforce.sh` | PostToolUse | Reminds checkpoint + Thor after task completion |

- Multi-step work (3+ tasks) must go through planner workflow.
- Do not self-declare done without verification artifacts.
- Use `plan-db-safe.sh` for task completion transitions before Thor validation.

## Distribution & Installation

```bash
curl -sSL https://raw.githubusercontent.com/Roberdan/MyConvergio/master/install.sh | bash
make install
make install-tier TIER=minimal VARIANT=lean
myconvergio upgrade
```

## v11 Migration References

- Primary migration guide: `docs/MIGRATION-v10-to-v11.md`
- Versioning policy: `docs/VERSIONING_POLICY.md`
- Operational references: `.claude/reference/operational/`

## Night Operations and Auto-Sync

- **Night agent**: `.github/agents/night-maintenance.agent.md` (nightly health, recovery, housekeeping).
- **Auto-sync agent flow**: `ecosystem-sync` agent + mesh sync scripts (`scripts/mesh-sync-all.sh`, `.claude/scripts/plan-db-autosync.sh`), referenced as **claude-sync** in operational runbooks.
- Mesh reference: `.claude/reference/operational/mesh-networking.md`

## Engineering Conventions

- YAML frontmatter required in agent definitions.
- Max 250 lines per file.
- Security framework blocks are mandatory where required by templates.
- SemVer 2.0.0 applies to product and agent artifacts.
- Conventional commits required.

## Validation Commands

```bash
make test
make lint
make validate
```

## Related Documentation

- `AGENTS.md` (catalog, categories, key agents)
- `.claude/CLAUDE.md` (model routing, Thor gates, hook enforcement)
- `README.md` (installation, usage, provider support)
