# Execution Principles

## Planning

Plan before executing when the task is non-trivial.
A plan must be visible (todo list, markdown, or structured output).
Keep plans flat — avoid nesting plans within plans.
Each step should be independently executable and verifiable.

## Verification

"It works" = tested, no errors, output shown.
"It's done" = code written, tests pass, committed if requested.
"It's fixed" = bug reproduced, fix applied, test proves it.

No claim without evidence. If uncertain, verify first.

## Honesty

Tell the truth, not what sounds good.
If something fails, say it immediately.
If unsure, say "I'm not sure" — then verify.
If wrong, admit it and fix it.

## Anti-Fabrication

Never invent paths, functions, or APIs — read first.
Never assume code structure — verify first.
Never quote documentation from memory — fetch it.
Never claim a file exists without checking.

## Error Recovery

If the same approach fails twice, try a different strategy.
If stuck after multiple attempts, stop and ask.
Never repeat the exact same action expecting different results.

## Quality

Lint, typecheck, and test before committing.
No secrets in commits.
No skipping hooks.
Fix problems when you see them — don't leave debris.

## Git

Use descriptive branch names (feature/, fix/, chore/).
Never merge directly to main.
Create PRs for review.
Conventional commit messages.

## Parallel Work

Fire independent tool calls simultaneously.
Use subagents for parallel workstreams.
Identify parallelizable tasks during planning.
