# Testing Standards

> This rule is enforced by the MyConvergio agent ecosystem.

## Overview
Comprehensive testing is mandatory in the MyConvergio ecosystem. All code must include appropriate unit, integration, and end-to-end tests to ensure reliability, prevent regressions, and facilitate confident refactoring.

## Requirements

### Test Coverage
- Minimum 80% code coverage for all business logic
- 100% coverage for critical paths (authentication, payment, data integrity)
- Track coverage metrics in CI/CD pipeline
- Coverage should include branches, not just lines

### Unit Testing
- Required for all business logic functions
- Test pure functions in isolation
- Mock external dependencies (databases, APIs, file system)
- Each test should verify one specific behavior
- Fast execution (< 1ms per test ideal)
- No network calls or file I/O in unit tests

### Integration Testing
- Required for all API endpoints
- Test database interactions with test database
- Verify external service integrations
- Test authentication and authorization flows
- Use fixtures and factories for test data
- Clean up test data after each test

### Test Naming Conventions
- Use descriptive names that explain the scenario
- Format: `describe('ComponentName', () => it('should do X when Y'))`
- Name should read like a specification
- Group related tests in describe blocks
- Use nested describe blocks for context

### Test Data Management
- Use fixtures for complex test data
- Use factories for generating test objects
- Never use production data in tests
- Reset database state between tests
- Avoid test interdependencies

### Test Isolation
- Tests must run independently
- No shared state between tests
- Each test should set up its own data
- Clean up resources in afterEach/teardown
- Tests should pass in any order

### Mocking & Stubbing
- Mock external dependencies (APIs, databases, time)
- Use dependency injection to enable mocking
- Avoid over-mocking (test real integration when possible)
- Document what is mocked and why
- Use test doubles appropriately (mocks, stubs, spies, fakes)

### Performance
- Unit tests should run in milliseconds
- Integration tests should run in seconds
- Optimize slow tests
- Parallelize test execution when possible
- Flag and investigate flaky tests

## Examples

### Good Examples

#### Unit Test (TypeScript/Jest)
```typescript
// Good: Clear naming, isolated, single behavior
describe('calculateDiscount', () => {
  it('should apply 10% discount for premium users', () => {
    const user = { isPremium: true };
    const price = 100;

    const result = calculateDiscount(price, user);

    expect(result).toBe(90);
  });

  it('should return original price for non-premium users', () => {
    const user = { isPremium: false };
    const price = 100;

    const result = calculateDiscount(price, user);

    expect(result).toBe(100);
  });

  it('should throw error for negative prices', () => {
    const user = { isPremium: true };
    const price = -50;

    expect(() => calculateDiscount(price, user))
      .toThrow('Price must be positive');
  });
});
```

#### Integration Test (Python/pytest)
```python
# Good: Database integration, fixtures, cleanup
@pytest.fixture
def test_db():
    """Create test database and clean up after."""
    db = create_test_database()
    yield db
    db.cleanup()

def test_create_user_endpoint(test_db, client):
    """Should create user and return 201 with user data."""
    # Arrange
    user_data = {
        "email": "test@example.com",
        "name": "Test User"
    }

    # Act
    response = client.post("/api/users", json=user_data)

    # Assert
    assert response.status_code == 201
    assert response.json["email"] == user_data["email"]

    # Verify in database
    user = test_db.query(User).filter_by(email=user_data["email"]).first()
    assert user is not None
    assert user.name == user_data["name"]
```

#### Mocking External Services (TypeScript)
```typescript
// Good: Mock external API, test error handling
describe('UserService', () => {
  let mockHttpClient: jest.Mocked<HttpClient>;
  let userService: UserService;

  beforeEach(() => {
    mockHttpClient = {
      get: jest.fn(),
      post: jest.fn(),
    } as any;
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

#### Test Fixtures (Python)
```python
# Good: Reusable fixtures, factory pattern
@pytest.fixture
def sample_user():
    """Create a sample user for testing."""
    return User(
        id="123",
        email="test@example.com",
        name="Test User",
        is_premium=True
    )

@pytest.fixture
def user_factory():
    """Factory for creating test users with custom attributes."""
    def _create_user(**kwargs):
        defaults = {
            "email": "test@example.com",
            "name": "Test User",
            "is_premium": False
        }
        return User(**{**defaults, **kwargs})
    return _create_user

def test_with_factory(user_factory):
    premium_user = user_factory(is_premium=True)
    regular_user = user_factory()

    assert premium_user.is_premium
    assert not regular_user.is_premium
```

### Bad Examples

#### Poor Test Naming
```typescript
// Bad: Unclear test names
describe('User', () => {
  it('test1', () => {
    // What does this test?
  });

  it('works', () => {
    // Works for what scenario?
  });
});
```

#### Shared State
```typescript
// Bad: Tests share state, order-dependent
let userId;

it('creates user', async () => {
  const user = await createUser({ email: 'test@example.com' });
  userId = user.id; // Shared state!
});

it('updates user', async () => {
  await updateUser(userId, { name: 'Updated' }); // Depends on previous test!
});
```

#### No Mocking (Slow Tests)
```typescript
// Bad: Real API call in unit test
it('should fetch user data', async () => {
  const result = await fetch('https://api.example.com/users/123');
  // This is slow, unreliable, and not a unit test!
  expect(result.status).toBe(200);
});
```

#### Magic Values
```python
# Bad: Magic numbers and unclear test data
def test_calculate_price():
    result = calculate_price(100, 0.1, True, 5)
    assert result == 427.5  # What do these numbers mean?
```

#### No Assertions
```typescript
// Bad: No verification of behavior
it('should process order', () => {
  processOrder(order);
  // Test passes but doesn't verify anything!
});
```

## References
- [Jest Documentation](https://jestjs.io/docs/getting-started)
- [Pytest Documentation](https://docs.pytest.org/)
- [Testing Best Practices](https://testingjavascript.com/)
- [Martin Fowler - Test Pyramid](https://martinfowler.com/articles/practical-test-pyramid.html)
- [Test-Driven Development by Kent Beck](https://www.amazon.com/Test-Driven-Development-Kent-Beck/dp/0321146530)
- [xUnit Test Patterns](http://xunitpatterns.com/)
- [Google Testing Blog](https://testing.googleblog.com/)
