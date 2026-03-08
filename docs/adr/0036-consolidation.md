# ADR 0036: P2+P3 Consolidation

Status: Accepted | Date: 07 Mar 2026 | Plan: 100025

## Context
Execution reliability degraded due to duplicated validators, overlapping hook responsibilities, and repeated SQL utility logic across scripts.

## Decision
Consolidate shared primitives (SQL utils, dispatchers, validation ownership), keep hook checks advisory where appropriate, and centralize canonical behavior in single libraries.

## Consequences
- Positive: Less drift, fewer contradictory checks, and simpler maintenance.
- Negative: Shared modules become critical dependencies for multiple flows.

## Enforcement
- Rule: `No duplicate core helpers when a canonical library exists`
- Check: `bash tests/test-T9-03-sql-utils-consolidation.sh && bash tests/test-T9-04-validation-dedupe.sh`
- Ref: ADR-0021, ADR-0026, ADR-0032
