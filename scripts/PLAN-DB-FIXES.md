# plan-db.sh Bug Fixes

## Issues Identified

### 1. SQL Injection Vulnerabilities
Multiple places where user input is not properly quoted, allowing SQL injection:
- Line 205: `INSERT INTO tasks` - values not quoted
- Line 231: `UPDATE tasks SET status` - notes parameter not quoted
- Line 419: `INSERT INTO plan_versions` - validated_by not quoted

**Example vulnerability:**
```bash
plan-db.sh add-task 1 T1 "My'; DROP TABLE tasks; --"
# Becomes: INSERT INTO tasks (..., title) VALUES (..., 'My'; DROP TABLE tasks; --')
# SQL is broken!
```

### 2. Structural Bug: wave_id should be FK, not TEXT
Current structure:
```sql
tasks.wave_id TEXT           -- Stores "W1" (logical ID)
JOIN waves USING (project_id, wave_id TEXT)  -- Composite join
```

Should be:
```sql
tasks.wave_id TEXT              -- Keep for compatibility
tasks.wave_id_fk INTEGER FK     -- New proper FK to waves.id
JOIN waves ON tasks.wave_id_fk = waves.id  -- Simple FK join
```

### 3. Argument Concatenation Issue
When multiple optional arguments are passed, shell expansion can lose arguments.

**Example:**
```bash
plan-db.sh add-wave 1 W1 "Wave 1" --planned-start "2026-01-15" --planned-end "2026-01-20" --depends-on W0
# "$@:5" expands to: --planned-start "2026-01-15" --planned-end "2026-01-20" --depends-on W0
# But if depends_on value contains spaces, it may break
```

## Fixes Required

### Fix 1: Quote all SQL values
Use SQLite proper parameter binding OR quote all values:

```bash
# BEFORE (vulnerable):
sqlite3 "$DB_FILE" "
    INSERT INTO tasks (project_id, wave_id, task_id, title, status, priority, type, assignee)
    VALUES ('$project_id', '$wave_id', '$task_id', '$title', 'pending', '$priority', '$type', '$assignee');
"

# AFTER (safe - quote all user input):
sqlite3 "$DB_FILE" "
    INSERT INTO tasks (project_id, wave_id, task_id, title, status, priority, type, assignee)
    VALUES ('$project_id', '$wave_id', '$task_id', '${title//\'/\'\'}', 'pending', '$priority', '$type', '${assignee//\'/\'\'}');
"
# Note: Use ${var//\'/\'\'} to escape single quotes in SQL strings
```

OR (better) use SQLite prepared statements:
```bash
# Not easily done in shell, but would look like:
sqlite3 "$DB_FILE" "
    INSERT INTO tasks (project_id, wave_id, task_id, title, status, priority, type, assignee)
    VALUES (?, ?, ?, ?, 'pending', ?, ?, ?);
" -- "$project_id" "$wave_id" "$task_id" "$title" "$priority" "$type" "$assignee"
```

### Fix 2: Create migration for wave_id FK
Run the migration script FIRST:
```bash
~/.claude/scripts/migrate-wave-fk.sh
```

This adds `tasks.wave_id_fk INTEGER FK` to properly reference `waves.id`.

### Fix 3: Update plan-db.sh to use wave_id_fk
After migration, update all task queries to join on wave_id_fk:

```bash
# BEFORE:
UPDATE waves SET tasks_done = tasks_done + 1
WHERE project_id = '$project_id' AND wave_id = '$wave_id_text';

# AFTER:
UPDATE waves SET tasks_done = tasks_done + 1
WHERE id = (SELECT wave_id_fk FROM tasks WHERE id = $task_id);
```

### Fix 4: Safe parameter handling
Helper function to escape SQL strings:

```bash
sql_escape() {
    local input="$1"
    # Replace single quotes with doubled single quotes (SQL standard)
    echo "${input//\'/\'\'}"
}

# Usage:
local safe_title=$(sql_escape "$title")
sqlite3 "$DB_FILE" "
    INSERT INTO tasks (..., title, ...)
    VALUES (..., '$safe_title', ...);
"
```

## Implementation Steps

1. **Run the migration FIRST:**
   ```bash
   ~/.claude/scripts/migrate-wave-fk.sh
   ```

2. **Backup current plan-db.sh:**
   ```bash
   cp ~/.claude/scripts/plan-db.sh ~/.claude/scripts/plan-db.sh.backup
   ```

3. **Apply fixes to plan-db.sh:**
   - Add `sql_escape()` helper function at top
   - Update all `INSERT` statements to quote values properly
   - Update all `UPDATE` statements to quote values properly
   - Update joins to use `wave_id_fk` where available
   - Test thoroughly!

4. **Test the fixed script:**
   ```bash
   # Test with problematic characters
   plan-db.sh create test-proj "My Project"
   plan-db.sh add-wave 1 W1 "Wave with, comma"
   plan-db.sh add-task 1 T1 "Task with 'quotes'"
   plan-db.sh validate 1
   ```

## Risk Assessment

⚠️ **CRITICAL**: SQL injection is possible with current code
⚠️ **HIGH**: Structural mismatch (wave_id TEXT vs FK) breaks referential integrity
⚠️ **MEDIUM**: Argument parsing could lose values with special characters

## Timeline

- Pre-migration tests: 5 min
- Run migration: 1 min
- Update plan-db.sh: 20-30 min
- Testing: 10-15 min
- Total: ~1 hour
