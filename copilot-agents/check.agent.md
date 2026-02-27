---
name: check
description: Session status check — brief recap of git state, active plans, open PRs, forgotten items, and next steps.
tools: ["read", "search", "execute"]
model: gpt-5.1-codex-mini
version: "1.0.0"
---

# Session Check — Quick Recap

`@check` produces a brief summary of the current session state.

## Data Source

```bash
export PATH="$HOME/.claude/scripts:$PATH"
SESSION_DATA=$(session-check.sh 2>/dev/null || echo '{}')
```

## Interpretation Rules

Read the JSON from `session-check.sh` and present a **brief Italian summary**:

1. **Git Status**: branch, clean/dirty, uncommitted count, unpushed count
2. **Piani Attivi**: name, progress, stuck waves (or "Nessun piano attivo")
3. **PR Aperte**: number, title, CI status (or "Nessuna PR aperta")
4. **Dimenticanze**: list `forgotten` items as `WARN:` (skip if empty)
5. **Prossimi Passi**: list `next_steps` items (or "Nulla da fare")

Keep output **concise** — max 15 lines. No tables.

## Example Output

```
**Git**: feature/auth, 2 file non committati, 1 commit non pushato
**Piani**: Plan 253 "WaveWorktree-SessionCheck" — 7/9 task (doing)
**PR**: #42 "Fix auth flow" — CI passing
**WARN**: 2 file non committati nel working directory
**Prossimi passi**: Completare 2 task rimanenti, pushare commit
```
