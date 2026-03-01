# Execute

Execute plan tasks with inline TDD + independent Thor validation.

## Usage

`@execute {plan_id}` or `/execute {plan_id}`

## Protocol (per task)

```
1. plan-db.sh update-task {db_id} in_progress "Started"
2. TDD: write failing test → implement → pass (inline edit)
3. Verify: unit tests + typecheck + task verify commands
4. plan-db-safe.sh update-task {db_id} done "Summary"
   → Guards: time, git-diff, verify commands → status: submitted
5. @validate handoff (NEVER self-validate — see execute.agent.md §Anti-Self-Validation)
   → plan-db.sh validate-task {db_id} {plan_id} thor (called by @validate ONLY)
6. Confirm: status=done, validated_at NOT NULL
```

## Wave completion

```
plan-db.sh validate-wave {wave_db_id}
```

## Status chain (enforced by SQLite trigger)

```
pending → in_progress → submitted (plan-db-safe.sh) → done (validate-task ONLY)
```

Full spec: `.claude/copilot-agents/execute.agent.md`
