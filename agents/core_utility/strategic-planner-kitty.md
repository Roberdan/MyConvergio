---
name: strategic-planner-kitty
description: Kitty terminal parallel orchestration for strategic-planner. Reference module.
version: "2.0.0"
---

# Kitty Parallel Orchestration

## Overview
Orchestrate **parallel execution** with multiple Claude instances via Kitty terminal.

## Requirements
- Run FROM Kitty terminal (not Warp/iTerm)
- `wildClaude` alias configured (`claude --dangerously-skip-permissions`)
- Kitty remote control enabled in `~/.config/kitty/kitty.conf`:
  ```
  allow_remote_control yes
  listen_on unix:/tmp/kitty-socket
  ```

## Workflow
```
1. Create plan with Claude assignments (max 4)
2. Ask: "Vuoi eseguire in parallelo?"
3. If yes → Launch workers, send tasks, monitor
```

## Plan Format for Parallel Execution

```markdown
## 🎭 RUOLI CLAUDE

| Claude | Ruolo | Task Assegnati | Files (NO OVERLAP!) |
|--------|-------|----------------|---------------------|
| CLAUDE 1 | COORDINATORE | Monitor, verify | - |
| CLAUDE 2 | IMPLEMENTER | T-01, T-02 | src/api/*.ts |
| CLAUDE 3 | IMPLEMENTER | T-03, T-04 | src/components/*.tsx |
| CLAUDE 4 | IMPLEMENTER | T-05, T-06 | src/lib/*.ts |
```

---

## Inter-Claude Communication Protocol

### Communication Command Pattern
```bash
# Universal pattern for ALL inter-Claude communication:
kitty @ send-text --match title:Claude-X "messaggio" && kitty @ send-key --match title:Claude-X Return
```

### Communication Scenarios

**1. Coordinator → Worker (Task Assignment)**
```bash
kitty @ send-text --match title:Claude-3 "Leggi il piano, sei CLAUDE 3, inizia T-05" && kitty @ send-key --match title:Claude-3 Return
```

**2. Worker → Coordinator (Status Report)**
```bash
kitty @ send-text --match title:Claude-1 "CLAUDE 3: ✅ T-05 completato, piano aggiornato" && kitty @ send-key --match title:Claude-1 Return
```

**3. Worker → Worker (Direct Sync)**
```bash
kitty @ send-text --match title:Claude-4 "CLAUDE 2: Ho finito types.ts, puoi procedere con api.ts" && kitty @ send-key --match title:Claude-4 Return
```

**4. Broadcast (One → All)**
```bash
for i in 2 3 4; do
  kitty @ send-text --match title:Claude-$i "🚨 STOP! Conflitto git rilevato." && kitty @ send-key --match title:Claude-$i Return
done
```

**5. Gate Unlock Notification**
```bash
kitty @ send-text --match title:Claude-3 "🟢 GATE-1 UNLOCKED! Procedi con Phase 1B" && kitty @ send-key --match title:Claude-3 Return
```

---

## Message Format Convention

```
[SENDER]: [EMOJI] [CONTENT]

Examples:
- "CLAUDE 3: ✅ T-05 completato"
- "CLAUDE 1: 🚨 STOP! Git conflict"
- "CLAUDE 2: 🟢 GATE-1 UNLOCKED"
- "CLAUDE 4: ❓ Need help with T-08"
```

### Emojis for Quick Parsing
| Emoji | Meaning |
|:-----:|---------|
| ✅ | Task completed |
| 🟢 | Gate unlocked / Go ahead |
| 🔴 | Stop / Blocked |
| 🚨 | Alert / Urgent |
| ❓ | Question / Help needed |
| 📊 | Status update |
| ⏳ | Waiting / In progress |

---

## Orchestration Commands

```bash
# Verify Kitty setup
~/.claude/scripts/kitty-check.sh

# Launch N Claude workers
~/.claude/scripts/claude-parallel.sh [N]

# Send tasks to workers
kitty @ send-text --match title:Claude-2 "Leggi [plan], sei CLAUDE 2, esegui i tuoi task" && kitty @ send-key --match title:Claude-2 Return

# Monitor progress
~/.claude/scripts/claude-monitor.sh
```

---

## Critical Rules

1. **MAX 4 CLAUDE**: Hard limit, beyond = unmanageable
2. **NO FILE OVERLAP**: Each Claude works on DIFFERENT files
3. **VERIFICATION LAST**: Final check with lint/typecheck/build
4. **GIT SAFETY**: Only one Claude commits at a time
5. **THOR VALIDATION**: ALL Claudes must get Thor approval

---

## Phase Gates (Synchronization)

### Add to Plan
```markdown
## 🚦 PHASE GATES

| Gate | Blocking Phase | Waiting Phases | Status | Unlocked By |
|------|----------------|----------------|--------|-------------|
| GATE-1 | Phase 0 (Safety) | Phase 1A, 1B, 1C | 🔴 LOCKED | CLAUDE 2 |
```

### Gate Status Values
- 🔴 LOCKED - Waiting phases cannot start
- 🟢 UNLOCKED - Waiting phases can proceed

### Unlock Protocol
When ALL tasks in blocking phase are ✅:
1. Update plan file - change gate to 🟢 UNLOCKED
2. Notify waiting Claude instances:
```bash
kitty @ send-text --match title:Claude-3 "🟢 GATE-1 UNLOCKED!" && kitty @ send-key --match title:Claude-3 Return
```

### Polling Protocol (waiting Claude)
```bash
while ! grep "GATE-1" plan.md | grep -q "🟢 UNLOCKED"; do
  echo "$(date): Waiting for GATE-1..."
  sleep 300
done
echo "🟢 GATE-1 UNLOCKED! Starting work..."
```

---

## Coordinator Responsibilities (CLAUDE 1)

```
CLAUDE 1 MUST:
1. Monitor all gates every 10 minutes
2. Verify gate unlocks are legitimate (all tasks ✅)
3. If a Claude forgets to unlock, do it for them
4. Track elapsed time per phase
5. Alert if a phase takes >2x estimated time
```

---

## Scripts Location

```
~/.claude/scripts/
├── orchestrate.sh       # Full orchestration
├── claude-parallel.sh   # Launch N Claude tabs
├── claude-monitor.sh    # Monitor workers
└── kitty-check.sh       # Verify setup
```

---

## Changelog

- **2.0.0** (2026-01-10): Extracted from strategic-planner.md for modularity
