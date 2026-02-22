<!-- v2.0.0 | 15 Feb 2026 | Token-optimized per ADR 0009 -->

# Tool Preferences

## Priority Order (fastest → slowest, least → most tokens)

1. **LSP** (if available) → go-to-definition, find-references, hover for type info
2. **Dedicated tools** → Glob, Grep, Read, Edit, Write
3. **Subagents** → Explore for open-ended search, task-executor for plan tasks
4. **Bash** → ONLY for git, npm, build commands

## Tool Mapping

| Task                   | Use                             | NOT                     |
| ---------------------- | ------------------------------- | ----------------------- |
| Find file by name      | Glob                            | `find`, `ls`            |
| Search code content    | Grep                            | `grep`, `rg`            |
| Read file              | Read                            | `cat`, `head`, `tail`   |
| Edit file              | Edit                            | `sed`, `awk`            |
| Create file            | Write                           | `echo >`, `cat <<EOF`   |
| Navigate to definition | LSP go-to-definition            | Grep for class/function |
| Find all usages        | LSP find-references             | Grep for symbol         |
| Explore codebase       | `Task(subagent_type='Explore')` | Multiple grep/glob      |
| Run project audit      | `project-audit.sh --project-root $(pwd)` | Manual audit scripts |

## Parallel Execution

- **ALWAYS** parallelize independent tool calls in single message
- **ALWAYS** parallelize independent subagent launches
- **NEVER** wait for result if not needed for next call
- Example: Read 3 files → single message with 3 Read calls

## Subagent Routing

| Scenario                        | Subagent                          |
| ------------------------------- | --------------------------------- |
| Open-ended codebase exploration | `Explore` (quick/medium/thorough) |
| Execute plan task               | `task-executor`                   |
| Create execution plan           | `strategic-planner`               |
| Quality validation              | `thor-quality-assurance-guardian` |
| Multi-step research             | `general-purpose`                 |

## Shell Safety (zsh)

- **ALWAYS single-quote** URLs with `?` or `&` in Bash (zsh glob expansion)
- **NEVER use `!=` in double-quoted sqlite3/SQL** — zsh expands `!` in double quotes (`\!=`). Use `<>` or `NOT IN (...)` instead. Hook `warn-bash-antipatterns.sh` blocks this.
- For PRs on forks, use REST API (`gh api 'repos/{owner}/{repo}/pulls'`) not `gh pr list` (GraphQL numbering mismatch)
- All `pr-ops.sh`, `pr-digest.sh`, `collect-github.sh` already use REST API

## CI/Build Commands (Token Optimization)

**MANDATORY**: Use project scripts instead of raw commands when available.

| Raw command (AVOID)      | Optimized alternative             |
| ------------------------ | --------------------------------- |
| `npm run lint`           | `./scripts/ci-summary.sh --lint`  |
| `npm run typecheck`      | `./scripts/ci-summary.sh --types` |
| `npm run build`          | `./scripts/ci-summary.sh --build` |
| `npm run test:unit`      | `./scripts/ci-summary.sh --unit`  |
| `npx playwright test`    | `./scripts/ci-summary.sh --e2e`   |
| A11y/axe-core tests      | `./scripts/ci-summary.sh --a11y`  |
| `gh run view --log`      | `./scripts/ci-check.sh <id>`      |
| `git diff file \| head`  | `git diff --stat` + Read tool     |
| `git log` (verbose)      | `git log --oneline -N`            |
| `gh pr view` (verbose)   | `pr-ops.sh status <pr>`           |
| `gh api .../comments -f` | `pr-ops.sh reply <pr> <id> "msg"` |
| `gh pr merge`            | `pr-ops.sh merge <pr>`            |
| Pattern check (pre-PR)   | `code-pattern-check.sh --json`    |
| Copilot review digest    | `copilot-review-digest.sh <pr>`   |

Hook `prefer-ci-summary.sh` enforces this automatically.

## Script Discovery

`script-versions.sh` — auto-generated index of all `~/.claude/scripts/` with versions and categories.

| Command                                | Purpose                                         |
| -------------------------------------- | ----------------------------------------------- |
| `script-versions.sh`                   | Grouped table (82 scripts, 14 categories)       |
| `script-versions.sh --json`            | JSON for programmatic use                       |
| `script-versions.sh --stale`           | Scripts missing version header                  |
| `script-versions.sh --category <name>` | Filter by category                              |
| `agent-versions.sh`                    | Agent/component versions (markdown frontmatter) |
