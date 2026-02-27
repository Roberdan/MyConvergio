<!-- v2.1.0 | 27 Feb 2026 | Agent Teams routing + new commands -->

# Agent Routing

## Routing Logic

**Route**: MyConvergio agents first (`$MYCONVERGIO_HOME/agents/`), fallback `~/.claude/agents/`

## Delegation Triggers

| Trigger                   | Reason                          |
| ------------------------- | ------------------------------- |
| Specialist needed         | Domain expertise required       |
| Parallel work             | Multiple independent tasks      |
| Fresh context             | Avoid context contamination     |
| Parallel independent work | Agent Teams native coordination |

## Mandatory Skill Routing (NON-NEGOTIABLE)

| Trigger                | Claude Code                           | Copilot CLI     | NOT                        |
| ---------------------- | ------------------------------------- | --------------- | -------------------------- |
| Create plan (3+ tasks) | `Skill(skill="planner")`              | `@planner`      | EnterPlanMode, manual text |
| Execute plan           | `Skill(skill="execute", args="{id}")` | `@execute {id}` | Direct file editing        |
| Validate               | `Task(subagent_type="thor")`          | `@validate`     | Self-declaring done        |

EnterPlanMode = no DB registration = VIOLATION. _Why: Plan 225._

## Task Routing Table

| Task                 | Use                                      |
| -------------------- | ---------------------------------------- |
| Explore codebase     | `Explore`                                |
| Execute plan task    | `task-executor`                          |
| Quality validation   | `thor-quality-assurance-guardian`        |
| Complex debugging    | `adversarial-debugger`                   |
| Parallel multi-agent | Agent Teams (`TeamCreate`/`SendMessage`) |

## Repo Knowledge

```bash
~/.claude/scripts/repo-index.sh  # Generate context
repo-info                        # Quick summary
agent-versions.sh                # All component versions (--json, --check)
agent-version-bump.sh <file> <major|minor|patch>  # Bump semver
script-versions.sh               # All script versions (--json, --stale, --category <name>)
```

## Useful Commands

| Command     | Purpose                                |
| ----------- | -------------------------------------- |
| `/teleport` | Move current session context to web UI |
| `/debug`    | Troubleshoot agent/plan/session issues |
| `/copy`     | Copy code block from agent response    |
