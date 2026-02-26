<!-- v2.0.0 | 15 Feb 2026 | Token-optimized per ADR 0009 -->

# Copilot CLI Alignment

GitHub Copilot CLI as Claude Code alternative reference.

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
{project}/.github/: copilot-instructions.md, agents/, instructions/
```

## Mandatory Routing (NON-NEGOTIABLE)

| Trigger                    | Claude Code                           | Copilot CLI     | NOT                        |
| -------------------------- | ------------------------------------- | --------------- | -------------------------- |
| Multi-step work (3+ tasks) | `Skill(skill="planner")`              | `@planner`      | EnterPlanMode, manual text |
| Execute plan tasks         | `Skill(skill="execute", args="{id}")` | `@execute {id}` | Direct file editing        |
| Thor validation            | `Task(subagent_type="thor")`          | `@validate`     | Self-declaring done        |
| Single isolated fix        | Direct edit                           | Direct edit     | Creating unnecessary plan  |

EnterPlanMode = no DB registration = VIOLATION. _Why: Plan 225._

## Workflow Mapping

| Claude Code            | Copilot CLI      | Notes                    |
| ---------------------- | ---------------- | ------------------------ |
| `/prompt`              | `@prompt "desc"` | Same F-xx extraction     |
| `/planner`             | `@planner`       | Same spec.json + plan-db |
| `/execute {id}`        | `@execute`       | Same TDD, one at a time  |
| Thor subagent          | `@validate`      | Same 9 gates             |
| `Task` tool (parallel) | N/A              | No parallel spawning     |
| preCompact hook        | N/A              | Auto-compact at 95%      |

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

`SELECT * FROM token_usage WHERE agent='copilot-cli' ORDER BY id DESC;` → dashboard.db (localhost:31415)

## Sync & Maintenance

`copilot-sync.sh status|sync` — Fix model refs, symlinks, chmod after CLAUDE.md edits.

## Instruction Loading Order

1. `~/.copilot/copilot-instructions.md` — global
2. `.github/copilot-instructions.md` — project (combined)
3. `.github/instructions/*.instructions.md` — path-specific
4. `CLAUDE.md` — agent-specific

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
