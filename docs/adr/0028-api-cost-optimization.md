# ADR 0028: API Cost Optimization

**Status**: Accepted
**Date**: 2026-03-01
**Refs**: ADR-0012 (token accounting), ADR-0025 (tiered model strategy)

## Context

Multi-provider Claude/GPT usage has significant cost variance. Simple tasks (docs, chores) run on expensive models unnecessarily. No systematic cost tracking or Batch API usage.

## Decision

Implement 5-strategy cost optimization:

1. **Batch API** (50% discount): `batch-dispatcher.sh` for effort=1 chore/doc/test tasks
2. **Prompt caching**: leverage auto-caching, stable system prompts per `prompt-caching-guide.md`
3. **Model routing**: `model-router.sh` selects haiku/sonnet/opus/gpt per task-type+effort
4. **Cost tracking**: `cost-calculator.sh` + `model_cost_breakdown` column in plan_actuals
5. **Claude Max fallback**: `CLAUDE_MAX_EXHAUSTED` env var switches to ANTHROPIC_API_KEY billing

## Consequences

- 40-60% estimated cost reduction via routing + batch
- New scripts: batch-dispatcher.sh, model-router.sh, cost-calculator.sh
- No breaking changes to plan-db.sh, copilot-worker.sh, execute.md workflows
- Batch API limited to non-blocking tasks (effort=1, type: chore/doc/test)
- Opus/architecture tasks excluded from batch (C-03 constraint)
