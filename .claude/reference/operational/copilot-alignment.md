# Copilot CLI Alignment with Claude Code

Reference guide for using GitHub Copilot CLI as a Claude Code alternative on MirrorBuddy.

## Decision Matrix

| Plan Size | Waves          | Recommended     | Why                                                        |
| --------- | -------------- | --------------- | ---------------------------------------------------------- |
| 1-6 task  | 1-2 wave       | **Copilot CLI** | Rigore sufficiente, risparmia token Claude Max             |
| 7+ task   | 3+ wave        | **Claude Code** | Serve Thor indipendente + parallelo + context preservation |
| Qualsiasi | Wave parallele | **Claude Code** | Copilot non spawna worker paralleli                        |

## When to Use Copilot CLI

- **Piani piccoli** (1-6 task, 1-2 wave) — rigore sufficiente
- **Task sequenziali** (one at a time, TDD, review, validation)
- **Save Claude Max tokens** for complex/parallel work
- **Same model** (claude-opus-4.6) with same quality

## When to Use Claude Code Instead

- **Piani grandi** (7+ task) — rischio compaction perde contesto del piano
- **Parallel orchestration** (Kitty multi-worker, 3-4 executors)
- **Thor as independent subagent** (fresh context, zero trust validation)
- **preCompact control** (context preservation during compaction)
- **Deep skill workflows** (`/planner`, `/execute` multi-step)

## Architecture

```
~/.copilot/
  config.json                  # Model: claude-opus-4.6, trusted folders
  copilot-instructions.md      # Global instructions (equiv. CLAUDE.md)
  hooks.json                   # Hook registry (pre/postToolUse, sessionEnd)
  mcp-config.json              # CodeGraph MCP server
  hooks/
    enforce-standards.sh       # preToolUse: digest script enforcement
    worktree-guard.sh          # preToolUse: protect main branch
    enforce-line-limit.sh      # postToolUse: max 250 lines/file
    session-tokens.sh          # sessionEnd: track tokens in dashboard.db
  agents/  (symlinks)
    prompt.agent.md    -> ~/.claude/copilot-agents/prompt.agent.md
    planner.agent.md   -> ~/.claude/copilot-agents/planner.agent.md
    execute.agent.md   -> ~/.claude/copilot-agents/execute.agent.md
    validate.agent.md  -> ~/.claude/copilot-agents/validate.agent.md
```

```
MirrorBuddy/.github/
  copilot-instructions.md      # Project-specific instructions (246 lines)
  agents/                      # 4 project agents (tdd, review, a11y, compliance)
  instructions/                # 9 path-specific rule files
  prompts/                     # 6 reusable prompts
  skills/                      # 2 skills (ci-verification, release-gate)
```

## Workflow Mapping

| Claude Code            | Copilot CLI      | Notes                              |
| ---------------------- | ---------------- | ---------------------------------- |
| `/prompt`              | `@prompt "desc"` | Same F-xx extraction               |
| `/planner`             | `@planner`       | Same spec.json + plan-db           |
| `/execute {id}`        | `@execute`       | Same TDD, one task at a time       |
| Thor subagent          | `@validate`      | Same 8 gates, but shared context   |
| `Task` tool (parallel) | N/A              | No parallel subagent spawning      |
| preCompact hook        | N/A              | Auto-compaction at 95%, no control |

## Hooks Comparison

| Hook Type     | Claude Code                                               | Copilot CLI                       |
| ------------- | --------------------------------------------------------- | --------------------------------- |
| preToolUse    | worktree-guard, prefer-ci-summary, warn-bash-antipatterns | worktree-guard, enforce-standards |
| postToolUse   | enforce-line-limit, auto-format                           | enforce-line-limit                |
| sessionStart  | —                                                         | —                                 |
| sessionEnd    | session-end-tokens                                        | session-tokens                    |
| subagentStart | inject-agent-context                                      | N/A                               |
| preCompact    | preserve-context                                          | N/A                               |
| errorOccurred | —                                                         | — (available but unused)          |

## Token Tracking

Copilot sessions record to dashboard.db with `agent='copilot-cli'`.
Query: `SELECT * FROM token_usage WHERE agent='copilot-cli' ORDER BY id DESC;`
Dashboard at http://localhost:31415 shows both Claude Code and Copilot costs.

## Sync & Maintenance

```bash
copilot-sync.sh status   # Check alignment drift
copilot-sync.sh sync     # Fix model refs, ensure symlinks, chmod hooks
```

Run `copilot-sync.sh status` periodically or after updating CLAUDE.md/rules.

## Instruction Loading Order

1. `~/.copilot/copilot-instructions.md` — global rules (always loaded)
2. `.github/copilot-instructions.md` — project rules (combined, not override)
3. `.github/instructions/*.instructions.md` — path-specific (via `applyTo` glob)
4. `CLAUDE.md` — recognized by Copilot as agent-specific instructions

## Rigour Gap Analysis

### Where rigour is EQUAL

- **Hook enforcement**: same preToolUse/postToolUse guardrails
- **Plan DB**: same database, same commands, same validation
- **TDD workflow**: same RED-GREEN-REFACTOR in execute.agent.md
- **8 validation gates**: same checklist in validate.agent.md
- **Worktree discipline**: same guards, same scripts
- **Digest scripts**: same token-efficient wrappers

### Where rigour is LOWER

1. **Thor is NOT independent**. In Claude Code, Thor runs as a separate
   subagent with fresh context — no confirmation bias from seeing the
   executor's work. In Copilot, `@validate` shares the session context.
   **Mitigation**: close executor session, open new one, run `@validate`.

2. **No mechanical workflow enforcement**. Claude Code hooks (`subagentStart`)
   force the sequence (mark in_progress -> TDD -> stale check -> mark done).
   Copilot follows agent instructions but no hook blocks skipped steps.
   If the model "forgets" a step, nothing stops it mechanically.

3. **Compaction loses context**. In long sessions (many tasks), auto-compaction
   at 95% may drop plan details. Claude Code's `preserve-context` hook saves
   critical state. Copilot has no equivalent.
   **Mitigation**: run `/compact` manually between waves; keep sessions short.

4. **Sequential only**. A 12-task plan runs ~4 at a time with Claude Code
   (Kitty). With Copilot, strictly one-by-one. Longer sessions = higher
   compaction risk.

## Known Limitations

1. **No subagent spawning**: `@agent` runs in same session, not parallel
2. **No preCompact**: auto-compaction at 95% without user hook
3. **No subagentStart**: can't inject context into built-in Explore/Task
4. **Shared context for validation**: `@validate` sees executor context
5. **No parallel workers**: copilot-worker.sh runs one instance at a time
6. **Instruction caching**: edit instructions requires restart or `/resume`
