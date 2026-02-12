# ADR 0007: CLAUDE.md Restructuring — Extract to Reference Files

Status: Accepted | Date: 12 Feb 2026 | Plan: none

## Context

CLAUDE.md grew to 197 lines with inline details for concurrency, plan-db, and digests.
Agents lost context in long system prompts. OpenAI "Harness Engineering" validated
smaller on-demand references over monolithic instructions.

## Decision

Slim to 115 lines. Extract 3 sections to `reference/operational/` (concurrency-control,
plan-scripts, digest-scripts). Add inline `_Why:_` rationale to all NON-NEGOTIABLE rules.
Reference table in CLAUDE.md points to all 11 operational files.

## Consequences

- Positive: 42% smaller system prompt, on-demand loading, self-documenting rules
- Negative: Agents need extra tool call to read reference file details

## Enforcement

- Rule: `grep -c '^##' ~/.claude/CLAUDE.md` must be <= 15 sections
- Check: `awk 'END{print NR}' ~/.claude/CLAUDE.md` must be <= 130 lines
- Ref: ADR 0001, ADR 0003
