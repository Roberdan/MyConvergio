# ADR-013: v11 Migration Strategy

Status: Accepted | Date: 08 Mar 2026 | Plan: 379

## Context

v11.0.0 is a breaking release. Previous .claude upgrade lost plan DB data
because no backup/restore pipeline existed. MyConvergio users need safe upgrade path.

## Decision

Mandatory backup before any migration. Three-script pipeline:
myconvergio-backup.sh → migrate-v10-to-v11.sh → myconvergio-restore.sh (rollback).
install.sh detects version and routes to correct path.

## Consequences

- Positive: Zero data loss risk, user confidence, rollback capability
- Negative: More complex install flow, 3 new scripts to maintain

## Enforcement

- Rule: install.sh refuses v10→v11 without backup
- Check: `test -f ~/.myconvergio-backups/*/manifest.json`
