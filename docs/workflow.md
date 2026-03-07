# MyConvergio Workflow

Complete pipeline from user intent to shipped code.

```mermaid
graph LR
    P[Prompt] --> PL[Planner]
    PL --> EX[Executor]
    EX --> TH[Thor]
    TH -->|PASS| PR[PR + CI]
    PR --> MG[Merge]
    TH -->|FAIL| EX
```

## 1. Prompt

```bash
@prompt Add real-time notifications with WebSocket support
```

Convert intent into F-xx requirements.

## 2. Planner

```bash
@planner Create plan from .copilot-tracking/notifications-prompt.md
```

Planner decomposes work into waves and tasks, stores them in SQLite, and creates worktree context.

## 3. Executor

```bash
@execute 42
```

Executor runs RED → GREEN → REFACTOR for each task, then submits proof of work.

## 4. Thor validation

Thor independently validates the task before status can move from `submitted` to `done`.

Key checks:

- F-xx coverage
- tests and type checks
- docs and repo hygiene
- token attribution and execution trace integrity
- no silent bypass of hooks / plan DB flow

## 5. PR, CI, merge

After a validated wave, MyConvergio creates the PR, waits for CI, fixes failures in batches, then merges.

## Control Room

Start the dashboard:

```bash
python3 ~/.claude/scripts/dashboard_web/server.py
```

The web dashboard shows:

- current plans, waves, tasks
- live AI organization grouped by node and role
- active agent runs, handoffs, and recent task events
- tokens / costs with exact task attribution where available

## Bootstrap workflow

Before starting serious work on a new machine:

```bash
myconvergio setup --standard --with-shell --with-devtools
myconvergio doctor
```

For a full maintainer-style workstation:

```bash
myconvergio setup --full --with-workstation
```

## Ecosystem release sync

When preparing a public release from your private `~/.claude` source of truth:

```bash
myconvergio ecosystem-sync all --dry-run
myconvergio ecosystem-sync all
```

This ensures:

- sanitized upstream sync into `.claude/`
- mirrored runtime copies under `scripts/` stay consistent
- Copilot agents are regenerated and validation checks run
