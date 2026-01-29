# Maturity Lifecycle

All agents and skills follow a 4-stage lifecycle.

## Stages

| Stage | Criteria | Routing Priority |
|-------|----------|------------------|
| `experimental` | New, untested, may have issues | Use only when explicitly requested |
| `preview` | 2+ successful uses, basic validation | Available but prefer stable alternatives |
| `stable` | Thor-validated, production-proven | Default choice for routing |
| `deprecated` | Superseded, move to `.disabled/` | Never route to, warn if referenced |

## Rules
- New agents/skills start at `experimental`
- Promotion requires evidence (successful task completion, Thor pass)
- Demotion happens on repeated failures or when superseded
- `deprecated` agents must have a documented replacement
- Agent frontmatter SHOULD include `maturity:` field

## Current Registry

### Agents (stable)
- strategic-planner, thor-quality-assurance-guardian, task-executor
- marcus-context-memory-keeper, socrates-first-principles-reasoning
- wanda-workflow-orchestrator, xavier-coordination-patterns

### Agents (preview)
- diana-performance-dashboard, po-prompt-optimizer
- taskmaster-strategic-task-decomposition-master
- app-release-manager

### Skills (stable)
- architecture, code-review, debugging, security-audit

### Skills (preview)
- performance, orchestration

### Skills (deprecated)
- strategic-analysis (in `.disabled/`), project-management (in `.disabled/`)
