# ADR-009: Skills & Rules System

| Field | Value |
|-------|-------|
| **Status** | Accepted |
| **Date** | 2025-12-15 |
| **Deciders** | Roberto, AI Team |

## Context

Claude Code supports two additional configuration mechanisms beyond agents:
- **Rules**: Path-specific guidelines that apply to all operations in a directory
- **Skills**: Reusable workflows that can be invoked by Claude Code

## Decision

Create `.claude/rules/` and `.claude/skills/` directories with:

### Rules (6 files)
- `code-style.md` - ESLint, Prettier, PEP8, Black standards
- `security-requirements.md` - OWASP Top 10, input validation
- `testing-standards.md` - Unit tests, integration tests, 80% coverage
- `documentation-standards.md` - JSDoc, README, ADRs
- `api-development.md` - RESTful conventions, error handling
- `ethical-guidelines.md` - Privacy, WCAG 2.1 AA, inclusive language

### Skills (8 files)
- `code-review/SKILL.md` - Based on rex-code-reviewer
- `debugging/SKILL.md` - Based on dario-debugger
- `architecture/SKILL.md` - Based on baccio-tech-architect
- `security-audit/SKILL.md` - Based on luca-security-expert
- `performance/SKILL.md` - Based on otto-performance-optimizer
- `strategic-analysis/SKILL.md` - Based on domik-mckinsey
- `release-management/SKILL.md` - Based on app-release-manager
- `project-management/SKILL.md` - Based on davide-project-manager

## Rationale

1. Rules provide consistent standards across all operations
2. Skills allow invoking expert workflows without calling specific agents
3. Reduces token usage by centralizing common patterns
4. Makes agent expertise available through lightweight invocations

## Consequences

**Positive:**
- Consistent standards
- Reusable workflows
- Token efficiency

**Negative:**
- More files to maintain
- Need to keep skills in sync with agent updates

## Implementation

- Created `.claude/rules/` with 6 rule files
- Created `.claude/skills/` with 8 skill directories
- Updated `.gitignore` to track these directories
- Documented in CLAUDE.md
