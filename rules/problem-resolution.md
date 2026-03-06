<!-- v1.0.0 -->

# Problem Resolution Protocol (NON-NEGOTIABLE)

When encountering errors, failures, or unexpected behavior, agents MUST follow this search order BEFORE attempting fixes.

## Mandatory Search Order

| Step | Source                    | Command/Action                                                        | Skip if             |
| ---- | ------------------------- | --------------------------------------------------------------------- | ------------------- |
| 1    | Repo `TROUBLESHOOTING.md` | `Read TROUBLESHOOTING.md` (root)                                      | File doesn't exist  |
| 2    | Repo ADRs                 | `Glob("docs/adr/*.md")` + `Grep(pattern="keyword", path="docs/adr/")` | No `/docs/adr/` dir |
| 3    | Global KB                 | `plan-db.sh kb-search "error keywords" --limit 5`                     | Empty results       |
| 4    | Global troubleshooting    | `Read ~/.claude/data/troubleshooting/` (if exists)                    | Dir doesn't exist   |
| 5    | Web/Explore               | `WebSearch` or `Task(subagent_type="Explore")`                        | Steps 1-4 resolved  |

## Rules

- **NEVER attempt a fix without completing steps 1-2 first** — repo docs contain project-specific solutions
- **Cite source**: When applying a fix from docs, reference it: "Per ADR-0014: use single quotes for zsh"
- **Update on resolution**: After solving a NEW issue, add it to `TROUBLESHOOTING.md` (or create PR to add it)
- **KB write**: For reusable solutions: `plan-db.sh kb-write troubleshooting "title" "solution" --tags '["error-type"]'`

## Anti-Patterns

| WRONG                              | RIGHT                                                          |
| ---------------------------------- | -------------------------------------------------------------- |
| Immediately try Stack Overflow fix | Check repo TROUBLESHOOTING.md first                            |
| Guess based on error message       | Search ADRs for prior decisions on this area                   |
| Retry same approach 3 times        | Check `plan-db.sh get-failures $PROJECT_ID` for prior failures |
| Fix without documenting            | Add to TROUBLESHOOTING.md after resolution                     |
