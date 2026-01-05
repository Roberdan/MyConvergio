# Dashboard Enhanced Tracking - Implementation Status

**Date**: 2026-01-05
**Status**: Backend Complete ✅ | Frontend In Progress 🚧

## ✅ COMPLETED

### 1. Database Schema (Migration 005)
**File**: `server/migrations/005_enhanced_tracking.sql`

- ✅ Markdown file path tracking (`plans.markdown_dir`, `waves.markdown_path`, `tasks.markdown_path`)
- ✅ Plan archiving (`plans.archived_at`, `plans.archived_path`)
- ✅ Executor session tracking (`tasks.executor_session_id`, `executor_status`, `executor_started_at`, `executor_last_activity`)
- ✅ Conversation logs table (full conversation history with tool calls)
- ✅ Monitoring views (`v_active_executions`, `v_task_conversations`)

**Applied**: Migration successfully applied to `~/.claude/data/dashboard.db`

### 2. Monitoring APIs
**File**: `dashboard/server/routes-monitoring.js`

**Endpoints Created**:
- `GET /api/monitoring/sessions` - All active executor sessions
- `GET /api/project/:projectId/task/:taskId/session` - Task session info + conversation summary
- `GET /api/project/:projectId/task/:taskId/conversation` - Full conversation logs
- `GET /api/project/:projectId/task/:taskId/live` - **SSE real-time stream** for live monitoring
- `GET /api/project/:projectId/wave/:waveId/conversations` - All conversations for a wave
- `POST /api/project/:projectId/task/:taskId/executor/start` - Register executor session start
- `POST /api/project/:projectId/task/:taskId/executor/heartbeat` - Update last activity
- `POST /api/project/:projectId/task/:taskId/executor/complete` - Mark execution complete/failed
- `POST /api/project/:projectId/task/:taskId/conversation/log` - Log conversation message

**Features**:
- Real-time SSE streaming with 2-second polling
- Automatic heartbeat tracking
- Tool call logging (tool name, input, output)
- Session metadata (tokens, model, thinking time)

### 3. Plan Archiving APIs
**File**: `dashboard/server/routes-plans.js` (extended)

**Endpoints Created**:
- `POST /api/plan/:id/archive` - Archive completed plan to `~/.claude/plans/archived/YYYY-MM/{project}/`
- `POST /api/plan/:id/unarchive` - Restore archived plan

**Features**:
- Automatic directory structure creation
- Moves all plan markdown files (Main + Phase files)
- Updates DB with archiving metadata
- Only allows archiving `done` plans

### 4. Server Integration
**File**: `dashboard/server.js`

- ✅ Added `routesMonitoring` module
- ✅ SSE handler support (returns `_sse_handled` flag)
- ✅ Modified handler signature to pass `req`, `res`, `body`
- ✅ Server restarted successfully (PID 25960)

**Test**:
```bash
curl http://localhost:31415/api/monitoring/sessions
# Returns: []
```

## 🚧 TODO

### 5. Frontend UI Redesign
**Objective**: Unified wave card + tree navigation

**Design**:
```
┌─────────────────────────────────────────┐
│ 8-W3 - Progress Tracking       [v]     │ ← Collapsible header
│ ● In progress | 2/5 tasks | 40% ████░░ │ ← Current wave status
├─────────────────────────────────────────┤
│ All Waves (4)                    [^]    │ ← Tree toggle
│                                          │
│ ├─ 8-W1: Pedagogical Analysis    [✓]   │ ← Completed
│ │  ├─ T1-01: Implementare analisi [✓]  │
│ │  ├─ T1-02: Test analisi         [✓]  │
│ │  └─ T1-03: Estrarre concetti    [✓]  │
│ │                                        │
│ ├─ 8-W2: Learning Path Generation [✓]  │
│ │  └─ 6 tasks (all completed)           │
│ │                                        │
│ ├─ 8-W3: Progress Tracking        [●]  │ ← In progress (expanded)
│ │  ├─ T3-01: Stato argomento      [✓]  │
│ │  ├─ T3-02: UI stato             [●] ← Running (live indicator)
│ │  │   └─ [View conversation] [Watch live] │
│ │  ├─ T3-03: Percentuale          [ ]  │
│ │  └─ T3-04: Storia performance   [ ]  │
│ │                                        │
│ └─ 8-W4: UI Integration           [ ]  │ ← Locked
└─────────────────────────────────────────┘
```

**Features Needed**:
- Collapse/expand waves
- Collapse/expand tasks within wave
- Live execution indicator (● pulsing)
- "View conversation" button → opens conversation viewer modal
- "Watch live" button → connects to SSE stream
- Real-time progress updates

### 6. Conversation Viewer Component
**File**: `dashboard/js/conversation-viewer.js` (NEW)

**UI Mock**:
```
┌─────────────────────────────────────────┐
│ Conversation: T3-02 UI stato     [×]   │
├─────────────────────────────────────────┤
│ [12:30] User: Start task T3-02         │
│ [12:30] Assistant: I'll implement...   │
│ [12:31] Tool: Read file                │
│         Input: /path/to/file.js        │
│         Output: [200 lines]            │
│ [12:32] Tool: Edit file                │
│ [12:33] Tool: Bash (npm test)          │
│         Output: All tests passed ✓     │
│ [12:34] Assistant: Task completed      │
│                                         │
│ 📊 Stats: 4 tools | 12.5k tokens       │
└─────────────────────────────────────────┘
```

**Features**:
- Real-time updates via SSE
- Syntax highlighting for code
- Collapsible tool calls
- Token usage stats
- Export conversation to markdown

### 7. Task Markdown Generation (Planner)
**Objective**: Generate individual markdown files for each task

**Structure**:
```
~/.claude/plans/active/convergioedu/
  plan-8/
    plan.md                    # Master plan
    waves/
      W1-pedagogical/
        wave.md                # Wave overview
        tasks/
          T1-01-analisi.md    # ← NEW: Task markdown
          T1-02-test.md
          T1-03-concetti.md
      W2-learning-path/
        wave.md
        tasks/
          T2-01-schema.md
          ...
```

**Task Markdown Template**:
```markdown
# T1-01: Implementare Analisi PDF

**Wave**: 8-W1 Pedagogical Analysis
**Status**: completed
**Priority**: P0
**Assignee**: executor-agent

## Description
Input: testo estratto da PDF → Output: 2-5 argomenti con titoli
Use AI prompt to identify topic boundaries in text

## Acceptance Criteria
- [ ] Identifica 2-5 macro-argomenti
- [ ] Ogni argomento ha titolo chiaro
- [ ] Test su PDF Storia Romana passa

## Execution Log

### Session: abc-123-def (Started: 2026-01-05 12:00)
- **Duration**: 15 minutes
- **Tokens**: 12.5k
- **Status**: Completed ✓

### Conversation
[Link to full conversation](./conversations/abc-123-def.md)

### Files Modified
- `src/analysis/pdf-parser.ts` (created)
- `src/analysis/topic-extractor.ts` (created)
- `tests/analysis.test.ts` (added 3 tests)

### Thor Validation
✓ Validated by thor-quality-assurance-guardian
  - All tests pass
  - No linting errors
  - Code coverage 85%

## Notes
Implemented using GPT-4 prompt engineering instead of fine-tuned model.
Performance acceptable for MVP.
```

**Implementation**:
- Modify planner to generate task markdown when creating waves
- Add `markdown_path` to DB when task created
- Link task → conversation logs → markdown export

### 8. Executor Session Tracking
**Objective**: Executor agent logs activity to DB

**Hook Points** (in executor agent):
1. **On task start**: Call `POST /api/.../executor/start` with session_id
2. **On tool call**: Call `POST /api/.../conversation/log` with tool details
3. **Every 30s**: Call `POST /api/.../executor/heartbeat`
4. **On completion**: Call `POST /api/.../executor/complete`

**Session ID**: Use Claude conversation ID or generate UUID

**Tool Logging Format**:
```json
{
  "session_id": "abc-123",
  "role": "tool",
  "tool_name": "Read",
  "tool_input": {
    "file_path": "/path/to/file.js",
    "limit": 100
  },
  "tool_output": "File contents...",
  "metadata": {
    "tokens_input": 50,
    "tokens_output": 2000,
    "duration_ms": 120
  }
}
```

## 📊 PROGRESS SUMMARY

| Component | Status | Lines Changed |
|-----------|--------|---------------|
| DB Schema | ✅ Complete | 100+ |
| Monitoring APIs | ✅ Complete | 300+ |
| Archiving APIs | ✅ Complete | 130+ |
| Server Integration | ✅ Complete | 10 |
| **Frontend UI** | 🚧 TODO | ~500 estimated |
| **Conversation Viewer** | 🚧 TODO | ~300 estimated |
| **Task Markdown Gen** | 🚧 TODO | ~200 estimated |
| **Executor Tracking** | 🚧 TODO | ~100 estimated |

**Total Backend**: ✅ 540 lines | **Total Frontend**: 🚧 ~1100 lines

## 🚀 NEXT STEPS

1. **Commit current work** to MyConvergio repository
2. **Create UI prototype** with basic tree navigation (no full redesign yet)
3. **Test monitoring APIs** with mock data
4. **Implement conversation viewer** as standalone component
5. **Add executor hooks** to track sessions
6. **Generate task markdown** in planner

## 🧪 TESTING

**Test Monitoring API**:
```bash
# Check active sessions
curl http://localhost:31415/api/monitoring/sessions

# Get task conversation (replace with real IDs)
curl http://localhost:31415/api/project/convergioedu/task/T3-02/conversation

# SSE live stream (use browser or curl -N)
curl -N http://localhost:31415/api/project/convergioedu/task/T3-02/live
```

**Test Archiving**:
```bash
# Archive plan 8 (if status=done)
curl -X POST http://localhost:31415/api/plan/8/archive

# Check archived location
ls ~/.claude/plans/archived/2026-01/convergioedu/
```

## 📝 NOTES

- Migration 005 already applied to dashboard.db
- Server running on PID 25960, port 31415
- SSE polling interval: 2 seconds (configurable)
- Archive structure: `archived/YYYY-MM/{project}/{plan}/`
- Conversation logs support JSON in tool_input/tool_output fields
