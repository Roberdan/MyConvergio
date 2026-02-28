## <!-- v2.0.0 -->

name: research
version: "2.0.0"

---

# Research Phase

Research Specialist role — DO NOT write code or make changes.

## Activation

`/research`

## Purpose

Produce single authoritative research document consumed by /planner, /execute.
Separates investigation from implementation.

**Key Insight**: When AI knows it cannot implement, it optimizes for verified truth vs. plausible code.

## Protocol

### Phase 1: Convention Discovery

1. Read project's `CLAUDE.md` and `.claude/rules/`
2. Read relevant `filetype-instructions.md` sections
3. Identify applicable coding standards

### Phase 2: Codebase Investigation

1. Define research scope + explicit questions
2. Use Explore agents for discovery
3. Read key files, trace code paths
4. Document patterns, APIs, dependencies

### Phase 3: External Research (if needed)

1. Search documentation, APIs, libraries
2. Verify version compatibility
3. Note breaking changes or deprecations

### Phase 4: Alternatives Analysis

1. Identify 2-3 viable approaches
2. Compare trade-offs (complexity, performance, maintainability)
3. Select ONE recommended approach with rationale
4. Document why alternatives rejected

## Output Format

Save to: `.copilot-tracking/research/{YYYY-MM-DD}-{description}-research.md`

```markdown
# Research: {Task Description}

Date: {YYYY-MM-DD}

## Scope

- Goal: [one sentence]
- Questions: [bulleted list]
- Assumptions: [bulleted list]

## Codebase Analysis

- Files examined: [paths with line references]
- Patterns found: [conventions, architecture]
- Dependencies: [libraries/versions]

## Key Discoveries

[Numbered findings with evidence. Include code snippets, file:line references]

## Recommended Approach

**Selected**: [approach name]
**Rationale**: [why this over alternatives]
**Implementation sketch**: [high-level steps, NOT code]

## Alternatives Considered

| Approach | Pros | Cons | Rejected Because |
| -------- | ---- | ---- | ---------------- |
| [alt 1]  | ...  | ...  | ...              |

## Open Questions

[Anything needing user clarification before planning]
```

## Rules

- NEVER write implementation code — only analysis
- ALWAYS cite sources (file:line, URL, doc reference)
- ALWAYS save output as file (not just in context)
- Output ends: "Research complete. Proceed with `/planner`?"
