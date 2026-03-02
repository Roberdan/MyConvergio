<!-- v2.1.0 -->

# Coding Standards

> ISE: https://microsoft.github.io/code-with-engineering-playbook/

## Style

**TS/JS**: ESLint+Prettier, semicolons, single quotes, max 100 chars, const>let, async/await | Named imports, no default export (unless framework) | `interface` > `type` | Props interface above component | Colocated `.test.ts`, AAA | **Python**: Black 88 chars, Google docstrings, type hints public APIs, pytest+fixtures | **Bash**: `set -euo pipefail` | Quote vars | `local` in functions | `trap cleanup EXIT` | **CSS**: CSS Modules or BEM | `rem` for type, `px` for borders | Mobile-first | Max 3 nesting | **Config**: 2-space indent | Schema refs where supported

## Token-Aware Writing (ALL text agents produce)

Every token costs money and latency. Applies to ALL agent-produced text: code, comments, commits, PRs, reviews, documentation, ADRs, changelogs, agent .md files. Both Claude Code and Copilot CLI. **Exception**: README files remain human-friendly (prose allowed).

### Code Comments

**ALLOWED**: version/shebang, non-obvious logic (WHY not WHAT), workaround reasons, safety annotations
**FORBIDDEN**: restating code, section dividers (`# ===`), parameter docs for self-documenting names
**Target**: <5% comment lines. Enforced: `code-pattern-check.sh` P3 >20%

### Commits & PRs

Commits: conventional, 1 subject line, body only when subject insufficient. No filler ("This commit...").
PRs: `## Summary` (2-3 bullets) + `## Test plan`. Diff is the documentation.
Reviews: direct + actionable. Issue + fix. No softening.

### Documentation, ADRs, CHANGELOGs, Agent .md

Same principle: only text that changes agent behavior. Tables > prose. Commands > descriptions. No introductory paragraphs that restate the title. No "This document describes..." preamble.
**CHANGELOG**: `## [version] - date` then `### Added|Changed|Fixed` with 1-line entries. No sub-bullets explaining what the entry means.
**ADR**: Context/Decision/Consequences, each 1-3 sentences. No background essays.
**Agent .md**: frontmatter + rules + commands. No motivational prose.
**Exception**: README.md files are human-facing — prose, examples, and explanations are appropriate.

## Quality

**Testing**: 80% business logic, 100% critical paths, isolated, one behavior/test, no shared state | **API**: REST, plural nouns, /api/v1/, OpenAPI docs, paginate all lists, rate limiting | **Security**: Parameterized queries, CSP headers, env vars for secrets, TLS 1.2+, RBAC | Bicep outputs: no secrets (connection strings, keys) — store in Key Vault, output resource IDs only | SQL: bind parameters (`:param`) always, never f-strings — even for integers | IaC resource names: include environment suffix or `uniqueString()` to avoid collisions | **A11y**: 4.5:1 contrast, keyboard nav, screen readers, text alternatives, 200% resize | **Terms**: blocklist/allowlist, gender-neutral, primary/replica

## Fail-Loud Patterns (NON-NEGOTIABLE)

Empty data that SHOULD NOT be empty MUST produce visible feedback. Silent degradation (`return null` on unexpected empty) = BUG.

| Pattern | WRONG | RIGHT |
|---|---|---|
| Admin with 0 studios | `if (!studios.length) return null` | `console.warn('[Component] unexpected empty') + <Alert>` |
| API returns empty unexpectedly | Silently show blank UI | Log warning + show "No data — check configuration" |
| Missing CSS variable | Render with broken style | CI script validates all `var(--name)` are defined |
| Import not found at runtime | App crashes with cryptic error | Explicit error boundary with human-readable message |

**Exception**: Loading states, optional features, explicit "no data" UX.

## Async/Await

`async def` + sync I/O = wrap in `anyio.to_thread.run_sync()` or keep endpoint as `def` (FastAPI threadpool) | Azure SDK: import from `.aio` modules in async context, never sync SDK with `await` | No `asyncio.get_event_loop()` in sync functions — use lazy-connect or `asyncio.get_running_loop()`

## Bicep / IaC

`@secure()` propagation: parent `@secure()` param → module param MUST also be `@secure()` | `listKeys()`: only inline (secrets block), NEVER in outputs | `@description()` on every param and output | API versions: latest stable GA, not preview | ADR references: verify file exists in `docs/adr/` before citing | Markdown in CHANGELOG: escape underscores in env var names (`\_`)
