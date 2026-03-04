# ADR 0031: Knowledge Base Architecture

Status: Accepted | Date: 04 Mar 2026 | Plan: 332

## Context

AI agents lose learnings between sessions. Squad (bradygaster/squad) uses markdown files. We need structured, queryable knowledge that compounds across plans.

## Decision

SQLite table `knowledge_base` with LIKE search (not FTS5 — premature for <100 entries). Earned skills as VIEW (not separate table — 85% schema overlap). Schema includes `embedding BLOB` nullable for future vector migration.

## Consequences

- Positive: Zero new dependencies, instant queries, vector-ready schema
- Negative: LIKE search degrades at scale (mitigated: add FTS5 at 1000+ entries)

## Enforcement

- Rule: All KB writes via `plan-db.sh kb-*` commands (never raw sqlite3)
- Check: `sqlite3 ~/.claude/data/dashboard.db "SELECT COUNT(*) FROM knowledge_base;"`
