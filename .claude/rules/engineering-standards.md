# Engineering Standards

> Consolidated rules for software development. See ISE Fundamentals: https://microsoft.github.io/code-with-engineering-playbook/

---

## Code Style

### TypeScript/JavaScript
- ESLint + Prettier, `const` over `let`, never `var`
- camelCase (vars/funcs), PascalCase (classes/components), UPPER_SNAKE_CASE (constants)
- async/await, semicolons, single quotes, trailing commas
- Max 100 chars/line, meaningful names, no magic numbers

### Python
- PEP 8 + Black formatter, snake_case (funcs/vars), PascalCase (classes)
- Type hints required for public APIs, docstrings for public modules/classes/functions
- f-strings, list comprehensions where readable

### General
- Comments explain "why" not "what", no commented-out code
- Single responsibility, DRY, small focused functions

---

## Security (OWASP Top 10)

### Input Validation
- Validate client AND server side, allowlists over denylists
- Sanitize before storage, length limits, reject malformed input

### SQL/XSS Prevention
- Parameterized queries only, never concatenate user input
- Use ORM (Prisma, SQLAlchemy), escape user content
- CSP headers, DOMPurify for HTML, no raw `dangerouslySetInnerHTML`

### Secrets
- NEVER commit secrets to git, use env vars
- `.env` in `.gitignore`, different secrets per environment
- Rotate regularly, use secret managers (Vault, AWS Secrets Manager)

### Auth/Transport
- OAuth 2.0 / JWT, RBAC, verify auth on every request
- HTTPS only, HSTS, secure cookies (Secure, HttpOnly, SameSite)
- TLS 1.2+, account lockout after failed attempts

---

## Testing

### Coverage
- 80% minimum for business logic, 100% for critical paths
- Track in CI, include branch coverage

### Unit Tests
- Isolated, mock external deps, one behavior per test
- Fast (<1ms), no network/IO, descriptive names: `it('should X when Y')`

### Integration Tests
- Test DB with test database, cleanup after each test
- Fixtures/factories for test data, no production data

### Principles
- Tests run independently, no shared state
- Avoid over-mocking, parallelize execution

---

## API Design (REST)

### Conventions
- GET/POST/PUT/PATCH/DELETE, plural nouns (`/api/users`)
- Nested resources: `/api/users/{id}/orders`, max 3 levels deep
- kebab-case for multi-word: `/api/payment-methods`

### Status Codes
- 200 OK, 201 Created, 204 No Content
- 400 Bad Request, 401 Unauthorized, 403 Forbidden, 404 Not Found
- 409 Conflict, 422 Validation Error, 429 Rate Limited, 500 Server Error

### Pagination/Filtering
- All list endpoints paginated, include metadata (total, hasNext)
- Query params: `?page=1&limit=20&sort=createdAt&order=desc`

### Versioning
- URL versioning: `/api/v1/users`, support 2 major versions
- OpenAPI/Swagger docs, rate limiting with headers

---

## Documentation

### Code
- JSDoc/docstrings for public APIs with params, returns, throws
- ADRs in `/docs/adr/` for architectural decisions
- CHANGELOG.md with Keep a Changelog format

### Comments
- Explain "why" not "what", update when code changes
- No commented-out code, TODO tracked and resolved

---

## Ethics & Accessibility

### Privacy (GDPR/CCPA)
- Data minimization, explicit consent, encryption at rest/transit
- Users can access, modify, delete their data

### Accessibility (WCAG 2.1 AA)
- Keyboard navigable, 4.5:1 contrast, screen reader support
- Text alternatives, captions, 200% text resize

### Inclusive Language
- blocklist/allowlist (not black/white), gender-neutral
- primary/replica (not master/slave)

### AI Transparency
- Disclose AI interactions, explain recommendations
- Enable opt-out, document limitations and biases
