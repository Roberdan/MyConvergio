# ADR 0022: Session Reaper — Orphan Process Cleanup

Status: Accepted | Date: 27 Feb 2026

## Context

Claude Code spawns `/bin/zsh -c source ~/.claude/shell-snapshots/snapshot-zsh-*.sh && ...` processes for every Bash tool call. Copilot CLI spawns similar processes writing to `/tmp/claude-*-cwd` files. When sessions end, compact, or crash, child processes become orphaned (reparented to PID 1) and accumulate indefinitely.

Observed impact: 38GB swap consumed by zombie pytest processes (~1.1GB each) and orphan sleep processes from stale sessions. Killing them recovered 32GB swap.

Root cause: no cleanup mechanism existed for session-end process termination.

## Decision

**Three-layer defense against orphaned AI agent shell processes:**

| Layer | Mechanism                   | Trigger     | Max-age       | Coverage                 |
| ----- | --------------------------- | ----------- | ------------- | ------------------------ |
| 1     | Claude Code Stop hook       | Session end | 0 (immediate) | Claude Code processes    |
| 2     | Copilot CLI sessionEnd hook | Session end | 0 (immediate) | Copilot CLI processes    |
| 3     | launchd periodic agent      | Every 5 min | 10 min        | Safety net (all orphans) |

All three layers delegate to a single central script: `scripts/session-reaper.sh`.

### Detection Patterns

| Pass | Pattern                                     | Catches                            |
| ---- | ------------------------------------------- | ---------------------------------- |
| 1    | `shell-snapshots/snapshot` in command line  | Claude Code Bash processes         |
| 2    | `claude-[a-zA-Z0-9_-]+-cwd` in command line | Copilot CLI / delegation processes |

### Orphan Criteria

A process is killed only if ALL conditions are met:

1. Matches a detection pattern
2. Age >= `--max-age` minutes (default 10, hooks use 0)
3. Is orphaned: `ppid=1` OR parent command doesn't contain `claude|copilot|github-copilot`

Exception: `--snapshot <name>` mode kills all matching processes regardless of orphan status (used for targeted cleanup).

### zsh exec Optimization

zsh `-c` replaces itself with the last command (`exec` optimization). The real Claude pattern includes `< /dev/null && pwd -P >|` suffix which prevents this, keeping zsh as a visible wrapper in `ps`. This is critical for Pass 1 detection.

## Files

| File                                                     | Purpose                                                                                        |
| -------------------------------------------------------- | ---------------------------------------------------------------------------------------------- |
| `scripts/session-reaper.sh`                              | Central reaper (v2.0.0): two-pass detection, orphan check, process tree kill, JSON output, log |
| `hooks/session-reaper.sh`                                | Claude Code Stop hook: async `--max-age 0`                                                     |
| `copilot-config/hooks/session-reaper.sh`                 | Copilot CLI sessionEnd hook: async `--max-age 0`                                               |
| `~/Library/LaunchAgents/com.claude.session-reaper.plist` | launchd agent: every 300s, `--max-age 10`                                                      |

## Consequences

### Positive

- Eliminates orphan process accumulation (root cause of 38GB swap leak)
- Covers both Claude Code and Copilot CLI (including cross-delegation)
- Three layers ensure cleanup even if one mechanism fails
- launchd safety net catches processes from crashed sessions
- Stale snapshot files auto-cleaned (>2 days)

### Negative

- launchd agent runs every 5 min even when no sessions active (negligible overhead)
- Aggressive `--max-age 0` in hooks could theoretically kill a still-needed process during session overlap (mitigated: only kills orphans with dead parent)
