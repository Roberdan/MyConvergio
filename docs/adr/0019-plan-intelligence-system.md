# ADR 0019: Plan Intelligence System

Status: Accepted | Date: 24 Feb 2026

## Context

Plan execution currently lacks three capabilities:

1. **No pre-execution review**: Plans go directly to execution without quality validation. Bad specs, missing dependencies, and unrealistic estimates are caught only after wasted tokens.
2. **No post-mortem process**: Completed plans have no structured retrospective. Successes and failures are not captured, so the same mistakes repeat across plans.
3. **No ROI tracking**: Token spend per plan/wave/task is recorded but never analyzed against business value. There is no visibility into which plan types deliver the best return.

These gaps result in preventable execution failures, no organizational learning, and inability to justify or optimize AI spend.

## Decision

**Implement a 5-component Plan Intelligence System integrated into the existing plan-db infrastructure.**

### Components

| #  | Component            | Script / Agent                              | Purpose                                      |
|----|----------------------|---------------------------------------------|----------------------------------------------|
| 1  | Plan Reviewer        | `agents/core_utility/plan-reviewer.md`      | Pre-execution quality gate (5 checks)        |
| 2  | Business Advisor     | `agents/core_utility/plan-business-advisor.md` | Strategic alignment assessment            |
| 3  | Learnings Engine     | `agents/core_utility/plan-post-mortem.md`   | Post-mortem analysis and pattern extraction   |
| 4  | Token Tracking       | `scripts/token-estimator.sh`                | Estimate vs actual token spend analysis       |
| 5  | Intelligence Dashboard | `dashboard/server/routes-plans-intelligence.js` | REST API for intelligence data          |

### Data Model (5 tables)

| Table               | Purpose                              | Key Fields                          |
|---------------------|--------------------------------------|-------------------------------------|
| `plan_reviews`      | Pre-execution review results         | plan_id, gate, score, verdict       |
| `plan_assessments`  | Business alignment scores            | plan_id, dimension, score, rationale|
| `plan_learnings`    | Extracted patterns and lessons        | plan_id, category, pattern, severity|
| `plan_actuals`      | Actual execution metrics              | plan_id, total_tokens, total_duration|
| `plan_token_estimates` | Per-task token budget predictions  | task_id, estimated_tokens, effort   |

### Workflow Integration

```
Plan Created → [1] Reviewer (5 gates) → [2] Business Advisor → Execute
                                                                    ↓
Dashboard ← [5] Intelligence API ← [4] Token Reconciliation ← [3] Post-Mortem
```

**Pre-execution** (Steps 3.1–3.2 in planner.md):
- Reviewer validates spec completeness, dependency graph, effort estimates, risk coverage, and task granularity
- Business Advisor scores strategic alignment, complexity vs value, and resource efficiency
- Both write results to DB; reviewer can block execution on critical findings

**Post-execution** (Step 5.5 in planner.md):
- Post-mortem extracts learnings across 9 categories (estimation, dependencies, scope, quality, tooling, testing, architecture, process, communication)
- Token estimator reconciles predicted vs actual spend; flags >100% variance as learnings
- All findings stored for future plan improvement

### Intelligence API Endpoints

| Endpoint                               | Method | Purpose                           |
|----------------------------------------|--------|-----------------------------------|
| `/api/plans/:id/intelligence/review`   | GET    | Fetch review results              |
| `/api/plans/:id/intelligence/business` | GET    | Fetch business assessment         |
| `/api/plans/:id/intelligence/learnings`| GET    | Fetch extracted learnings         |
| `/api/plans/:id/intelligence/tokens`   | GET    | Fetch token estimates             |
| `/api/plans/:id/intelligence/actuals`  | GET    | Fetch actual metrics              |
| `/api/plans/intelligence/learnings/search` | GET | Search learnings across plans  |
| `/api/plans/intelligence/roi-trend`    | GET    | ROI trend over time               |
| `/api/plans/intelligence/token-accuracy` | GET  | Estimation accuracy metrics      |
| `/api/plans/intelligence/notify`       | GET    | Actionable intelligence alerts    |

## Consequences

- **Positive**: Better plan quality through pre-execution review. ROI visibility per plan/wave/task. Learning feedback loop prevents repeated mistakes. Token estimation improves over time via reconciliation. Strategic alignment scoring guides prioritization.
- **Negative**: Added latency for review step (~30-60s per plan). Additional token spend for reviewer and advisor agents. DB storage growth from intelligence tables. Requires discipline to run post-mortems.

## Enforcement

- Rule: `planner.md` Steps 3.1/3.2 invoke reviewer and advisor before execution
- Rule: `planner.md` Step 5.5 invokes post-mortem after plan completion
- Check: `plan-db.sh review-status <plan_id>` returns non-empty result
- Bypass: `--skip-review` flag for emergency/trivial plans (logged as learning)

## File Impact

| File                                           | Purpose                                      |
|------------------------------------------------|----------------------------------------------|
| `scripts/lib/plan-db-intelligence.sh`          | 9 DB command functions for intelligence data  |
| `scripts/plan-db.sh`                           | Dispatch entries for intelligence commands    |
| `scripts/token-estimator.sh`                   | Token estimation and reconciliation           |
| `agents/core_utility/plan-reviewer.md`         | Pre-execution quality gate agent              |
| `agents/core_utility/plan-business-advisor.md` | Strategic alignment assessment agent          |
| `agents/core_utility/plan-post-mortem.md`      | Post-mortem analysis agent                    |
| `dashboard/server/routes-plans-intelligence.js`| REST API for intelligence data                |
| `commands/planner.md`                          | Updated workflow (Steps 3.1, 3.2, 5.5)       |
| `config/plan-spec-schema.json`                 | Schema with summary field for intelligence    |
| `scripts/init-db.sql`                          | DDL for 5 intelligence tables + views         |

## Related ADRs

- ADR-0002: Inter-Wave Communication (task-level output_data used by learnings)
- ADR-0004: Distributed Plan Execution (plan lifecycle that intelligence hooks into)
- ADR-0008: Thor Per-Task Validation (quality gates complemented by plan-level review)
- ADR-0012: Token Accounting (token tracking extended with estimation and reconciliation)
