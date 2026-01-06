# File Size Limits

**Rule**: Max 250 lines/file. No exceptions without user approval.

**Why**: Token optimization, maintainability, parallel execution, review efficiency.

## Enforcement
- Check line count BEFORE writing any file
- If file would exceed 250 lines → split first
- Applies to: code (.js, .ts, .py), docs (.md), configs

## Split Strategies
- **Code**: Extract modules, split by responsibility, barrel exports (index.ts)
- **Docs**: Main doc + linked detail files
- **Large functions**: Extract to separate module

## Exceptions (must document why)
- Generated configs (package.json, tsconfig.json)
- Vendor/third-party files
- Auto-generated (migrations, schemas)

## Validation
```bash
# Find violations
find . -name "*.js" -o -name "*.ts" -o -name "*.md" | xargs wc -l | awk '$1 > 250'
```

Files >250 without documented exception = REJECTED.
