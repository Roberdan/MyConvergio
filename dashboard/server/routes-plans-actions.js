// Plan Actions Routes (POST updates)

const { execSync } = require('child_process');
const { query, escapeSQL, CLAUDE_HOME } = require('./db');

const routes = {
  // Update task status
  'POST /api/task/:id/status': (params, req, res, body) => {
    const data = JSON.parse(body);
    const taskId = parseInt(params.id, 10);
    if (isNaN(taskId)) return { error: 'Invalid task ID' };
    const { status, notes } = data;
    const validStatuses = ['pending', 'in_progress', 'done', 'blocked', 'skipped'];
    if (!validStatuses.includes(status)) return { error: 'Invalid status' };
    // Sanitize notes for shell - escape single quotes and remove dangerous chars
    const safeNotes = (notes || '').replace(/'/g, "'\\''").replace(/[;&|`$]/g, '');
    execSync(`${CLAUDE_HOME}/scripts/plan-db.sh update-task ${taskId} ${status} '${safeNotes}'`, {
      encoding: 'utf-8'
    });
    return { success: true, task_id: taskId, status };
  },

  // Update wave status
  'POST /api/wave/:id/status': (params, req, res, body) => {
    const data = JSON.parse(body);
    const waveId = parseInt(params.id, 10);
    if (isNaN(waveId)) return { error: 'Invalid wave ID' };
    const validStatuses = ['pending', 'in_progress', 'done', 'blocked'];
    if (!validStatuses.includes(data.status)) return { error: 'Invalid status' };
    execSync(`${CLAUDE_HOME}/scripts/plan-db.sh update-wave ${waveId} ${data.status}`, {
      encoding: 'utf-8'
    });
    return { success: true, wave_id: waveId, status: data.status };
  },

  // Update plan status (for Kanban drag & drop)
  'POST /api/plan/:id/status': (params, req, res, body) => {
    const data = JSON.parse(body);
    const planId = parseInt(params.id, 10);
    if (isNaN(planId)) return { error: 'Invalid plan ID' };
    const { status } = data;
    const validStatuses = ['todo', 'doing', 'done'];
    if (!validStatuses.includes(status)) {
      return { success: false, error: `Invalid status. Must be one of: ${validStatuses.join(', ')}` };
    }

    // Set appropriate timestamps based on new status
    let timestampUpdate = '';
    if (status === 'doing') {
      timestampUpdate = ", started_at = COALESCE(started_at, datetime('now'))";
    } else if (status === 'done') {
      timestampUpdate = ", completed_at = datetime('now')";
    } else if (status === 'todo') {
      timestampUpdate = ", started_at = NULL, completed_at = NULL";
    }

    query(`UPDATE plans SET status = '${status}'${timestampUpdate} WHERE id = ${planId}`);
    return { success: true, plan_id: planId, status };
  },

  // Validate plan (Thor)
  'POST /api/plan/:id/validate': (params, req, res, body) => {
    const data = JSON.parse(body);
    const planId = parseInt(params.id, 10);
    if (isNaN(planId)) return { error: 'Invalid plan ID' };
    const validatedBy = (data.by || 'thor').replace(/[^a-zA-Z0-9_-]/g, '');
    execSync(`${CLAUDE_HOME}/scripts/plan-db.sh validate ${planId} ${validatedBy}`, {
      encoding: 'utf-8'
    });
    return { success: true, plan_id: planId, validated_by: validatedBy };
  },

  // Record token usage (called by agents/hooks)
  'POST /api/tokens': (params, req, res, body) => {
    const data = JSON.parse(body);
    const { project_id, plan_id, wave_id, task_id, agent, model, input_tokens, output_tokens, cost_usd } = data;
    const safePlanId = plan_id ? parseInt(plan_id, 10) : null;
    const safeInputTokens = parseInt(input_tokens, 10) || 0;
    const safeOutputTokens = parseInt(output_tokens, 10) || 0;
    const safeCost = parseFloat(cost_usd) || 0;
    query(`
      INSERT INTO token_usage (project_id, plan_id, wave_id, task_id, agent, model, input_tokens, output_tokens, cost_usd)
      VALUES ('${escapeSQL(project_id)}', ${safePlanId || 'NULL'}, '${escapeSQL(wave_id || '')}', '${escapeSQL(task_id || '')}', '${escapeSQL(agent)}', '${escapeSQL(model)}', ${safeInputTokens}, ${safeOutputTokens}, ${safeCost})
    `);
    return { success: true };
  }
};

module.exports = routes;

