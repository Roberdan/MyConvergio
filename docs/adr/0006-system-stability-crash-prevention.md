# ADR-0006: System Stability and Crash Prevention

Status: Accepted | Date: 09 Febbraio 2026

## Context

Mac crashed overnight (09 Feb 2026 02:54 CET). Investigation found: boot reason `gcb_off_wakeup` (watchdog restart, not kernel panic), no `.panic` files in DiagnosticReports, no clean shutdown record. Root cause: sustained CPU load from idle Claude Code sessions (~430% CPU across 2 claude processes) combined with Microsoft Defender scanning all generated files (~70% CPU across 3 Defender processes) on macOS 26.2 Tahoe. Multiple `caffeinate` processes kept the Mac awake under load all night.

## Decision

### Microsoft Defender Exclusions

Added folder and process exclusions to eliminate unnecessary scanning of development artifacts:

| Type    | Exclusion               | Rationale                                  |
| ------- | ----------------------- | ------------------------------------------ |
| Folder  | `~/GitHub`              | All project repositories                   |
| Folder  | `~/.claude`             | Scripts, config, SQLite databases          |
| Folder  | `~/.local/share/claude` | Claude Code binaries and data              |
| Folder  | `~/.npm`                | npm cache and packages                     |
| Folder  | `/tmp`                  | Temporary files from builds and tests      |
| Process | `claude`                | Claude Code CLI process                    |
| Process | `node`                  | Node.js runtime (builds, tests, dashboard) |

Applied via `sudo mdatp exclusion folder/process add`. Reduces Defender CPU from ~70% to near-zero for dev workloads.

### Idle Session Cleanup (`session-cleanup.sh`)

Script kills orphaned `caffeinate` processes older than a configurable threshold (default: 2 hours). `caffeinate` is spawned by Claude Code to prevent system sleep during active work, but persists after sessions become idle.

Cron job installed: runs hourly 23:00-06:00 with 60-minute threshold.

```
0 23,0,1,2,3,4,5,6 * * * ~/.claude/scripts/session-cleanup.sh --max-idle 60
```

Log output at `/tmp/session-cleanup.log`.

## Consequences

- Positive: ~70% CPU reduction from Defender exclusions (immediate). Overnight idle sessions auto-cleaned (prevents sustained load). Crash root cause documented for future reference.
- Negative: Defender exclusions reduce security scanning coverage for dev directories (acceptable tradeoff: source code is version-controlled, dependencies are audited via `audit-digest.sh`). Cron job may kill legitimate long-running sessions if they exceed threshold.

## Enforcement

- Check: `mdatp exclusion list` (must show 5 folders + 2 processes)
- Check: `crontab -l` (must show session-cleanup.sh entry)
- Check: `ps -eo pcpu,comm -r | head -5` (claude/Defender should not dominate)
