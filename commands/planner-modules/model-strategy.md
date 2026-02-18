---
name: model-strategy
version: "2.0.0"
---

# Model Strategy & Assignment

## Copilot-First Principle (NON-NEGOTIABLE)

**Copilot CLI is free and unlimited. Claude API is paid.** Maximize Copilot delegation, minimize Claude API usage. Thor (Claude) validates everything -- quality doesn't degrade.

| Phase      | Engine                | Why                                  |
| ---------- | --------------------- | ------------------------------------ |
| Planning   | Claude (opus)         | Reasoning, architecture, judgment    |
| Execution  | **Copilot (default)** | Free, unlimited requests             |
| Validation | Claude (sonnet)       | Thor must be independent of executor |

## Agent Routing (executor_agent)

**DEFAULT IS `copilot`.** Only use `claude` when cost-of-failure justifies paid API.

| Value               | Use For                                           | Billing        |
| ------------------- | ------------------------------------------------- | -------------- |
| `copilot` (default) | ALL tasks unless escalation criteria met          | GitHub (free)  |
| `claude`            | Architecture, security, debug, cross-cutting ONLY | Anthropic ($$) |
| `manual`            | Tasks requiring human intervention                | N/A            |

## Copilot Model Selection

Pick the cheapest Copilot model adequate for the task:

| Complexity        | Copilot Model          | Premium | Use When                                           |
| ----------------- | ---------------------- | ------- | -------------------------------------------------- |
| **Trivial**       | `gpt-5.1-codex-mini`   | 0.33    | Config, rename, text, constants                    |
| **Standard**      | `gpt-5.3-codex`        | 1       | CRUD, components, endpoints, tests with clear spec |
| **Complex**       | `claude-opus-4.6-fast` | 30      | Multi-file, nuanced logic -- still free!           |
| **Max reasoning** | `claude-opus-4.6`      | 30      | Hard tasks where copilot needs full Opus           |

All Copilot models available: `claude-opus-4.6`, `claude-opus-4.6-fast`, `claude-sonnet-4.6`, `claude-sonnet-4.5`, `claude-haiku-4.5`, `gpt-5.3-codex`, `gpt-5.2-codex`, `gpt-5.1-codex-max`, `gpt-5.1-codex`, `gpt-5.1-codex-mini`, `gpt-5`, `gpt-5-mini`, `gpt-4.1`, `gemini-3-pro-preview`

## Claude Escalation Criteria (ONLY these cases)

Escalate to `executor_agent: "claude"` ONLY when ALL of:

1. Task requires **deciding what to do** (not just how)
2. **AND** one of: architectural decision, unknown root cause, security-sensitive, cross-system integration, ambiguous requirements, no existing pattern
3. **AND** failure would cascade to other tasks/systems

If the task is "do X following pattern Y" -- that's Copilot, even if complex.

## Decision Tree (Planner MUST follow)

```
Does the task require DECIDING what to do (architecture, design)?
  YES → claude (opus)
  NO  ↓
Unknown root cause (investigative debugging)?
  YES → claude (opus)
  NO  ↓
Security-sensitive (auth, crypto, permissions, data access)?
  YES → claude (sonnet)
  NO  ↓
Cross-system integration (systems not designed together)?
  YES → claude (opus)
  NO  ↓
ALL REMAINING → copilot
  ↓
  Trivial (config, rename, text, 1 file)?
    YES → copilot + gpt-5.1-codex-mini
    NO  ↓
  Clear requirements + existing pattern?
    YES → copilot + gpt-5.3-codex
    NO  → copilot + claude-opus-4.6-fast
```

## Task Granularity (DO NOT fragment for model fit)

Split by **responsibility/concern**, NOT by model capability. 1 task = 1 coherent unit. Prefer fewer reliable tasks over many fragile ones. Micro-tasks waste tokens on bootstrap.

## Model Selection for Claude Tasks

When `executor_agent: "claude"`, pick model by complexity:

| Complexity             | Model    | Criteria                                                    |
| ---------------------- | -------- | ----------------------------------------------------------- |
| **Standard**           | `sonnet` | Clear requirements, known patterns, 1-3 files               |
| **Requires reasoning** | `opus`   | Ambiguous, architectural, cross-cutting, unknown root cause |

## Context Isolation

- **task-executor** (Claude): FRESH session per task. No parent context.
- **copilot-worker.sh**: FRESH session per task. `--no-ask-user` for autonomous mode.
- **thor**: FRESH session per validation. Skeptical, reads everything.

## DB Registration

```bash
# MANDATORY: --model, --effort, --executor-agent for EVERY task
plan-db.sh add-task {db_wave_id} T1-01 "Fix typo" P2 chore \
  --model gpt-5.1-codex-mini --effort 1 --executor-agent copilot
plan-db.sh add-task {db_wave_id} T1-02 "Add endpoint" P1 feature \
  --model gpt-5.3-codex --effort 2 --executor-agent copilot
plan-db.sh add-task {db_wave_id} T1-03 "Redesign auth" P0 feature \
  --model opus --effort 3 --executor-agent claude
```

## Thor Validation Gate

**Progress counts only Thor-validated tasks.** Executor doesn't matter -- Thor validates all equally. Dashboard: `T✓` = validated, `T!` = done but not validated.

## Cross-Tool Execution (Claude plan → Copilot execution)

When a plan is executed by Copilot, the executing tool gets **T0-00 Review Plan** as first task in W0:

```bash
plan-db.sh add-task {db_w0_id} T0-00 "Review plan and reassign models/effort" P0 chore \
  --model gpt-5.3-codex --effort 1 --executor-agent copilot \
  --description "Review all tasks. Reassign model per task to optimal Copilot model. Adjust effort. Flag tasks needing replan."
```
