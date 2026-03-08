<!-- v1.2.0 -->

# Testing Standards

> Addresses: mock masking, integration gaps, cascading silent failures, schema/migration drift

## Mock Boundaries (NON-NEGOTIABLE)

| Mock ALLOWED | Mock FORBIDDEN |
|---|---|
| External APIs (Azure DevOps, Redis, third-party) | Auth functions (`is_admin`, `get_current_user`, `fetch_studios`) |
| Network I/O (HTTP calls, WebSocket) | Database queries (use test DB with seed data) |
| File system (when testing non-I/O logic) | The module under test (circular mock = useless test) |
| Time/Date (deterministic tests) | Internal routing/middleware (test the real chain) |

**Rule**: If you mock the thing you're testing, the test proves nothing. Mock at system BOUNDARIES, not at internal seams.

## Integration Test Requirements

| Trigger | Required Test |
|---|---|
| New API endpoint | Request through real middleware chain (auth + validation + handler) |
| New component consuming API data | Test with realistic API response shape (case, nulls, empty arrays) |
| Interface change (props, types) | Test ALL consumers with new interface (grep for old interface first) |
| New CSS variables | Verify variable defined in loaded stylesheet (not just referenced) |

**Minimum**: Every plan MUST include at least ONE integration test that exercises the full data path from API response to UI render (or equivalent for backend-only plans).

## Data Format Verification

Backend/frontend boundary mismatches are recurring bugs. For EVERY API integration:

1. Log actual API response shape in test (case, field names, nesting)
2. Assert frontend expectations match backend format
3. Case-insensitive matching for string enums (`PROSPECT` vs `Prospect`)

## Fail-Loud Patterns (NON-NEGOTIABLE)

Empty data that SHOULD NOT be empty MUST produce visible feedback:

```typescript
// WRONG: silent degradation
if (studios.length === 0) return null;

// RIGHT: fail-loud with user feedback
if (studios.length === 0) {
  console.warn('[StudioSelector] Admin has 0 studios — check configuration');
  return <Alert severity="warning">No studios found. Contact admin.</Alert>;
}
```

**Rule**: `return null` on unexpected empty data = BUG. Use `console.warn` + visible UI message.

**Exceptions**: Loading states, explicit "no data yet" states, optional features.

## CSS Variable Validation

Every component using `var(--name)` MUST have the variable defined in the loaded stylesheet chain.

**Verify**: `grep -rh 'var(--' src/ | grep -oP '(?<=var\()--.+?(?=[\),])' | sort -u` vs `grep -rh '^\s*--' src/styles/ | grep -oP '(?<=\s)--.+?(?=:)' | sort -u`. Orphans = REJECT.

## Real Data Only (NON-NEGOTIABLE)

Test data MUST reflect real production values. NEVER invent, hallucinate, or use placeholder data.

| ALLOWED | FORBIDDEN |
|---|---|
| Real studio names from config (`GTM EMEA Studio 3`, `Commercial Studio 2`) | Made-up names (`Studio A`, `Test Studio`, `Fake Studio`) |
| Real API response shapes (exact fields, case, nesting) | Simplified/altered response shapes |
| Real email formats matching config patterns | `test@example.com` if not in actual config |
| Real stage labels from backend (`PROSPECT`, `EXPLORATION`) | Altered case or invented stages (`prospect`, `Stage 1`) |
| Seed data from test fixtures that mirror production schema | Random data that "looks right" |

**Rule**: If a test uses `'Studio A'` but production data never contains `'Studio A'`, the test proves nothing about real behavior. Use actual values from config files, seed data, or documented API contracts.

**Enforcement**: Thor Gate 8b checks test data against production format. `code-pattern-check.sh` flags generic test data patterns.

## Schema-Migration Consistency (NON-NEGOTIABLE)

When a PR adds/modifies a database model, a corresponding migration MUST exist in the same PR.

| Check | REJECT if |
|---|---|
| New model class | No migration file creates the table |
| Column added/removed/renamed | No migration file alters the table |
| Index added/removed | No migration file modifies indexes |
| Model deleted | No migration file drops the table |

**Verify** (language-generic):
```bash
# Files with model changes
MODEL_FILES=$(git diff --name-only HEAD~1 | grep -iE 'models/|schema|entities/')
# Files with migrations
MIGRATION_FILES=$(git diff --name-only HEAD~1 | grep -iE 'migrations/|alembic/versions/|prisma/migrations/')
# If MODEL_FILES non-empty and MIGRATION_FILES empty → REJECT
```

_Why: PR #235 added `PatToken` model without migration. Production table never created. Silent failure._

## Post-Deploy Data Smoke Test (NON-NEGOTIABLE)

Plans touching auth, RBAC, tokens, or data access MUST include a smoke test that verifies:
1. Authenticated request returns `200` (not `401`/`403`)
2. Response contains non-empty data (not `[]` or `{"engagements": []}`)
3. Scope filtering returns correct subset (not everything, not nothing)

**Silent empty data = BUG.** If an endpoint returns empty when it shouldn't, the test MUST fail loudly.

## Signature Change Impact (NON-NEGOTIABLE — Plan 100027 incident)

When a task adds/removes/renames a parameter on an existing function:

1. **Grep ALL direct callers** — not just HTTP clients, but unit tests that call the function directly
2. **Update every caller** with the new parameter (or mock/patch the new dependency)
3. **Framework DI is invisible to direct callers**: `Depends()`, `@Inject()`, `@Autowired` resolve via framework at runtime — unit tests calling the function directly get the raw DI wrapper object, not the resolved value

| Framework | DI pattern | Direct caller gets |
|---|---|---|
| FastAPI | `param: T = Depends(fn)` | `Depends(fn)` object (no `.method()`) |
| NestJS | `@Inject(TOKEN)` | undefined / wrong type |
| Spring | `@Autowired` | null |
| Django | N/A (views are different) | N/A |

**Executor MUST**: after adding a DI param, run `grep -rn "function_name(" tests/` and update every match.

**Thor MUST verify**: if function signature changed in diff, `grep` for direct callers in test files. Unpatched callers = REJECT.

_Why: Plan 100027 — added `cache_svc: CacheService = Depends(get_cache_service)` to 6 routers. 4 existing tests called those functions directly without the new param → `AttributeError: 'Depends' object has no attribute 'invalidate_pattern'`._

## Test Data Domain Safety (NON-NEGOTIABLE)

Test data containing URLs, emails, or hostnames MUST use safe domains to avoid triggering secrets/credential hooks.

| WRONG | RIGHT |
|---|---|
| `https://dev.azure.com/myorg/project` | `https://ado.example.com/org/project` |
| `https://api.github.com/repos/real/repo` | `https://api.example.com/repos/test/repo` |
| `secret_key_abc123` in test fixture | Use env var mock or `# noqa: secrets` annotation |

**Safe domains**: `example.com`, `example.org`, `test.example.com` (RFC 2606 reserved). For Python files with unavoidable patterns, add `# noqa: secrets` inline comment. For TypeScript/JavaScript, use `example.com` equivalents.

_Why: Plan 100028 — pre-commit `check-no-hardcoded-secrets` hook blocked commit because test files contained `dev.azure.com/myorg` URLs. Required manual `# noqa: secrets` annotation or domain replacement._

## Test Quality Checklist (Thor Gate 8 Extension)

| Check | REJECT if |
|---|---|
| Mock depth | Test mocks >2 layers deep from the function under test |
| Mock of tested module | Test mocks the very function/module it claims to test |
| Coverage without assertions | Test has 80% coverage but zero meaningful assertions |
| Format mismatch | Test uses different data format than production (case, shape) |
| Missing consumer test | New export has zero tests for its integration point |
| Missing migration | New/modified ORM model without corresponding migration file |
| Missing smoke test | Auth/RBAC/data plan without post-deploy data verification |
| Unsafe test domains | Test URLs use real service domains instead of `example.com` |
