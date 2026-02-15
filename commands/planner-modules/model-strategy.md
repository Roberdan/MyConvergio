---
name: model-strategy
version: "1.0.0"
---

# Model Strategy & Assignment

## Phase-Model Mapping

| Phase        | Standard Mode           | Max Parallel |
| ------------ | ----------------------- | ------------ |
| Planning     | opus                    | opus         |
| Coordination | sonnet                  | **opus**     |
| Execution    | **gpt-5.3-codex** (default) | gpt-5.3-codex |
| Validation   | opus                    | opus         |

## Model Selection (MANDATORY per task)

Planner assigns model to EACH task during planning phase.
Executor uses EXACTLY the model specified (no override).

If task scope changes during execution → re-plan, don't auto-escalate.

**DEFAULT IS SONNET.** Use haiku only for trivial. Use opus when reasoning matters.

## Agent Routing (executor_agent) & Model Mapping

Each task specifies which agent executes it via `executor_agent`:

| Value              | Use For                                                | Model Options                              |
| ------------------ | ------------------------------------------------------ | ------------------------------------------ |
| `claude` (default) | Architecture, security, debugging, cross-cutting logic | haiku, sonnet, opus                        |
| `copilot`          | Mechanical, repetitive, well-defined tasks             | gpt-5.1-codex-mini, gpt-5.3-codex, gpt-5  |
| `codex`            | Mechanical bulk tasks with clear specs                 | gpt-5.3-codex                              |
| `manual`           | Tasks requiring human intervention                     | N/A                                        |

**Model weight tiers** (used for weighted progress):

| Tier | Weight | Models                                |
| ---- | ------ | ------------------------------------- |
| Low  | x1     | haiku, gpt-5.1-codex-mini             |
| Mid  | x2     | sonnet, gpt-5.3-codex, gpt-5.1-codex |
| High | x3     | opus, gpt-5, gpt-5.2                  |

**Decision criteria:**

- Cost-of-failure HIGH → `claude` (opus/sonnet)
- Mechanical + well-defined → `copilot` or `codex`
- Requires judgment → `claude`
- **Never delegate**: architecture, security, debugging, DB schema, API design

Replaces the legacy `codex: true/false` boolean. Backward compatible: `codex: true` maps to `executor_agent: "codex"`.

## Cost-of-Failure Principle

Pick the model based on **cost of getting it wrong**, not cost of the call:

| Scenario             | Cheap model cost | Failure + retry cost    | Right choice |
| -------------------- | ---------------- | ----------------------- | ------------ |
| Fix typo             | haiku $0.01      | N/A (can't fail)        | haiku        |
| Add endpoint         | sonnet $0.15     | retry $0.30+            | sonnet       |
| Integrate 2 services | sonnet $0.15     | debug+rewrite $1+       | **opus**     |
| Debug unknown cause  | sonnet $0.15     | 3 wrong attempts $0.45+ | **opus**     |

**Rule**: If P(failure) > 40%, use the next model up. One failed retry already
costs more than the upgrade.

## Assignment Criteria

| Complexity             | Model    | Criteria                                                                                                                |
| ---------------------- | -------- | ----------------------------------------------------------------------------------------------------------------------- |
| **Trivial**            | `haiku`  | Single file, zero logic (string/config/constant), no new code paths                                                     |
| **Standard**           | `sonnet` | Clear requirements, known patterns, 1-3 files, tests with obvious assertions                                            |
| **Requires reasoning** | `opus`   | Ambiguous requirements, architectural decisions, cross-cutting concerns, unknown root cause, 4+ files with dependencies |

## Haiku: ONLY for these cases

- Fix typo in string/comment
- Update a constant/config value
- Change UI text (no logic)
- Rename a variable (single file)
- Update version number
- Add/remove a CSS class (no logic)

## Sonnet: solid when requirements are clear

- Implement a well-defined function/method
- Add an endpoint following existing patterns
- Write tests when the behavior is specified
- Refactor with clear before/after structure
- Bug fix with known root cause
- CRUD operations, form components, data transformations

## Opus: invest upfront when reasoning matters

- **Architectural decisions**: Where to put things, how to structure, which pattern
- **Multi-file interdependencies**: 4+ files that must change consistently
- **Unknown root cause**: Debug where the symptom doesn't point to the source
- **Integration work**: Connecting systems that weren't designed together
- **Ambiguous requirements**: Task needs interpretation, not just execution
- **First-of-its-kind**: No existing pattern to follow in the codebase
- **Security-sensitive**: Auth, permissions, data access, crypto
- **Data model changes**: Schema migrations, breaking API changes

**Key insight**: Sonnet executes well. Opus reasons well. If the task is about
_what to do_ (not just _how_), use Opus. Getting it wrong once costs more than
Opus upfront.

## Decision Tree (Planner MUST follow)

```
Is it a string/constant/config-only change in 1 file?
  YES → haiku
  NO  ↓
Does the task require DECIDING what to do (not just how)?
  YES → opus
  NO  ↓
Are requirements ambiguous or is root cause unknown?
  YES → opus
  NO  ↓
Does it touch 4+ files with interdependencies?
  YES → opus
  NO  ↓
Is there an existing pattern to follow in the codebase?
  YES → sonnet
  NO  → opus
```

## Task Granularity (DO NOT fragment for model fit)

Split tasks by **responsibility/concern**, NOT by model capability.

**WRONG**: Break "Add login form with validation" into 5 micro-tasks.
Each task-executor starts with zero context — micro-tasks waste tokens
on bootstrap and fail on anything requiring cross-piece reasoning.

**RIGHT**: Keep "Add login form with validation" as one sonnet/opus task.
If the plan naturally produces trivial tasks (rename, config), those go to haiku.

**Rule**: Optimize for reliability first, cost second.

**Task size guidance**:

- 1 task = 1 coherent unit of work (a function, a component, an endpoint)
- If splitting makes a task lose its logical coherence → don't split
- Prefer fewer reliable tasks over many fragile ones

## Context Isolation (Token Optimization)

- **task-executor**: FRESH session per task. No parent context inheritance.
- **thor**: FRESH session per validation. Skeptical, reads everything.
- **Benefit**: 50-70% token reduction vs inherited context
- **MCP**: task-executor has WebSearch/WebFetch disabled

## DB Registration

```bash
# MANDATORY: specify --model and --effort for EVERY task
plan-db.sh add-task {db_wave_id} T1-01 "Fix typo" P2 chore --model haiku --effort 1
plan-db.sh add-task {db_wave_id} T1-02 "Add endpoint" P1 feature --model sonnet --effort 2
plan-db.sh add-task {db_wave_id} T1-03 "Redesign auth" P0 feature --model opus --effort 3

# Shorthand (model as last positional arg, effort defaults to 1)
plan-db.sh add-task {db_wave_id} T1-01 "Fix typo" P2 chore haiku
```

## Thor Validation Gate

**Progress counts only Thor-validated tasks.** A task marked "done" by the executor
does NOT contribute to the weighted progress until Thor validates it.

Dashboard shows: `T✓` = Thor validated, `T!` = done but not validated.

## Cross-Tool Execution (Claude plan → Copilot execution)

When a plan created by Claude is executed by Copilot (or vice versa), the
executing tool MUST be given a **T0-00 Review Plan** task as the first task
in W0:

```bash
plan-db.sh add-task {db_w0_id} T0-00 "Review plan and reassign models/effort per task" P0 chore \
  --model gpt-4o --effort 1 \
  --description "Review all tasks. For each task: verify model is optimal for this executor, adjust effort_level if needed, flag any tasks that need replanning."
```

This allows the executing tool to:

1. Read the full plan context
2. Reassign `model` per task to its own optimal models
3. Adjust `effort_level` based on its own assessment
4. Flag any tasks that need replanning before execution starts
