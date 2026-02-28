# ADR 0018: Memory Protocol

Status: Accepted | Date: 21 Feb 2026

## Context

AI agents operate in stateless sessions. Each new session has no memory of previous interactions, decisions, or learned context. Users must re-explain project structure and conventions. Agents cannot recall past mistakes or successful approaches. Existing solutions (conversation history, RAG embeddings) are session-bound or require complex infrastructure.

## Decision

**Implement hierarchical memory system with file-based persistence.**

### Memory Layers

| Layer    | Path                                  | Scope         | Duration       |
|----------|---------------------------------------|---------------|----------------|
| Session  | `memory/sessions/<id>.json`           | Current only  | Ephemeral      |
| Project  | `memory/projects/<id>/memory.json`    | Project       | Persistent     |
| Global   | `memory/global/memory.json`           | All projects  | Persistent     |
| Team     | `memory/teams/<id>/memory.json`       | Team members  | Shared         |

**Session Memory**: Tool usage, file edits, decisions (auto-cleaned on session end)
**Project Memory**: Conventions, architecture, patterns (explicit writes via `memory-write.sh`)
**Global Memory**: User preferences, tool patterns (rare, high-confidence only)
**Team Memory**: Team decisions, cross-agent coordination (any member can write)

### Memory Schema

```json
{
  "version": "1.0",
  "entries": [
    {
      "id": "mem-001",
      "type": "decision|convention|pattern|preference",
      "content": "Use Zod for all input validation",
      "confidence": 0.95,
      "created_at": "2026-02-15T14:20:00Z",
      "accessed_count": 12
    }
  ]
}
```

### Memory Operations

```bash
# Read
memory-read.sh project <project_id> --type decision

# Write
memory-write.sh project <project_id> --type convention --content "..." --confidence 0.9

# Search
memory-search.sh --query "validation" --scope project

# Forget (soft delete)
memory-forget.sh --id mem-001 --scope project --reason "Outdated"
```

### Context Injection

**Session Start**: Load project + team memory → inject top 10 entries into system prompt
**Pre-Task**: Search memory for relevant patterns → inject as context
**Post-Task**: Extract learnings → propose memory writes → store approved

### Memory Ranking

Relevance score: `(confidence * 0.4) + (recency * 0.3) + (access_frequency * 0.3)`

Top-ranked entries injected first (token budget limited).

### Memory Conflicts

**Same Scope**: Present both to user → user resolves (keep/merge/delete)
**Cross-Scope**: Project > Global, Team > Project (explicit override: `--override-global`)

## Consequences

- **Positive**: Persistent context across sessions. Reduced repeated explanations. Consistent decisions. Learning from mistakes. Team knowledge sharing. File-based (no database). Version controllable.
- **Negative**: Token overhead (~1000-5000 per session). Can become stale. Requires curation. File I/O on session start.

## Enforcement

- Rule: Read project memory on session start
- Rule: Propose memory writes for significant decisions
- Check: `jq . < memory/projects/<id>/memory.json` (valid JSON)
- Migration: `memory-init.sh` creates directory structure

## File Impact

| File                              | Purpose                                      |
|-----------------------------------|----------------------------------------------|
| `scripts/memory-read.sh`          | Read entries (project/global/team)           |
| `scripts/memory-write.sh`         | Write entries with confidence scoring        |
| `scripts/memory-search.sh`        | Full-text search across scopes               |
| `scripts/memory-forget.sh`        | Soft-delete entries                          |
| `scripts/memory-init.sh`          | Initialize directory structure               |
| `scripts/memory-rank.sh`          | Rank entries by relevance                    |
| `memory/sessions/`                | Ephemeral session memory                     |
| `memory/projects/<id>/`           | Per-project persistent memory                |
| `memory/global/`                  | Cross-project memory                         |
| `memory/teams/<id>/`              | Team-shared memory                           |
| `agents/*/system-prompt.md`       | Inject memory on session start               |

## Usage Example

**Session Start**: Load "Use Zod for validation" (0.95), "Prefer functional components" (0.85)
**Mid-Task**: Check memory → "Use Zod" → proceed with Zod schema
**Post-Task**: Learned "Library X lacks feature Y" → propose write → approved → stored (mem-015)

## Related ADRs

- ADR-0002: Inter-Wave Communication (task-level output_data)
- ADR-0004: Distributed Plan Execution (cross-agent coordination)
- ADR-0010: Multi-Provider Orchestration (cross-provider memory)
