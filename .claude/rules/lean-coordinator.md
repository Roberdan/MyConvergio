<!-- v1.0.0 -->

# Lean Coordinator Protocol

During plan execution, the coordinator MUST minimize context consumption. Compaction mid-wave = state loss = stalled plans.

## Coordinator Budget

| Action | Token cost | Allowed? |
|---|---|---|
| Launch task-executor | ~200 | YES — core function |
| Read Agent result summary | ~500 | YES — brief only |
| Update plan-db | ~300 | YES — mandatory |
| Read project files to verify | ~2000+ | **NO** — delegate to Thor |
| Read task output transcript | ~5000+ | **NO** — summary is enough |
| Grep/Glob project codebase | ~1000+ | **NO** — delegate to executor |
| Multiple sequential DB queries | ~500/each | MINIMIZE — batch in one call |

## Rules (NON-NEGOTIABLE)

1. **NEVER Read project files** during execution. Task-executor reads+writes. Thor validates. Coordinator dispatches.
2. **NEVER read `/private/tmp/` transcript files**. The Agent tool returns a summary — use ONLY that.
3. **After task completes**: (a) checkpoint, (b) update DB, (c) launch Thor or next task. Three steps, nothing more.
4. **Batch DB operations**: Use `plan-checkpoint.sh save <id>` (one call) instead of multiple sqlite3 queries.
5. **Parallel launches**: Launch ALL independent tasks in ONE message with multiple Agent tool calls.
6. **Max 4 tasks per wave**: Planner MUST split waves with >4 tasks. Coordinator context cannot survive 6+ task cycles.

## Checkpoint Cadence (MANDATORY)

| Event | Action |
|---|---|
| After every task-executor completes | `plan-checkpoint.sh save <plan_id>` |
| Before launching >2 parallel tasks | `plan-checkpoint.sh save <plan_id>` |
| PreCompact hook (automatic) | `preserve-context.sh` → `plan-checkpoint.sh save-auto` |

## Post-Compaction Recovery

After compaction, the coordinator MUST:
1. Read checkpoint: `plan-checkpoint.sh restore <plan_id>` (or check MEMORY.md)
2. Verify: `plan-db.sh execution-tree <plan_id>`
3. Resume from last known state — do NOT re-read files or re-verify completed work
4. Trust task-executor + Thor results — they ran in isolated contexts

## Anti-Patterns (VIOLATION)

- Reading files "to understand what the executor did" — the summary tells you
- Running pytest in coordinator "to double-check" — Thor does this
- Grep'ing codebase "to see if task was wired correctly" — that's Thor Gate 2b
- Reading CLAUDE.md/rules mid-execution — they're in context from session start
