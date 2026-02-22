# Testing Standards v2.0.0

> Enforced by MyConvergio agent ecosystem. Compact format per ADR 0009.

## Test Types & Coverage

| Type        | Purpose                    | Coverage Target | Speed        | Dependencies     |
|-------------|----------------------------|-----------------|--------------|------------------|
| Unit        | Business logic in isolation| 80% minimum     | <1ms/test    | Mock all I/O     |
| Integration | API endpoints, DB, services| All endpoints   | <1s/test     | Test DB, mocks   |
| E2E         | User flows                 | Critical paths  | <10s/test    | Real services    |

**Critical paths**: 100% coverage (auth, payment, data integrity)

## Test Naming Convention

```typescript
describe('ComponentName', () => {
  describe('methodName', () => {
    it('should do X when Y', () => {
      // Test reads like specification
    });
  });
});
```

Format: `describe('what') → it('should behavior when condition')`

## Core Principles

| Principle    | Implementation                                    |
|--------------|---------------------------------------------------|
| Isolation    | Tests run independently, any order                |
| No state     | Each test sets up own data, cleans up after       |
| Mocking      | Mock external deps (APIs, DBs, time) in unit      |
| Performance  | Parallelize, optimize slow tests, flag flakes     |
| Data         | Use factories/fixtures, never production data     |

## Examples

### Unit Test (TypeScript/Jest)

```typescript
describe('calculateDiscount', () => {
  it('should apply 10% discount for premium users', () => {
    const user = { isPremium: true };
    const price = 100;
    
    const result = calculateDiscount(price, user);
    
    expect(result).toBe(90);
  });

  it('should return original price for non-premium users', () => {
    const user = { isPremium: false };
    expect(calculateDiscount(100, user)).toBe(100);
  });

  it('should throw error for negative prices', () => {
    expect(() => calculateDiscount(-50, { isPremium: true }))
      .toThrow('Price must be positive');
  });
});
```

### Integration Test (Python/pytest)

```python
@pytest.fixture
def test_db():
    """Create test DB, cleanup after."""
    db = create_test_database()
    yield db
    db.cleanup()

def test_create_user_endpoint(test_db, client):
    """Should create user and return 201 with user data."""
    # Arrange
    user_data = {"email": "test@example.com", "name": "Test User"}
    
    # Act
    response = client.post("/api/users", json=user_data)
    
    # Assert
    assert response.status_code == 201
    assert response.json["email"] == user_data["email"]
    
    # Verify in DB
    user = test_db.query(User).filter_by(email=user_data["email"]).first()
    assert user is not None
    assert user.name == user_data["name"]
```

### Mocking External Services

```typescript
describe('UserService', () => {
  let mockHttpClient: jest.Mocked<HttpClient>;
  let userService: UserService;

  beforeEach(() => {
    mockHttpClient = { get: jest.fn(), post: jest.fn() } as any;
    userService = new UserService(mockHttpClient);
  });

  it('should fetch user profile from API', async () => {
    const mockUser = { id: '123', name: 'John' };
    mockHttpClient.get.mockResolvedValue({ data: mockUser });

    const result = await userService.getProfile('123');

    expect(result).toEqual(mockUser);
    expect(mockHttpClient.get).toHaveBeenCalledWith('/users/123');
  });

  it('should handle API errors gracefully', async () => {
    mockHttpClient.get.mockRejectedValue(new Error('Network error'));
    
    await expect(userService.getProfile('123'))
      .rejects.toThrow('Failed to fetch user profile');
  });
});
```

### Test Fixtures & Factories

```python
@pytest.fixture
def sample_user():
    """Sample user for testing."""
    return User(id="123", email="test@example.com", is_premium=True)

@pytest.fixture
def user_factory():
    """Factory for custom test users."""
    def _create(**kwargs):
        defaults = {"email": "test@example.com", "is_premium": False}
        return User(**{**defaults, **kwargs})
    return _create

def test_with_factory(user_factory):
    premium = user_factory(is_premium=True)
    regular = user_factory()
    
    assert premium.is_premium
    assert not regular.is_premium
```

## Anti-Patterns

| ✗ Bad                                              | ✓ Good                                |
|----------------------------------------------------|---------------------------------------|
| `it('test1')`, `it('works')`                       | `it('should return 404 when user missing')` |
| `let userId; it('creates')... it('updates')...`    | Each test independent, own setup      |
| `await fetch('https://real-api.com')`              | Mock external calls in unit tests     |
| `result = calculate(100, 0.1, True, 5)`            | Use named constants/variables         |
| `processOrder(order); // no assertions`            | Always verify behavior with assertions|
| Tests fail randomly                                | Fix flaky tests immediately           |

## Test Data Management

```typescript
// ✓ Good: Descriptive test data
const PREMIUM_DISCOUNT_RATE = 0.1;
const BASE_PRICE = 100;
const EXPECTED_DISCOUNTED_PRICE = 90;

it('should apply premium discount', () => {
  const result = calculateDiscount(BASE_PRICE, PREMIUM_DISCOUNT_RATE);
  expect(result).toBe(EXPECTED_DISCOUNTED_PRICE);
});

// ✗ Bad: Magic numbers
it('should calculate price', () => {
  expect(calculate(100, 0.1, true, 5)).toBe(427.5);  // What does this mean?
});
```

## Performance Guidelines

- Unit: <1ms ideal, <10ms acceptable
- Integration: <1s ideal, <5s acceptable
- E2E: <10s ideal, <30s acceptable
- Parallelize test execution
- Profile and optimize slow tests
- Use test.only/test.skip temporarily, never commit

## References

Jest: jestjs.io | Pytest: docs.pytest.org | Test Pyramid: martinfowler.com/articles/practical-test-pyramid.html | xUnit Patterns: xunitpatterns.com | Testing Best Practices: testingjavascript.com | TDD by Kent Beck: book

---

**v2.0.0** (2026-02-15): Compact format per ADR 0009 - 62% reduction from 266 to 200 lines
