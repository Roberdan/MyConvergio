# MyConvergio Hooks

Enforcement hooks for Claude Code. These hooks integrate with Claude Code's hook system to enforce quality standards, optimize token usage, and maintain project discipline.

## Installation

Hooks are automatically installed to `~/.claude/hooks/` by `myconvergio install`. To activate them, add the hook configuration to your `~/.claude/settings.json` (see Settings Templates).

## Hook Reference

### PreToolUse (Bash)

| Hook                        | Purpose                                                                             | Exit    |
| --------------------------- | ----------------------------------------------------------------------------------- | ------- |
| `worktree-guard.sh`         | Blocks git operations on main/master when worktrees are active                      | 2=block |
| `prefer-ci-summary.sh`      | Blocks verbose commands (npm build, git status, gh run view), forces digest scripts | 2=block |
| `warn-bash-antipatterns.sh` | Warns when using bash for find/grep/cat/sed instead of dedicated tools              | 0=warn  |

### PostToolUse (Edit/Write)

| Hook                    | Purpose                                                                | Exit    |
| ----------------------- | ---------------------------------------------------------------------- | ------- |
| `enforce-line-limit.sh` | Blocks file writes that exceed 250 lines                               | 2=block |
| `auto-format.sh`        | Auto-formats code after write (prettier, black, shfmt, gofmt, rustfmt) | 0=pass  |

### SubagentStart

| Hook                      | Purpose                                                     |
| ------------------------- | ----------------------------------------------------------- |
| `inject-agent-context.sh` | Injects constitution and project context into all subagents |

### PreCompact

| Hook                  | Purpose                                                                          |
| --------------------- | -------------------------------------------------------------------------------- |
| `preserve-context.sh` | Preserves plan ID, F-xx requirements, and current task before context compaction |

### Stop

| Hook                    | Purpose                                                         |
| ----------------------- | --------------------------------------------------------------- |
| `session-end-tokens.sh` | Records final token usage to dashboard DB with cost calculation |

### Utility

| Hook                  | Purpose                                                 |
| --------------------- | ------------------------------------------------------- |
| `track-tokens.sh`     | Flexible token counter (CLI args, env vars, stdin JSON) |
| `debug-hook-input.sh` | Logs hook input to debug.log for troubleshooting        |

## Shared Library

`lib/common.sh` provides utilities used by all hooks:

- `have_bin` - Check if a binary exists
- `check_deps` - Verify required dependencies
- `log_hook` - Structured logging
- `json_field` - Extract JSON field (jq fallback to grep)
- Dashboard DB helpers (graceful degradation if no dashboard)

## Settings Configuration

Add to `~/.claude/settings.json`:

```json
{
  "hooks": {
    "PreToolUse": [
      {
        "matcher": "Bash",
        "hooks": [
          { "type": "command", "command": "~/.claude/hooks/worktree-guard.sh" },
          {
            "type": "command",
            "command": "~/.claude/hooks/prefer-ci-summary.sh"
          },
          {
            "type": "command",
            "command": "~/.claude/hooks/warn-bash-antipatterns.sh"
          }
        ]
      }
    ],
    "PostToolUse": [
      {
        "matcher": "Edit|MultiEdit|Write",
        "hooks": [
          {
            "type": "command",
            "command": "~/.claude/hooks/enforce-line-limit.sh"
          },
          { "type": "command", "command": "~/.claude/hooks/auto-format.sh" }
        ]
      }
    ],
    "SubagentStart": [
      {
        "hooks": [
          {
            "type": "command",
            "command": "~/.claude/hooks/inject-agent-context.sh"
          }
        ]
      }
    ],
    "PreCompact": [
      {
        "hooks": [
          {
            "type": "command",
            "command": "~/.claude/hooks/preserve-context.sh"
          }
        ]
      }
    ],
    "Stop": [
      {
        "hooks": [
          {
            "type": "command",
            "command": "~/.claude/hooks/session-end-tokens.sh"
          }
        ]
      }
    ]
  }
}
```

## Token Savings

The `prefer-ci-summary.sh` hook alone saves **~21k tokens (10.7%)** per session by forcing digest scripts instead of verbose CLI output. Combined with context isolation and the reference doc system, total savings exceed 50%.

## Dependencies

- `jq` - JSON processing (most hooks gracefully degrade without it)
- `sqlite3` - Dashboard DB writes (optional, hooks skip if unavailable)
- Formatter binaries (optional): `prettier`, `black`, `shfmt`, `gofmt`, `rustfmt`
