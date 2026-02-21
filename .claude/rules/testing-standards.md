<!-- v2.0.0 -->

# Testing Standards

> MyConvergio agent ecosystem rule

## Coverage

**Required**: 80% business logic, 100% critical paths (auth, payment, data integrity) | Track in CI/CD | Branch coverage, not just lines

## Unit Tests

**All business logic** | Isolated, mock external deps (DB, APIs, filesystem) | One behavior/test | Fast (<1ms ideal) | No network/IO | Format: `describe('Component', () => it('should X when Y'))` | Group in describe blocks

## Integration Tests

**All API endpoints** | Test DB with test database | Fixtures/factories for test data | Cleanup after each test | Auth/authz flows | External service integrations

## Test Isolation

Independent execution | No shared state | Each test sets up own data | `afterEach`/teardown cleanup | Pass in any order | No test interdependencies

## Mocking

Mock external deps (APIs, DB, time) | Dependency injection | Avoid over-mocking (test real integration when beneficial) | Document what's mocked and why | Use test doubles appropriately (mocks, stubs, spies, fakes)

## Performance

Unit: milliseconds | Integration: seconds | Optimize slow tests | Parallelize when possible | Flag and fix flaky tests

## Data Management

Fixtures for complex data | Factories for test objects | NEVER production data | Reset DB state between tests

## Good Patterns

```typescript
// Clear naming, isolated, AAA pattern
describe('calculateDiscount', () => {
  it('should apply 10% for premium users', () => {
    const user = { isPremium: true }, price = 100;
    const result = calculateDiscount(price, user);
    expect(result).toBe(90);
  });
});
```

```python
# Fixtures with cleanup
@pytest.fixture
def test_db():
    db = create_test_database()
    yield db
    db.cleanup()

def test_create_user(test_db, client):
    response = client.post("/api/users", json={"email": "test@example.com"})
    assert response.status_code == 201
    assert test_db.query(User).filter_by(email="test@example.com").first()
```

## Anti-Patterns

❌ Unclear names (`it('test1')`, `it('works')`) | ❌ Shared state between tests | ❌ Real API calls in unit tests | ❌ Magic values without context | ❌ Tests with no assertions | ❌ Order-dependent tests

## References

Jest | Pytest | [Testing Best Practices](https://testingjavascript.com/) | [Test Pyramid](https://martinfowler.com/articles/practical-test-pyramid.html)
