# ADR 0035: P1 Token Diet

Status: Accepted | Date: 07 Mar 2026 | Plan: 100025

## Context
Prompt bloat across agents, commands, and hooks was increasing latency and cost, and reducing effective reasoning budget during plan execution.

## Decision
Standardize compact instruction patterns, lazy-load large agent definitions, and split oversized docs into indexed references with strict size limits and verification tests.

## Consequences
- Positive: Lower token burn with faster startup and higher signal density per call.
- Negative: Navigation now depends on index integrity and wrapper consistency.

## Enforcement
- Rule: `Keep instruction surfaces compact and move long detail behind @reference indexes`
- Check: `bash tests/test-T7-01-agent-lazy-load.sh && bash tests/test-T7-02-doc-compaction.sh && bash tests/test-T7-04-command-size.sh`
- Ref: ADR-0001, ADR-0009, ADR-0031
