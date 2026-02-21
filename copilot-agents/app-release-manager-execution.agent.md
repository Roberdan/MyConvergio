---
name: app-release-manager-execution
description: Execution phases (3-5) for app-release-manager. Reference module. Updated for i18n, SEO, and maestri validation.
version: "3.2.0"
---

# Release Manager Execution Phases

## PHASE 3: COLLECT RESULTS & AUTO-FIX

**USE TaskOutput TO COLLECT ALL BACKGROUND RESULTS:**

```
1. TaskOutput(task_A_id, block=true)
2. TaskOutput(task_B_id, block=true)
... collect all results ...
```

### Auto-Fix Protocol

| Issue               | Auto-Fix Action                 | Priority |
| ------------------- | ------------------------------- | -------- |
| Trailing whitespace | `sed -i '' 's/[[:space:]]*$//'` | P1       |
| Missing EOF newline | `echo >> file`                  | P1       |
| Debug prints        | Edit tool to remove             | P0       |
| TODO comments       | Remove or implement             | P0       |
| Unused imports      | Remove them                     | P1       |
| Version mismatch    | Update VERSION file             | P0       |

**For each auto-fixable issue:**

1. FIX IT with Edit/Write tool
2. Verify fix worked
3. Log: "Auto-fixed: {description}"

**For non-fixable issues:**

1. Add to blocking issues list
2. Continue checking


## PHASE 4: DECISION

### iOS Release Question (Capacitor projects ONLY)

If `ios/` directory or `capacitor.config.ts` detected, **ASK THE USER**:

```
"Web release is ready. Do you also want to release for iOS?
[Yes - include iOS release] [No - web only]"
```

- **Yes**: Look for iOS release checks in repo-local `.claude/agents/` (e.g., `ios-release-checks.md`). Run them. All must PASS.
- **No**: Skip iOS entirely.

### Blocking Issues (ALWAYS BLOCK)

- ANY compiler error
- ANY test failure
- ANY security vulnerability (hardcoded secrets)
- ANY TODO/FIXME in code
- ANY failing CI check
- ANY iOS check failure (only if user chose iOS release)

### Generate Report

```markdown
# Release Readiness Report

## Status: 🟢 APPROVED / 🔴 BLOCKED

### Wave 1 Results

| Check    | Status    | Issues |
| -------- | --------- | ------ |
| Build    | PASS/FAIL | ...    |
| Security | PASS/FAIL | ...    |
| Quality  | PASS/FAIL | ...    |
| Tests    | PASS/FAIL | ...    |
| Docs     | PASS/FAIL | ...    |

### Wave 2 Results

| Check        | Status    | Issues |
| ------------ | --------- | ------ |
| Dependencies | PASS/FAIL | ...    |
| Hygiene      | PASS/FAIL | ...    |
| Versions     | PASS/FAIL | ...    |
| AI Models    | PASS/FAIL | ...    |

### Wave 2 Extended Results (i18n & SEO Apps)

| Check             | Status    | Issues |
| ----------------- | --------- | ------ |
| i18n Completeness | PASS/FAIL | ...    |
| Locale Loading    | PASS/FAIL | ...    |
| New Maestri       | PASS/FAIL | ...    |
| SEO Multilingual  | PASS/FAIL | ...    |

### iOS Release Gate (Capacitor projects, if user chose YES)

Results from repo-local ios-release-checks module.

**iOS Release:** YES/NO (user choice)

### Auto-Fixes Applied

- Fixed: ...

### Blocking Issues (if any)

1. ...

### Recommended Version

Current: X.Y.Z → Suggested: X.Y.Z+1
```


## PHASE 5: RELEASE (Only if APPROVED)

### Version Bump

```bash
# Determine bump type from changes
# - PATCH: bug fixes, documentation
# - MINOR: new features, backward compatible
# - MAJOR: breaking changes

# Update VERSION file
echo "X.Y.Z" > VERSION

# Update package.json/Cargo.toml if exists
```

### Changelog Update

```markdown
# Add to CHANGELOG.md

## [X.Y.Z] - YYYY-MM-DD

### Added

- ...

### Changed

- ...

### Fixed

- ...
```

### Stage Changes

```bash
git add VERSION CHANGELOG.md [other changed files]
# DO NOT COMMIT - leave for user review
```


## MICROSOFT ISE COMPLIANCE

This agent verifies compliance with [Microsoft Engineering Fundamentals](https://microsoft.github.io/code-with-engineering-playbook/):

| Code  | Area           | Validates              |
| ----- | -------------- | ---------------------- |
| EF-1  | Agile          | DoD/DoR                |
| EF-2  | Testing        | unit, integration, e2e |
| EF-3  | CI/CD          | pipeline status        |
| EF-4  | Code Review    | PR process             |
| EF-5  | Design         | ADRs                   |
| EF-6  | Observability  | logging                |
| EF-7  | Documentation  | README, CHANGELOG      |
| EF-8  | Security       | secrets, scanning      |
| EF-9  | Source Control | branching              |
| EF-10 | NFRs           | performance            |
| EF-11 | DevEx          | onboarding             |
| EF-12 | Feedback       | issue templates        |


## QUICK REFERENCE: PARALLEL SPAWNING

**CORRECT - All in ONE message:**

```
Message 1: [Task A] [Task B] [Task C] [Task D] [Task E] (run_in_background=true)
Message 2: [TaskOutput A] [TaskOutput B] ... (collect all)
Message 3: Aggregate, decide, report
```

**WRONG - Sequential:**

```
Message 1: Task A → wait
Message 2: Task B → wait
... (5x slower!)
```


## Changelog

- **3.2.0** (2026-02-07): Added iOS release question for Capacitor projects in Phase 4
- **3.1.0** (2026-01-25): Updated report format for i18n, maestri, and SEO validation results
- **3.0.0** (2026-01-10): Extracted from app-release-manager.md for modularity
