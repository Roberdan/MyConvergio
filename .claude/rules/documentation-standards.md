<!-- v2.1.0 -->

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

### Per-Wave ADR Mandate (NON-NEGOTIABLE)

Every wave of every plan MUST produce ADRs:

| Situation                             | Required ADR                                            |
| ------------------------------------- | ------------------------------------------------------- |
| Wave includes architectural decisions | Full ADR per decision (Context, Decision, Consequences) |
| Wave has NO architectural decisions   | Lightweight wave summary ADR                            |

**Wave Summary ADR Template** (file: `docs/adr/NNNN-wave-summary-plan-{id}-W{n}.md`):

```
# NNNN - Wave Summary: Plan {id} W{n}
## Context: {wave scope — what was done and why}
## Decision: {approach taken, key choices made}
## Consequences: {files changed, behaviors altered, what to watch}
```

Thor Gate 9 validates ADR presence per wave. Missing ADR = wave REJECTED.

## Changelog

CHANGELOG.md updated with releases | Keep a Changelog format | Group by: Added, Changed, Deprecated, Removed, Fixed, Security | Version numbers, dates, issue/PR refs

## Comments

Explain "why" not "what" | Update when code changes | No commented-out code (use git) | Sparse TO-DOs (track them) | Explain complex algorithms

## Diagrams

Architecture diagrams for complex systems | Consistent notation (C4, UML) | Keep updated | Store as code (Mermaid, PlantUML)

## README Standards

Comprehensive README per repo | Include: description, prerequisites, installation, usage, contributing | Badges (build, coverage, version) | Link to detailed docs | Quick-start examples

## Troubleshooting Doc (NON-NEGOTIABLE)

Every repo MUST have `TROUBLESHOOTING.md` in root (alongside CHANGELOG.md, README.md).

| Rule             | Detail                                                                      |
| ---------------- | --------------------------------------------------------------------------- |
| **Mandatory**    | Create before first plan if missing (part of repo onboarding)               |
| **Updated**      | Every plan that encounters+resolves issues MUST add them                    |
| **Format**       | `## Problem: {title}` then `**Symptom**:` then `**Cause**:` then `**Fix**:` |
| **Search first** | See `rules/problem-resolution.md` for mandatory search order                |

## Anti-Patterns

❌ States obvious ("Gets user") | ❌ Comments restate code | ❌ Commented-out code | ❌ Outdated docs | ❌ Missing context on complex logic
