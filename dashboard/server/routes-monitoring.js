// Executor Session Monitoring and Conversation Logs Routes

const { query } = require('./db');

const routes = {
  // Get active executor sessions for all tasks
  'GET /api/monitoring/sessions': () => {
    return query(`
      SELECT * FROM v_active_executions
      ORDER BY executor_last_activity DESC
    `);
  },

  // Get session info for specific task
  'GET /api/project/:projectId/task/:taskId/session': (params) => {
    const rows = query(`
      SELECT
        t.id,
        t.project_id,
        t.wave_id,
        t.task_id,
        t.title,
        t.status,
        t.executor_session_id,
        t.executor_status,
        t.executor_started_at,
        t.executor_last_activity,
        (julianday('now') - julianday(t.executor_last_activity)) * 24 * 60 AS minutes_since_activity,
        w.name AS wave_name,
        p.name AS plan_name
      FROM tasks t
      JOIN waves w ON t.wave_id = w.wave_id AND t.project_id = w.project_id
      LEFT JOIN plans p ON w.plan_id = p.id
      WHERE t.project_id = '${params.projectId}' AND t.task_id = '${params.taskId}'
      LIMIT 1
    `);

    if (rows.length === 0) {
      return { error: 'Task not found' };
    }

    const task = rows[0];

    // Get conversation summary
    if (task.executor_session_id) {
      const convSummary = query(`
        SELECT * FROM v_task_conversations
        WHERE task_id = ${task.id}
        ORDER BY last_activity DESC
        LIMIT 1
      `);
      task.conversation_summary = convSummary[0] || null;
    }

    return task;
  },

  // Get conversation logs for specific task
  'GET /api/project/:projectId/task/:taskId/conversation': (params) => {
    // Get task ID from task_id string
    const tasks = query(`
      SELECT id FROM tasks
      WHERE project_id = '${params.projectId}' AND task_id = '${params.taskId}'
      LIMIT 1
    `);

    if (tasks.length === 0) {
      return { error: 'Task not found' };
    }

    const taskId = tasks[0].id;

    return query(`
      SELECT
        id,
        timestamp,
        role,
        content,
        tool_name,
        tool_input,
        tool_output,
        metadata
      FROM conversation_logs
      WHERE task_id = ${taskId}
      ORDER BY timestamp ASC
    `);
  },

  // SSE stream for real-time task execution monitoring
  'GET /api/project/:projectId/task/:taskId/live': (params, req, res) => {
    // SSE headers
    res.writeHead(200, {
      'Content-Type': 'text/event-stream',
      'Cache-Control': 'no-cache',
      'Connection': 'keep-alive',
      'Access-Control-Allow-Origin': '*'
    });

    // Get task ID
    const tasks = query(`
      SELECT id, executor_session_id FROM tasks
      WHERE project_id = '${params.projectId}' AND task_id = '${params.taskId}'
      LIMIT 1
    `);

    if (tasks.length === 0) {
      res.write(`data: ${JSON.stringify({ error: 'Task not found' })}\n\n`);
      res.end();
      return;
    }

    const taskId = tasks[0].id;
    const sessionId = tasks[0].executor_session_id;

    // Send initial state
    const initialConv = query(`
      SELECT * FROM conversation_logs
      WHERE task_id = ${taskId}
      ORDER BY timestamp DESC
      LIMIT 1
    `);

    res.write(`data: ${JSON.stringify({ type: 'initial', message: initialConv[0] || null })}\n\n`);

    // Poll for new messages every 2 seconds
    let lastTimestamp = initialConv[0]?.timestamp || '1970-01-01 00:00:00';

    const pollInterval = setInterval(() => {
      try {
        const newMessages = query(`
          SELECT * FROM conversation_logs
          WHERE task_id = ${taskId}
            AND timestamp > '${lastTimestamp}'
          ORDER BY timestamp ASC
        `);

        if (newMessages.length > 0) {
          newMessages.forEach(msg => {
            res.write(`data: ${JSON.stringify({ type: 'message', message: msg })}\n\n`);
          });
          lastTimestamp = newMessages[newMessages.length - 1].timestamp;
        }

        // Send keepalive ping every poll
        res.write(`:keepalive\n\n`);
      } catch (err) {
        console.error('SSE poll error:', err);
        clearInterval(pollInterval);
        res.end();
      }
    }, 2000);

    // Clean up on connection close
    req.on('close', () => {
      clearInterval(pollInterval);
      res.end();
    });

    // Return 'handled' to prevent default JSON response
    return { _sse_handled: true };
  },

  // Get all conversation logs for a wave (all tasks)
  'GET /api/project/:projectId/wave/:waveId/conversations': (params) => {
    return query(`
      SELECT
        c.id,
        c.task_id,
        c.session_id,
        c.timestamp,
        c.role,
        c.content,
        c.tool_name,
        t.task_id AS task_code,
        t.title AS task_title
      FROM conversation_logs c
      JOIN tasks t ON c.task_id = t.id
      WHERE t.project_id = '${params.projectId}'
        AND t.wave_id = '${params.waveId}'
      ORDER BY c.timestamp ASC
    `);
  },

  // Mark task executor as started (called by executor agent)
  'POST /api/project/:projectId/task/:taskId/executor/start': (params, req, res, body) => {
    const data = JSON.parse(body);
    const sessionId = data.session_id;
    const agent = data.agent || 'executor';

    // Update task with executor info
    query(`
      UPDATE tasks
      SET executor_session_id = '${sessionId}',
          executor_started_at = datetime('now'),
          executor_last_activity = datetime('now'),
          executor_status = 'running'
      WHERE project_id = '${params.projectId}' AND task_id = '${params.taskId}'
    `);

    return { success: true };
  },

  // Update executor heartbeat (called periodically by executor)
  'POST /api/project/:projectId/task/:taskId/executor/heartbeat': (params) => {
    query(`
      UPDATE tasks
      SET executor_last_activity = datetime('now')
      WHERE project_id = '${params.projectId}' AND task_id = '${params.taskId}'
    `);

    return { success: true };
  },

  // Mark task executor as completed
  'POST /api/project/:projectId/task/:taskId/executor/complete': (params, req, res, body) => {
    const data = JSON.parse(body);
    const status = data.status || 'completed'; // 'completed' or 'failed'

    query(`
      UPDATE tasks
      SET executor_last_activity = datetime('now'),
          executor_status = '${status}'
      WHERE project_id = '${params.projectId}' AND task_id = '${params.taskId}'
    `);

    return { success: true };
  },

  // Log conversation message (called by executor during execution)
  'POST /api/project/:projectId/task/:taskId/conversation/log': (params, req, res, body) => {
    const data = JSON.parse(body);

    // Get task ID from task_id string
    const tasks = query(`
      SELECT id FROM tasks
      WHERE project_id = '${params.projectId}' AND task_id = '${params.taskId}'
      LIMIT 1
    `);

    if (tasks.length === 0) {
      return { error: 'Task not found' };
    }

    const taskId = tasks[0].id;

    // Insert conversation log entry
    const role = data.role || 'system';
    const content = data.content ? data.content.replace(/'/g, "''") : null;
    const toolName = data.tool_name ? data.tool_name.replace(/'/g, "''") : null;
    const toolInput = data.tool_input ? JSON.stringify(data.tool_input).replace(/'/g, "''") : null;
    const toolOutput = data.tool_output ? JSON.stringify(data.tool_output).replace(/'/g, "''") : null;
    const metadata = data.metadata ? JSON.stringify(data.metadata).replace(/'/g, "''") : null;

    query(`
      INSERT INTO conversation_logs (
        task_id, session_id, role, content,
        tool_name, tool_input, tool_output, metadata
      ) VALUES (
        ${taskId},
        '${data.session_id}',
        '${role}',
        ${content ? `'${content}'` : 'NULL'},
        ${toolName ? `'${toolName}'` : 'NULL'},
        ${toolInput ? `'${toolInput}'` : 'NULL'},
        ${toolOutput ? `'${toolOutput}'` : 'NULL'},
        ${metadata ? `'${metadata}'` : 'NULL'}
      )
    `);

    // Update last activity
    query(`
      UPDATE tasks
      SET executor_last_activity = datetime('now')
      WHERE id = ${taskId}
    `);

    return { success: true, logged_at: new Date().toISOString() };
  }
};

module.exports = routes;
