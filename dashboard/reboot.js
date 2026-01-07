#!/usr/bin/env node
// Dashboard server reboot script
// Usage: node reboot.js [--pm2]

const { execSync, spawn } = require('child_process');
const path = require('path');

const PORT = 31415;
const SERVER_DIR = __dirname;
const usePM2 = process.argv.includes('--pm2');

console.log('Restarting dashboard server...');

// Check if PM2 is available
function hasPM2() {
  try {
    execSync('pm2 --version', { stdio: 'ignore' });
    return true;
  } catch {
    return false;
  }
}

// Kill existing dashboard process on port with graceful shutdown
function killPort() {
  try {
    // Get process info for port
    const output = execSync(`lsof -i:${PORT} -F pcn`, { encoding: 'utf8' });
    const lines = output.trim().split('\n');

    let dashboardPids = [];
    for (let i = 0; i < lines.length; i += 3) {
      if (lines[i] && lines[i].startsWith('p')) {
        const pid = lines[i].substring(1);
        const command = lines[i + 1] ? lines[i + 1].substring(1) : '';
        const name = lines[i + 2] ? lines[i + 2].substring(1) : '';

        // Only kill if it's our dashboard server
        if (command.includes('node') && command.includes('server.js') && command.includes('dashboard')) {
          dashboardPids.push(pid);
        }
      }
    }

    if (dashboardPids.length > 0) {
      console.log(`Found dashboard process(es) on port ${PORT}, attempting graceful shutdown...`);

      // First try SIGTERM for graceful shutdown
      execSync(`kill -TERM ${dashboardPids.join(' ')}`);

      // Wait a bit for graceful shutdown
      setTimeout(() => {
        try {
          // Check if processes are still running
          const stillRunning = execSync(`ps -p ${dashboardPids.join(',')} -o pid=`, { encoding: 'utf8' }).trim();
          if (stillRunning) {
            console.log('Processes still running, forcing shutdown...');
            execSync(`kill -9 ${dashboardPids.join(' ')}`);
            console.log(`Force killed dashboard process(es) on port ${PORT}`);
          } else {
            console.log(`Gracefully shut down dashboard process(es) on port ${PORT}`);
          }
        } catch {
          console.log(`Successfully shut down dashboard process(es) on port ${PORT}`);
        }
      }, 2000);
    }
  } catch {
    // No process on port or lsof not available
  }
}

// Start with PM2
function startWithPM2() {
  try {
    // Stop existing PM2 process if any
    try {
      execSync('pm2 delete claude-dashboard', { stdio: 'ignore', cwd: SERVER_DIR });
    } catch { }

    // Start with PM2
    execSync('pm2 start ecosystem.config.js', { stdio: 'inherit', cwd: SERVER_DIR });
    console.log(`\nDashboard managed by PM2 at http://localhost:${PORT}`);
    console.log('Commands: pm2 status | pm2 logs claude-dashboard | pm2 stop claude-dashboard');
    process.exit(0);
  } catch (e) {
    console.error('PM2 start failed:', e.message);
    process.exit(1);
  }
}

// Start without PM2 (detached)
function startDetached() {
  killPort();

  setTimeout(() => {
    const server = spawn('node', ['server.js'], {
      cwd: SERVER_DIR,
      detached: true,
      stdio: ['ignore', 'pipe', 'pipe']
    });

    server.stdout.once('data', (data) => {
      console.log(data.toString().trim());
      console.log(`Dashboard running at http://localhost:${PORT}`);
      process.exit(0);
    });

    server.stderr.once('data', (data) => {
      console.error('Error:', data.toString().trim());
      process.exit(1);
    });

    server.unref();

    setTimeout(() => {
      console.log(`Dashboard started at http://localhost:${PORT}`);
      process.exit(0);
    }, 3000);
  }, 500);
}

// Main
if (usePM2 || (hasPM2() && !process.argv.includes('--no-pm2'))) {
  if (!hasPM2()) {
    console.log('PM2 not installed. Install with: npm install -g pm2');
    console.log('Falling back to detached mode...\n');
    startDetached();
  } else {
    killPort();
    setTimeout(startWithPM2, 500);
  }
} else {
  startDetached();
}
