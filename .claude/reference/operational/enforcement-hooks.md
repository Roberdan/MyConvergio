<!-- v1.0.0 -->

# Enforcement Hooks

| Hook                   | Event         | Trigger              | Action                     | Claude Code        | Copilot CLI           |
| ---------------------- | ------------- | -------------------- | -------------------------- | ------------------ | --------------------- |
| guard-plan-mode        | PreToolUse    | EnterPlanMode        | Block (exit 2 / deny)      | Yes (matcher)      | Yes (internal filter) |
| enforce-plan-db-safe   | PreToolUse    | plan-db.sh done      | Block                      | Yes (Bash matcher) | Yes (bash filter)     |
| enforce-plan-edit      | PreToolUse    | Edit plan files      | Block unless task-executor | Yes (Edit matcher) | Yes (edit filter)     |
| worktree-guard         | PreToolUse    | git on main          | Warn/Block                 | Yes                | Yes                   |
| session-file-lock      | PreToolUse    | Edit/Write           | Lock file                  | Yes                | Yes                   |
| prefer-ci-summary      | PreToolUse    | Raw npm/gh commands  | Block (exit 2)             | Yes                | Yes                   |
| warn-bash-antipatterns | PreToolUse    | Bash unsafe patterns | Warn/Block                 | Yes                | Yes                   |
| guard-settings         | PostToolUse   | settings.json edit   | Auto-strip codegraph hooks | Yes                | Yes                   |
| enforce-line-limit     | PostToolUse   | File > 250 lines     | Warn                       | Yes                | Yes                   |
| auto-format            | PostToolUse   | File write           | Format                     | Yes                | Yes                   |
| verify-before-claim    | PostToolUse   | Success claim        | Warn if unverified         | Yes                | Yes                   |
| secret-scanner         | PreCommit     | Commit with secrets  | Block                      | Yes                | No                    |
| env-vault-guard        | PreCommit     | .env commit          | Block                      | Yes                | No                    |
| session-end-tokens     | Stop          | Session close        | Record tokens              | Yes                | No                    |
| inject-agent-context   | SubagentStart | Subagent spawn       | Inject context             | Yes                | No                    |
| preserve-context       | PreCompact    | Context compaction   | Preserve critical content  | Yes                | No                    |
| model-registry-refresh | Setup         | Session start        | Refresh model list         | Yes                | No                    |
| version-check          | Setup         | Session start        | Check component versions   | Yes                | No                    |

## Non-portable (Claude Code only, no Copilot event)

- **PreCommit**: secret-scanner, env-vault-guard
- **Setup**: model-registry-refresh, version-check
- **SubagentStart**: inject-agent-context
- **PreCompact**: preserve-context

## Portable (hooks aligned across both platforms)

guard-plan-mode, enforce-plan-db-safe, enforce-plan-edit, worktree-guard, session-file-lock, prefer-ci-summary, warn-bash-antipatterns, enforce-line-limit, auto-format, guard-settings, verify-before-claim + session tracking equivalents.
