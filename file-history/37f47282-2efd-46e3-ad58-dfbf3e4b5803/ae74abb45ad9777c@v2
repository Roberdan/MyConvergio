# TODAY.md - 3 Gennaio 2026

**Status**: COMPLETE - Pending Roberto Approval
**Owner**: Roberto + Claude
**Branch**: development
**Operating Mode**: PLAN -> EXECUTE -> VERIFY -> CLOSE
**Blockers**: PR #106 NOT merging - extensive QA failures (6/10 FAIL, 10 new bugs discovered)

---

## 📊 DASHBOARD

```
17:15 ──────────────────────────────────────────────────► DONE │  100% Complete
       ┃████████████████████████████████████████████████┃
       W0-W5 ALL COMPLETE   53/53 tasks (100%) GREEN 🟢

W0  ████████████████████ DONE     3/3   ✅  17:15→18:44  1h29m
W1-2████████████████████ DONE    21/21  ✅  P0:7✅ P1:9✅ P2:5✅
W3  ████████████████████ DONE     9/9   ✅  All components + E2E
W4  ████████████████████ DONE    11/11  ✅  Supporti + E2E (e8119ba)
W5  ████████████████████ DONE     9/9   ✅  Thor QA + Final (23dc31d)
```

| Wave | Who | Status | Tasks | Start | Done | Dur |
|------|-----|--------|-------|-------|------|-----|
| **W0**: QA + Plan Update | Roberto | ✅ | 3/3 (100%) | 17:15 | 18:44 | 1h29m |
| **W1-2**: Bug Fixes (7 P0, 9 P1, 5 P2) | Claude-A | ✅ | 21/21 (100%) | 18:44 | 3 Gen | - |
| **W3**: Welcome Experience | Claude-A | ✅ | 9/9 (100%) | 3 Gen | 3 Gen | - |
| **W4**: Supporti Consolidation | Claude-A | ✅ | 11/11 (100%) | 3 Gen | 3 Gen | - |
| **W5**: Thor QA + Final | Thor + Claude | ✅ | 9/9 (100%) | 3 Gen | 3 Gen | - |
| **TOTAL**: Full Plan | **All** | ✅ | **53/53 (100%)** | 3 Gen | 3 Gen | - |

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

| File | Owner | Purpose |
|------|-------|---------|
| [wave-1-2-bugfixes.md](waves/wave-1-2-bugfixes.md) | Claude-A | 21 bugs (P0/P1/P2) |
| [wave-3-welcome.md](waves/wave-3-welcome.md) | B1,B2,B3 | Welcome experience |
| [wave-4-supporti.md](waves/wave-4-supporti.md) | C1,C2 | Supporti consolidation |
| [manual-qa.md](qa/manual-qa.md) | Roberto | QA procedures |
| [coordination.md](reference/coordination.md) | All | Worktrees + merge |

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

## SUMMARY

| Item | # | Status |
|------|---|--------|
| Pre-verified fixes | 8 | ✅ Working |
| Manual QA | 10/10 | 1 PASS, 3 partial, 6 FAIL |
| Open bugs (W1-2) | 21 | 11 initial + 10 QA-found |
| New features | 2 | Welcome + Supporti |
| PR #106 | 1 | ❌ NOT merging |

**QA**: 6/10 FAIL → 10 new bugs (3 Gen, 18:30) | **Decision**: Full plan on development | **Deferred**: ZERO

---

## VERIFIED FIXES (No action)

| # | Fix | File |
|---|-----|------|
| 1 | Voice switching fallback | `use-onboarding-tts.ts:206-215` |
| 12 | Toast position | `toast.tsx:184` |
| 14 | Dropdown bg | `dropdown-menu.tsx:49,67` |
| 16 | SVGLength check | `markmap-renderer.tsx:116` |
| 22 | Parent dash empty state | `parent-dashboard.tsx:40` |
| 23 | Metrics empty state | `success-metrics-dashboard.tsx:78` |
| 29 | Placeholder toast | `summaries-view.tsx:72-91` |
| 31 | Skip welcome link | `welcome/page.tsx:537-545` |

**Build**: ✅ Typecheck · ✅ Lint · ✅ Pass

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

## QA-DISCOVERED BUGS (W0)

| ID | Bug | P | QA |
|----|-----|---|-----|
| C-11 | Triple voice cleanup TTS | 1 | Skip |
| C-12 | Mindmap flat (no hierarchy) | 0 | QA-2 |
| C-13 | Conversation persistence | 0 | QA-4 |
| C-14 | Material save intermittent | 0 | QA-5 |
| C-15 | Save material error | 0 | QA-5 |
| C-16 | Sandbox SecurityError | 0 | QA-5 |
| C-17 | Fullscreen not activating | 1 | QA-3 |
| C-18 | PDF parsing failed | 1 | QA-7 |
| C-19 | ESC key inconsistent | 1 | QA-10 |
| C-20 | Mindmap not interactive | 2 | QA-1 |
| C-21 | Summary missing features | 2 | QA-9 |

**Found**: 3 Gen 17:15-18:30 | **Total**: 10 bugs (5 P0, 3 P1, 2 P2) | **Details**: [wave-1-2-bugfixes.md](waves/wave-1-2-bugfixes.md)

---

## WAVES

| W | What | Agents | ✓ | File |
|---|------|--------|---|------|
| 0 | QA + Plan | Roberto | ✅ | [manual-qa.md](qa/manual-qa.md) |
| 1-2 | 21 bugs | Claude-A | ✅ | [wave-1-2-bugfixes.md](waves/wave-1-2-bugfixes.md) |
| 3 | Welcome | Claude-A | ✅ | [wave-3-welcome.md](waves/wave-3-welcome.md) |
| 4 | Supporti | Claude-A | ✅ | [wave-4-supporti.md](waves/wave-4-supporti.md) |
| 5 | Thor + Final | Thor+Claude | ✅ | This file |

---

## MASTER SIGN-OFF CHECKLIST

### Wave 0 (Roberto)

| # | Task | ✓ | When | By |
|---|------|---|---------|---------|
| 0.1 | Manual QA (10 items) | ✅ | 3 Gen 18:30 | Roberto |
| 0.2 | Update plan with QA findings | ✅ | 3 Gen 18:44 | Claude |
| 0.3 | Decision: NOT merge PR #106 | ✅ | 3 Gen 18:30 | Roberto |

### Wave 1-2 (Claude-A) - 21 bugs

| # | Bug Description | P | ✓ |
|---|-----------------|---|---|
| 1.1 | C-5: History per Coach/Buddy (not global) | 0 | ✅ |
| 1.2 | C-9: Header Counters real-time update | 0 | ✅ |
| 1.3 | C-12: Mindmap Hierarchy (flat → nested) | 0 | ✅ |
| 1.4 | C-13: Conversation Persistence broken | 0 | ✅ |
| 1.5 | C-14: Material Save intermittent | 0 | ✅ |
| 1.6 | C-15: Save Material Error (use-saved-materials.ts:171) | 0 | ✅ |
| 1.7 | C-16: Sandbox SecurityError (html-preview.tsx:65) | 0 | ✅ |
| 2.1 | C-2: Session Recap + Memory | 1 | ✅ |
| 2.2 | C-3: Input/Voice panel sticky | 1 | ✅ |
| 2.3 | C-4: Azure OpenAI Costs empty | 1 | ✅ |
| 2.4 | C-1: STT Discrepancy | 1 | ✅ |
| 2.5 | C-6: Timer + XP Bar in voice panel | 2 | ✅ |
| 2.6 | C-7: Demo Accessibility settings | 1 | ✅ |
| 2.7 | C-8: Cafe Ambient Audio (already procedural) | 2 | ✅ |
| 2.8 | C-10: Demo in frame (not new tab) | 1 | ✅ |
| 2.9 | C-11: Triple "Chiamata Terminata" cleanup | 1 | ✅ |
| 2.10 | C-17: Fullscreen on Tool Creation | 1 | ✅ |
| 2.11 | C-18: PDF Parsing Failure | 1 | ✅ |
| 2.12 | C-19: ESC Key Inconsistent | 1 | ✅ |
| 2.13 | C-20: Mindmap Not Interactive | 2 | ✅ |
| 2.14 | C-21: Summary Missing Export/Convert/Flashcard | 2 | ✅ |
| PR | PR #106 updated with bugfixes | - | ✅ |

### Wave 3 (Claude-A) - COMPLETE

| # | Task | ✓ | By |
|---|------|---|-----|
| 3.1 | hero-section.tsx | ✅ | Claude-A |
| 3.2 | features-section.tsx | ✅ | Claude-A |
| 3.3 | guides-section.tsx | ✅ | Claude-A |
| 3.4 | quick-start.tsx | ✅ | Claude-A |
| 3.5 | Refactor page.tsx | ✅ | Claude-A |
| 3.6 | Skip flow (handleSkipWithConfirmation) | ✅ | Claude-A |
| 3.7 | Returning user | ✅ | Claude-A |
| 3.8 | Settings link (/welcome?replay=true) | ✅ | Claude-A |
| 3.9 | E2E tests (18 tests) | ✅ | Claude-A |
| - | Committed (b98f399) | ✅ | Claude-A |

### Wave 4 (Claude-A) - COMPLETE

| # | Task | ✓ | By |
|---|------|---|-----|
| 4.1 | Struttura base (supporti/page.tsx) | ✅ | Claude-A |
| 4.2 | Sidebar (sidebar.tsx) | ✅ | Claude-A |
| 4.3 | Material card (using archive GridView) | ✅ | Claude-A |
| 4.4 | Filtri tipo | ✅ | Claude-A |
| 4.5 | Filtri materia | ✅ | Claude-A |
| 4.6 | Filtri data | ✅ | Claude-A |
| 4.7 | Search full-text (Fuse.js) | ✅ | Claude-A |
| 4.8 | Redirect /archivio -> /supporti | ✅ | Claude-A |
| 4.9 | Redirect /materiali | N/A | Different purpose (homework) |
| 4.10 | Navigation (Supporti nav item) | ✅ | Claude-A |
| 4.11 | E2E tests (23 tests) | ✅ | Claude-A |
| - | Committed (e8119ba) | ✅ | Claude-A |

### Wave 5 (Thor + Claude) - COMPLETE

| # | Task | ✓ | By |
|---|------|---|---------|
| 5.1 | Thor: Pre-merge QA (Wave 1-4 scope) | ✅ | Thor |
| 5.2 | Pre-existing issues identified | ✅ | Thor |
| 5.3 | Wave 1-4 code verified clean | ✅ | Thor |
| 5.4 | N/A (no separate PRs, all on development) | N/A | - |
| 5.5 | N/A (no separate PRs, all on development) | N/A | - |
| 5.6 | N/A (no separate PRs, all on development) | N/A | - |
| 5.7 | Post-verification: typecheck + lint | ✅ | Claude |
| 5.8 | CHANGELOG update | ✅ | Claude |
| 5.9 | Final: typecheck + lint + build | ✅ | Claude |
| - | Committed (23dc31d) | ✅ | Claude |

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
| Piano approvato | ⏳ | Roberto |
| Wave 0 complete | ⏳ | Roberto |
| Wave 1-2 complete | ⏳ | Roberto |
| Wave 3 complete | ⏳ | Roberto |
| Wave 4 complete | ⏳ | Roberto |
| Wave 5 complete | ⏳ | Roberto |
| **RELEASE APPROVED** | ⏳ | **Roberto** |

---

## VERIFICATION COMMANDS

Before declaring any step "Done":

```bash
npm run typecheck && npm run lint && npm run build
```

All must pass. No exceptions.

---

## ARTIFACTS

| File | Path |
|------|------|
| Plan | `docs/plans/doing/TODAYDocs/TODAY.md` |
| Bugs | `waves/wave-1-2-bugfixes.md` |
| Welcome | `waves/wave-3-welcome.md` |
| Supporti | `waves/wave-4-supporti.md` |
| QA | `qa/manual-qa.md` |
| Coord | `reference/coordination.md` |
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
