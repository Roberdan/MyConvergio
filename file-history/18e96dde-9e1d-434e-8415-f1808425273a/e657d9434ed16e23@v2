# Coordination Reference

**Purpose**: Technical reference for multi-agent parallel execution

---

## Conflict Analysis

### File Overlap Matrix

| Task Pair | Shared Files | Risk | Resolution |
|-----------|--------------|------|------------|
| C-5 vs C-2 | `conversation-memory.ts`, stores | HIGH | Sequential in same worktree |
| Wave 3.7 vs Wave 4.10 | `src/app/page.tsx` | MEDIUM | Wave 3 merges first, Wave 4 rebases |
| Wave 2.1 vs Wave 1.1 | Memory system | HIGH | 1.1 complete before 2.x starts |

### Tasks That Could Invalidate Earlier Work

| Later Task | Earlier Task | Risk | Mitigation |
|------------|--------------|------|------------|
| 3.5 (refactor page) | 3.1-3.4 (components) | LOW | Components are imports, not modified |
| 4.10 (nav update) | 4.8-4.9 (redirects) | NONE | Independent operations |
| 5.x (verify) | All | NONE | Read-only verification |

### Redundant Tasks

NONE IDENTIFIED - All tasks are necessary and distinct.

---

## Worktree Strategy

### Branch Structure

```
development (base, after PR #106)
    |
    +---> wt-bugfixes/
    |     Branch: fix/wave-1-2-bugs
    |     Tasks: 1.1, 2.1, 2.2, 2.3, 2.4, 2.5, 2.6, 2.7
    |     Reason: Sequential work on all 8 bug fixes
    |
    +---> wt-welcome/
    |     Branch: feat/welcome-experience
    |     Tasks: 3.1-3.9
    |     Reason: Isolated new feature, no overlap with bugfixes
    |
    +---> wt-supporti/
          Branch: feat/supporti-consolidation
          Tasks: 4.1-4.11
          Reason: Isolated new feature, touches different files
```

### Worktree Commands

```bash
# After PR #106 merged, create worktrees:
git worktree add ../wt-bugfixes -b fix/wave-1-2-bugs
git worktree add ../wt-welcome -b feat/welcome-experience
git worktree add ../wt-supporti -b feat/supporti-consolidation
```

---

## Agent Assignment

### Parallel Execution Groups

**IMPORTANT**: Max 3 concurrent agents at any time (Claude Code limit)

**Execution Sequence**:
1. **Wave 1-2 FIRST** (sequential, blocking)
2. **THEN Wave 3 OR Wave 4** (not both simultaneously)

**Group A: Bugfixes (Sequential - 1 Agent)**
- Agent: Claude-A
- Worktree: `wt-bugfixes`
- Tasks: 1.1 -> 1.2 -> 2.1 -> 2.2 -> 2.3 -> 2.4 -> 2.5 -> 2.6 -> 2.7 -> 2.8
- Reason: Memory/conversation code has interdependencies
- **Blocks**: Wave 3 and Wave 4 (must complete first)

**Group B: Welcome Components (Parallel - up to 3 Agents)**
- Agents: Claude-B1, Claude-B2, Claude-B3
- Worktree: `wt-welcome`
- Parallel tasks: 3.1, 3.2, 3.3 (max 3 concurrent)
- Sequential after: 3.5 -> 3.6 -> 3.7 -> 3.8 -> 3.9
- **Starts after**: Wave 1-2 complete

**Group C: Supporti (Mixed - 2 Agents max)**
- Agents: Claude-C1, Claude-C2
- Worktree: `wt-supporti`
- Phase 1: 4.1 (C1 solo)
- Phase 2: 4.2+4.3+4.8+4.9+4.10 (C1 + C2 parallel)
- Phase 3: 4.4 -> 4.5 -> 4.6 -> 4.7 -> 4.11 (sequential)
- **Starts after**: Wave 1-2 complete
- **Can run parallel with**: Wave 3 (total = 3+2 = 5 agents, VIOLATES LIMIT)
- **CORRECTION**: Wave 3 completes THEN Wave 4 starts

---

## Agent Coordination Protocol

1. Each agent updates TODAY.md before starting a task
2. Use `[in progress Agent-X]` prefix in status
3. Commit to worktree branch frequently
4. Signal completion in TODAY.md before next task

---

## Merge Strategy

### Merge Order (DAG)

```
PR #106 (BLOCKING)
    |
    v
+-----------------------------------------------------+
|  PARALLEL EXECUTION ZONE (after PR #106 merged)     |
|                                                      |
|  wt-bugfixes ------+                                |
|  wt-welcome -------+---> Merge Point 1              |
|  wt-supporti ------+     (when all complete)        |
|                                                      |
+-----------------------------------------------------+
    |
    v
Merge Order:
1. fix/wave-1-2-bugs -> development (PR #1xx)
2. feat/welcome-experience -> development (PR #1xx) [rebase first]
3. feat/supporti-consolidation -> development (PR #1xx) [rebase first]
    |
    v
Wave 5: Verification on development
```

### Merge Protocol

| Order | Branch | PR Title | Rebase Required |
|-------|--------|----------|-----------------|
| 1 | fix/wave-1-2-bugs | fix: conversation history per character + P1 bugs | NO |
| 2 | feat/welcome-experience | feat: redesigned welcome experience | YES (after #1) |
| 3 | feat/supporti-consolidation | feat: unified Supporti area | YES (after #2) |

### Conflict Resolution

- If merge conflict: **Rebase loses, main wins**
- Conflicted files must be manually resolved by the agent that owns the branch
- After resolution: Re-run `typecheck && lint && build`

---

## Plan Update Protocol

### Who Updates TODAY.md

- **Any agent** working on a task MUST update status before starting and after completing
- **Roberto** updates Wave 0 and final approvals
- **Merging agent** updates merge status

### Status Format

```markdown
| Step | Status | Date | Signature |
|------|--------|------|-----------|
| 1.1 | [in progress Claude-A] | 2026-01-03 14:30 | Claude-A |
| 1.1 | [done] | 2026-01-03 15:45 | Claude-A |
```

### Coordination Rules

1. **Before starting task**: Pull latest TODAY.md, update status to `[in progress Agent-X]`
2. **During work**: Commit to worktree branch (not main)
3. **After completing**: Update status to `[done]`, add date and signature
4. **If blocked**: Update status to `[blocked: reason]`
5. **Conflict**: If two agents claim same task, first timestamp wins

### File Locking (Soft)

- TODAY.md is the coordination file
- Agents should `git pull` before editing
- Use atomic commits for status updates
- If conflict on TODAY.md: Both agents re-pull and retry

---

## Verification Commands

Before declaring any step "Done":

```bash
npm run typecheck && npm run lint && npm run build
```

All must pass. No exceptions.

---

## PR Compliance (MANDATORY)

Before creating ANY Pull Request:

1. **Fill Evidence Section** in the wave file (all checks)
2. **Invoke Thor quality gate**:
   ```bash
   # Thor runs automatically via thor-quality-assurance-guardian agent
   # Checks:
   # - No workarounds (@ts-ignore, TODO, HACK, etc.)
   # - No placeholders (PLACEHOLDER, MOCK_DATA)
   # - Build/lint/typecheck pass
   # - E2E tests have assertions (not just waitFor)
   # - Accessibility compliance (where applicable)
   ```
3. **Thor approval required** before merge
4. **Guardian protocol**: Verify no scope creep, no autonomous decisions undisclosed

Reference: `~/.claude/rules/guardian.md` and `thor-quality-assurance-guardian` agent

---

*Parent document: [TODAY.md](../TODAY.md)*
*Created: 3 January 2026*
