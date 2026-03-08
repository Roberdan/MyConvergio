# MyConvergio Agents

**v11.0.0** | Multi-provider agent ecosystem for Claude Code + GitHub Copilot CLI

> _"Intent is human, momentum is agent"_ — [The Agentic Manifesto](./AgenticManifesto.md)

## Overview

This index documents the **actual** agent inventory shipped in this repository:

- `.claude/agents/`: 82 Claude agent files
- `copilot-agents/`: 85 Copilot agent files
- `.github/agents/`: project automation agents (night operations)

The category taxonomy below matches current folders and files in `.claude/agents/`.

## Claude Agent Categories (source of truth: `.claude/agents/`)

| Category | Count | Notes |
| --- | ---: | --- |
| `_root` | 2 | repo-level wrappers (`deep-repo-auditor`, `pr-comment-resolver`) |
| `business_operations` | 11 | PM, ops, GTM, customer success |
| `compliance_legal` | 5 | legal, security, healthcare, gov affairs |
| `core_utility` | 23 | constitution, thor, planner modules, orchestration |
| `design_ux` | 3 | creative direction and UX design |
| `leadership_strategy` | 7 | executive and strategic leadership |
| `release_management` | 5 | release, hardening, ecosystem sync |
| `research_report` | 1 | long-form strategic research reporting |
| `specialized_experts` | 14 | domain experts and specialist advisors |
| `technical_development` | 11 | architecture, debugging, TDD execution |

**Total Claude files: 82**

## Copilot Agent Inventory (`copilot-agents/`)

Copilot wrappers mirror the same domain taxonomy and add workflow-native wrappers:

- Orchestration wrappers: `check`, `prompt`, `planner`, `execute`, `validate`
- Execution extensions: `task-executor`, `task-executor-tdd`, `tdd-executor`
- Governance/quality: `code-reviewer`, `compliance-checker`, `knowledge-base`
- Sync/operations: `ecosystem-sync`, release manager modules

**Total Copilot files: 85**

## Key Agent Groups

### Core Utility

- `CONSTITUTION`
- `thor-quality-assurance-guardian`
- `thor-validation-gates`
- `strategic-planner` (+ `-git`, `-templates`, `-thor`)
- `wanda-workflow-orchestrator`
- `xavier-coordination-patterns`

### Technical Development

- `baccio-tech-architect`
- `dario-debugger` (+ lean profile)
- `rex-code-reviewer`
- `adversarial-debugger`
- `task-executor` (+ `task-executor-tdd`)
- `otto-performance-optimizer`

### Release and Sync

- `app-release-manager`
- `feature-release-manager`
- `mirrorbuddy-hardening-checks`
- `ecosystem-sync` (**auto-sync / claude-sync operational flow**)

## Project Automation Agents

These are not in `.claude/agents/` or `copilot-agents/`, but are shipped for repository operations:

- `night-maintenance` → `.github/agents/night-maintenance.agent.md`
- `claude-sync` → operational sync profile implemented via `ecosystem-sync` + mesh sync scripts

## Installation Notes

```bash
# Claude Code (repo mode)
claude --plugin-dir .

# Copilot CLI
cp copilot-agents/*.agent.md ~/.copilot/agents/
```

## Validation and Quality Gates

- Workflow and routing: `CLAUDE.md`, `.claude/CLAUDE.md`
- Thor gates reference: `.claude/agents/core_utility/thor-validation-gates.md`
- Migration path to v11: `docs/MIGRATION-v10-to-v11.md`

## Versioning

- Current docs target: **v11.0.0**
- Version policy: `docs/VERSIONING_POLICY.md`
- Changelog: `CHANGELOG.md`
