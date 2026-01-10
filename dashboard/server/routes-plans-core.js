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
        COUNT(p.id) as plans_total
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

     // Get token usage for this project (by project_id directly, since plan_id may be NULL)
     const tokenStats = query(`
       SELECT
         SUM(total_tokens) as total_tokens,
         SUM(cost_usd) as total_cost,
         COUNT(*) as api_calls,
         ROUND(AVG(total_tokens)) as avg_tokens_per_call
       FROM token_usage
       WHERE project_id = '${escapeSQL(params.id)}'
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

     // Get waves with computed started_at from tasks if NULL
     const waves = query(`
       SELECT w.id, w.wave_id, w.name, w.status, w.assignee, w.tasks_done, w.tasks_total,
              COALESCE(w.started_at, (SELECT MIN(t.started_at) FROM tasks t WHERE t.wave_id_fk = w.id)) as started_at,
              COALESCE(w.completed_at, (SELECT MAX(t.completed_at) FROM tasks t WHERE t.wave_id_fk = w.id AND t.status = 'done')) as completed_at,
              w.planned_start, w.planned_end, w.depends_on, w.estimated_hours, w.position
       FROM waves w WHERE w.plan_id = ${planId} ORDER BY w.position
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
  // Aggregates from both token_usage table AND tasks.tokens field
  'GET /api/plan/:id/tokens': (params) => {
    const planId = parseInt(params.id, 10);
    if (isNaN(planId)) return { error: 'Invalid plan ID' };

    // Get tokens from token_usage table (if plan_id is set)
    const tokenUsageStats = query(`
      SELECT
        SUM(total_tokens) as total_tokens,
        SUM(cost_usd) as total_cost,
        COUNT(*) as api_calls,
        ROUND(AVG(total_tokens)) as avg_tokens_per_call
      FROM token_usage WHERE plan_id = ${planId}
    `)[0] || { total_tokens: 0, total_cost: 0, api_calls: 0, avg_tokens_per_call: 0 };

    // Get tokens from tasks table (always populated)
    const taskTokenStats = query(`
      SELECT
        SUM(tokens) as total_tokens,
        COUNT(CASE WHEN tokens > 0 THEN 1 END) as tasks_with_tokens
      FROM tasks WHERE plan_id = ${planId}
    `)[0] || { total_tokens: 0, tasks_with_tokens: 0 };

    // Use task tokens if token_usage is empty (fallback)
    const stats = {
      total_tokens: tokenUsageStats.total_tokens || taskTokenStats.total_tokens || 0,
      total_cost: tokenUsageStats.total_cost || 0,
      api_calls: tokenUsageStats.api_calls || taskTokenStats.tasks_with_tokens || 0,
      avg_tokens_per_call: tokenUsageStats.avg_tokens_per_call ||
        (taskTokenStats.tasks_with_tokens > 0
          ? Math.round(taskTokenStats.total_tokens / taskTokenStats.tasks_with_tokens)
          : 0)
    };

    // Get tokens by wave from tasks
    const byWave = query(`
      SELECT w.wave_id, SUM(t.tokens) as tokens, 0 as cost
      FROM tasks t
      JOIN waves w ON t.wave_id_fk = w.id
      WHERE t.plan_id = ${planId} AND t.tokens > 0
      GROUP BY w.wave_id
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

  // Historical token usage by date for project
  'GET /api/project/:id/tokens/history': (params, req, res, body, url) => {
    const projectId = escapeSQL(params.id);
    const searchParams = url?.searchParams || new URLSearchParams();
    const range = searchParams.get('range') || '7d';

    let timeFilter, groupBy, history;

    if (range === '30m') {
      timeFilter = "created_at >= datetime('now', '-30 minutes')";
      groupBy = "strftime('%Y-%m-%d %H:%M', created_at, 'localtime')";
    } else if (range === '1h') {
      timeFilter = "created_at >= datetime('now', '-1 hour')";
      groupBy = "strftime('%Y-%m-%d %H:%M', created_at, 'localtime')";
    } else if (range === '1d') {
      timeFilter = "created_at >= datetime('now', '-1 day')";
      groupBy = "strftime('%Y-%m-%d %H:00', created_at, 'localtime')";
    } else if (range === '7d') {
      timeFilter = "created_at >= datetime('now', '-7 days')";
      groupBy = "DATE(created_at)";
    } else if (range === '30d') {
      timeFilter = "created_at >= datetime('now', '-30 days')";
      groupBy = "DATE(created_at)";
    } else {
      // 'all' - no time filter
      timeFilter = "1=1";
      groupBy = "DATE(created_at)";
    }

    history = query(`
      SELECT
        ${groupBy} as date,
        SUM(input_tokens) as input,
        SUM(output_tokens) as output,
        SUM(total_tokens) as total,
        COUNT(*) as calls
      FROM token_usage
      WHERE project_id = '${projectId}' AND ${timeFilter}
      GROUP BY ${groupBy}
      ORDER BY date ASC
    `);

    return { history, range };
  },

  // Create new plan
  'POST /api/plans': (params, req, res, body) => {
    try {
      const data = JSON.parse(body);
      const { name, project_id, status = 'todo', waves = [] } = data;

      if (!name || !project_id) {
        return { error: 'Plan name and project_id are required' };
      }

      const safeStatus = ['todo', 'doing', 'done'].includes(status) ? status : 'todo';
      const safeProject = escapeSQL(project_id);
      const safeName = escapeSQL(name);

      // Calculate totals from provided tasks to keep counters consistent
      const tasks_total = waves.reduce((sum, wave) => {
        const waveTasks = Array.isArray(wave.tasks) ? wave.tasks.length : (wave.tasks_total || 0);
        return sum + waveTasks;
      }, 0);

      const tasks_done = waves.reduce((sum, wave) => {
        if (Array.isArray(wave.tasks)) {
          return sum + wave.tasks.filter(t => (t.status || 'pending') === 'done').length;
        }
        return sum + (wave.tasks_done || 0);
      }, 0);

      // Insert plan and capture ID
      const planInsert = query(`
        INSERT INTO plans (project_id, name, status, tasks_total, tasks_done, created_at)
        VALUES ('${safeProject}', '${safeName}', '${escapeSQL(safeStatus)}',
                ${tasks_total}, ${tasks_done}, CURRENT_TIMESTAMP);
        SELECT last_insert_rowid() as id;
      `);

      const planId = planInsert?.[0]?.id;
      if (!planId) {
        throw new Error('Failed to create plan (no id returned)');
      }

      // Insert waves and tasks
      waves.forEach((wave, waveIndex) => {
        const safeWaveId = escapeSQL(wave.wave_id || `W${waveIndex + 1}`);
        const safeWaveName = escapeSQL(wave.name || `Wave ${waveIndex + 1}`);
        const safeWaveStatus = escapeSQL(wave.status || 'pending');
        const safeAssignee = wave.assignee ? `'${escapeSQL(wave.assignee)}'` : 'NULL';
        const safeDepends = wave.depends_on ? `'${escapeSQL(wave.depends_on)}'` : 'NULL';
        const safePlannedStart = wave.planned_start ? `'${escapeSQL(wave.planned_start)}'` : 'NULL';
        const safePlannedEnd = wave.planned_end ? `'${escapeSQL(wave.planned_end)}'` : 'NULL';

        const waveTasks = Array.isArray(wave.tasks) ? wave.tasks : [];
        const waveTasksTotal = waveTasks.length || wave.tasks_total || 0;
        const waveTasksDone = waveTasks.filter(t => (t.status || 'pending') === 'done').length || wave.tasks_done || 0;

        const waveInsert = query(`
          INSERT INTO waves (project_id, plan_id, wave_id, name, status, assignee, tasks_done, tasks_total,
                position, depends_on, estimated_hours, planned_start, planned_end)
          VALUES ('${safeProject}', ${planId}, '${safeWaveId}', '${safeWaveName}',
            '${safeWaveStatus}', ${safeAssignee},
            ${waveTasksDone}, ${waveTasksTotal}, ${waveIndex + 1},
            ${safeDepends},
            ${wave.estimated_hours || 'NULL'}, ${safePlannedStart},
            ${safePlannedEnd});
          SELECT last_insert_rowid() as id;
        `);

        const waveDbId = waveInsert?.[0]?.id;
        if (!waveDbId) {
          throw new Error(`Failed to create wave ${safeWaveId}`);
        }

        // Insert tasks for this wave
        if (waveTasks.length > 0) {
          waveTasks.forEach(task => {
            const safeTaskStatus = escapeSQL(task.status || 'pending');
            const safeTaskPriority = escapeSQL(task.priority || 'P3');
            const safeTaskType = escapeSQL(task.type || 'task');
            const safeTaskAssignee = task.assignee ? `'${escapeSQL(task.assignee)}'` : 'NULL';
            query(`
              INSERT INTO tasks (project_id, plan_id, wave_id, wave_id_fk, task_id, title, status, assignee,
                                priority, type, tokens)
              VALUES ('${safeProject}', ${planId}, '${safeWaveId}', ${waveDbId},
                      '${escapeSQL(task.task_id)}', '${escapeSQL(task.title)}',
                      '${safeTaskStatus}',
                      ${safeTaskAssignee},
                      '${safeTaskPriority}', '${safeTaskType}',
                      ${task.tokens || 0})
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
  },

  // Delete a plan (and all related waves/tasks)
  'DELETE /api/plan/:id': (params) => {
    const planId = parseInt(params.id);
    if (!planId || isNaN(planId)) {
      return { error: 'Invalid plan ID' };
    }

    try {
      // Check if plan exists
      const plan = query(`SELECT id, name FROM plans WHERE id = ${planId}`)[0];
      if (!plan) {
        return { error: 'Plan not found' };
      }

      // Delete tasks first (foreign key dependency)
      query(`DELETE FROM tasks WHERE plan_id = ${planId}`);
      
      // Delete waves
      query(`DELETE FROM waves WHERE plan_id = ${planId}`);
      
      // Delete token usage records
      query(`DELETE FROM token_usage WHERE plan_id = ${planId}`);
      
      // Delete the plan
      query(`DELETE FROM plans WHERE id = ${planId}`);

      return { success: true, deleted: plan.name };
    } catch (e) {
      console.error('Failed to delete plan:', e);
      return { error: 'Failed to delete plan: ' + e.message };
    }
  },

  // Delete a project (only if it has no plans)
  'DELETE /api/project/:id': (params) => {
    const projectId = escapeSQL(params.id);

    try {
      // Check if project exists
      const project = query(`SELECT id, name FROM projects WHERE id = '${projectId}'`)[0];
      if (!project) {
        return { error: 'Project not found' };
      }

      // Check if project has any plans
      const plansCount = query(`SELECT COUNT(*) as count FROM plans WHERE project_id = '${projectId}'`)[0];
      if (plansCount && plansCount.count > 0) {
        return { error: 'Cannot delete project with existing plans' };
      }

      // Delete the project
      query(`DELETE FROM projects WHERE id = '${projectId}'`);

      return { success: true, deleted: project.name };
    } catch (e) {
      console.error('Failed to delete project:', e);
      return { error: 'Failed to delete project: ' + e.message };
    }
  }
};

module.exports = routes;

