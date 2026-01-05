// Git Changes Routes (Stage, Unstage, Commit, Checkout, Branch)

const { execSync } = require('child_process');
const { query } = require('./db');

const routes = {
  // Stage files
  'POST /api/project/:id/git/stage': (params, body) => {
    const project = query(`SELECT path FROM projects WHERE id = '${params.id}'`)[0];
    if (!project || !project.path) return { error: 'Project not found' };

    try {
      const cwd = project.path;

      if (body.all) {
        execSync('git add -A', { cwd, encoding: 'utf-8' });
      } else if (body.files && body.files.length > 0) {
        const files = body.files.map(f => `"${f}"`).join(' ');
        execSync(`git add ${files}`, { cwd, encoding: 'utf-8' });
      } else {
        return { error: 'No files specified' };
      }

      return { success: true };
    } catch (e) {
      return { error: e.message };
    }
  },

  // Unstage files
  'POST /api/project/:id/git/unstage': (params, body) => {
    const project = query(`SELECT path FROM projects WHERE id = '${params.id}'`)[0];
    if (!project || !project.path) return { error: 'Project not found' };

    try {
      const cwd = project.path;

      if (body.all) {
        execSync('git reset HEAD', { cwd, encoding: 'utf-8' });
      } else if (body.files && body.files.length > 0) {
        const files = body.files.map(f => `"${f}"`).join(' ');
        execSync(`git reset HEAD ${files}`, { cwd, encoding: 'utf-8' });
      } else {
        return { error: 'No files specified' };
      }

      return { success: true };
    } catch (e) {
      return { error: e.message };
    }
  },

  // Discard file changes (handles both tracked and untracked files)
  'POST /api/project/:id/git/discard': (params, body) => {
    const project = query(`SELECT path FROM projects WHERE id = '${params.id}'`)[0];
    if (!project || !project.path) return { error: 'Project not found' };

    try {
      const cwd = project.path;
      const fs = require('fs');
      const path = require('path');

      if (!body.files || body.files.length === 0) {
        return { error: 'No files specified' };
      }

      for (const file of body.files) {
        const fullPath = path.join(cwd, file);
        // Check if file is untracked
        try {
          execSync(`git ls-files --error-unmatch "${file}"`, { cwd, encoding: 'utf-8', stdio: 'pipe' });
          // File is tracked - use checkout
          execSync(`git checkout -- "${file}"`, { cwd, encoding: 'utf-8' });
        } catch (e) {
          // File is untracked - delete it
          if (fs.existsSync(fullPath)) fs.unlinkSync(fullPath);
        }
      }

      return { success: true };
    } catch (e) {
      return { error: e.message };
    }
  },

  // Commit changes
  'POST /api/project/:id/git/commit': (params, body) => {
    const project = query(`SELECT path FROM projects WHERE id = '${params.id}'`)[0];
    if (!project || !project.path) return { error: 'Project not found' };

    if (!body.message) return { error: 'Commit message required' };

    try {
      const cwd = project.path;
      const message = body.message.replace(/"/g, '\\"');

      execSync(`git commit -m "${message}"`, { cwd, encoding: 'utf-8' });

      if (body.push) {
        try {
          execSync('git push', { cwd, encoding: 'utf-8', timeout: 30000 });
        } catch (pushErr) {
          return { success: true, warning: 'Committed but push failed: ' + pushErr.message };
        }
      }

      return { success: true };
    } catch (e) {
      return { error: e.message };
    }
  },

  // Checkout branch
  'POST /api/project/:id/git/checkout': (params, body) => {
    const project = query(`SELECT path FROM projects WHERE id = '${params.id}'`)[0];
    if (!project || !project.path) return { error: 'Project not found' };

    if (!body.branch) return { error: 'Branch name required' };

    try {
      const cwd = project.path;
      const branch = body.branch.replace(/[;&|`$]/g, '');

      // Let git handle uncommitted changes - it will fail if there are conflicts
      execSync(`git checkout ${branch}`, { cwd, encoding: 'utf-8' });
      return { success: true, branch };
    } catch (e) {
      // Git will return error if checkout fails due to conflicts
      return { error: e.message };
    }
  },

  // Create new branch
  'POST /api/project/:id/git/branch/create': (params, body) => {
    const project = query(`SELECT path FROM projects WHERE id = '${params.id}'`)[0];
    if (!project || !project.path) return { error: 'Project not found' };

    if (!body.name) return { error: 'Branch name required' };

    try {
      const cwd = project.path;
      const name = body.name.replace(/[;&|`$\s]/g, '');

      execSync(`git checkout -b ${name}`, { cwd, encoding: 'utf-8' });
      return { success: true, branch: name };
    } catch (e) {
      return { error: e.message };
    }
  },

  // Get file diff
  'GET /api/project/:id/git/diff/:file(*)': (params) => {
    const project = query(`SELECT path FROM projects WHERE id = '${params.id}'`)[0];
    if (!project || !project.path) return { error: 'Project not found' };

    try {
      const cwd = project.path;
      const filePath = params.file;
      const fs = require('fs');
      const path = require('path');
      const fullPath = path.join(cwd, filePath);

      // Get file extension for language detection
      const ext = path.extname(filePath).slice(1).toLowerCase();

      // Get diff output
      let diff = '';
      try {
        diff = execSync(`git diff --no-color -- "${filePath}"`, { cwd, encoding: 'utf-8' });
      } catch (e) {
        diff = '';
      }

      const language = getLanguage(ext);

      // Get staged diff if file is staged
      let stagedDiff = '';
      try {
        stagedDiff = execSync(`git diff --cached --no-color -- "${filePath}"`, { cwd, encoding: 'utf-8' });
      } catch (e) {
        stagedDiff = '';
      }

      // Determine if file is truly new (untracked, not in git history)
      let isNew = false;
      let content = '';

      if (!diff && !stagedDiff) {
        // No diff at all - check if file is untracked
        try {
          const gitStatus = execSync(`git status --porcelain -- "${filePath}"`, { cwd, encoding: 'utf-8' });
          isNew = gitStatus.trim().startsWith('??') || gitStatus.trim().startsWith('A ');
        } catch (e) {
          isNew = false;
        }
      }

      // Get file content for new files or markdown preview
      if (fs.existsSync(fullPath)) {
        if (isNew || language === 'markdown') {
          try {
            content = fs.readFileSync(fullPath, 'utf-8');
          } catch (e) {
            content = '';
          }
        }
      }

      // Combine staged and unstaged diffs, or use whichever is available
      let combinedDiff = '';
      if (diff && stagedDiff) {
        // Both staged and unstaged changes
        combinedDiff = `=== Staged Changes ===\n${stagedDiff}\n\n=== Unstaged Changes ===\n${diff}`;
      } else {
        combinedDiff = stagedDiff || diff;
      }

      return {
        path: filePath,
        extension: ext,
        diff: combinedDiff,
        stagedDiff: stagedDiff,
        unstagedDiff: diff,
        content,
        isNew,
        language
      };
    } catch (e) {
      return { error: e.message };
    }
  },

  // Get file content
  'GET /api/project/:id/file/:file(*)': (params) => {
    const project = query(`SELECT path FROM projects WHERE id = '${params.id}'`)[0];
    if (!project || !project.path) return { error: 'Project not found' };

    try {
      const fs = require('fs');
      const path = require('path');
      const filePath = params.file;
      const fullPath = path.join(project.path, filePath);
      const ext = path.extname(filePath).slice(1).toLowerCase();

      if (!fs.existsSync(fullPath)) {
        return { error: 'File not found' };
      }

      const content = fs.readFileSync(fullPath, 'utf-8');
      return {
        path: filePath,
        extension: ext,
        content,
        language: getLanguage(ext)
      };
    } catch (e) {
      return { error: e.message };
    }
  },

  // Open file externally with default app
  'POST /api/project/:id/file/open': (params, body) => {
    const project = query(`SELECT path FROM projects WHERE id = '${params.id}'`)[0];
    if (!project || !project.path) return { error: 'Project not found' };

    try {
      const path = require('path');
      const fullPath = path.join(project.path, body.path);
      const cmd = process.platform === 'darwin' ? 'open' : process.platform === 'win32' ? 'start' : 'xdg-open';
      execSync(`${cmd} "${fullPath}"`, { encoding: 'utf-8' });
      return { success: true };
    } catch (e) {
      return { error: e.message };
    }
  },

  // Get file modification time (for auto-refresh)
  'GET /api/project/:id/file/mtime/:file(*)': (params) => {
    const project = query(`SELECT path FROM projects WHERE id = '${params.id}'`)[0];
    if (!project || !project.path) return { error: 'Project not found' };

    try {
      const fs = require('fs');
      const path = require('path');
      const fullPath = path.join(project.path, params.file);
      const stats = fs.statSync(fullPath);
      return { mtime: stats.mtimeMs };
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
