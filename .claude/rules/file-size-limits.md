# File Size Limits

**Max 250 lines/file** - Check BEFORE writing. Split if exceeds. No exceptions without approval.

## Enforcement
- ALL code files (any language), docs (.md), configs
- Exceeds? Extract modules, split by responsibility, barrel exports

## Exceptions (document why)
Generated configs, vendor files, auto-generated (migrations, schemas)

## Validation
```bash
find . -name "*.js" -o -name "*.ts" -o -name "*.md" | xargs wc -l | awk '$1 > 250'
```
