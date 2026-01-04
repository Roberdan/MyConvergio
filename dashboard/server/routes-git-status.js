// Git Status, Branches, and Remote Operations

const { execSync } = require('child_process');
const { query } = require('./db');

const routes = {
  // Get project git status
  'GET /api/project/:id/git': (params) => {
    const project = query(`SELECT path FROM projects WHERE id = '${params.id}'`)[0];
    if (!project || !project.path) return { error: 'Project not found' };

    try {
      const cwd = project.path;

      // Current branch
      const branch = execSync('git branch --show-current', { cwd, encoding: 'utf-8' }).trim();

      // Uncommitted changes
      const statusOutput = execSync('git status --porcelain', { cwd, encoding: 'utf-8' });
      const lines = statusOutput.split('\n').filter(l => l.trim());

      const staged = [];
      const unstaged = [];
      const untracked = [];

      lines.forEach(line => {
        const status = line.substring(0, 2);
        const file = line.substring(3);
        if (status[0] !== ' ' && status[0] !== '?') {
          staged.push({ status: status[0], path: file });
        }
        if (status[1] !== ' ' && status[1] !== '?') {
          unstaged.push({ status: status[1], path: file });
        }
        if (status === '??') {
          untracked.push(file);
        }
      });

      // Recent commits (50 for scrollable history)
      let commits = [];
      try {
        const logJson = execSync('git log --oneline -50 --format="%H|%s|%an|%ar"', { cwd, encoding: 'utf-8' });
        commits = logJson.split('\n').filter(l => l).map(line => {
          const [hash, message, author, date] = line.split('|');
          return { hash: hash.substring(0, 7), message, author, date };
        });
      } catch (e) {}

      return {
        branch,
        uncommitted: { staged, unstaged, untracked },
        commits,
        totalChanges: staged.length + unstaged.length + untracked.length
      };
    } catch (e) {
      return { error: e.message, branch: 'unknown', uncommitted: { staged: [], unstaged: [], untracked: [] } };
    }
  },

  // Get branches
  'GET /api/project/:id/git/branches': (params) => {
    const project = query(`SELECT path FROM projects WHERE id = '${params.id}'`)[0];
    if (!project || !project.path) return { error: 'Project not found' };

    try {
      const cwd = project.path;
      const current = execSync('git branch --show-current', { cwd, encoding: 'utf-8' }).trim();
      const branchOutput = execSync('git branch -a', { cwd, encoding: 'utf-8' });

      const branches = branchOutput.split('\n')
        .filter(b => b.trim())
        .map(b => ({
          name: b.replace(/^\*?\s+/, '').trim(),
          current: b.startsWith('*'),
          remote: b.includes('remotes/')
        }));

      return { current, branches };
    } catch (e) {
      return { error: e.message, branches: [] };
    }
  },

  // Pull from remote
  'POST /api/project/:id/git/pull': (params) => {
    const project = query(`SELECT path FROM projects WHERE id = '${params.id}'`)[0];
    if (!project || !project.path) return { error: 'Project not found' };

    try {
      const cwd = project.path;
      const output = execSync('git pull', { cwd, encoding: 'utf-8', timeout: 60000 });
      return { success: true, output: output.trim() };
    } catch (e) {
      return { error: e.message };
    }
  },

  // Push to remote
  'POST /api/project/:id/git/push': (params, body) => {
    const project = query(`SELECT path FROM projects WHERE id = '${params.id}'`)[0];
    if (!project || !project.path) return { error: 'Project not found' };

    try {
      const cwd = project.path;
      let cmd = 'git push';
      if (body.setUpstream) {
        const branch = execSync('git branch --show-current', { cwd, encoding: 'utf-8' }).trim();
        cmd = `git push -u origin ${branch}`;
      }
      const output = execSync(cmd, { cwd, encoding: 'utf-8', timeout: 60000 });
      return { success: true, output: output.trim() };
    } catch (e) {
      if (e.message.includes('no upstream branch')) {
        return { error: 'No upstream branch. Use "Push with upstream" option.' };
      }
      return { error: e.message };
    }
  },

  // Fetch from remote
  'POST /api/project/:id/git/fetch': (params) => {
    const project = query(`SELECT path FROM projects WHERE id = '${params.id}'`)[0];
    if (!project || !project.path) return { error: 'Project not found' };

    try {
      const cwd = project.path;
      execSync('git fetch --all', { cwd, encoding: 'utf-8', timeout: 60000 });
      return { success: true };
    } catch (e) {
      return { error: e.message };
    }
  }
};

module.exports = routes;
