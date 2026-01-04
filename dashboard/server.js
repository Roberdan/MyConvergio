#!/usr/bin/env node
// Dashboard API Server - Single source of truth from SQLite
// Usage: node server.js [port]

const http = require('http');
const fs = require('fs');
const path = require('path');
const { execSync } = require('child_process');

const PORT = process.argv[2] || 31415;
const CLAUDE_HOME = process.env.HOME + '/.claude';
const DB_FILE = CLAUDE_HOME + '/data/dashboard.db';
const DASHBOARD_DIR = CLAUDE_HOME + '/dashboard';

// MIME types
const MIME = {
  '.html': 'text/html',
  '.css': 'text/css',
  '.js': 'application/javascript',
  '.json': 'application/json',
  '.png': 'image/png',
  '.svg': 'image/svg+xml'
};

// Execute SQLite query and return JSON
function query(sql) {
  try {
    const result = execSync(`sqlite3 -json "${DB_FILE}" "${sql.replace(/"/g, '\\"')}"`, {
      encoding: 'utf-8',
      maxBuffer: 10 * 1024 * 1024
    });
    return JSON.parse(result || '[]');
  } catch (e) {
    console.error('DB Error:', e.message);
    return [];
  }
}

// API Routes
const routes = {
  // Kanban board - all projects
  'GET /api/kanban': () => {
    return query('SELECT * FROM v_kanban');
  },

  // List projects
  'GET /api/projects': () => {
    return query('SELECT * FROM v_project_plans');
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
               started_at, completed_at
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
  },

  // ===== NOTIFICATIONS =====

  // Get all notifications (with optional filters)
  'GET /api/notifications': (params, body, url) => {
    let whereClause = '1=1';
    const searchParams = url?.searchParams || new URLSearchParams();

    const projectId = searchParams.get('project');
    const unreadOnly = searchParams.get('unread') === 'true';
    const severity = searchParams.get('severity');
    const limit = parseInt(searchParams.get('limit')) || 100;
    const offset = parseInt(searchParams.get('offset')) || 0;
    const search = searchParams.get('search');

    if (projectId) whereClause += ` AND n.project_id = '${projectId}'`;
    if (unreadOnly) whereClause += ' AND n.is_read = 0 AND n.is_dismissed = 0';
    if (severity) whereClause += ` AND n.severity = '${severity}'`;
    if (search) whereClause += ` AND (n.title LIKE '%${search}%' OR n.message LIKE '%${search}%')`;

    const notifications = query(`
      SELECT n.*, p.name as project_name
      FROM notifications n
      JOIN projects p ON n.project_id = p.id
      WHERE ${whereClause}
      ORDER BY n.created_at DESC
      LIMIT ${limit} OFFSET ${offset}
    `);

    const total = query(`SELECT COUNT(*) as count FROM notifications n WHERE ${whereClause}`)[0]?.count || 0;

    return { notifications, total, limit, offset };
  },

  // Get unread notifications count and recent
  'GET /api/notifications/unread': () => {
    const unread = query(`
      SELECT n.*, p.name as project_name
      FROM notifications n
      JOIN projects p ON n.project_id = p.id
      WHERE n.is_read = 0 AND n.is_dismissed = 0
      ORDER BY n.created_at DESC
      LIMIT 20
    `);

    const countByProject = query(`
      SELECT project_id, COUNT(*) as count
      FROM notifications
      WHERE is_read = 0 AND is_dismissed = 0
      GROUP BY project_id
    `);

    const countBySeverity = query(`
      SELECT severity, COUNT(*) as count
      FROM notifications
      WHERE is_read = 0 AND is_dismissed = 0
      GROUP BY severity
    `);

    return {
      notifications: unread,
      total: unread.length,
      byProject: countByProject,
      bySeverity: countBySeverity
    };
  },

  // Create a notification
  'POST /api/notifications': (params, body) => {
    const { project_id, type, severity, title, message, link, link_type, source_table, source_id } = body;

    if (!project_id || !type || !title) {
      return { error: 'Missing required fields: project_id, type, title' };
    }

    query(`
      INSERT INTO notifications (project_id, type, severity, title, message, link, link_type, source_table, source_id)
      VALUES ('${project_id}', '${type}', '${severity || 'info'}', '${title.replace(/'/g, "''")}',
              '${(message || '').replace(/'/g, "''")}', '${link || ''}', '${link_type || ''}',
              '${source_table || ''}', '${source_id || ''}')
    `);

    const notification = query('SELECT * FROM notifications ORDER BY id DESC LIMIT 1')[0];
    return { success: true, notification };
  },

  // Mark notification as read
  'POST /api/notifications/:id/read': (params) => {
    query(`UPDATE notifications SET is_read = 1, read_at = CURRENT_TIMESTAMP WHERE id = ${params.id}`);
    return { success: true, id: params.id };
  },

  // Dismiss notification
  'POST /api/notifications/:id/dismiss': (params) => {
    query(`UPDATE notifications SET is_dismissed = 1 WHERE id = ${params.id}`);
    return { success: true, id: params.id };
  },

  // Mark all as read (optionally for a project)
  'POST /api/notifications/read-all': (params, body) => {
    const projectClause = body.project_id ? `AND project_id = '${body.project_id}'` : '';
    query(`UPDATE notifications SET is_read = 1, read_at = CURRENT_TIMESTAMP WHERE is_read = 0 ${projectClause}`);
    return { success: true };
  },

  // Get notification triggers configuration
  'GET /api/notifications/triggers': () => {
    return query('SELECT * FROM notification_triggers ORDER BY event_type');
  },

  // Toggle notification trigger
  'POST /api/notifications/triggers/:id/toggle': (params) => {
    query(`UPDATE notification_triggers SET is_enabled = 1 - is_enabled WHERE id = ${params.id}`);
    return { success: true };
  },

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

      // Recent commits
      let commits = [];
      try {
        const logJson = execSync('git log --oneline -10 --format="%H|%s|%an|%ar"', { cwd, encoding: 'utf-8' });
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
  }
};

// Match route with params
function matchRoute(method, url) {
  const key = `${method} ${url}`;
  if (routes[key]) return { handler: routes[key], params: {} };

  for (const [pattern, handler] of Object.entries(routes)) {
    const [m, p] = pattern.split(' ');
    if (m !== method) continue;

    const patternParts = p.split('/');
    const urlParts = url.split('/');

    if (patternParts.length !== urlParts.length) continue;

    const params = {};
    let match = true;

    for (let i = 0; i < patternParts.length; i++) {
      if (patternParts[i].startsWith(':')) {
        params[patternParts[i].slice(1)] = urlParts[i];
      } else if (patternParts[i] !== urlParts[i]) {
        match = false;
        break;
      }
    }

    if (match) return { handler, params };
  }

  return null;
}

// Serve static files
function serveStatic(res, filePath) {
  const fullPath = path.join(DASHBOARD_DIR, filePath);

  if (!fs.existsSync(fullPath)) {
    res.writeHead(404);
    res.end('Not found');
    return;
  }

  const ext = path.extname(fullPath);
  const contentType = MIME[ext] || 'application/octet-stream';

  res.writeHead(200, { 'Content-Type': contentType });
  res.end(fs.readFileSync(fullPath));
}

// Create server
const server = http.createServer((req, res) => {
  const url = new URL(req.url, `http://localhost:${PORT}`);
  const pathname = url.pathname;

  // CORS headers
  res.setHeader('Access-Control-Allow-Origin', '*');
  res.setHeader('Access-Control-Allow-Methods', 'GET, POST, OPTIONS');
  res.setHeader('Access-Control-Allow-Headers', 'Content-Type');

  if (req.method === 'OPTIONS') {
    res.writeHead(200);
    res.end();
    return;
  }

  // API routes
  if (pathname.startsWith('/api/')) {
    const route = matchRoute(req.method, pathname);

    if (route) {
      let body = '';
      req.on('data', chunk => body += chunk);
      req.on('end', () => {
        try {
          const jsonBody = body ? JSON.parse(body) : {};
          const result = route.handler(route.params, jsonBody, url);
          res.writeHead(200, { 'Content-Type': 'application/json' });
          res.end(JSON.stringify(result));
        } catch (e) {
          res.writeHead(500, { 'Content-Type': 'application/json' });
          res.end(JSON.stringify({ error: e.message }));
        }
      });
    } else {
      res.writeHead(404, { 'Content-Type': 'application/json' });
      res.end(JSON.stringify({ error: 'Not found' }));
    }
    return;
  }

  // Static files
  let filePath = pathname === '/' ? '/dashboard.html' : pathname;
  serveStatic(res, filePath);
});

server.listen(PORT, '127.0.0.1', () => {
  console.log(`Dashboard API running at http://127.0.0.1:${PORT}`);
  console.log(`Database: ${DB_FILE}`);
});
