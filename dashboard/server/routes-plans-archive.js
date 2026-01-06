// Plan Archive Routes

const { query, escapeSQL, CLAUDE_HOME } = require('./db');
const fs = require('fs');
const path = require('path');

const routes = {
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

