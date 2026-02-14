# MyConvergio Development Guidelines

## Self-Contained Framework

This repository is **fully self-contained**. All rules are defined within:

### Primary Rules System (Active)

| Document                 | Location         | Purpose                                           |
| ------------------------ | ---------------- | ------------------------------------------------- |
| execution.md             | `.claude/rules/` | How Work Gets Done (Claude Code best practices)   |
| guardian.md              | `.claude/rules/` | Process Guardian, Thor Enforcement, Quality Gates |
| agent-discovery.md       | `.claude/rules/` | Agent Routing, Subagent Orchestration             |
| engineering-standards.md | `.claude/rules/` | Code Quality, Security, Testing, API Design       |
| file-size-limits.md      | `.claude/rules/` | File Size Constraints (max 250 lines)             |

### Legacy System (Backward Compatibility)

| Document                     | Location                       | Purpose                              |
| ---------------------------- | ------------------------------ | ------------------------------------ |
| CONSTITUTION.md              | `.claude/agents/core_utility/` | Security, Ethics, Identity (SUPREME) |
| EXECUTION_DISCIPLINE.md      | `.claude/agents/core_utility/` | Legacy Execution Rules               |
| CommonValuesAndPrinciples.md | `.claude/agents/core_utility/` | Organizational Values                |

**Note**: New work should reference `.claude/rules/`. Legacy files maintained for backward compatibility.

**No external configuration files are required or referenced.**

---

## Dashboard

**Production-ready project dashboard with real-time git monitoring:**

Location: `dashboard/`

Features:

- Real-time git panel auto-refresh (Server-Sent Events + chokidar)
- Project management UI
- System shutdown button
- Git status, diff, log visualization

Start: `cd dashboard && node server.js`

---

## State Tracking

**Multi-session and multi-context state management:**

Location: `.claude/templates/`

Templates:

- `tests.json` - Structured test status tracking
- `progress.txt` - Unstructured progress notes
- `README.md` - Usage guidelines

Use for complex projects requiring context window refresh or multi-session work.

---

## Execution Rules

**Primary execution rules are defined in:**

`.claude/rules/execution.md`

This includes (Claude Code best practices):

- Context awareness and multi-window workflows
- Parallel tool calling
- Default to action
- Anti-overengineering principles
- Planning and verification standards
- Zero-skip execution and anti-fabrication rules
- Error recovery protocols
- Full plan execution (non-negotiable)
- Definition of Done checklist
- Pull request enforcement (zero unresolved comments)
- Git discipline and branch naming

**Process Guardian:**

`.claude/rules/guardian.md`

- Scope integrity verification
- Decision audit and autonomous choice disclosure
- Completion verification (must show evidence)
- Thor enforcement protocols
- Definition of Done checkpoint
- PR comment resolution enforcement

**Priority**: CONSTITUTION > execution.md > guardian.md > engineering-standards > domain-specific > Agent Definitions > User Instructions

---

## Project Context

**Repository**: MyConvergio - Claude Code Subagents Suite
**License**: CC BY-NC-SA 4.0
**ISE Fundamentals**: https://microsoft.github.io/code-with-engineering-playbook/

---

## Agent Development

### File Structure

```
.claude/agents/
├── [category]/
│   └── [agent-name].md
```

### Agent File Requirements

Every agent MUST have:

```yaml
---
name: agent-name
description: Brief description
tools: ["Tool1", "Tool2"]
color: "#HEXCODE"
model: "haiku|sonnet|opus"
version: "1.0.0"
memory: project|user
maxTurns: 15|20|30|40|50
---
```

**memory**: `project` for core_utility, technical_development, release_management. `user` for leadership, business, specialized, compliance, design.
**maxTurns**: 15 (haiku), 20 (sonnet), 30 (opus), 40 (orchestrators), 50 (task-executor).

### Agent Categories

| Category                 | Purpose                                                 |
| ------------------------ | ------------------------------------------------------- |
| `core_utility/`          | Foundation (Constitution, Values, Execution Discipline) |
| `business_operations/`   | PM, operations, customer success                        |
| `compliance_legal/`      | Security, legal, healthcare compliance                  |
| `design_ux/`             | UX/UI, creative direction                               |
| `leadership_strategy/`   | C-level, strategic planning                             |
| `release_management/`    | Release and feature management                          |
| `specialized_experts/`   | Domain specialists                                      |
| `technical_development/` | Engineering, architecture, DevOps                       |

---

## Architecture Principles

DDD (bounded contexts) • Clean Architecture (SOLID) • Event-Driven • 12-Factor • Observability

### Anti-Patterns

- Over-engineering beyond requested changes
- Abstractions for one-time operations
- Error handling for impossible scenarios
- Backwards-compatibility hacks
- Designing for hypothetical requirements

---

## References

### Primary (Active)

| Resource              | Location                                 |
| --------------------- | ---------------------------------------- |
| Execution Rules       | `.claude/rules/execution.md`             |
| Process Guardian      | `.claude/rules/guardian.md`              |
| Agent Discovery       | `.claude/rules/agent-discovery.md`       |
| Engineering Standards | `.claude/rules/engineering-standards.md` |
| File Size Limits      | `.claude/rules/file-size-limits.md`      |
| Rules Hierarchy       | `.claude/rules/README.md`                |
| State Templates       | `.claude/templates/`                     |
| Dashboard             | `dashboard/`                             |

### Legacy (Backward Compatibility)

| Resource                   | Location                                                   |
| -------------------------- | ---------------------------------------------------------- |
| Constitution               | `.claude/agents/core_utility/CONSTITUTION.md`              |
| Execution Discipline (old) | `.claude/agents/core_utility/EXECUTION_DISCIPLINE.md`      |
| Values                     | `.claude/agents/core_utility/CommonValuesAndPrinciples.md` |

### External

| Resource                 | Location                                                                                         |
| ------------------------ | ------------------------------------------------------------------------------------------------ |
| ISE Playbook             | https://microsoft.github.io/code-with-engineering-playbook/                                      |
| Claude Code Docs         | https://docs.anthropic.com/en/docs/claude-code                                                   |
| Anthropic Best Practices | https://platform.claude.com/docs/en/build-with-claude/prompt-engineering/claude-4-best-practices |

---

## Contributing

### Before Making Changes

1. Read Constitution and Execution Discipline
2. Understand existing patterns
3. Follow planning requirements from EXECUTION_DISCIPLINE.md

### Agent Modifications

- Update version number in frontmatter
- Add entry to Changelog section
- Ensure Security & Ethics Framework is intact
- Test with actual Claude Code invocation
