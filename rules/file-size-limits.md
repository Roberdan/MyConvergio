# File Size Limits

**Rule**: Max 300 lines/file. No exceptions without approval.

**Why**: Token optimization, maintainability, parallel execution, review efficiency.

## Split Strategies

**Plans**: Main tracker (overview + phase links) + separate phase files
**Code**: Extract modules, split by responsibility, barrel exports (index.ts)
**Agents**: Core file (<300) + reference file for examples/edge cases

## Exceptions (must document why)
- Generated configs (package.json, tsconfig.json)
- Vendor/third-party files
- Auto-generated (migrations, schemas)
- Framework-required single-file exports

## Validation
```bash
find . -name "*.md" -o -name "*.ts" -o -name "*.tsx" | xargs wc -l | awk '$1 > 300'
```

Thor validates. Files >300 without exception = REJECTED.
