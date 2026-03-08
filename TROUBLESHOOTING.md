# Troubleshooting

## Dashboard web task execution

- Ensure `PATH` includes `~/.claude/scripts` before running plan-db and guard scripts.
- Verify worktree guard passes before edits: `worktree-guard.sh <repo>`.
- Re-run preflight if readiness warnings appear: `execution-preflight.sh --plan-id 100025 <repo>`.
