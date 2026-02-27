## <!-- v1.0.0 -->

name: check
version: "1.0.0"

---

# Session Check — Quick Recap

`/check` produces a brief summary of the current session state.

## Data Source

```bash
export PATH="$HOME/.claude/scripts:$PATH"
SESSION_DATA=$(session-check.sh 2>/dev/null || echo '{}')
```

## Interpretation Rules

Read the JSON from `session-check.sh` and present a **brief Italian summary** with these sections:

### 1. Git Status

One line: branch, clean/dirty, uncommitted count, unpushed count.
Example: `**Git**: main, pulito, 0 uncommitted, 0 unpushed`
If dirty: `**Git**: main, 3 file non committati, 2 commit non pushati`

### 2. Piani Attivi

For each plan in `plans` array with status `doing`/`todo`:

- Name, progress (tasks done/total), any stuck waves
- If no active plans: "Nessun piano attivo"

### 3. PR Aperte

For each PR in `open_prs`:

- Number, title, CI status
- If none: "Nessuna PR aperta"

### 4. Dimenticanze

List every item in `forgotten` array as a warning.
If empty: skip section.

### 5. Prossimi Passi

List every item in `next_steps` array.
If empty: "Nulla da fare"

## Output Format

Keep it **concise** — max 15 lines total. No tables, no headers larger than `###`.
Use bold for section labels. Warnings use `WARN:` prefix.

## Example Output

```
**Git**: feature/auth, 2 file non committati, 1 commit non pushato
**Piani**: Plan 253 "WaveWorktree-SessionCheck" — 7/9 task (doing)
**PR**: #42 "Fix auth flow" — CI passing
**WARN**: 2 file non committati nel working directory
**WARN**: Wave W1 bloccata in merging (plan 250)
**Prossimi passi**: Completare 2 task rimanenti in plan 253, pushare commit
```
