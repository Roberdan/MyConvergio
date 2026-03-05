# Prompt

Extract structured F-xx requirements from a user request without executing implementation.

## Usage

`@prompt` or `/prompt`

## Protocol

1. Clarification gate first: stop and ask at least one clarification round for ambiguities.
2. Extract explicit and implicit requirements as `F-xx`; keep `said` values in exact user wording.
3. Write `.copilot-tracking/prompt-{NNN}.json` with objective, requirements, scope, and stop conditions.
4. Ensure each `verify` entry is machine-checkable and scope exclusions only contain user-excluded items.
5. Ask for confirmation that nothing is missing, then hand off to `@planner`.

Full specification: `commands/prompt.md`
