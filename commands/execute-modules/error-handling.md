# Execution Error Handling

## Task Failed/Blocked

```
Task ${task_id} failed or blocked.
Status: ${status}
Notes: ${notes}

Options:
1. Skip and continue (mark skipped)
2. Retry task
3. Stop execution

Choose [1/2/3]:
```

## Build Failed

```
Thor validation FAILED after wave ${wave_id}

Errors:
${build_errors}

Options:
1. Fix and retry wave
2. Continue anyway (NOT RECOMMENDED)
3. Stop execution

Choose [1/2/3]:
```

## Thor Validation Failure

**If Thor Fails**:
1. DO NOT proceed to next wave
2. Identify which F-xx failed
3. Re-execute failed tasks OR fix manually
4. Re-run Thor until PASS

## Recovery Strategies

| Failure Type | Strategy |
|--------------|----------|
| Task timeout | Retry with sonnet (complexity escalation) |
| Test failure | Fix implementation, re-run tests |
| Build error | Check TypeScript/lint errors first |
| Thor rejection | Read actual files, verify changes exist |

## Anti-Failure Rules

- Never skip approval gate
- Never fake timestamps (only executor sets them)
- Never mark done without F-xx check
- **NEVER bypass Thor** - learned from Plan 085 failure
- **NEVER trust executor reports** - always verify with Thor + file reads
- Use db_wave_id (numeric) not wave_code ("W1")
- **Wave completion = Thor PASS** - not just executor reports
