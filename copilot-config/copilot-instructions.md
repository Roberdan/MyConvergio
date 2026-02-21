# Copilot CLI — Global Instructions

**For shared standards, rules, and workflow, see AGENTS.md and CLAUDE.md**

This file contains ONLY Copilot CLI-specific configurations: model routing and orchestration agents.

## Model Strategy (18 models available)

Select the optimal model based on task type. Override via `model:` parameter in task tool.

### Model Routing Table

| Use Case                       | Model                | Tier     |
| ------------------------------ | -------------------- | -------- |
| **Requirements extraction**    | `claude-opus-4.6`    | premium  |
| **Strategic planning**         | `claude-opus-4.6-1m` | premium  |
| **Code generation / TDD**      | `gpt-5.3-codex`      | standard |
| **Quality validation (Thor)**  | `claude-opus-4.6`    | premium  |
| **Code review / security**     | `claude-opus-4.6`    | premium  |
| **Compliance (full codebase)** | `claude-opus-4.6-1m` | premium  |
| **Documentation writing**      | `claude-sonnet-4.5`  | standard |
| **Codebase exploration**       | `claude-haiku-4.5`   | fast     |
| **Quick fixes / bulk edits**   | `gpt-5.1-codex-mini` | fast     |
| **Build / test execution**     | `claude-haiku-4.5`   | fast     |
| **Complex refactoring**        | `gpt-5.3-codex`      | standard |
| **Architecture analysis**      | `claude-opus-4.6-1m` | premium  |

### When to Use 1M Context (`claude-opus-4.6-1m`)

- Planning across an entire large codebase (>100 files)
- Compliance audit reading all docs + source
- Architecture review of full project
- Migration planning needing full dependency graph

### When to Use Codex (`gpt-5.3-codex`)

- Writing new code (functions, classes, modules)
- TDD cycles (test writing + implementation)
- Refactoring with clear patterns
- Mechanical transformations across files

### When to Use Opus (`claude-opus-4.6`)

- Security analysis requiring deep reasoning
- Requirement extraction catching edge cases
- Thor validation gates (zero tolerance mode)
- Complex design decisions

## Orchestration Agents

| Agent                 | Purpose                   | Default Model        |
| --------------------- | ------------------------- | -------------------- |
| `@prompt`             | Extract F-xx requirements | `claude-opus-4.6`    |
| `@planner`            | Wave/task decomposition   | `claude-opus-4.6-1m` |
| `@execute`            | TDD task execution        | `gpt-5.3-codex`      |
| `@validate`           | Thor quality gates        | `claude-opus-4.6`    |
| `@strategic-planner`  | Multi-phase initiatives   | `claude-opus-4.6-1m` |
| `@code-reviewer`      | Security-focused review   | `claude-opus-4.6`    |
| `@tdd-executor`       | Standalone TDD cycle      | `gpt-5.3-codex`      |
| `@compliance-checker` | Regulatory validation     | `claude-opus-4.6-1m` |

## Anti-Bypass Protection (CRITICAL)

**NEVER execute plan tasks by editing files directly.** EVERY task MUST go through `copilot-worker.sh` or equivalent agent execution. Direct file editing during active plan = VIOLATION.

## Digest Scripts (NON-NEGOTIABLE)

**NEVER run verbose commands directly.** Use digest scripts — compact JSON, cached.

```bash
export PATH="$HOME/.claude/scripts:$PATH"
```

| Instead of                 | Use                          |
| -------------------------- | ---------------------------- |
| `gh run view --log-failed` | `service-digest.sh ci`       |
| `gh pr view --comments`    | `service-digest.sh pr`       |
| `npm install` / `npm ci`   | `npm-digest.sh install`      |
| `npm run build`            | `build-digest.sh`            |
| `npm audit`                | `audit-digest.sh`            |
| `npx vitest` / `npm test`  | `test-digest.sh`             |
| `git diff main...feat`     | `diff-digest.sh main feat`   |
| `git status` / `git log`   | `git-digest.sh [--full]`     |
| `npx prisma migrate`       | `migration-digest.sh status` |

## Plan DB Commands

```bash
plan-db.sh create {project} "Name" --source-file {prompt.md} --auto-worktree
plan-db.sh import {plan_id} spec.json
plan-db-safe.sh update-task {id} done "Summary"  # ALWAYS use safe for done (auto-validates)
plan-db.sh validate {id}
plan-db.sh list-tasks {plan_id}
git-digest.sh --full
```
