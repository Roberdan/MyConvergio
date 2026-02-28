# ADR-0003: Opus 4.6 Configuration Upgrade

**Status**: Accepted
**Date**: 07 February 2026
**Context**: Claude Opus 4.6 released 05 Feb 2026 with breaking changes and new capabilities

## Decision

Upgrade global Claude configuration to leverage Opus 4.6 features without
enabling experimental Agent Teams (evaluated and rejected for our workflow).

## Changes

### Critical (settings.json)

- **Output tokens**: 64K -> 128K (Opus 4.6 doubled max output)
- **Thinking mode**: Removed `MAX_THINKING_TOKENS` (adaptive thinking replaces
  manual budget_tokens, deprecated on Opus 4.6)
- **MCP permissions**: 7 codegraph entries -> wildcard `mcp__codegraph__*`

### Hooks

- **Setup event**: Replaced `SessionStart` conditional hook with native `Setup`
  event (triggered by `--init`/`--maintenance` flags, no env var needed)

### Status Line

- **Cost estimate**: Added inline session cost approximation using
  `ctx_used * model_pricing` with awk. Output as 25% of input approximation.

### New Components

- **adversarial-debugger agent**: Spawns 3 parallel Explore subagents with
  competing hypotheses for complex bug diagnosis. Read-only, evidence-based.
- **plan-db-safe.sh**: Wrapper around plan-db.sh that runs pre-checks
  (file existence, lint, untracked tests) before allowing done transitions.

## Rejected: Agent Teams

Evaluated `CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS=1`. Decision: not enabled.

**Reasons**:

- Our DB-driven wave system provides more structured coordination
- Worktree isolation prevents file conflicts (Agent Teams has none)
- Cost: 5x token usage per team vs our context-isolated task-executor
- No session resumption for in-process teammates
- Task status lag issues in current research preview

**Revisit when**: GA release with file locking and session persistence.

## Consequences

- New sessions automatically use adaptive thinking (no config needed)
- 128K output enables longer thinking budgets and comprehensive responses
- Setup hook only runs when explicitly invoked (cleaner than conditional)
- adversarial-debugger available for complex debugging (Preview maturity)

## February 2026 Update

**Model Landscape Review** (Plan 189)

- **Opus 4.6 validation**: Production-tested across Plan 149, 173, 189. Adaptive thinking stable; no manual budget_tokens needed. Used for quality gates in thor-quality-assurance-guardian.
- **Thinking token monitoring**: Implemented via usage tracking in plan-db.sh. Extended thinking mode increases task completion quality but adds cost. Monitor via dashboard cost analytics.
- **Multi-provider expansion**: 18 models available across Anthropic, OpenAI, Google Gemini. Per-task model routing via spec.json model field. See ADR-0010 for orchestration strategy.
- **Token cost optimization**: ADR-0009 compact format achieves 35-47% reduction in instruction token cost. Opus 4.6 128K output ceiling allows comprehensive responses without truncation.
