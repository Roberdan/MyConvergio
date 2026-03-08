# Copilot Instructions — MyConvergio

Multi-tool agent platform (Claude Code, Copilot CLI, OpenCode). Distributed via install scripts and Make targets.

## Workflow Enforcement (MANDATORY — ALL AGENTS)

Every agent (Claude, Copilot, OpenCode, custom) MUST follow this sequence:

```
GOAL → @planner → DB approved → @execute {id} → @validate per-task → @validate per-wave → merge → done
```

| Step | Command | Skip = REJECTED |
|------|---------|-----------------|
| Plan | `@planner` (Opus model) | No direct plan creation |
| Create in DB | `planner-create.sh` (3 reviews required) | No `plan-db.sh create` |
| Execute | `@execute {id}` | No direct file edits during plan |
| Task done | `plan-db-safe.sh update-task {id} done` | No `plan-db.sh update-task done` |
| Validate | `@validate {task_id}` or `plan-db.sh validate-task` | No self-declaring done |
| Merge | After all tasks Thor-validated | No merge with pending tasks |

### After Every Task Completion

1. `plan-checkpoint.sh save {plan_id}`
2. `plan-db.sh validate-task {task_id} {plan_id}`
3. Launch next task

### Single Fixes (No Plan Needed)

Direct edits OK for isolated bug fixes. Workflow only required for 3+ task work.

## Product Conventions

- YAML frontmatter required in all agent .md files
- Max 250 lines per file
- SemVer 2.0.0 for product and agent artifacts
- Conventional commits
- `make test && make lint && make validate` before commit

## Validation

```bash
make test    # Unit tests
make lint    # Linting
make validate # Full validation
```
