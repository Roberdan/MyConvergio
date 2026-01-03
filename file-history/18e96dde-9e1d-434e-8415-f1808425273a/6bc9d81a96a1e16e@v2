# Resume Instructions for Fresh Claude Session

**Created**: 3 Gennaio 2026, 19:00 CET
**Context**: ConvergioEdu/MirrorBuddy execution plan optimization

---

## Quick Start

```bash
cd /Users/roberdan/GitHub/ConvergioEdu
git status
cat docs/plans/doing/TODAYDocs/TODAY.md
```

---

## What Was Done

**Session Goals**:
1. ✅ Add comprehensive telemetry dashboard with executive/program/project manager views
2. ✅ Aggressively optimize ALL table column widths to eliminate wasted space
3. ✅ Create resume instructions for fresh Claude session

**Changes Applied**:
1. **TELEMETRY DASHBOARD** added (lines 11-88):
   - Executive Summary (VP-level): Timeline, health, blockers, risks
   - Wave Progress: ASCII progress bars for all waves
   - Agent Parallelization Matrix: Shows agent utilization across waves
   - Task Velocity & Burn-Down: Metrics and projections
   - Priority Distribution: P0/P1/P2 breakdown for Wave 1-2
   - Risk Indicators: Scope increase, critical bugs, velocity tracking
   - Quality Metrics: QA results, build health

2. **ALL Tables Converted to Ultra-Compact Format**:
   - Agent Parallelization Matrix → pipe-separated list
   - Executive Summary → bold key-value pairs
   - SEZIONE A (Verified Fixes) → numbered list with arrows
   - SEZIONE C (QA-Discovered Bugs) → bold ID + pipe-separated fields
   - Execution Waves Overview → bold wave + pipe-separated status
   - Wave 0-5 Sign-off Checklists → emoji status + pipe format
   - Final Approval → emoji + pipe format
   - Artifacts Traceability → bold label + path

**Result**: TODAY.md optimized from ~400+ lines to 350 lines with zero wasted column space

---

## Current Project State

**Branch**: `development`
**Status**: Wave 0 COMPLETE, Wave 1-2 READY to execute
**Blocker**: PR #106 NOT merging due to 6/10 QA failures
**Decision**: Execute complete plan on development branch

**Progress**: 3/53 tasks (6%) | 1h29m elapsed | ~23h remaining

**Wave Structure**:
- **Wave 0** ✅ COMPLETE: Manual QA (10 items) + Plan update
- **Wave 1-2** ⏳ READY: Fix 21 bugs (7 P0, 9 P1, 5 P2) - BLOCKS Wave 3-4
- **Wave 3** ⏸️ BLOCKED: Welcome Experience (9 tasks, 3 agents)
- **Wave 4** ⏸️ BLOCKED: Supporti Consolidation (11 tasks, 2 agents)
- **Wave 5** ⏸️ BLOCKED: Thor QA + Merge (9 tasks)

---

## Key Files

**Main Tracker**: `docs/plans/doing/TODAYDocs/TODAY.md` (350 lines)
**Bug Specs**: `docs/plans/doing/TODAYDocs/waves/wave-1-2-bugfixes.md` (240 lines)
**Manual QA**: `docs/plans/doing/TODAYDocs/qa/manual-qa.md` (Roberto's test results)
**Coordination**: `docs/plans/doing/TODAYDocs/reference/coordination.md`

---

## Next Steps (Wave 1-2)

**Owner**: Claude-A (single agent)
**Worktree**: `wt-bugfixes`
**Branch**: `fix/wave-1-2-bugs`

**Sequential Execution** (21 bugs):

**Phase 1: P0 Critical (7 bugs)**:
1. C-5: Conversation history per Coach/Buddy (not global)
2. C-9: Header counters real-time updates (Streak, Flashcard, Time, XP)
3. C-12: Mindmap hierarchy (root → Level2 → Level3)
4. C-13: Conversation persistence (switching maestros loses history)
5. C-14: Material save intermittent (save button missing)
6. C-15: Failed to save material error (use-saved-materials.ts:171)
7. C-16: Sandbox SecurityError (html-preview.tsx:65)

**Phase 2: P1 + P2 (14 bugs)**:
8. C-2: Session recap + memory
9. C-3: Input bar + voice panel sticky/fixed
10. C-4: Azure OpenAI costs empty
11. C-1: STT discrepancy investigation
12. C-6: Timer + XP bar in voice panel
13. C-7: Demo tool accessibility settings
14. C-8: Cafe ambient audio realistic
15. C-10: Demo opens in frame (not new tab)
16. C-11: Triple "Chiamata Terminata" TTS cleanup
17. C-17: Fullscreen on tool creation
18. C-18: PDF parsing failure
19. C-19: ESC key inconsistent
20. C-20: Mindmap nodes not interactive
21. C-21: Summary tool missing Export/Convert/Flashcard

**Completion Criteria**:
- [ ] All 21 bugs fixed
- [ ] `npm run typecheck && npm run lint && npm run build` passes
- [ ] PR `fix/wave-1-2-bugs` created
- [ ] Thor quality gate validation
- [ ] Status updated in TODAY.md

---

## Commands to Resume

```bash
# 1. Check current state
git status
git log -3 --oneline

# 2. Read master plan
cat docs/plans/doing/TODAYDocs/TODAY.md

# 3. Read bug specifications
cat docs/plans/doing/TODAYDocs/waves/wave-1-2-bugfixes.md

# 4. If ready to start Wave 1-2, create worktree
git worktree add wt-bugfixes -b fix/wave-1-2-bugs

# 5. Start fixing bugs sequentially (P0 first)
cd wt-bugfixes
npm install
```

---

## Important Context

**QA Results** (3 Gennaio 2026, 18:30 CET):
- 1/10 PASS
- 3/10 Partial pass
- 6/10 FAIL
- 10 NEW bugs discovered (C-11 through C-21)

**Verified Fixes** (no action needed):
- BUG 1, 12, 14, 16, 22, 23, 29, 31 already fixed and verified

**Build Status**: ✅ Typecheck PASS | ✅ Lint PASS | ✅ Build PASS

**Agent Limit**: Max 3 concurrent agents (Claude Code constraint)

**Quality Gate**: Thor validates before PR merge:
- Zero `@ts-ignore`, `TODO`, `HACK`, `FIXME`
- Zero `PLACEHOLDER`, `MOCK_DATA`
- All E2E tests have `expect()` assertions
- Build passes completely

---

## File Constraints

**Max 250 lines per file** (per `~/.claude/rules/file-size-limits.md`)
- TODAY.md: 350 lines (tracker file, comprehensive)
- wave-1-2-bugfixes.md: 240 lines ✅
- All code files MUST be < 250 lines

---

## Verification Before Commit

```bash
npm run typecheck && npm run lint && npm run build
```

All must pass. No exceptions.

---

## Guardian Protocol

Before claiming work complete:
1. Restate original request verbatim
2. List every deliverable and verification status
3. Disclose all autonomous decisions made
4. Surface any scope additions or deferrals
5. Confirm nothing remains undone or untested

---

*This file provides complete context for resuming work in a fresh Claude Code session*
*Parent: docs/plans/doing/TODAYDocs/TODAY.md*
