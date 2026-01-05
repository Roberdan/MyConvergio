// Plan, Project, Kanban, and Token Routes

const { execSync } = require('child_process');
const { query, CLAUDE_HOME } = require('./db');
const fs = require('fs');
const path = require('path');

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
      WHERE project_id = '${params.project}'
      ORDER BY is_master DESC, status, name
    `);
  },

  // Single plan with waves and tasks
  'GET /api/plan/:id': (params) => {
    const plan = query(`SELECT * FROM plans WHERE id = ${params.id}`)[0];
    if (!plan) return { error: 'Plan not found' };

    const waves = query(`
      SELECT id, wave_id, name, status, assignee, tasks_done, tasks_total,
             started_at, completed_at, planned_start, planned_end,
             depends_on, estimated_hours, position
      FROM waves WHERE plan_id = ${params.id} ORDER BY position
    `);

    for (const wave of waves) {
      wave.tasks = query(`
        SELECT id, task_id, title, status, assignee, priority, type,
               started_at, completed_at, duration_minutes, tokens, validated_at, validated_by
        FROM tasks WHERE project_id = '${plan.project_id}' AND wave_id = '${wave.wave_id}'
        ORDER BY task_id
      `);
    }

    plan.waves = waves;
    return plan;
  },

  // Plan versions/history
  'GET /api/plan/:id/history': (params) => {
    return query(`
      SELECT version, change_type, change_reason, changed_by, created_at
      FROM plan_versions
      WHERE plan_id = ${params.id}
      ORDER BY version DESC
    `);
  },

  // Token usage stats for specific plan
  'GET /api/plan/:id/tokens': (params) => {
    const stats = query(`
      SELECT
        SUM(total_tokens) as total_tokens,
        SUM(cost_usd) as total_cost,
        COUNT(*) as api_calls,
        ROUND(AVG(total_tokens)) as avg_tokens_per_call
      FROM token_usage WHERE plan_id = ${params.id}
    `)[0] || { total_tokens: 0, total_cost: 0, api_calls: 0, avg_tokens_per_call: 0 };

    const byWave = query(`
      SELECT wave_id, SUM(total_tokens) as tokens, SUM(cost_usd) as cost
      FROM token_usage WHERE plan_id = ${params.id} AND wave_id IS NOT NULL
      GROUP BY wave_id
    `);

    const byAgent = query(`
      SELECT agent, SUM(total_tokens) as tokens, COUNT(*) as calls
      FROM token_usage WHERE plan_id = ${params.id}
      GROUP BY agent ORDER BY tokens DESC LIMIT 10
    `);

    return { stats, byWave, byAgent };
  },

  // Update task status
  'POST /api/task/:id/status': (params, body) => {
    const { status, notes } = body;
    execSync(`${CLAUDE_HOME}/scripts/plan-db.sh update-task ${params.id} ${status} "${notes || ''}"`, {
      encoding: 'utf-8'
    });
    return { success: true, task_id: params.id, status };
  },

  // Update wave status
  'POST /api/wave/:id/status': (params, body) => {
    execSync(`${CLAUDE_HOME}/scripts/plan-db.sh update-wave ${params.id} ${body.status}`, {
      encoding: 'utf-8'
    });
    return { success: true, wave_id: params.id, status: body.status };
  },

  // Update plan status (for Kanban drag & drop)
  'POST /api/plan/:id/status': (params, body) => {
    const { status } = body;
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

    query(`UPDATE plans SET status = '${status}'${timestampUpdate} WHERE id = ${params.id}`);
    return { success: true, plan_id: parseInt(params.id), status };
  },

  // Validate plan (Thor)
  'POST /api/plan/:id/validate': (params, body) => {
    execSync(`${CLAUDE_HOME}/scripts/plan-db.sh validate ${params.id} ${body.by || 'thor'}`, {
      encoding: 'utf-8'
    });
    return { success: true, plan_id: params.id, validated_by: body.by || 'thor' };
  },

  // Token usage stats for project
  'GET /api/project/:id/tokens': (params) => {
    const stats = query(`
      SELECT
        SUM(total_tokens) as total_tokens,
        SUM(cost_usd) as total_cost,
        COUNT(*) as api_calls,
        ROUND(AVG(total_tokens)) as avg_tokens_per_call
      FROM token_usage WHERE project_id = '${params.id}'
    `)[0] || { total_tokens: 0, total_cost: 0, api_calls: 0, avg_tokens_per_call: 0 };

    const byPlan = query(`
      SELECT plan_id, SUM(total_tokens) as tokens, SUM(cost_usd) as cost
      FROM token_usage WHERE project_id = '${params.id}' AND plan_id IS NOT NULL
      GROUP BY plan_id
    `);

    const byAgent = query(`
      SELECT agent, SUM(total_tokens) as tokens, COUNT(*) as calls
      FROM token_usage WHERE project_id = '${params.id}'
      GROUP BY agent ORDER BY tokens DESC LIMIT 10
    `);

    return { stats, byPlan, byAgent };
  },

  // Record token usage (called by agents/hooks)
  'POST /api/tokens': (params, body) => {
    const { project_id, plan_id, wave_id, task_id, agent, model, input_tokens, output_tokens, cost_usd } = body;
    query(`
      INSERT INTO token_usage (project_id, plan_id, wave_id, task_id, agent, model, input_tokens, output_tokens, cost_usd)
      VALUES ('${project_id}', ${plan_id || 'NULL'}, '${wave_id || ''}', '${task_id || ''}', '${agent}', '${model}', ${input_tokens}, ${output_tokens}, ${cost_usd || 0})
    `);
    return { success: true };
  },

  // Get wave markdown file
  'GET /api/plan/:id/wave/:waveId/markdown': (params) => {
    const plan = query(`SELECT project_id, name FROM plans WHERE id = ${params.id}`)[0];
    if (!plan) return { error: 'Plan not found' };

    const project = query(`SELECT path FROM projects WHERE id = '${plan.project_id}'`)[0];
    if (!project) return { error: 'Project not found' };

    // Extract wave number from wave ID format: 8-W1 -> 1, 8-W2 -> 2
    const waveMatch = params.waveId.match(/W(\d+)$/);
    if (!waveMatch) return { error: 'Invalid wave ID format' };
    const waveNumber = waveMatch[1];

    const planName = plan.name.replace(/-Main$/, '');
    const phaseFile = `${planName}-Phase${waveNumber}.md`;
    const phasePath = path.join(CLAUDE_HOME, 'plans', plan.project_id, phaseFile);

    // Try phase file first, fallback to main file if not found
    try {
      if (fs.existsSync(phasePath)) {
        const content = fs.readFileSync(phasePath, 'utf-8');
        return { success: true, content, filename: phaseFile, waveId: params.waveId };
      }

      // Fallback to main file
      const mainFile = `${plan.name}-Main.md`;
      const mainPath = path.join(CLAUDE_HOME, 'plans', plan.project_id, mainFile);
      if (!fs.existsSync(mainPath)) {
        return { error: `Plan file not found: ${mainFile}` };
      }
      const content = fs.readFileSync(mainPath, 'utf-8');
      return { success: true, content, filename: mainFile, waveId: params.waveId };
    } catch (e) {
      return { error: e.message };
    }
  },

  // Get plan main markdown file
  'GET /api/plan/:id/markdown': (params) => {
    const plan = query(`SELECT project_id, name FROM plans WHERE id = ${params.id}`)[0];
    if (!plan) return { error: 'Plan not found' };

    const project = query(`SELECT path FROM projects WHERE id = '${plan.project_id}'`)[0];
    if (!project) return { error: 'Project not found' };

    const mainFile = `${plan.name}-Main.md`;
    const mainPath = path.join(CLAUDE_HOME, 'plans', plan.project_id, mainFile);

    try {
      if (!fs.existsSync(mainPath)) {
        return { error: `Plan file not found: ${mainFile}` };
      }
      const content = fs.readFileSync(mainPath, 'utf-8');
      return { success: true, content, filename: mainFile };
    } catch (e) {
      return { error: e.message };
    }
  },

  // Archive a completed plan
  'POST /api/plan/:id/archive': (params) => {
    const plan = query(`SELECT * FROM plans WHERE id = ${params.id}`)[0];
    if (!plan) return { error: 'Plan not found' };

    if (plan.status !== 'done') {
      return { error: 'Only completed plans can be archived' };
    }

    try {
      // Create archived directory structure: ~/.claude/plans/archived/YYYY-MM/{project}/
      const now = new Date();
      const yearMonth = `${now.getFullYear()}-${String(now.getMonth() + 1).padStart(2, '0')}`;
      const archiveDir = path.join(CLAUDE_HOME, 'plans', 'archived', yearMonth, plan.project_id);

      // Ensure archive directory exists
      if (!fs.existsSync(archiveDir)) {
        fs.mkdirSync(archiveDir, { recursive: true });
      }

      // Move all plan files matching pattern {planName}-*.md
      const plansDir = path.join(CLAUDE_HOME, 'plans', plan.project_id);
      const planPattern = new RegExp(`^${plan.name}.*\\.md$`);

      if (fs.existsSync(plansDir)) {
        const files = fs.readdirSync(plansDir).filter(f => planPattern.test(f));
        const movedFiles = [];

        for (const file of files) {
          const sourcePath = path.join(plansDir, file);
          const destPath = path.join(archiveDir, file);
          fs.renameSync(sourcePath, destPath);
          movedFiles.push(file);
        }

        // Update DB with archived info
        const archivedPath = path.relative(CLAUDE_HOME, archiveDir);
        query(`
          UPDATE plans
          SET archived_at = datetime('now'),
              archived_path = '${archivedPath}'
          WHERE id = ${params.id}
        `);

        return {
          success: true,
          archived_at: now.toISOString(),
          archived_path: archivedPath,
          files_moved: movedFiles
        };
      } else {
        return { error: 'Plans directory not found' };
      }
    } catch (e) {
      return { error: `Archive failed: ${e.message}` };
    }
  },

  // Unarchive a plan
  'POST /api/plan/:id/unarchive': (params) => {
    const plan = query(`SELECT * FROM plans WHERE id = ${params.id}`)[0];
    if (!plan) return { error: 'Plan not found' };

    if (!plan.archived_at || !plan.archived_path) {
      return { error: 'Plan is not archived' };
    }

    try {
      const archiveDir = path.join(CLAUDE_HOME, plan.archived_path);
      const plansDir = path.join(CLAUDE_HOME, 'plans', plan.project_id);

      // Ensure destination directory exists
      if (!fs.existsSync(plansDir)) {
        fs.mkdirSync(plansDir, { recursive: true });
      }

      // Move all plan files back
      const planPattern = new RegExp(`^${plan.name}.*\\.md$`);

      if (fs.existsSync(archiveDir)) {
        const files = fs.readdirSync(archiveDir).filter(f => planPattern.test(f));
        const movedFiles = [];

        for (const file of files) {
          const sourcePath = path.join(archiveDir, file);
          const destPath = path.join(plansDir, file);
          fs.renameSync(sourcePath, destPath);
          movedFiles.push(file);
        }

        // Update DB
        query(`
          UPDATE plans
          SET archived_at = NULL,
              archived_path = NULL
          WHERE id = ${params.id}
        `);

        return {
          success: true,
          unarchived_at: new Date().toISOString(),
          files_moved: movedFiles
        };
      } else {
        return { error: 'Archive directory not found' };
      }
    } catch (e) {
      return { error: `Unarchive failed: ${e.message}` };
    }
  }
};

module.exports = routes;
