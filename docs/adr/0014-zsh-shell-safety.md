# ADR 0014: zsh Shell Safety Constraints

**Status**: Accepted
**Date**: 21 Feb 2026
**Plan**: 189

## Context

The `.claude` ecosystem runs on macOS with zsh as default shell (since macOS 10.15 Catalina). zsh has subtle incompatibilities with bash that cause script failures:

- **`!=` operator**: zsh treats `!=` as glob pattern match, not string inequality
- **Unquoted variables**: zsh's word splitting differs from bash
- **Pipe failures**: `set -o pipefail` not enforced in hooks causes silent failures
- **Array indexing**: zsh arrays start at 1, bash at 0

Real incidents:
1. `worktree-guard.sh` failed on `[[ "$A" != "$B" ]]` (treated as glob)
2. `plan-db.sh drift-check` pipe to `head -1` silently ignored grep errors
3. Git hooks allowed uncommitted code due to missing `set -euo pipefail`

## Decision

### Mandatory Shell Header (All Scripts)

```bash
#!/usr/bin/env bash
set -euo pipefail
```

| Flag | Purpose | Failure Mode Without It |
|------|---------|--------------------------|
| `-e` | Exit on command failure | Silent continuation after errors |
| `-u` | Exit on undefined variable | Empty string substitution causes logic bugs |
| `-o pipefail` | Fail if any pipe command fails | `grep error | head -1` succeeds even if grep fails |

### Forbidden Patterns (zsh Incompatible)

| Anti-Pattern | Why Forbidden | Safe Alternative |
|--------------|---------------|------------------|
| `[[ $A != $B ]]` | zsh glob matching | `[[ "$A" != "$B" ]]` (quoted) |
| `cmd \| head -1` in hooks | Masks upstream failures | `OUTPUT=$(cmd); echo "$OUTPUT" \| head -1` |
| `array[0]` without test | zsh 1-indexed | Test with `[[ ${#array[@]} -gt 0 ]]` first |
| `function foo() { ... }` | Bash-specific syntax | `foo() { ... }` (POSIX) |
| `let x++` | Non-POSIX | `x=$((x + 1))` |

### Variable Quoting Rules

| Context | Rule | Example |
|---------|------|---------|
| **Conditionals** | Always quote | `[[ "$VAR" == "value" ]]` |
| **Assignments** | Quote if spaces possible | `PATH="$HOME/.claude/scripts"` |
| **Command args** | Quote unless intentional split | `echo "$MESSAGE"` |
| **Array expansion** | Quote with `@` | `"${FILES[@]}"` |

### Git Hook Safety (CRITICAL)

Pre-commit, pre-push, post-merge hooks MUST:

```bash
#!/usr/bin/env bash
set -euo pipefail  # ← MANDATORY

# BAD (silent failure):
git status | grep -q "modified" && exit 1

# GOOD (explicit capture):
STATUS=$(git status)
if echo "$STATUS" | grep -q "modified"; then
  exit 1
fi
```

Rationale: Hooks that silently fail allow broken commits/pushes.

### Pipe-to-head/tail/grep in Hooks FORBIDDEN

| Forbidden | Reason | Safe Alternative |
|-----------|--------|------------------|
| `git diff \| head -n 1` | grep/awk failure masked | `git diff > /tmp/out; head -n 1 /tmp/out` |
| `plan-db.sh list \| grep X` | plan-db.sh error ignored | `OUTPUT=$(plan-db.sh list); echo "$OUTPUT" \| grep X` |

### Testing for zsh Compatibility

```bash
# Run in zsh to detect issues:
zsh -c 'source scripts/my-script.sh'

# Common errors:
# - "no matches found: !=" → missing quotes
# - "command not found: function" → bash-specific syntax
```

## Consequences

### Positive
- **Reliability**: Scripts fail fast on errors instead of silently continuing
- **Portability**: Works on macOS (zsh), Linux (bash), CI (bash)
- **Debuggability**: Clear error messages with line numbers (`set -e`)
- **Audit compliance**: No silent failures in pre-commit/pre-push hooks

### Negative
- **Verbosity**: More explicit quoting and variable captures
- **Learning curve**: Team must understand pipefail and quoting rules
- **Strictness**: `set -u` fails on typos (but this is good!)

### Migration Checklist

- [ ] All scripts start with `#!/usr/bin/env bash` + `set -euo pipefail`
- [ ] All `[[ $A != $B ]]` replaced with `[[ "$A" != "$B" ]]`
- [ ] Git hooks use explicit variable capture (no direct pipes to head/grep)
- [ ] Arrays quoted: `"${ARRAY[@]}"`
- [ ] Test in both bash and zsh: `zsh -c 'source script.sh'`

### Linter Integration

`.shellcheckrc` (enforces rules):

```
enable=all
severity=warning
external-sources=true

# SC2086: Quote variables
# SC2015: Use explicit if statements
# SC2164: cd without error check
```

Run: `shellcheck scripts/**/*.sh hooks/**/*`

## File Impact Table

| File | Impact |
|------|--------|
| scripts/*.sh | Add `set -euo pipefail`, quote all variables |
| hooks/* | Add explicit variable capture, no pipes-to-head |
| tests/shell-safety-test.sh | Validate quoting and pipefail |
| .shellcheckrc | Enable strictness checks |
| Makefile | Add `make shellcheck` target |

## References

- zsh documentation: `man zshoptions`
- ShellCheck: https://www.shellcheck.net/
- POSIX shell spec: https://pubs.opengroup.org/onlinepubs/9699919799/
- ADR 0006: System Stability & Crash Prevention (error handling)
