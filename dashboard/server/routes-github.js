// GitHub Data Routes

const { execSync } = require('child_process');
const { query } = require('./db');

const routes = {
  // Get project GitHub data (issues, PRs)
  'GET /api/project/:id/github': (params) => {
    const project = query(`SELECT path, github_url FROM projects WHERE id = '${params.id}'`)[0];
    if (!project || !project.path) return { error: 'Project not found' };

    try {
      const cwd = project.path;

      // Get GitHub repo from remote
      let repo = '';
      try {
        const remote = execSync('git remote get-url origin', { cwd, encoding: 'utf-8' }).trim();
        const match = remote.match(/github\.com[/:]([\w-]+\/[\w-]+)/);
        if (match) repo = match[1].replace('.git', '');
      } catch (e) {
        return { error: 'No GitHub remote found', issues: [], prs: [] };
      }

      if (!repo) return { error: 'Not a GitHub repository', issues: [], prs: [] };

      // Get open issues
      let issues = [];
      try {
        const issuesJson = execSync(`gh issue list --repo ${repo} --state open --limit 20 --json number,title,state,labels,createdAt,author`, {
          encoding: 'utf-8', timeout: 10000
        });
        issues = JSON.parse(issuesJson || '[]');
      } catch (e) { console.error('Issues error:', e.message); }

      // Get open PRs
      let prs = [];
      try {
        const prsJson = execSync(`gh pr list --repo ${repo} --state open --limit 10 --json number,title,state,additions,deletions,files,author,createdAt,headRefName`, {
          encoding: 'utf-8', timeout: 10000
        });
        prs = JSON.parse(prsJson || '[]');
      } catch (e) { console.error('PRs error:', e.message); }

      return { repo, issues, prs };
    } catch (e) {
      return { error: e.message, issues: [], prs: [] };
    }
  }
};

module.exports = routes;
