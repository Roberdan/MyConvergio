# Rules

Supplementary rules auto-loaded on every Claude session. Core rules are in `~/.claude/CLAUDE.md`.

## Active Rules (auto-loaded)

| File | Lines | Purpose |
|------|-------|---------|
| execution.md | 42 | PR rules, git, verification, phase isolation |
| guardian.md | 41 | Thor enforcement, F-xx, dispute protocol |
| agent-discovery.md | 25 | Agent routing + maturity lifecycle |
| engineering-standards.md | 35 | Code/security/testing |
| file-size-limits.md | 24 | Max 250 lines/file enforcement |
| filetype-instructions.md | 64 | Context-aware conventions per file type |
| maturity-lifecycle.md | 40 | Agent/skill lifecycle stages |

**Total**: ~271 lines (~680 tokens)

## Hierarchy

1. **CLAUDE.md** (master) - Core rules, language, workflow, pre-closure checklist
2. **rules/*.md** (supplementary) - Details that extend core rules

## Detailed Reference (NOT auto-loaded)

Full versions at `~/.claude/reference/detailed/`:
- api-development.md, code-style.md, documentation-standards.md
- ethical-guidelines.md, security-requirements.md, testing-standards.md

Access on-demand: `Read ~/.claude/reference/detailed/{file}.md`
