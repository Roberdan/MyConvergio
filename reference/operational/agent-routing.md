<!-- v2.0.0 | 15 Feb 2026 | Token-optimized per ADR 0009 -->

# Agent Routing

## Extended Agents

**Technical**: baccio, dario, marco, otto, rex, luca
**Leadership**: ali, amy, antonio, dan

## Routing Logic

**Route**: MyConvergio agents first (`$MYCONVERGIO_HOME/agents/`), fallback `~/.claude/agents/`

## Delegation Triggers

| Trigger           | Reason                      |
| ----------------- | --------------------------- |
| Specialist needed | Domain expertise required   |
| Parallel work     | Multiple independent tasks  |
| Fresh context     | Avoid context contamination |

## Maturity Levels

| Status  | Agents                                                                  |
| ------- | ----------------------------------------------------------------------- |
| Stable  | strategic-planner, thor, task-executor, marcus, socrates, wanda, xavier |
| Preview | diana, po, taskmaster, app-release-manager, adversarial-debugger        |

## Codex Usage

**Suggest for**: Mechanical/repetitive bulk tasks
**Never for**: Architecture, security, debugging

## Task Routing Table

| Task               | Use                               |
| ------------------ | --------------------------------- |
| Explore codebase   | `Explore`                         |
| Execute plan task  | `task-executor`                   |
| Quality validation | `thor-quality-assurance-guardian` |
| Complex debugging  | `adversarial-debugger`            |

## Repo Knowledge

```bash
~/.claude/scripts/repo-index.sh  # Generate context
repo-info                        # Quick summary
agent-versions.sh                # All component versions (--json, --check)
agent-version-bump.sh <file> <major|minor|patch>  # Bump semver
script-versions.sh               # All script versions (--json, --stale, --category <name>)
```
