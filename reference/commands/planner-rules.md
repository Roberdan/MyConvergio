# Planner Rules & Templates

Reference file for planner.md. Contains templates, integrity rules, and model strategy.

---

## Model Strategy (Cost-of-Failure Optimization)

| Phase      | Model                                                | Rationale                                |
| ---------- | ---------------------------------------------------- | ---------------------------------------- |
| Planning   | **opus**                                             | Complex reasoning, architecture (PINNED) |
| Execution  | **sonnet** (default), **opus** when reasoning needed | See decision tree below                  |
| Validation | sonnet                                               | Quality checks, F-xx verification        |
| Thor       | sonnet                                               | ISE compliance, thorough review          |

**Full reference**: [model-strategy.md](../commands/planner-modules/model-strategy.md)

**Model Annotation per Task** (MANDATORY):

```markdown
| Task  | Description                               | F-xx | Model  | Status  |
| ----- | ----------------------------------------- | ---- | ------ | ------- |
| T1-01 | Fix typo in header                        | F-01 | haiku  | pending |
| T1-02 | Add API endpoint (existing pattern)       | F-02 | sonnet | pending |
| T1-03 | Integrate payment + notification services | F-03 | opus   | pending |
```

**Decision tree**:

- String/constant/config only, 1 file → `haiku`
- Clear requirements, existing pattern, 1-3 files → `sonnet`
- Reasoning needed, ambiguous, 4+ files, no pattern → `opus`

**Principle**: Pick based on cost of getting it wrong, not cost of the call.
One failed retry costs more than the model upgrade.

---

## Plan File Template

```markdown
# Piano: {PlanName}

**Created**: DD Mese YYYY, HH:MM CET
**Project**: {project_id} | **Status**: draft|active|completed

## USER REQUEST (verbatim)

> [Copy user's exact words here]

## FUNCTIONAL REQUIREMENTS

| ID   | Requirement       | Wave | Verified |
| ---- | ----------------- | ---- | -------- |
| F-01 | [from user words] | W1   | [ ]      |
| F-02 | [from user words] | W1   | [ ]      |

## WAVE STRUCTURE

W1 (Phase) ──> W2 (Phase) ──> W3 (Phase)

## W1: {PhaseName} ({task_count} tasks)

| Task  | Description | F-xx | Status  |
| ----- | ----------- | ---- | ------- |
| T1-01 | [task]      | F-01 | pending |

## STOP CONDITIONS

- [ ] All F-xx verified [x]
- [ ] Build passes
- [ ] Thor validation passed
```

---

## Thor Enforcement Rules

**Per-Wave Check (MANDATORY)**:

```bash
~/.claude/scripts/plan-db.sh validate {plan_id}
npm run lint && npm run typecheck && npm run build
```

**Thor Rejects Closure When**:

- Any F-xx marked `[ ]` without skip reason
- F-xx marked `[x]` but no verification evidence
- Build/lint/typecheck failed
- Tasks marked done without executor invocation

**Thor Approves Closure When**:

- ALL F-xx marked `[x]` with evidence
- Build passes
- Tests pass for affected code
- Database state consistent

---

## Anti-Failure Rules

1. **Never skip user approval gate** - Wait for explicit "si"/"yes"/"procedi"
2. **Never fake timestamps** - Only executor sets started_at/completed_at
3. **Never mark done without F-xx check** - Verify acceptance criteria
4. **Never bypass Thor** - Wave done = Thor passed
5. **Use db_wave_id not wave_code** - `add-task {numeric_id}` not `add-task W1`

---

## Plan Integrity Rules

**Counter Sync**:

```bash
# After each task completion, verify counts match
# Use wave_id_fk (numeric FK) instead of wave_id string
sqlite3 ~/.claude/data/dashboard.db \
  "SELECT COUNT(*) FROM tasks WHERE wave_id_fk={db_wave_id} AND status='done';"
```

**State Transitions**:

```
pending → in_progress → done|blocked|skipped
```

**Forbidden Transitions**:

- `done → pending` (rollback not allowed)
- `skipped → done` (must re-execute)

---

## DB Quick Reference

```bash
# Create plan
plan-db.sh create {project_id} "{name}"

# Add wave (returns db_wave_id)
plan-db.sh add-wave {plan_id} "W1" "Phase Name"

# Add task (use numeric db_wave_id!)
plan-db.sh add-task {db_wave_id} T1-01 "Description" P1 feature

# Update task status
plan-db.sh update-task {db_task_id} in_progress "notes"
plan-db-safe.sh update-task {db_task_id} done "notes"  # ALWAYS safe for done
plan-db.sh update-task {db_task_id} blocked "notes"

# Validate plan
plan-db.sh validate {plan_id}
```

---

## Parallel Execution (Max 3)

```typescript
// Launch up to 3 executors in parallel for independent tasks
await Promise.all([
  Task({ subagent_type: "task-executor", prompt: "Task T1-01..." }),
  Task({ subagent_type: "task-executor", prompt: "Task T1-02..." }),
  Task({ subagent_type: "task-executor", prompt: "Task T1-03..." }),
]);
```

**Rules**:

- Tasks in same wave can parallelize if independent
- Cross-wave tasks are sequential (dependency)
- Max 3 concurrent executors
