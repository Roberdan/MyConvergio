# Tool Preferences (Context Optimization)

## Priority Order (fastest → slowest, least → most tokens)
1. **LSP** (if available) → go-to-definition, find-references, hover for type info
2. **Dedicated tools** → Glob, Grep, Read, Edit, Write
3. **Subagents** → Explore for open-ended search, task-executor for plan tasks
4. **Bash** → ONLY for git, npm, build commands

## Tool Mapping

| Task | Use | NOT |
|------|-----|-----|
| Find file by name | Glob | `find`, `ls` |
| Search code content | Grep | `grep`, `rg` |
| Read file | Read | `cat`, `head`, `tail` |
| Edit file | Edit | `sed`, `awk` |
| Create file | Write | `echo >`, `cat <<EOF` |
| Navigate to definition | LSP go-to-definition | Grep for class/function |
| Find all usages | LSP find-references | Grep for symbol |
| Explore codebase | `Task(subagent_type='Explore')` | Multiple grep/glob |

## LSP Usage (when available)

```
# Instead of: Grep for "class MyComponent" then Read file
# Do: LSP go-to-definition on MyComponent usage

# Instead of: Grep for all usages of a function
# Do: LSP find-references on function name
```

## Parallel Execution

- **ALWAYS** parallelize independent tool calls in single message
- **ALWAYS** parallelize independent subagent launches
- **NEVER** wait for result if not needed for next call
- Example: Read 3 files → single message with 3 Read calls

## Subagent Routing

| Scenario | Subagent |
|----------|----------|
| Open-ended codebase exploration | `Explore` (quick/medium/thorough) |
| Execute plan task | `task-executor` |
| Create execution plan | `strategic-planner` |
| Quality validation | `thor-quality-assurance-guardian` |
| Multi-step research | `general-purpose` |

## CI/Build Commands (Token Optimization)

**MANDATORY**: Use project scripts instead of raw commands when available.

| Raw command (AVOID) | Optimized alternative |
|---------------------|----------------------|
| `npm run lint` | `./scripts/ci-summary.sh --lint` |
| `npm run typecheck` | `./scripts/ci-summary.sh --types` |
| `npm run build` | `./scripts/ci-summary.sh --build` |
| `npm run test:unit` | `./scripts/ci-summary.sh --unit` |
| `npx playwright test` | `./scripts/ci-summary.sh --e2e` |
| `npm run test` (E2E) | `./scripts/ci-summary.sh --e2e` |
| A11y/axe-core tests | `./scripts/ci-summary.sh --a11y` |
| `gh run view --log` | `./scripts/ci-check.sh <id>` |
| `git diff file \| head` | `git diff --stat` + Read tool |
| `git log` (verbose) | `git log --oneline -N` |

Hook `prefer-ci-summary.sh` enforces this automatically.
