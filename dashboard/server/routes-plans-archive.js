// Plan Archive Routes

const { query, escapeSQL, CLAUDE_HOME } = require('./db');
const fs = require('fs');
const path = require('path');

const routes = {
  // Get all archived plans
  'GET /api/archive/plans': () => {
    return query(`
      SELECT id, name, project_id, status, tasks_done, tasks_total,
             archived_at, archived_path, created_at, completed_at
      FROM plans
      WHERE archived_at IS NOT NULL
      ORDER BY archived_at DESC
    `);
  },

  // Get all archived waves
  'GET /api/archive/waves': () => {
    return query(`
      SELECT w.id, w.wave_id, w.name, w.plan_id, w.status,
             w.tasks_done, w.tasks_total, w.completed_at,
             p.archived_at, p.archived_path
      FROM waves w
      JOIN plans p ON w.plan_id = p.id
      WHERE p.archived_at IS NOT NULL
      ORDER BY p.archived_at DESC
    `);
  },

  // Get all archived tasks
  'GET /api/archive/tasks': () => {
    return query(`
      SELECT t.id, t.task_id, t.title, t.status, t.priority,
             t.completed_at, t.duration_minutes,
             p.id as plan_id, p.name as plan_name,
             p.archived_at, p.archived_path
      FROM tasks t
      JOIN plans p ON t.plan_id = p.id
      WHERE p.archived_at IS NOT NULL
      ORDER BY p.archived_at DESC, t.task_id
    `);
  },

  // Archive a completed plan
  'POST /api/plan/:id/archive': (params) => {
    const planId = parseInt(params.id, 10);
    if (isNaN(planId)) return { error: 'Invalid plan ID' };
    const plan = query(`SELECT * FROM plans WHERE id = ${planId}`)[0];
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
              archived_path = '${escapeSQL(archivedPath)}'
          WHERE id = ${planId}
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
    const planId = parseInt(params.id, 10);
    if (isNaN(planId)) return { error: 'Invalid plan ID' };
    const plan = query(`SELECT * FROM plans WHERE id = ${planId}`)[0];
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
          WHERE id = ${planId}
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

