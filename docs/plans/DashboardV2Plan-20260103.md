# DashboardV2Plan - Real Metrics & Data Integration

**Created**: 3 Gennaio 2026, 23:45 CET | **Target**: Dashboard con dati reali | **Metodo**: VERIFICA BRUTALE

---

## CHECKPOINT LOG

| Timestamp | Agent | Task | Status | Notes |
|-----------|-------|------|--------|-------|
| 22:33 CET | Claude-Opus | T-01 to T-03 | DONE | Phase 1 completata |
| 22:35 CET | Claude-Opus | T-04 to T-08 | DONE | Phase 2 completata |
| 22:38 CET | Claude-Opus | T-09 to T-13 | DONE | Phase 3 completata |
| 22:42 CET | Claude-Opus | T-14 to T-17 | DONE | Phase 4 completata |
| 22:48 CET | Claude-Opus | T-18 to T-21 | DONE | Phase 5 completata |

**Last Good State**: Piano eseguito completamente
**Resume Instructions**: Piano completato, nessun resume necessario

---

## OBIETTIVO

Trasformare la dashboard da mockup statico a strumento di monitoring reale:
- Dati git/GitHub live
- Metriche calcolate dinamicamente
- Drill-down navigabile (Plan > Wave > Task)
- Persistenza storica in SQLite
- Zero bottoni fake

---

## FUNCTIONAL REQUIREMENTS

| ID | Requisito Funzionale | Criterio di Accettazione | Verificato |
|----|---------------------|-------------------------|------------|
| F-01 | Metriche reali git | `collect-git.sh` ritorna JSON valido con status, log, branches | [x] |
| F-02 | GitHub Actions status | `collect-github.sh` ritorna workflow runs status | [x] |
| F-03 | Technical debt scan | `collect-debt.sh` trova TODO/FIXME con count | [x] |
| F-04 | SQLite persistence | Insert/query funziona su dashboard.db | [x] |
| F-05 | Drill-down Wave | Click su wave mostra tasks di quella wave | [x] |
| F-06 | Drill-down Task | Click su task mostra dettagli task | [x] |
| F-07 | Git tree espandibile | Mostra file modified/uncommitted | [x] |
| F-08 | Timestamp refresh | Ogni sezione mostra "last updated" | [x] |
| F-09 | No fake buttons | Rimossi Assign, chart tools, mock actions | [x] |
| F-10 | Plan.json v2 | Schema supporta tutti i nuovi campi | [x] |

---

## PHASE 1: DATA SCHEMA & DATABASE

| Status | ID | Task | Assignee | Files |
|:------:|-----|------|----------|-------|
| DONE | T-01 | Definire plan.json v2 schema con waves.tasks[], timing, debt | Claude-Opus | `~/.claude/dashboard/SCHEMA-V2.md` |
| DONE | T-02 | Creare SQLite schema (projects, snapshots, metrics) | Claude-Opus | `~/.claude/scripts/init-db.sql` |
| DONE | T-03 | Script init database | Claude-Opus | `~/.claude/scripts/init-dashboard-db.sh` |

## PHASE 2: DATA COLLECTORS

| Status | ID | Task | Assignee | Files |
|:------:|-----|------|----------|-------|
| DONE | T-04 | collect-git.sh (status, log, diff, branches, uncommitted) | Claude-Opus | `~/.claude/scripts/collect-git.sh` |
| DONE | T-05 | collect-github.sh (actions, PR, comments, copilot reviews) | Claude-Opus | `~/.claude/scripts/collect-github.sh` |
| DONE | T-06 | collect-tests.sh (parse playwright/jest JSON output) | Claude-Opus | `~/.claude/scripts/collect-tests.sh` |
| DONE | T-07 | collect-debt.sh (grep TODO/FIXME/DEFERRED/SKIPPED) | Claude-Opus | `~/.claude/scripts/collect-debt.sh` |
| DONE | T-08 | collect-quality.sh (engineering fundamentals checklist) | Claude-Opus | `~/.claude/scripts/collect-quality.sh` |

## PHASE 3: UI OVERHAUL (NO CSS)

| Status | ID | Task | Assignee | Files |
|:------:|-----|------|----------|-------|
| DONE | T-09 | Rimuovere bottoni fake (Assign, chart tools) da HTML | Claude-Opus | `~/.claude/dashboard/dashboard.html` |
| DONE | T-10 | Aggiungere drill-down UI (wave list > task list) | Claude-Opus | `~/.claude/dashboard/dashboard.html` |
| DONE | T-11 | Aggiungere git tree espandibile | Claude-Opus | `~/.claude/dashboard/dashboard.html` |
| DONE | T-12 | Aggiungere "last updated" timestamps per sezione | Claude-Opus | `~/.claude/dashboard/dashboard.html` |
| DONE | T-13 | Aggiungere refresh buttons per sezioni manuali | Claude-Opus | `~/.claude/dashboard/dashboard.html` |

## PHASE 4: JAVASCRIPT LOGIC

| Status | ID | Task | Assignee | Files |
|:------:|-----|------|----------|-------|
| DONE | T-14 | Implementare drill-down logic (state machine Plan/Wave/Task) | Claude-Opus | `~/.claude/dashboard/dashboard.js` |
| DONE | T-15 | Implementare git tree toggle/expand | Claude-Opus | `~/.claude/dashboard/dashboard.js` |
| DONE | T-16 | Implementare refresh con fetch collectors output | Claude-Opus | `~/.claude/dashboard/dashboard.js` |
| DONE | T-17 | Aggiornare renderChart per dati wave/task reali | Claude-Opus | `~/.claude/dashboard/dashboard.js` |

## PHASE 5: INTEGRATION

| Status | ID | Task | Assignee | Files |
|:------:|-----|------|----------|-------|
| DONE | T-18 | Master collector script (chiama tutti + merge JSON) | Claude-Opus | `~/.claude/scripts/collect-all.sh` |
| DONE | T-19 | Aggiornare planner.md per output plan.json v2 | Claude-Opus | `~/.claude/commands/planner.md` |
| DONE | T-20 | Creare sample plan.json v2 con dati reali questo piano | Claude-Opus | `~/.claude/dashboard/plan.json` |
| DONE | T-21 | Test end-to-end: collector > plan.json > dashboard | Claude-Opus | - |

---

## THOR APPROVAL SECTION

**Status**: APPROVED
**Validated**: 10 / 10 functional requirements
**Gates Passed**: 4 / 4

- [x] F-01 to F-04: Data layer working
- [x] F-05 to F-08: UI navigation working
- [x] F-09 to F-10: Cleanup complete
- [x] End-to-end test passes

**Thor Signature**: Claude-Opus 4.5 **Date**: 4 Gennaio 2026, 00:50 CET

---

## PROGRESS

| Phase | Done/Total |
|-------|------------|
| 1 - Schema | 3/3 |
| 2 - Collectors | 5/5 |
| 3 - UI | 5/5 |
| 4 - JS Logic | 4/4 |
| 5 - Integration | 4/4 |
| **TOTAL** | 21/21 |

---

## DELIVERABLES

### Files Created

| File | Purpose |
|------|---------|
| `~/.claude/dashboard/SCHEMA-V2.md` | Plan.json V2 schema documentation |
| `~/.claude/scripts/init-db.sql` | SQLite schema |
| `~/.claude/scripts/init-dashboard-db.sh` | Database init script |
| `~/.claude/scripts/collect-git.sh` | Git collector |
| `~/.claude/scripts/collect-github.sh` | GitHub collector |
| `~/.claude/scripts/collect-tests.sh` | Test results collector |
| `~/.claude/scripts/collect-debt.sh` | Tech debt collector |
| `~/.claude/scripts/collect-quality.sh` | Quality checklist collector |
| `~/.claude/scripts/collect-all.sh` | Master collector |
| `~/.claude/data/dashboard.db` | SQLite database |

### Files Modified

| File | Changes |
|------|---------|
| `~/.claude/dashboard/dashboard.html` | Added drill-down UI, git tree, tabs, removed fake buttons |
| `~/.claude/dashboard/dashboard.js` | Added drill-down logic, tab switching, git tree, debt panel |
| `~/.claude/dashboard/plan.json` | Updated to V2 schema with waves.tasks[] |
| `~/.claude/commands/planner.md` | Updated Dashboard section for V2 |

---

## USAGE

### Start Dashboard
```bash
npx live-server ~/.claude/dashboard --port=31415 --no-browser &
open http://127.0.0.1:31415
```

### Update with Collectors
```bash
~/.claude/scripts/collect-all.sh /path/to/project --update-plan
```

### Init Database
```bash
~/.claude/scripts/init-dashboard-db.sh --force
```
