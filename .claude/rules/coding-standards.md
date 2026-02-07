# Coding Standards

> ISE: https://microsoft.github.io/code-with-engineering-playbook/

## Style

**TS/JS**: ESLint+Prettier, semicolons, single quotes, max 100 chars, const>let, async/await. Named imports, no default export (unless framework). `interface` > `type`. Props interface above component. Colocated `.test.ts`, AAA.
**Python**: Black 88 chars, Google docstrings, type hints public APIs, pytest+fixtures.
**Bash**: `set -euo pipefail`. Quote vars. `local` in functions. `trap cleanup EXIT`.
**CSS**: CSS Modules or BEM. `rem` for type, `px` for borders. Mobile-first. Max 3 nesting.
**Config**: 2-space indent. Schema refs where supported.

## Quality

**Testing**: 80% business logic, 100% critical paths, isolated, one behavior/test, no shared state
**API**: REST, plural nouns, /api/v1/, OpenAPI docs, paginate all lists, rate limiting
**Security**: Parameterized queries, CSP headers, env vars for secrets, TLS 1.2+, RBAC
**A11y**: 4.5:1 contrast, keyboard nav, screen readers, text alternatives, 200% resize
**Terms**: blocklist/allowlist, gender-neutral, primary/replica
