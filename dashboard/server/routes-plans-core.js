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

   // Project dashboard stats (aggregated data for main dashboard)
   'GET /api/project/:id/dashboard': (params) => {
     const project = query(`SELECT * FROM projects WHERE id = '${escapeSQL(params.id)}'`)[0];
     if (!project) return { error: 'Project not found' };

     // Get all plans for this project
     const plans = query(`
       SELECT id, name, status, tasks_done, tasks_total, created_at, started_at, completed_at
       FROM plans WHERE project_id = '${escapeSQL(params.id)}'
       ORDER BY is_master DESC, status, created_at DESC
     `);

     // Calculate aggregated metrics
     const totalTasks = plans.reduce((sum, p) => sum + (p.tasks_total || 0), 0);
     const completedTasks = plans.reduce((sum, p) => sum + (p.tasks_done || 0), 0);
     const donePlans = plans.filter(p => p.status === 'done').length;
     const doingPlans = plans.filter(p => p.status === 'doing').length;
     const totalPlans = plans.length;

     // Get token usage for this project
     const tokenStats = query(`
       SELECT
         SUM(total_tokens) as total_tokens,
         SUM(cost_usd) as total_cost,
         COUNT(*) as api_calls,
         ROUND(AVG(total_tokens)) as avg_tokens_per_call
       FROM token_usage
       WHERE plan_id IN (SELECT id FROM plans WHERE project_id = '${escapeSQL(params.id)}')
     `)[0] || { total_tokens: 0, total_cost: 0, api_calls: 0, avg_tokens_per_call: 0 };

     // Calculate average tokens per task
     const avgTokensPerTask = completedTasks > 0 ? Math.round(tokenStats.total_tokens / completedTasks) : 0;

     // Build dashboard data structure
     return {
       meta: {
         project: project.name,
         projectId: project.id
       },
       metrics: {
         throughput: {
           done: completedTasks,
           total: totalTasks,
           percent: totalTasks > 0 ? Math.round((completedTasks / totalTasks) * 100) : 0
         }
       },
       tokens: {
         total: tokenStats.total_tokens,
         avgPerTask: avgTokensPerTask,
         totalCost: tokenStats.total_cost,
         apiCalls: tokenStats.api_calls
       },
       waves: plans.map(p => ({
         id: `P${p.id}`,
         name: p.name,
         status: p.status,
         done: p.tasks_done || 0,
         total: p.tasks_total || 0
       })),
       plans: {
         total: totalPlans,
         done: donePlans,
         doing: doingPlans,
         todo: totalPlans - donePlans - doingPlans
       }
     };
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
          FROM tasks WHERE plan_id = ${planId} AND wave_id_fk = ${wave.id}
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
  },

  // Create new plan
  'POST /api/plans': (params, req, res, body) => {
    try {
      const data = JSON.parse(body);
      const { name, project_id, status = 'todo', waves = [] } = data;

      if (!name || !project_id) {
        return { error: 'Plan name and project_id are required' };
      }

      // Calculate totals
      const tasks_total = waves.reduce((sum, wave) => sum + (wave.tasks_total || 0), 0);
      const tasks_done = waves.reduce((sum, wave) => sum + (wave.tasks_done || 0), 0);

      // Insert plan
      const planResult = query(`
        INSERT INTO plans (project_id, name, status, tasks_total, tasks_done, created_at)
        VALUES ('${escapeSQL(project_id)}', '${escapeSQL(name)}', '${escapeSQL(status)}',
                ${tasks_total}, ${tasks_done}, CURRENT_TIMESTAMP)
      `);

      const planId = planResult.insertId;

      // Insert waves and tasks
      waves.forEach((wave, waveIndex) => {
        query(`
          INSERT INTO waves (plan_id, wave_id, name, status, assignee, tasks_done, tasks_total,
                            position, depends_on, estimated_hours, planned_start, planned_end, created_at)
          VALUES (${planId}, '${escapeSQL(wave.wave_id)}', '${escapeSQL(wave.name)}',
                  '${escapeSQL(wave.status || 'pending')}', ${wave.assignee ? `'${escapeSQL(wave.assignee)}'` : 'NULL'},
                  ${wave.tasks_done || 0}, ${wave.tasks_total || 0}, ${waveIndex + 1},
                  ${wave.depends_on ? `'${escapeSQL(wave.depends_on)}'` : 'NULL'},
                  ${wave.estimated_hours || 'NULL'}, ${wave.planned_start ? `'${escapeSQL(wave.planned_start)}'` : 'NULL'},
                  ${wave.planned_end ? `'${escapeSQL(wave.planned_end)}'` : 'NULL'}, CURRENT_TIMESTAMP)
        `);

        // Insert tasks for this wave
        if (wave.tasks && wave.tasks.length > 0) {
          wave.tasks.forEach(task => {
            query(`
              INSERT INTO tasks (project_id, plan_id, wave_id, task_id, title, status, assignee,
                                priority, type, tokens, created_at)
              VALUES ('${escapeSQL(project_id)}', ${planId}, '${escapeSQL(wave.wave_id)}',
                      '${escapeSQL(task.task_id)}', '${escapeSQL(task.title)}',
                      '${escapeSQL(task.status || 'pending')}',
                      ${task.assignee ? `'${escapeSQL(task.assignee)}'` : 'NULL'},
                      '${escapeSQL(task.priority || 'P3')}', '${escapeSQL(task.type || 'task')}',
                      ${task.tokens || 0}, CURRENT_TIMESTAMP)
            `);
          });
        }
      });

      return { id: planId, name, project_id, status, tasks_total, tasks_done, waves_count: waves.length };
    } catch (e) {
      console.error('Failed to create plan:', e);
      return { error: 'Failed to create plan: ' + e.message };
    }
  },

  // Fix data consistency issues
  'POST /api/admin/fix-consistency': () => {
    // Fix plans marked as done but with incomplete tasks
    query(`
      UPDATE plans
      SET status = 'todo'
      WHERE status = 'done' AND (tasks_done IS NULL OR tasks_done = 0) AND tasks_total > 0
    `);

    // Fix plans with tasks_done > tasks_total
    query(`
      UPDATE plans
      SET tasks_done = tasks_total
      WHERE tasks_done > tasks_total
    `);

    // Fix plans marked as doing but with all tasks completed
    query(`
      UPDATE plans
      SET status = 'done'
      WHERE status = 'doing' AND tasks_done = tasks_total AND tasks_total > 0
    `);

    return { message: 'Data consistency fixed', fixed: true };
  }
};

module.exports = routes;

