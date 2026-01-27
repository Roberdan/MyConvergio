# Model Strategy & Assignment

## Phase-Model Mapping

| Phase | Standard Mode | Max Parallel |
|-------|---------------|--------------|
| Planning | opus | opus |
| Coordination | sonnet | **opus** |
| Execution | haiku | haiku |
| Validation | sonnet | sonnet |

## Model Selection (MANDATORY per task)

Planner assigns model to EACH task during planning phase.
Executor uses EXACTLY the model specified (no override).

If task scope changes during execution → re-plan, don't auto-escalate.

## Assignment Criteria

| Complexity | Model | Criteria |
|------------|-------|----------|
| **Simple** | `haiku` | 1-2 file, logica lineare, test esistenti, no architettura |
| **Medium** | `sonnet` | 3+ file, logica condizionale, nuovi test, API changes |
| **High** | `opus` | Cross-cutting, architettura, breaking changes, security |

## Examples

**haiku**:
- Fix typo
- Aggiorna costante
- Modifica testo UI
- Aggiungi campo form

**sonnet**:
- Nuovo endpoint API
- Refactor componente
- Integrazione servizio

**opus**:
- Nuovo sistema auth
- Migrazione DB
- Redesign architettura

## Context Isolation (Token Optimization)

- **task-executor**: FRESH session per task. No parent context inheritance.
- **thor**: FRESH session per validation. Skeptical, reads everything.
- **Benefit**: 50-70% token reduction vs inherited context
- **MCP**: task-executor has WebSearch/WebFetch disabled

## DB Registration

```bash
# MANDATORY: specify --model for EVERY task
plan-db.sh add-task {db_wave_id} T1-01 "Desc" P1 feature --model haiku
plan-db.sh add-task {db_wave_id} T1-02 "Complex" P1 feature --model sonnet
plan-db.sh add-task {db_wave_id} T1-03 "Arch change" P0 feature --model opus

# Shorthand (model as last arg)
plan-db.sh add-task {db_wave_id} T1-01 "Desc" P1 feature haiku
```
