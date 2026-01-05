// Git File System Watcher - Real-time git status updates via SSE
const chokidar = require('chokidar');
const path = require('path');
const { query } = require('./db');

// Store active SSE connections per project
const sseClients = new Map(); // projectId -> Set of response objects

// Debounce map to avoid excessive notifications
const debounceTimers = new Map(); // projectId -> timeout

// Active watchers per project
const watchers = new Map(); // projectId -> chokidar watcher

/**
 * Start watching a project's git repository
 * @param {string} projectId - Project ID
 * @param {string} projectPath - Absolute path to project
 */
function startWatcher(projectId, projectPath) {
  if (watchers.has(projectId)) {
    return; // Already watching
  }

  const gitDir = path.join(projectPath, '.git');

  // Watch ONLY .git directory (for commits, checkouts, etc.)
  // Working directory changes will be detected by polling (30s interval)
  const watcher = chokidar.watch(gitDir, {
    ignored: [
      '**/.git/logs/**',           // Ignore reflog updates (too noisy)
      '**/.git/objects/**',        // Ignore object DB changes (too many files)
      '**/.git/hooks/**'           // Ignore hooks
    ],
    ignoreInitial: true,            // Don't trigger on initial scan
    persistent: true,
    depth: 3,                       // Shallow depth - .git is not deep
    awaitWriteFinish: {
      stabilityThreshold: 200,     // Wait 200ms after last change
      pollInterval: 100
    },
    usePolling: false,              // Use native FS events
    atomic: true                    // Wait for atomic writes
  });

  watcher.on('all', (event, filepath) => {
    // Debounce notifications - only send update after 300ms of no changes
    if (debounceTimers.has(projectId)) {
      clearTimeout(debounceTimers.get(projectId));
    }

    const timer = setTimeout(() => {
      notifyClients(projectId);
      debounceTimers.delete(projectId);
    }, 300);

    debounceTimers.set(projectId, timer);
  });

  watcher.on('error', (error) => {
    console.error(`Git watcher error for project ${projectId}:`, error);
  });

  watchers.set(projectId, watcher);
  console.log(`Started git watcher for project ${projectId} at ${projectPath}`);
}

/**
 * Stop watching a project
 * @param {string} projectId - Project ID
 */
function stopWatcher(projectId) {
  const watcher = watchers.get(projectId);
  if (watcher) {
    watcher.close();
    watchers.delete(projectId);
    console.log(`Stopped git watcher for project ${projectId}`);
  }
}

/**
 * Notify all connected clients for a project
 * @param {string} projectId - Project ID
 */
function notifyClients(projectId) {
  const clients = sseClients.get(projectId);
  if (!clients || clients.size === 0) return;

  const data = JSON.stringify({
    type: 'git-change',
    projectId,
    timestamp: Date.now()
  });

  clients.forEach(res => {
    try {
      res.write(`data: ${data}\n\n`);
    } catch (e) {
      // Client disconnected, remove from set
      clients.delete(res);
    }
  });

  console.log(`Notified ${clients.size} client(s) for project ${projectId}`);
}

/**
 * SSE endpoint handler - must be called differently from regular routes
 * @param {string} projectId - Project ID
 * @param {http.IncomingMessage} req - HTTP request object
 * @param {http.ServerResponse} res - HTTP response object
 */
function handleSSE(projectId, req, res) {
  // Get project path from database
  const project = query(`SELECT path FROM projects WHERE id = '${projectId}'`)[0];

  if (!project) {
    res.writeHead(404, { 'Content-Type': 'application/json' });
    res.end(JSON.stringify({ error: 'Project not found' }));
    return;
  }

  // Set SSE headers
  res.writeHead(200, {
    'Content-Type': 'text/event-stream',
    'Cache-Control': 'no-cache',
    'Connection': 'keep-alive',
    'Access-Control-Allow-Origin': '*'
  });

  // Send initial connection confirmation
  res.write(`data: ${JSON.stringify({ type: 'connected', projectId })}\n\n`);

  // Add client to set
  if (!sseClients.has(projectId)) {
    sseClients.set(projectId, new Set());
  }
  sseClients.get(projectId).add(res);

  // Start watcher if not already running
  startWatcher(projectId, project.path);

  console.log(`SSE client connected for project ${projectId} (total: ${sseClients.get(projectId).size})`);

  // Handle client disconnect
  req.on('close', () => {
    const clients = sseClients.get(projectId);
    if (clients) {
      clients.delete(res);
      console.log(`SSE client disconnected for project ${projectId} (remaining: ${clients.size})`);

      // Stop watcher if no more clients
      if (clients.size === 0) {
        stopWatcher(projectId);
        sseClients.delete(projectId);
      }
    }
  });
}

// Cleanup on server shutdown
process.on('SIGTERM', () => {
  console.log('Shutting down git watchers...');
  watchers.forEach((watcher, projectId) => stopWatcher(projectId));
});

module.exports = {
  handleSSE,
  startWatcher,
  stopWatcher
};
