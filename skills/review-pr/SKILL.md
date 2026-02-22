---
name: review-pr
description: Pre-PR review catching GitHub Copilot patterns
allowed-tools:
  - Read
  - Glob
  - Grep
  - Bash
context: fork
user-invocable: true
version: "1.0.0"
---

# Pre-PR Review Skill

> Focused pre-PR review targeting patterns that GitHub Copilot code review catches. NOT a generic code review — use `/code-review` for that.

## Purpose

Catch the 9 recurring pattern categories (contract mismatch, null safety, error handling, scalability, security, logic errors, architecture drift, test quality, naming conflicts) BEFORE creating a PR, reducing review cycles.

## When to Use

- Before `gh pr create` — run `/review-pr` first
- After significant changes to a feature branch
- When touching API routes AND frontend consumers in same PR

## Workflow

### Step 1: Detect Scope

```bash
# Detect base branch
BASE=$(git merge-base --fork-point main HEAD 2>/dev/null || echo "main")

# Get changed files
CHANGED_FILES=$(git diff --name-only --diff-filter=ACMR "${BASE}...HEAD")

# Count and report scope
FILE_COUNT=$(echo "$CHANGED_FILES" | grep -c . || echo 0)
```

If no changed files detected, report "No changes found" and exit.

### Step 2: Automated Pattern Check (Zero AI Cost)

Run the mechanical pattern checker first:

```bash
~/.claude/scripts/code-pattern-check.sh --diff-base "$BASE" --json
```

Parse the JSON output. Report P1/P2 counts immediately.

### Step 3: Read Changed Files

Read the FULL content of each changed file (not just diff). Cross-file analysis requires full context.

Prioritize:

1. API route files (`**/api/**/route.ts`, `**/api/**/route.py`)
2. Service/hook files that consume APIs (`**/services/*.ts`, `**/hooks/use*.ts`)
3. Type/interface definitions (`**/types/*.ts`, `**/interfaces/*.ts`)
4. Test files (`**/*.test.ts`, `**/*.spec.ts`, `**/test_*.py`)

### Step 4: AI Cross-File Analysis

Analyze for patterns that `code-pattern-check.sh` CANNOT catch:

#### 4a. Contract Mismatch (P1)

- Compare API route return types with frontend fetch/hook expectations
- Check Prisma schema field types vs API DTO fields
- Verify request body types match API parameter expectations

#### 4b. Logic Errors (P1)

- Wrong field used in object mapping (e.g., `user.name` vs `user.displayName`)
- Regex patterns that match too broadly or too narrowly
- Off-by-one in array/string operations
- Transaction ordering (dependent ops outside `$transaction`)

#### 4c. Architecture Drift (P2)

- Read active ADRs: `ls docs/adr/*.md` and check `Status: Accepted`
- Compare new code patterns against ADR decisions
- Flag contradictions (e.g., localStorage usage when ADR mandates Zustand)

#### 4d. Test Quality (P2)

- Check test files cover edge cases, not just happy path
- Flag brittle assertions (`toHaveBeenCalledTimes` on implementation details)
- Verify error paths are tested
- Check for shared mutable state between tests

### Step 5: Generate Report

Output a structured report with this format:

```markdown
## Pre-PR Review: {branch_name}

**Scope**: {file_count} files changed | Base: {base_branch}

### Automated Findings (code-pattern-check.sh)

| Severity | Check                  | Count |
| -------- | ---------------------- | ----- |
| P1       | unguarded_json_parse   | 2     |
| P2       | missing_error_boundary | 1     |

### AI Analysis Findings

| #   | Severity | Category           | File                   | Line | Issue                                             |
| --- | -------- | ------------------ | ---------------------- | ---- | ------------------------------------------------- |
| 1   | P1       | contract_mismatch  | src/api/users/route.ts | 45   | Returns `{name}` but hook expects `{displayName}` |
| 2   | P2       | architecture_drift | src/store/auth.ts      | 12   | Uses localStorage, ADR-007 requires Zustand       |

### Recommendations

1. **[P1]** Fix contract mismatch in user API...
2. **[P2]** Migrate auth storage to Zustand per ADR-007...

### Summary

- **P1 (must fix)**: {count}
- **P2 (should fix)**: {count}
- **P3 (consider)**: {count}
- **Verdict**: {READY | NOT READY} for PR
```

## What This Skill Does NOT Do

- Generic code quality review (use `/code-review`)
- Style/formatting checks (use ESLint/Prettier)
- Performance profiling (use `/performance`)
- Security audit (use `/security-audit`)

## Reference

- Pattern knowledge base: `~/.claude/reference/copilot-patterns.md`
- Automated checker: `~/.claude/scripts/code-pattern-check.sh`
- Copilot feedback digest: `~/.claude/scripts/copilot-review-digest.sh`
- Full code review: `/code-review` skill

## Integration with Thor

Thor Gate 4b runs `code-pattern-check.sh` automatically during validation.
This skill adds AI analysis on top for pre-PR use.
