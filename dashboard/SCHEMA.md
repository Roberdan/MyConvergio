# Plan Dashboard Schema

> Data contract between planner and dashboard. The planner writes `plan.json`, the dashboard reads and visualizes it.

## Quick Start

1. Copy template: `cp ~/.claude/dashboard/plan.json /path/to/your/plan.json`
2. Start server: `npx live-server ~/.claude/dashboard --port=31415`
3. Open: `http://127.0.0.1:31415`

## Schema Reference

### meta (required)

```json
{
  "meta": {
    "project": "ProjectName",
    "plan": "Sprint/Plan Name",
    "version": "1.0",
    "branch": "feature/branch-name",
    "status": "in_progress | done | blocked",
    "created": "ISO8601 timestamp",
    "updated": "ISO8601 timestamp",
    "owner": "username"
  }
}
```

### metrics (required)

```json
{
  "metrics": {
    "velocity": { "value": 12.5, "unit": "tasks/h", "trend": 15, "trendDir": "up|down" },
    "cycleTime": { "value": 8.5, "unit": "min", "trend": 2, "trendDir": "up|down" },
    "throughput": { "done": 54, "total": 62, "percent": 87 },
    "quality": { "score": 98.2, "trend": 1.2, "trendDir": "up|down" }
  }
}
```

| Metric | Description | Calculation |
|--------|-------------|-------------|
| velocity | Tasks completed per hour | done_tasks / elapsed_hours |
| cycleTime | Average time per task | elapsed_minutes / done_tasks |
| throughput | Overall progress | (done / total) * 100 |
| quality | Code quality score | From linter/tests/coverage |

### bugs (required)

```json
{
  "bugs": {
    "total": 21,
    "fixed": 21,
    "p0": { "count": 7, "fixed": 7 },
    "p1": { "count": 9, "fixed": 9 },
    "p2": { "count": 5, "fixed": 5 }
  }
}
```

### github (optional)

```json
{
  "github": {
    "pr": {
      "number": 123,
      "title": "feat: Description",
      "status": "open | merged | closed",
      "url": "https://github.com/...",
      "additions": 890,
      "deletions": 234,
      "files": 23,
      "comments": 3,
      "reviewers": ["user1", "user2"]
    },
    "checks": [
      { "name": "TypeCheck", "status": "pass | fail | pending", "detail": "optional" },
      { "name": "Tests", "status": "pass", "detail": "142/142" }
    ]
  }
}
```

### contributors (required)

```json
{
  "contributors": [
    {
      "id": "claude-a",
      "name": "Claude-A",
      "role": "Executor",
      "avatar": "emoji",
      "tasks": 44,
      "status": "active | idle | pending",
      "currentTask": "W5.1",
      "efficiency": 125.73
    }
  ]
}
```

| Field | Description |
|-------|-------------|
| id | Unique identifier |
| role | Executor, QA Guardian, Code Reviewer, Owner, etc. |
| status | active (working), idle (available), pending (waiting) |
| efficiency | % vs baseline (100 = normal, 125 = 25% faster) |
| currentTask | Wave.Task ID currently being worked on |

### timeline (required)

```json
{
  "timeline": {
    "start": "ISO8601",
    "eta": "ISO8601",
    "elapsed": "5h 15m",
    "remaining": "1h 00m",
    "data": [
      { "time": "17:15", "done": 0, "target": 62 },
      { "time": "18:00", "done": 3, "target": 55 }
    ]
  }
}
```

The `data` array drives the progress chart. Add a new entry each time progress is updated.

### waves (required)

```json
{
  "waves": [
    {
      "id": "W1",
      "name": "Wave Name",
      "status": "done | in_progress | pending",
      "assignee": "username",
      "done": 21,
      "total": 21,
      "start": "18:44",
      "end": "20:00"
    }
  ]
}
```

### alerts (required)

```json
{
  "alerts": [
    { "type": "blocker", "title": "PR Not Merging", "desc": "6/10 QA failures" },
    { "type": "warning", "title": "Wave 5 Pending", "desc": "Thor QA waiting" }
  ]
}
```

Types: `blocker` (red), `warning` (yellow), `info` (blue)

### git (optional, for git graph)

```json
{
  "git": {
    "currentBranch": "development",
    "commits": [
      { "hash": "abc1234", "message": "feat: Add dashboard", "author": "claude", "time": "2h ago" }
    ],
    "branches": ["main", "development", "feature/dashboard"]
  }
}
```

### files (optional)

```json
{
  "files": {
    "plan": "docs/plans/TODAY.md",
    "waves": "waves/",
    "qa": "qa/manual-qa.md"
  }
}
```

## Planner Integration

The planner should:

1. **Initialize**: Create plan.json from template at plan start
2. **Update continuously**: Modify plan.json after each completed task
3. **Track metrics**: Calculate velocity, cycle time from timestamps
4. **Populate git**: Run `git log --oneline -10` and parse into commits array
5. **Set alerts**: Add blockers/warnings as they arise

Example planner update:

```bash
# After completing a task, update plan.json
jq '.metrics.throughput.done += 1 | .metrics.throughput.percent = (.metrics.throughput.done / .metrics.throughput.total * 100 | floor)' plan.json > tmp.json && mv tmp.json plan.json
```

## Dashboard Features

- **Live reload**: Changes to plan.json auto-refresh the browser
- **Theme toggle**: Light/Dark mode (persisted in localStorage)
- **Export PNG**: Screenshot of current state
- **Export CSV**: Wave data for Azure DevOps import
- **Export JSON**: Raw plan data

## Port

Default: **31415** (pi) - chosen to avoid conflicts with common dev ports.

---

*Part of the Claude Code system. See `~/.claude/commands/planner.md` for integration.*
