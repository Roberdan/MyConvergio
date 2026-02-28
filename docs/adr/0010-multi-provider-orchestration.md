# ADR 0010: Multi-Provider Orchestration

Status: Accepted
Date: 2026-02-21

## Context
The orchestrator must support delegation across multiple AI providers (Copilot, OpenCode, Gemini) for task execution, privacy routing, and budget control. Prior work includes delegate.sh (provider router), orchestrator.yaml (provider config), model-registry.sh (model multipliers), worktree-safety.sh (pre-check/audit), env vault (secret management), and Thor validation gates.

## Decision
- Use `delegate.sh` as the central router for task delegation, enforcing worktree safety and provider selection.
- Provider config in `orchestrator.yaml` (YAML, portable via $CLAUDE_HOME).
- Copilot 0x and Gemini 0x models routed for free/low-privacy tasks; OpenCode for paid/high-privacy.
- Privacy routing enforced via orchestrator.yaml and delegate.sh checks.
- Thor validates all delegated work (per-task, per-wave).
- Model registry (model-registry.sh, data/models-registry.json) used for multiplier and version checks.
- Worktree safety enforced via worktree-safety.sh (pre-check, audit).
- Environment secrets managed via env vault (vault section in orchestrator.yaml).

## Consequences
- Delegation is robust, auditable, and privacy-aware.
- All provider routing, budget, and privacy checks are centralized.
- Thor validation ensures quality and compliance.
- Model registry enables dynamic provider/model selection.
- Worktree safety prevents merge conflicts and data loss.
- Secrets are never exposed to workers; vault is enforced.

## File Impact Table
| File                                 | Purpose/Impact                                      |
|--------------------------------------|-----------------------------------------------------|
| scripts/delegate.sh                  | Provider routing, worktree safety, privacy checks    |
| config/orchestrator.yaml             | Provider config, privacy, budget, vault              |
| scripts/model-registry.sh            | Model multipliers, version checks                    |
| data/models-registry.json            | Model registry data                                 |
| scripts/worktree-safety.sh           | Worktree pre-check, audit                           |
| scripts/copilot-worker.sh            | Copilot delegation, safe update, Thor validation     |
| scripts/opencode-worker.sh           | OpenCode delegation, safe update, Thor validation    |
| scripts/gemini-worker.sh             | Gemini delegation, safe update, Thor validation      |
| scripts/lib/delegate-utils.sh        | Shared worker utilities, safe task update            |
| scripts/lib/agent-protocol.sh        | Envelope context, Thor input formatting              |
| env vault (vault section)            | Secret management, enforced in orchestrator.yaml     |

