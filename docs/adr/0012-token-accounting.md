# ADR 0012: Token Accounting & Cost Attribution

**Status**: Accepted
**Date**: 21 Feb 2026
**Plan**: 189

## Context

Token usage directly impacts operational costs and resource allocation. The system executes tasks across multiple AI providers (Claude, Copilot, Codex, Gemini) with different pricing models and token multipliers. Without granular tracking, we cannot:

- Attribute costs to specific plans, waves, or tasks
- Identify expensive operations for optimization
- Validate model registry multipliers against actual usage
- Budget for multi-wave plan execution
- Audit provider billing accuracy

The plan database schema includes `token_usage` table (task_id, input_tokens, output_tokens, total_cost_usd, model, timestamp) but lacks enforcement and reporting tooling.

## Decision

### Token Tracking Requirements

| Layer | Requirement | Mechanism |
|-------|-------------|-----------|
| **Task level** | Record input/output tokens per task execution | plan-db.sh update-task accepts --token-usage JSON |
| **Wave level** | Aggregate tokens across all tasks in wave | plan-db.sh wave-summary computes sum |
| **Plan level** | Total cost across all waves | plan-db.sh cost-report --plan-id X |
| **Provider level** | Track actual vs. expected multipliers | Compare token_usage.total_cost_usd vs. (tokens × registry multiplier) |

### Cost Attribution Formula

```
total_cost_usd = (input_tokens × input_price) + (output_tokens × output_price)
```

Prices stored in `data/models-registry.json` per provider/model.

### Implementation Components

1. **Token collection**: Agents report token usage via `--token-usage '{"input":N,"output":M,"model":"X"}'`
2. **Cost calculation**: plan-db.sh computes cost using model registry prices
3. **Reporting**: 
   - `plan-db.sh cost-report --plan-id X` → total plan cost
   - `plan-db.sh wave-summary --wave-id Y` → wave-level breakdown
   - `plan-db.sh task-tokens --task-id Z` → single task detail
4. **Validation**: Compare actual costs vs. budgeted costs in plan metadata
5. **Drift detection**: Flag tasks with token usage >2× wave average for review

### Database Schema (Existing)

```sql
CREATE TABLE token_usage (
  id INTEGER PRIMARY KEY,
  task_id INTEGER NOT NULL,
  input_tokens INTEGER,
  output_tokens INTEGER,
  total_cost_usd REAL,
  model TEXT,
  timestamp TEXT,
  FOREIGN KEY(task_id) REFERENCES tasks(id)
);
```

## Consequences

### Positive
- **Cost transparency**: Per-task attribution enables optimization targeting
- **Budget control**: Real-time tracking prevents runaway costs
- **Audit trail**: Validates provider billing against recorded usage
- **Model selection**: Data-driven decisions on model routing (e.g., prefer Copilot 0x for low-stakes tasks)
- **Anomaly detection**: Flag tasks with unusual token consumption

### Negative
- **Reporting overhead**: Agents must capture and report token usage (2-5 lines per task)
- **Schema dependency**: Requires token_usage table migration (completed in plan 115)
- **Price maintenance**: model-registry.json must stay current with provider pricing changes

### Monitoring Strategy

| Metric | Threshold | Action |
|--------|-----------|--------|
| Task tokens | >10K input | Review task complexity |
| Wave cost | >$5 USD | Require manual approval for next wave |
| Model drift | Actual cost >20% vs. registry | Update model-registry.json |
| Plan budget | >80% consumed | Alert user before final wave |

## File Impact Table

| File | Purpose/Impact |
|------|----------------|
| scripts/plan-db.sh | Add cost-report, wave-summary, task-tokens commands |
| data/models-registry.json | Maintain per-model pricing (input/output rates) |
| db/schema.sql | token_usage table (already exists) |
| scripts/copilot-worker.sh | Report token usage after execution |
| scripts/opencode-worker.sh | Report token usage after execution |
| scripts/delegate.sh | Validate token budget before delegation |
| docs/PLANNER-ARCHITECTURE.md | Document cost attribution workflow |

## References

- ADR 0010: Multi-Provider Orchestration (provider routing)
- ADR 0002: Inter-Wave Communication (task metadata passing)
- data/models-registry.json (pricing data source)
- db/schema.sql (token_usage table definition)
