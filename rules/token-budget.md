# Token Budget Enforcement

## Per-Type Limits

| Instruction Type | Max Tokens | Max Bytes |
|-----------------|-----------|-----------|
| CLAUDE.md | 4000 | 16KB |
| AGENTS.md | 4000 | 16KB |
| rules/*.md | 2000 | 8KB |
| skills/*/SKILL.md | 1500 | 6KB |
| agents/*/*.md | 1500 | 6KB |
| copilot-agents/*.md | 1500 | 6KB |

## Enforcement

Pre-commit hook `token-audit.sh` checks byte sizes. Over-budget = WARN (soft gate).

## Reduction Strategies

1. Tables over prose
2. One-line rules (pipe-separated)
3. `@reference/` includes over inline content
4. No preambles, no filler
5. Code examples: max 5 lines each
