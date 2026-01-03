# TODAY.md - 3 Gennaio 2026

**Status**: IN PROGRESS
**Owner**: Roberto + Claude
**Branch**: development
**Operating Mode**: PLAN -> EXECUTE -> VERIFY -> CLOSE
**Blockers**: PR #106 in attesa di merge

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

---

## EXECUTIVE SUMMARY

| Category | Count | Action |
|----------|-------|--------|
| Code-verified fixes | 8 | None (verified working) |
| Manual QA required | 10 | Execute manual tests |
| Open issues (unfixed) | 10 | Requires development |
| New initiatives | 2 | Welcome Experience + Supporti |
| PR #106 | 1 | Merge after QA |

**ZERO DEFERRED** - All requested work is in the execution plan.

---

## SEZIONE A: VERIFIED FIXES (No action needed)

| Bug | Description | Evidence | File |
|-----|-------------|----------|------|
| BUG 1 | Voice switching | No Web Speech fallback | `use-onboarding-tts.ts:206-215` |
| BUG 12 | Toast position | `top-0 right-0` | `toast.tsx:184` |
| BUG 14 | Dropdown transparent | `bg-white dark:bg-slate-900` | `dropdown-menu.tsx:49,67` |
| BUG 16 | SVGLength error | Container dimension check | `markmap-renderer.tsx:116` |
| BUG 22 | Parent dashboard mock | Empty state added | `parent-dashboard.tsx:40` |
| BUG 23 | Metrics mock data | Empty state added | `success-metrics-dashboard.tsx:78` |
| BUG 29 | Placeholder alerts | toast.success() | `summaries-view.tsx:72-91` |
| BUG 31 | Skip welcome | "Salta intro" link | `welcome/page.tsx:537-545` |

**Build Status**: Typecheck PASS, Lint PASS, Build PASS

---

## SEZIONE B: PR #106 STATUS

| Field | Value |
|-------|-------|
| State | **OPEN** |
| URL | https://github.com/Roberdan/ConvergioEdu/pull/106 |
| Additions | 8453 |
| Deletions | 1402 |
| Files | 100+ |

**Action Required**:
1. [ ] Complete Manual QA -> [qa/manual-qa.md](qa/manual-qa.md)
2. [ ] If QA PASS: `gh pr merge 106 --merge`
3. [ ] If QA FAIL: Create issue for failed items

---

## EXECUTION WAVES OVERVIEW

| Wave | Content | File | Status |
|------|---------|------|--------|
| Wave 0 | QA + PR merge + Worktrees | This file + [qa/manual-qa.md](qa/manual-qa.md) | [ ] |
| Wave 1-2 | Bug fixes (10 issues) | [waves/wave-1-2-bugfixes.md](waves/wave-1-2-bugfixes.md) | [ ] |
| Wave 3 | Welcome Experience | [waves/wave-3-welcome.md](waves/wave-3-welcome.md) | [ ] |
| Wave 4 | Supporti Consolidation | [waves/wave-4-supporti.md](waves/wave-4-supporti.md) | [ ] |
| Wave 5 | Merge + Verification | This file | [ ] |

---

## MASTER SIGN-OFF CHECKLIST

### Wave 0: Prerequisites (Roberto)

| Step | Task | Status | Date | Signature |
|------|------|--------|------|-----------|
| 0.1 | Manual QA (10 items) | [ ] | | Roberto |
| 0.2 | Merge PR #106 | [ ] | | Roberto |
| 0.3 | Create worktrees | [ ] | | Roberto |

### Wave 1-2: Bug Fixes (Claude-A)

| Step | Task | Status | Date | Signature |
|------|------|--------|------|-----------|
| 1.1 | C-5: Storico per Coach/Buddy (P0) | [ ] | | Claude-A |
| 1.2 | C-9: Header Counters Real-time (P0) | [ ] | | Claude-A |
| 2.1 | C-2: Session Recap + Memory (P1) | [ ] | | Claude-A |
| 2.2 | C-3: Layout sticky (P1) | [ ] | | Claude-A |
| 2.3 | C-4: Azure costs (P1) | [ ] | | Claude-A |
| 2.4 | C-1: STT Discrepancy (P1) | [ ] | | Claude-A |
| 2.5 | C-6: Timer + XP Bar (P2) | [ ] | | Claude-A |
| 2.6 | C-7: Demo Accessibility (P1) | [ ] | | Claude-A |
| 2.7 | C-8: Cafe Audio Realistico (P2) | [ ] | | Claude-A |
| 2.8 | C-10: Demo in frame (P1) | [ ] | | Claude-A |
| - | PR fix/wave-1-2-bugs created | [ ] | | Claude-A |

### Wave 3: Welcome Experience (Claude-B team)

| Step | Task | Status | Date | Signature |
|------|------|--------|------|-----------|
| 3.1 | hero-section.tsx | [ ] | | Claude-B1 |
| 3.2 | features-section.tsx | [ ] | | Claude-B2 |
| 3.3 | guides-section.tsx | [ ] | | Claude-B3 |
| 3.4 | quick-start.tsx | [ ] | | Claude-B1 |
| 3.5 | Refactor page.tsx | [ ] | | Claude-B1 |
| 3.6 | Skip flow | [ ] | | Claude-B1 |
| 3.7 | Returning user logic | [ ] | | Claude-B1 |
| 3.8 | Settings link | [ ] | | Claude-B1 |
| 3.9 | E2E tests | [ ] | | Claude-B1 |
| - | PR feat/welcome-experience created | [ ] | | Claude-B1 |

### Wave 4: Supporti (Claude-C team)

| Step | Task | Status | Date | Signature |
|------|------|--------|------|-----------|
| 4.1 | Struttura base | [ ] | | Claude-C1 |
| 4.2 | Sidebar | [ ] | | Claude-C1 |
| 4.3 | Material card | [ ] | | Claude-C2 |
| 4.8 | Redirect /archivio | [ ] | | Claude-C2 |
| 4.9 | Redirect /materiali | [ ] | | Claude-C2 |
| 4.10 | Navigation update | [ ] | | Claude-C1 |
| 4.4 | Filtri tipo | [ ] | | Claude-C1 |
| 4.5 | Filtri materia | [ ] | | Claude-C1 |
| 4.6 | Filtri data | [ ] | | Claude-C1 |
| 4.7 | Search full-text | [ ] | | Claude-C1 |
| 4.11 | E2E tests | [ ] | | Claude-C1 |
| - | PR feat/supporti-consolidation created | [ ] | | Claude-C1 |

### Wave 5: Merge & Verification

| Step | Task | Status | Date | Signature |
|------|------|--------|------|-----------|
| 5.1 | PLACEHOLDER/MOCK check (0 matches) | [ ] | | Claude |
| 5.2 | Thor quality gate passed | [ ] | | Thor |
| 5.3 | EXECUTION-CHECKLIST.md for bugfixes PR | [ ] | | Claude-A |
| 5.4 | EXECUTION-CHECKLIST.md for welcome PR | [ ] | | Claude-B |
| 5.5 | EXECUTION-CHECKLIST.md for supporti PR | [ ] | | Claude-C |
| 5.6 | Merge PR bugfixes | [ ] | | Roberto |
| 5.7 | Rebase + Merge PR welcome | [ ] | | Roberto |
| 5.8 | Rebase + Merge PR supporti | [ ] | | Roberto |
| 5.9 | typecheck | [ ] | | Claude |
| 5.10 | lint | [ ] | | Claude |
| 5.11 | build | [ ] | | Claude |
| 5.12 | E2E suite | [ ] | | Claude |
| 5.13 | CHANGELOG | [ ] | | Claude |

**Pre-Merge Verification** (per `docs/plans/VERIFICATION-PROCESS.md`):
```bash
grep -ri PLACEHOLDER src/ | wc -l  # Must be 0
grep -ri MOCK_DATA src/ | wc -l    # Must be 0
npm run typecheck && npm run lint && npm run build  # All must pass
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
*Last Updated: 3 January 2026 (Integrated BUG 28/20 from legacy files - now 10 open issues)*
*Operating Mode: PLAN -> EXECUTE -> VERIFY -> CLOSE*
*Worktrees: wt-bugfixes, wt-welcome, wt-supporti*
*Max Parallel Agents: 3 (per CLAUDE.md)*
