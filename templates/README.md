# State Tracking Templates

Template per gestire lo stato durante task multi-sessione e multi-context window.

## Quando usare

**Multi-session tasks:** Task che richiedono più sessioni di lavoro o context window refresh.

**Complex projects:** Progetti con molti test, feature in sviluppo parallelo, o stato complesso.

## Template disponibili

### tests.json - Structured State

**Usa per:** Test status, schema requirements, structured data

**Best practices:**
- Aggiorna dopo ogni test run
- Track passing/failing/not_started status
- Include error messages per test falliti
- **NON rimuovere test** - potrebbe causare missing functionality

**Esempio:**
```json
{
  "tests": [
    {"id": 1, "name": "auth_flow", "status": "passing"},
    {"id": 2, "name": "user_mgmt", "status": "failing", "error": "401"}
  ],
  "summary": {"total": 200, "passing": 150, "failing": 25}
}
```

### progress.txt - Unstructured Progress

**Usa per:** Progress notes, context generale, decisioni tecniche

**Best practices:**
- Una sessione per sezione
- Track completed, in-progress, next steps
- Documenta decisioni tecniche e motivazioni
- Note su blockers e workaround

**Formato suggerito:**
- Obiettivi sessione
- Completed (✓)
- In Progress (→)
- Next Steps (numbered)
- Technical Decisions
- Blockers
- Notes

## Come usare

### Starting fresh context window

Quando riparti da context window pulito:

1. **Review state files:**
   ```bash
   cat progress.txt tests.json
   ```

2. **Check git logs:**
   ```bash
   git log --oneline -10
   git status
   ```

3. **Run setup script** (se esiste):
   ```bash
   ./init.sh
   ```

4. **Run integration test:**
   - Verifica che tutto funzioni prima di continuare

### Durante il lavoro

1. **Update progress.txt** dopo ogni milestone
2. **Update tests.json** dopo ogni test run
3. **Commit frequentemente** per git state tracking
4. **Create init.sh** se non esiste (setup server, linters, etc.)

### Before context refresh

1. **Save current state** a progress.txt
2. **Update tests.json** con latest results
3. **Commit work** a git
4. **Note next steps** chiaramente

## Git as state tracker

Git fornisce log automatico e restore points:

```bash
# Vedere cosa è stato fatto
git log --oneline --all -20

# Vedere file modificati
git log --name-status -5

# Restore to checkpoint
git checkout <commit>
```

**Best practice:** Commit frequenti con conventional commits

## Multi-context workflow

**Context 1 (Setup):**
- Write tests in tests.json
- Create setup scripts (init.sh)
- Establish framework

**Context 2+ (Iteration):**
- Review progress.txt + tests.json + git logs
- Run setup script
- Continue from last checkpoint
- Update state files as you go

## Note importanti

**Structured (JSON) vs Unstructured (TXT):**
- JSON: test results, schemas, countable metrics
- TXT: progress narrative, decisions, notes

**Incremental progress:**
- Focus on completing small tasks fully
- Don't start new features with uncommitted work
- Verify before moving on

**Test immutability:**
- Never remove tests without explicit approval
- Editing tests can hide bugs
- Better to fix code than modify tests
