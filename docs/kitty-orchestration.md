# Multi-Claude Orchestration (Kitty + tmux)

> Reference: `@docs/kitty-orchestration.md` when needed

## TL;DR

**From Kitty:**
1. Apri Kitty (not Warp)
2. `wildClaude`
3. `/planner` per piano con assegnazioni
4. "Esegui in parallelo"

**From Zed/Any Terminal:**
1. `~/.claude/scripts/tmux-parallel.sh 4`
2. `tmux attach -t claude-workers`
3. Send tasks via `tmux send-keys`

## Terminal Detection

The planner auto-detects your terminal:

| Terminal | Detection | Orchestration |
|----------|-----------|---------------|
| Kitty | `$KITTY_PID` | `kitty @ send-text` |
| tmux | `$TMUX` | `tmux send-keys` |
| Zed/Warp/other | tmux available | Launch tmux session |

## Prerequisites

### Kitty
```bash
# ~/.config/kitty/kitty.conf
allow_remote_control yes

# Verify (from Kitty):
~/.claude/scripts/kitty-check.sh
```

### tmux
```bash
# Install
brew install tmux

# Verify
tmux -V
```

## Commands

### Kitty Scripts
| Script | Usage |
|--------|-------|
| `~/.claude/scripts/orchestrate.sh <plan>` | Full orchestration |
| `~/.claude/scripts/claude-parallel.sh [N]` | Launch N tabs |
| `~/.claude/scripts/claude-monitor.sh` | Monitor workers |

### tmux Scripts
| Script | Usage |
|--------|-------|
| `~/.claude/scripts/tmux-parallel.sh [N]` | Launch N windows |
| `~/.claude/scripts/tmux-monitor.sh` | Monitor workers |
| `~/.claude/scripts/tmux-send-all.sh "msg"` | Broadcast to all |
| `~/.claude/scripts/detect-terminal.sh` | Detect terminal type |

## Quick Start

### Kitty
```bash
~/.claude/scripts/claude-parallel.sh 4
kitty @ send-text --match title:Claude-1 "Do task X" && kitty @ send-key --match title:Claude-1 Return
kitty @ send-text --match title:Claude-2 "Do task Y" && kitty @ send-key --match title:Claude-2 Return
```

### tmux (from any terminal)
```bash
~/.claude/scripts/tmux-parallel.sh 4
tmux send-keys -t claude-workers:Claude-1 "Do task X" Enter
tmux send-keys -t claude-workers:Claude-2 "Do task Y" Enter

# Attach to see all workers
tmux attach -t claude-workers
```

## Zed Integration

### Keyboard Shortcuts
| Shortcut | Action |
|----------|--------|
| `Cmd+Shift+O` | Launch 4 Claude workers |
| `Cmd+Shift+M` | Monitor workers |
| `Cmd+Shift+A` | Attach to tmux session |

### Tasks (via Cmd+Shift+P → "task")
- `claude-orchestrate` - Launch 4 workers
- `claude-monitor` - View worker status
- `claude-attach` - Attach to session

## Remote Control Reference

### Kitty
```bash
kitty @ ls                                    # List tabs
kitty @ get-text --match title:Claude-2       # Read output
kitty @ send-text --match title:Claude-2 "X"  # Send text
kitty @ send-key --match title:Claude-2 Return # Press Enter
kitty @ focus-tab --match title:Claude-2      # Focus tab
```

### tmux
```bash
tmux list-sessions                           # List sessions
tmux list-windows -t claude-workers          # List windows
tmux send-keys -t claude-workers:Claude-2 "X" Enter  # Send + execute
tmux select-window -t claude-workers:Claude-2        # Focus window
tmux capture-pane -t claude-workers:Claude-2 -p      # Read output
```

## Rules

- Tasks MUST touch different files (avoid git conflicts)
- Uses `wildClaude` alias (--dangerously-skip-permissions)
- Max 4 Claude instances (hard limit)
- Kitty orchestration only works FROM Kitty terminal
- tmux orchestration works from ANY terminal (including Zed)

## Troubleshooting

### tmux session already exists
```bash
tmux kill-session -t claude-workers  # Kill existing
~/.claude/scripts/tmux-parallel.sh 4 # Restart
```

### Can't send commands to tmux
```bash
# Verify session exists
tmux has-session -t claude-workers && echo "OK" || echo "No session"

# Check window names
tmux list-windows -t claude-workers -F "#W"
```

### Kitty remote control not working
```bash
# Check if enabled
grep "allow_remote_control" ~/.config/kitty/kitty.conf
# Should show: allow_remote_control yes
```
