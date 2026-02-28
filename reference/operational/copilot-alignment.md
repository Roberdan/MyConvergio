<!-- v2.1.0 | 27 Feb 2026 | GA status, feature parity, plugin system, skills sync -->

# Copilot CLI Alignment

GitHub Copilot CLI as Claude Code alternative reference.

**Copilot CLI is Generally Available (GA) as of 25 Feb 2026, v0.0.419.**

## Decision Matrix

| Plan Size | Waves    | Use         | Why                                                |
| --------- | -------- | ----------- | -------------------------------------------------- |
| 1-6 task  | 1-2      | Copilot CLI | Sufficient rigour, saves tokens                    |
| 7+ task   | 3+       | Claude Code | Thor independent + parallel + context preservation |
| Any       | Parallel | Claude Code | No parallel worker spawning in Copilot             |

## Architecture

```
~/.copilot/: config.json, copilot-instructions.md, hooks.json, mcp-config.json
  hooks/: enforce-standards.sh, worktree-guard.sh, enforce-line-limit.sh, session-tokens.sh
{project}/.github/: copilot-instructions.md, agents/, instructions/, skills/
```

## Mandatory Routing (NON-NEGOTIABLE)

| Trigger                    | Claude Code                           | Copilot CLI     | NOT                        |
| -------------------------- | ------------------------------------- | --------------- | -------------------------- |
| Multi-step work (3+ tasks) | `Skill(skill="planner")`              | `@planner`      | EnterPlanMode, manual text |
| Execute plan tasks         | `Skill(skill="execute", args="{id}")` | `@execute {id}` | Direct file editing        |
| Thor validation            | `Task(subagent_type="thor")`          | `@validate`     | Self-declaring done        |
| Single isolated fix        | Direct edit                           | Direct edit     | Creating unnecessary plan  |

EnterPlanMode = no DB registration = VIOLATION. _Why: Plan 225._

## Feature Parity Matrix

| Feature                | Claude Code       | Copilot CLI         | Notes                                     |
| ---------------------- | ----------------- | ------------------- | ----------------------------------------- |
| Plan DB + TDD + Thor   | Native            | Native              | Identical behaviour                       |
| Hooks enforcement      | 15+ hooks         | 15+ hooks           | 15 portable, 6 Claude Code-only           |
| Worktree isolation     | Native            | Native              | Same scripts                              |
| Parallel task spawning | Yes (`Task` tool) | No                  | Claude Code only                          |
| Agent Teams            | Native            | No                  | Claude Code native; no Copilot equivalent |
| `/chronicle`           | No                | Yes                 | Copilot CLI only                          |
| Background delegation  | No                | Yes                 | Copilot CLI only; async agent handoff     |
| Cross-session memory   | Yes               | Yes                 | Both support persistent memory            |
| Plugin system          | No                | Yes (`/plugin`)     | Copilot CLI only; see Plugin System below |
| Context compaction     | Auto (preCompact) | Manual (`/compact`) | Claude Code auto at 95%                   |
| Instruction caching    | Live reload       | Restart / `/resume` | Copilot requires restart on edit          |

## Workflow Mapping

| Claude Code            | Copilot CLI      | Notes                    |
| ---------------------- | ---------------- | ------------------------ |
| `/prompt`              | `@prompt "desc"` | Same F-xx extraction     |
| `/planner`             | `@planner`       | Same spec.json + plan-db |
| `/execute {id}`        | `@execute`       | Same TDD, one at a time  |
| Thor subagent          | `@validate`      | Same 9 gates             |
| `Task` tool (parallel) | N/A              | No parallel spawning     |
| preCompact hook        | N/A              | Auto-compact at 95%      |

## Plugin System

Copilot CLI supports `/plugin install` for bundled agents, MCP servers, and hooks.

**Our plugin manifest**: `copilot-config/plugin.json`

```
/plugin install <name>   # Install from manifest
/plugin list             # Show installed plugins
/plugin remove <name>    # Uninstall
```

Plugin types supported:

- **Bundled agents**: skill .md files auto-loaded into session
- **MCP servers**: registered in `mcp-config.json` via plugin
- **Hooks**: injected into `hooks.json` on install

Claude Code equivalent: none. Use `settings.json` + `agents/` directory directly.

## .github/skills/ Sync

Key skills are mirrored to `.github/skills/` for Copilot CLI auto-loading.

```bash
copilot-sync.sh sync    # Mirror skills to .github/skills/, fix refs + symlinks
copilot-sync.sh status  # Verify alignment between ~/.copilot/ and .github/skills/
```

Sync ensures Copilot CLI picks up updated skill definitions without manual install. Runs after `CLAUDE.md` edits that affect shared skills.

## Hooks Comparison

| Hook          | Claude Code                                                                                                                               | Copilot CLI                                                                                                    |
| ------------- | ----------------------------------------------------------------------------------------------------------------------------------------- | -------------------------------------------------------------------------------------------------------------- |
| preToolUse    | guard-plan-mode, enforce-plan-db-safe, enforce-plan-edit, worktree-guard, prefer-ci-summary, warn-bash, session-file-lock, guard-settings | guard-plan-mode, enforce-plan-db-safe, enforce-plan-edit, worktree-guard, enforce-standards, session-file-lock |
| postToolUse   | enforce-line-limit, auto-format                                                                                                           | enforce-line-limit                                                                                             |
| sessionEnd    | session-end-tokens, session-file-unlock                                                                                                   | session-tokens                                                                                                 |
| subagentStart | inject-agent-context                                                                                                                      | N/A                                                                                                            |
| preCompact    | preserve-context                                                                                                                          | N/A                                                                                                            |
| preCommit     | secret-scanner, env-vault-guard                                                                                                           | N/A                                                                                                            |
| setup         | model-registry-refresh, version-check                                                                                                     | N/A                                                                                                            |

**Parity**: 15 portable hooks aligned across both platforms | 6 non-portable (Claude Code only: preCommit, setup, subagentStart, preCompact events)

Full hook reference: `reference/operational/enforcement-hooks.md`

## Token Tracking

`SELECT * FROM token_usage WHERE agent='copilot-cli' ORDER BY id DESC;` → dashboard.db

## Sync & Maintenance

`copilot-sync.sh status|sync` — Fix model refs, symlinks, chmod after CLAUDE.md edits.

## Instruction Loading Order

1. `~/.copilot/copilot-instructions.md` — global
2. `.github/copilot-instructions.md` — project (combined)
3. `.github/instructions/*.instructions.md` — path-specific
4. `.github/skills/*.md` — auto-loaded skill definitions
5. `CLAUDE.md` — agent-specific

## Rigour & Limitations

| Area                                        | Status | Notes                                                 |
| ------------------------------------------- | ------ | ----------------------------------------------------- |
| Hooks, Plan DB, TDD, Thor, Worktree, Digest | Equal  | Identical to Claude Code                              |
| Thor independence                           | Lower  | Shares session; **fix**: close executor, new session  |
| Workflow enforcement                        | Lower  | No `subagentStart` hook                               |
| Compaction                                  | Lower  | Auto at 95%; **fix**: manual `/compact` between waves |
| Parallelization                             | Lower  | Sequential only; higher compaction risk               |
| Subagent spawning                           | Lower  | In-session, not parallel                              |
| Instruction caching                         | Lower  | Edit requires restart or `/resume`                    |
