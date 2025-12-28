# ADR-011: Modular Execution Plans and Enhanced Security Framework

| Field | Value |
|-------|-------|
| **Status** | Accepted |
| **Date** | 2025-12-28 |
| **Deciders** | Roberto, AI Team |

## Context

Two improvements were identified from ConvergioCLI that enhance the MyConvergio ecosystem:

1. **Modular Execution Plan Structure**: Large plans (15+ tasks) were causing context compression and token limit issues. A modular file structure was developed to keep plans manageable.

2. **Security & Anti-Manipulation Framework**: Enhanced security guidelines were needed to protect agents from prompt injection, information disclosure, and ethical boundary violations.

## Decision

### 1. Modular Execution Plan Structure

Implemented in `taskmaster-strategic-task-decomposition-master` and `davide-project-manager`:

```
docs/
├── [ProjectName]MasterPlan.md      # Main plan (~100-150 lines max)
└── [project-name]/
    ├── phases/                      # One file per phase
    │   ├── phase-1-[name].md
    │   ├── phase-2-[name].md
    │   └── ...
    ├── adr/                         # Feature-specific ADRs
    │   └── NNN-decision-name.md
    ├── architecture.md              # Diagrams and structure
    └── execution-log.md             # Chronological log
```

**Mandatory Requirements per Phase:**
- Objective
- Task table (ID, Status, Effort, Note)
- Modified files list
- **TEST section with verification tests**
- Acceptance criteria
- Result

### 2. Security & Anti-Manipulation Framework

Added to `CommonValuesAndPrinciples.md`:

- **Prompt Injection Protection**: Detection patterns and response templates
- **Information Security**: What to never disclose or generate
- **Data Handling Principles**: Minimize, no persistence, anonymization
- **Ethical Boundaries**: Clear refusal guidelines
- **Inclusive Language**: Person-first, gender-neutral, culturally sensitive

## Rationale

1. **Modular Plans**: Prevents token compression failures, improves readability, enables parallel work
2. **Security Framework**: Protects against common attack vectors, ensures consistent behavior across all agents
3. **Test Requirements**: Ensures phases are verifiable and complete before moving forward

## Affected Agents

| Agent | Change | Version |
|-------|--------|---------|
| taskmaster-strategic-task-decomposition-master | Added Modular Execution Plan Structure | 1.0.3 |
| davide-project-manager | Added Modular Execution Plan Structure | 1.0.3 |
| CommonValuesAndPrinciples | Added Security & Anti-Manipulation section | N/A |

## Consequences

**Positive:**
- Plans stay manageable and don't cause context compression
- Clear test requirements per phase
- Consistent security posture across all agents
- Better protection against prompt injection attacks

**Negative:**
- Slightly more complex plan structure
- Additional file management for large projects

## Implementation

1. Updated agent files with new sections
2. Added changelog entries to affected agents
3. Created repository-level CLAUDE.md with development guidelines
