<!-- v1.0.0 -->

# Copilot Review Patterns

> Knowledge base of recurring patterns from GitHub Copilot code review analysis (~34 comments across MirrorBuddy and VirtualBPM PRs). Used by `/review-pr` skill and Thor Gate 4b.

## Pattern Categories

| #   | Category           | Description                                                | Severity | Frequency |
| --- | ------------------ | ---------------------------------------------------------- | -------- | --------- |
| 1   | Contract Mismatch  | Frontend/backend API type divergence                       | P1       | High      |
| 2   | Null Safety        | Missing null/undefined guards before method calls          | P1       | High      |
| 3   | Error Handling     | Missing try/catch around JSON.parse, fetch, file I/O       | P1       | High      |
| 4   | Scalability        | In-memory aggregation of unbounded data (findMany + slice) | P2       | Medium    |
| 5   | Security           | File permissions, credential handling, input validation    | P2       | Medium    |
| 6   | Logic Errors       | Off-by-one, wrong field mapping, regex scope too wide      | P1       | Medium    |
| 7   | Architecture Drift | Code contradicts ADR or established patterns               | P2       | Medium    |
| 8   | Test Quality       | Missing edge case coverage, brittle assertions             | P2       | Low       |
| 9   | Naming Conflicts   | Duplicate class/function names across modules              | P2       | Low       |

## Detailed Patterns

### 1. Contract Mismatch (P1)

API response types in backend don't match frontend consumption. Often caused by adding fields to Prisma schema without updating API DTOs and frontend types.

**Detection**: Cross-file analysis comparing API route return types with frontend fetch call expectations.

**Common locations**: `src/app/api/*/route.ts` vs `src/hooks/use*.ts` or `src/services/*.ts`

### 2. Null Safety (P1)

Calling `.toFixed()`, `.toString()`, `.trim()`, `.split()` on values that may be `null | undefined`. Common after Prisma queries with optional fields.

**Detection**: `grep` for method calls without `?.` or preceding null check within 3 lines.

### 3. Error Handling (P1)

`JSON.parse()` and `json.loads()` without try/catch. `fetch()` and `axios` calls without error boundaries. File operations without error handling.

**Detection**: `grep` for parse/fetch calls, check surrounding 5 lines for try/catch.

### 4. Scalability (P2)

Loading all records with `.findMany()` or `SELECT *` then slicing client-side instead of using database-level pagination (`skip`/`take`, `LIMIT`/`OFFSET`).

**Detection**: `grep` for load-all followed by `.slice()` or array subscript within 5 lines.

### 5. Security (P2)

File writes (`writeFileSync`, `open(..,'w')`) on sensitive paths without explicit file mode. Missing `mode: 0o600` for credential files. Overly permissive CORS.

**Detection**: `grep` for file write operations on paths containing config/secret/key/env patterns.

### 6. Logic Errors (P1)

Wrong field used in mapping (e.g., `user.name` where `user.displayName` intended). Regex matching too broadly. Transaction ordering issues in Prisma (dependent operations outside `$transaction`).

**Detection**: AI cross-file analysis required. Cannot be fully automated.

### 7. Architecture Drift (P2)

New code contradicts active ADRs. Common: using localStorage when ADR mandates Zustand, adding REST endpoints when ADR specifies GraphQL for that domain.

**Detection**: AI analysis comparing code changes against `docs/adr/*.md` with `Status: Accepted`.

### 8. Test Quality (P2)

Tests that only cover happy path. Missing boundary conditions. Assertions on implementation details (mock call counts) instead of behavior. Shared mutable state between tests.

**Detection**: AI analysis of test files. Partial grep for `expect(mock).toHaveBeenCalledTimes` as brittle assertion indicator.

### 9. Naming Conflicts (P2)

Same class or function name exported from different modules, causing import confusion and potential tree-shaking issues.

**Detection**: `grep` for duplicate export names across changed files.

## Automated vs AI-Required

| Automated (`code-pattern-check.sh`) | AI-Required (`/review-pr`)     |
| ----------------------------------- | ------------------------------ |
| Null safety (pattern 2)             | Contract mismatch (pattern 1)  |
| Error handling (pattern 3)          | Logic errors (pattern 6)       |
| Scalability (pattern 4)             | Architecture drift (pattern 7) |
| Security (pattern 5)                | Test quality (pattern 8)       |
| Naming conflicts (pattern 9)        | Cross-file field mapping       |
| React.lazy default export           | Transaction ordering           |

## References

- Source analysis: MirrorBuddy PRs #217-#224, VirtualBPM PRs #105-#109
- Thor integration: Gate 4b in `thor-validation-gates.md`
- Automated checks: `~/.claude/scripts/code-pattern-check.sh`
- AI review: `/review-pr` skill
