<!-- v2.0.0 -->

# Documentation Standards

> MyConvergio agent ecosystem rule

## Code Docs

**JSDoc/Docstrings** for all public APIs | Params, returns, exceptions | Usage examples for complex functions | Class purposes | Comments explain "why" not "what"

## Module Docs

Every module/package: README.md | Purpose, public APIs, usage examples | Dependencies, installation

## API Docs

OpenAPI/Swagger for REST APIs | All endpoints (method, path, params, responses) | Example requests/responses | Error codes | Auth requirements | Version with API

## ADRs

**All significant architectural decisions** | Format: Context, Decision, Consequences | Store in `/docs/adr/` | Number sequentially (0001-title.md) | Link related ADRs | Update when superseded

## Changelog

CHANGELOG.md updated with releases | Keep a Changelog format | Group by: Added, Changed, Deprecated, Removed, Fixed, Security | Version numbers, dates, issue/PR refs

## Comments

Explain "why" not "what" | Update when code changes | No commented-out code (use git) | Sparse TODOs (track them) | Explain complex algorithms

## Diagrams

Architecture diagrams for complex systems | Consistent notation (C4, UML) | Keep updated | Store as code (Mermaid, PlantUML)

## README Standards

Comprehensive README per repo | Include: description, prerequisites, installation, usage, contributing | Badges (build, coverage, version) | Link to detailed docs | Quick-start examples

## Examples

```typescript
/**
 * Calculates total price after discount and tax.
 * @param items - Array of items to price
 * @param discountRate - Discount as decimal (0.1 = 10%)
 * @returns Total including discount and tax
 * @throws {ValidationError} If rates negative
 * @example
 * const total = calculateTotal([{price: 10}], 0.1, 0.08); // 9.72
 */
```

```python
def process_payment(amount: Decimal, method: PaymentMethod, user_id: str) -> PaymentResult:
    """Process payment transaction.
    
    Args:
        amount: Payment in USD (positive)
        method: Payment configuration
        user_id: User ID
    
    Returns:
        PaymentResult with transaction ID, status, receipt URL
    
    Raises:
        ValidationError: Invalid amount/method
        PaymentGatewayError: Gateway rejection
    """
```

## Anti-Patterns

❌ States obvious ("Gets user") | ❌ Comments restate code | ❌ Commented-out code | ❌ Outdated docs | ❌ Missing context on complex logic
