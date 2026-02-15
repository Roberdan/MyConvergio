<!-- v2.0.0 | 15 Feb 2026 | Token-optimized per ADR 0009 -->

# Execution Optimization

## Context Isolation (50-70% Token Reduction)

**Isolated Subagents** (FRESH session per invocation):

- `task-executor` (v1.8.0): NO parent context, TDD workflow, modular
- `thor-quality-assurance-guardian` (v3.3.0): Skeptical validation, Gate 8 TDD, modular

**Benefits**:

- Task executor: ~30K tokens/task (vs 50-100K with inherited context)
- Thor: Unbiased validation (no assumptions from parent session)
- Parallel execution: No context collision between concurrent tasks

**MCP Restrictions**:

- `task-executor`: disables WebSearch/WebFetch (uses Read/Grep only)
- Focus on codebase operations, not web research during execution

## Token Tracking via API (MANDATORY for task-executor)

```bash
curl -s -X POST http://127.0.0.1:31415/api/tokens \
  -H "Content-Type: application/json" \
  -d '{"project_id":"{project}","plan_id":{plan},"wave_id":"{wave}","task_id":"{task}","agent":"task-executor","model":"{model}","input_tokens":{in},"output_tokens":{out},"cost_usd":{cost}}'
```

## Model Escalation Strategy

| Agent Type                 | Default          | Escalation Rule                          |
| -------------------------- | ---------------- | ---------------------------------------- |
| Task Executor              | gpt-5.3-codex    | → opus if cross-cutting or architectural |
| Coordinator (Standard)     | sonnet           | → opus if >3 concurrent tasks            |
| Coordinator (Max Parallel) | **opus**         | Required for unlimited parallelization   |
| Validator (Thor)           | opus             | No escalation                            |

## Parallelization Modes (User Choice)

**Standard Mode** (default):

- Max 3 concurrent task-executors
- Sonnet coordination
- Cost: $ moderate, Speed: ⚡⚡ normal

**Max Parallel Mode** (optional):

- Unlimited concurrent task-executors
- **Opus coordination** (required)
- Cost: $$$ high, Speed: ⚡⚡⚡⚡ (3-5x faster)
- Use case: Urgent deadlines, large plans (10+ tasks)

**Selection**: Planner asks user after plan approval, before execution starts.
