# Multi-Claude Parallel Orchestration

Run multiple Claude instances in parallel for faster execution of complex plans.

## Quick Start

```bash
# Auto-detects terminal (Kitty or tmux)
./scripts/orchestration/orchestrate.sh 4

# With a plan file
./scripts/orchestration/orchestrate.sh 4 docs/plans/MyPlan.md
```

## Terminal Support

| Terminal | How It Works | Setup Required |
|----------|--------------|----------------|
| **Kitty** | `kitty @ send-text` | Enable remote control |
| **Zed/Warp/iTerm** | tmux sessions | Install tmux |
| **tmux** | `tmux send-keys` | Already installed |

The `orchestrate.sh` script auto-detects your terminal and uses the right method.

## Scripts

### Universal
| Script | Description |
|--------|-------------|
| `orchestrate.sh [N] [plan]` | **Main entry point** - auto-detects terminal |
| `detect-terminal.sh` | Detect terminal type (kitty/tmux/plain) |

### Kitty-specific
| Script | Description |
|--------|-------------|
| `kitty-check.sh` | Verify Kitty is configured correctly |
| `claude-parallel.sh [N]` | Launch N Claude tabs in Kitty |
| `claude-monitor.sh` | Monitor Kitty workers |

### tmux-specific
| Script | Description |
|--------|-------------|
| `tmux-parallel.sh [N]` | Launch N Claude windows in tmux |
| `tmux-monitor.sh` | Monitor tmux workers |
| `tmux-send-all.sh "msg"` | Broadcast to all tmux workers |

## Setup

### For Kitty Users

1. **Enable remote control** in `~/.config/kitty/kitty.conf`:
   ```
   allow_remote_control yes
   ```

2. **Restart Kitty** (Cmd+Q, then reopen)

3. **Verify**:
   ```bash
   ./scripts/orchestration/kitty-check.sh
   ```

### For Zed/Warp/Other Users

1. **Install tmux**:
   ```bash
   brew install tmux
   ```

2. **Verify**:
   ```bash
   tmux -V
   ```

### For All Users

Add wildClaude alias to `~/.zshrc`:
```bash
alias wildClaude='claude --dangerously-skip-permissions'
```

## Usage Examples

### From Kitty

```bash
./scripts/orchestration/claude-parallel.sh 4

# Send tasks
kitty @ send-text --match title:Claude-2 "Do task X" && kitty @ send-key --match title:Claude-2 Return
```

### From Zed/Warp/Any Terminal

```bash
./scripts/orchestration/tmux-parallel.sh 4

# Send tasks
tmux send-keys -t claude-workers:Claude-2 "Do task X" Enter

# Attach to see workers
tmux attach -t claude-workers
```

### tmux Navigation

When attached:
- `Ctrl+B` then `1-4` → Jump to window
- `Ctrl+B` then `n/p` → Next/Previous window
- `Ctrl+B` then `d` → Detach (workers keep running)

## Zed Integration

Add to `~/.config/zed/keymap.json`:
```json
{
  "cmd-shift-o": ["task::Spawn", { "task_name": "claude-orchestrate" }],
  "cmd-shift-m": ["task::Spawn", { "task_name": "claude-monitor" }]
}
```

Add to `~/.config/zed/tasks.json`:
```json
{
  "label": "claude-orchestrate",
  "command": "~/.claude/scripts/tmux-parallel.sh 4 && sleep 2 && tmux attach -t claude-workers",
  "use_new_terminal": true
}
```

## Plan Format

For parallel execution, plans must include Claude assignments:

```markdown
## 🎭 RUOLI CLAUDE

| Claude | Role | Tasks | Files (NO OVERLAP!) |
|--------|------|-------|---------------------|
| CLAUDE 1 | Coordinator | Monitor, verify | - |
| CLAUDE 2 | Implementer | T-01, T-02 | src/api/*.ts |
| CLAUDE 3 | Implementer | T-03, T-04 | src/components/*.tsx |
| CLAUDE 4 | Implementer | T-05, T-06 | src/lib/*.ts |
```

## Critical Rules

1. **MAX 4 CLAUDE** - Beyond this becomes unmanageable
2. **NO FILE OVERLAP** - Each Claude works on different files to avoid git conflicts
3. **VERIFICATION LAST** - Final step always runs lint/typecheck/build
4. **ONE COMMIT AT A TIME** - Coordinate commits to avoid conflicts

## Troubleshooting

### tmux: "Session not found"
```bash
tmux kill-session -t claude-workers  # Clean up
./scripts/orchestration/tmux-parallel.sh 4  # Restart
```

### Kitty: "Cannot connect to remote control"
1. Check config has `allow_remote_control yes`
2. Restart Kitty completely (Cmd+Q, then reopen)

### "wildClaude alias not found"
```bash
echo "alias wildClaude='claude --dangerously-skip-permissions'" >> ~/.zshrc
source ~/.zshrc
```
