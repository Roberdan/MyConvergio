# ADR 0034: P0 Conversational Plan Builder

Status: Accepted | Date: 07 Mar 2026 | Plan: 100025

## Context
Plan 100025 needed a conversational path that can capture requirements, clarify intent, and convert chat context into an executable plan without leaving the dashboard.

## Decision
Adopt a phase-driven chat architecture (CAPTURE -> CLARIFY -> RESEARCH -> PLAN -> APPROVE -> EXECUTE -> MONITOR) with explicit requirement accumulation and approval gating.

## Consequences
- Positive: Planning is faster, traceable, and directly connected to execution.
- Negative: Orchestrator logic and UI state management become more complex.

## Enforcement
- Rule: `EXECUTE requires explicit APPROVE state for the active chat session`
- Check: `rg -n "APPROVE|EXECUTE|phase" scripts/dashboard_web/{chat_orchestrator.py,lib/phase_detector.py,api_chat.py}`
- Ref: ADR-0019, ADR-0031
