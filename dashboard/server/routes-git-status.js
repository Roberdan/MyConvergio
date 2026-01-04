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

      // Recent commits (initial batch)
      let commits = [];
      try {
        const logJson = execSync('git log --oneline -30 --format="%H|%P|%s|%an|%ar"', { cwd, encoding: 'utf-8' });
        commits = logJson.split('\n').filter(l => l).map(line => {
          const parts = line.split('|');
          const hash = parts[0];
          const parents = parts[1] ? parts[1].split(' ').filter(p => p) : [];
          const message = parts[2] || '';
          const author = parts[3] || '';
          const date = parts[4] || '';
          return {
            hash: hash.substring(0, 7),
            fullHash: hash,
            message,
            author,
            date,
            isMerge: parents.length > 1
          };
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
  },

  // Get paginated commits for lazy scroll with multi-branch support
  'GET /api/project/:id/git/commits': (params, body, url) => {
    const project = query(`SELECT path FROM projects WHERE id = '${params.id}'`)[0];
    if (!project || !project.path) return { error: 'Project not found' };

    const skip = parseInt(url.searchParams.get('skip') || '0');
    const limit = parseInt(url.searchParams.get('limit') || '30');
    const allBranches = url.searchParams.get('all') === 'true';

    try {
      const cwd = project.path;

      // Get all branches for decoration
      const branchMap = {};
      try {
        const branchForCommit = execSync('git branch -a --format="%(refname:short)|%(objectname:short)"', { cwd, encoding: 'utf-8' });
        branchForCommit.split('\n').filter(l => l).forEach(line => {
          const [branch, hash] = line.split('|');
          if (!branchMap[hash]) branchMap[hash] = [];
          branchMap[hash].push(branch);
        });
      } catch (e) {}

      // Get commits from all branches if requested
      const branchArg = allBranches ? '--all' : '';
      const logCmd = `git log ${branchArg} --skip=${skip} -${limit} --format="%H|%P|%s|%an|%ar|%D"`;
      const logJson = execSync(logCmd, { cwd, encoding: 'utf-8' });

      const commits = logJson.split('\n').filter(l => l).map(line => {
        const parts = line.split('|');
        const hash = parts[0];
        const parents = parts[1] ? parts[1].split(' ').filter(p => p) : [];
        const refs = parts[5] ? parts[5].split(', ').filter(r => r) : [];
        const shortHash = hash.substring(0, 7);

        return {
          hash: shortHash,
          fullHash: hash,
          message: parts[2] || '',
          author: parts[3] || '',
          date: parts[4] || '',
          isMerge: parents.length > 1,
          parentCount: parents.length,
          branches: branchMap[shortHash] || [],
          refs: refs
        };
      });

      // Check if there are more commits
      const countCmd = allBranches ? 'git rev-list --all --count' : 'git rev-list --count HEAD';
      const totalCount = parseInt(execSync(countCmd, { cwd, encoding: 'utf-8' }).trim()) || 0;
      const hasMore = skip + commits.length < totalCount;

      return { commits, hasMore, total: totalCount };
    } catch (e) {
      return { error: e.message, commits: [], hasMore: false };
    }
  }
};

module.exports = routes;
