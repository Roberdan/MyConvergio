#!/usr/bin/env node

const fs = require('fs');
const path = require('path');
const os = require('os');
const readline = require('readline');

const CLAUDE_HOME = path.join(os.homedir(), '.claude');
const PACKAGE_ROOT = path.join(__dirname, '..');
const VERSION_FILE = path.join(PACKAGE_ROOT, 'VERSION');
const MANIFEST_FILE = path.join(CLAUDE_HOME, '.myconvergio-manifest.json');

// Colors for terminal output
const colors = {
  reset: '\x1b[0m',
  green: '\x1b[32m',
  yellow: '\x1b[33m',
  blue: '\x1b[34m',
  red: '\x1b[31m',
};

function log(color, message) {
  console.log(`${color}${message}${colors.reset}`);
}

function getVersion() {
  try {
    const content = fs.readFileSync(VERSION_FILE, 'utf8');
    const match = content.match(/SYSTEM_VERSION=(.+)/);
    return match ? match[1].trim() : 'unknown';
  } catch {
    const pkg = require('../package.json');
    return pkg.version;
  }
}

function countInstalled() {
  const counts = { agents: 0, rules: 0, skills: 0 };

  const agentsDir = path.join(CLAUDE_HOME, 'agents');
  if (fs.existsSync(agentsDir)) {
    counts.agents = countMdFiles(agentsDir);
  }

  const rulesDir = path.join(CLAUDE_HOME, 'rules');
  if (fs.existsSync(rulesDir)) {
    counts.rules = countMdFiles(rulesDir);
  }

  const skillsDir = path.join(CLAUDE_HOME, 'skills');
  if (fs.existsSync(skillsDir)) {
    counts.skills = fs.readdirSync(skillsDir).filter(f =>
      fs.statSync(path.join(skillsDir, f)).isDirectory()
    ).length;
  }

  return counts;
}

function countMdFiles(dir) {
  let count = 0;
  const items = fs.readdirSync(dir);
  for (const item of items) {
    const fullPath = path.join(dir, item);
    const stat = fs.statSync(fullPath);
    if (stat.isDirectory()) {
      count += countMdFiles(fullPath);
    } else if (item.endsWith('.md') &&
               !['CONSTITUTION.md', 'CommonValuesAndPrinciples.md', 'SECURITY_FRAMEWORK_TEMPLATE.md'].includes(item)) {
      count++;
    }
  }
  return count;
}

function copyRecursive(src, dest, installedFiles = []) {
  if (!fs.existsSync(src)) return installedFiles;

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
  return { files: [], version: null, installedAt: null };
}

function saveManifest(files, version) {
  const manifest = {
    version,
    installedAt: new Date().toISOString(),
    files
  };
  fs.writeFileSync(MANIFEST_FILE, JSON.stringify(manifest, null, 2));
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

  if (hasContent) {
    return backupDir;
  }
  return null;
}

function hasExistingContent() {
  const dirs = ['agents', 'rules', 'skills'];
  for (const dir of dirs) {
    const dirPath = path.join(CLAUDE_HOME, dir);
    if (fs.existsSync(dirPath) && fs.readdirSync(dirPath).length > 0) {
      return true;
    }
  }
  return false;
}

function install(skipBackup = false) {
  log(colors.blue, 'Installing MyConvergio to ~/.claude/...\n');

  // Check for existing content and ALWAYS backup if found
  const existingManifest = loadManifest();
  const hasContent = hasExistingContent();

  if (!skipBackup && hasContent) {
    if (existingManifest.version) {
      log(colors.yellow, `Upgrading from v${existingManifest.version}...`);
    } else {
      log(colors.yellow, 'Existing ~/.claude/ content detected.');
    }
    log(colors.yellow, 'Creating backup before installation...\n');
    const backupDir = createBackup();
    if (backupDir) {
      log(colors.green, `  ✓ Backup created: ${backupDir}\n`);
    }
  } else if (!hasContent) {
    log(colors.blue, 'Fresh installation to ~/.claude/\n');
  }

  const srcAgents = path.join(PACKAGE_ROOT, '.claude', 'agents');
  const srcRules = path.join(PACKAGE_ROOT, '.claude', 'rules');
  const srcSkills = path.join(PACKAGE_ROOT, '.claude', 'skills');

  const installedFiles = [];

  // Install agents
  copyRecursive(srcAgents, path.join(CLAUDE_HOME, 'agents'), installedFiles);
  log(colors.green, '  ✓ Installed agents');

  // Install rules
  copyRecursive(srcRules, path.join(CLAUDE_HOME, 'rules'), installedFiles);
  log(colors.green, '  ✓ Installed rules');

  // Install skills
  copyRecursive(srcSkills, path.join(CLAUDE_HOME, 'skills'), installedFiles);
  log(colors.green, '  ✓ Installed skills');

  // Save manifest
  const version = getVersion();
  saveManifest(installedFiles, version);
  log(colors.green, `  ✓ Saved manifest (${installedFiles.length} files)`);

  console.log('');
  log(colors.green, '✅ Installation complete!');
  console.log('');
  log(colors.yellow, 'Note: Your ~/.claude/CLAUDE.md was NOT modified.');
  console.log('      Create your own configuration file if needed.');
}

function uninstall() {
  log(colors.blue, 'Removing MyConvergio from ~/.claude/...\n');

  const manifest = loadManifest();

  if (manifest.files && manifest.files.length > 0) {
    // Safe uninstall: only remove files we installed
    log(colors.yellow, `Removing ${manifest.files.length} files installed by MyConvergio...\n`);

    let removed = 0;
    for (const file of manifest.files) {
      if (fs.existsSync(file)) {
        fs.unlinkSync(file);
        removed++;
      }
    }

    // Clean up empty directories
    const dirs = ['agents', 'rules', 'skills'];
    for (const dir of dirs) {
      cleanEmptyDirs(path.join(CLAUDE_HOME, dir));
    }

    // Remove manifest
    if (fs.existsSync(MANIFEST_FILE)) {
      fs.unlinkSync(MANIFEST_FILE);
    }

    log(colors.green, `  ✓ Removed ${removed} files`);
    console.log('');
    log(colors.green, '✅ Uninstall complete!');
    log(colors.yellow, 'Your custom files were preserved.');
  } else {
    // No manifest - warn user
    log(colors.yellow, '⚠️  No installation manifest found.');
    log(colors.yellow, 'This means MyConvergio was installed before manifest tracking,');
    log(colors.yellow, 'or was installed via git clone.\n');
    log(colors.yellow, 'To avoid deleting your custom files, please manually remove:');
    console.log('  ~/.claude/agents/');
    console.log('  ~/.claude/rules/');
    console.log('  ~/.claude/skills/');
    console.log('');
    log(colors.yellow, 'Or use: make clean (if installed via git clone)');
  }

  console.log('');
  log(colors.yellow, 'Note: ~/.claude/CLAUDE.md was NOT removed (user config).');
}

function cleanEmptyDirs(dir) {
  if (!fs.existsSync(dir)) return;

  const items = fs.readdirSync(dir);
  for (const item of items) {
    const fullPath = path.join(dir, item);
    if (fs.statSync(fullPath).isDirectory()) {
      cleanEmptyDirs(fullPath);
    }
  }

  // Check if directory is now empty
  if (fs.readdirSync(dir).length === 0) {
    fs.rmdirSync(dir);
  }
}

function showVersion() {
  const version = getVersion();
  log(colors.blue, `MyConvergio v${version}`);
  console.log('');

  const counts = countInstalled();
  log(colors.blue, 'Installed Components:');
  console.log(`  Agents: ${counts.agents > 0 ? counts.agents : colors.red + 'not installed' + colors.reset}`);
  console.log(`  Rules:  ${counts.rules > 0 ? counts.rules : colors.red + 'not installed' + colors.reset}`);
  console.log(`  Skills: ${counts.skills > 0 ? counts.skills : colors.red + 'not installed' + colors.reset}`);
}

function showHelp() {
  console.log(`
${colors.blue}MyConvergio - Claude Code Subagents Suite${colors.reset}

${colors.yellow}Usage:${colors.reset}
  myconvergio [command]

${colors.yellow}Commands:${colors.reset}
  install     Install/reinstall agents, rules, and skills to ~/.claude/
  uninstall   Remove all installed components from ~/.claude/
  version     Show version and installation status
  help        Show this help message

${colors.yellow}Examples:${colors.reset}
  myconvergio install     # Install or update components
  myconvergio version     # Check what's installed
  myconvergio uninstall   # Remove everything

${colors.yellow}More info:${colors.reset}
  https://github.com/roberdan/MyConvergio
`);
}

// Main
const args = process.argv.slice(2);
const command = args[0] || 'help';

switch (command) {
  case 'install':
  case 'reinstall':
  case 'update':
    install();
    break;
  case 'uninstall':
  case 'remove':
    uninstall();
    break;
  case 'version':
  case '-v':
  case '--version':
    showVersion();
    break;
  case 'help':
  case '-h':
  case '--help':
  default:
    showHelp();
    break;
}
