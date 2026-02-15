---
name: parallelization-modes
version: "1.0.0"
---

# Parallelization Modes

## Mode Selection (MANDATORY)

At plan approval, ASK user via AskUserQuestion:

```
Modalità di esecuzione:
1. Standard (3 task paralleli) - Bilanciata, costi moderati
2. Massima Parallelizzazione - Veloce, costi elevati, Opus orchestration

Quale modalità preferisci?
```

## Mode 1: Standard (Default)

| Setting     | Value                                 |
| ----------- | ------------------------------------- |
| Concurrency | Max 3 task-executor                   |
| Coordinator | Sonnet                                |
| Task Model  | Sonnet (default), Haiku solo triviali |
| Cost        | $ moderato                            |
| Speed       | ⚡⚡ normale                          |

**Execution Logic**:

- Batch tasks in groups of 3
- Run parallel within batch
- Thor validates after each wave

## Mode 2: Massima Parallelizzazione

| Setting     | Value                                 |
| ----------- | ------------------------------------- |
| Concurrency | Unlimited                             |
| Coordinator | **OPUS** (required)                   |
| Task Model  | Sonnet (default), Haiku solo triviali |
| Cost        | $$$ elevato                           |
| Speed       | ⚡⚡⚡⚡ (3-5x faster)                |

**Use case**: Deadline stretti, piani grandi (10+ task)

**Execution Logic**:

- ALL independent tasks launch simultaneously
- Wave-level parallelization
- Opus coordinator manages N task-executors
- Thor validates after each wave (same as standard)

**CRITICAL**: Se user sceglie Mode 2, upgrade coordinator a Opus.

## Token/Cost Estimates

| Mode         | Per Batch      | Per Wave           |
| ------------ | -------------- | ------------------ |
| Standard     | ~90K tokens    | ~90K × batches     |
| Max Parallel | ~30K × N tasks | +50K Opus overhead |

## Store Mode

```bash
sqlite3 ~/.claude/data/dashboard.db \
  "UPDATE plans SET parallel_mode='$MODE' WHERE id=$PLAN_ID;"
```
