# Brain Tracking Hooks

Auto-tracks all tool activity for brain visualization.

## Setup (add to ~/.claude/settings.json)

```json
{
  "hooks": {
    "PostToolUse": [
      { "command": "bash ~/.claude-plan-100022/hooks/track-agent-activity.sh" }
    ],
    "Stop": [
      { "command": "bash ~/.claude-plan-100022/hooks/track-session-stop.sh" }
    ],
    "PreCompact": [
      { "command": "bash ~/.claude-plan-100022/hooks/track-precompact.sh" }
    ]
  }
}
```

## What gets tracked

| Hook | Triggers on | Brain region |
|------|-------------|-------------|
| PostToolUse (task) | Agent spawn/complete | Motor cortex |
| PostToolUse (edit) | File modifications | Right parietal |
| PostToolUse (bash) | Shell commands | Session pulse |
| Stop | Response complete | Prefrontal |
| PreCompact | Context compaction | Hippocampus |

## No-cost guarantee

All hooks are pure SQLite writes (~0.001s each). Zero tokens, zero latency.
Hooks exit 0 always — never block tool execution.
All DB writes use `2>/dev/null || true` — missing DB = silent skip.
