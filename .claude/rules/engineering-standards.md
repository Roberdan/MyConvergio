# Engineering Standards

> ISE Fundamentals: https://microsoft.github.io/code-with-engineering-playbook/

## Code Style
**TS/JS**: ESLint+Prettier, const>let, never var, camelCase/PascalCase/UPPER_SNAKE, async/await, semicolons, single quotes, max 100 chars
**Python**: PEP8+Black, snake_case/PascalCase, type hints for public APIs, f-strings
**General**: Comments explain "why", no commented code, SRP, DRY, small functions

## Security (OWASP)
**Input**: Validate client+server, allowlists, sanitize, length limits
**SQL/XSS**: Parameterized queries only, ORM, escape content, CSP headers, DOMPurify
**Secrets**: Never commit, use env vars, .env in .gitignore, rotate, use secret managers
**Auth**: OAuth2/JWT, RBAC, verify every request, HTTPS only, HSTS, secure cookies, TLS 1.2+

## Testing
**Coverage**: 80% business logic, 100% critical paths, track in CI
**Unit**: Isolated, mock externals, one behavior/test, fast (<1ms), no network/IO
**Integration**: Test DB, cleanup after, fixtures/factories, no prod data
**Principles**: Independent, no shared state, avoid over-mocking, parallelize

## API Design (REST)
**Conventions**: GET/POST/PUT/PATCH/DELETE, plural nouns, nested max 3 levels, kebab-case
**Status**: 200/201/204, 400/401/403/404/409/422/429/500
**Pagination**: All lists paginated, metadata (total, hasNext), query params
**Versioning**: URL /api/v1/, support 2 major, OpenAPI docs, rate limiting

## Documentation
JSDoc/docstrings for public APIs, ADRs in /docs/adr/, CHANGELOG.md, comments explain "why"

## Ethics
**Privacy**: Data minimization, consent, encryption, user data rights
**A11y**: Keyboard nav, 4.5:1 contrast, screen readers, text alternatives, 200% resize
**Language**: blocklist/allowlist, gender-neutral, primary/replica
**AI**: Disclose interactions, explain recommendations, enable opt-out
