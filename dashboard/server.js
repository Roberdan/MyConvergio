#!/usr/bin/env node
// Dashboard API Server - Single source of truth from SQLite
// Usage: node server.js [port]

const http = require('http');
const fs = require('fs');
const path = require('path');

const { DB_FILE } = require('./server/db');

// Import route modules
const routesPlans = require('./server/routes-plans');
const routesGithub = require('./server/routes-github');
const routesNotifications = require('./server/routes-notifications');
const routesGitStatus = require('./server/routes-git-status');
const routesGitChanges = require('./server/routes-git-changes');
const routesSystem = require('./server/routes-system');
const gitWatcher = require('./server/routes-git-watcher');

const PORT = process.argv[2] || 31415;
const CLAUDE_HOME = process.env.HOME + '/.claude';
const DASHBOARD_DIR = __dirname; // Use current directory for static files

// MIME types
const MIME = {
  '.html': 'text/html',
  '.css': 'text/css',
  '.js': 'application/javascript',
  '.json': 'application/json',
  '.png': 'image/png',
  '.svg': 'image/svg+xml'
};

// Merge all route modules
const routes = {
  ...routesPlans,
  ...routesGithub,
  ...routesNotifications,
  ...routesGitStatus,
  ...routesGitChanges,
  ...routesSystem
};

// Match route with params (supports wildcards like :file(*) for file paths)
function matchRoute(method, url) {
  const key = `${method} ${url}`;
  if (routes[key]) return { handler: routes[key], params: {} };

  for (const [pattern, handler] of Object.entries(routes)) {
    const [m, p] = pattern.split(' ');
    if (m !== method) continue;

    const patternParts = p.split('/');
    const urlParts = url.split('/');

    // Check for wildcard parameter (e.g., :file(*))
    const wildcardIndex = patternParts.findIndex(part => part.endsWith('(*)'));

    if (wildcardIndex >= 0) {
      // Pattern has wildcard - match prefix and capture rest
      if (urlParts.length < wildcardIndex) continue;

      const params = {};
      let match = true;

      for (let i = 0; i < wildcardIndex; i++) {
        if (patternParts[i].startsWith(':')) {
          const paramName = patternParts[i].slice(1).replace('(*)', '');
          params[paramName] = urlParts[i];
        } else if (patternParts[i] !== urlParts[i]) {
          match = false;
          break;
        }
      }

      if (match) {
        // Capture the wildcard part (rest of the URL)
        const wildcardParam = patternParts[wildcardIndex].slice(1).replace('(*)', '');
        params[wildcardParam] = urlParts.slice(wildcardIndex).join('/');
        return { handler, params };
      }
    } else {
      // No wildcard - exact segment match
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

  // No cache for JS/CSS/HTML to force reload during development
  const headers = { 'Content-Type': contentType };
  if (['.js', '.css', '.html'].includes(ext)) {
    headers['Cache-Control'] = 'no-cache, no-store, must-revalidate';
    headers['Pragma'] = 'no-cache';
    headers['Expires'] = '0';
  }

  res.writeHead(200, headers);
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

  // Raw file serving for images/binary
  const rawMatch = pathname.match(/^\/api\/project\/([^/]+)\/file-raw\/(.+)$/);
  if (rawMatch) {
    const project = require('./server/db').query(`SELECT path FROM projects WHERE id = '${rawMatch[1]}'`)[0];
    if (project?.path) {
      const fullPath = path.join(project.path, decodeURIComponent(rawMatch[2]));
      if (fs.existsSync(fullPath)) {
        const ext = path.extname(fullPath);
        res.writeHead(200, { 'Content-Type': MIME[ext] || 'application/octet-stream' });
        res.end(fs.readFileSync(fullPath));
        return;
      }
    }
    res.writeHead(404);
    res.end('Not found');
    return;
  }

  // SSE route for git watching (special handling - not JSON response)
  const sseMatch = pathname.match(/^\/api\/project\/([^/]+)\/git\/watch$/);
  if (sseMatch && req.method === 'GET') {
    gitWatcher.handleSSE(sseMatch[1], req, res);
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
