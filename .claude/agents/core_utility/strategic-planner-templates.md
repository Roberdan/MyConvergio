---
name: strategic-planner-templates
description: Plan document templates for strategic-planner. Reference module.
version: "2.0.0"
maturity: stable
providers:
  - claude
constraints: ["Reference module — plan templates"]
---

# Strategic Planner Templates

## Plan Document Structure

```markdown
# [Project Name] Execution Plan

**Date**: [YYYY-MM-DD]
**Last Update**: [YYYY-MM-DD HH:MM TZ]  ← USE `date +"%Y-%m-%d %H:%M %Z"`
**Version**: [X.Y.Z]
**Objective**: [Clear goal statement]

---

## PROGRESS DASHBOARD

**Overall**: ████████░░░░░░░░░░░░ **X%** (X/Y tasks)
**Elapsed**: Xh Xm | **Started**: [HH:MM TZ]

| Wave | Tasks | Progress | Started | Ended | Time | Status |
|:----:|:-----:|----------|:-------:|:-----:|:----:|:------:|
| W0 | X/Y | ██████████ 100% | 10:00 | 10:45 | 45m | ✅ |
| W1 | X/Y | ████████░░ 80% | 10:45 | 11:50 | 1h05m | ✅ |
| W2 | X/Y | ███░░░░░░░ 35% | 11:50 | - | 45m+ | 🔄 |
| W3 | X/Y | ░░░░░░░░░░ 0% | - | - | - | ⏳ |

> **Time format**: Same day = `HH:MM`, different day = `MM-DD HH:MM`
> **Progress bar**: Each █ = 10%

| Current Wave | Blockers | Active | Next Up |
|:------------:|----------|:------:|---------|
| Wave X | None | C2, C3 | T-XX |

---

## OPERATING INSTRUCTIONS
> 1. Update status (`⬜` → `✅✅`)  2. Add completion timestamp  3. Save  4. `date +"%Y-%m-%d %H:%M %Z"`

---

## PROGRESS STATUS
**Last update**: [YYYY-MM-DD HH:MM TZ] | **Current wave**: [WAVE X] | **Total**: [X/Y tasks (Z%)]

### WAVE 0 - Prerequisites
| Status | ID | Task | Assignee | Est | Started | Ended | Actual |
|:------:|-----|------|----------|:---:|---------|-------|:------:|
| ⬜ | W0A | [Task] | **CLAUDE 2** | 1h | | | |

### WAVE FINAL - Documentation & Deployment (MANDATORY)
| Status | ID | Task | Assignee | Est | Started | Ended | Actual |
|:------:|-----|------|----------|:---:|---------|-------|:------:|
| ⬜ | WF-01 | Update CHANGELOG.md | **CLAUDE 1** | 15m | | | |
| ⬜ | WF-02 | Create/update ADRs | **CLAUDE 1** | 30m | | | |
| ⬜ | WF-03 | Update README if new features | **CLAUDE 1** | 20m | | | |
| ⬜ | WF-04 | Update API docs if changed | **CLAUDE 1** | 20m | | | |
| ⬜ | WF-05 | Final lint/typecheck/build | **CLAUDE 1** | 10m | | | |
| ⬜ | WF-06 | Create release commit/tag | **CLAUDE 1** | 10m | | | |

> ⚠️ **WAVE FINAL is NOT optional**

---

## ISSUE TRACKING
| Issue | Title | Tasks | Progress | Owner | Started | Ended | Time |
|:-----:|-------|:-----:|----------|:-----:|---------|-------|:----:|
| #XX | [Issue title] | T-01, T-02 | ████░░░░░░ 40% | C2 | 10:00 | - | 1h+ |

## TIME STATISTICS
| Phase | Estimated | Actual | Variance |
|-------|:---------:|:------:|:--------:|
| Wave 0 | Xh | Yh | +Z% |
| **TOTAL** | **Xh** | **Yh** | **+Z%** |

## SUMMARY BY WAVE
| Wave | Description | Tasks | Done | Status |
|:----:|-------------|:-----:|:----:|:------:|
| W0 | Prerequisites | X | Y | Z% |
| **TOTAL** | | **X** | **Y** | **Z%** |

## ADRs (Architecture Decision Records)
[Document all significant decisions]

## COMMIT HISTORY
| Date | Commit | Wave | Description |
|------|--------|:----:|-------------|

## RISK REGISTER
| ID | Risk | Impact | Probability | Mitigation |
|----|------|:------:|:-----------:|------------|
```

## Claude Roles Table

```markdown
## CLAUDE ROLES

| Claude | Role | Assigned Tasks | Files (NO OVERLAP!) |
|--------|------|----------------|---------------------|
| **CLAUDE 1** | 🎯 COORDINATOR | Monitor, verify | - |
| **CLAUDE 2** | 👨‍💻 IMPLEMENTER | [Task IDs] | [file patterns] |
| **CLAUDE 3** | 👨‍💻 IMPLEMENTER | [Task IDs] | [file patterns] |
| **CLAUDE 4** | 👨‍💻 IMPLEMENTER | [Task IDs] | [file patterns] |

> **MAX 4 CLAUDE** - Beyond becomes unmanageable
```

## Execution Tracker Table

```markdown
### Phase X: [Name] — 0/N [BLOCKS/Parallel with...]

| Status | ID | Task | Assignee | Issue | Est | Started | Ended | Actual |
|:------:|-----|------|----------|:-----:|:---:|---------|-------|:------:|
| ⬜ | T-01 | [Description] | **CLAUDE 2** | #XX | 2h | | | |
| 🔄 | T-02 | [Description] | **CLAUDE 3** | #XX | 1h | 2025-01-01 10:00 | | |
| ✅ | T-03 | [Description] | **CLAUDE 2** | #XX | 1h | 2025-01-01 09:00 | 2025-01-01 09:45 | 45m |
```

## Task Test Criteria (TDD — MANDATORY)

Every task MUST include test_criteria. Tests written BEFORE implementation.

```markdown
### T-01: [Task Title]

**F-xx**: F-03
**Test Criteria** (write BEFORE implementation):

| Type | Target | Description | Framework |
|------|--------|-------------|-----------|
| unit | ComponentName | Behavior to verify | Jest/Vitest |
| integration | POST /api/endpoint | Expected behavior | Supertest |
| e2e | User flow name | Complete scenario | Playwright |

**Acceptance**: All tests GREEN before marking done.
```

**Test Types**: unit (isolated, mock externals) | integration (real DB/services) | e2e (browser automation)

## ADR Template

```markdown
## ADR-NNN: [Decision Title]

| Field | Value |
|-------|-------|
| **Status** | ✅ Accepted / ⏸️ Pending / ❌ Rejected |
| **Date** | YYYY-MM-DD |
| **Deciders** | [Names] |

**Context**: [Why is this decision needed?]
**Decision**: [What was decided]
**Rationale**: [Why this option was chosen]
**Consequences**: (+) [Positive] | (-) [Trade-offs]
```

## Non-Negotiable Rules

```markdown
## NON-NEGOTIABLE CODING RULES

### Zero Tolerance
Zero tolerance for: bullshit, tech debt, errors, warnings, forgotten deferred items, console.logs, commented code, temp files. If wrong, FIX IT NOW.

### Mandatory Verification for EVERY Task
\`\`\`bash
npm run lint        # MUST be 0 errors, 0 warnings
npm run typecheck   # MUST compile without errors
npm run build       # MUST build successfully
\`\`\`

### Testing Rules
- If tests exist → they MUST pass
- If you add functionality → add tests

### Honest Behavior
- "It works" = tests pass + no errors + verified output shown
- "It's done" = code written + tests pass + committed
- "It's fixed" = bug reproduced + fix applied + test proves fix
- NO CLAIM WITHOUT EVIDENCE

### Engineering Fundamentals (MANDATORY)
Apply ISE: https://microsoft.github.io/code-with-engineering-playbook/
```

## Changelog

- **2.0.0** (2026-01-10): Extracted from strategic-planner.md for modularity
