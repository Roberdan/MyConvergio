<!-- v2.0.0 | 15 Feb 2026 | Token-optimized per ADR 0009 -->

# Copilot CLI Alignment

GitHub Copilot CLI as Claude Code alternative reference.

## Decision Matrix

| Plan Size | Waves     | Use         | Why                                                  |
| --------- | --------- | ----------- | ---------------------------------------------------- |
| 1-6 task  | 1-2       | Copilot CLI | Sufficiente rigore, risparmia token                  |
| 7+ task   | 3+        | Claude Code | Thor indipendente + parallelo + context preservation |
| Qualsiasi | Parallele | Claude Code | No parallel worker spawning in Copilot               |

## Use Copilot CLI When

- Piani piccoli (1-6 task, 1-2 wave)
- Sequential tasks (TDD, review, validation one at a time)
- Save Claude Max tokens for complex work
- Same model (claude-opus-4.6 or claude-opus-4.6-1m), same quality

## Use Claude Code Instead

- Piani grandi (7+ task) — compaction risk
- Parallel orchestration (Kitty multi-worker, 3-4 executors)
- Thor as independent subagent (fresh context, zero trust)
- preCompact control (context preservation)
- Deep skill workflows (`/planner`, `/execute` multi-step)

## Architecture

```
~/.copilot/
  config.json, copilot-instructions.md, hooks.json, mcp-config.json
  hooks/: enforce-standards.sh, worktree-guard.sh, enforce-line-limit.sh, session-tokens.sh
  agents/ (symlinks): prompt, planner, execute, validate → ~/.claude/copilot-agents/

MirrorBuddy/.github/
  copilot-instructions.md (246 lines), agents/ (4), instructions/ (9), prompts/ (6), skills/ (2)
```

## Workflow Mapping

| Claude Code            | Copilot CLI      | Notes                              |
| ---------------------- | ---------------- | ---------------------------------- |
| `/prompt`              | `@prompt "desc"` | Same F-xx extraction               |
| `/planner`             | `@planner`       | Same spec.json + plan-db           |
| `/execute {id}`        | `@execute`       | Same TDD, one at a time            |
| Thor subagent          | `@validate`      | Same 9 gates, shared context       |
| `Task` tool (parallel) | N/A              | No parallel spawning               |
| preCompact hook        | N/A              | Auto-compaction at 95%, no control |

## Hooks Comparison

| Hook          | Claude Code                                  | Copilot CLI                       |
| ------------- | -------------------------------------------- | --------------------------------- |
| preToolUse    | worktree-guard, prefer-ci-summary, warn-bash | worktree-guard, enforce-standards |
| postToolUse   | enforce-line-limit, auto-format              | enforce-line-limit                |
| sessionEnd    | session-end-tokens                           | session-tokens                    |
| subagentStart | inject-agent-context                         | N/A                               |
| preCompact    | preserve-context                             | N/A                               |

## Token Tracking

Sessions record to dashboard.db with `agent='copilot-cli'`.
Query: `SELECT * FROM token_usage WHERE agent='copilot-cli' ORDER BY id DESC;`
Dashboard: http://localhost:31415

## Sync & Maintenance

```bash
copilot-sync.sh status   # Alignment drift check
copilot-sync.sh sync     # Fix model refs, symlinks, chmod hooks
```

Run `status` after updating CLAUDE.md/rules.

## Instruction Loading Order

1. `~/.copilot/copilot-instructions.md` — global (always loaded)
2. `.github/copilot-instructions.md` — project (combined, not override)
3. `.github/instructions/*.instructions.md` — path-specific (`applyTo` glob)
4. `CLAUDE.md` — recognized as agent-specific

## Rigour Gap Analysis

### Equal Rigour

- Hook enforcement: same preToolUse/postToolUse
- Plan DB: same database, commands, validation
- TDD: same RED-GREEN-REFACTOR in execute.agent.md
- 9 gates: same checklist in validate.agent.md
- Worktree discipline: same guards, scripts
- Digest scripts: same token-efficient wrappers

### Lower Rigour

1. **Thor NOT independent**: `@validate` shares session context (confirmation bias). **Mitigation**: close executor, open new session, run `@validate`.
2. **No mechanical workflow enforcement**: No `subagentStart` hook to block skipped steps.
3. **Compaction loses context**: Auto-compact at 95% may drop plan details. No `preserve-context` hook. **Mitigation**: `/compact` manually between waves.
4. **Sequential only**: 12-task plan → 1 at a time (vs 4 parallel with Claude Code). Longer sessions = higher compaction risk.

## Known Limitations

- No subagent spawning: `@agent` runs in same session, not parallel
- No preCompact: auto-compaction at 95% without user hook
- No subagentStart: can't inject context into built-in Explore/Task
- Shared context for validation: `@validate` sees executor context
- No parallel workers: copilot-worker.sh runs one instance at a time
- Instruction caching: edit instructions requires restart or `/resume`
