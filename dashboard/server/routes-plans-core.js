// Plan, Project, Kanban Core Routes

const { query, escapeSQL } = require('./db');

const routes = {
  // Kanban board - all projects
  'GET /api/kanban': () => {
    return query('SELECT * FROM v_kanban');
  },

  // List projects
  'GET /api/projects': () => {
    return query(`
      SELECT
        pr.id as project_id,
        pr.name as project_name,
        pr.github_url,
        COUNT(CASE WHEN p.status = 'todo' THEN 1 END) as plans_todo,
        COUNT(CASE WHEN p.status = 'doing' THEN 1 END) as plans_doing,
        COUNT(CASE WHEN p.status = 'done' THEN 1 END) as plans_done,
        COUNT(*) as plans_total
      FROM projects pr
      LEFT JOIN plans p ON p.project_id = pr.id
      GROUP BY pr.id
    `);
  },

  // Plans for a project
  'GET /api/plans/:project': (params) => {
    return query(`
      SELECT id, name, is_master, parent_plan_id, status,
             tasks_done, tasks_total,
             CASE WHEN tasks_total > 0 THEN ROUND(100.0 * tasks_done / tasks_total) ELSE 0 END as progress,
             created_at, started_at, completed_at, validated_at, validated_by
      FROM plans
      WHERE project_id = '${escapeSQL(params.project)}'
      ORDER BY is_master DESC, status, name
    `);
  },

  // Single plan with waves and tasks
  'GET /api/plan/:id': (params) => {
    const planId = parseInt(params.id, 10);
    if (isNaN(planId)) return { error: 'Invalid plan ID' };

    const plan = query(`SELECT * FROM plans WHERE id = ${planId}`)[0];
    if (!plan) return { error: 'Plan not found' };

    const waves = query(`
      SELECT id, wave_id, name, status, assignee, tasks_done, tasks_total,
             started_at, completed_at, planned_start, planned_end,
             depends_on, estimated_hours, position
      FROM waves WHERE plan_id = ${planId} ORDER BY position
    `);

    for (const wave of waves) {
      wave.tasks = query(`
        SELECT id, task_id, title, status, assignee, priority, type,
               started_at, completed_at, duration_minutes, tokens, validated_at, validated_by
        FROM tasks WHERE project_id = '${escapeSQL(plan.project_id)}' AND wave_id = '${escapeSQL(wave.wave_id)}'
        ORDER BY task_id
      `);
    }

    plan.waves = waves;
    return plan;
  },

  // Plan versions/history
  'GET /api/plan/:id/history': (params) => {
    const planId = parseInt(params.id, 10);
    if (isNaN(planId)) return { error: 'Invalid plan ID' };
    return query(`
      SELECT version, change_type, change_reason, changed_by, created_at
      FROM plan_versions
      WHERE plan_id = ${planId}
      ORDER BY version DESC
    `);
  },

  // Token usage stats for specific plan
  'GET /api/plan/:id/tokens': (params) => {
    const planId = parseInt(params.id, 10);
    if (isNaN(planId)) return { error: 'Invalid plan ID' };

    const stats = query(`
      SELECT
        SUM(total_tokens) as total_tokens,
        SUM(cost_usd) as total_cost,
        COUNT(*) as api_calls,
        ROUND(AVG(total_tokens)) as avg_tokens_per_call
      FROM token_usage WHERE plan_id = ${planId}
    `)[0] || { total_tokens: 0, total_cost: 0, api_calls: 0, avg_tokens_per_call: 0 };

    const byWave = query(`
      SELECT wave_id, SUM(total_tokens) as tokens, SUM(cost_usd) as cost
      FROM token_usage WHERE plan_id = ${planId} AND wave_id IS NOT NULL
      GROUP BY wave_id
    `);

    const byAgent = query(`
      SELECT agent, SUM(total_tokens) as tokens, COUNT(*) as calls
      FROM token_usage WHERE plan_id = ${planId}
      GROUP BY agent ORDER BY tokens DESC LIMIT 10
    `);

    return { stats, byWave, byAgent };
  },

  // Token usage stats for project
  'GET /api/project/:id/tokens': (params) => {
    const projectId = escapeSQL(params.id);
    const stats = query(`
      SELECT
        SUM(total_tokens) as total_tokens,
        SUM(cost_usd) as total_cost,
        COUNT(*) as api_calls,
        ROUND(AVG(total_tokens)) as avg_tokens_per_call
      FROM token_usage WHERE project_id = '${projectId}'
    `)[0] || { total_tokens: 0, total_cost: 0, api_calls: 0, avg_tokens_per_call: 0 };

    const byPlan = query(`
      SELECT plan_id, SUM(total_tokens) as tokens, SUM(cost_usd) as cost
      FROM token_usage WHERE project_id = '${projectId}' AND plan_id IS NOT NULL
      GROUP BY plan_id
    `);

    const byAgent = query(`
      SELECT agent, SUM(total_tokens) as tokens, COUNT(*) as calls
      FROM token_usage WHERE project_id = '${projectId}'
      GROUP BY agent ORDER BY tokens DESC LIMIT 10
    `);

    return { stats, byPlan, byAgent };
  }
};

module.exports = routes;

