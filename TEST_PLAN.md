# Test Plan - Dashboard Enhancement Features

**Data:** 05 Gennaio 2026
**Progetto:** MyConvergio Dashboard
**Features:** Unified Waves Card, Conversation Viewer, Bug List, Real-time Tracking

---

## 1. Backend API Tests

### 1.1 Monitoring Endpoints

**Test: GET /api/monitoring/sessions**
- [ ] Avvia dashboard e verifica che l'endpoint risponda con 200
- [ ] Verifica che restituisca array vuoto se nessuna sessione attiva
- [ ] Crea task in esecuzione e verifica che compaia nella lista
- [ ] Verifica che mostri executor_session_id, status, last_activity

**Test: GET /api/project/:projectId/task/:taskId/session**
- [ ] Recupera session info per task esistente
- [ ] Verifica che includa executor_status, executor_started_at
- [ ] Testa con task_id inesistente (deve dare errore appropriato)

**Test: GET /api/project/:projectId/task/:taskId/conversation**
- [ ] Recupera conversation logs per task con messaggi
- [ ] Verifica che includa role, content, timestamp
- [ ] Verifica che tool messages abbiano tool_name, tool_input, tool_output
- [ ] Verifica ordinamento cronologico (timestamp ASC)

**Test: POST /api/project/:projectId/task/:taskId/executor/start**
- [ ] Invia richiesta con session_id
- [ ] Verifica che aggiorni executor_session_id nella tabella tasks
- [ ] Verifica che imposti executor_status = 'running'
- [ ] Verifica che imposti executor_started_at con timestamp corrente

**Test: POST /api/project/:projectId/task/:taskId/executor/heartbeat**
- [ ] Invia heartbeat per task running
- [ ] Verifica che aggiorni executor_last_activity
- [ ] Verifica che v_active_executions calcoli minutes_since_activity correttamente

**Test: POST /api/project/:projectId/task/:taskId/executor/complete**
- [ ] Completa task execution
- [ ] Verifica che imposti executor_status = 'completed'
- [ ] Testa anche /executor/failed

**Test: POST /api/project/:projectId/task/:taskId/conversation/log**
- [ ] Log user message
- [ ] Log assistant message
- [ ] Log tool call (con tool_name, tool_input JSON, tool_output JSON)
- [ ] Verifica che timestamp sia auto-generated
- [ ] Verifica che message appaia in GET conversation

### 1.2 SSE Streaming Endpoint

**Test: GET /api/project/:projectId/task/:taskId/live**
- [ ] Connetti con EventSource
- [ ] Verifica headers (Content-Type: text/event-stream)
- [ ] Ricevi keepalive ping ogni 2 secondi
- [ ] Log un nuovo messaggio e verifica che arrivi via SSE
- [ ] Testa disconnessione e riconnessione
- [ ] Verifica che lastTimestamp filtri correttamente i messaggi

### 1.3 Plan Archiving Endpoints

**Test: POST /api/plan/:id/archive**
- [ ] Crea plan con status='done'
- [ ] Archivia plan
- [ ] Verifica che file vengano spostati in ~/.claude/plans/archived/YYYY-MM/{project}/
- [ ] Verifica che archived_at e archived_path siano popolati
- [ ] Testa con plan non 'done' (deve dare errore)
- [ ] Testa con plan inesistente (deve dare errore)

**Test: POST /api/plan/:id/unarchive**
- [ ] Archivia un plan
- [ ] Unarchive plan
- [ ] Verifica che file tornino in ~/.claude/plans/active/{project}/
- [ ] Verifica che archived_at e archived_path siano NULL
- [ ] Testa con plan non archiviato (deve dare errore)

---

## 2. Frontend Component Tests

### 2.1 Unified Waves Card

**Test: Rendering**
- [ ] Apri dashboard con progetto che ha waves
- [ ] Verifica che unified-waves-card venga renderizzato
- [ ] Verifica che header mostri current wave (wave_id, name, status)
- [ ] Verifica progress bar (tasks_done/tasks_total)
- [ ] Verifica status badge colore corretto (in_progress=orange, done=green)

**Test: Tree Expansion/Collapse**
- [ ] Click su header per expand/collapse tree
- [ ] Verifica che icona toggle ruoti correttamente
- [ ] Click su wave node per espandere tasks
- [ ] Verifica che icona wave passi da ▶ a ▼
- [ ] Click su task node per vedere details
- [ ] Verifica che details mostrino status, assignee, tokens, session_id

**Test: Expand All / Collapse All**
- [ ] Click "Expand All" button
- [ ] Verifica che tutti i wave node si espandano
- [ ] Verifica che tutte le task vengano mostrate
- [ ] Click "Collapse All" button
- [ ] Verifica che tutto si chiuda

**Test: Live Indicator**
- [ ] Crea task con executor_status='running'
- [ ] Verifica che appaia live indicator (● pulsante arancione)
- [ ] Verifica animazione pulse
- [ ] Task completo non deve avere indicator

**Test: View Wave Markdown**
- [ ] Click icona markdown su wave node
- [ ] Verifica che apra markdown viewer
- [ ] Verifica che mostri contenuto wave markdown file

**Test: Action Buttons**
- [ ] Click "View Conversation" button su task
- [ ] Verifica che apra conversation viewer modal
- [ ] Task running deve avere "Watch Live" button
- [ ] Click "Watch Live" deve aprire modal in live mode

### 2.2 Conversation Viewer Modal

**Test: Modal Opening**
- [ ] Click "View Conversation" da unified waves card
- [ ] Verifica che modal appaia con overlay blur
- [ ] Verifica che header mostri task_id e title
- [ ] Verifica status badge corretto

**Test: Stats Display**
- [ ] Verifica che stats mostrino message count
- [ ] Verifica tool calls count
- [ ] Verifica duration calculation
- [ ] Verifica total tokens (se disponibile)

**Test: Messages Rendering**
- [ ] Verifica user messages (sfondo viola, border viola)
- [ ] Verifica assistant messages (sfondo verde, border verde)
- [ ] Verifica system messages (sfondo grigio)
- [ ] Verifica tool messages (sfondo arancione)
- [ ] Verifica timestamp formattato (HH:MM:SS)

**Test: Tool Call Expansion**
- [ ] Tool messages devono essere collapsed di default
- [ ] Click su tool message header per espandere
- [ ] Verifica che mostri tool_input (JSON formattato)
- [ ] Verifica che mostri tool_output (JSON formattato)
- [ ] Verifica icona toggle (▶/▼)

**Test: Live Mode (SSE Streaming)**
- [ ] Apri conversation viewer per task running in live mode
- [ ] Verifica badge "● LIVE" verde con animazione pulse
- [ ] Log un nuovo messaggio (via executor)
- [ ] Verifica che appaia immediatamente nella modal
- [ ] Verifica auto-scroll to bottom
- [ ] Testa disconnessione SSE (deve mostrare notice "Live stream disconnected")

**Test: Export to Markdown**
- [ ] Click "Export to Markdown" button
- [ ] Verifica download file conversation-{taskId}-{timestamp}.md
- [ ] Apri file e verifica formato corretto
- [ ] Verifica che includa timestamp, role, content
- [ ] Verifica che tool calls siano formattati con code blocks JSON

**Test: Modal Close**
- [ ] Click X button per chiudere
- [ ] Verifica che SSE stream venga chiuso (se live mode)
- [ ] Riapri modal e verifica che funzioni ancora

### 2.3 Bug/Todo List

**Test: Initial Render**
- [ ] Apri dashboard
- [ ] Verifica bug list card nel right panel
- [ ] Se nessun bug, verifica empty state ("No bugs or todos yet")
- [ ] Verifica "+ Add First Item" button

**Test: Add Bug Item**
- [ ] Click "+ Add" button
- [ ] Verifica che appaia input field in edit mode
- [ ] Verifica autofocus su input
- [ ] Digita testo e premi Enter
- [ ] Verifica che bug venga salvato e mostrato nella lista

**Test: Edit Bug Item**
- [ ] Click su bug item text per editare
- [ ] Modifica testo
- [ ] Premi Enter per salvare
- [ ] Verifica che testo venga aggiornato
- [ ] Premi Escape durante edit per cancellare
- [ ] Verifica che torni al valore precedente

**Test: Toggle Done**
- [ ] Click checkbox su bug item
- [ ] Verifica che testo diventi strikethrough
- [ ] Verifica opacity 0.6
- [ ] Click di nuovo per uncheck
- [ ] Verifica che torni normale

**Test: Set Priority**
- [ ] Seleziona P0 dal dropdown
- [ ] Verifica badge rosso con testo "P0"
- [ ] Seleziona P1 (arancione)
- [ ] Seleziona P2 (grigio)
- [ ] Seleziona "-" per rimuovere priority

**Test: Delete Bug Item**
- [ ] Click delete button (×)
- [ ] Verifica confirmation dialog
- [ ] Conferma e verifica che item venga rimosso
- [ ] Annulla e verifica che item rimanga

**Test: LocalStorage Persistence**
- [ ] Aggiungi 3 bug items
- [ ] Ricarica pagina (F5)
- [ ] Verifica che tutti i bug items siano ancora presenti
- [ ] Verifica che priority e done status siano preservati

**Test: Project-Specific Bugs**
- [ ] Aggiungi bug nel project A
- [ ] Cambia progetto a B
- [ ] Verifica che bug list sia vuota
- [ ] Torna a project A
- [ ] Verifica che bug items tornino visibili

### 2.4 Planner Execution Modal

**Test: Opening Modal**
- [ ] Aggiungi 3 bug items (uno con priority P0)
- [ ] Click "⚡ Execute with Planner" button
- [ ] Verifica che modal appaia con items list
- [ ] Verifica che P0 bug abbia border rosso

**Test: Generated Prompt**
- [ ] Verifica che prompt includa project name
- [ ] Verifica data formattata (it-IT locale)
- [ ] Verifica numerazione bug items (1. 2. 3.)
- [ ] Verifica che priority appaia [P0] [P1]
- [ ] Verifica che completed bugs NON siano inclusi

**Test: Edit Prompt**
- [ ] Modifica testo nel textarea
- [ ] Aggiungi contesto extra
- [ ] Verifica che hint dica "You can edit the prompt..."

**Test: Archive Option**
- [ ] Verifica checkbox "Archive completed bugs after plan creation" checked
- [ ] Uncheck e verifica che non archivia
- [ ] Check e verifica che archivia dopo 5 secondi

**Test: Send to Planner**
- [ ] Click "Send to Planner" button
- [ ] Verifica toast "Command copied to clipboard!"
- [ ] Verifica che modal si chiuda
- [ ] Verifica che instruction modal appaia

**Test: Instruction Modal**
- [ ] Verifica green checkmark icon
- [ ] Verifica "Command copied to clipboard!" message
- [ ] Verifica 5 steps nella lista
- [ ] Verifica command preview con testo completo
- [ ] Verifica escape delle quote nel comando

**Test: Copy to Clipboard**
- [ ] Dopo send, apri terminale
- [ ] Paste (Cmd+V)
- [ ] Verifica che comando sia `claude "...prompt..."`
- [ ] Verifica che quote siano escapate correttamente

**Test: Archive After Send**
- [ ] Send to planner con archive option checked
- [ ] Aspetta 5 secondi
- [ ] Verifica che tutti i bug items siano marcati done
- [ ] Verifica che localStorage sia aggiornato

---

## 3. Integration Tests

### 3.1 Full Executor Tracking Workflow

**Test: Task Execution Lifecycle**
1. [ ] Crea plan con task T1
2. [ ] Executor agent inizia T1 → POST /executor/start
3. [ ] Verifica che unified waves card mostri T1 con live indicator
4. [ ] Executor invia heartbeat ogni 30s
5. [ ] Verifica che v_active_executions mostri T1 con recent activity
6. [ ] Executor logga messaggi → POST /conversation/log
7. [ ] Apri conversation viewer in live mode
8. [ ] Verifica SSE stream attivo
9. [ ] Executor completa task → POST /executor/complete
10. [ ] Verifica che live indicator scompaia
11. [ ] Verifica che conversation viewer mostri tutti i messaggi

**Test: Multiple Concurrent Tasks**
1. [ ] Avvia 2 task in parallelo (T1, T2)
2. [ ] Verifica che entrambi abbiano live indicators
3. [ ] Verifica che GET /monitoring/sessions mostri 2 sessioni
4. [ ] Apri conversation viewer per T1
5. [ ] Verifica SSE solo per T1 (non mix con T2)
6. [ ] Completa T1, verifica che T2 rimanga running

### 3.2 Bug List → Planner → Execution

**Test: Complete Workflow**
1. [ ] Aggiungi 5 bugs con mix di priority
2. [ ] Click "Execute with Planner"
3. [ ] Modifica prompt per aggiungere contesto
4. [ ] Send to planner (archive option checked)
5. [ ] Paste comando in terminale e avvia claude
6. [ ] Claude legge bugs, fa domande, crea plan
7. [ ] Verifica che bug items siano marcati done dopo 5 secondi
8. [ ] Plan eseguito da executor
9. [ ] Verifica tracking in real-time via conversation viewer

### 3.3 Plan Archiving Workflow

**Test: Archive Completed Plan**
1. [ ] Completa tutti i task di un plan
2. [ ] Plan status diventa 'done'
3. [ ] POST /api/plan/:id/archive
4. [ ] Verifica file spostati in ~/.claude/plans/archived/2026-01/{project}/
5. [ ] Verifica che dashboard non mostri più il plan nei active
6. [ ] Unarchive plan
7. [ ] Verifica file tornati in active
8. [ ] Verifica che dashboard mostri di nuovo il plan

---

## 4. End-to-End Tests

### 4.1 Real Task Execution with Live Tracking

**Prerequisites:**
- Plan attivo con almeno 1 task pending
- Executor agent configurato con tracking hooks

**Steps:**
1. [ ] Apri dashboard
2. [ ] Verifica unified waves card mostra plan corrente
3. [ ] Avvia executor agent su un task
4. [ ] Verifica che live indicator appaia nel tree
5. [ ] Click "Watch Live" button
6. [ ] Verifica conversation viewer in live mode
7. [ ] Monitora messaggi che arrivano in real-time
8. [ ] Verifica tool calls vengano loggati
9. [ ] Espandi tool call e verifica input/output JSON
10. [ ] Task completa
11. [ ] Verifica status aggiornato
12. [ ] Export conversation to markdown
13. [ ] Verifica file scaricato con tutti i dati

### 4.2 Multiple Projects Bug Management

**Steps:**
1. [ ] Project A: aggiungi 3 bugs
2. [ ] Project B: aggiungi 2 bugs
3. [ ] Switch da A a B
4. [ ] Verifica solo 2 bugs di B visibili
5. [ ] Execute planner per B
6. [ ] Verifica command generato include solo bugs di B
7. [ ] Switch a project A
8. [ ] Verifica 3 bugs di A ancora presenti
9. [ ] Complete 1 bug di A
10. [ ] Reload dashboard
11. [ ] Verifica persistence (2 active, 1 done in A)

### 4.3 Wave Tree Navigation Stress Test

**Steps:**
1. [ ] Plan con 5 waves, ogni wave con 10 tasks
2. [ ] Expand all waves
3. [ ] Verifica che tutte le 50 task siano visibili
4. [ ] Scroll performance test
5. [ ] Collapse all
6. [ ] Expand singola wave
7. [ ] Expand singolo task per vedere details
8. [ ] Click markdown viewer su wave
9. [ ] Chiudi viewer
10. [ ] Ripeti per ogni wave

---

## 5. Executor Integration (Not Yet Implemented)

### 5.1 Hooks da Aggiungere all'Executor Agent

**Location:** Trovare file executor agent implementation

**Hook Points:**
```javascript
// 1. Task Start
await fetch(`${DASHBOARD_API}/project/${projectId}/task/${taskId}/executor/start`, {
  method: 'POST',
  headers: { 'Content-Type': 'application/json' },
  body: JSON.stringify({
    session_id: uuidv4(),
    metadata: { agent_version: '1.0' }
  })
});

// 2. Heartbeat (ogni 30s)
setInterval(async () => {
  await fetch(`${DASHBOARD_API}/project/${projectId}/task/${taskId}/executor/heartbeat`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({ session_id })
  });
}, 30000);

// 3. Conversation Log
async function logMessage(role, content, toolName = null, toolInput = null, toolOutput = null) {
  await fetch(`${DASHBOARD_API}/project/${projectId}/task/${taskId}/conversation/log`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({
      session_id,
      role,
      content,
      tool_name: toolName,
      tool_input: toolInput ? JSON.stringify(toolInput) : null,
      tool_output: toolOutput ? JSON.stringify(toolOutput) : null,
      metadata: { timestamp: new Date().toISOString() }
    })
  });
}

// 4. Task Complete
await fetch(`${DASHBOARD_API}/project/${projectId}/task/${taskId}/executor/complete`, {
  method: 'POST',
  headers: { 'Content-Type': 'application/json' },
  body: JSON.stringify({
    session_id,
    success: true,
    metadata: { completed_at: new Date().toISOString() }
  })
});
```

**Test Hooks:**
- [ ] Avvia task manualmente e verifica che POST /start venga chiamata
- [ ] Verifica heartbeat ogni 30s
- [ ] Simula user message e verifica log
- [ ] Simula tool call e verifica input/output loggati
- [ ] Completa task e verifica POST /complete

---

## 6. Task Markdown Generation (Not Yet Implemented)

### 6.1 Modifiche al Planner

**Location:** Trovare planner implementation

**Requirements:**
1. [ ] Quando planner genera wave markdown, generare anche task.md files
2. [ ] Directory structure: `plan-X/waves/WX/tasks/TX-taskname.md`
3. [ ] Popolare tasks.markdown_path nel database
4. [ ] Template task markdown:

```markdown
# Task: TX - Task Name

**Wave:** WX
**Status:** pending
**Priority:** P1
**Assignee:** agent-name
**Created:** 2026-01-05 14:30 CET

---

## Description

[Task description here]

## Acceptance Criteria

- [ ] Criterion 1
- [ ] Criterion 2
- [ ] Criterion 3

## Execution Log

[Empty initially, populated during execution]

## File Changes

[Empty initially, populated during execution]

## Validation

[Empty initially, populated after completion]

---

**Links:**
- Wave: [WX-wave-name.md](../../WX-wave-name.md)
- Plan: [plan-X.md](../../../../plan-X.md)
```

**Test Task Markdown:**
- [ ] Genera plan con planner
- [ ] Verifica che task.md files esistano
- [ ] Verifica directory structure corretta
- [ ] Verifica markdown_path popolato nel DB
- [ ] Verifica links relativi funzionanti

---

## 7. Browser Compatibility Tests

**Test su:**
- [ ] Chrome (latest)
- [ ] Firefox (latest)
- [ ] Safari (latest)
- [ ] Edge (latest)

**Features da testare:**
- [ ] SSE EventSource API
- [ ] Clipboard API (navigator.clipboard.writeText)
- [ ] LocalStorage persistence
- [ ] CSS animations (pulse, transitions)
- [ ] Modal backdrop blur filter

---

## 8. Performance Tests

**Test: Large Dataset**
- [ ] Plan con 100 waves, 1000 tasks
- [ ] Verifica rendering time < 2s
- [ ] Verifica scroll smoothness
- [ ] Verifica memory usage

**Test: SSE Long Connection**
- [ ] Mantieni SSE connection aperta per 1 ora
- [ ] Verifica no memory leaks
- [ ] Verifica keepalive ping regolare
- [ ] Verifica disconnection/reconnection handling

**Test: LocalStorage Size**
- [ ] Aggiungi 500 bug items
- [ ] Verifica che LocalStorage non ecceda 5MB
- [ ] Verifica performance rendering

---

## 9. Error Handling Tests

**Test: Network Errors**
- [ ] Disconnect network durante SSE stream
- [ ] Verifica graceful error handling
- [ ] Reconnect e verifica recovery

**Test: Invalid Data**
- [ ] Send malformed JSON a POST endpoints
- [ ] Verifica 400 Bad Request
- [ ] Send task_id inesistente
- [ ] Verifica 404 Not Found

**Test: Concurrent Modifications**
- [ ] Due browser tabs aperti
- [ ] Modifica bug list in tab 1
- [ ] Tab 2 non si aggiorna (expected - LocalStorage)
- [ ] Reload tab 2, verifica sync

---

## 10. Security Tests

**Test: XSS Prevention**
- [ ] Aggiungi bug con `<script>alert('xss')</script>` nel testo
- [ ] Verifica che venga escapato (escapeHtml function)
- [ ] Verifica che non esegua JavaScript

**Test: SQL Injection**
- [ ] Send task_id con SQL injection attempt
- [ ] Verifica che query siano parametrizzate
- [ ] Nessun errore SQL

**Test: API Authentication**
- [ ] Verifica che API sia accessibile solo da localhost
- [ ] Test CORS headers

---

## Completion Checklist

**Frontend:**
- [ ] Unified waves card renderizzato correttamente
- [ ] Tree navigation funzionante (expand/collapse)
- [ ] Live indicators visibili per running tasks
- [ ] Conversation viewer apre e chiude correttamente
- [ ] SSE streaming funziona in live mode
- [ ] Tool calls espandibili con JSON formattato
- [ ] Export markdown scarica file corretto
- [ ] Bug list add/edit/delete funzionano
- [ ] Priority selection funziona
- [ ] Done checkbox funziona
- [ ] LocalStorage persistence OK
- [ ] Planner execution modal funziona
- [ ] Command copy to clipboard OK
- [ ] Instruction modal con steps chiari

**Backend:**
- [ ] Tutti i monitoring endpoints rispondono
- [ ] SSE endpoint stream messages correttamente
- [ ] Conversation logging funziona
- [ ] Plan archiving sposta file correttamente
- [ ] Plan unarchiving ripristina file
- [ ] Database migration applicata senza errori
- [ ] Views (v_active_executions, v_task_conversations) funzionano

**Integration:**
- [ ] Executor hooks implementati (DA FARE)
- [ ] Task markdown generation implementata (DA FARE)
- [ ] End-to-end workflow testato
- [ ] Performance accettabile con dataset realistici
- [ ] No memory leaks in SSE connections
- [ ] Cross-browser compatibility OK

---

**Notes:**
- Test con [ ] sono da eseguire
- Test con [x] sono completati con successo
- Priorità: P0 test critici, P1 importanti, P2 nice-to-have
