<!-- v2.0.0 | 15 Feb 2026 | Token-optimized per ADR 0009 -->

# Thor Gate Details

_Why: agents self-report "all tests pass" when they don't. Thor reads files directly, trusts nothing._

## Gate Levels

1. Task executor completes task -> per-task Thor validates (Gate 1-4, 8, 9) -> `plan-db.sh validate-task`
2. All tasks in wave validated -> per-wave Thor validates (all 9 gates + build) -> `plan-db.sh validate-wave`
3. Fix ALL Thor rejections (max 3 rounds per level)
4. Thor PASS -> commit -> next wave

## The 9 Gates

1. Task Compliance
2. Code Quality
3. ISE Standards
4. Repo Compliance
5. Documentation
6. Git Conventions
7. Performance
8. TDD (Test-Driven Development)
9. **Constitution & ADR** - Checks CLAUDE.md rules, coding-standards, ADRs. ADR-Smart Mode for tasks that update ADRs.

## Violations

**Committing before Thor = VIOLATION.** Task progress only counts Thor-validated work.

## Commands

```bash
plan-db.sh validate-task {task_db_id}
plan-db.sh validate-wave {wave_db_id}
```
