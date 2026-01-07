// PM2 Ecosystem Configuration
// Usage: pm2 start ecosystem.config.js

module.exports = {
  apps: [{
    name: 'claude-dashboard',
    script: 'server.js',
    cwd: __dirname,
    instances: 1,
    autorestart: true,
    watch: false,
    max_memory_restart: '200M',
    env: {
      NODE_ENV: 'production'
    },
    error_file: '/tmp/claude-dashboard-error.log',
    out_file: '/tmp/claude-dashboard-out.log',
    log_date_format: 'YYYY-MM-DD HH:mm:ss',
    restart_delay: 1000,
    max_restarts: 10,
    min_uptime: '5s'
  }]
};
