# VirtualBPM CI Knowledge Base

Patterns from 66 PR review comments analysis (PRs 160-166). Task executors MUST check these before committing.

## Error Handling (11/66 comments — most frequent)

- NEVER `return null` on unexpected empty data — use `console.warn` + visible UI message
- NEVER swallow errors with `catch {}` in critical flows
- Vite preload errors need reload-loop prevention
- Missing PAT should fail fast before I/O operations

## Test Data (7/66 comments)

- MUST use real production values from config files
- Real studio names: `GTM EMEA Studio 3`, `Commercial Studio 2` (NOT `Studio A`, `Test Studio`)
- Real stage labels: `PROSPECT`, `EXPLORATION` (case-sensitive, from backend)
- Real email formats matching actual config patterns
- Seed data must mirror production schema exactly

## Docs Alignment (6/66 comments)

- Docs MUST reference existing scripts (`env-seal.sh`, NOT raw `az keyvault` commands)
- Corporate policy: OAuth secret rotation = 7 days max (NOT 24 months)
- Error messages must reference current env var names (both `ENVIRONMENT` and `VIRTUALBPM_ENV`)
- KV secret names in docs must match actual Key Vault entries

## Feature Wiring (4/66 comments)

- Every new export MUST have at least one consumer import
- Auth integration tests required for every new auth endpoint
- Edit mode exports must be wired into parent consumers
- No orphan code — grep for imports after creating new exports

## Test Coverage (4/66 comments)

- Use AST-based checks for security patterns, NOT regex (regex misses multi-line and f' vs f")
- Test both `f"` and `f'` string formats for log injection checks
- Test spy cleanup required on both happy AND failure paths
- Mock envelope must match actual API response shape for multi-URL handlers

## Performance (3/66 comments)

- `isPatGateBlocking()` adds 3s per test — batch or cache
- Check prerequisites BEFORE loading heavy resources
- Measure wall-time impact of new middleware/guards

## Accessibility (2/66 comments)

- `role="tab"` requires matching `role="tabpanel"` on content container
- Active tab state must reset when parent component changes

## CI Pipeline Notes

- Backend: ruff + black + pytest (80% coverage gate) + pip-audit + bandit + security-audit
- Frontend: ESLint (0 warnings) + TypeScript + vitest (65% gate) + Playwright + bundle (4200KB max)
- 3 known CVE ignores in pip-audit (configured)
- Self-hosted runner: port 5001 contention possible on E2E
