# File Size Limits

**Max 250 lines/file** - MANDATORY. Hook blocks Write/Edit if exceeded.

## Automatic Enforcement
- Hook: `~/.claude/hooks/enforce-line-limit.sh`
- Runs on: Write, Edit operations
- Action: BLOCKS operation if file > 250 lines
- No workarounds. Split first, then write.

## Scope
- ALL code files (any language), docs (.md), configs
- Exceeds? Extract modules, split by responsibility, barrel exports

## Exceptions (auto-skipped by hook)
- Lock files: `*.lock`, `package-lock.json`, `yarn.lock`
- Generated: `node_modules/`, `vendor/`, `dist/`, `build/`
- Databases: `*.db`, `*.sqlite`

## Manual Check
```bash
find . -name "*.js" -o -name "*.ts" -o -name "*.md" | xargs wc -l | awk '$1 > 250'
```
