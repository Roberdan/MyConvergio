---
name: thor-validation-gates
description: Validation gates module for Thor. Reference only.
version: "2.0.0"
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

## Gate 4: Repository Compliance (project-level patterns)

- [ ] Existing codebase patterns followed (naming, structure, idioms)
- [ ] File/folder conventions respected (colocation, barrel exports, etc.)
- [ ] Import patterns consistent with rest of codebase
- [ ] No unnecessary deviation from established project conventions

**Note**: Gate 4 checks codebase patterns. Gate 9 checks constitution (CLAUDE.md rules, ADRs, 250-line limit). Together they cover all compliance.

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

## Gate 9: Constitution & ADR Compliance (MANDATORY)

Validates that changes respect the repository's established rules and architectural decisions.

### 9a. Constitution Compliance (CLAUDE.md / coding-standards / guardian rules)

- [ ] Read `CLAUDE.md` in worktree root (project-level rules)
- [ ] Read `~/.claude/CLAUDE.md` (global rules)
- [ ] Read `~/.claude/rules/*.md` (coding-standards, guardian)
- [ ] Verify new/changed code follows ALL stated conventions
- [ ] Max 250 lines/file enforced (check with `grep -c .`)
- [ ] No violations of explicit prohibitions (e.g., no `git checkout` on main)

**Commands**:

```bash
# Check file lengths (use grep -c, NOT wc -l which is blocked by hooks)
for f in {changed_files}; do echo "$(grep -c . "$f") $f"; done | sort -rn | head -10

# Check for prohibited patterns from CLAUDE.md
grep -rn 'TODO\|FIXME\|@ts-ignore' {changed_files}
```

### 9b. ADR Compliance (Architectural Decision Records)

- [ ] List existing ADRs: `ls docs/adr/*.md` (in worktree)
- [ ] For each changed file, check if an ADR governs its domain
- [ ] Verify changes are consistent with active ADRs (status: Accepted)
- [ ] If changes CONTRADICT an ADR: REJECT with "ADR violation: {ADR-NNN} requires {X}, but code does {Y}"
- [ ] Superseded ADRs (status: Superseded) should NOT be enforced

**ADR-Smart Exception**: If the task IS updating/creating an ADR (task type=`documentation`, files include `docs/adr/*.md`):

- Do NOT enforce the old version of that specific ADR
- DO validate the ADR format and internal consistency
- DO check that the new ADR doesn't contradict OTHER active ADRs
- DO verify the ADR update has proper metadata (date, status, supersedes)

**Commands**:

```bash
# List active ADRs
grep -l 'Status: Accepted' docs/adr/*.md 2>/dev/null

# Check if task modifies ADRs (ADR-Smart detection)
echo "{task_files}" | grep -q 'docs/adr/' && echo "ADR-SMART-MODE"

# Find ADRs relevant to changed files
grep -rl '{keyword_from_changed_domain}' docs/adr/ 2>/dev/null
```

**Challenge**: "Does this change respect ADR-NNN? Show me evidence."

**REJECTION triggers**:

- Code contradicts active ADR → REJECTED
- CLAUDE.md rule violated → REJECTED
- File exceeds 250 lines → REJECTED
- New pattern introduced without ADR justification (for architectural changes) → WARNING
