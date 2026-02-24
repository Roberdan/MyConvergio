---
name: thor-validation-gates
description: Validation gates module for Thor. Reference only.
version: "3.1.0"
---

# Thor Validation Gates

> Referenced by thor-quality-assurance-guardian.md. Do not invoke directly.

## Gate 1: Task Compliance

- Read ORIGINAL instructions from plan
- Compare claim vs instructions point-by-point (every requirement, not "most")
- No scope creep or scope reduction
- **Challenge**: "Show me where you addressed requirement X"

## Gate 2: Code Quality

- Tests exist for new/changed code, PASS (run them, don't trust claims)
- Coverage ≥80% modified files, lint ZERO warnings, build succeeds
- No debug statements, commented code, TODO
- **Challenge**: "Run tests right now. Show output."

## Gate 3: ISE Fundamentals

- No secrets/credentials in code
- Proper error handling (not empty catch), input validation
- No SQL injection/XSS, type safety (no `any` abuse in TS)
- SOLID and DRY principles
- **Challenge**: "Show me error handling in new code"

## Gate 4: Repo Compliance

- Existing codebase patterns followed (naming, structure, idioms, imports)
- File/folder conventions respected (colocation, barrel exports)
- **Note**: Gate 4 = codebase patterns. Gate 9 = constitution (CLAUDE.md, ADRs, 250-line limit).

### Gate 4b: Automated Pattern Checks

Run `code-pattern-check.sh` on changed files to catch mechanical issues (null safety, error handling, scalability, security, naming):

```bash
~/.claude/scripts/code-pattern-check.sh --files {changed_files} --json
```

- **P1 finding = REJECT**: unguarded JSON.parse, unguarded method calls, React.lazy without default export
- **P2 finding = WARN**: load-all + paginate, duplicate names, unused params, insecure file writes, missing error boundaries (reviewer discretion)
- Reference: `~/.claude/reference/copilot-patterns.md` for pattern details

## Gate 5: Documentation

- README updated if behavior changed, API docs if endpoints changed
- JSDoc/docstrings for public functions, comments explain WHY not WHAT
- **Challenge**: "You changed the API. Where's the doc update?"

## Gate 6: Git Hygiene

- Correct branch (NOT main for features), changes committed
- Conventional commits, no unrelated files, no secrets committed
- **Challenge**: "Run `git status` and `git branch` now."

## Gate 7: Performance

- `./scripts/perf-check.sh` passes (if exists)
- No PNG/JPG (must be WebP), EventSource/listeners have cleanup
- Heavy deps lazy-loaded, no N+1 database patterns
- **Challenge**: "Run `./scripts/perf-check.sh` now."

## Gate 8: TDD Verification (MANDATORY)

- Test files exist for each `test_criteria`, written BEFORE implementation (check git log)
- All tests PASS, coverage ≥80% new files, no coverage regression

```bash
ls -la **/*.test.ts **/*.spec.ts tests/*.py
npm test -- --coverage --coverageReporters=text-summary
git log --oneline --name-only | head -20
```

**REJECT if**: No test files | Tests fail | Coverage <80% new | Implementation before tests

## Gate 9: Constitution & ADR Compliance (MANDATORY)

### 9a. Constitution

- Read `CLAUDE.md` (worktree root + `~/.claude/CLAUDE.md`) + `~/.claude/rules/*.md`
- Verify new/changed code follows ALL conventions
- Max 250 lines/file: `for f in {changed_files}; do echo "$(grep -c . "$f") $f"; done | sort -rn | head -10`
- Check prohibited patterns: `grep -rn 'TODO\|FIXME\|@ts-ignore' {changed_files}`

### 9b. ADR Compliance

- List ADRs: `ls docs/adr/*.md`, check active (Status: Accepted) vs superseded
- For each changed file, verify consistency with governing ADR
- ADR contradiction = REJECT: "ADR violation: {ADR-NNN} requires {X}, but code does {Y}"

**ADR-Smart Exception** (task type=`documentation`, files include `docs/adr/*.md`):

- Don't enforce old version of modified ADR
- DO validate format, internal consistency, no contradictions with OTHER active ADRs
- DO verify metadata (date, status, supersedes)

```bash
grep -l 'Status: Accepted' docs/adr/*.md 2>/dev/null
echo "{task_files}" | grep -q 'docs/adr/' && echo "ADR-SMART-MODE"
```

**REJECT if**: Code contradicts active ADR | CLAUDE.md rule violated | File >250 lines

## Gate 10: Cross-Review (Per-Wave, MANDATORY)

Independent holistic review of ALL wave deliverables by a fresh session.

**Checks**: Cross-file consistency (versions, counts, names match) | Content accuracy (claims vs source) | Link integrity | F-xx coverage | Policy compliance

**Mechanism**: Fresh session, antagonistic prompt ("find problems, not confirm success"). Cross-provider preferred (executor=Claude -> reviewer=Copilot, vice versa).

**Trigger**: After gates 1-9 pass per-wave. Before merge.
**Failure**: Wave stays `in_progress`. Fix + re-review (max 2 rounds).
**Script**: `cross-review.sh <plan_id> <wave_db_id> [--provider copilot|claude]`
