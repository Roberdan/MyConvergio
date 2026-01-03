# DashboardV2Plan - Real Metrics & Data Integration

**Created**: 3 Gennaio 2026, 23:45 CET | **Target**: Dashboard con dati reali | **Metodo**: VERIFICA BRUTALE

---

## CHECKPOINT LOG

| Timestamp | Agent | Task | Status | Notes |
|-----------|-------|------|--------|-------|
| - | - | - | - | Piano creato |

**Last Good State**: Piano iniziale
**Resume Instructions**: Leggi questo file, riprendi da ultimo task incompleto

---

## OBIETTIVO

Trasformare la dashboard da mockup statico a strumento di monitoring reale:
- Dati git/GitHub live
- Metriche calcolate dinamicamente
- Drill-down navigabile (Plan → Wave → Task)
- Persistenza storica in SQLite
- Zero bottoni fake

---

## RUOLI CLAUDE

| Claude | Ruolo | Task | Model |
|--------|-------|------|-------|
| CLAUDE 1 | COORDINATORE | Crea piano, monitora, verifica | opus |
| CLAUDE 2 | DATA LAYER | T-01 to T-08 (Schema + Collectors) | haiku |
| CLAUDE 3 | UI LAYER | T-09 to T-16 (HTML/JS updates) | haiku |

---

## REGOLE (TUTTI I CLAUDE)

1. Leggi TUTTO il piano prima di iniziare
2. Per ogni task: implementa → verifica → **AGGIORNA CHECKPOINT LOG** → marca done
3. **NON TOCCARE CSS** - styling gia stabile
4. NON "FATTO" senza checkpoint aggiornato
5. Se crash/blocco: scrivi stato nel CHECKPOINT LOG prima di morire
6. **CONTINUOUS EXECUTION**: Completa TUTTI i task assegnati senza fermarti

---

## FUNCTIONAL REQUIREMENTS

| ID | Requisito Funzionale | Criterio di Accettazione | Verificato |
|----|---------------------|-------------------------|------------|
| F-01 | Metriche reali git | `collect-git.sh` ritorna JSON valido con status, log, branches | [ ] |
| F-02 | GitHub Actions status | `collect-github.sh` ritorna workflow runs status | [ ] |
| F-03 | Technical debt scan | `collect-debt.sh` trova TODO/FIXME con count | [ ] |
| F-04 | SQLite persistence | Insert/query funziona su dashboard.db | [ ] |
| F-05 | Drill-down Wave | Click su wave mostra tasks di quella wave | [ ] |
| F-06 | Drill-down Task | Click su task mostra dettagli task | [ ] |
| F-07 | Git tree espandibile | Mostra file modified/uncommitted | [ ] |
| F-08 | Timestamp refresh | Ogni sezione mostra "last updated" | [ ] |
| F-09 | No fake buttons | Rimossi Assign, chart tools, mock actions | [ ] |
| F-10 | Plan.json v2 | Schema supporta tutti i nuovi campi | [ ] |

---

## PHASE 1: DATA SCHEMA & DATABASE

| Status | ID | Task | Assignee | Files |
|:------:|-----|------|----------|-------|
| ⬜ | T-01 | Definire plan.json v2 schema con waves.tasks[], timing, debt | CLAUDE 2 | `~/.claude/dashboard/SCHEMA-V2.md` |
| ⬜ | T-02 | Creare SQLite schema (projects, snapshots, metrics) | CLAUDE 2 | `~/.claude/scripts/init-db.sql` |
| ⬜ | T-03 | Script init database | CLAUDE 2 | `~/.claude/scripts/init-dashboard-db.sh` |

## PHASE 2: DATA COLLECTORS

| Status | ID | Task | Assignee | Files |
|:------:|-----|------|----------|-------|
| ⬜ | T-04 | collect-git.sh (status, log, diff, branches, uncommitted) | CLAUDE 2 | `~/.claude/scripts/collect-git.sh` |
| ⬜ | T-05 | collect-github.sh (actions, PR, comments, copilot reviews) | CLAUDE 2 | `~/.claude/scripts/collect-github.sh` |
| ⬜ | T-06 | collect-tests.sh (parse playwright/jest JSON output) | CLAUDE 2 | `~/.claude/scripts/collect-tests.sh` |
| ⬜ | T-07 | collect-debt.sh (grep TODO/FIXME/DEFERRED/SKIPPED) | CLAUDE 2 | `~/.claude/scripts/collect-debt.sh` |
| ⬜ | T-08 | collect-quality.sh (engineering fundamentals checklist) | CLAUDE 2 | `~/.claude/scripts/collect-quality.sh` |

## PHASE 3: UI OVERHAUL (NO CSS)

| Status | ID | Task | Assignee | Files |
|:------:|-----|------|----------|-------|
| ⬜ | T-09 | Rimuovere bottoni fake (Assign, chart tools) da HTML | CLAUDE 3 | `~/.claude/dashboard/dashboard.html` |
| ⬜ | T-10 | Aggiungere drill-down UI (wave list → task list) | CLAUDE 3 | `~/.claude/dashboard/dashboard.html` |
| ⬜ | T-11 | Aggiungere git tree espandibile | CLAUDE 3 | `~/.claude/dashboard/dashboard.html` |
| ⬜ | T-12 | Aggiungere "last updated" timestamps per sezione | CLAUDE 3 | `~/.claude/dashboard/dashboard.html` |
| ⬜ | T-13 | Aggiungere refresh buttons per sezioni manuali | CLAUDE 3 | `~/.claude/dashboard/dashboard.html` |

## PHASE 4: JAVASCRIPT LOGIC

| Status | ID | Task | Assignee | Files |
|:------:|-----|------|----------|-------|
| ⬜ | T-14 | Implementare drill-down logic (state machine Plan/Wave/Task) | CLAUDE 3 | `~/.claude/dashboard/dashboard.js` |
| ⬜ | T-15 | Implementare git tree toggle/expand | CLAUDE 3 | `~/.claude/dashboard/dashboard.js` |
| ⬜ | T-16 | Implementare refresh con fetch collectors output | CLAUDE 3 | `~/.claude/dashboard/dashboard.js` |
| ⬜ | T-17 | Aggiornare renderChart per dati wave/task reali | CLAUDE 3 | `~/.claude/dashboard/dashboard.js` |

## PHASE 5: INTEGRATION

| Status | ID | Task | Assignee | Files |
|:------:|-----|------|----------|-------|
| ⬜ | T-18 | Master collector script (chiama tutti + merge JSON) | CLAUDE 2 | `~/.claude/scripts/collect-all.sh` |
| ⬜ | T-19 | Aggiornare planner.md per output plan.json v2 | CLAUDE 2 | `~/.claude/commands/planner.md` |
| ⬜ | T-20 | Creare sample plan.json v2 con dati reali questo piano | CLAUDE 2 | `~/.claude/dashboard/plan.json` |
| ⬜ | T-21 | Test end-to-end: collector → plan.json → dashboard | BOTH | - |

---

## THOR APPROVAL SECTION

**Status**: PENDING
**Validated**: 0 / 10 functional requirements
**Gates Passed**: 0 / 4

- [ ] F-01 to F-04: Data layer working
- [ ] F-05 to F-08: UI navigation working
- [ ] F-09 to F-10: Cleanup complete
- [ ] End-to-end test passes

**Thor Signature**: _____________ **Date**: _______

---

## PROGRESS

| Phase | Done/Total |
|-------|------------|
| 1 - Schema | 0/3 |
| 2 - Collectors | 0/5 |
| 3 - UI | 0/5 |
| 4 - JS Logic | 0/4 |
| 5 - Integration | 0/4 |
| **TOTAL** | 0/21 |

---

## TECHNICAL NOTES

### SQLite Schema (preview)
```sql
CREATE TABLE projects (
  id TEXT PRIMARY KEY,
  name TEXT,
  path TEXT,
  created_at DATETIME
);

CREATE TABLE snapshots (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  project_id TEXT,
  plan_json TEXT,
  captured_at DATETIME,
  FOREIGN KEY (project_id) REFERENCES projects(id)
);

CREATE TABLE metrics_history (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  project_id TEXT,
  metric_name TEXT,
  metric_value REAL,
  recorded_at DATETIME
);
```

### Collector Output Format
Ogni collector produce JSON su stdout:
```json
{
  "collector": "git",
  "timestamp": "2026-01-03T23:45:00+01:00",
  "data": { ... }
}
```

### Engineering Fundamentals Checklist
- [ ] Tests exist (unit/integration/e2e)
- [ ] Test coverage > 80%
- [ ] Accessibility (WCAG 2.1 AA)
- [ ] Security (no secrets, input validation)
- [ ] Documentation (README, API docs)
- [ ] Error handling
- [ ] Logging
- [ ] Performance (no N+1, lazy loading)

---

## DASHBOARD UPDATE PROTOCOL

Quando planner crea/aggiorna piano:
1. Genera plan.json v2 nella root del progetto
2. Esegue `~/.claude/scripts/collect-all.sh [project-path]`
3. Output viene merged in plan.json
4. Dashboard legge plan.json aggiornato

---

## FILE STRUCTURE

```
~/.claude/
├── dashboard/
│   ├── dashboard.html    (UI)
│   ├── dashboard.css     (styling - NON TOCCARE)
│   ├── dashboard.js      (logic)
│   ├── plan.json         (data source)
│   └── SCHEMA-V2.md      (documentation)
├── scripts/
│   ├── collect-git.sh
│   ├── collect-github.sh
│   ├── collect-tests.sh
│   ├── collect-debt.sh
│   ├── collect-quality.sh
│   ├── collect-all.sh
│   ├── init-db.sql
│   └── init-dashboard-db.sh
├── data/
│   └── dashboard.db      (SQLite)
└── docs/plans/
    └── DashboardV2Plan-20260103.md
```
