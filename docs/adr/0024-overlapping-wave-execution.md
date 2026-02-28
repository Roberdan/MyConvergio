# ADR 0024: Overlapping Wave Execution Protocol

Status: Accepted | Date: 2026-02-27

## Context

`wave-worktree.sh merge` blocks 20-60 minutes per wave waiting for CI (5-15m) + PR review/fix (10-30m) + re-CI (5-15m). During this time the executor is idle. For a 4-wave plan, this wastes 1-4 hours.

Analysis of Plans 246-262 (VirtualBPM) and Plans 220-224 (MirrorBuddy) confirmed the bottleneck: the synchronous merge flow (`gh pr checks --watch` + `pr-ops.sh ready`) blocks wave transitions even when waves have no code dependency on PR review outcomes.

## Decision

Add **non-blocking wave transitions** via three new components:

| Component | File | Purpose |
|-----------|------|---------|
| `merge-async` | `wave-worktree.sh` | Push + create PR + return immediately |
| `pr-sync` | `wave-worktree.sh` | Verify prev PR merged, rebase current wave, extract feedback |
| Feedback injection | `copilot-task-prompt.sh` | Inject PR review comments into next wave task prompts |

### Flow

```
Wave N tasks done → merge-async (returns immediately)
                 → Wave N+1 branches from Wave N tip, starts immediately
                 → [background: CI + review + merge of Wave N]
                 → Before closing Wave N+1: pr-sync
                   → If merged: rebase onto main, inject feedback
                   → If conflict: STOP, manual resolution
                   → If still open: continue, sync later
```

### Precondition type added

`{type: wave_pr_created, wave_id: W1}` — allows next wave to start once PR exists (vs `wave_status: done` which requires full merge).

### Safety guarantees

- Existing `merge` command unchanged (backward compatible)
- Rebase conflicts → automatic abort + manual fallback
- PR closed without merge → error, stops execution
- DB tracks `merge_mode` (sync|async) per wave
- Feedback file stored at `~/.claude/data/pr-feedback-wave-{id}.txt`

## Consequences

- **Positive**: 20-60 min saved per wave transition; feedback from PR reviews propagates to next wave
- **Negative**: Rebase conflicts possible if PR review changes conflict with next wave work
- **Risk**: If PR is rejected entirely, Wave N+1 work may need to be redone (same risk exists with sync flow, just delayed)
