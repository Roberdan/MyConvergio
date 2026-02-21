---
name: task-executor-tdd
description: TDD workflow module for task-executor. Reference only.
version: "1.0.0"
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

### Step 2: Write Failing Tests

For each item in `test_criteria`:

1. **Create test file** in appropriate location (`__tests__/`, `tests/`)
2. **Write test describing expected behavior** - MUST FAIL initially
3. **Run test to confirm RED state**

**Commands by Framework**:
```bash
# Jest/Vitest
npm test -- --testPathPattern="ComponentName"

# pytest
pytest tests/test_feature.py -v

# Playwright
npx playwright test feature.spec.ts

# Cargo
cargo test test_name
```

### Step 3: Verify RED State

```bash
npm test 2>&1 | grep -E "(FAIL|failed)" && echo "RED confirmed"
```

**DO NOT proceed to implementation until tests are written and failing.**


## Test File Naming Conventions

| Type | JavaScript/TypeScript | Python | Rust |
|------|----------------------|--------|------|
| Unit | `Component.test.ts` | `test_module.py` | `mod.rs` (tests mod) |
| Integration | `api.integration.test.ts` | `test_integration.py` | `tests/integration.rs` |
| E2E | `feature.spec.ts` | `test_e2e.py` | N/A |


## Coverage Requirements

- **New files**: ≥80% coverage
- **Modified files**: No regression
- **Excluded**: Generated code, type definitions

```bash
# Check coverage
npm test -- --coverage --coverageReporters=text-summary
pytest --cov=src --cov-report=term-missing
cargo tarpaulin --out Stdout
```


## TDD Success Criteria

1. ✓ Tests written BEFORE implementation
2. ✓ Tests initially FAILED (RED state confirmed)
3. ✓ Implementation makes tests PASS (GREEN)
4. ✓ Coverage ≥80% on new files
5. ✓ No coverage regression on modified files
