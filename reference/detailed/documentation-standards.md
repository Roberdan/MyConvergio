# Documentation Standards

> This rule is enforced by the MyConvergio agent ecosystem.

## Overview
Clear, comprehensive documentation is essential for maintainability, knowledge transfer, and team collaboration. All code in the MyConvergio ecosystem must include appropriate documentation at multiple levels, from inline comments to architectural decision records.

## Requirements

### Code Documentation
- JSDoc (TypeScript/JavaScript) or docstrings (Python) required for all public APIs
- Document function parameters, return types, and exceptions
- Include usage examples for complex functions
- Document class purposes and responsibilities
- Explain "why" in comments, not "what" (code should be self-documenting)

### Module Documentation
- Every module/package must have a README.md
- Explain module purpose and responsibilities
- Document public APIs and exports
- Include usage examples
- List dependencies and prerequisites
- Provide installation/setup instructions

### API Documentation
- Document all REST endpoints (method, path, parameters, responses)
- Use OpenAPI/Swagger specification for REST APIs
- Include example requests and responses
- Document error codes and their meanings
- Specify authentication requirements
- Version API documentation with the API

### Architectural Decision Records (ADRs)
- Document all significant architectural decisions
- Use ADR format: Context, Decision, Consequences
- Store in `/docs/adr/` directory
- Number ADRs sequentially (0001-title.md)
- Link related ADRs
- Update when decisions are superseded

### Changelog Maintenance
- Keep CHANGELOG.md updated with all releases
- Follow Keep a Changelog format
- Group changes by type: Added, Changed, Deprecated, Removed, Fixed, Security
- Include version numbers and dates
- Reference issue/PR numbers

### Comments Guidelines
- Comments explain "why", not "what"
- Avoid comments that restate the code
- Update comments when code changes
- Remove commented-out code (use version control)
- Use TODO comments sparingly and track them
- Mark complex algorithms with explanations

### Diagrams and Visuals
- Include architecture diagrams for complex systems
- Use consistent notation (C4, UML, or informal)
- Keep diagrams up to date with code
- Store diagrams as code when possible (Mermaid, PlantUML)

### README Standards
- Every repository needs a comprehensive README
- Include: project description, prerequisites, installation, usage, contributing guidelines
- Add badges for build status, coverage, version
- Link to detailed documentation
- Provide quick-start examples

## Examples

### Good Examples

#### JSDoc (TypeScript)
```typescript
/**
 * Calculates the total price after applying discount and tax.
 *
 * @param items - Array of items to price
 * @param discountRate - Discount as decimal (0.1 = 10% off)
 * @param taxRate - Tax rate as decimal (0.08 = 8% tax)
 * @returns Total price including discount and tax
 * @throws {ValidationError} If discount or tax rate is negative
 *
 * @example
 * ```typescript
 * const items = [{ price: 10 }, { price: 20 }];
 * const total = calculateTotal(items, 0.1, 0.08);
 * // Returns: 29.16 (30 - 10% discount + 8% tax)
 * ```
 */
export function calculateTotal(
  items: Item[],
  discountRate: number,
  taxRate: number
): number {
  if (discountRate < 0 || taxRate < 0) {
    throw new ValidationError('Rates cannot be negative');
  }

  const subtotal = items.reduce((sum, item) => sum + item.price, 0);
  const afterDiscount = subtotal * (1 - discountRate);
  return afterDiscount * (1 + taxRate);
}
```

#### Python Docstring
```python
def process_payment(
    amount: Decimal,
    payment_method: PaymentMethod,
    user_id: str
) -> PaymentResult:
    """Process a payment transaction for a user.

    This function handles payment processing through various payment methods,
    including credit cards, PayPal, and bank transfers. It validates the
    payment, processes it through the appropriate gateway, and records the
    transaction in the database.

    Args:
        amount: Payment amount in USD (must be positive)
        payment_method: Payment method configuration with credentials
        user_id: ID of the user making the payment

    Returns:
        PaymentResult containing transaction ID, status, and receipt URL

    Raises:
        ValidationError: If amount is invalid or payment method is not configured
        PaymentGatewayError: If payment gateway rejects the transaction
        InsufficientFundsError: If user account has insufficient balance

    Example:
        >>> method = PaymentMethod(type='credit_card', token='tok_visa')
        >>> result = process_payment(Decimal('99.99'), method, 'user_123')
        >>> print(result.transaction_id)
        'txn_abc123'

    Note:
        This function is idempotent - duplicate calls with the same parameters
        will return the same transaction without charging twice.
    """
    # Implementation...
```

#### Architectural Decision Record
```markdown
# ADR 0003: Use PostgreSQL with JSONB for Document Storage

## Status
Accepted

## Context
We need to store semi-structured product data that varies significantly between
product categories. Some products have 5 attributes, others have 50+. The schema
needs to be flexible while maintaining query performance.

Options considered:
1. MongoDB - NoSQL document store
2. PostgreSQL with JSONB columns
3. DynamoDB - AWS managed NoSQL
4. Traditional normalized PostgreSQL schema

## Decision
We will use PostgreSQL with JSONB columns for product attributes while keeping
core fields (id, name, price) in regular columns.

Rationale:
- JSONB provides flexible schema for varying attributes
- Strong indexing and query capabilities for JSON data
- Maintains ACID guarantees unlike MongoDB
- Team has existing PostgreSQL expertise
- Avoids vendor lock-in with AWS-specific solution
- Can use SQL for complex queries across structured and unstructured data

## Consequences

### Positive
- Single database technology (PostgreSQL) reduces operational complexity
- JSONB indexing provides good query performance
- Schema flexibility for product attributes
- Strong consistency guarantees
- Familiar SQL query language

### Negative
- JSONB queries are less performant than indexed columns
- Limited to PostgreSQL-specific features (not portable to MySQL)
- Larger storage footprint than normalized tables
- Need to educate team on JSONB best practices

## References
- [PostgreSQL JSONB Documentation](https://www.postgresql.org/docs/current/datatype-json.html)
- [JSONB Performance Benchmarks](internal-link)
- Related ADRs: #0001 (Database Selection), #0002 (Product Catalog Design)
```

#### API Documentation (OpenAPI)
```yaml
# Good: Complete endpoint documentation
/api/users/{userId}/profile:
  get:
    summary: Get user profile
    description: Retrieves detailed profile information for a specific user
    parameters:
      - name: userId
        in: path
        required: true
        schema:
          type: string
          format: uuid
        description: Unique identifier for the user
    responses:
      200:
        description: User profile retrieved successfully
        content:
          application/json:
            schema:
              $ref: '#/components/schemas/UserProfile'
            example:
              id: "123e4567-e89b-12d3-a456-426614174000"
              email: "user@example.com"
              name: "John Doe"
              createdAt: "2025-01-15T10:30:00Z"
      404:
        description: User not found
        content:
          application/json:
            schema:
              $ref: '#/components/schemas/Error'
      401:
        description: Unauthorized - authentication required
    security:
      - bearerAuth: []
```

#### README Example
```markdown
# MyConvergio Payment Service

High-performance payment processing microservice for the MyConvergio ecosystem.

[![Build Status](https://github.com/myconvergio/payment-service/workflows/CI/badge.svg)](https://github.com/myconvergio/payment-service/actions)
[![Coverage](https://codecov.io/gh/myconvergio/payment-service/branch/main/graph/badge.svg)](https://codecov.io/gh/myconvergio/payment-service)
[![Version](https://img.shields.io/npm/v/@myconvergio/payment-service.svg)](https://www.npmjs.com/package/@myconvergio/payment-service)

## Features
- Multi-gateway support (Stripe, PayPal, Square)
- PCI-DSS compliant tokenization
- Automatic retry with exponential backoff
- Real-time webhook processing
- Comprehensive audit logging

## Prerequisites
- Node.js 18+
- PostgreSQL 14+
- Redis 6+ (for job queue)

## Quick Start

bash
# Install dependencies
npm install

# Configure environment
cp .env.example .env
# Edit .env with your settings

# Run migrations
npm run migrate

# Start development server
npm run dev


## Usage Example

typescript
import { PaymentService } from '@myconvergio/payment-service';

const service = new PaymentService({
  apiKey: process.env.PAYMENT_API_KEY
});

const result = await service.processPayment({
  amount: 1999, // cents
  currency: 'USD',
  paymentMethod: 'pm_card_visa',
  customerId: 'cus_123'
});


## Documentation
- [API Reference](./docs/api.md)
- [Architecture Overview](./docs/architecture.md)
- [Deployment Guide](./docs/deployment.md)

## Contributing
See [CONTRIBUTING.md](./CONTRIBUTING.md)

## License
MIT
```

### Bad Examples

#### Poor JSDoc
```typescript
// Bad: States the obvious, no examples
/**
 * Gets user.
 * @param id user id
 * @returns user
 */
function getUser(id: string): User {
  // ...
}
```

#### Useless Comments
```typescript
// Bad: Comment restates the code
// Increment counter by 1
counter++;

// Bad: Commented-out code
// const oldImplementation = () => {
//   return data.map(x => x.value);
// };
```

#### Missing Context
```python
# Bad: No explanation of complex logic
def process(data):
    # Why this specific calculation?
    result = sum(data) * 0.7 + 15
    return result
```

#### Outdated Documentation
```typescript
/**
 * Sends email to user
 * @param email - User email address
 */
function notifyUser(userId: string, channel: NotificationChannel) {
  // Function signature changed but docs didn't!
}
```

## References
- [JSDoc Documentation](https://jsdoc.app/)
- [Python Docstring Conventions (PEP 257)](https://peps.python.org/pep-0257/)
- [OpenAPI Specification](https://swagger.io/specification/)
- [Keep a Changelog](https://keepachangelog.com/)
- [Architectural Decision Records](https://adr.github.io/)
- [Writing Great Documentation](https://www.writethedocs.org/guide/)
- [Google Developer Documentation Style Guide](https://developers.google.com/style)
- [README Best Practices](https://github.com/matiassingers/awesome-readme)
