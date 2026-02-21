# Market Comparison

## How MyConvergio Differs from Market Solutions

The agentic AI space is crowded with frameworks (Microsoft Agent Framework, AutoGen, CrewAI, LangGraph, OpenAI Agents SDK). MyConvergio takes a fundamentally different approach.

## Comparison Matrix

| Dimension             | Microsoft Agent Framework / AutoGen    | CrewAI / LangGraph         | MyConvergio                                                        |
| --------------------- | -------------------------------------- | -------------------------- | ------------------------------------------------------------------ |
| **Runtime**           | Python/.NET SDK, cloud deployment      | Python SDK, server process | CLI-native (bash + sqlite3), zero server                           |
| **LLM Lock-in**       | Azure OpenAI / single provider         | Single provider per agent  | Multi-provider routing: Claude, Copilot, OpenCode (local), Gemini  |
| **Cost Model**        | Pay-per-token, no budget controls      | Pay-per-token              | Budget caps, multi-tier fallback chain, per-task cost tracking     |
| **Privacy**           | Cloud-only (data leaves your machine)  | Cloud-only                 | Privacy-aware: sensitive data routes to local models only          |
| **Quality Assurance** | Agents self-report success             | Agents self-report success | Independent Thor validation (9 gates, reads files directly)        |
| **State Management**  | Redis/Pinecone/cloud DB                | In-memory or cloud DB      | SQLite file, portable, inspectable, no dependencies                |
| **Git Safety**        | No git awareness                       | No git awareness           | Worktree isolation per plan, branch protection hooks               |
| **Execution**         | API calls via SDK                      | API calls via SDK          | Real CLI tools (claude, copilot, opencode, gemini)                 |
| **Agent Count**       | Generic agent templates                | Role-based templates       | 65 domain-specialized agents with personas                         |
| **Workflow**          | Freeform or graph-based                | Role-based or graph-based  | Structured pipeline: Prompt > Plan > Execute (TDD) > Thor > Verify |
| **Setup**             | pip install + cloud config             | pip install + API keys     | `git clone` or `npm install -g`, works immediately                 |
| **Target User**       | Platform engineers building agent apps | Python developers          | Software engineers using AI coding assistants daily                |

## Key Architectural Differences

### 1. Multi-Provider Intelligence (vs Single-Vendor Lock-in)

MyConvergio routes tasks to the best provider based on priority, privacy, cost, and task type. A P0 critical bug goes to Claude Opus; a bulk refactoring goes to Copilot; sensitive data stays on local OpenCode models. No other framework offers this routing intelligence.

### 2. Independent Quality Validation (vs Self-Reporting)

In every other framework, agents report their own success. MyConvergio's Thor agent validates independently: reads files, runs tests, checks 9 quality gates. An agent claiming "tests pass" means nothing until Thor confirms it. This is the single biggest reliability differentiator.

### 3. CLI-Native, Zero Infrastructure

No Python runtime, no Docker, no cloud accounts, no servers. Just `bash` + `sqlite3` (preinstalled on macOS/Linux). The entire orchestration layer runs in your terminal alongside your existing coding workflow. Market frameworks require deploying infrastructure before writing a single line of code.

### 4. Cost Awareness as First-Class Citizen

Daily budget caps, automatic fallback chains (Claude > Copilot > Gemini > OpenCode), per-task token tracking, cost-per-wave reporting. Other frameworks treat cost as an afterthought; MyConvergio treats it as an architectural constraint.

### 5. Git Worktree Isolation

Every execution plan runs in an isolated git worktree. No risk of corrupting your main branch. Concurrent plans work on separate branches simultaneously. No other agentic framework provides git-level execution isolation.

## When to Use What

| Scenario                                                 | Best Choice                          |
| -------------------------------------------------------- | ------------------------------------ |
| Building a multi-agent SaaS product                      | Microsoft Agent Framework, LangGraph |
| Research prototype with agent dialogue                   | AutoGen, CrewAI                      |
| Content generation with role-based teams                 | CrewAI                               |
| **Daily software engineering with AI coding assistants** | **MyConvergio**                      |
| **Multi-provider cost optimization**                     | **MyConvergio**                      |
| **Privacy-sensitive codebases**                          | **MyConvergio**                      |

MyConvergio is not competing with agent frameworks. It is a **practitioner's toolkit** for engineers who use AI coding assistants every day and need structure, quality gates, cost control, and multi-provider flexibility.

---

## Engineering Foundations

MyConvergio's workflow is informed by two Microsoft engineering references:

- **[ISE Code-with-Engineering Playbook](https://microsoft.github.io/code-with-engineering-playbook/)** — The Industry Solutions Engineering team's internal standard for all customer engagements. Covers testing, code reviews, CI/CD, design reviews, security, observability, and agile practices.
- **[HVE Core](https://github.com/microsoft/hve-core)** — Hierarchical Verifiable Execution framework for AI agents. Research-Plan-Implement-Review-Discover lifecycle with schema validation and failed approach tracking.

### Alignment with ISE Engineering Playbook

| ISE Playbook Concept         | MyConvergio Equivalent                                         | Status                                                           |
| ---------------------------- | -------------------------------------------------------------- | ---------------------------------------------------------------- |
| Definition of Ready          | `/prompt` F-xx extraction + Technical Clarification (step 1.6) | Aligned                                                          |
| Definition of Done (feature) | Thor per-task validation (Gates 1-4, 8, 9)                     | **Enhanced** — automated, independent agent reads files directly |
| Definition of Done (sprint)  | Thor per-wave validation (all 9 gates + build)                 | **Enhanced** — no self-reporting, 3-round rejection cycle        |
| PR author checklist          | Pre-commit hooks (lint, typecheck, test) + TF-pr task          | Aligned                                                          |
| PR reviewer checklist        | Thor Gates 2 (code quality) + 3 (ISE standards) + 8 (TDD)      | **Enhanced** — automated, zero human reviewer bottleneck         |
| Code review SLA              | Not applicable (agents review immediately)                     | Adapted                                                          |
| Design reviews / ADRs        | `/research` phase + Thor Gate 9 (Constitution & ADR)           | Aligned                                                          |
| Trade studies                | ADR with alternatives in Context section                       | Aligned                                                          |
| Sprint goal                  | Wave-level task grouping with shared F-xx refs                 | Adapted                                                          |
| Conventional commits         | Enforced by Git Hygiene gate (Gate 6)                          | Aligned                                                          |
| Branch naming convention     | `feature/`, `fix/`, `chore/` enforced by worktree-create.sh    | Aligned                                                          |
| Credential scanning (CI)     | Thor Gate 3: grep for AWS/API/GitHub/password patterns         | Aligned                                                          |
| TDD (Red-Green-Refactor)     | Thor Gate 8 (MANDATORY) + task-executor-tdd module             | **Enhanced** — enforced per-task, not just in CI                 |
| 80%+ code coverage           | Thor approval criteria: coverage >= 80% new files              | Aligned                                                          |
| Secrets in Key Vault         | `env-vault.sh` + coding-standards.md rules                     | Aligned                                                          |
| Documentation-as-code        | Thor Gate 5 (docs updated if behavior changed)                 | Aligned                                                          |
| Retrospectives               | Knowledge Codification (errors -> ADR + ESLint rules)          | Adapted — machine-readable instead of meeting-based              |

### Patterns Adopted from HVE Core

| HVE Core Pattern               | MyConvergio Implementation                                                                                                                             |
| ------------------------------ | ------------------------------------------------------------------------------------------------------------------------------------------------------ |
| **Failed Approaches Tracking** | Executor logs `{task_id, approach, reason}` on max retries via `plan-db.sh log-failure`. Planner reads prior failures to avoid repeating them.         |
| **Schema-Driven Validation**   | `plan-spec-schema.json` validates spec.json structure before plan import. Catches missing `verify` arrays, invalid task IDs, effort outside 1-3 range. |
| **Phase 5 Discover**           | Knowledge Codification rule: errors discovered during execution are codified as ADRs and ESLint rules, not just fixed.                                 |
| **Discrepancy Logging**        | F-xx verification report with `[x] PASS` / `[ ] FAIL` evidence per requirement.                                                                        |

### Where MyConvergio Goes Beyond Both

- **Multi-provider routing** — Neither ISE Playbook nor HVE Core address multi-provider orchestration
- **Independent quality validation** — ISE relies on human reviewers; HVE Core uses self-review. Thor is a separate agent that trusts nothing.
- **Budget-aware execution** — Daily caps, fallback chains, per-task cost tracking
- **Git worktree isolation** — Plans execute in isolated branches; no main branch corruption risk

---

For orchestrator details, see [orchestrator.md](./orchestrator.md).
