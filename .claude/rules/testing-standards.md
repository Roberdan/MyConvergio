<!-- v1.0.0 -->

# Testing Standards

> Addresses: mock masking, integration gaps, cascading silent failures

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

## Test Quality Checklist (Thor Gate 8 Extension)

| Check | REJECT if |
|---|---|
| Mock depth | Test mocks >2 layers deep from the function under test |
| Mock of tested module | Test mocks the very function/module it claims to test |
| Coverage without assertions | Test has 80% coverage but zero meaningful assertions |
| Format mismatch | Test uses different data format than production (case, shape) |
| Missing consumer test | New export has zero tests for its integration point |
