// System Routes - Server management endpoints

const { query } = require('./db');

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
