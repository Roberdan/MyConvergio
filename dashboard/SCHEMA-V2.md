# Plan.json Schema V2

> Archived reference: dashboard and agents now consume the SQLite database as the single source of truth (see PLANNER-ARCHITECTURE.md). Use this schema only for documentation or exports.

**Version**: 2.0 | **Updated**: 3 Gennaio 2026, 23:50 CET

## Overview

Schema completo per plan.json con supporto per:
- Drill-down Wave > Task
- Technical debt tracking
- Git tree espandibile
- Metriche real-time dai collectors

---

## Root Structure

```typescript
interface PlanV2 {
  meta: Meta;
  metrics: Metrics;
  bugs: Bugs;
  github: GitHub;
  contributors: Contributor[];
  timeline: Timeline;
  waves: Wave[];           // Extended con tasks[]
  alerts: Alert[];
  git: Git;                // Extended con files modificati
  debt: TechnicalDebt;     // NEW
  quality: QualityChecks;  // NEW
  files: FileRefs;
  collectors: CollectorStatus;  // NEW
}
```

---

## Meta

```typescript
interface Meta {
  project: string;      // Nome progetto
  plan: string;         // Nome piano corrente
  version: string;      // Schema version "2.0"
  branch: string;       // Git branch attivo
  status: "pending" | "in_progress" | "done" | "blocked";
  created: string;      // ISO 8601
  updated: string;      // ISO 8601
  owner: string;        // Responsabile
}
```

---

## Waves (Extended)

```typescript
interface Wave {
  id: string;           // "W1", "W2", etc.
  name: string;
  status: "pending" | "in_progress" | "done" | "blocked";
  assignee: string;
  done: number;
  total: number;
  start: string | null; // "HH:MM"
  end: string | null;
  tasks: Task[];        // NEW: lista task per drill-down
}

interface Task {
  id: string;           // "W1.1", "W1.2"
  title: string;
  status: "pending" | "in_progress" | "done" | "blocked" | "skipped";
  assignee: string;
  priority: "P0" | "P1" | "P2" | "P3";
  type: "bug" | "feature" | "chore" | "doc" | "test";
  files: string[];      // Files modificati
  timing: {
    started: string | null;   // ISO 8601
    completed: string | null; // ISO 8601
    duration: number | null;  // minuti
  };
  notes: string | null;
}
```

---

## Git (Extended)

```typescript
interface Git {
  currentBranch: string;
  commits: Commit[];
  branches: string[];
  uncommitted: UncommittedChanges;  // NEW
  lastFetch: string;                // NEW: timestamp
}

interface Commit {
  hash: string;
  message: string;
  author: string;
  time: string;
}

interface UncommittedChanges {
  staged: FileChange[];
  unstaged: FileChange[];
  untracked: string[];
}

interface FileChange {
  path: string;
  status: "M" | "A" | "D" | "R";  // Modified, Added, Deleted, Renamed
  additions: number;
  deletions: number;
}
```

---

## Technical Debt (NEW)

```typescript
interface TechnicalDebt {
  total: number;        // Conteggio totale
  byType: {
    todo: DebtItem[];
    fixme: DebtItem[];
    hack: DebtItem[];
    deferred: DebtItem[];
    skipped: DebtItem[];
  };
  lastScan: string;     // ISO 8601
}

interface DebtItem {
  file: string;
  line: number;
  text: string;
  author: string | null;
  date: string | null;
}
```

---

## Quality Checks (NEW)

```typescript
interface QualityChecks {
  fundamentals: {
    tests: { exists: boolean; coverage: number | null };
    accessibility: { wcag: boolean; score: number | null };
    security: { noSecrets: boolean; inputValidation: boolean };
    documentation: { readme: boolean; apiDocs: boolean };
    errorHandling: boolean;
    logging: boolean;
    performance: { noN1: boolean; lazyLoading: boolean };
  };
  score: number;        // 0-100
  lastCheck: string;    // ISO 8601
}
```

---

## Collectors Status (NEW)

```typescript
interface CollectorStatus {
  git: { lastRun: string; status: "success" | "error"; error?: string };
  github: { lastRun: string; status: "success" | "error"; error?: string };
  tests: { lastRun: string; status: "success" | "error"; error?: string };
  debt: { lastRun: string; status: "success" | "error"; error?: string };
  quality: { lastRun: string; status: "success" | "error"; error?: string };
}
```

---

## Example (Minimal)

```json
{
  "meta": {
    "project": "MyProject",
    "plan": "Sprint 1",
    "version": "2.0",
    "status": "in_progress"
  },
  "waves": [
    {
      "id": "W1",
      "name": "Setup",
      "status": "done",
      "tasks": [
        {
          "id": "W1.1",
          "title": "Init repository",
          "status": "done",
          "timing": { "duration": 5 }
        }
      ]
    }
  ],
  "debt": {
    "total": 3,
    "byType": {
      "todo": [{ "file": "src/app.ts", "line": 42, "text": "TODO: refactor" }]
    }
  }
}
```

---

## Validation Rules

1. `meta.version` MUST be "2.0"
2. Every `wave` MUST have `tasks[]` array (can be empty)
3. Every `task.id` MUST follow pattern `{waveId}.{n}` (e.g., "W1.1")
4. `timing.duration` is calculated: `completed - started` in minutes
5. `debt.total` MUST equal sum of all items in `byType`
6. `collectors.*` timestamps MUST be ISO 8601

---

## Migration from V1

V1 plan.json senza tasks[] resta compatibile. I collectors aggiungono:
- `waves[].tasks[]` - popolato da parsing piano markdown
- `debt` - popolato da `collect-debt.sh`
- `quality` - popolato da `collect-quality.sh`
- `git.uncommitted` - popolato da `collect-git.sh`
- `collectors` - status di ogni collector
