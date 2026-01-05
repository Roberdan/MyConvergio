# Rules Hierarchy

This directory contains the consolidated rules system for MyConvergio. Rules are organized by scope and priority.

## Architecture

**Two rule systems coexist:**

1. **New System (Primary)**: `.claude/rules/` - Consolidated, token-efficient rules
2. **Legacy System**: `.claude/agents/core_utility/` - EXECUTION_DISCIPLINE.md, CONSTITUTION.md

**Use new system for active development. Legacy maintained for backward compatibility.**

---

## Rule Categories

### Global Execution Rules

**execution.md** - How work gets done
- Planning and verification standards
- Context awareness and multi-window workflows
- Parallel tool calling
- Anti-overengineering principles
- Default to action
- Full plan execution (non-negotiable)
- Definition of Done checklist
- Pull request enforcement

**guardian.md** - Process guardian and quality gates
- Scope integrity verification
- Decision audit
- Completion verification
- Thor enforcement protocols
- Definition of Done checkpoint
- Pull request comment resolution

**agent-discovery.md** - Agent routing and delegation
- Agent catalog by domain
- Subagent orchestration patterns
- Skills catalog
- When and how to delegate

### Technical Standards

**engineering-standards.md** - Code quality and best practices
- Code style (TS/JS, Python, General)
- Security (OWASP Top 10)
- Testing (coverage, unit, integration)
- API design (REST conventions)
- Documentation standards
- Ethics and accessibility

**file-size-limits.md** - File size constraints
- Max 300 lines per file
- Split strategies
- Exceptions and validation

### Domain-Specific Rules

**api-development.md** - API-specific guidelines
**code-style.md** - Language-specific conventions
**documentation-standards.md** - Documentation requirements
**ethical-guidelines.md** - Ethical considerations
**security-requirements.md** - Security protocols
**testing-standards.md** - Testing methodologies

---

## Rule Priority

```
CONSTITUTION > EXECUTION_DISCIPLINE > execution.md > guardian.md >
engineering-standards > domain-specific > user instructions
```

**Note:** execution.md and EXECUTION_DISCIPLINE.md overlap. EXECUTION_DISCIPLINE.md is legacy. Use execution.md for new work.

---

## Usage

### For Agents
When invoked, check:
1. execution.md (primary execution rules)
2. guardian.md (quality gates)
3. engineering-standards.md (technical standards)
4. Domain-specific rules as needed

### For Developers
When contributing:
1. Read CONSTITUTION.md (if referencing legacy system)
2. Read execution.md (primary execution rules)
3. Follow engineering-standards.md
4. Apply guardian.md verification

---

## Recent Updates

**5 Gen 2026**: Synced with ~/.claude
- Updated execution.md with Anthropic Claude 4.5 best practices
- Added context awareness and multi-window workflows
- Enhanced parallel tool calling guidelines
- Added anti-overengineering principles
- Added Definition of Done enforcement
- Added PR comment resolution rules
- Updated agent-discovery.md with subagent orchestration
- Added guardian.md for Thor enforcement
- Added file-size-limits.md

**15 Dic 2025**: MyConvergio-specific rules
- api-development.md
- documentation-standards.md
- ethical-guidelines.md
- security-requirements.md
- testing-standards.md

---

## Migration Notes

**From EXECUTION_DISCIPLINE.md to execution.md:**
- Content is similar but execution.md is more concise
- execution.md includes latest Anthropic best practices
- Both files maintained during transition period
- New work should reference execution.md

**Consolidation strategy:**
- Keep both systems for 1-2 months
- Gradually migrate agents to rules/ references
- Eventually deprecate EXECUTION_DISCIPLINE.md
