# Code Style Standards

> This rule is enforced by the MyConvergio agent ecosystem.

## Overview
Consistent code formatting and style standards across all languages in the MyConvergio ecosystem. These standards ensure readability, maintainability, and team collaboration efficiency.

## Requirements

### TypeScript/JavaScript
- Use ESLint with Prettier for automated formatting
- Prefer `const` over `let`, never use `var`
- Use arrow functions for callbacks and short functions
- Maximum line length: 100 characters
- Use camelCase for variables and functions
- Use PascalCase for classes and React components
- Use UPPER_SNAKE_CASE for constants
- Use async/await over callbacks and raw Promises
- Always use semicolons
- Use single quotes for strings (except when avoiding escapes)
- Trailing commas in multiline arrays and objects

### Python
- Follow PEP 8 style guide
- Use Black formatter with default settings
- Maximum line length: 100 characters
- Use snake_case for functions and variables
- Use PascalCase for classes
- Use UPPER_SNAKE_CASE for constants
- Type hints required for all public functions
- Docstrings required for all public modules, classes, and functions
- Use f-strings for string formatting
- Prefer list comprehensions over map/filter where readable

### General Principles
- Meaningful variable names (no single letters except `i`, `j`, `k` for loop counters)
- Function names should be verbs describing what they do
- Class names should be nouns describing what they represent
- Constants should clearly indicate their purpose
- Avoid magic numbers - use named constants
- Keep functions small and focused (single responsibility)
- DRY principle: Don't Repeat Yourself
- Comments explain "why", not "what"

## Examples

### Good Examples

#### TypeScript/JavaScript
```typescript
// Good: Meaningful names, const, async/await
const getUserProfile = async (userId: string): Promise<UserProfile> => {
  const response = await fetch(`/api/users/${userId}`);
  if (!response.ok) {
    throw new Error(`Failed to fetch user: ${response.status}`);
  }
  return response.json();
};

// Good: Named constant
const MAX_RETRY_ATTEMPTS = 3;
const API_TIMEOUT_MS = 5000;
```

#### Python
```python
# Good: Type hints, meaningful names, snake_case
def calculate_total_price(items: list[Item], discount_rate: float) -> float:
    """Calculate total price with discount applied.

    Args:
        items: List of items to price
        discount_rate: Discount as decimal (0.1 = 10%)

    Returns:
        Total price after discount
    """
    subtotal = sum(item.price for item in items)
    return subtotal * (1 - discount_rate)

# Good: Named constant
MAX_FILE_SIZE_MB = 10
DEFAULT_TIMEOUT_SECONDS = 30
```

### Bad Examples

#### TypeScript/JavaScript
```javascript
// Bad: var, single letter variable, no async/await
var u = function(id, cb) {
  fetch('/api/users/' + id).then(function(r) {
    r.json().then(function(d) {
      cb(d);
    });
  });
};

// Bad: Magic numbers, unclear names
function process(x) {
  if (x > 100) {
    return x * 0.9;
  }
  return x;
}
```

#### Python
```python
# Bad: No type hints, camelCase in Python, no docstring
def processData(d):
    r = []
    for x in d:
        if x > 100:  # Magic number
            r.append(x * 0.9)  # Magic number
    return r

# Bad: Single letter variables, unclear purpose
def calc(a, b, c):
    return a + b - c
```

## References
- [TypeScript Style Guide](https://google.github.io/styleguide/tsguide.html)
- [Airbnb JavaScript Style Guide](https://github.com/airbnb/javascript)
- [PEP 8 - Python Style Guide](https://peps.python.org/pep-0008/)
- [Black - Python Code Formatter](https://black.readthedocs.io/)
- [Prettier - Code Formatter](https://prettier.io/)
- [Clean Code by Robert C. Martin](https://www.amazon.com/Clean-Code-Handbook-Software-Craftsmanship/dp/0132350882)
