---
name: orchestration
version: "2.0.0"
context: fork
user-invocable: true
allowed-tools:
  - Read
  - Glob
  - Grep
  - Bash
  - Task
---

# Multi-Agent Orchestration via Agent Teams

## When to Use

- Complex tasks with 4+ independent subtasks
- Release preparations with multiple verification steps
- Large refactoring across multiple file domains
- Any plan created by `strategic-planner` agent

## Team Lifecycle

```
TeamCreate → TaskCreate (assign) → SendMessage → execute → shutdown
```

1. **Create team**: `TeamCreate` with named members (agents by name)
2. **Create tasks**: `TaskCreate` per subtask with title, description, assigned agent
3. **Assign work**: `SendMessage` to each member with task context
4. **Monitor**: `TaskList` to track progress
5. **Update**: `TaskUpdate` when status changes
6. **Shutdown**: `SendMessage` type: shutdown_request to each member

## Example Team Creation Pattern

```
TeamCreate: "plan-{id}-executors" with members [baccio, marco, luca, rex]

TaskCreate: title="T-01: API refactor", assignee=baccio, description="Refactor src/api/"
TaskCreate: title="T-02: Component update", assignee=marco, description="Update src/components/"
TaskCreate: title="T-03: Tests", assignee=luca, description="Write unit tests"
TaskCreate: title="T-04: DB migration", assignee=rex, description="Run migrations"

SendMessage: to baccio → "Execute T-01: Refactor src/api/ per plan specs"
SendMessage: to marco → "Execute T-02: Update src/components/ per plan specs"
SendMessage: to luca → "Execute T-03: Write tests for updated components"
SendMessage: to rex → "Execute T-04: Run DB migrations and verify schema"
```

## Shutdown Protocol

When all tasks are done or on abort:

```
SendMessage: to baccio → type: shutdown_request
SendMessage: to marco → type: shutdown_request
SendMessage: to luca → type: shutdown_request
SendMessage: to rex → type: shutdown_request
```

## Pattern Selection

| Workers | Pattern    | Use When                      |
| ------- | ---------- | ----------------------------- |
| 2-3     | Small team | Independent parallel tasks    |
| 4-6     | Swarm      | Multi-domain plan execution   |
| 7+      | Mega-swarm | Opus coordinator + TeamCreate |

## Task Assignment Rules

1. **NO FILE OVERLAP** - Assign disjoint file sets per agent
2. **WORKTREE MANDATORY** - Each agent must use wave worktree (not main)
3. **TDD per task** - Each agent follows RED → GREEN workflow
4. **Thor per task** - `plan-db.sh validate-task` before marking done

## Integration with strategic-planner

```
Skill(skill="planner")
→ Plan approved
→ Skill(skill="orchestration")
→ TeamCreate + parallel SendMessage
→ All tasks complete → wave merge
```

## Task Tracking Commands

```bash
TaskList                              # All tasks + status
TaskUpdate <id> status=done           # Mark task complete
plan-db.sh validate-task <id> <plan>  # Thor per-task gate
plan-db.sh validate-wave <wave_id>    # Thor per-wave gate
wave-worktree.sh merge <plan> <wave>  # Merge on all done
```

## Related

- Agent: `agents/strategic-planner.md`
- Coordination patterns: `agents/core_utility/xavier-coordination-patterns.md`
- ADR: `docs/adr/0020-ecosystem-modernization-v2.1.md`
- Disabled predecessor: `skills/.disabled/orchestration-kitty/SKILL.md`
