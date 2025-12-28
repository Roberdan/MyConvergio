# Multi-Claude Parallel Orchestration

Run multiple Claude instances in parallel for faster execution of complex plans.

## Requirements

### Kitty Terminal (MANDATORY)

These scripts **only work with Kitty terminal**. They will NOT work with:
- ❌ Warp
- ❌ iTerm2
- ❌ Terminal.app
- ❌ Ghostty (no remote control yet)

**Why Kitty?** It's the only terminal with robust remote control API that allows:
- Creating new tabs programmatically
- Sending text to specific tabs
- Reading output from tabs
- All without user interaction

### Setup

1. **Install Kitty** (if not installed):
   ```bash
   brew install --cask kitty
   ```

2. **Enable remote control** in `~/.config/kitty/kitty.conf`:
   ```
   allow_remote_control yes
   listen_on unix:/tmp/kitty-socket
   ```

3. **Restart Kitty** (required after config change):
   ```bash
   # Close Kitty completely (Cmd+Q), then reopen
   ```

4. **Add wildClaude alias** to `~/.zshrc`:
   ```bash
   alias wildClaude='claude --dangerously-skip-permissions'
   ```

5. **Verify setup**:
   ```bash
   ./scripts/orchestration/kitty-check.sh
   ```

## Scripts

| Script | Description |
|--------|-------------|
| `kitty-check.sh` | Verify Kitty is configured correctly |
| `claude-parallel.sh [N]` | Launch N Claude instances (default: 4) |
| `claude-monitor.sh [sec]` | Monitor all Claude workers (refresh every N seconds) |

## Usage

### From Kitty terminal:

```bash
# 1. Check setup
./scripts/orchestration/kitty-check.sh

# 2. Launch 4 Claude workers
./scripts/orchestration/claude-parallel.sh 4

# 3. Send tasks to each worker
kitty @ send-text --match title:Claude-2 "Read plan.md, you are CLAUDE 2, execute your tasks"
kitty @ send-text --match title:Claude-3 "Read plan.md, you are CLAUDE 3, execute your tasks"
kitty @ send-text --match title:Claude-4 "Read plan.md, you are CLAUDE 4, execute your tasks"

# 4. Monitor progress
./scripts/orchestration/claude-monitor.sh
```

### With strategic-planner agent:

```bash
# From Kitty:
wildClaude

# Then ask:
@strategic-planner Create a plan for [task] and execute in parallel
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

### "Run from inside Kitty terminal"
You're running from Warp/iTerm. Open Kitty and run from there.

### "Cannot connect to Kitty remote control"
1. Check config has `allow_remote_control yes`
2. Restart Kitty completely (Cmd+Q, then reopen)

### "wildClaude alias not found"
Add to `~/.zshrc`:
```bash
alias wildClaude='claude --dangerously-skip-permissions'
```
Then: `source ~/.zshrc`
