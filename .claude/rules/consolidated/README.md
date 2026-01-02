# Consolidated Rules

This directory contains **consolidated** engineering rules that combine multiple individual rule files into single, context-optimized documents.

## Why Consolidated Rules?

- **Reduced Context**: ~93% less tokens (52KB → 3.6KB)
- **Faster Loading**: Single file read vs 6 separate files
- **Same Coverage**: All essential standards maintained

## Available Files

### engineering-standards.md (~3.6KB)
Consolidates:
- code-style.md
- security-requirements.md
- testing-standards.md
- api-development.md
- documentation-standards.md
- ethical-guidelines.md

## Usage

**For minimal context installations:**
```bash
# Use consolidated rules (recommended for 8GB RAM systems)
cp .claude/rules/consolidated/engineering-standards.md ~/.claude/rules/
```

**For detailed reference:**
```bash
# Use full detailed rules (6 separate files)
cp .claude/rules/*.md ~/.claude/rules/
```

## Comparison

| Mode | Files | Size | Context Tokens |
|------|-------|------|----------------|
| Consolidated | 1 | ~3.6KB | ~900 |
| Detailed | 6 | ~52KB | ~13,000 |

Choose consolidated for:
- Systems with <16GB RAM
- Projects with many agents active
- Fast context loading priority

Choose detailed for:
- Deep reference documentation
- Team onboarding
- Comprehensive examples
