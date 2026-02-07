# Memory Protocol

Structured protocol for cross-session continuity via persistent memory files.

## Save Path Convention
```
~/.claude/memory/{project-name}/{YYYY-MM-DD}-{short-description}.md
```

Example: `~/.claude/memory/mirrorbuddy/2026-01-29-auth-refactor.md`

## When to Save
- Before ending a complex multi-session task
- After significant architectural decisions
- When context would be lost on session restart
- Before switching to a different project/branch

## Memory File Format

```markdown
# Memory: {Short Description}
Project: {project-name}
Date: {YYYY-MM-DD HH:MM CET}
Session: {session-id if available}

## Task Overview
- **Request**: [original user request in 1-2 sentences]
- **Scope**: [what's in/out]
- **Status**: [in_progress | completed | blocked]

## Completed Work
- [x] [task/file] - [what was done]
- [x] [task/file] - [what was done]

## Modified Files
| File | Change | Status |
|------|--------|--------|
| path/to/file.ts | Added auth middleware | committed |

## Decisions Made
| Decision | Rationale | Alternatives Rejected |
|----------|-----------|----------------------|
| Used JWT | Stateless, scalable | Session cookies (server state) |

## Failed Approaches
| Approach | Why It Failed | Lesson |
|----------|---------------|--------|
| Redis sessions | Overkill for this scale | Start simple, scale later |

## Next Steps (Priority Order)
1. [ ] [immediate next action]
2. [ ] [follow-up action]

## Context to Preserve
- **Active branch**: {branch-name}
- **Plan ID**: {plan-id if applicable}
- **Key files**: [files the next session needs to read first]
- **Blockers**: [any unresolved issues]
- **User preferences**: [any expressed preferences to remember]
```

## Resume Protocol
When starting a new session on the same project:
1. Check `~/.claude/memory/{project-name}/` for recent files
2. Read the most recent memory file
3. Summarize: "Resuming from {date}. Last session: {summary}. Next steps: {list}"
4. Ask user: "Continue from where we left off?"

## Helper Script
```bash
~/.claude/scripts/memory-save.sh {project} "short description"
# Creates file with correct path and template
```

## Cleanup
- Memory files older than 90 days: archive to `~/.claude/memory/.archive/`
- Completed tasks with no pending follow-ups: safe to archive
- Never delete — archive preserves organizational learning
