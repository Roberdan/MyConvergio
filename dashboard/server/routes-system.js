// System Routes - Server management endpoints

const { query } = require('./db');
const fs = require('fs');
const path = require('path');

const CLAUDE_HOME = process.env.HOME + '/.claude';

module.exports = {
  'GET /api/health': () => {
    const start = Date.now();
    try {
      const dbCheck = query('SELECT COUNT(*) as count FROM projects')[0];
      const dbLatency = Date.now() - start;
      return {
        status: 'healthy',
        timestamp: new Date().toISOString(),
        uptime: process.uptime(),
        db: { connected: true, latency_ms: dbLatency, projects: dbCheck.count },
        memory: process.memoryUsage()
      };
    } catch (e) {
      return {
        status: 'unhealthy',
        timestamp: new Date().toISOString(),
        uptime: process.uptime(),
        db: { connected: false, error: e.message },
        memory: process.memoryUsage()
      };
    }
  },

  // Serve markdown files for task documentation
  'GET /api/file/:path(*)': (params) => {
    const requestedPath = params.path;
    if (!requestedPath) {
      return { error: 'No file path specified', status: 400 };
    }
    
    // Security: only allow access to .claude directory files
    let fullPath;
    if (requestedPath.startsWith('/')) {
      fullPath = requestedPath;
    } else {
      fullPath = path.join(CLAUDE_HOME, requestedPath);
    }
    
    // Normalize and check path is within allowed directory
    const normalizedPath = path.normalize(fullPath);
    if (!normalizedPath.startsWith(CLAUDE_HOME)) {
      return { error: 'Access denied - path outside allowed directory', status: 403 };
    }
    
    if (!fs.existsSync(normalizedPath)) {
      return { error: `File not found: ${normalizedPath}`, status: 404 };
    }
    
    try {
      const content = fs.readFileSync(normalizedPath, 'utf-8');
      const ext = path.extname(normalizedPath).toLowerCase();
      
      return {
        _raw: true,
        contentType: ext === '.md' ? 'text/markdown; charset=utf-8' : 'text/plain; charset=utf-8',
        content: content
      };
    } catch (e) {
      return { error: `Failed to read file: ${e.message}`, status: 500 };
    }
  },

  'POST /api/system/shutdown': (params, body) => {
    console.log('Shutdown requested');

    // Send response before shutting down
    setTimeout(() => {
      console.log('Shutting down server...');
      process.exit(0);
    }, 500); // Give time for response to be sent

    return { success: true, message: 'Server shutting down' };
  }
};
