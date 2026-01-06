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

// Kill existing process on port
function killPort() {
  try {
    const pids = execSync(`lsof -ti:${PORT}`, { encoding: 'utf8' }).trim();
    if (pids) {
      execSync(`kill -9 ${pids.split('\n').join(' ')}`);
      console.log(`Killed process(es) on port ${PORT}`);
    }
  } catch {
    // No process on port
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
