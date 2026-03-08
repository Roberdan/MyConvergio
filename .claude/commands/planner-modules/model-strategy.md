---
name: model-strategy
version: "2.2.0"
---

# Model Strategy & Assignment

## Copilot-First Principle (NON-NEGOTIABLE)

**Premium requests are finite.** Use the lowest adequate model for the job and reserve expensive models for work where failure cost is higher than request cost. Thor remains the quality gate.

| Phase      | Engine                | Why                                         |
| ---------- | --------------------- | ------------------------------------------- |
| Planning   | Claude (opus)         | Highest judgment, ambiguity handling        |
| Execution  | **Copilot (default)** | Best request efficiency for deterministic work |
| Validation | Claude (sonnet)       | Thor must be independent of executor        |

## Agent Routing (executor_agent)

**DEFAULT IS `copilot`.** Only use `claude` when cost-of-failure justifies paid API.

| Value               | Use For                                           | Billing        |
| ------------------- | ------------------------------------------------- | -------------- |
| `copilot` (default) | ALL tasks unless escalation criteria met          | GitHub premium |
| `claude`            | Architecture, security, debug, cross-cutting ONLY | Anthropic ($$) |
| `manual`            | Tasks requiring human intervention                | N/A            |

Every task should also be thought of as a **capability request**: planner, researcher, executor, validator, reviewer, or deployer. Model choice optimizes that capability; it does not define it.

## Copilot Model Selection

Pick the cheapest Copilot model adequate for the task:

| Complexity          | Copilot Model        | Relative Cost | Use When                                              |
| ------------------- | -------------------- | ------------- | ----------------------------------------------------- |
| **Fast default**    | `gpt-5-mini`         | low           | Simple coding, summaries, boilerplate, light cleanup  |
| **Fast lightweight**| `claude-haiku-4.5`   | low           | Repetitive transforms, tiny utilities, quick scans    |
| **Standard agentic**| `gpt-5.3-codex`      | medium        | Planned TDD, components, endpoints, tests, refactors  |
| **Deep reasoning**  | `gpt-5.4`            | medium-high   | Debugging, design tradeoffs, code review, tricky bugs |
| **Balanced Claude** | `claude-sonnet-4.6`  | medium        | Nuanced implementation or validation with good speed  |
| **Max reasoning**   | `claude-opus-4.6`    | high          | Architecture, security, ambiguous cross-system work   |

### Full Copilot Multiplier Reference

| Model                  | Role                               |
| ---------------------- | ---------------------------------- |
| `gpt-5-mini`           | Fast default                       |
| `gpt-5.3-codex`        | Agentic software development       |
| `gpt-5.4`              | Deep reasoning and debugging       |
| `claude-haiku-4.5`     | Fast lightweight assistance        |
| `claude-sonnet-4.6`    | Balanced Claude latest            |
| `claude-opus-4.6`      | Maximum-quality reasoning          |
| `gemini-3-pro-preview` | Large-context research/analysis    |

Use GitHub Docs as source of truth for currently supported models and premium multipliers; do not hardcode "free/unlimited" assumptions into planning.

## OpenCode Provider

OpenCode is an open-source AI coding tool with free and paid model access.

| Model            | Cost     | Notes                                    |
| ---------------- | -------- | ---------------------------------------- |
| `qwen2.5-coder`  | Free     | Local/open model, good for codegen       |
| `deepseek-coder` | Free     | Strong at code completion                |
| `gpt-4.1`        | Paid API | OpenAI billing, not GitHub free tier     |
| `claude-sonnet`  | Paid API | Anthropic billing, not Copilot free tier |

**PRIVACY WARNING**: OpenCode may send code to third-party endpoints. Do NOT use with:

- Proprietary source code
- Secrets or credentials
- Customer PII or regulated data

Use OpenCode only for open-source projects or personal tooling where data sensitivity is low.

## Gemini Provider

Gemini is available for **research and analysis tasks only** (not code execution).

| Model                  | Context Window | Use For                               |
| ---------------------- | -------------- | ------------------------------------- |
| `gemini-2.5-pro`       | 1M tokens      | Large codebase analysis, doc research |
| `gemini-3-pro-preview` | 1M tokens      | Via Copilot CLI (free tier)           |

**Constraints**:

- Research-only: summarization, analysis, large-context reading
- NOT for code generation or task execution (use Copilot)
- 1M context is its advantage -- use it for whole-repo reads

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
  Mechanical 1-file task (config, rename, text, constants)?
    YES → copilot + gpt-5-mini
    NO  ↓
  Simple generation (boilerplate, stubs, repetitive transforms)?
    YES → copilot + claude-haiku-4.5
    NO  ↓
  Clear requirements + existing pattern?
    YES → copilot + gpt-5.3-codex
    NO  ↓
  Hard debugging / review / architecture-level tradeoffs?
    YES → copilot + gpt-5.4
    NO  → copilot + claude-sonnet-4.6
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
- **copilot-worker.sh**: FRESH session per task. `--yolo` for full autonomous mode.
- **thor**: FRESH session per validation. Skeptical, reads everything.

## DB Registration

```bash
# MANDATORY: --model, --effort, --executor-agent for EVERY task
plan-db.sh add-task {db_wave_id} T1-01 "Fix typo" P2 chore \
  --model gpt-5-mini --effort 1 --executor-agent copilot
plan-db.sh add-task {db_wave_id} T1-02 "Add endpoint" P1 feature \
  --model gpt-5.3-codex --effort 2 --executor-agent copilot
plan-db.sh add-task {db_wave_id} T1-03 "Redesign auth" P0 feature \
  --model claude-opus-4.6 --effort 3 --executor-agent claude
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

## Changelog

- **2.2.0** (2026-03-07): Added GPT-5.4 role, removed outdated free/unlimited assumption, switched to lowest-adequate-model routing
