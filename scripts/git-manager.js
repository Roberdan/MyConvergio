#!/usr/bin/env node

/**
 * MyConvergio Git Manager (Opt-In)
 *
 * Optional git tracking for ~/.claude directory
 * Usage: myconvergio git-init    - Initialize git tracking (opt-in)
 *        myconvergio git-status  - Show git status
 */

const { execSync } = require('child_process');
const fs = require('fs');
const path = require('path');
const os = require('os');

const CLAUDE_HOME = path.join(os.homedir(), '.claude');
const GIT_DIR = path.join(CLAUDE_HOME, '.git');
const GITIGNORE_PATH = path.join(CLAUDE_HOME, '.gitignore');

// Check if git is initialized in ~/.claude
function isGitInitialized() {
  return fs.existsSync(GIT_DIR);
}

// Check git status
function getGitStatus() {
  if (!isGitInitialized()) {
    return { initialized: false, status: null };
  }

  try {
    const status = execSync('git status --porcelain', {
      cwd: CLAUDE_HOME,
      encoding: 'utf8'
    });

    const changes = status.trim().split('\n').filter(line => line.length > 0);

    return {
      initialized: true,
      hasChanges: changes.length > 0,
      changes: changes,
      status: status
    };
  } catch (err) {
    return { initialized: true, status: null, error: err.message };
  }
}

// Create default .gitignore for ~/.claude
function createDefaultGitignore() {
  const gitignoreContent = `# MyConvergio Git Tracking
# This tracks your Claude configuration safely

# Ignore sensitive data
*.log
*.secret
*credentials*
*secrets*
.env
.env.*

# Ignore cache and temp files
.cache/
tmp/
temp/
*.tmp

# Ignore large data files (keep structure only)
data/*.db
data/*.sqlite
data/*.db-journal

# Ignore node_modules if any plugins use them
node_modules/

# Track these important directories
!agents/
!rules/
!skills/
!templates/
!CLAUDE.md

# Dashboard files (optional - uncomment to track)
# !dashboard/
`;

  fs.writeFileSync(GITIGNORE_PATH, gitignoreContent);
  return gitignoreContent;
}

// Initialize git tracking
function initGit(options = {}) {
  const { force = false } = options;

  if (isGitInitialized() && !force) {
    return {
      success: false,
      message: 'Git already initialized. Use --force to reinitialize.'
    };
  }

  try {
    // Ensure directory exists
    if (!fs.existsSync(CLAUDE_HOME)) {
      fs.mkdirSync(CLAUDE_HOME, { recursive: true });
    }

    // Initialize git
    execSync('git init', { cwd: CLAUDE_HOME, stdio: 'pipe' });

    // Create .gitignore
    const gitignoreContent = createDefaultGitignore();

    // Create initial commit
    execSync('git add .gitignore', { cwd: CLAUDE_HOME, stdio: 'pipe' });
    execSync('git commit -m "Initial commit: MyConvergio git tracking"', {
      cwd: CLAUDE_HOME,
      stdio: 'pipe'
    });

    // Add all tracked files
    execSync('git add -A', { cwd: CLAUDE_HOME, stdio: 'pipe' });

    const status = getGitStatus();

    return {
      success: true,
      message: 'Git tracking initialized successfully',
      gitignoreCreated: true,
      hasChanges: status.hasChanges,
      changes: status.changes
    };
  } catch (err) {
    return {
      success: false,
      message: 'Failed to initialize git',
      error: err.message
    };
  }
}

// Suggest commit message based on changes
function suggestCommitMessage(changes) {
  if (!changes || changes.length === 0) {
    return null;
  }

  const added = changes.filter(c => c.startsWith('A') || c.startsWith('??')).length;
  const modified = changes.filter(c => c.startsWith('M')).length;
  const deleted = changes.filter(c => c.startsWith('D')).length;

  const parts = [];
  if (added > 0) parts.push(`${added} added`);
  if (modified > 0) parts.push(`${modified} modified`);
  if (deleted > 0) parts.push(`${deleted} deleted`);

  const summary = parts.join(', ');
  const timestamp = new Date().toISOString().split('T')[0];

  return `chore: update claude config (${summary}) - ${timestamp}`;
}

// Create commit with all changes
function commitChanges(message = null) {
  if (!isGitInitialized()) {
    return {
      success: false,
      message: 'Git not initialized. Run "myconvergio git-init" first.'
    };
  }

  const status = getGitStatus();

  if (!status.hasChanges) {
    return {
      success: false,
      message: 'No changes to commit.'
    };
  }

  const commitMessage = message || suggestCommitMessage(status.changes);

  try {
    execSync('git add -A', { cwd: CLAUDE_HOME, stdio: 'pipe' });
    execSync(`git commit -m "${commitMessage}"`, {
      cwd: CLAUDE_HOME,
      stdio: 'pipe'
    });

    return {
      success: true,
      message: 'Changes committed successfully',
      commitMessage: commitMessage
    };
  } catch (err) {
    return {
      success: false,
      message: 'Failed to commit changes',
      error: err.message
    };
  }
}

// Show git log
function showLog(limit = 10) {
  if (!isGitInitialized()) {
    return {
      success: false,
      message: 'Git not initialized.'
    };
  }

  try {
    const log = execSync(`git log --oneline -n ${limit}`, {
      cwd: CLAUDE_HOME,
      encoding: 'utf8'
    });

    return {
      success: true,
      log: log.trim().split('\n')
    };
  } catch (err) {
    return {
      success: false,
      message: 'Failed to get git log',
      error: err.message
    };
  }
}

// Interactive git init prompt
async function promptGitInit() {
  const readline = require('readline');
  const rl = readline.createInterface({
    input: process.stdin,
    output: process.stdout
  });

  console.log('\n╔════════════════════════════════════════════════════════════╗');
  console.log('║              Git Tracking for ~/.claude (OPTIONAL)        ║');
  console.log('╚════════════════════════════════════════════════════════════╝\n');

  console.log('MyConvergio can track your Claude configuration with git.');
  console.log('This allows you to:');
  console.log('  ✓ Track changes to agents, rules, skills over time');
  console.log('  ✓ Rollback to previous configurations');
  console.log('  ✓ Sync across machines (if you set up a remote)\n');

  console.log('This is OPTIONAL and can be enabled later with "myconvergio git-init"\n');

  return new Promise((resolve) => {
    rl.question('Enable git tracking now? [y/N]: ', (answer) => {
      rl.close();
      resolve(answer.toLowerCase().trim() === 'y');
    });
  });
}

module.exports = {
  isGitInitialized,
  getGitStatus,
  createDefaultGitignore,
  initGit,
  suggestCommitMessage,
  commitChanges,
  showLog,
  promptGitInit
};
