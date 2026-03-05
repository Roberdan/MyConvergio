# Check

Produce a quick session recap from `session-check.sh` output.

## Usage

`@check` or `/check`

## Protocol

1. Run `session-check.sh` and parse returned JSON.
2. Return a concise Italian recap (max 15 lines) with:
   - Git status (branch, clean/dirty, uncommitted, unpushed)
   - Active plans progress
   - Open PR status
   - Forgotten items as `WARN:` lines
   - Next steps
3. If sections are empty, use the fallback text defined by the command contract.

Full specification: `commands/check.md`
