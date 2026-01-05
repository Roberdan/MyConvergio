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
          // Expand directories to individual files
          if (file.endsWith('/')) {
            try {
              const dirFiles = execSync(`git ls-files --others --exclude-standard "${file}"`, { cwd, encoding: 'utf-8' });
              dirFiles.split('\n').filter(f => f.trim()).forEach(f => untracked.push(f));
            } catch (e) {
              untracked.push(file);
            }
          } else {
            untracked.push(file);
          }
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
  },

  // Get commit details with changed files
  'GET /api/project/:id/git/commit/:sha': (params) => {
    const project = query(`SELECT path FROM projects WHERE id = '${params.id}'`)[0];
    if (!project || !project.path) return { error: 'Project not found' };

    try {
      const cwd = project.path;
      const sha = params.sha.replace(/[^a-fA-F0-9]/g, '');

      // Get commit details
      const format = '%H|%an|%ae|%at|%s|%b|%P';
      const commitInfo = execSync(`git show -s --format="${format}" ${sha}`, { cwd, encoding: 'utf-8' }).trim();
      const parts = commitInfo.split('|');

      const commit = {
        hash: parts[0],
        shortHash: parts[0].substring(0, 7),
        author: parts[1],
        email: parts[2],
        timestamp: parseInt(parts[3]) * 1000,
        date: new Date(parseInt(parts[3]) * 1000).toLocaleString('it-IT', { timeZone: 'Europe/Rome' }),
        subject: parts[4],
        body: parts[5] || '',
        parents: parts[6] ? parts[6].split(' ') : [],
        isMerge: parts[6] && parts[6].includes(' ')
      };

      // Get list of changed files with stats
      const diffStat = execSync(`git diff-tree --no-commit-id --name-status -r ${sha}`, { cwd, encoding: 'utf-8' });
      const files = diffStat.split('\n').filter(l => l.trim()).map(line => {
        const [status, ...pathParts] = line.split('\t');
        const path = pathParts.join('\t'); // Handle renames with tab
        return {
          status: status.charAt(0), // A=added, M=modified, D=deleted, R=renamed
          path: path,
          statusLabel: { A: 'Added', M: 'Modified', D: 'Deleted', R: 'Renamed', C: 'Copied' }[status.charAt(0)] || status
        };
      });

      // Get stats (insertions/deletions)
      try {
        const stats = execSync(`git diff --shortstat ${sha}^..${sha}`, { cwd, encoding: 'utf-8' }).trim();
        const insertMatch = stats.match(/(\d+) insertion/);
        const deleteMatch = stats.match(/(\d+) deletion/);
        commit.insertions = insertMatch ? parseInt(insertMatch[1]) : 0;
        commit.deletions = deleteMatch ? parseInt(deleteMatch[1]) : 0;
      } catch (e) {
        commit.insertions = 0;
        commit.deletions = 0;
      }

      return { commit, files };
    } catch (e) {
      return { error: e.message };
    }
  },

  // Get diff for a specific file in a specific commit
  'GET /api/project/:id/git/commit/:sha/diff/:file(*)': (params) => {
    const project = query(`SELECT path FROM projects WHERE id = '${params.id}'`)[0];
    if (!project || !project.path) return { error: 'Project not found' };

    try {
      const cwd = project.path;
      const sha = params.sha.replace(/[^a-fA-F0-9]/g, '');
      const filePath = params.file;
      const path = require('path');
      const ext = path.extname(filePath).slice(1).toLowerCase();

      // Get diff for this specific file in this commit
      let diff = '';
      try {
        diff = execSync(`git diff --no-color ${sha}^..${sha} -- "${filePath}"`, { cwd, encoding: 'utf-8' });
      } catch (e) {
        // First commit has no parent
        try {
          diff = execSync(`git diff --no-color 4b825dc642cb6eb9a060e54bf8d69288fbee4904..${sha} -- "${filePath}"`, { cwd, encoding: 'utf-8' });
        } catch (e2) {
          diff = '';
        }
      }

      // Get commit info for header
      const format = '%H|%an|%at|%s';
      const commitInfo = execSync(`git show -s --format="${format}" ${sha}`, { cwd, encoding: 'utf-8' }).trim();
      const parts = commitInfo.split('|');

      const language = getLanguage(ext);

      return {
        path: filePath,
        extension: ext,
        diff: diff,
        language,
        commit: {
          hash: parts[0],
          shortHash: parts[0].substring(0, 7),
          author: parts[1],
          date: new Date(parseInt(parts[2]) * 1000).toLocaleString('it-IT', { timeZone: 'Europe/Rome' }),
          subject: parts[3]
        }
      };
    } catch (e) {
      return { error: e.message };
    }
  }
};

function getLanguage(ext) {
  const langMap = {
    js: 'javascript', jsx: 'javascript', ts: 'typescript', tsx: 'typescript',
    py: 'python', rb: 'ruby', rs: 'rust', go: 'go', java: 'java',
    c: 'c', cpp: 'cpp', h: 'c', hpp: 'cpp',
    css: 'css', scss: 'scss', sass: 'sass', less: 'less',
    html: 'html', htm: 'html', xml: 'xml', svg: 'xml',
    json: 'json', yaml: 'yaml', yml: 'yaml', toml: 'toml',
    md: 'markdown', mdx: 'markdown',
    sh: 'bash', bash: 'bash', zsh: 'bash',
    sql: 'sql', graphql: 'graphql',
    dockerfile: 'dockerfile', makefile: 'makefile'
  };
  return langMap[ext] || 'plaintext';
}

module.exports = routes;
