// Plan Markdown Routes

const { query, escapeSQL, CLAUDE_HOME } = require('./db');
const fs = require('fs');
const path = require('path');

const routes = {
  // Get wave markdown file
  'GET /api/plan/:id/wave/:waveId/markdown': (params) => {
    const planId = parseInt(params.id, 10);
    if (isNaN(planId)) return { error: 'Invalid plan ID' };
    const plan = query(`SELECT project_id, name FROM plans WHERE id = ${planId}`)[0];
    if (!plan) return { error: 'Plan not found' };

    const project = query(`SELECT path FROM projects WHERE id = '${escapeSQL(plan.project_id)}'`)[0];
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
    const planId = parseInt(params.id, 10);
    if (isNaN(planId)) return { error: 'Invalid plan ID' };
    const plan = query(`SELECT project_id, name FROM plans WHERE id = ${planId}`)[0];
    if (!plan) return { error: 'Plan not found' };

    const project = query(`SELECT path FROM projects WHERE id = '${escapeSQL(plan.project_id)}'`)[0];
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
  }
};

module.exports = routes;

