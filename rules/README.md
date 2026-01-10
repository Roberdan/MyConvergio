# Rules

Supplementary rules auto-loaded on every Claude session. Core rules are in `~/.claude/CLAUDE.md`.

## Active Rules (auto-loaded)

| File | Lines | Purpose |
|------|-------|---------|
| execution.md | 34 | PR rules, git, verification definitions |
| guardian.md | 41 | Thor enforcement, F-xx, dispute protocol |
| agent-discovery.md | 22 | Agent routing |
| engineering-standards.md | 35 | Code/security/testing |
| file-size-limits.md | 24 | Max 250 lines/file |

**Total**: ~156 lines (~390 tokens)

## Hierarchy

1. **CLAUDE.md** (master) - Core rules, language, workflow, pre-closure checklist
2. **rules/*.md** (supplementary) - Details that extend core rules

## Detailed Reference (NOT auto-loaded)

Full versions at `~/.claude/reference/detailed/`:
- api-development.md, code-style.md, documentation-standards.md
- ethical-guidelines.md, security-requirements.md, testing-standards.md

Access on-demand: `Read ~/.claude/reference/detailed/{file}.md`
