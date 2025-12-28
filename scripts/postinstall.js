#!/usr/bin/env node

/**
 * MyConvergio Post-Install Script
 *
 * Automatically copies agents, rules, and skills to ~/.claude/
 * after npm install -g myconvergio
 *
 * Features:
 * - Creates backup if existing installation found
 * - Saves manifest of installed files for safe uninstall
 * - Preserves user's custom files and CLAUDE.md
 */

const fs = require('fs');
const path = require('path');
const os = require('os');

const CLAUDE_HOME = path.join(os.homedir(), '.claude');
const PACKAGE_ROOT = path.join(__dirname, '..');
const MANIFEST_FILE = path.join(CLAUDE_HOME, '.myconvergio-manifest.json');

// Colors for terminal output
const colors = {
  reset: '\x1b[0m',
  green: '\x1b[32m',
  yellow: '\x1b[33m',
  blue: '\x1b[34m',
};

function log(color, message) {
  console.log(`${color}${message}${colors.reset}`);
}

function copyRecursive(src, dest, installedFiles = []) {
  if (!fs.existsSync(src)) {
    return installedFiles;
  }

  fs.mkdirSync(dest, { recursive: true });

  const items = fs.readdirSync(src);

  for (const item of items) {
    const srcPath = path.join(src, item);
    const destPath = path.join(dest, item);
    const stat = fs.statSync(srcPath);

    if (stat.isDirectory()) {
      copyRecursive(srcPath, destPath, installedFiles);
    } else {
      fs.copyFileSync(srcPath, destPath);
      installedFiles.push(destPath);
    }
  }

  return installedFiles;
}

function loadManifest() {
  try {
    if (fs.existsSync(MANIFEST_FILE)) {
      return JSON.parse(fs.readFileSync(MANIFEST_FILE, 'utf8'));
    }
  } catch {}
  return { files: [], version: null };
}

function saveManifest(files, version) {
  const manifest = {
    version,
    installedAt: new Date().toISOString(),
    files
  };
  fs.mkdirSync(CLAUDE_HOME, { recursive: true });
  fs.writeFileSync(MANIFEST_FILE, JSON.stringify(manifest, null, 2));
}

function getVersion() {
  try {
    const versionFile = path.join(PACKAGE_ROOT, 'VERSION');
    const content = fs.readFileSync(versionFile, 'utf8');
    const match = content.match(/SYSTEM_VERSION=(.+)/);
    return match ? match[1].trim() : 'unknown';
  } catch {
    const pkg = require('../package.json');
    return pkg.version;
  }
}

function createBackup() {
  const backupDir = path.join(os.homedir(), '.claude-backup-' + Date.now());
  const dirs = ['agents', 'rules', 'skills'];
  let hasContent = false;

  for (const dir of dirs) {
    const srcDir = path.join(CLAUDE_HOME, dir);
    if (fs.existsSync(srcDir) && fs.readdirSync(srcDir).length > 0) {
      hasContent = true;
      copyRecursive(srcDir, path.join(backupDir, dir));
    }
  }

  return hasContent ? backupDir : null;
}

function countDirs(dir) {
  if (!fs.existsSync(dir)) return 0;
  return fs.readdirSync(dir).filter(f =>
    fs.statSync(path.join(dir, f)).isDirectory()
  ).length;
}

function main() {
  // Skip if running in CI or if MYCONVERGIO_SKIP_POSTINSTALL is set
  if (process.env.CI || process.env.MYCONVERGIO_SKIP_POSTINSTALL) {
    console.log('Skipping postinstall (CI environment or MYCONVERGIO_SKIP_POSTINSTALL set)');
    return;
  }

  log(colors.blue, '\n📦 MyConvergio Post-Install\n');

  const srcAgents = path.join(PACKAGE_ROOT, '.claude', 'agents');
  const srcRules = path.join(PACKAGE_ROOT, '.claude', 'rules');
  const srcSkills = path.join(PACKAGE_ROOT, '.claude', 'skills');

  // Check if source directories exist
  if (!fs.existsSync(srcAgents)) {
    log(colors.yellow, 'Warning: Source agents directory not found. Skipping installation.');
    return;
  }

  // Check for existing installation and backup
  const existingManifest = loadManifest();
  if (existingManifest.version) {
    log(colors.yellow, `Existing installation found (v${existingManifest.version})`);
    log(colors.yellow, 'Creating backup before upgrade...\n');
    const backupDir = createBackup();
    if (backupDir) {
      log(colors.green, `  ✓ Backup created: ${backupDir}\n`);
    }
  }

  const installedFiles = [];

  // Install agents
  copyRecursive(srcAgents, path.join(CLAUDE_HOME, 'agents'), installedFiles);
  log(colors.green, `  ✓ Installed agents`);

  // Install rules
  copyRecursive(srcRules, path.join(CLAUDE_HOME, 'rules'), installedFiles);
  log(colors.green, `  ✓ Installed rules`);

  // Install skills
  copyRecursive(srcSkills, path.join(CLAUDE_HOME, 'skills'), installedFiles);
  const skillsCount = countDirs(path.join(CLAUDE_HOME, 'skills'));
  log(colors.green, `  ✓ Installed ${skillsCount} skills`);

  // Save manifest for safe uninstall
  const version = getVersion();
  saveManifest(installedFiles, version);
  log(colors.green, `  ✓ Saved manifest (${installedFiles.length} files)`);

  console.log('');
  log(colors.green, '✅ MyConvergio installed successfully!');
  console.log('');
  log(colors.yellow, 'Your ~/.claude/CLAUDE.md was NOT modified.');
  console.log('Create your own configuration file if needed.\n');
  console.log('Run `myconvergio help` for available commands.\n');
}

main();
