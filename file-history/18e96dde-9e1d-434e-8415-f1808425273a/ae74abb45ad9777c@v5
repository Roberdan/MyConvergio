# TODAY.md - 3 Gennaio 2026

**Status**: IN PROGRESS
**Owner**: Roberto + Claude
**Branch**: development
**Operating Mode**: PLAN -> EXECUTE -> VERIFY -> CLOSE
**Blockers**: PR #106 NOT merging - extensive QA failures (6/10 FAIL, 10 new bugs discovered)

---

## EXECUTION DASHBOARD

### Overall Progress

| Phase | Status | Progress | Started | Completed | Duration |
|-------|--------|----------|---------|-----------|----------|
| **Wave 0** | ✅ COMPLETE | 3/3 (100%) | 3 Gen 2026, 17:15 CET | 3 Gen 2026, 18:44 CET | 1h 29m |
| **Wave 1-2** | ⏳ READY | 0/21 (0%) | - | - | - |
| **Wave 3** | ⏸️ BLOCKED | 0/9 (0%) | - | - | - |
| **Wave 4** | ⏸️ BLOCKED | 0/11 (0%) | - | - | - |
| **Wave 5** | ⏸️ BLOCKED | 0/9 (0%) | - | - | - |
| **TOTAL** | 🔄 IN PROGRESS | 3/53 (6%) | 3 Gen 2026 | - | - |

### Wave 0: QA & Planning (COMPLETE)

| Task | ✓ | Start | Done | Time | By |
|------|---|-------|------|------|-----|
| Manual QA execution (10 items) | ✅ | 17:15 | 18:30 | 1h 15m | R |
| Update plan with QA findings | ✅ | 18:30 | 18:44 | 14m | C |
| Decision: NOT merge PR #106 | ✅ | 18:30 | 18:30 | - | R |

**Result**: 6/10 QA FAIL, 10 new bugs discovered, all added to Wave 1-2

### Wave 1-2: Bug Fixes (READY - 21 bugs)

**Status**: Ready to execute
**P0 Critical**: 7 bugs (33%)
**P1 High**: 9 bugs (43%)
**P2 Medium**: 5 bugs (24%)
**Blocking**: Wave 3 and Wave 4

---

## MODULAR STRUCTURE

This plan is split into focused sub-files for token optimization.

| Section | File | Purpose | Owner |
|---------|------|---------|-------|
| Bug Fixes | [waves/wave-1-2-bugfixes.md](waves/wave-1-2-bugfixes.md) | P0/P1/P2 bug specifications and execution | Claude-A |
| Welcome | [waves/wave-3-welcome.md](waves/wave-3-welcome.md) | Welcome experience IA and execution | Claude-B team |
| Supporti | [waves/wave-4-supporti.md](waves/wave-4-supporti.md) | Supporti consolidation IA and execution | Claude-C team |
| QA | [qa/manual-qa.md](qa/manual-qa.md) | Manual QA test procedures | Roberto |
| Coordination | [reference/coordination.md](reference/coordination.md) | Worktrees, agents, merge strategy | All |

**Agent Instructions**: Read only the file(s) relevant to your assigned work.

**Execution Model**: Sequential waves with controlled parallelism
- Wave 0: Roberto (manual QA + PR merge)
- Wave 1-2: 1 agent (Claude-A) - sequential bugfixes → **BLOCKS Wave 3-4**
- Wave 3: Up to 3 agents (B1, B2, B3) - parallel component creation
- Wave 4: 2 agents (C1, C2) - mixed parallel/sequential
- **Max concurrent: 3 agents** (adheres to Claude Code limits)
- **Execution order**: Wave 0 → Wave 1-2 → Wave 3 → Wave 4 → Wave 5
- **NO parallel execution** of Wave 3 + Wave 4 (would exceed 3-agent limit)

---

## EXECUTIVE SUMMARY

| Category | Count | Status |
|----------|-------|--------|
| Code-verified fixes | 8 | Verified working (Section A) |
| Manual QA executed | 10/10 | COMPLETE - 1 PASS, 3 partial, 6 FAIL |
| Open bugs (Wave 1-2) | 21 | 11 initial + 10 QA-discovered |
| New initiatives | 2 | Welcome Experience + Supporti |
| PR #106 | 1 | NOT MERGING - QA failures |

**QA RESULT**: 6/10 FAIL, 10 new bugs discovered (3 Gennaio 2026, 18:30 CET)
**DECISION**: Stay on development, execute complete TODAY.md plan with all bugs
**ZERO DEFERRED** - All discovered issues tracked in Wave 1-2

---

## SEZIONE A: VERIFIED FIXES (No action needed)

| # | Description | Evidence / File |
|---|-------------|-----------------|
| 1 | Voice switching | No Web Speech fallback → `use-onboarding-tts.ts:206-215` |
| 12 | Toast position | `top-0 right-0` → `toast.tsx:184` |
| 14 | Dropdown transparent | `bg-white dark:bg-slate-900` → `dropdown-menu.tsx:49,67` |
| 16 | SVGLength error | Container dimension check → `markmap-renderer.tsx:116` |
| 22 | Parent dashboard mock | Empty state added → `parent-dashboard.tsx:40` |
| 23 | Metrics mock data | Empty state added → `success-metrics-dashboard.tsx:78` |
| 29 | Placeholder alerts | toast.success() → `summaries-view.tsx:72-91` |
| 31 | Skip welcome | "Salta intro" link → `welcome/page.tsx:537-545` |

**Build Status**: Typecheck PASS, Lint PASS, Build PASS

---

## SEZIONE B: PR #106 STATUS

**State**: OPEN (NOT MERGING)
**URL**: https://github.com/Roberdan/ConvergioEdu/pull/106
**QA**: FAILED - 6/10 items failed
**Decision**: Stay on development, do NOT merge

**QA Execution Complete** (3 Gennaio 2026, 18:30 CET):
- [x] Manual QA executed -> [qa/manual-qa.md](qa/manual-qa.md)
- QA FAIL: 6/10 complete failures, 3/10 partial pass, 1/10 pass
- 10 new bugs discovered (C-12 through C-21)
- **Action**: All bugs added to Wave 1-2, execute complete plan on development branch
- PR #106 will remain open, NOT merged until all work complete and user-approved

---

## SEZIONE C: QA-DISCOVERED BUGS (Found during Wave 0)

| ID | Description | P | QA |
|----|-------------|---|-----|
| C-11 (NEW-1) | Triple "Chiamata Terminata" TTS on voice cleanup | 1 | Skip |
| C-12 (7) | Mindmap completely flat, no hierarchy | 0 | QA-2 |
| C-13 (11) | Conversation persistence broken + console error | 0 | QA-4 |
| C-14 (13) | Material save intermittent, no save button | 0 | QA-5 |
| C-15 (NEW-2) | Failed to save material error at use-saved-materials.ts:171 | 0 | QA-5 |
| C-16 (NEW-3) | Sandbox SecurityError at html-preview.tsx:65 | 0 | QA-5 |
| C-17 (8) | Fullscreen not activating on tool creation | 1 | QA-3 |
| C-18 (19) | PDF parsing completely failed | 1 | QA-7 |
| C-19 (27) | ESC key inconsistent across app | 1 | QA-10 |
| C-20 (5) | Mindmap nodes not interactive/expandable | 2 | QA-1 |
| C-21 (26) | Summary missing Export/Convert/Flashcard features | 2 | QA-9 |

**Discovered**: 3 Gennaio 2026, 17:15-18:30 CET (during Manual QA execution)
**Total**: 10 new bugs (5 P0, 3 P1, 2 P2) added to Wave 1-2
**Details**: See [wave-1-2-bugfixes.md](waves/wave-1-2-bugfixes.md) for full specifications

---

## EXECUTION WAVES OVERVIEW

| Wave | Content | File | Agents | Status |
|------|---------|------|--------|--------|
| Wave 0 | QA + Plan Update | This file + [qa/manual-qa.md](qa/manual-qa.md) | Roberto | [COMPLETE] |
| Wave 1-2 | Bug fixes (21 issues: 11 initial + 10 QA-discovered) | [waves/wave-1-2-bugfixes.md](waves/wave-1-2-bugfixes.md) | 1 (Claude-A) | [ ] READY |
| Wave 3 | Welcome Experience | [waves/wave-3-welcome.md](waves/wave-3-welcome.md) | 3 (B1, B2, B3) | [ ] BLOCKED by Wave 1-2 |
| Wave 4 | Supporti Consolidation | [waves/wave-4-supporti.md](waves/wave-4-supporti.md) | 2 (C1, C2) | [ ] BLOCKED by Wave 1-2 |
| Wave 5 | Thor + Merge + Verification | This file | Thor + Roberto | [ ] BLOCKED by Wave 1-4 |

---

## MASTER SIGN-OFF CHECKLIST

### Wave 0: Prerequisites (Roberto)

| # | Task | ✓ | When | By |
|---|------|---|------|-----|
| 0.1 | Manual QA (10 items) | ✅ | 3 Gen 18:30 | Roberto |
| 0.2 | Update plan with QA findings | ✅ | 3 Gen 18:44 | Claude |
| 0.3 | Decision: NOT merge PR #106 | ✅ | 3 Gen 18:30 | Roberto |

### Wave 1-2: Bug Fixes (Claude-A) - 21 bugs total

| # | Task (Priority) | ✓ | Start | Done | Time |
|---|-----------------|---|-------|------|------|
| 1.1 | C-5: History per Coach/Buddy (P0) | [ ] | | | |
| 1.2 | C-9: Header Counters (P0) | [ ] | | | |
| 1.3 | C-12: Mindmap Hierarchy (P0) | [ ] | | | |
| 1.4 | C-13: Conversation Persistence (P0) | [ ] | | | |
| 1.5 | C-14: Material Save (P0) | [ ] | | | |
| 1.6 | C-15: Save Material Error (P0) | [ ] | | | |
| 1.7 | C-16: Sandbox SecurityError (P0) | [ ] | | | |
| 2.1 | C-2: Session Recap + Memory (P1) | [ ] | | | |
| 2.2 | C-3: Layout sticky (P1) | [ ] | | | |
| 2.3 | C-4: Azure costs (P1) | [ ] | | | |
| 2.4 | C-1: STT Discrepancy (P1) | [ ] | | | |
| 2.5 | C-6: Timer + XP Bar (P2) | [ ] | | | |
| 2.6 | C-7: Demo Accessibility (P1) | [ ] | | | |
| 2.7 | C-8: Cafe Audio (P2) | [ ] | | | |
| 2.8 | C-10: Demo in frame (P1) | [ ] | | | |
| 2.9 | C-11: Triple voice cleanup (P1) | [ ] | | | |
| 2.10 | C-17: Fullscreen Tool Creation (P1) | [ ] | | | |
| 2.11 | C-18: PDF Parsing (P1) | [ ] | | | |
| 2.12 | C-19: ESC Key Inconsistent (P1) | [ ] | | | |
| 2.13 | C-20: Tool Not Interactive (P2) | [ ] | | | |
| 2.14 | C-21: Summary Missing Features (P2) | [ ] | | | |
| - | PR fix/wave-1-2-bugs created | [ ] | | | |

### Wave 3: Welcome Experience (Claude-B team)

| # | Task | ✓ | By |
|---|------|---|----|
| 3.1 | hero-section.tsx | [ ] | B1 |
| 3.2 | features-section.tsx | [ ] | B2 |
| 3.3 | guides-section.tsx | [ ] | B3 |
| 3.4 | quick-start.tsx | [ ] | B1 |
| 3.5 | Refactor page.tsx | [ ] | B1 |
| 3.6 | Skip flow | [ ] | B1 |
| 3.7 | Returning user logic | [ ] | B1 |
| 3.8 | Settings link | [ ] | B1 |
| 3.9 | E2E tests | [ ] | B1 |
| - | PR feat/welcome-experience | [ ] | B1 |

### Wave 4: Supporti (Claude-C team)

| # | Task | ✓ | By |
|---|------|---|----|
| 4.1 | Struttura base | [ ] | C1 |
| 4.2 | Sidebar | [ ] | C1 |
| 4.3 | Material card | [ ] | C2 |
| 4.8 | Redirect /archivio | [ ] | C2 |
| 4.9 | Redirect /materiali | [ ] | C2 |
| 4.10 | Navigation update | [ ] | C1 |
| 4.4 | Filtri tipo | [ ] | C1 |
| 4.5 | Filtri materia | [ ] | C1 |
| 4.6 | Filtri data | [ ] | C1 |
| 4.7 | Search full-text | [ ] | C1 |
| 4.11 | E2E tests | [ ] | C1 |
| - | PR feat/supporti-consolidation | [ ] | C1 |

### Wave 5: Thor Quality Gate + Merge

| # | Task | ✓ | By |
|---|------|---|----|
| 5.1 | Thor: Pre-merge QA (bugfixes PR) | [ ] | Thor |
| 5.2 | Thor: Pre-merge QA (welcome PR) | [ ] | Thor |
| 5.3 | Thor: Pre-merge QA (supporti PR) | [ ] | Thor |
| 5.4 | Merge PR bugfixes | [ ] | Roberto |
| 5.5 | Rebase + Merge PR welcome | [ ] | Roberto |
| 5.6 | Rebase + Merge PR supporti | [ ] | Roberto |
| 5.7 | Thor: Post-merge integration test | [ ] | Thor |
| 5.8 | CHANGELOG update | [ ] | Claude |
| 5.9 | Final: typecheck + lint + build | [ ] | Claude |

**Thor Quality Gate Criteria** (automated by thor-quality-assurance-guardian):
```bash
# Workaround pattern detection
grep -r "@ts-ignore\|@ts-expect-error\|eslint-disable\|TODO\|HACK\|FIXME" src/ --include="*.ts" --include="*.tsx" | wc -l  # Must be 0

# Placeholder/Mock detection
grep -ri "PLACEHOLDER\|MOCK_DATA" src/ --include="*.ts" --include="*.tsx" | wc -l  # Must be 0

# Build verification
npm run typecheck && npm run lint && npm run build  # All must pass

# E2E assertion verification
# Thor validates: ogni E2E test ha expect() assertions, non solo waitFor()
```

---

## FINAL APPROVAL

| Checkpoint | Status | Approver |
|------------|--------|----------|
| Piano approvato | [ ] | Roberto |
| Wave 0 complete | [ ] | Roberto |
| Wave 1-2 complete | [ ] | Roberto |
| Wave 3 complete | [ ] | Roberto |
| Wave 4 complete | [ ] | Roberto |
| Wave 5 complete | [ ] | Roberto |
| **RELEASE APPROVED** | [ ] | Roberto |

---

## VERIFICATION COMMANDS

Before declaring any step "Done":

```bash
npm run typecheck && npm run lint && npm run build
```

All must pass. No exceptions.

---

## ARTIFACTS TRACEABILITY

| Artifact | Location |
|----------|----------|
| Master Plan | `docs/plans/doing/TODAYDocs/TODAY.md` |
| Bug Fixes | `docs/plans/doing/TODAYDocs/waves/wave-1-2-bugfixes.md` |
| Welcome IA | `docs/plans/doing/TODAYDocs/waves/wave-3-welcome.md` |
| Supporti IA | `docs/plans/doing/TODAYDocs/waves/wave-4-supporti.md` |
| Manual QA | `docs/plans/doing/TODAYDocs/qa/manual-qa.md` |
| Coordination | `docs/plans/doing/TODAYDocs/reference/coordination.md` |
| CHANGELOG | `CHANGELOG.md` |

---

*Created: 3 January 2026*
*Author: Claude Opus 4.5*
*Last Updated: 3 January 2026 (Aligned with Thor + Guardian protocols)*
*Operating Mode: PLAN -> EXECUTE -> VERIFY -> CLOSE*
*Worktrees: wt-bugfixes, wt-welcome, wt-supporti*
*Max Parallel Agents: 3 (per Claude Code constraints)*
*Quality Gate: Thor (thor-quality-assurance-guardian)*
*Compliance: execution.md, guardian.md, file-size-limits.md*
