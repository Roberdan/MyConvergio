---
name: thor-validation-gates
description: Validation gates module for Thor. Reference only.
version: "1.0.0"
---

# Thor Validation Gates

> Referenced by thor-quality-assurance-guardian.md. Do not invoke directly.

## Gate 1: Task Compliance

- [ ] Read ORIGINAL instructions from plan
- [ ] Compare claim vs instructions point-by-point
- [ ] Every requirement addressed (not "most")
- [ ] No scope creep or scope reduction

**Challenge**: "Show me where you addressed requirement X"

## Gate 2: Code Quality

- [ ] Tests exist for new/changed code
- [ ] Tests PASS (run them, don't trust claims)
- [ ] Coverage ≥80% on modified files
- [ ] Lint passes with ZERO warnings
- [ ] Build succeeds
- [ ] No debug statements, commented code, or TODO

**Challenge**: "Run tests right now. Show output."

## Gate 3: Engineering Fundamentals (ISE)

- [ ] No secrets/credentials in code
- [ ] Proper error handling (not empty catch)
- [ ] Input validation present
- [ ] No SQL injection / XSS vulnerabilities
- [ ] Type safety (no `any` abuse in TS)
- [ ] SOLID and DRY principles followed

**Challenge**: "Show me error handling in new code"

## Gate 4: Repository Compliance

- [ ] CLAUDE.md guidelines followed
- [ ] Existing codebase patterns followed
- [ ] File/folder conventions respected
- [ ] Max 250 lines/file respected

## Gate 5: Documentation

- [ ] README updated (if behavior changed)
- [ ] API docs updated (if endpoints changed)
- [ ] JSDoc/docstrings for public functions
- [ ] Comments explain WHY, not WHAT

**Challenge**: "You changed the API. Where's the doc update?"

## Gate 6: Git Hygiene

- [ ] On correct branch (NOT main for features!)
- [ ] Changes committed (not just staged)
- [ ] Commit message follows conventional commits
- [ ] No unrelated files, no secrets committed

**Challenge**: "Run `git status` and `git branch` now."

## Gate 7: Performance (if perf-check.sh exists)

- [ ] `./scripts/perf-check.sh` passes
- [ ] No PNG/JPG images (must be WebP)
- [ ] EventSource/listeners have cleanup
- [ ] Heavy deps lazy-loaded
- [ ] No N+1 database patterns

**Challenge**: "Run `./scripts/perf-check.sh` now."

## Gate 8: TDD Verification (MANDATORY)

- [ ] Test files exist for each `test_criteria`
- [ ] Tests written BEFORE implementation (check git)
- [ ] All tests PASS
- [ ] Coverage ≥80% for NEW files
- [ ] No coverage regression

**Commands**:
```bash
# Check test files
ls -la **/*.test.ts **/*.spec.ts tests/*.py

# Coverage
npm test -- --coverage --coverageReporters=text-summary

# TDD order verification
git log --oneline --name-only | head -20
```

**Challenge**: "Show me the test file. Run `npm test` now."

**REJECTION triggers**:
- No test files → REJECTED
- Tests fail → REJECTED
- Coverage <80% new files → REJECTED
- Implementation before tests → REJECTED (TDD violation)
