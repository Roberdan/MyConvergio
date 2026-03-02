# ADR-0025: Agent Format Standardization (PROSE → Structured YAML)

| Field    | Value                  |
| -------- | ---------------------- |
| Status   | Accepted               |
| Date     | 2026-03-02             |
| Author   | roberdan + Copilot CLI |
| Affects  | 77 Claude agents, 83 Copilot agents |

## Context

Audit revealed 26/77 Claude agents still use narrative prose body format (long paragraphs, descriptive sentences). 28/77 have incomplete YAML frontmatter (missing `maturity`, `providers`, `constraints`). 7/83 Copilot agents miss `model` or `tools`.

AI consumers (Claude Code, Copilot CLI) waste tokens parsing prose. Structured format (tables, bullets) reduces token consumption ~40-50% and improves instruction following.

## Decision

1. **All agent bodies** converted from prose to structured format: tables for capabilities/mappings, bullets for rules/constraints, no narrative paragraphs
2. **All agent frontmatter** must include: `name`, `description`, `tools`, `model`, `version`, `maturity`, `providers`, `constraints`
3. **Gold standard template**: `jony-creative-director.md` — compact, table-driven, zero prose
4. **Checklist files** (`nfr-checklist.md`, `metrics-checklist.md`, `owasp-checklist.md`) exempt — they are reference data, not agents

## Format Rules

| Element | Before (prose) | After (structured) |
|---------|----------------|-------------------|
| Capabilities | "Expert in X, Y, and Z with deep knowledge of..." | Table: `\| Domain \| Scope \|` |
| Methodology | Paragraphs describing approach | Table: `\| Category \| Frameworks \|` |
| Integration | "Works with Ali for coordination and Thor for..." | Table: `\| Agent \| Collaboration \|` |
| Rules | Paragraph explaining constraints | Bullet list |
| Security | 20+ lines boilerplate | Compact 8-line block |

## Frontmatter Values

| Field | Logic |
|-------|-------|
| `maturity` | `stable` if v2+, `preview` if v1.x, `alpha` if v0.x |
| `providers` | `[claude]` for all (primary platform) |
| `constraints` | Based on `tools`: no write → `["Read-only"]`, has write → `["Modifies files within assigned domain"]`, advisory → `["Advisory only"]` |

## Consequences

- ~40-50% token reduction per agent load
- Consistent machine-parseable format across all 77 agents
- Frontmatter enables automated routing, filtering, and validation
- Breaking: agents with custom formatting may look different in raw view
