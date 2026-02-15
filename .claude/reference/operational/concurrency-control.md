<!-- v2.0.0 | 15 Feb 2026 | Token-optimized per ADR 0009 -->

# Concurrency Control

> **Why**: Multi-agent file edits cause silent overwrites. File locking prevents data loss. Stale checks detect external changes before commit. Merge queue prevents race conditions.

## Sequence for Multi-Agent Parallel Work

1. **Planner**: `wave-overlap.sh check-spec spec.json` before import (blocks critical overlap)
2. **Executor start**: `file-lock.sh acquire <file> <task_id>` for each target file
3. **Executor start**: `stale-check.sh snapshot <task_id> <files...>` to record baseline
4. **Before commit**: `stale-check.sh check <task_id>` (BLOCKS if files changed externally)
5. **On task done**: `plan-db-safe.sh` auto-releases locks + checks staleness
6. **Merge**: `merge-queue.sh enqueue <branch>` then `merge-queue.sh process --validate`

## Violations

- **Direct merge without queue = VIOLATION.** Only `merge-queue.sh process` merges to main.
- Skipping file-lock on shared files = risk of silent overwrite.
- Committing without stale-check = risk of overwriting other agent's work.
