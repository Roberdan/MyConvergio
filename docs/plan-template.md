# Plan Template Reference

## Status Dashboard (MANDATORY at TOP of every plan)

```markdown
# PLAN: [Task Name]
Generated: [timestamp via `date`]
Last Updated: [timestamp via `date`]

## STATUS DASHBOARD
| Phase | Status | Progress |
|-------|--------|----------|
| Phase 1: [name] | ✅ DONE | 100% |
| Phase 2: [name] | 🔄 IN PROGRESS | 60% |
| Phase 3: [name] | ⏳ PENDING | 0% |

**Current Focus**: [Exact task being worked on]
**Blockers**: [Any issues]
**Next Up**: [What happens next]
```

## Phase Structure

```markdown
## Phase N: [Name] - [Complexity: Low/Medium/High]

### Parallel Lane A (can run with Lane B)
- [ ] Task N.1: [Action] → File: `path/file.ts`
- [ ] Task N.2: [Action] → File: `path/file.ts`

### Parallel Lane B
- [ ] Task N.3: [Action] → File: `path/other.ts`

### Sequential (depends on above)
- [ ] Task N.4: [Integration]

**Verification**: `npm run test && npm run typecheck`
**Checkpoint**: Commit "feat: Phase N complete"
```

## State Files

### progress.txt (freeform notes)
```
Session N progress:
- Completed: [what was done]
- Issues: [problems encountered]
- Next: [what to do next]
```

### tasks.json (structured tracking)
```json
{
  "tasks": [
    {"id": 1, "name": "task name", "status": "done"},
    {"id": 2, "name": "task name", "status": "in_progress"},
    {"id": 3, "name": "task name", "status": "pending"}
  ],
  "lastUpdated": "2025-12-28T10:00:00Z"
}
```

## Anti-Compression Rules

- Each subagent task: MAX 500 characters
- Max 3 edits per agent call
- If truncated: retry with smaller scope
- Prefer multiple small agents over one large
