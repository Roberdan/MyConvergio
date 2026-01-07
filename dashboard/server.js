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
const { routes: routesNotifications, handleSSE: handleNotificationSSE } = require('./server/routes-notifications');
const routesGitStatus = require('./server/routes-git-status');
const routesGitChanges = require('./server/routes-git-changes');
const routesSystem = require('./server/routes-system');
const routesMonitoring = require('./server/routes-monitoring');
const gitWatcher = require('./server/routes-git-watcher');

const BASE_PORT = parseInt(process.argv[2]) || 31415;
const CLAUDE_HOME = process.env.HOME + '/.claude';
const DASHBOARD_DIR = __dirname; // Use current directory for static files

// Port management with automatic fallback
function findAvailablePort(startPort, maxAttempts = 10) {
  return new Promise((resolve, reject) => {
    const net = require('net');

    function tryPort(port, attempts) {
      if (attempts >= maxAttempts) {
        reject(new Error(`No available ports found after ${maxAttempts} attempts`));
        return;
      }

      const server = net.createServer();
      server.listen(port, '127.0.0.1', () => {
        server.close(() => resolve(port));
      });

      server.on('error', (err) => {
        if (err.code === 'EADDRINUSE') {
          console.log(`Port ${port} in use, trying ${port + 1}...`);
          tryPort(port + 1, attempts + 1);
        } else {
          reject(err);
        }
      });
    }

    tryPort(startPort, 0);
  });
}

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
  ...routesSystem,
  ...routesMonitoring
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

// Global variable to store the actual port
let ACTUAL_PORT = 31415;

// Function to get current port
function getCurrentPort() {
  return ACTUAL_PORT;
}

// Create server
const server = http.createServer((req, res) => {
  const url = new URL(req.url, `http://localhost:${getCurrentPort()}`);
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

  // SSE route for real-time notifications
  if (pathname === '/api/notifications/stream' && req.method === 'GET') {
    handleNotificationSSE(req, res);
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
          const result = route.handler(route.params, req, res, body);

          // Check if SSE was handled (don't send JSON response)
          if (result && result._sse_handled) {
            return; // SSE handler manages the response
          }

          // Handle raw content responses (for serving files)
          if (result && result._raw) {
            const statusCode = result.status || 200;
            res.writeHead(statusCode, { 'Content-Type': result.contentType || 'text/plain' });
            res.end(result.content);
            return;
          }

          // Handle error responses with status codes
          if (result && result.status && result.status >= 400) {
            res.writeHead(result.status, { 'Content-Type': 'application/json' });
            res.end(JSON.stringify({ error: result.error }));
            return;
          }

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

// Start server with port management
findAvailablePort(BASE_PORT).then(PORT => {
  ACTUAL_PORT = PORT; // Store the actual port for URL construction
  server.listen(PORT, '127.0.0.1', () => {
    console.log(`Dashboard API running at http://127.0.0.1:${PORT}`);
    console.log(`Database: ${DB_FILE}`);
  });

  server.on('error', (err) => {
    console.error('Server error:', err.message);
    if (err.code === 'EADDRINUSE') {
      console.error(`Port ${PORT} is already in use. Try a different port with: node server.js <port>`);
    }
    process.exit(1);
  });
}).catch(err => {
  console.error('Failed to find available port:', err.message);
  process.exit(1);
});

// Graceful shutdown
process.on('SIGINT', () => {
  console.log('\nShutting down dashboard server...');
  server.close(() => {
    console.log('Server closed successfully');
    process.exit(0);
  });
});

// Handle uncaught exceptions
process.on('uncaughtException', (err) => {
  console.error('Uncaught Exception:', err.message);
  console.error(err.stack);
  server.close(() => process.exit(1));
});

process.on('unhandledRejection', (reason, promise) => {
  console.error('Unhandled Rejection at:', promise, 'reason:', reason);
  server.close(() => process.exit(1));
});
