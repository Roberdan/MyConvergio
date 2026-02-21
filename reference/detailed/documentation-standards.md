# Documentation Standards v2.0.0

> Enforced by MyConvergio agent ecosystem. Compact format per ADR 0009.

## Documentation Layers

| Layer      | Format           | Required For                | Key Elements                         |
|------------|------------------|-----------------------------|--------------------------------------|
| Code       | JSDoc/Docstring  | All public APIs             | Params, returns, exceptions, example |
| Module     | README.md        | Every module/package        | Purpose, APIs, usage, setup          |
| API        | OpenAPI/Swagger  | All REST endpoints          | Methods, params, responses, auth     |
| ADR        | Markdown         | Significant decisions       | Context, decision, consequences      |
| Changelog  | CHANGELOG.md     | All releases                | Added/Changed/Fixed/Security         |
| Diagrams   | Mermaid/PlantUML | Complex systems             | Architecture, flows, relationships   |

## Code Documentation Rules

- JSDoc (TS/JS) or docstrings (Python) for all public functions/classes
- Document: params | returns | exceptions | usage examples
- Comments explain "why", not "what" (code self-documents)
- No TODO/FIXME in production code (use issue tracker)
- Remove commented code (rely on version control)
- Update docs when code changes

## Module README Requirements

Every module needs:
1. Purpose & responsibilities
2. Public API documentation
3. Usage examples
4. Dependencies & prerequisites
5. Installation/setup instructions
6. Links to detailed docs

## ADR Format

```markdown
# ADR 0003: Use PostgreSQL with JSONB

## Status
Accepted | Deprecated | Superseded by ADR-0005

## Context
Problem statement. Options considered: 1) Option A, 2) Option B, 3) Option C

## Decision
We will use [chosen solution]. Rationale: flexibility, performance, team expertise.

## Consequences
Positive: maintainability, performance | Negative: complexity, learning curve

## References
Related ADRs, docs, benchmarks
```

Store in `/docs/adr/NNNN-title.md`. Number sequentially.

## Examples

### TypeScript JSDoc

```typescript
/**
 * Calculate total with discount and tax.
 * @param items - Array of items to price
 * @param discountRate - Discount (0.1 = 10%)
 * @param taxRate - Tax (0.08 = 8%)
 * @returns Total after discount and tax
 * @throws {ValidationError} If rates negative
 * @example calculateTotal([{price: 10}], 0.1, 0.08) // 9.72
 */
export function calculateTotal(items: Item[], discountRate: number, taxRate: number): number {
  if (discountRate < 0 || taxRate < 0) throw new ValidationError('Rates ≥0');
  return items.reduce((sum, i) => sum + i.price, 0) * (1 - discountRate) * (1 + taxRate);
}
```

### Python Docstring

```python
def process_payment(amount: Decimal, method: PaymentMethod, user_id: str) -> PaymentResult:
    """Process payment through gateway (idempotent).
    
    Args:
        amount: USD amount (positive)
        method: Payment method w/ credentials
        user_id: User ID
    Returns: PaymentResult w/ transaction ID, status, receipt URL
    Raises: ValidationError | PaymentGatewayError | InsufficientFundsError
    Example: process_payment(Decimal('99.99'), method, 'user_123')
    """
```

### README Template

```markdown
# Project Name
Brief description.

[![Build](url)](link) [![Coverage](url)](link)

## Features
- Feature 1 | Feature 2

## Prerequisites
Node.js 18+ | PostgreSQL 14+

## Quick Start
\`\`\`bash
npm install && cp .env.example .env && npm run migrate && npm run dev
\`\`\`

## Usage
\`\`\`typescript
import { Service } from '@org/package';
const result = await service.process(data);
\`\`\`

## Docs
[API](./docs/api.md) | [Architecture](./docs/architecture.md)

## License
MIT
```

### Anti-Patterns

| ✗ Bad                                    | ✓ Good                           |
|------------------------------------------|----------------------------------|
| `// Increment counter`<br>`counter++;`   | Remove obvious comment           |
| `// TODO: Fix later`                     | Create issue, link if needed     |
| Commented-out code                       | Delete (use git)                 |
| Outdated docs after code changes         | Update docs with code            |
| `/** Gets user @param id */`             | Add exceptions, examples, notes  |

## Changelog Format

```markdown
# Changelog
## [1.2.0] - 2025-12-15
### Added
- Feature X (#123)
### Fixed
- Bug Y (#125)
### Security
- Patched XSS (#126)
```

Groups: Added | Changed | Deprecated | Removed | Fixed | Security

## OpenAPI Example

```yaml
/api/users/{userId}/profile:
  get:
    summary: Get user profile
    parameters:
      - name: userId
        in: path
        required: true
        schema: {type: string, format: uuid}
    responses:
      200:
        description: Success
        content:
          application/json:
            schema: {$ref: '#/components/schemas/UserProfile'}
            example: {id: "123", email: "user@example.com"}
      404: {description: Not found}
      401: {description: Unauthorized}
    security: [{bearerAuth: []}]
```

## References

JSDoc: jsdoc.app | Python PEP 257: peps.python.org/pep-0257 | OpenAPI: swagger.io/specification | Keep a Changelog: keepachangelog.com | ADR: adr.github.io | Google Style Guide: developers.google.com/style

---

**v2.0.0** (2026-02-15): Compact format per ADR 0009 - 64% reduction from 359 to 200 lines
