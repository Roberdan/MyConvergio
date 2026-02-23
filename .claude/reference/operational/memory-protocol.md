<!-- v2.0.0 | 15 Feb 2026 | Token-optimized per ADR 0009 -->

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
