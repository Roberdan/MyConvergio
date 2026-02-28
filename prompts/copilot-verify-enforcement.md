# Verification: Thor Enforcement System

Run ALL verification checks below. Report results as a table.
This system MUST work identically regardless of the LLM model (GPT, Gemini, Mistral, Llama, Ollama, Claude, etc.)

## Step 1: Run the test suite

```bash
export PATH="$HOME/.claude/scripts:$PATH"
bash ~/.claude/scripts/tests/test-thor-enforcement.sh
```

**Expected**: 53/53 PASS. If ANY test fails, report the failure and STOP.

## Step 2: Verify trigger exists and is correct

```bash
sqlite3 ~/.claude/data/dashboard.db "SELECT name, sql FROM sqlite_master WHERE type='trigger' ORDER BY name;"
```

**Expected triggers** (4 total):

1. `enforce_thor_done` — blocks `done` without Thor validator
2. `task_done_counter` — increments counters on done
3. `task_undone_counter` — decrements counters when leaving done
4. `wave_auto_complete` — transitions wave to `merging` (NOT `done`)

## Step 3: Attempt to bypass (must ALL fail)

```bash
DB=~/.claude/data/dashboard.db

# Create test task
TASK_ID=$(sqlite3 "$DB" "INSERT INTO tasks (project_id, wave_id, task_id, title, status, plan_id, wave_id_fk) VALUES ('test-verify', 'W-test', 'T-verify', 'Verify test', 'in_progress', (SELECT id FROM plans LIMIT 1), (SELECT id FROM waves LIMIT 1)); SELECT last_insert_rowid();")

# Bypass attempt 1: direct done (must BLOCK)
sqlite3 "$DB" "UPDATE tasks SET status = 'done' WHERE id = $TASK_ID;" 2>&1
# Expected: BLOCKED error

# Bypass attempt 2: done with fake validator (must BLOCK)
sqlite3 "$DB" "UPDATE tasks SET status = 'done', validated_by = 'copilot-agent' WHERE id = $TASK_ID;" 2>&1
# Expected: BLOCKED error (not in whitelist)

# Bypass attempt 3: done without going through submitted (must BLOCK)
sqlite3 "$DB" "UPDATE tasks SET status = 'done', validated_by = 'thor' WHERE id = $TASK_ID;" 2>&1
# Expected: BLOCKED (OLD.status is not submitted)

# Correct flow: in_progress → submitted → done with Thor
sqlite3 "$DB" "UPDATE tasks SET status = 'submitted' WHERE id = $TASK_ID;"
sqlite3 "$DB" "UPDATE tasks SET status = 'done', validated_at = datetime('now'), validated_by = 'thor' WHERE id = $TASK_ID AND status = 'submitted';"
sqlite3 "$DB" "SELECT status, validated_by FROM tasks WHERE id = $TASK_ID;"
# Expected: done|thor

# Cleanup
sqlite3 "$DB" "DELETE FROM tasks WHERE id = $TASK_ID;"
```

## Step 4: Verify Copilot integration files

```bash
# copilot-task-prompt.sh must mention 'submitted' not expect 'done'
grep -c "submitted" ~/.claude/scripts/copilot-task-prompt.sh
# Expected: >= 2

# copilot-worker.sh must track submitted status
grep -c 'FINAL_STATUS="submitted"' ~/.claude/scripts/copilot-worker.sh
# Expected: >= 1

# copilot-worker.sh must call validate-task with thor
grep -c "validate-task.*thor" ~/.claude/scripts/copilot-worker.sh
# Expected: >= 1

# validate.agent.md must document submitted flow
grep -c "submitted" ~/.claude/copilot-agents/validate.agent.md
# Expected: >= 3

# thor-validate.sh must handle submitted tasks
grep -c "submitted" ~/.claude/scripts/thor-validate.sh
# Expected: >= 3

# execute.agent.md must document submitted flow
grep -c "submitted" ~/.claude/copilot-agents/execute.agent.md
# Expected: >= 5
```

## Step 5: Cross-platform sanity

```bash
# SQLite version (must be 3.x, trigger support guaranteed since 3.6.18)
sqlite3 --version

# WAL mode active
sqlite3 ~/.claude/data/dashboard.db "PRAGMA journal_mode;"
# Expected: wal

# Busy timeout configured in db_query wrapper
grep "timeout" ~/.claude/scripts/lib/plan-db-core.sh
# Expected: .timeout 5000
```

## Step 6: File lock system

```bash
# Acquire + release cycle
file-lock.sh acquire /tmp/test-copilot-verify task-verify --timeout 2
file-lock.sh check /tmp/test-copilot-verify
file-lock.sh release /tmp/test-copilot-verify task-verify
rm -f /tmp/test-copilot-verify
```

## Report format

| Check               | Result      | Notes |
| ------------------- | ----------- | ----- |
| Test suite          | 53/53 PASS  |       |
| Triggers (4)        | OK/FAIL     |       |
| Bypass attempts (3) | ALL BLOCKED |       |
| Correct flow        | done\|thor  |       |
| Copilot files (6)   | ALL OK      |       |
| SQLite version      | X.Y.Z       |       |
| WAL mode            | wal         |       |
| File lock           | OK          |       |

**If ALL checks pass**: System is model-agnostic and enforcement works regardless of LLM.
**If ANY check fails**: Report the specific failure with full error output.
