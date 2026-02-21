<!-- v2.0.0 -->

# Coding Standards

> ISE: https://microsoft.github.io/code-with-engineering-playbook/

## Style

**TS/JS**: ESLint+Prettier, semicolons, single quotes, max 100 chars, const>let, async/await | Named imports, no default export (unless framework) | `interface` > `type` | Props interface above component | Colocated `.test.ts`, AAA | **Python**: Black 88 chars, Google docstrings, type hints public APIs, pytest+fixtures | **Bash**: `set -euo pipefail` | Quote vars | `local` in functions | `trap cleanup EXIT` | **CSS**: CSS Modules or BEM | `rem` for type, `px` for borders | Mobile-first | Max 3 nesting | **Config**: 2-space indent | Schema refs where supported

## Quality

**Testing**: 80% business logic, 100% critical paths, isolated, one behavior/test, no shared state | **API**: REST, plural nouns, /api/v1/, OpenAPI docs, paginate all lists, rate limiting | **Security**: Parameterized queries, CSP headers, env vars for secrets, TLS 1.2+, RBAC | Bicep outputs: no secrets (connection strings, keys) — store in Key Vault, output resource IDs only | SQL: bind parameters (`:param`) always, never f-strings — even for integers | IaC resource names: include environment suffix or `uniqueString()` to avoid collisions | **A11y**: 4.5:1 contrast, keyboard nav, screen readers, text alternatives, 200% resize | **Terms**: blocklist/allowlist, gender-neutral, primary/replica

## Async/Await

`async def` + sync I/O = wrap in `anyio.to_thread.run_sync()` or keep endpoint as `def` (FastAPI threadpool) | Azure SDK: import from `.aio` modules in async context, never sync SDK with `await` | No `asyncio.get_event_loop()` in sync functions — use lazy-connect or `asyncio.get_running_loop()`

## Bicep / IaC

`@secure()` propagation: parent `@secure()` param → module param MUST also be `@secure()` | `listKeys()`: only inline (secrets block), NEVER in outputs | `@description()` on every param and output | API versions: latest stable GA, not preview | ADR references: verify file exists in `docs/adr/` before citing | Markdown in CHANGELOG: escape underscores in env var names (`\_`)
