# Plan DB Migration & Bug Fixes Guide

## Critical Issues Fixed

### 1. SQL Injection Vulnerabilities ⚠️ CRITICAL

**Problem**: User input not properly escaped in SQL queries

```bash
# Example attack:
plan-db.sh add-task 1 T1 "My'; DROP TABLE tasks; --"
# Would execute: INSERT INTO tasks (...) VALUES (..., 'My'; DROP TABLE tasks; --')
```

**Impact**: Complete database corruption, data loss, unauthorized access

**Solution**: All string parameters now escaped using `sql_escape()` function

### 2. Structural Bug: wave_id should be FK, not TEXT

**Problem**:

- `tasks.wave_id` is TEXT ("W1") instead of INTEGER FK to `waves.id`
- Requires complex composite key joins: `WHERE project_id = X AND wave_id = 'W1'`
- No referential integrity enforcement

**Solution**:

- New column: `tasks.wave_id_fk INTEGER` with FK constraint
- Simple joins: `WHERE wave_id_fk = waves.id`
- Proper referential integrity

### 3. Argument Concatenation Issues

**Problem**: Multiple optional arguments could be lost or concatenated incorrectly
**Solution**: Fixed shell parameter handling and quoting

---

## Implementation Steps

### Step 1: Backup Database

```bash
cp ~/.claude/data/dashboard.db ~/.claude/data/dashboard.db.backup.$(date +%s)
```

### Step 2: Run Migration

```bash
~/.claude/scripts/migrate-wave-fk.sh
```

**What it does**:

1. Adds `wave_id_fk` column to tasks table
2. Populates FK values from existing data
3. Adds proper FK constraints
4. Recreates indexes
5. Validates data integrity

**Expected output**:

```
✓ Backup created: ~/.claude/data/dashboard.db.backup.xxxx
✓ Column added
✓ Updated XXXX rows with wave_id_fk
✓ FK constraint added
✓ Indexes recreated
✓ FK integrity validated
```

### Step 3: Update plan-db.sh

The migration adds `wave_id_fk` column, but plan-db.sh still uses old `wave_id TEXT` queries.

**Critical functions to update** (see plan-db-fixed-functions.sh for complete implementations):

```bash
# Add to top of plan-db.sh:
sql_escape() {
    local input="$1"
    printf '%s\n' "${input//\'/\'\'}"
}
```

Replace these functions in plan-db.sh:

- `cmd_add_task()` - Use `wave_id_fk` instead of composite join
- `cmd_update_task()` - Use FK-based lookups
- `cmd_add_wave()` - Escape `$name` parameter
- `cmd_create()` - Escape `$name` parameter
- `cmd_validate()` - Use FK queries, escape `$validated_by`
- `cmd_sync()` - Use FK-based counter updates

See `~/.claude/scripts/plan-db-fixed-functions.sh` for complete implementations.

### Step 4: Test Fixed Script

```bash
# Test with problematic characters
plan-db.sh create test-proj "My Project"
plan-db.sh add-wave 1 W1 "Wave with, comma"
plan-db.sh add-task 1 T1 "Task with 'quotes'"
plan-db.sh validate 1

# These should not crash or corrupt data!
```

---

## Key Changes After Migration

### Before Migration

```sql
-- Query tasks for a wave (composite key):
SELECT * FROM tasks
WHERE project_id = 'proj-1' AND wave_id = 'W1'

-- Vulnerable code:
sqlite3 "$DB_FILE" "INSERT INTO tasks (..., title) VALUES (..., '$title')"
```

### After Migration

```sql
-- Query tasks for a wave (FK):
SELECT * FROM tasks
WHERE wave_id_fk = 42

-- Safe code:
local safe_title=$(sql_escape "$title")
sqlite3 "$DB_FILE" "INSERT INTO tasks (..., title) VALUES (..., '$safe_title')"
```

---

## Rollback Plan (if needed)

If something goes wrong:

```bash
# Restore from backup
cp ~/.claude/data/dashboard.db.backup.XXXX ~/.claude/data/dashboard.db

# Then re-run migration after fixing plan-db.sh
~/.claude/scripts/migrate-wave-fk.sh
```

---

## Validation After Migration

Run Thor validation:

```bash
# On any existing plan
plan-db.sh validate <plan_id>

# Should show 0 errors if migration successful
```

Check FK integrity:

```bash
sqlite3 ~/.claude/data/dashboard.db "
    SELECT COUNT(*) FROM tasks
    WHERE wave_id_fk IS NULL OR
    NOT EXISTS (SELECT 1 FROM waves WHERE id = tasks.wave_id_fk);
"
# Should return: 0
```

---

## Files Reference

| File                         | Purpose                               |
| ---------------------------- | ------------------------------------- |
| `migrate-wave-fk.sh`         | Database schema migration (RUN FIRST) |
| `plan-db-fixed-functions.sh` | Corrected function implementations    |
| `PLAN-DB-FIXES.md`           | Detailed technical analysis           |
| `MIGRATION-GUIDE.md`         | This guide (you are here)             |

---

## Timeline

- Backup: 1 min
- Migration: 1 min
- Update plan-db.sh: 20-30 min
- Testing: 10-15 min
- **Total: ~1 hour**

---

## Security Assessment After Fixes

| Issue                 | Before           | After                 |
| --------------------- | ---------------- | --------------------- |
| SQL Injection         | CRITICAL ⚠️      | SAFE ✓                |
| Referential Integrity | BROKEN (text FK) | PROPER (integer FK) ✓ |
| Argument Handling     | UNSAFE           | SAFE ✓                |
| Validation Queries    | COMPLEX          | SIMPLE ✓              |

---

## Questions?

1. **"Can I upgrade without downtime?"**
   - Yes, migration is backward compatible. Old queries still work.
   - Plan-db.sh can use either `wave_id` (text) or `wave_id_fk` (FK).
   - Update functions gradually.

2. **"What if I have orphaned tasks?"**
   - Migration script reports orphans (tasks with invalid wave references).
   - These have `wave_id_fk = NULL`.
   - Run cleanup before deploying to production:
     ```bash
     sqlite3 ~/.claude/data/dashboard.db "
       DELETE FROM tasks WHERE wave_id_fk IS NULL;
     "
     ```

3. **"How do I verify it worked?"**
   - Run: `~/.claude/scripts/migrate-wave-fk.sh` again
   - Should report: "Migration already applied (wave_id_fk column exists)"
   - Run: `plan-db.sh validate <plan_id>`
   - Should show: "VALIDATION PASSED: 0 errors"

---

## Next Steps

1. ✓ Read this guide completely
2. → Back up database
3. → Run migrate-wave-fk.sh
4. → Review plan-db-fixed-functions.sh
5. → Update plan-db.sh functions
6. → Test with examples above
7. → Deploy and monitor

**Start with:**

```bash
~/.claude/scripts/migrate-wave-fk.sh
```
