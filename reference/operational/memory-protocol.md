<!-- v2.1.0 | 27 Feb 2026 | Added auto-memory vs manual memory section -->

# Memory Protocol

Structured cross-session continuity via persistent memory files. See format template below.

## Save Path Convention

`~/.claude/memory/{project-name}/{YYYY-MM-DD}-{short-description}.md` — e.g., `~/.claude/memory/my-project/2026-01-29-auth-refactor.md`

## When to Save

- Before ending complex multi-session task | After significant architectural decisions
- When context lost on restart | Before switching project/branch

## Memory File Format

```
# Memory: {Short Description}

Project: {project-name} | Date: {YYYY-MM-DD HH:MM CET} | Session: {session-id}

## Task Overview

- **Request**: [original in 1-2 sentences]
- **Scope**: [in/out]
- **Status**: in_progress | completed | blocked

## Completed Work

- [x] [task/file] - [what was done]

## Modified Files

| File | Change | Status |
| --- | --- | --- |
| path/to/file.ts | Added middleware | committed |

## Decisions & Failed Approaches

| Type | Item | Rationale | Rejected |
| --- | --- | --- | --- |
| Decision | JWT | Stateless, scalable | Session cookies |
| Failed | Redis | Overkill | Start simple, scale later |

## Next Steps (Priority Order)

1. [ ] [immediate next action]
2. [ ] [follow-up action]

## Context to Preserve

- **Active branch**: {branch-name}
- **Plan ID**: {plan-id if applicable}
- **Key files**: [files next session needs to read first]
- **Blockers**: [unresolved issues]
- **User preferences**: [expressed preferences to remember]
```

## Resume Protocol

Check `~/.claude/memory/{project-name}/` for recent files. Read, summarize, ask user to continue.

## Helper Script

`~/.claude/scripts/memory-save.sh {project} "short description"` — creates file with template.

## Cleanup

Archive files >90 days to `~/.claude/memory/.archive/`. Never delete.

---

## Auto-Memory vs Manual Memory

Two memory systems coexist. Both active. Neither replaces the other.

### Auto-Memory (Claude native v2.1.59+)

- **What**: Automatic cross-session recall. Claude saves/retrieves context without explicit commands.
- **Best for**: Recurring patterns, file locations, project structure, ephemeral context that repeats.
- **How**: Claude manages it internally. No user action required.
- **View/edit**: `/memory` command to inspect or modify.

### Manual Memory (`~/.claude/projects/*/memory/`)

- **What**: Explicit saves via Write/Edit tools. User-controlled markdown files.
- **Best for**: Strategic decisions, stable conventions, architecture patterns, decisions that must persist reliably.
- **How**: Explicitly write files using this protocol (save path, format, resume protocol above).
- **View/edit**: Read/Write/Edit tools directly on `~/.claude/memory/{project}/` files.

### Coexistence Rule

| Scenario                                      | Use                                                           |
| --------------------------------------------- | ------------------------------------------------------------- |
| Ephemeral context (file locations, patterns)  | Auto-memory                                                   |
| Durable decisions (architecture, conventions) | Manual memory                                                 |
| Conflict between the two                      | Manual memory takes precedence (present in CLAUDE.md context) |

**Decision order**: CLAUDE.md > manual memory files > auto-memory recall.
