# Executor Tracking & Task Markdown Generation

Documentazione completa per l'integrazione tra strategic-planner, executor tracking e MyConvergio Dashboard.

---

## 📋 Overview

Il sistema di tracking executor permette di:
- Monitorare l'esecuzione dei task in real-time
- Loggare conversazioni e tool calls
- Generare file markdown per ogni task
- Visualizzare progress live nella dashboard
- Esportare conversazioni complete

---

## 🚀 Quick Start

### 1. Setup Scripts

Gli script sono installati in `~/.claude/scripts/`:

```bash
# Copia scripts nella directory corretta
mkdir -p ~/.claude/scripts

# generate-task-md.sh - Genera task markdown files
# executor-tracking.sh - Helper functions per tracking

# Rendi eseguibili
chmod +x ~/.claude/scripts/generate-task-md.sh
chmod +x ~/.claude/scripts/executor-tracking.sh
```

### 2. Carica Executor Tracking

Nel tuo shell (bash/zsh):

```bash
# Carica functions helper
source ~/.claude/scripts/executor-tracking.sh

# Per auto-load, aggiungi al tuo .zshrc o .bashrc:
echo 'source ~/.claude/scripts/executor-tracking.sh' >> ~/.zshrc
```

### 3. Avvia Dashboard

```bash
cd /path/to/MyConvergio/dashboard
node server.js &
```

Dashboard disponibile su: http://localhost:31415

---

## 📝 Generazione Task Markdown

### Script: `generate-task-md.sh`

Genera file markdown individuali per ogni task durante la planning phase.

#### Usage

```bash
~/.claude/scripts/generate-task-md.sh <project> <plan_id> <wave> <task_id> <task_name> [assignee] [estimate]
```

#### Example

```bash
~/.claude/scripts/generate-task-md.sh \
  convergioedu \
  8 \
  0 \
  T01 \
  "Setup database migration" \
  "CLAUDE 2" \
  "1h"
```

#### Output

Crea file: `~/.claude/plans/active/convergioedu/plan-8/waves/W0/tasks/T01-setup-database-migration.md`

Aggiorna database con markdown_path.

#### Directory Structure

```
~/.claude/plans/active/
└── {project}/
    └── plan-{id}/
        ├── plan-{id}.md
        └── waves/
            ├── W0/
            │   ├── W0-prerequisites.md
            │   └── tasks/
            │       ├── T01-task-name.md
            │       └── T02-task-name.md
            └── W1/
                ├── W1-implementation.md
                └── tasks/
                    └── T03-task-name.md
```

---

## 🔧 Executor Tracking Functions

### Script: `executor-tracking.sh`

Fornisce helper functions per tracking durante l'esecuzione.

### Functions

#### `executor_start <project> <task_id>`

Inizializza tracking per un task.

```bash
executor_start "convergioedu" "T01"
# 🚀 Starting executor tracking...
#   Project: convergioedu
#   Task: T01
#   Session: a1b2c3d4-e5f6-7890-abcd-ef1234567890
# ✅ Task started and registered in dashboard
# 💓 Heartbeat started (PID: 12345)
```

**Cosa fa:**
1. Genera session_id univoco
2. Chiama POST `/api/project/{project}/task/{taskId}/executor/start`
3. Avvia heartbeat loop (POST ogni 30s)
4. Logga messaggio iniziale

#### `executor_log <role> <content> [tool_name] [tool_input_json] [tool_output_json]`

Logga messaggio di conversazione.

```bash
# User message
executor_log "user" "Analyze the requirements"

# Assistant message
executor_log "assistant" "Found 3 files to modify"

# Tool call (solo nome)
executor_log "tool" "" "Read" '{"file_path":"src/index.ts"}' '{"lines":150}'

# System message
executor_log "system" "Build completed successfully"
```

#### `executor_log_tool <tool_name> <input_json> <output_json>`

Shortcut per loggare tool calls.

```bash
executor_log_tool "Read" \
  '{"file_path":"src/index.ts"}' \
  '{"content":"import ...","lines":150}'
```

#### `executor_status`

Mostra stato corrente del tracking.

```bash
executor_status
# 📊 Executor Status
#   Project: convergioedu
#   Task: T01
#   Session: a1b2c3d4-e5f6-7890-abcd-ef1234567890
#   Heartbeat: 12345
#   Dashboard: http://localhost:31415?project=convergioedu&task=T01
```

#### `executor_complete [success|failed]`

Completa il task e chiude tracking.

```bash
# Success
executor_complete success

# Failed
executor_complete failed
```

**Cosa fa:**
1. Ferma heartbeat loop
2. Logga messaggio finale
3. Chiama POST `/api/project/{project}/task/{taskId}/executor/complete`
4. Pulisce environment variables

---

## 🎯 Workflow Completo

### Planning Phase (Strategic Planner)

1. **Crea plan con strategic-planner:**

```bash
claude "Create execution plan for feature X"
```

2. **Planner genera task markdown per ogni task:**

Il strategic-planner ora include istruzioni per:
- Generare `task.md` file per ogni task
- Popolare database con `markdown_path`
- Linkare task → wave → plan

3. **Verifica struttura:**

```bash
ls ~/.claude/plans/active/myproject/plan-8/waves/W0/tasks/
# T01-setup-env.md
# T02-create-api.md
# T03-test-endpoints.md
```

### Execution Phase (Executor Agent)

1. **Carica tracking functions:**

```bash
source ~/.claude/scripts/executor-tracking.sh
```

2. **Inizia task:**

```bash
executor_start "myproject" "T01"
```

3. **Esegui task con logging:**

```bash
# User input
executor_log "user" "Starting task T01: Setup environment"

# Analyze
executor_log "assistant" "Analyzing project structure..."

# Read files
executor_log_tool "Read" \
  '{"file_path":"package.json"}' \
  '{"content":"...","version":"1.0.0"}'

# Modify
executor_log_tool "Edit" \
  '{"file_path":"package.json","changes":"..."}' \
  '{"success":true,"lines_changed":5}'

# Build/test
executor_log "assistant" "Running npm install..."
executor_log_tool "Bash" \
  '{"command":"npm install"}' \
  '{"exit_code":0,"output":"added 150 packages"}'

# Complete
executor_log "assistant" "Task T01 completed successfully"
```

4. **Completa task:**

```bash
executor_complete success
```

### Monitoring Phase (Dashboard)

1. **Apri dashboard:**

http://localhost:31415

2. **Naviga unified waves card:**
   - Vedi current wave
   - Expand per vedere tutti i task
   - Click "Watch Live" su task in esecuzione

3. **Conversation Viewer:**
   - Vedi tutti i messaggi in real-time
   - SSE streaming per live updates
   - Expand tool calls per vedere JSON input/output

4. **Export conversation:**
   - Click "Export to Markdown"
   - Download `conversation-T01-timestamp.md`

---

## 📊 Dashboard API Endpoints

### Executor Tracking

| Endpoint | Method | Description |
|----------|--------|-------------|
| `/api/project/:projectId/task/:taskId/executor/start` | POST | Start task execution |
| `/api/project/:projectId/task/:taskId/executor/heartbeat` | POST | Heartbeat (every 30s) |
| `/api/project/:projectId/task/:taskId/executor/complete` | POST | Complete task (success) |
| `/api/project/:projectId/task/:taskId/executor/failed` | POST | Complete task (failed) |

### Conversation Logging

| Endpoint | Method | Description |
|----------|--------|-------------|
| `/api/project/:projectId/task/:taskId/conversation/log` | POST | Log message or tool call |
| `/api/project/:projectId/task/:taskId/conversation` | GET | Get all messages |
| `/api/project/:projectId/task/:taskId/live` | GET | SSE stream for live updates |

### Task Metadata

| Endpoint | Method | Description |
|----------|--------|-------------|
| `/api/project/:projectId/task/:taskId/session` | GET | Get session info |
| `/api/project/:projectId/task/:taskId/update-markdown` | POST | Update markdown_path |
| `/api/monitoring/sessions` | GET | Get all active sessions |

---

## 🔍 Examples

### Example 1: Simple Task Execution

```bash
# Setup
source ~/.claude/scripts/executor-tracking.sh
executor_start "myproject" "T01"

# Execute
executor_log "user" "Fix authentication bug"
executor_log "assistant" "Analyzing auth flow..."
executor_log_tool "Read" '{"file":"auth.ts"}' '{"lines":200}'
executor_log_tool "Edit" '{"file":"auth.ts"}' '{"changed":true}'
executor_log "assistant" "Bug fixed and tested"

# Complete
executor_complete success
```

### Example 2: Task with Build Verification

```bash
executor_start "myproject" "T02"

executor_log "user" "Add new API endpoint"
executor_log "assistant" "Creating endpoint /api/users"
executor_log_tool "Write" '{"file":"routes.ts"}' '{"created":true}'

# Run verification
executor_log "assistant" "Running lint..."
BUILD_OUTPUT=$(npm run lint 2>&1)
executor_log_tool "Bash" '{"cmd":"npm run lint"}' "{\"output\":\"$BUILD_OUTPUT\"}"

# Check if passed
if [ $? -eq 0 ]; then
  executor_log "system" "✅ Lint passed"
  executor_complete success
else
  executor_log "system" "❌ Lint failed"
  executor_complete failed
fi
```

### Example 3: Generate Task Markdown During Planning

```bash
# Strategic planner creates these task markdown files

~/.claude/scripts/generate-task-md.sh convergioedu 8 0 T01 "Setup Prerequisites" "CLAUDE 2" "30m"
~/.claude/scripts/generate-task-md.sh convergioedu 8 0 T02 "Database Migration" "CLAUDE 2" "1h"
~/.claude/scripts/generate-task-md.sh convergioedu 8 1 T03 "Create API Routes" "CLAUDE 3" "2h"
~/.claude/scripts/generate-task-md.sh convergioedu 8 1 T04 "Build Frontend UI" "CLAUDE 4" "3h"
```

---

## ⚠️ Troubleshooting

### Dashboard not responding

```bash
# Check if running
curl http://localhost:31415/health

# If not, start it
cd /path/to/MyConvergio/dashboard
node server.js &
```

### Heartbeat not starting

```bash
# Check if already running
executor_status

# Stop old heartbeat
kill $HEARTBEAT_PID

# Restart
executor_start "project" "taskId"
```

### Database not updating

```bash
# Check if endpoint exists
curl -X POST http://localhost:31415/api/project/test/task/T01/update-markdown \
  -H "Content-Type: application/json" \
  -d '{"markdown_path":"/path/to/file.md"}'

# Should return: {"success":true,"task_id":"T01","markdown_path":"..."}
```

### Markdown files not created

```bash
# Check directory exists
ls -la ~/.claude/plans/active/{project}/plan-{id}/waves/

# Create manually if missing
mkdir -p ~/.claude/plans/active/{project}/plan-{id}/waves/W{X}/tasks/

# Run generation script with full paths
bash ~/.claude/scripts/generate-task-md.sh {project} {plan_id} {wave} {task_id} "{name}" "{assignee}" "{estimate}"
```

---

## 📚 Integration with Strategic Planner

Il file `agents/strategic-planner.md` è stato aggiornato con:

### Nuove Sezioni

1. **Step 6: Task Markdown Generation** - Processo per generare task.md files
2. **Step 7: Dashboard Integration** - Come integrare con dashboard API
3. **Task Markdown Template** - Template completo per task files
4. **Dashboard Integration Commands** - Esempi di curl per tutti gli endpoint
5. **Task Markdown Generation Script** - Script bash completo inline
6. **Plan Generation Workflow** - Workflow passo-passo

### Uso

Quando invochi strategic-planner:

```bash
@strategic-planner Create plan for feature X with MyConvergio integration
```

Il planner ora:
- Genera plan markdown file principale
- Genera wave markdown files
- Genera task markdown files per ogni task
- Include section "DASHBOARD INTEGRATION" con tutti i comandi
- Documenta come usare executor tracking
- Fornisce esempi di curl per ogni endpoint

---

## 🎨 Features Dashboard

### Unified Waves Card

- Tree navigation gerarchica
- Live indicators per task running
- Expand/collapse waves e tasks
- View markdown per waves
- "Watch Live" button per task attivi

### Conversation Viewer

- Modal con SSE live streaming
- Messages color-coded per role
- Tool calls espandibili con JSON
- Export to markdown
- Stats: messages, tool calls, duration, tokens

### Bug List

- Quick entry con priority
- Integration con planner
- Copy command to clipboard
- Auto-archive dopo execution

---

## 📖 References

- **Strategic Planner:** `agents/strategic-planner.md`
- **Test Plan:** `TEST_PLAN.md`
- **Scripts:** `~/.claude/scripts/`
- **Dashboard:** `dashboard/`
- **API Routes:** `dashboard/server/routes-monitoring.js`
- **Database Schema:** `dashboard/server/migrations/005_enhanced_tracking.sql`

---

**Last Updated:** 05 Gennaio 2026
**Version:** 1.0.0
