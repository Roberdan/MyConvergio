# ADR 0033: Dashboard UX Refactor

## Status

Accepted

## Context

Dashboard had 8 files exceeding 250 lines, duplicated functions across modules, stale mesh data (no live CPU/RAM), and plan status that was hard to interpret at a glance.

## Decision

- Split all oversized files: kpi.js→3, mesh-actions.js→4, api_mesh.py→3, api_plans.py→4, mesh_handoff.py→3, api_dashboard.py extracted jsonl_scraper
- Extract shared modules: lib/ssh.py, lib/sse.py, lib/jsonl_scraper.py, lib/mesh_helpers.py
- Add live RAM data to mesh-load-query.sh and peer cards with visual gauges
- BLOCKED counter includes submitted tasks stuck >5min
- Actionable buttons: Run Thor (calls validate-task API), Resume (opens terminal with /execute), Debug (opens terminal)
- Collapse pending waves into expandable counter
- Task pipeline rows colored by status with tooltip on truncated titles

## Consequences

- All in-scope files ≤250 lines (Thor Gate 3 compliant)
- Single source for SSH, SSE, formatters — no duplication
- Dashboard shows real system state, not stale DB heartbeats
- Users can act on stuck plans directly from the UI
