---
name: task-executor-tdd
description: TDD workflow module for task-executor. Reference only.
version: "1.3.0"
---

# TDD Workflow Module

> Referenced by task-executor.md. Do not invoke directly.

## Phase 2.5: TDD - Write Tests FIRST (RED)

**MANDATORY**: Before ANY implementation, write failing tests based on `test_criteria`.

### Step 1: Detect Test Framework

```bash
# Auto-detect from project
if [ -f "package.json" ]; then
  grep -q '"vitest"' package.json && FRAMEWORK="vitest"
  grep -q '"jest"' package.json && FRAMEWORK="jest"
  grep -q '"playwright"' package.json && E2E_FRAMEWORK="playwright"
elif [ -f "pyproject.toml" ]; then
  FRAMEWORK="pytest"
elif [ -f "Cargo.toml" ]; then
  FRAMEWORK="cargo"
fi
```

### Step 1b: Navigate to Test Files (LSP)

LSP go-to-definition is available for test file navigation — use it to jump between implementation and test files without manual path searching.

### Step 2: Write Failing Tests

For each item in `test_criteria`:

1. **Create test file** in appropriate location (`__tests__/`, `tests/`)
2. **Write test describing expected behavior** - MUST FAIL initially
3. **Run test to confirm RED state**

**Commands by Framework** (ALWAYS minimize output — verbose wastes tokens):

```bash
# Jest/Vitest (--silent = no console.log, summary only)
npm test -- --testPathPattern="ComponentName" --silent

# pytest (--tb=line = 1-line failures, -q = dots not verbose, --no-header = skip banner)
pytest tests/test_feature.py --tb=line -q --no-header

# Playwright (line reporter = compact)
npx playwright test feature.spec.ts --reporter=line

# Cargo (--quiet = summary only)
cargo test test_name --quiet
```

**NEVER use `-v`/`--verbose` flags.** NEVER use `| tail`/`| head` pipes (hooks block these).

### Step 3: Verify RED State

```bash
# Non-zero exit = RED confirmed. Framework flags already minimize output.
npm test -- --testPathPattern="ComponentName" --silent
# Check $? in Bash result
```

**DO NOT proceed to implementation until tests are written and failing.**

---

## Test File Naming Conventions

| Type        | JavaScript/TypeScript     | Python                | Rust                   |
| ----------- | ------------------------- | --------------------- | ---------------------- |
| Unit        | `Component.test.ts`       | `test_module.py`      | `mod.rs` (tests mod)   |
| Integration | `api.integration.test.ts` | `test_integration.py` | `tests/integration.rs` |
| E2E         | `feature.spec.ts`         | `test_e2e.py`         | N/A                    |

---

## Coverage Requirements

- **New files**: ≥80% coverage
- **Modified files**: No regression
- **Excluded**: Generated code, type definitions

```bash
# Coverage (summary reporters only, no verbose)
npm test -- --coverage --coverageReporters=text-summary --silent
pytest --cov=src --cov-report=term-missing -q --no-header
cargo tarpaulin --out Stdout --quiet
```

---

## Mock Discipline (NON-NEGOTIABLE)

Per `~/.claude/rules/testing-standards.md`:

| ALLOWED mocks | FORBIDDEN mocks |
|---|---|
| External APIs, network I/O, time/date | Auth functions (`is_admin`, `get_current_user`) |
| Third-party services (Azure, Redis) | Database queries (use test DB with seed data) |
| File system (for non-I/O logic) | The module under test (circular mock) |

**Rule**: Mock at system BOUNDARIES. If you mock the thing you're testing, the test proves nothing. For API↔frontend tasks, verify test data format matches production (case, shape, field names).

## TDD Success Criteria

1. ✓ Tests written BEFORE implementation
2. ✓ Tests initially FAILED (RED state confirmed)
3. ✓ Implementation makes tests PASS (GREEN)
4. ✓ Coverage ≥80% on new files
5. ✓ No coverage regression on modified files
6. ✓ Mocks only at system boundaries (not on module under test)
7. ✓ Test data format matches production format

---

## Changelog

- **1.3.0** (2026-02-27): Mock discipline rules; TDD success criteria 6-7 (mock boundaries, format match)
- **1.2.0** (2026-02-27): Minimize test output (--silent, --tb=line, -q, --quiet); no | tail pipes (hooks block)
- **1.1.0** (2026-02-27): Added LSP go-to-definition note for test file navigation (Step 1b)
- **1.0.0** (2026-01-10): Extracted TDD workflow from task-executor.md for modularity
