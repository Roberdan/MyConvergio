<!-- v2.0.0 -->

# Coding Standards

> ISE: https://microsoft.github.io/code-with-engineering-playbook/

## Style

**TS/JS**: ESLint+Prettier, semicolons, single quotes, max 100 chars, const>let, async/await | Named imports, no default export (unless framework) | `interface` > `type` | Props interface above component | Colocated `.test.ts`, AAA | **Python**: Black 88 chars, Google docstrings, type hints public APIs, pytest+fixtures | **Bash**: `set -euo pipefail` | Quote vars | `local` in functions | `trap cleanup EXIT` | **CSS**: CSS Modules or BEM | `rem` for type, `px` for borders | Mobile-first | Max 3 nesting | **Config**: 2-space indent | Schema refs where supported

## Token-Aware Writing (ALL text agents produce)

Every token costs money and latency. Applies to code comments, commit messages, PR descriptions, review comments, agent output. Both Claude Code and Copilot CLI.

### Code Comments

**ALLOWED**: version/shebang headers, non-obvious logic (WHY not WHAT), workaround reasons, regex explanations, safety annotations
**FORBIDDEN**: restating what the next line does, section dividers (`# ===`, `# ---`), parameter descriptions for self-documenting names
**Target**: <5% comment lines in new files. Enforced by `code-pattern-check.sh` (P3 >20%)

### Commit Messages

Conventional commit, 1 subject line + optional body. No filler prose ("This commit...", "In this change..."). Body only when subject is insufficient.
**Good**: `feat: add null safety check to user API` | **Bad**: `feat: This commit adds a comprehensive null safety check to ensure that the user API properly handles null values`

### PR Descriptions

Structured markdown: `## Summary` (2-3 bullet points max) + `## Test plan`. No prose restating what the diff shows. Diff is the documentation.

### Review Comments

Direct and actionable. State the issue + the fix. No softening ("Perhaps consider...", "It might be worth..."). Code suggestion > prose explanation.

## Quality

**Testing**: 80% business logic, 100% critical paths, isolated, one behavior/test, no shared state | **API**: REST, plural nouns, /api/v1/, OpenAPI docs, paginate all lists, rate limiting | **Security**: Parameterized queries, CSP headers, env vars for secrets, TLS 1.2+, RBAC | Bicep outputs: no secrets (connection strings, keys) — store in Key Vault, output resource IDs only | SQL: bind parameters (`:param`) always, never f-strings — even for integers | IaC resource names: include environment suffix or `uniqueString()` to avoid collisions | **A11y**: 4.5:1 contrast, keyboard nav, screen readers, text alternatives, 200% resize | **Terms**: blocklist/allowlist, gender-neutral, primary/replica

## Async/Await

`async def` + sync I/O = wrap in `anyio.to_thread.run_sync()` or keep endpoint as `def` (FastAPI threadpool) | Azure SDK: import from `.aio` modules in async context, never sync SDK with `await` | No `asyncio.get_event_loop()` in sync functions — use lazy-connect or `asyncio.get_running_loop()`

## Bicep / IaC

`@secure()` propagation: parent `@secure()` param → module param MUST also be `@secure()` | `listKeys()`: only inline (secrets block), NEVER in outputs | `@description()` on every param and output | API versions: latest stable GA, not preview | ADR references: verify file exists in `docs/adr/` before citing | Markdown in CHANGELOG: escape underscores in env var names (`\_`)
